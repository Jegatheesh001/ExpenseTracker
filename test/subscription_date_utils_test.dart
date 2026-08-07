import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/subscription_date_utils.dart';

void main() {
  group('SubscriptionDateUtils Tests', () {
    test('Jan 31 + 1 month clamps to Feb 28 in non-leap year', () {
      final jan31 = DateTime(2026, 1, 31);
      final result = SubscriptionDateUtils.addMonths(jan31, 1);
      expect(result, DateTime(2026, 2, 28));
    });

    test('Jan 31 + 1 month clamps to Feb 29 in leap year', () {
      final jan31 = DateTime(2028, 1, 31);
      final result = SubscriptionDateUtils.addMonths(jan31, 1);
      expect(result, DateTime(2028, 2, 29));
    });

    test('Aug 31 + 1 month clamps to Sep 30', () {
      final aug31 = DateTime(2026, 8, 31);
      final result = SubscriptionDateUtils.addMonths(aug31, 1);
      expect(result, DateTime(2026, 9, 30));
    });

    test('Feb 29 on leap year + 1 year clamps to Feb 28', () {
      final feb29 = DateTime(2028, 2, 29);
      final result = SubscriptionDateUtils.addYears(feb29, 1);
      expect(result, DateTime(2029, 2, 28));
    });

    test('calculateNextBillingDate weekly', () {
      final start = DateTime(2026, 8, 1);
      final next = SubscriptionDateUtils.calculateNextBillingDate(start, 'Weekly');
      expect(next, DateTime(2026, 8, 8));
    });

    test('calculateNextBillingDate yearly', () {
      final start = DateTime(2026, 8, 1);
      final next = SubscriptionDateUtils.calculateNextBillingDate(start, 'Yearly');
      expect(next, DateTime(2027, 8, 1));
    });

    test('catchUpNextBillingDate advances overdue date to on or after targetDate', () {
      final overdueDate = DateTime(2026, 5, 1);
      final targetDate = DateTime(2026, 8, 7);
      final caughtUp = SubscriptionDateUtils.catchUpNextBillingDate(
        overdueDate,
        'Monthly',
        targetDate: targetDate,
      );
      expect(caughtUp, DateTime(2026, 9, 1));
    });

    test('Logging overdue subscription advances next due date to next future cycle', () {
      final overdueDate = DateTime(2026, 6, 7);
      final targetDate = DateTime(2026, 8, 7);
      // Catch up to current period (2026-08-07), then advance 1 cycle -> 2026-09-07
      final caughtUp = SubscriptionDateUtils.catchUpNextBillingDate(
        overdueDate,
        'Monthly',
        targetDate: targetDate,
      );
      final nextDue = SubscriptionDateUtils.advanceNextBillingDate(caughtUp, 'Monthly');
      expect(nextDue, DateTime(2026, 9, 7));
    });

    test('Logging due-today subscription advances next due date to next cycle', () {
      final dueToday = DateTime(2026, 8, 7);
      final targetDate = DateTime(2026, 8, 7);
      final caughtUp = SubscriptionDateUtils.catchUpNextBillingDate(
        dueToday,
        'Monthly',
        targetDate: targetDate,
      );
      final nextDue = SubscriptionDateUtils.advanceNextBillingDate(caughtUp, 'Monthly');
      expect(nextDue, DateTime(2026, 9, 7));
    });
  });
}
