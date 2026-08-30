import 'package:intl/intl.dart';

class AreaScheduleHelper {
  static const List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  /// Returns the current time converted to the authoritative Indian Standard Time (UTC+5:30)
  static DateTime getKolkataTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  /// Calculates order schedule details for the given list of order-taking days and optional cutoff time string (e.g. "20:00:00")
  static ScheduleDetails calculateDetails(List<dynamic>? orderDays, {String? cutoffTimeStr, bool isStoreClosed = false}) {
    if (orderDays == null || orderDays.isEmpty) {
      return ScheduleDetails(state: ScheduleState.noSchedule);
    }

    final now = getKolkataTime();
    
    // Normalise order days to match case
    final Set<String> activeDays = orderDays
        .map((d) => d.toString().trim())
        .where((d) => weekdays.any((w) => w.toLowerCase() == d.toLowerCase()))
        .map((d) => weekdays.firstWhere((w) => w.toLowerCase() == d.toLowerCase()))
        .toSet();

    if (activeDays.isEmpty) {
      return ScheduleDetails(state: ScheduleState.noSchedule);
    }

    final todayName = weekdays[now.weekday - 1];
    final isOrderDayToday = activeDays.contains(todayName) && !isStoreClosed;

    // Parse cutoff time (defaulting to 23:59)
    int cutoffHour = 23;
    int cutoffMinute = 59;
    if (cutoffTimeStr != null && cutoffTimeStr.isNotEmpty) {
      final parts = cutoffTimeStr.split(':');
      if (parts.length >= 2) {
        cutoffHour = int.tryParse(parts[0]) ?? 23;
        cutoffMinute = int.tryParse(parts[1]) ?? 59;
      }
    }

    // Cutoff time today (in Kolkata timezone, represented as UTC datetime)
    final cutoffTime = DateTime.utc(now.year, now.month, now.day, cutoffHour, cutoffMinute, 0);

    if (isOrderDayToday && now.isBefore(cutoffTime)) {
      final remaining = cutoffTime.difference(now);
      final deliveryDate = now.add(const Duration(days: 1));
      return ScheduleDetails(
        state: ScheduleState.openToday,
        orderTakingDate: now,
        deliveryDate: deliveryDate,
        remainingTime: remaining,
        cutoffTime: cutoffTime,
      );
    }

    // Today is not order day, or today's order day has passed cutoff
    // Let's find the next scheduled order taking day
    int daysToAdd = 1;
    DateTime nextOrderDate = now.add(const Duration(days: 1));
    String nextOrderDayName = weekdays[nextOrderDate.weekday - 1];

    while (!activeDays.contains(nextOrderDayName) && daysToAdd <= 8) {
      daysToAdd++;
      nextOrderDate = now.add(Duration(days: daysToAdd));
      nextOrderDayName = weekdays[nextOrderDate.weekday - 1];
    }

    final nextDeliveryDate = nextOrderDate.add(const Duration(days: 1));

    return ScheduleDetails(
      state: ScheduleState.closedToday,
      nextOrderDate: nextOrderDate,
      nextDeliveryDate: nextDeliveryDate,
    );
  }

  /// Formats a DateTime to "DayName, DD MonthName" format, e.g. "Tuesday, 26 August"
  /// If the date is tomorrow (based on getKolkataTime()), it returns "Tomorrow, DD MonthName"
  static String formatDayAndDate(DateTime date) {
    final now = getKolkataTime();
    final tomorrow = now.add(const Duration(days: 1));
    final isDateTomorrow = date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
    if (isDateTomorrow) {
      return "Tomorrow, ${DateFormat('d MMMM').format(date)}";
    }
    return DateFormat('EEEE, d MMMM').format(date);
  }

  /// Formats Duration to HH:MM:SS format
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
}

enum ScheduleState {
  openToday,
  closedToday,
  noSchedule
}

class ScheduleDetails {
  final ScheduleState state;
  
  // Available when state == openToday
  final DateTime? orderTakingDate;
  final DateTime? deliveryDate;
  final Duration? remainingTime;
  final DateTime? cutoffTime;

  // Available when state == closedToday
  final DateTime? nextOrderDate;
  final DateTime? nextDeliveryDate;

  ScheduleDetails({
    required this.state,
    this.orderTakingDate,
    this.deliveryDate,
    this.remainingTime,
    this.cutoffTime,
    this.nextOrderDate,
    this.nextDeliveryDate,
  });
}
