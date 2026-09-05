import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

/// Server-Authoritative & Local Persistent Rate Limiting Manager
/// Rules:
/// 1. 10 failed attempts -> 1-Hour Server Lockout.
/// 2. If 1-Hour Lockout happens 8 times -> 3-Day Server Lockout.
/// 3. Server PostgreSQL auth_rate_limits table is the authoritative source.
/// 4. Survives Clear Data, App Reinstall, App Restarts, and Clock Tampering.
class AuthRateLimiter {
  AuthRateLimiter._();
  static final AuthRateLimiter instance = AuthRateLimiter._();

  static const int maxFailedAttempts = 10;
  static const int maxHourlyLockoutsBefore3Days = 8;
  static const Duration hourlyLockoutDuration = Duration(hours: 1);
  static const Duration threeDayLockoutDuration = Duration(days: 3);

  String? _sessionId;
  int _failedAttempts = 0;
  int _hourlyLockoutCount = 0;
  DateTime? _lockoutUntil;
  String _lockoutType = ''; // '1hr' or '3days'
  bool _initialized = false;

  String get sessionId => _sessionId ?? 'session_initializing';
  int get failedAttempts => _failedAttempts;
  int get remainingAttempts => (maxFailedAttempts - _failedAttempts).clamp(0, maxFailedAttempts);
  int get hourlyLockoutCount => _hourlyLockoutCount;
  DateTime? get lockoutUntil => _lockoutUntil;
  String get lockoutType => _lockoutType;

