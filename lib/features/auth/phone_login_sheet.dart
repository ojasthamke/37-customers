import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/phone_auth_service.dart';
import '../../core/widgets/shake_widget.dart';
import '../dashboard/home_screen.dart';
import '../profile/legal/policy_models.dart';
import '../profile/legal/policy_detail_screen.dart';
import 'auth_provider.dart';
import 'google_onboarding_sheet.dart';

enum PhoneAuthStateStep { enterPhone, enterOtp }

/// Bottom Sheet & Modal View for Firebase Phone Number Authentication (SMS OTP)
class PhoneLoginSheet extends ConsumerStatefulWidget {
  const PhoneLoginSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const PhoneLoginSheet(),
      ),
    );
  }

  @override
  ConsumerState<PhoneLoginSheet> createState() => _PhoneLoginSheetState();
}

class _PhoneLoginSheetState extends ConsumerState<PhoneLoginSheet> {
  PhoneAuthStateStep _step = PhoneAuthStateStep.enterPhone;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _termsShakeKey = GlobalKey<ShakeWidgetState>();

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _agreeToTerms = true;
  bool _termsError = false;

  String? _verificationId;
  int? _resendToken;
  int _secondsRemaining = 45;
  Timer? _countdownTimer;
  String? _errorMessage;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 45);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendOtp({bool isResend = false}) async {
    if (!isResend && !_agreeToTerms) {
      _termsShakeKey.currentState?.shake();
      setState(() => _termsError = true);
      HapticFeedback.heavyImpact();
      return;
    }

    if (!isResend && !_phoneFormKey.currentState!.validate()) {
      return;
    }

    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (rawPhone.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number.');
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    try {
      await PhoneAuthService.instance.sendOtp(
        phoneNumber: rawPhone,
        forceResendingToken: isResend ? _resendToken : null,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isSendingOtp = false;
            _step = PhoneAuthStateStep.enterOtp;
          });
          _startTimer();
          HapticFeedback.mediumImpact();
        },
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          // Automatic SMS verification on Android
          debugPrint('PhoneLoginSheet: Auto-retrieval completed');
          if (credential.smsCode != null && mounted) {
            _otpController.text = credential.smsCode!;
          }
          await _handleAutoVerification(credential);
        },
        onVerificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isSendingOtp = false;
            _errorMessage = _cleanFirebaseAuthErrorMessage(e);
          });
          HapticFeedback.heavyImpact();
        },
        onCodeAutoRetrievalTimeout: (verificationId) {
          if (!mounted) return;
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _errorMessage = 'Could not send verification code. Please try again.';
      });
    }
  }

  Future<void> _handleAutoVerification(PhoneAuthCredential credential) async {
    setState(() => _isVerifyingOtp = true);
    try {
      final userCred = await PhoneAuthService.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user != null) {
        await _completeLoginWithBackend(user.phoneNumber ?? _phoneController.text.trim(), user.uid);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
          _errorMessage = 'Auto verification failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_verificationId == null) {
      setState(() => _errorMessage = 'Please request a new OTP code.');
      return;
    }

    final code = _otpController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit OTP code.');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });

    try {
      final userCred = await PhoneAuthService.instance.verifyOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );

      final user = userCred.user;
      if (user != null && mounted) {
        final phone = user.phoneNumber ?? _phoneController.text.trim();
        await _completeLoginWithBackend(phone, user.uid);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingOtp = false;
        _errorMessage = _cleanFirebaseAuthErrorMessage(e);
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingOtp = false;
        _errorMessage = 'Invalid verification code. Please check and try again.';
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _completeLoginWithBackend(String phone, String uid) async {
    try {
      final customer = await ref.read(authProvider.notifier).loginWithPhoneOtp(
            phone: phone,
            firebaseUid: uid,
          );

      if (!mounted) return;

      if (customer != null) {
        final isBrandNew = customer['is_brand_new'] == true;
        final hasPassword = (customer['password']?.toString().trim().isNotEmpty ?? false);
        final isComplete = ref.read(authProvider.notifier).isProfileComplete(customer);

        Navigator.pop(context); // Close bottom sheet

        if (!isBrandNew && hasPassword && isComplete) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful! Welcome back.'),
              backgroundColor: Color(0xFF1B3624),
            ),
          );
        } else {
          // Mandatory onboarding to complete name and delivery route
          await GoogleOnboardingSheet.show(context, customer);
        }
      } else {
        setState(() {
          _isVerifyingOtp = false;
          _errorMessage = ref.read(authProvider).error ?? 'Could not initialize session.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
        });
      }
    }
  }

  String _cleanFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The phone number entered is invalid.';
      case 'quota-exceeded':
      case 'too-many-requests':
        return 'SMS quota or rate limit exceeded. Please try again in a few minutes.';
      case 'invalid-verification-code':
        return 'Incorrect 6-digit OTP code. Please try again.';
      case 'session-expired':
        return 'OTP code expired. Please tap Resend OTP.';
      case 'app-not-authorized':
        return 'Play Integrity / App verification pending. Please verify SHA certificate in Firebase.';
      default:
        return e.message ?? 'Authentication error occurred. Please try again.';
    }
  }

  Widget _buildTermsCheckbox() {
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: _termsError ? 10 : 0, vertical: _termsError ? 8 : 0),
      decoration: BoxDecoration(
        color: _termsError ? const Color(0xFFFEF2F2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: _termsError ? Border.all(color: const Color(0xFFEF4444), width: 1.5) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _agreeToTerms,
              onChanged: (val) {
                setState(() {
                  _agreeToTerms = val ?? true;
                  if (_agreeToTerms) _termsError = false;
                });
              },
              activeColor: const Color(0xFF1B3624),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'I agree to the ',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PolicyDetailScreen(policy: OrderKartPolicies.termsAndConditions),
                    ),
                  ),
                  child: Text(
                    'Terms & Conditions',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B3624),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  ' and ',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PolicyDetailScreen(policy: OrderKartPolicies.privacyPolicy),
                    ),
                  ),
                  child: Text(
                    'Privacy Policy',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B3624),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return ShakeWidget(
      key: _termsShakeKey,
      shakeOffset: 10,
      child: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 25, offset: Offset(0, -5)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF1B3624), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _step == PhoneAuthStateStep.enterPhone ? 'Mobile Number Login' : 'Enter 6-Digit OTP',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B3624),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _step == PhoneAuthStateStep.enterPhone
                            ? 'Instant & secure login with SMS verification'
                            : 'Code sent to +91 ${_phoneController.text.trim()}',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error Banner
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // STEP 1: PHONE NUMBER INPUT
            if (_step == PhoneAuthStateStep.enterPhone) ...[
              Form(
                key: _phoneFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofocus: true,
                      autofillHints: const [AutofillHints.telephoneNumber, AutofillHints.telephoneNumberNational],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: '9876543210',
                        prefixIcon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Text(
                            '+91',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF1B3624),
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      validator: (val) {
                        final digits = (val ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.isEmpty) return 'Please enter your mobile number';
                        if (digits.length != 10) return 'Please enter a valid 10-digit number';
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleSendOtp(),
                    ),
                    const SizedBox(height: 8),
                    _buildTermsCheckbox(),
                    const SizedBox(height: 8),

                    // Send OTP Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B3624),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed: _isSendingOtp ? null : () => _handleSendOtp(),
                        child: _isSendingOtp
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                'GET OTP CODE',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ]

            // STEP 2: OTP INPUT
            else if (_step == PhoneAuthStateStep.enterOtp) ...[
              Form(
                key: _otpFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '6-Digit OTP',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1B3624)),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                          icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1B3624)),
                          label: const Text('Change Number', style: TextStyle(fontSize: 12, color: Color(0xFF1B3624), fontWeight: FontWeight.bold)),
                          onPressed: () => setState(() {
                            _step = PhoneAuthStateStep.enterPhone;
                            _otpController.clear();
                            _errorMessage = null;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        hintText: '••••••',
                        hintStyle: const TextStyle(letterSpacing: 8, color: Color(0xFFCBD5E1)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      validator: (val) {
                        final digits = (val ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.length != 6) return 'Please enter 6-digit OTP';
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleVerifyOtp(),
                    ),
                    const SizedBox(height: 12),

                    // Countdown & Resend Option
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_secondsRemaining > 0)
                          Text(
                            'Resend code in ${_secondsRemaining}s',
                            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          )
                        else
                          TextButton(
                            onPressed: _isSendingOtp ? null : () => _handleSendOtp(isResend: true),
                            child: const Text(
                              'Resend OTP Code',
                              style: TextStyle(color: Color(0xFF1B3624), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B3624),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed: _isVerifyingOtp ? null : _handleVerifyOtp,
                        child: _isVerifyingOtp
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                'VERIFY & SIGN IN',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
