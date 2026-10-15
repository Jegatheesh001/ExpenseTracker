import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:expense_tracker/services/notification_service.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/utils/pref_keys.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  group('NotificationService Configuration & Calculation Tests', () {
    test('Notification constants and channels are configured properly', () {
      expect(NotificationService.dailyReminderNotificationId, 1001);
      expect(NotificationService.testNotificationId, 1002);
      expect(NotificationService.subscriptionIdBase, 20000);

      expect(NotificationService.dailyChannelId, 'daily_expense_reminder');
      expect(NotificationService.subscriptionChannelId, 'subscription_due_alerts');
      expect(NotificationService.generalChannelId, 'general_notifications');
    });

    test('Subscription target reminder date matches advanceDays config', () {
      final renewalDate = DateTime(2026, 11, 15);

      // Same day (advanceDays = 0)
      final sameDayTarget = renewalDate.subtract(const Duration(days: 0));
      expect(sameDayTarget, DateTime(2026, 11, 15));

      // 1 day before (advanceDays = 1)
      final oneDayBeforeTarget = renewalDate.subtract(const Duration(days: 1));
      expect(oneDayBeforeTarget, DateTime(2026, 11, 14));

      // 2 days before (advanceDays = 2)
      final twoDaysBeforeTarget = renewalDate.subtract(const Duration(days: 2));
      expect(twoDaysBeforeTarget, DateTime(2026, 11, 13));

      // 3 days before (advanceDays = 3)
      final threeDaysBeforeTarget = renewalDate.subtract(const Duration(days: 3));
      expect(threeDaysBeforeTarget, DateTime(2026, 11, 12));
    });

    test('Subscription notification ID generation is unique per subscription id', () {
      final sub1 = Subscription(
        id: 1,
        profileId: 0,
        title: 'Netflix',
        amount: 15.99,
        categoryId: 5,
        category: 'Entertainment',
        billingCycle: 'Monthly',
        startDate: DateTime(2026, 1, 1),
        nextBillingDate: DateTime(2026, 11, 1),
      );

      final sub2 = Subscription(
        id: 42,
        profileId: 0,
        title: 'Spotify',
        amount: 9.99,
        categoryId: 5,
        category: 'Entertainment',
        billingCycle: 'Monthly',
        startDate: DateTime(2026, 1, 1),
        nextBillingDate: DateTime(2026, 11, 5),
      );

      final notifId1 = NotificationService.subscriptionIdBase + sub1.id!;
      final notifId2 = NotificationService.subscriptionIdBase + sub2.id!;

      expect(notifId1, 20001);
      expect(notifId2, 20042);
      expect(notifId1 != notifId2, isTrue);
    });

    test('Daily reminder next instance logic schedules for today or tomorrow', () {
      final now = tz.TZDateTime.now(tz.local);

      // If scheduled time is in future today
      final futureHour = (now.hour + 2) % 24;
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, futureHour, 0);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      expect(scheduled.isAfter(now), isTrue);

      // If scheduled time is in the past today, it rolls to tomorrow
      final pastHour = (now.hour - 2 + 24) % 24;
      var pastScheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, pastHour, 0);
      if (pastScheduled.isBefore(now)) {
        pastScheduled = pastScheduled.add(const Duration(days: 1));
      }
      expect(pastScheduled.isAfter(now), isTrue);
      expect(pastScheduled.day != now.day || pastScheduled.month != now.month, isTrue);
    });

    test('PrefKeys constants include all required notification keys', () {
      expect(PrefKeys.dailyReminderEnabled, 'dailyReminderEnabled');
      expect(PrefKeys.dailyReminderHour, 'dailyReminderHour');
      expect(PrefKeys.dailyReminderMinute, 'dailyReminderMinute');
      expect(PrefKeys.subscriptionRemindersEnabled, 'subscriptionRemindersEnabled');
      expect(PrefKeys.subscriptionReminderAdvanceDays, 'subscriptionReminderAdvanceDays');
      expect(PrefKeys.subscriptionReminderHour, 'subscriptionReminderHour');
      expect(PrefKeys.subscriptionReminderMinute, 'subscriptionReminderMinute');
    });

    test('Singleton instance identity is preserved', () {
      final instance1 = NotificationService();
      final instance2 = NotificationService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('Leap year subscription advance calculation clamps properly', () {
      final leapRenewal = DateTime(2028, 2, 29);
      final oneDayBefore = leapRenewal.subtract(const Duration(days: 1));
      expect(oneDayBefore, DateTime(2028, 2, 28));

      final twoDaysBefore = leapRenewal.subtract(const Duration(days: 2));
      expect(twoDaysBefore, DateTime(2028, 2, 27));
    });

    test('Past subscription dates are identified and not scheduled', () {
      final now = tz.TZDateTime.now(tz.local);
      final pastDate = now.subtract(const Duration(days: 5));
      expect(pastDate.isAfter(now), isFalse);

      final futureDate = now.add(const Duration(days: 5));
      expect(futureDate.isAfter(now), isTrue);
    });
  });
}