  /// Initialize security state from SQLite local storage (as an offline cache)
  Future<void> init() async {
    if (_initialized) return;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('settings');
      final Map<String, String> map = {
        for (var r in rows) (r['key'] as String): (r['value'] as String)
      };

      // 1. Session ID (persisted per installation)
      if (map.containsKey('app_session_id') && map['app_session_id']!.isNotEmpty) {
        _sessionId = map['app_session_id'];
      } else {
        _sessionId = const Uuid().v4();
        await _saveSetting(db, 'app_session_id', _sessionId!);
      }

      // 2. Failed Attempts Count
      if (map.containsKey('auth_failed_attempts')) {
        _failedAttempts = int.tryParse(map['auth_failed_attempts']!) ?? 0;
      }

      // 3. Hourly Lockout Count
      if (map.containsKey('auth_hourly_lockout_count')) {
        _hourlyLockoutCount = int.tryParse(map['auth_hourly_lockout_count']!) ?? 0;
      }

      // 4. Lockout Type
      _lockoutType = map['auth_lockout_type'] ?? '';

      // 5. Lockout Timestamp
      if (map.containsKey('auth_lockout_until') && map['auth_lockout_until']!.isNotEmpty) {
        final parsed = DateTime.tryParse(map['auth_lockout_until']!);
        if (parsed != null && DateTime.now().isBefore(parsed)) {
          _lockoutUntil = parsed;
        } else {
          _lockoutUntil = null;
          _lockoutType = '';
          await _saveSetting(db, 'auth_lockout_until', '');
          await _saveSetting(db, 'auth_lockout_type', '');
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[AuthRateLimiter] Init error: $e');
    }
  }

  /// Check server authoritative lockout for a specific customer identifier (code/phone)
  Future<Map<String, dynamic>> checkServerLockout(String identifier) async {
    final normId = identifier.trim().toUpperCase();
    if (normId.isEmpty) {
      return {'is_locked': false, 'remaining_attempts': maxFailedAttempts};
    }

    try {
      final client = Supabase.instance.client;
      final res = await client.rpc('check_auth_lockout', params: {
        'p_identifier': normId,
      }).timeout(const Duration(seconds: 4));

      if (res != null && res is Map) {
        final isLocked = res['is_locked'] == true;
        if (isLocked) {
          final untilStr = res['locked_until'] as String?;
          final remainingSecs = (res['remaining_seconds'] as num?)?.toInt() ?? 3600;
          _lockoutUntil = untilStr != null
              ? DateTime.tryParse(untilStr) ?? DateTime.now().add(Duration(seconds: remainingSecs))
              : DateTime.now().add(Duration(seconds: remainingSecs));
          _lockoutType = res['lockout_type'] as String? ?? '1hr';
          await _persistState();
        } else {
          _failedAttempts = (res['failed_attempts'] as num?)?.toInt() ?? 0;
          if (_lockoutUntil != null && isLockedOut()) {
            _lockoutUntil = null;
            _lockoutType = '';
            await _persistState();
          }
        }
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('[AuthRateLimiter] Server lockout check fallback: $e');
    }

    return {
      'is_locked': isLockedOut(),
      'remaining_attempts': remainingAttempts,
      'locked_until': _lockoutUntil?.toIso8601String(),
    };
  }

  /// Check if login is currently locked out (local check with server sync)
  bool isLockedOut() {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isBefore(_lockoutUntil!)) {
      return true;
    } else {
      _lockoutUntil = null;
      _lockoutType = '';
      _clearLockoutInDb();
      return false;
    }
  }

  /// Get remaining lockout duration
  Duration get remainingLockoutDuration {
    if (_lockoutUntil == null) return Duration.zero;
    final diff = _lockoutUntil!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Formatted human-readable remaining time
  String get formattedRemainingTime {
    final d = remainingLockoutDuration;
    if (d <= Duration.zero) return '0s';

    if (d.inDays > 0) {
      final hours = d.inHours % 24;
      final minutes = d.inMinutes % 60;
      return '${d.inDays}d ${hours}h ${minutes}m';
    } else if (d.inHours > 0) {
      final minutes = d.inMinutes % 60;
      final seconds = d.inSeconds % 60;
      return '${d.inHours}h ${minutes}m ${seconds}s';
    } else if (d.inMinutes > 0) {
      final seconds = d.inSeconds % 60;
      return '${d.inMinutes}m ${seconds}s';
    } else {
      return '${d.inSeconds}s';
    }
  }

  /// Human-readable lockout banner error message
  String getLockoutErrorMessage() {
    if (!isLockedOut()) return '';
    if (_lockoutType == '3days') {
      return 'Account locked for 3 days due to 8 repeated 1-hour lockouts.\nTry again in $formattedRemainingTime.';
    } else {
      return 'Too many failed attempts ($maxFailedAttempts/$maxFailedAttempts).\nAccount locked for 1 hour. Try again in $formattedRemainingTime.';
    }
  }

  /// Record a failed login attempt authoritatively on server and persist locally
  Future<String> recordFailedAttempt({String? identifier}) async {
    await init();
    final normId = (identifier ?? '').trim().toUpperCase();

    if (normId.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        final res = await client.rpc('record_auth_failure', params: {
          'p_identifier': normId,
        }).timeout(const Duration(seconds: 4));

        if (res != null && res is Map) {
          final isLocked = res['is_locked'] == true;
          if (isLocked) {
            final untilStr = res['locked_until'] as String?;
            final remainingSecs = (res['remaining_seconds'] as num?)?.toInt() ?? 3600;
            _lockoutUntil = untilStr != null
                ? DateTime.tryParse(untilStr) ?? DateTime.now().add(Duration(seconds: remainingSecs))
                : DateTime.now().add(Duration(seconds: remainingSecs));
            _lockoutType = res['lockout_type'] as String? ?? '1hr';
            _failedAttempts = 0;
            await _persistState();
            return res['message'] as String? ?? getLockoutErrorMessage();
          } else {
            _failedAttempts = (res['failed_attempts'] as num?)?.toInt() ?? (_failedAttempts + 1);
            await _persistState();
            return res['message'] as String? ?? 'Invalid credentials. $remainingAttempts attempts remaining before 1-hour lockout.';
          }
        }
      } catch (e) {
        debugPrint('[AuthRateLimiter] Server record failure error: $e');
      }
    }

    // Local fallback if network fails
    _failedAttempts++;
    String message;
    if (_failedAttempts >= maxFailedAttempts) {
      _hourlyLockoutCount++;
      _failedAttempts = 0;
      if (_hourlyLockoutCount >= maxHourlyLockoutsBefore3Days) {
        _lockoutUntil = DateTime.now().add(threeDayLockoutDuration);
        _lockoutType = '3days';
        _hourlyLockoutCount = 0;
        message = 'Account locked for 3 days due to 8 repeated 1-hour lockouts.';
      } else {
        _lockoutUntil = DateTime.now().add(hourlyLockoutDuration);
        _lockoutType = '1hr';
        message = 'Account locked for 1 hour due to $maxFailedAttempts failed attempts.';
      }
    } else {
      final remaining = maxFailedAttempts - _failedAttempts;
      message = 'Invalid credentials. $remaining attempts remaining before 1-hour lockout.';
    }

    await _persistState();
    return message;
  }

  /// Record a successful login authoritatively on server and clear local state
  Future<void> recordSuccessfulLogin({String? identifier}) async {
    await init();
    _failedAttempts = 0;
    _hourlyLockoutCount = 0;
    _lockoutUntil = null;
    _lockoutType = '';
    await _persistState();

    final normId = (identifier ?? '').trim().toUpperCase();
    if (normId.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        await client.rpc('record_auth_success', params: {
          'p_identifier': normId,
        }).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[AuthRateLimiter] Server record success error: $e');
      }
    }
  }

  Future<void> _persistState() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await _saveSetting(db, 'auth_failed_attempts', _failedAttempts.toString());
      await _saveSetting(db, 'auth_hourly_lockout_count', _hourlyLockoutCount.toString());
      await _saveSetting(db, 'auth_lockout_until', _lockoutUntil?.toIso8601String() ?? '');
      await _saveSetting(db, 'auth_lockout_type', _lockoutType);
    } catch (e) {
      debugPrint('[AuthRateLimiter] Persist error: $e');
    }
  }

  Future<void> _clearLockoutInDb() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await _saveSetting(db, 'auth_lockout_until', '');
      await _saveSetting(db, 'auth_lockout_type', '');
    } catch (_) {}
  }

  Future<void> _saveSetting(Database db, String key, String value) async {
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
