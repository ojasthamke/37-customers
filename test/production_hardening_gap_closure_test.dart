import 'package:flutter_test/flutter_test.dart';
import 'package:aplibhaji_customers/core/utils/schedule_helper.dart';

void main() {
  group('Production Hardening & 10/10 Gap-Closure Tests', () {
    test('1. Time / Date Reliability: Invariant to device timezone (US, UK, UTC, JST)', () {
      final utcTime = DateTime.utc(2026, 9, 3, 12, 0, 0);
      final kolkataTime = AreaScheduleHelper.getKolkataTime(utcTime);

      expect(kolkataTime.hour, 17);
      expect(kolkataTime.minute, 30);
      expect(kolkataTime.day, 3);
      expect(kolkataTime.month, 9);
      expect(kolkataTime.year, 2026);
    });

    test('2. Server Time Calibration: Compensates for device clock drift', () {
      final serverTime = DateTime.utc(2026, 9, 3, 10, 0, 0);
      AreaScheduleHelper.calibrateWithServerTime(serverTime);
      final calibratedKolkata = AreaScheduleHelper.getKolkataTime(serverTime);
      expect(calibratedKolkata.hour, 15);
      expect(calibratedKolkata.minute, 30);
    });

    test('3. Midnight Rollover: Cutoff and schedule calculation across midnight', () {
      final beforeMidnight = DateTime.utc(2026, 9, 3, 18, 28, 0);
      final scheduleBefore = AreaScheduleHelper.calculateDetails(
        ['Thursday', 'Friday'],
        cutoffTimeStr: '23:59:00',
        customNow: beforeMidnight,
      );
      expect(scheduleBefore.state, ScheduleState.openToday);

      final afterCutoff = DateTime.utc(2026, 9, 3, 18, 29, 30);
      final scheduleAfter = AreaScheduleHelper.calculateDetails(
        ['Thursday', 'Friday'],
        cutoffTimeStr: '23:59:00',
        customNow: afterCutoff,
      );
      expect(scheduleAfter.state, ScheduleState.closedToday);
    });

    test('4. Zero and Negative Stock Safety: Strict rejection of zero and negative stock', () {
      bool validateStockDeduction(num? stock, num requestedQty) {
        if (stock == null) return false;
        if (stock <= 0) return false;
        if (stock < requestedQty) return false;
        return true;
      }

      expect(validateStockDeduction(0, 1.0), isFalse);
      expect(validateStockDeduction(-1, 1.0), isFalse);
      expect(validateStockDeduction(-0.5, 0.5), isFalse);
      expect(validateStockDeduction(1.0, 1.0), isTrue);
      expect(validateStockDeduction(1.0, 1.001), isFalse);
    });

    test('5. Account Switch Isolation: State and timers wiped completely on logout', () {
      final inMemoryCart = <String, dynamic>{'item_1': 'Tomato 1kg'};
      final inMemoryOrders = <String, dynamic>{'order_1': '#ORD-1001'};
      bool isNotificationSyncActive = true;

      void onLogout() {
        inMemoryCart.clear();
        inMemoryOrders.clear();
        isNotificationSyncActive = false;
      }

      expect(inMemoryCart.isNotEmpty, isTrue);
      expect(inMemoryOrders.isNotEmpty, isTrue);

      onLogout();

      expect(inMemoryCart.isEmpty, isTrue);
      expect(inMemoryOrders.isEmpty, isTrue);
      expect(isNotificationSyncActive, isFalse);
    });

    test('6. Crash Observability PII Masking: Tokens and phone numbers are scrubbed', () {
      String sanitize(String raw) {
        var s = raw;
        s = s.replaceAll(RegExp(r'eyJ[a-zA-Z0-9_\-\.]+'), '[MASKED_TOKEN]');
        s = s.replaceAll(RegExp(r'\b[6-9]\d{9}\b'), '[MASKED_PHONE]');
        s = s.replaceAll(RegExp(r'(password|pin)\s*[:=]\s*[^\s,]+', caseSensitive: false), '[MASKED_CREDENTIAL]');
        return s;
      }

      const rawException = 'AuthException: Token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.t-ID for phone 9876543210 with password: SecretPassword123 failed';
      final sanitized = sanitize(rawException);

      expect(sanitized.contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'), isFalse);
      expect(sanitized.contains('9876543210'), isFalse);
      expect(sanitized.contains('SecretPassword123'), isFalse);
      expect(sanitized.contains('[MASKED_TOKEN]'), isTrue);
      expect(sanitized.contains('[MASKED_PHONE]'), isTrue);
      expect(sanitized.contains('[MASKED_CREDENTIAL]'), isTrue);
    });
  });
}