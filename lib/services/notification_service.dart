import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/utils/currency_symbol.dart';
import 'package:expense_tracker/utils/pref_keys.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Function(String?)? onNotificationSelected;

  static const int dailyReminderNotificationId = 1001;
  static const int testNotificationId = 1002;
  static const int subscriptionIdBase = 20000;

  static const String dailyChannelId = 'daily_expense_reminder';
  static const String dailyChannelName = 'Daily Expense Reminder';
  static const String dailyChannelDesc = 'Reminders to log your daily expenses';

  static const String subscriptionChannelId = 'subscription_due_alerts';
  static const String subscriptionChannelName = 'Subscription Due Alerts';
  static const String subscriptionChannelDesc =
      'Alerts for upcoming recurring subscriptions';

  static const String generalChannelId = 'general_notifications';
  static const String generalChannelName = 'General Notifications';
  static const String generalChannelDesc =
      'General alerts and test notifications';

  Future<void> init({Function(String?)? onSelectNotification}) async {
    if (_isInitialized) return;
    onNotificationSelected = onSelectNotification;

    // 1. Initialize timezones with safe fallback
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('NotificationService: Unable to resolve device timezone: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    // 2. Platform initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (onNotificationSelected != null) {
          onNotificationSelected!(response.payload);
        }
      },
    );

    // 3. Handle cold-start launch via notification tap
    try {
      final launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null && onNotificationSelected != null) {
          Future.delayed(const Duration(milliseconds: 400), () {
            onNotificationSelected!(payload);
          });
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error reading launch details: $e');
    }

    _isInitialized = true;
  }

  /// Request permissions on Android 13+ and iOS.
  Future<bool> requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final bool? granted =
            await androidImpl?.requestNotificationsPermission();
        return granted ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final bool? granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('NotificationService: requestPermissions error: $e');
    }
    return true;
  }

  /// Explicitly request exact alarms permission on Android 12+ if needed.
  /// Note: Opening this redirects the user to the system "Alarms & Reminders" settings screen.
  Future<bool?> requestExactAlarmsPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidImpl?.requestExactAlarmsPermission();
    }
    return true;
  }

  /// Synchronize all notifications (daily reminder + subscription alerts)
  /// using saved preferences.
  Future<void> syncAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await _syncDailyReminderFromPrefs(prefs);
    await rescheduleAllSubscriptionReminders();
  }

  // --- Daily Expense Reminder ---

  Future<void> _syncDailyReminderFromPrefs(SharedPreferences prefs) async {
    final bool enabled = prefs.getBool(PrefKeys.dailyReminderEnabled) ?? false;
    final int hour = prefs.getInt(PrefKeys.dailyReminderHour) ?? 21;
    final int minute = prefs.getInt(PrefKeys.dailyReminderMinute) ?? 0;

    await scheduleDailyReminder(
      enabled: enabled,
      hour: hour,
      minute: minute,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleDailyReminder({
    required bool enabled,
    int hour = 21,
    int minute = 0,
  }) async {
    try {
      await _notificationsPlugin.cancel(id: dailyReminderNotificationId);
    } catch (_) {}

    if (!enabled) return;

    try {
      final scheduledDate = _nextInstanceOfTime(hour, minute);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        dailyChannelId,
        dailyChannelName,
        channelDescription: dailyChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails darwinDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          id: dailyReminderNotificationId,
          title: 'Daily Expense Reminder 📝',
          body: 'Keep your budget on track! Remember to log today\'s expenses.',
          scheduledDate: scheduledDate,
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'daily_reminder',
        );
      } catch (exactAlarmError) {
        debugPrint(
            'NotificationService: Exact alarm schedule failed, falling back to inexact: $exactAlarmError');
        await _notificationsPlugin.zonedSchedule(
          id: dailyReminderNotificationId,
          title: 'Daily Expense Reminder 📝',
          body: 'Keep your budget on track! Remember to log today\'s expenses.',
          scheduledDate: scheduledDate,
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'daily_reminder',
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule daily reminder: $e');
    }
  }

  // --- Subscriptions Due Alerts ---

  Future<void> cancelSubscriptionReminder(int subId) async {
    try {
      await _notificationsPlugin.cancel(id: subscriptionIdBase + subId);
    } catch (_) {}
  }

  Future<void> rescheduleAllSubscriptionReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final bool enabled =
        prefs.getBool(PrefKeys.subscriptionRemindersEnabled) ?? true;
    final int advanceDays =
        prefs.getInt(PrefKeys.subscriptionReminderAdvanceDays) ?? 1;
    final int reminderHour =
        prefs.getInt(PrefKeys.subscriptionReminderHour) ?? 9;
    final int reminderMinute =
        prefs.getInt(PrefKeys.subscriptionReminderMinute) ?? 0;

    List<Subscription> subs = [];
    try {
      subs = await DatabaseHelper().getSubscriptions();
    } catch (e) {
      debugPrint('NotificationService: Error loading subscriptions: $e');
      return;
    }

    // Cancel existing scheduled notifications for all subscriptions (including any deleted subscriptions)
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      for (final req in pending) {
        if (req.id >= subscriptionIdBase) {
          try {
            await _notificationsPlugin.cancel(id: req.id);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error clearing pending notifications: $e');
    }
    for (final sub in subs) {
      if (sub.id != null) {
        await cancelSubscriptionReminder(sub.id!);
      }
    }

    if (!enabled) return;

    final nowTz = tz.TZDateTime.now(tz.local);

    for (final sub in subs) {
      if (sub.id == null || !sub.isActive) continue;

      final renewalDate = sub.nextBillingDate;
      final targetDate = renewalDate.subtract(Duration(days: advanceDays));

      final scheduledDateTime = tz.TZDateTime(
        tz.local,
        targetDate.year,
        targetDate.month,
        targetDate.day,
        reminderHour,
        reminderMinute,
      );

      // Only schedule if the reminder time is in the future
      if (scheduledDateTime.isAfter(nowTz)) {
        final symbol = CurrencySymbol().getSymbol(sub.currency);
        final String title = advanceDays == 0
            ? 'Subscription Due Today: ${sub.title} 🔔'
            : 'Subscription Due in $advanceDays day${advanceDays > 1 ? 's' : ''}: ${sub.title} 🔔';
        final String body =
            '${sub.title} renewal ($symbol${sub.amount.toStringAsFixed(2)}) is due on ${DateFormat('dd MMM yyyy').format(sub.nextBillingDate)}.';

        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
          subscriptionChannelId,
          subscriptionChannelName,
          channelDescription: subscriptionChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

        const DarwinNotificationDetails darwinDetails =
            DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        const NotificationDetails platformDetails = NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
        );

        try {
          await _notificationsPlugin.zonedSchedule(
            id: subscriptionIdBase + sub.id!,
            title: title,
            body: body,
            scheduledDate: scheduledDateTime,
            notificationDetails: platformDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'subscription_${sub.id}',
          );
        } catch (exactAlarmError) {
          debugPrint(
              'NotificationService: Exact alarm schedule failed for sub, falling back to inexact: $exactAlarmError');
          try {
            await _notificationsPlugin.zonedSchedule(
              id: subscriptionIdBase + sub.id!,
              title: title,
              body: body,
              scheduledDate: scheduledDateTime,
              notificationDetails: platformDetails,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: 'subscription_${sub.id}',
            );
          } catch (e) {
            debugPrint(
                'NotificationService: Inexact schedule also failed for ${sub.title}: $e');
          }
        }
      }
    }
  }

  // --- Instant Test Notification ---

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      generalChannelId,
      generalChannelName,
      channelDescription: generalChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: testNotificationId,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload ?? 'test_notification',
    );
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService: cancelAll error: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('NotificationService: getPendingNotifications error: $e');
      return [];
    }
  }
}
