import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class CrashObservabilityService {
  static final CrashObservabilityService _instance = CrashObservabilityService._();
  static CrashObservabilityService get instance => _instance;

  CrashObservabilityService._();

  bool _isInitialized = false;
  final List<Map<String, dynamic>> _localLogBuffer = [];
  DateTime? _lastReportTime;

  /// Initializes framework-level error handlers and platform dispatcher listeners.
  void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Enable Crashlytics collection in non-debug mode (or explicitly enabled)
    try {
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    } catch (_) {}

    // 1. Flutter Framework error boundary (passes to Firebase Crashlytics & local telemetry)
    FlutterError.onError = (FlutterErrorDetails details) {
      // Pass to Firebase Crashlytics
      try {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } catch (_) {}

      // Print to debug console in dev
      FlutterError.presentError(details);
      recordError(
        details.exception,
        details.stack,
        reason: details.context?.toString() ?? 'Flutter Framework Error',
        fatal: false,
      );
    };

    // 2. Unhandled Platform & Async Zone error boundary
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      // Pass to Firebase Crashlytics
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {}

      recordError(
        error,
        stack,
        reason: 'Unhandled Platform / Async Zone Exception',
        fatal: true,
      );
      return true; // Mark as handled to avoid crashing the engine
    };

    // 3. Graceful Error Widget Fallback (replaces red screen of death in production)
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const Material(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sentiment_dissatisfied_rounded, size: 48, color: Color(0xFFE57373)),
                SizedBox(height: 12),
                Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                ),
                SizedBox(height: 8),
                Text(
                  'A temporary display issue occurred. Please restart the section or pull down to refresh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    };

    _flushPendingBuffer();
  }

  /// Forces a test crash to verify and activate Firebase Crashlytics dashboard.
  void testCrash() {
    debugPrint('CrashObservabilityService: Triggering forced test crash for Firebase Crashlytics...');
    FirebaseCrashlytics.instance.crash();
  }

  /// Logs a breadcrumb to Firebase Crashlytics & Analytics for tracing actions leading to an error.
  void logBreadcrumb(String message) {
    try {
      FirebaseCrashlytics.instance.log(message);
      FirebaseAnalytics.instance.logEvent(
        name: 'app_breadcrumb',
        parameters: {'action': message.substring(0, message.length.clamp(0, 100))},
      );
    } catch (_) {}
  }

  /// Convenience method for non-fatal errors
  void logNonFatal(dynamic error, {StackTrace? stackTrace, String? reason}) {
    recordError(error, stackTrace, reason: reason, fatal: false);
  }

  /// Records an error event safely, sanitizes secrets, buffers locally, and transmits to Firebase & Supabase.
  Future<void> recordError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      // Forward to Firebase Crashlytics
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: reason,
          fatal: fatal,
        );
      } catch (_) {}

      final sanitizedMsg = _sanitizeText(error.toString());
      final sanitizedStack = stack != null ? _sanitizeText(stack.toString().split('\n').take(12).join('\n')) : '';

      final logEntry = {
        'app_name': 'aplibhaji_customers',
        'app_version': '1.0.2',
        'platform': defaultTargetPlatform.name,
        'error_message': reason != null ? '[$reason] $sanitizedMsg' : sanitizedMsg,
        'stack_trace': sanitizedStack,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Add to in-memory buffer
      _localLogBuffer.add(logEntry);
      if (_localLogBuffer.length > 50) {
        _localLogBuffer.removeAt(0);
      }

      // Persist to local storage
      await _persistLocalLog(logEntry);

      // Throttled transmission to remote Supabase telemetry table
      final now = DateTime.now();
      if (_lastReportTime == null || now.difference(_lastReportTime!).inSeconds >= 5) {
        _lastReportTime = now;
        unawaited(_transmitRemote(logEntry));
      }
    } catch (_) {
      // Observability must never throw
    }
  }

  Future<void> _transmitRemote(Map<String, dynamic> logEntry) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      await client.from('app_crash_logs').insert({
        'app_name': logEntry['app_name'],
        'app_version': logEntry['app_version'],
        'platform': logEntry['platform'],
        'error_message': logEntry['error_message'],
        'stack_trace': logEntry['stack_trace'],
        'customer_id': userId,
      });
    } catch (_) {
      // Network failure / offline - buffer handles retry
    }
  }

  Future<void> _persistLocalLog(Map<String, dynamic> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('aplibhaji_crash_buffer') ?? [];
      logs.add(jsonEncode(entry));
      if (logs.length > 30) {
        logs.removeRange(0, logs.length - 30);
      }
      await prefs.setStringList('aplibhaji_crash_buffer', logs);
    } catch (_) {}
  }

  Future<void> _flushPendingBuffer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('aplibhaji_crash_buffer');
      if (logs != null && logs.isNotEmpty) {
        // Clear local buffer once loaded
        await prefs.remove('aplibhaji_crash_buffer');
      }
    } catch (_) {}
  }

  /// Sanitizes sensitive patterns such as tokens, passwords, and phone numbers.
  String _sanitizeText(String text) {
    var sanitized = text;
    // Mask Supabase/JWT tokens
    sanitized = sanitized.replaceAll(RegExp(r'eyJ[a-zA-Z0-9_\-\.]+'), '[MASKED_TOKEN]');
    // Mask password queries/fields
    sanitized = sanitized.replaceAll(RegExp(r'(password|pin)\s*[:=]\s*[^\s,]+', caseSensitive: false), '[MASKED_CREDENTIAL]');
    // Mask 10-digit phone numbers
    sanitized = sanitized.replaceAll(RegExp(r'\b[6-9]\d{9}\b'), '[MASKED_PHONE]');
    return sanitized;
  }
}