class SubscriptionDateUtils {
  /// Adds [months] to [date] while clamping the day to the maximum valid day of the resulting month.
  /// If [anchorDay] is provided (e.g. from subscription startDate.day), it is used as the target day
  /// to prevent permanent day-of-month drift when passing through shorter months (e.g. 31st -> 28th -> 31st).
  static DateTime addMonths(DateTime date, int months, {int? anchorDay}) {
    int totalMonths = (date.year * 12) + (date.month - 1) + months;
    int newYear = totalMonths ~/ 12;
    int newMonth = (totalMonths % 12) + 1;
    int maxDays = daysInMonth(newYear, newMonth);
    int targetDay = anchorDay ?? date.day;
    int newDay = targetDay > maxDays ? maxDays : targetDay;
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute, date.second);
  }

  /// Adds [years] to [date] while handling leap year edge cases (Feb 29 -> Feb 28 in non-leap years,
  /// restored to Feb 29 on future leap years if [anchorDay] is 29).
  static DateTime addYears(DateTime date, int years, {int? anchorDay}) {
    int newYear = date.year + years;
    int maxDays = daysInMonth(newYear, date.month);
    int targetDay = anchorDay ?? date.day;
    int newDay = targetDay > maxDays ? maxDays : targetDay;
    return DateTime(newYear, date.month, newDay, date.hour, date.minute, date.second);
  }

  /// Returns the number of days in a given [month] of [year].
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final bool isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const daysPerMonth = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return daysPerMonth[month];
  }

  /// Calculates the next billing date from [startDate] according to [cycle].
  static DateTime calculateNextBillingDate(DateTime startDate, String cycle, {int? anchorDay}) {
    final normalizedCycle = cycle.toLowerCase().trim();
    final effectiveAnchor = anchorDay ?? startDate.day;
    if (normalizedCycle == 'weekly') {
      return DateTime(
        startDate.year,
        startDate.month,
        startDate.day + 7,
        startDate.hour,
        startDate.minute,
        startDate.second,
      );
    } else if (normalizedCycle == 'yearly') {
      return addYears(startDate, 1, anchorDay: effectiveAnchor);
    } else {
      // Monthly or default
      return addMonths(startDate, 1, anchorDay: effectiveAnchor);
    }
  }

  /// Advances [currentDueDate] by 1 billing cycle according to [cycle].
  static DateTime advanceNextBillingDate(DateTime currentDueDate, String cycle, {int? anchorDay}) {
    return calculateNextBillingDate(currentDueDate, cycle, anchorDay: anchorDay);
  }

  /// If [dueDate] is in the past relative to [targetDate] (defaults to today),
  /// advances [dueDate] cycle by cycle until it is on or after [targetDate].
  static DateTime catchUpNextBillingDate(DateTime dueDate, String cycle, {DateTime? targetDate, int? anchorDay}) {
    final now = targetDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime next = dueDate;
    
    int iterations = 0;
    while (DateTime(next.year, next.month, next.day).isBefore(today) && iterations < 500) {
      next = advanceNextBillingDate(next, cycle, anchorDay: anchorDay);
      iterations++;
    }
    return next;
  }

  /// Calculates the next renewal date after a subscription payment is logged or skipped.
  /// Always advances [currentDueDate] by at least 1 cycle. If the resulting date is still
  /// on or before [targetDate] (defaults to today), catches up cycle by cycle until it is
  /// strictly in the upcoming period (after [targetDate]).
  /// Preserves [anchorDay] (e.g. from subscription startDate.day) to prevent month-end drift.
  static DateTime getNextRenewalDate(
    DateTime currentDueDate,
    String cycle, {
    DateTime? targetDate,
    int? anchorDay,
  }) {
    DateTime next = advanceNextBillingDate(currentDueDate, cycle, anchorDay: anchorDay);
    final now = targetDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int iterations = 0;
    while (!DateTime(next.year, next.month, next.day).isAfter(today) && iterations < 500) {
      next = advanceNextBillingDate(next, cycle, anchorDay: anchorDay);
      iterations++;
    }
    return next;
  }
}
