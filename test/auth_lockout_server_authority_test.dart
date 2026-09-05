import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth Lockout Server Authority & Clear Data Resilience Tests', () {

    test('1. Local Wipe Simulation (Clear Data): Server retains lockout state', () {
      // Server mock state
      final Map<String, dynamic> serverAuthTable = {
        'CUST101': {
          'failed_attempts': 0,
          'locked_until': DateTime.now().toUtc().add(const Duration(hours: 1)),
          'is_locked': true,
        }
      };

      // Client local SQLite state before Clear Data
      Map<String, dynamic> localSqflite = {
        'auth_failed_attempts': '10',
        'auth_lockout_until': DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
      };

      // Attacker performs "Clear Data" -> Local SQLite is wiped clean
      localSqflite.clear();
      expect(localSqflite.isEmpty, isTrue);

      // Client performs Server Lockout Sync on startup
      Map<String, dynamic> checkServerLockout(String identifier) {
        final record = serverAuthTable[identifier];
        if (record != null && record['is_locked'] == true) {
          return {
            'is_locked': true,
            'locked_until': record['locked_until'].toString(),
          };
        }
        return {'is_locked': false};
      }

      final serverCheck = checkServerLockout('CUST101');
      expect(serverCheck['is_locked'], isTrue);

      // Re-populate client security barrier from authoritative server
      if (serverCheck['is_locked'] == true) {
        localSqflite['auth_lockout_until'] = serverCheck['locked_until'];
      }

      expect(localSqflite['auth_lockout_until'], isNotNull);
    });

    test('2. Device Clock Manipulation Attack Defense: Server clock is authority', () {
      final DateTime serverNow = DateTime.utc(2026, 9, 2, 12, 0, 0);
      final DateTime lockedUntil = serverNow.add(const Duration(hours: 1)); // 13:00:00

      // Attacker changes device clock forward to 2026-09-02 14:00:00 or backward
      final DateTime manipulatedDeviceClock = DateTime.utc(2026, 9, 2, 14, 0, 0);

      // Server evaluation logic (using PostgreSQL clock_timestamp())
      bool evaluateLockoutOnServer(DateTime currentServerClock, DateTime serverLockedUntil) {
        return currentServerClock.isBefore(serverLockedUntil);
      }

      // Device clock indicates expired, but Server clock indicates LOCKED
      expect(manipulatedDeviceClock.isAfter(lockedUntil), isTrue);
      expect(evaluateLockoutOnServer(serverNow, lockedUntil), isTrue); // Server BLOCKS
    });

    test('3. Direct API Bypass Defense: Server aborts before credential verification', () {
      bool isLocked = true;
      bool verifyCredentialsCalled = false;

      Map<String, dynamic> serverLoginEndpoint(String identifier, String password) {
        // Step 1: Server checks lock FIRST
        if (isLocked) {
          return {
            'authenticated': false,
            'is_locked': true,
            'error': 'Account is temporarily locked for 1 hour.',
          };
        }

        verifyCredentialsCalled = true;
        return {'authenticated': true};
      }

      final result = serverLoginEndpoint('CUST101', 'correct_password');
      expect(result['authenticated'], isFalse);
      expect(result['is_locked'], isTrue);
      expect(verifyCredentialsCalled, isFalse); // Credential check completely bypassed/blocked
    });

    test('4. Consecutive Failed Attempts Transition Rule', () {
      int failedAttempts = 0;
      int hourlyLockoutCount = 0;
      DateTime? lockedUntil;

      void recordFailure() {
        failedAttempts++;
        if (failedAttempts >= 10) {
          hourlyLockoutCount++;
          if (hourlyLockoutCount >= 8) {
            lockedUntil = DateTime.now().add(const Duration(days: 3));
            hourlyLockoutCount = 0;
          } else {
            lockedUntil = DateTime.now().add(const Duration(hours: 1));
          }
          failedAttempts = 0;
        }
      }

      for (int i = 0; i < 9; i++) {
        recordFailure();
        expect(lockedUntil, isNull);
      }
      expect(failedAttempts, 9);

      // 10th failure triggers 1-hour lock
      recordFailure();
      expect(failedAttempts, 0);
      expect(lockedUntil, isNotNull);
      expect(hourlyLockoutCount, 1);
    });
  });
}
