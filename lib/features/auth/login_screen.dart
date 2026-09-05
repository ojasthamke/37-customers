import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_provider.dart';
import 'password_rules_helper.dart';
import '../dashboard/home_screen.dart';
import '../profile/legal/policy_models.dart';
import '../profile/legal/policy_detail_screen.dart';
import '../../core/services/auth_rate_limiter.dart';
import '../../core/widgets/shake_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_screen.dart';
import 'google_onboarding_sheet.dart';

// ============================================================
// MAIN LOGIN SCREEN WITH SELECTION PANEL (LOGIN & SETUP MODES)
// ============================================================
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _termsShakeKeyLogin = GlobalKey<ShakeWidgetState>();
  bool _obscurePassword = true;
  bool _acceptTermsLogin = false;
  bool _termsErrorLogin = false;

  // Setup Password Mode
  final _setupFormKey = GlobalKey<FormState>();
  final _setupCodeController = TextEditingController();
  final _setupPasswordController = TextEditingController();
  final _setupConfirmPasswordController = TextEditingController();
  final _termsShakeKeySetup = GlobalKey<ShakeWidgetState>();
  bool _setupObscurePassword = true;
  bool _setupObscureConfirmPassword = true;
  bool _isSettingUp = false;
  bool _acceptTermsSetup = false;
  bool _termsErrorSetup = false;


  String? _selectedOption; // null = selector, 'login' = login form, 'setup' = setup password form
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Live countdown timer for active lockouts
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && AuthRateLimiter.instance.isLockedOut()) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    _passwordController.dispose();
    _setupCodeController.dispose();
    _setupPasswordController.dispose();
    _setupConfirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final code = _codeController.text.trim();
    if (code.isNotEmpty) {
      await AuthRateLimiter.instance.checkServerLockout(code);
      if (!mounted) return;
    }
    if (AuthRateLimiter.instance.isLockedOut()) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthRateLimiter.instance.getLockoutErrorMessage()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_acceptTermsLogin) {
      _termsShakeKeyLogin.currentState?.shake();
      setState(() => _termsErrorLogin = true);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Please accept the Terms & Conditions and Privacy Policy to continue.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final success = await ref.read(authProvider.notifier).loginWithCodeAndPassword(
            _codeController.text.trim(),
            _passwordController.text,
          );

      if (!mounted) return;

      if (success) {
        TextInput.finishAutofillContext(shouldSave: true);
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful! Welcome back.')),
        );
      } else {
        final err = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Login failed. Please check your credentials.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final customer = await ref.read(authProvider.notifier).loginWithGoogle();
      if (!mounted) return;

      if (customer != null) {
        final isBrandNew = customer['is_brand_new'] == true;
        final hasPassword = (customer['password']?.toString().trim().isNotEmpty ?? false);
        final isComplete = ref.read(authProvider.notifier).isProfileComplete(customer);

        if (!isBrandNew && hasPassword && isComplete) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful! Welcome back.'),
              backgroundColor: Color(0xFF1B3624),
            ),
          );
        } else {
          // Mandatory onboarding: generates 7-character code, displays glassmorphism card, and sets up password
          await GoogleOnboardingSheet.show(context, customer);
        }
      }
    } catch (e) {
      if (mounted) {
        final cleanErr = e.toString().replaceAll('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanErr.isNotEmpty ? cleanErr : 'Google Sign-In failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _submitSetup() async {
    final setupCode = _setupCodeController.text.trim();
    if (setupCode.isNotEmpty) {
      await AuthRateLimiter.instance.checkServerLockout(setupCode);
      if (!mounted) return;
    }
    if (AuthRateLimiter.instance.isLockedOut()) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthRateLimiter.instance.getLockoutErrorMessage()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_acceptTermsSetup) {
      _termsShakeKeySetup.currentState?.shake();
      setState(() => _termsErrorSetup = true);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Please accept the Terms & Conditions and Privacy Policy to create your password.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }


    if (_setupFormKey.currentState!.validate()) {
      setState(() => _isSettingUp = true);
      final code = _setupCodeController.text.trim().toUpperCase();

      // Step 1: Pre-check if customer already has a password set on backend
      final authStatus = await ref.read(authProvider.notifier).checkCustomerAuthStatus(code);

      if (!mounted) return;

      if (authStatus['has_password'] == true) {
        setState(() => _isSettingUp = false);
        _showAlreadyHavePasswordModal(code);
        return;
      }

      if (authStatus['exists'] == false) {
        setState(() => _isSettingUp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authStatus['message'] ?? 'Customer Code "$code" not found. Please contact the store team.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Step 2: Customer has no password yet -> proceed to setup password
      final canonicalCode = (authStatus['customer_code'] as String? ?? '').trim().isNotEmpty
          ? (authStatus['customer_code'] as String).trim()
          : code;
      final success = await ref.read(authProvider.notifier).setupPassword(
            canonicalCode,
            authStatus['name'] ?? '',
            _setupPasswordController.text,
          );

      if (!mounted) return;
      setState(() => _isSettingUp = false);

      if (success) {
        TextInput.finishAutofillContext(shouldSave: true);
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password set successfully! Welcome to Orderkart.')),
        );
      } else {
        final err = ref.read(authProvider).error;
        if (err != null && (err.toLowerCase().contains('already have a password') || err.toLowerCase().contains('already claimed') || err.toLowerCase().contains('already set') || err.toLowerCase().contains('already created'))) {
          _showAlreadyHavePasswordModal(code);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err ?? 'Setup failed. Please check your Customer Code.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAlreadyHavePasswordModal(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Password Already Created',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B3624),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your password has already been created for Customer Code: $code.\n\nPlease use your existing password to log in, or use Reset Password if you want to change it.',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B3624),
                          side: const BorderSide(color: Color(0xFF1B3624), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedOption = 'login';
                          });
                        },
                        child: const Text('Go to Login', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B3624),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ResetPasswordScreen(initialCode: code),
                            ),
                          );
                        },
                        child: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTermsCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    GlobalKey<ShakeWidgetState>? shakeKey,
    bool hasError = false,
  }) {
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: hasError ? 10 : 0, vertical: hasError ? 8 : 0),
      decoration: BoxDecoration(
        color: hasError ? const Color(0xFFFEF2F2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: hasError
            ? Border.all(color: const Color(0xFFEF4444), width: 1.5)
            : null,
        boxShadow: hasError
            ? [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF1B3624),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              side: hasError
                  ? const BorderSide(color: Color(0xFFEF4444), width: 1.8)
                  : const BorderSide(color: Color(0xFF64748B), width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'I agree to OrderKart\'s ',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: hasError ? const Color(0xFF991B1B) : const Color(0xFF475569),
                    fontWeight: hasError ? FontWeight.w600 : FontWeight.normal,
                  ),
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
                      color: hasError ? const Color(0xFFB91C1C) : const Color(0xFF1B3624),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  ' and ',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: hasError ? const Color(0xFF991B1B) : const Color(0xFF475569),
                    fontWeight: hasError ? FontWeight.w600 : FontWeight.normal,
                  ),
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
                      color: hasError ? const Color(0xFFB91C1C) : const Color(0xFF1B3624),
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

    if (shakeKey != null) {
      return ShakeWidget(
        key: shakeKey,
        shakeOffset: 12.0,
        shakeCount: 4,
        duration: const Duration(milliseconds: 500),
        child: body,
      );
    }
    return body;
  }


  void _showContactStoreResetPassword() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Contact Support',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B3624),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'To reset your account password, please contact the store team directly via WhatsApp or phone call at +91 9021107009.',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final msg = Uri.encodeComponent('Hello Orderkart Support! I need assistance to reset my password.');
                          final whatsappUrls = [
                            'https://wa.me/919021107009?text=$msg',
                            'https://api.whatsapp.com/send?phone=919021107009&text=$msg',
                            'whatsapp://send?phone=919021107009&text=$msg',
                          ];
                          bool launched = false;
                          for (final urlStr in whatsappUrls) {
                            try {
                              final uri = Uri.parse(urlStr);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                launched = true;
                                break;
                              }
                            } catch (_) {}
                          }
                          if (!launched) {
                            try {
                              await launchUrl(Uri.parse(whatsappUrls[0]), mode: LaunchMode.externalApplication);
                            } catch (_) {}
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B3624),
                          side: const BorderSide(color: Color(0xFF1B3624), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final telUri = Uri.parse('tel:+919021107009');
                          try {
                            if (await canLaunchUrl(telUri)) {
                              await launchUrl(telUri);
                            } else {
                              await launchUrl(telUri, mode: LaunchMode.externalNonBrowserApplication);
                            }
                          } catch (_) {
                            try {
                              await launchUrl(Uri.parse('tel:9021107009'));
                            } catch (_) {}
                          }
                        },
                        icon: const Icon(Icons.phone_outlined, size: 20),
                        label: const Text('Call Store', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Store Helpline: +91 9021107009',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B3624),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/orderkart_logo.png',
                width: 280,
                height: 160,
                cacheWidth: 560,
                cacheHeight: 320,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 24),

              // CASE 1: OPTION SELECTION SCREEN
              if (_selectedOption == null) ...[
                Text(
                  'Choose Your Account Status',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B3624),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Have you set up your password yet?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Option A: Yes, I have password
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOption = 'login';
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B3624),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B3624).withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_open_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'I have created my password',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sign in with your Customer Code and Password',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                
                // Option B: No, I don't have password
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOption = 'setup';
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_reset_rounded, color: Color(0xFF1B3624), size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'I have NOT created my password yet',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1B3624),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Setup a new password using your Customer Code',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Option C: New Customer? Create Account
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F5EE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.7), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B3624).withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF1B3624), size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Customer? Create Account',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1B3624),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Register with your delivery area and route',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF1B3624), size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Option D: Continue with Google
                InkWell(
                  onTap: _handleGoogleSignIn,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Continue with Google',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Quick sign-in with your Google account',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Guest option
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GuestLoginScreen()),
                    );
                  },
                  child: Text(
                    'Continue as Guest',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ]

              // CASE 2: SIGN IN MODE
              else if (_selectedOption == 'login') ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: AutofillGroup(
                      onDisposeAction: AutofillContextAction.commit,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1B3624), size: 18),
                                onPressed: () => setState(() => _selectedOption = null),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Welcome Back',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1B3624),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in with your Customer Code & Password',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Lockout Banner or Attempts Remaining Warning
                          if (AuthRateLimiter.instance.isLockedOut()) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.lock_clock_outlined, color: Color(0xFFDC2626), size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        AuthRateLimiter.instance.lockoutType == '3days'
                                            ? 'Account Locked (3 Days)'
                                            : 'Account Locked (1 Hour)',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    AuthRateLimiter.instance.lockoutType == '3days'
                                        ? 'Locked due to 8 repeated 1-hour penalties.\nUnlock in: ${AuthRateLimiter.instance.formattedRemainingTime}'
                                        : 'Locked due to 10 failed login attempts.\nUnlock in: ${AuthRateLimiter.instance.formattedRemainingTime}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: _showContactStoreResetPassword,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFFDC2626)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Need urgent help? Contact Store',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFDC2626),
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (AuthRateLimiter.instance.failedAttempts > 0) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${AuthRateLimiter.instance.failedAttempts} of 10 attempts remaining before 1-hour lockout.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Customer Code
                          TextFormField(
                            controller: _codeController,
                            autofillHints: const [AutofillHints.username, AutofillHints.telephoneNumber, AutofillHints.email],
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            enabled: !AuthRateLimiter.instance.isLockedOut(),
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Customer Code',
                              prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20, color: Color(0xFF1B3624)),
                              hintText: 'e.g. OK1025',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your customer code';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            autofillHints: const [AutofillHints.password],
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            enabled: !AuthRateLimiter.instance.isLockedOut(),
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF1B3624)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ResetPasswordScreen(
                                      initialCode: _codeController.text.trim(),
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              ),
                              child: const Text(
                                'Forgot / Reset Password?',
                                style: TextStyle(
                                  color: Color(0xFF1B3624),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          _buildTermsCheckbox(
                            value: _acceptTermsLogin,
                            shakeKey: _termsShakeKeyLogin,
                            hasError: _termsErrorLogin && !_acceptTermsLogin,
                            onChanged: (val) {
                              setState(() {
                                _acceptTermsLogin = val ?? false;
                                if (_acceptTermsLogin) _termsErrorLogin = false;
                              });
                            },
                          ),


                          // Sign In Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AuthRateLimiter.instance.isLockedOut()
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF1B3624),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: AuthRateLimiter.instance.isLockedOut() ? 0 : 4,
                              ),
                              onPressed: (authState.isLoading || AuthRateLimiter.instance.isLockedOut()) ? null : _submit,
                              child: authState.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Text(
                                      AuthRateLimiter.instance.isLockedOut()
                                          ? 'LOCKED (${AuthRateLimiter.instance.formattedRemainingTime})'
                                          : 'SIGN IN',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _handleGoogleSignIn,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFF1F5F9),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF4285F4),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Continue with Google',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]

              // CASE 3: SETUP PASSWORD MODE
              else if (_selectedOption == 'setup') ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: AutofillGroup(
                      onDisposeAction: AutofillContextAction.commit,
                      child: Form(
                        key: _setupFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1B3624), size: 18),
                                onPressed: () => setState(() => _selectedOption = null),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Setup Password',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1B3624),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your Customer Code and choose a new password.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Customer Code
                          TextFormField(
                            controller: _setupCodeController,
                            autofillHints: const [AutofillHints.username, AutofillHints.telephoneNumber, AutofillHints.email],
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            enabled: !_isSettingUp,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Customer Code',
                              prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20, color: Color(0xFF1B3624)),
                              hintText: 'e.g. OK1025',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your Customer Code';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextFormField(
                            controller: _setupPasswordController,
                            autofillHints: const [AutofillHints.newPassword],
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.next,
                            enabled: !_isSettingUp,
                            obscureText: _setupObscurePassword,
                            onChanged: (val) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF1B3624)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _setupObscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () => setState(() => _setupObscurePassword = !_setupObscurePassword),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (!PasswordRulesHelper.isPasswordStrong(val)) {
                                return 'Password does not meet strength requirements';
                              }
                              return null;
                            },
                          ),
                          PasswordRulesHelper(password: _setupPasswordController.text),
                          const SizedBox(height: 14),

                          // Confirm Password
                          TextFormField(
                            controller: _setupConfirmPasswordController,
                            autofillHints: const [AutofillHints.newPassword],
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            enabled: !_isSettingUp,
                            obscureText: _setupObscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20, color: Color(0xFF1B3624)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _setupObscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () => setState(() => _setupObscureConfirmPassword = !_setupObscureConfirmPassword),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            validator: (val) {
                              if (val != _setupPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submitSetup(),
                          ),

                          _buildTermsCheckbox(
                            value: _acceptTermsSetup,
                            shakeKey: _termsShakeKeySetup,
                            hasError: _termsErrorSetup && !_acceptTermsSetup,
                            onChanged: (val) {
                              setState(() {
                                _acceptTermsSetup = val ?? false;
                                if (_acceptTermsSetup) _termsErrorSetup = false;
                              });
                            },
                          ),


                          // Setup Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B3624),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              onPressed: _isSettingUp ? null : _submitSetup,
                              child: _isSettingUp
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text(
                                      'CREATE PASSWORD',
                                      style: TextStyle(
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
                  ),
                ),
              ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// GUEST LOGIN SCREEN
// ============================================================
class GuestLoginScreen extends ConsumerStatefulWidget {
  const GuestLoginScreen({super.key});

  @override
  ConsumerState<GuestLoginScreen> createState() => _GuestLoginScreenState();
}

class _GuestLoginScreenState extends ConsumerState<GuestLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _termsShakeKeyGuest = GlobalKey<ShakeWidgetState>();
  bool _acceptTermsGuest = false;
  bool _termsErrorGuest = false;

  List<Map<String, dynamic>> _areas = [];
  String? _selectedAreaId;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  void _loadAreas() async {
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('areas')
          .select('id, name, area_code, delivery_schedule, cutoff_time')
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
          _areas = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('GuestLogin: Failed to load areas: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_acceptTermsGuest) {
      _termsShakeKeyGuest.currentState?.shake();
      setState(() => _termsErrorGuest = true);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Please accept the Terms & Conditions and Privacy Policy to continue.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your delivery Area.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final digits = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      String address = _addressController.text.trim();
      if (address.isEmpty || address.toUpperCase() == 'N/A') {
        final areaObj = _areas.firstWhere((a) => a['id'] == _selectedAreaId, orElse: () => <String, dynamic>{});
        final aName = (areaObj['name'] as String? ?? '').trim();
        address = aName;
      }

      final success = await ref.read(authProvider.notifier).registerGuest(
            name: _nameController.text.trim(),
            phone: digits,
            address: address,
            areaId: _selectedAreaId,
            roadId: null,
            subRoadId: null,
          );

      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome! You are logged in as a Guest.')),
        );
      } else {
        final err = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Registration failed. The phone number may already be in use.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/919021107009?text=Hi%20Orderkart%20Support!%20I%20want%20to%20become%20a%20member.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openCall() async {
    final telUri = Uri.parse('tel:+919021107009');
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        await launchUrl(telUri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (_) {
      try {
        await launchUrl(Uri.parse('tel:9021107009'));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Guest Login',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B3624),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1B3624), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              // Support notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Contact support to become a member',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF57F17),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openWhatsApp,
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF25D366)),
                            label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF25D366),
                              side: const BorderSide(color: Color(0xFF25D366)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openCall,
                            icon: const Icon(Icons.call, size: 16, color: Color(0xFF1B3624)),
                            label: const Text('Call', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1B3624),
                              side: const BorderSide(color: Color(0xFF1B3624)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Guest Form
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guest Registration',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B3624),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter your details to continue as a guest',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF1B3624)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone Number
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          maxLength: 10,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF1B3624)),
                            hintText: 'Enter 10-digit number',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your phone number';
                            }
                            final digits = val.trim().replaceAll(RegExp(r'\D'), '');
                            if (digits.length != 10) {
                              return 'Phone number must be exactly 10 digits';
                            }
                            if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                              return 'Enter a valid 10-digit phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Area Dropdown (Road selection is omitted)
                        DropdownButtonFormField<String>(
                          value: _selectedAreaId,
                          decoration: InputDecoration(
                            labelText: 'Select Delivery Area',
                            prefixIcon: const Icon(Icons.map_outlined, color: Color(0xFF1B3624)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          hint: const Text('Select Delivery Area'),
                          items: _areas.map((a) {
                            return DropdownMenuItem<String>(
                              value: a['id']?.toString() ?? '',
                              child: Text(a['name']?.toString() ?? ''),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedAreaId = val;
                              });
                            }
                          },
                          validator: (val) => val == null ? 'Please select an area' : null,
                        ),
                        const SizedBox(height: 16),

                        // Address
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Delivery Address',
                            prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF1B3624)),
                            hintText: 'e.g. Flat 302, Green Heights',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          maxLines: 2,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your delivery address';
                            }
                            return null;
                          },
                        ),
                        ShakeWidget(
                          key: _termsShakeKeyGuest,
                          shakeOffset: 12.0,
                          shakeCount: 4,
                          duration: const Duration(milliseconds: 500),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(top: 12, bottom: 16),
                            padding: EdgeInsets.symmetric(
                              horizontal: (_termsErrorGuest && !_acceptTermsGuest) ? 10 : 0,
                              vertical: (_termsErrorGuest && !_acceptTermsGuest) ? 8 : 0,
                            ),
                            decoration: BoxDecoration(
                              color: (_termsErrorGuest && !_acceptTermsGuest) ? const Color(0xFFFEF2F2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: (_termsErrorGuest && !_acceptTermsGuest)
                                  ? Border.all(color: const Color(0xFFEF4444), width: 1.5)
                                  : null,
                              boxShadow: (_termsErrorGuest && !_acceptTermsGuest)
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _acceptTermsGuest,
                                    onChanged: (val) {
                                      setState(() {
                                        _acceptTermsGuest = val ?? false;
                                        if (_acceptTermsGuest) _termsErrorGuest = false;
                                      });
                                    },
                                    activeColor: const Color(0xFF1B3624),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    side: (_termsErrorGuest && !_acceptTermsGuest)
                                        ? const BorderSide(color: Color(0xFFEF4444), width: 1.8)
                                        : const BorderSide(color: Color(0xFF64748B), width: 1.5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'I agree to OrderKart\'s ',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: (_termsErrorGuest && !_acceptTermsGuest)
                                              ? const Color(0xFF991B1B)
                                              : const Color(0xFF475569),
                                          fontWeight: (_termsErrorGuest && !_acceptTermsGuest) ? FontWeight.w600 : FontWeight.normal,
                                        ),
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
                                            color: (_termsErrorGuest && !_acceptTermsGuest)
                                                ? const Color(0xFFB91C1C)
                                                : const Color(0xFF1B3624),
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ' and ',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: (_termsErrorGuest && !_acceptTermsGuest)
                                              ? const Color(0xFF991B1B)
                                              : const Color(0xFF475569),
                                          fontWeight: (_termsErrorGuest && !_acceptTermsGuest) ? FontWeight.w600 : FontWeight.normal,
                                        ),
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
                                            color: (_termsErrorGuest && !_acceptTermsGuest)
                                                ? const Color(0xFFB91C1C)
                                                : const Color(0xFF1B3624),
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),


                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B3624),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            onPressed: authState.isLoading ? null : _submit,
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'CONTINUE AS GUEST',
                                    style: TextStyle(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RESET PASSWORD SCREEN (WhatsApp Only help)
// ============================================================
class ResetPasswordScreen extends StatefulWidget {
  final String? initialCode;

  const ResetPasswordScreen({super.key, this.initialCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  void _openStoreWhatsApp() async {
    final code = widget.initialCode ?? '';
    final codePart = code.isNotEmpty ? " (Customer Code: $code)" : "";
    final msg = Uri.encodeComponent('I forgot my password, please reset it$codePart');
    final whatsappUrls = [
      'https://wa.me/919021107009?text=$msg',
      'https://api.whatsapp.com/send?phone=919021107009&text=$msg',
      'whatsapp://send?phone=919021107009&text=$msg',
    ];
    for (final urlStr in whatsappUrls) {
      try {
        final uri = Uri.parse(urlStr);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Need Help',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B3624),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1B3624), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 36.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 64,
                      color: Color(0xFF25D366),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Need Help?',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B3624),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'If you forgot your password, please contact the store team directly via WhatsApp to reset it.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF475569),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _openStoreWhatsApp,
                      icon: const Icon(Icons.chat_bubble_rounded, size: 24),
                      label: const Text(
                        'CONTACT SUPPORT',
                        style: TextStyle(
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
          ),
        ),
      ),
    );
  }
}
