class SubscriptionDateUtils {
  /// Adds [months] to [date] while clamping the day to the maximum valid day of the resulting month.
  /// E.g. Jan 31 + 1 month -> Feb 28 (or Feb 29 on leap year).
  static DateTime addMonths(DateTime date, int months) {
    int newYear = date.year + ((date.month - 1 + months) ~/ 12);
    int newMonth = ((date.month - 1 + months) % 12) + 1;
    if (newMonth <= 0) {
      newMonth += 12;
      newYear -= 1;
    }
    int maxDays = daysInMonth(newYear, newMonth);
    int newDay = date.day > maxDays ? maxDays : date.day;
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute, date.second);
  }

  /// Adds [years] to [date] while handling leap year edge cases (Feb 29 -> Feb 28 in non-leap years).
  static DateTime addYears(DateTime date, int years) {
    int newYear = date.year + years;
    int maxDays = daysInMonth(newYear, date.month);
    int newDay = date.day > maxDays ? maxDays : date.day;
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
  static DateTime calculateNextBillingDate(DateTime startDate, String cycle) {
    final normalizedCycle = cycle.toLowerCase().trim();
    if (normalizedCycle == 'weekly') {
      return startDate.add(const Duration(days: 7));
    } else if (normalizedCycle == 'yearly') {
      return addYears(startDate, 1);
    } else {
      // Monthly or default
      return addMonths(startDate, 1);
    }
  }

  /// Advances [currentDueDate] by 1 billing cycle according to [cycle].
  static DateTime advanceNextBillingDate(DateTime currentDueDate, String cycle) {
    return calculateNextBillingDate(currentDueDate, cycle);
  }

  /// If [dueDate] is in the past relative to [targetDate] (defaults to today),
  /// advances [dueDate] cycle by cycle until it is on or after [targetDate].
  static DateTime catchUpNextBillingDate(DateTime dueDate, String cycle, {DateTime? targetDate}) {
    final now = targetDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime next = dueDate;
    
    int iterations = 0;
    while (DateTime(next.year, next.month, next.day).isBefore(today) && iterations < 500) {
      next = advanceNextBillingDate(next, cycle);
      iterations++;
    }
    return next;
  }
}
