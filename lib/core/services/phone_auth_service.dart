import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service managing Firebase Phone Authentication (SMS OTP verification)
class PhoneAuthService {
  static final PhoneAuthService _instance = PhoneAuthService._internal();
  static PhoneAuthService get instance => _instance;

  final FirebaseAuth _auth;

  PhoneAuthService._internal({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Visible for testing to inject mock FirebaseAuth
  @visibleForTesting
  factory PhoneAuthService.withAuth(FirebaseAuth auth) => PhoneAuthService._internal(auth: auth);

  /// Formats raw 10-digit or international phone string to E.164 (+91XXXXXXXXXX by default for India)
  static String formatE164(String input, {String defaultCountryCode = '+91'}) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (input.trim().startsWith('+')) {
      return '+$digits';
    }
    if (digits.length == 10) {
      return '$defaultCountryCode$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    return '$defaultCountryCode$digits';
  }

  /// Sends a phone verification SMS with 6-digit OTP code
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? forceResendingToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    required void Function(FirebaseAuthException exception) onVerificationFailed,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final formattedPhone = formatE164(phoneNumber);
    debugPrint('PhoneAuthService: Initiating verification for $formattedPhone');

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: timeout,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) {
          debugPrint('PhoneAuthService: Verification auto-completed via Play Integrity / SMS Retriever');
          onVerificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('PhoneAuthService: Verification failed: ${e.code} - ${e.message}');
          onVerificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('PhoneAuthService: OTP Code sent. VerificationId: $verificationId');
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('PhoneAuthService: Code auto-retrieval timeout');
          onCodeAutoRetrievalTimeout(verificationId);
        },
      );
    } catch (e) {
      debugPrint('PhoneAuthService: Error triggering verifyPhoneNumber: $e');
      rethrow;
    }
  }

  /// Verifies the entered SMS code using verificationId
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final cleanCode = smsCode.trim().replaceAll(RegExp(r'\D'), '');
    debugPrint('PhoneAuthService: Verifying OTP code for verificationId: $verificationId');

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: cleanCode,
    );

    return await _auth.signInWithCredential(credential);
  }

  /// Verifies a direct PhoneAuthCredential (e.g., from auto-retrieval)
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  /// Signs out the current Firebase user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('PhoneAuthService: Sign-out notice: $e');
    }
  }

  /// Returns current Firebase user if signed in
  User? get currentUser => _auth.currentUser;
}
