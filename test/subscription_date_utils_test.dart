import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/subscription_date_utils.dart';

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
      final nextDue = SubscriptionDateUtils.getNextRenewalDate(
        overdueDate,
        'Monthly',
        targetDate: targetDate,
      );
      expect(nextDue, DateTime(2026, 9, 7));
    });

    test('Logging subscription overdue by 2 days advances to next month, not two months ahead', () {
      // Overdue by 2 days: Aug 5 when today is Aug 7
      final overdueDate = DateTime(2026, 8, 5);
      final targetDate = DateTime(2026, 8, 7);
      final nextDue = SubscriptionDateUtils.getNextRenewalDate(
        overdueDate,
        'Monthly',
        targetDate: targetDate,
      );
      // Must advance to Sep 5, NOT Oct 5
      expect(nextDue, DateTime(2026, 9, 5));
    });

    test('Logging subscription overdue by 1 day (yesterday) advances to next month', () {
      final overdueYesterday = DateTime(2026, 8, 6);
      final targetDate = DateTime(2026, 8, 7);
      final nextDue = SubscriptionDateUtils.getNextRenewalDate(
        overdueYesterday,
        'Monthly',
        targetDate: targetDate,
      );
      expect(nextDue, DateTime(2026, 9, 6));
    });

    test('Logging due-today subscription advances next due date to next cycle', () {
      final dueToday = DateTime(2026, 8, 7);
      final targetDate = DateTime(2026, 8, 7);
      final nextDue = SubscriptionDateUtils.getNextRenewalDate(
        dueToday,
        'Monthly',
        targetDate: targetDate,
      );
      expect(nextDue, DateTime(2026, 9, 7));
    });

    test('Logging future subscription advances next due date by 1 cycle', () {
      final futureDue = DateTime(2026, 8, 15);
      final targetDate = DateTime(2026, 8, 7);
      final nextDue = SubscriptionDateUtils.getNextRenewalDate(
        futureDue,
        'Monthly',
        targetDate: targetDate,
      );
      expect(nextDue, DateTime(2026, 9, 15));
    });

    test('Skipping subscription advances next due date to next billing cycle', () {
      final currentDue = DateTime(2026, 8, 15);
      final targetDate = DateTime(2026, 8, 10);
      final nextDue = SubscriptionDateUtils.getNextRenewalDate(
        currentDue,
        'Monthly',
        targetDate: targetDate,
      );
      expect(nextDue, DateTime(2026, 9, 15));
    });

    test('Skipping overdue subscription advances to upcoming cycle', () {
      final overdue = DateTime(2026, 7, 1);
      final targetDate = DateTime(2026, 8, 10);
      final nextDue = SubscriptionDateUtils.getNextRenewalDate(
        overdue,
        'Monthly',
        targetDate: targetDate,
      );
      expect(nextDue, DateTime(2026, 9, 1));
    });

    test('Skip and Log produce consistent renewal date for overdue subscription', () {
      final overdueDate = DateTime(2026, 10, 10);
      final today = DateTime(2026, 10, 14);

      final nextOnLog = SubscriptionDateUtils.getNextRenewalDate(
        overdueDate,
        'Monthly',
        targetDate: today,
        anchorDay: 10,
      );

      final nextOnSkip = SubscriptionDateUtils.getNextRenewalDate(
        overdueDate,
        'Monthly',
        targetDate: today,
        anchorDay: 10,
      );

      expect(nextOnLog, DateTime(2026, 11, 10));
      expect(nextOnSkip, DateTime(2026, 11, 10));
      expect(nextOnLog, equals(nextOnSkip));
    });

    test('Preserves anchor day 31 across months without drifting permanently to 28 or 30', () {
      final start = DateTime(2026, 1, 31);
      const cycle = 'Monthly';

      // Jan 31 -> Feb 28
      final feb = SubscriptionDateUtils.advanceNextBillingDate(start, cycle, anchorDay: start.day);
      expect(feb, DateTime(2026, 2, 28));

      // Feb 28 -> Mar 31 (recovers 31st!)
      final mar = SubscriptionDateUtils.advanceNextBillingDate(feb, cycle, anchorDay: start.day);
      expect(mar, DateTime(2026, 3, 31));

      // Mar 31 -> Apr 30
      final apr = SubscriptionDateUtils.advanceNextBillingDate(mar, cycle, anchorDay: start.day);
      expect(apr, DateTime(2026, 4, 30));

      // Apr 30 -> May 31 (recovers 31st!)
      final may = SubscriptionDateUtils.advanceNextBillingDate(apr, cycle, anchorDay: start.day);
      expect(may, DateTime(2026, 5, 31));
    });

    test('Preserves anchor day 29 for yearly leap year', () {
      final leapStart = DateTime(2024, 2, 29);
      const cycle = 'Yearly';

      // 2024 (leap) -> 2025
      final y2025 = SubscriptionDateUtils.advanceNextBillingDate(leapStart, cycle, anchorDay: leapStart.day);
      expect(y2025, DateTime(2025, 2, 28));

      // 2025 -> 2026
      final y2026 = SubscriptionDateUtils.advanceNextBillingDate(y2025, cycle, anchorDay: leapStart.day);
      expect(y2026, DateTime(2026, 2, 28));

      // 2026 -> 2027
      final y2027 = SubscriptionDateUtils.advanceNextBillingDate(y2026, cycle, anchorDay: leapStart.day);
      expect(y2027, DateTime(2027, 2, 28));

      // 2027 -> 2028 (leap year, recovers Feb 29!)
      final y2028 = SubscriptionDateUtils.advanceNextBillingDate(y2027, cycle, anchorDay: leapStart.day);
      expect(y2028, DateTime(2028, 2, 29));
    });
  });
}
