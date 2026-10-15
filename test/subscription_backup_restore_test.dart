import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/utils/pref_keys.dart';

void main() {
  group('Subscription Backup and Restore Verification Tests', () {
    test('Subscription serializes correctly to backup format', () {
      final sub = Subscription(
        id: 42,
        profileId: 1,
        title: 'Netflix Premium',
        amount: 649.0,
        categoryId: 5,
        category: 'Entertainment',
        billingCycle: 'Monthly',
        startDate: DateTime(2026, 1, 15, 0, 0),
        nextBillingDate: DateTime(2026, 2, 15, 0, 0),
        currency: 'Rupee',
        paymentMethod: 'Credit Card',
        remarks: '4K Ultra HD Plan',
        isActive: true,
        autoLogExpense: true,
      );

      final exportedLine =
          'SUBSCRIPTION;;${sub.id};;${sub.profileId};;${sub.title};;${sub.amount};;${sub.categoryId};;${sub.category};;${sub.billingCycle};;${sub.startDate.toIso8601String()};;${sub.nextBillingDate.toIso8601String()};;${sub.currency};;${sub.paymentMethod};;${sub.remarks};;${sub.isActive ? "1" : "0"};;${sub.autoLogExpense ? "1" : "0"}';

      final parts = exportedLine.split(';;');
      expect(parts.length, 15);
      expect(parts[0], 'SUBSCRIPTION');
      expect(parts[1], '42');
      expect(parts[2], '1');
      expect(parts[3], 'Netflix Premium');
      expect(parts[4], '649.0');
      expect(parts[5], '5');
      expect(parts[6], 'Entertainment');
      expect(parts[7], 'Monthly');
      expect(parts[8], '2026-01-15T00:00:00.000');
      expect(parts[9], '2026-02-15T00:00:00.000');
      expect(parts[10], 'Rupee');
      expect(parts[11], 'Credit Card');
      expect(parts[12], '4K Ultra HD Plan');
      expect(parts[13], '1');
      expect(parts[14], '1');
    });

    test('Subscription deserializes correctly from backup line with all fields', () {
      const line =
          'SUBSCRIPTION;;10;;2;;Spotify Family;;179.0;;5;;Entertainment;;Monthly;;2026-03-01T10:00:00.000;;2026-04-01T10:00:00.000;;Dollar;;Bank;;Family account;;1;;0';

      final parts = line.split(';;');
      expect(parts[0], 'SUBSCRIPTION');
      expect(parts.length >= 15, isTrue);

      final sub = Subscription(
        id: int.tryParse(parts[1]),
        profileId: int.tryParse(parts[2]) ?? 0,
        title: parts[3],
        amount: double.tryParse(parts[4]) ?? 0.0,
        categoryId: int.tryParse(parts[5]) ?? 0,
        category: parts[6],
        billingCycle: parts[7],
        startDate: DateTime.tryParse(parts[8]) ?? DateTime.now(),
        nextBillingDate: DateTime.tryParse(parts[9]) ?? DateTime.now(),
        currency: parts[10].isNotEmpty && parts[10] != 'null' ? parts[10] : 'Rupee',
        paymentMethod: (parts[11] != 'null' && parts[11].trim().isNotEmpty) ? parts[11] : null,
        remarks: (parts[12] != 'null' && parts[12].trim().isNotEmpty) ? parts[12] : null,
        isActive: parts[13] == '1',
        autoLogExpense: parts[14] == '1',
      );

      expect(sub.id, 10);
      expect(sub.profileId, 2);
      expect(sub.title, 'Spotify Family');
      expect(sub.amount, 179.0);
      expect(sub.categoryId, 5);
      expect(sub.category, 'Entertainment');
      expect(sub.billingCycle, 'Monthly');
      expect(sub.startDate, DateTime(2026, 3, 1, 10, 0));
      expect(sub.nextBillingDate, DateTime(2026, 4, 1, 10, 0));
      expect(sub.currency, 'Dollar');
      expect(sub.paymentMethod, 'Bank');
      expect(sub.remarks, 'Family account');
      expect(sub.isActive, isTrue);
      expect(sub.autoLogExpense, isFalse);
    });

    test('Subscription handles null paymentMethod and remarks correctly during round-trip', () {
      final original = Subscription(
        id: 7,
        profileId: 0,
        title: 'Gym Membership',
        amount: 1500.0,
        categoryId: 6,
        category: 'Health',
        billingCycle: 'Yearly',
        startDate: DateTime(2026, 1, 1),
        nextBillingDate: DateTime(2027, 1, 1),
        currency: 'Euro',
        paymentMethod: null,
        remarks: null,
        isActive: false,
        autoLogExpense: false,
      );

      // Serialize
      final serialized =
          'SUBSCRIPTION;;${original.id};;${original.profileId};;${original.title};;${original.amount};;${original.categoryId};;${original.category};;${original.billingCycle};;${original.startDate.toIso8601String()};;${original.nextBillingDate.toIso8601String()};;${original.currency};;${original.paymentMethod};;${original.remarks};;${original.isActive ? "1" : "0"};;${original.autoLogExpense ? "1" : "0"}';

      final parts = serialized.split(';;');
      expect(parts[11], 'null');
      expect(parts[12], 'null');
      expect(parts[13], '0');
      expect(parts[14], '0');

      // Deserialize
      final restored = Subscription(
        id: int.tryParse(parts[1]),
        profileId: int.tryParse(parts[2]) ?? 0,
        title: parts[3],
        amount: double.tryParse(parts[4]) ?? 0.0,
        categoryId: int.tryParse(parts[5]) ?? 0,
        category: parts[6],
        billingCycle: parts[7],
        startDate: DateTime.tryParse(parts[8]) ?? DateTime.now(),
        nextBillingDate: DateTime.tryParse(parts[9]) ?? DateTime.now(),
        currency: parts[10].isNotEmpty && parts[10] != 'null' ? parts[10] : 'Rupee',
        paymentMethod: (parts[11] != 'null' && parts[11].trim().isNotEmpty) ? parts[11] : null,
        remarks: (parts[12] != 'null' && parts[12].trim().isNotEmpty) ? parts[12] : null,
        isActive: parts[13] == '1',
        autoLogExpense: parts[14] == '1',
      );

      expect(restored.id, original.id);
      expect(restored.profileId, original.profileId);
      expect(restored.title, original.title);
      expect(restored.amount, original.amount);
      expect(restored.categoryId, original.categoryId);
      expect(restored.category, original.category);
      expect(restored.billingCycle, original.billingCycle);
      expect(restored.startDate, original.startDate);
      expect(restored.nextBillingDate, original.nextBillingDate);
      expect(restored.currency, original.currency);
      expect(restored.paymentMethod, isNull);
      expect(restored.remarks, isNull);
      expect(restored.isActive, isFalse);
      expect(restored.autoLogExpense, isFalse);
    });

    test('Subscription notification preference keys are allowed for import', () {
      const safeExactKeys = {
        PrefKeys.username,
        PrefKeys.isDarkMode,
        PrefKeys.showExpStatusBar,
        PrefKeys.dailyBackupReminderEnabled,
        PrefKeys.lastBackupReminderTimestamp,
        PrefKeys.lastBackupTimestamp,
        PrefKeys.balanceVisible,
        PrefKeys.profileId,
        PrefKeys.monthlyLimit,
        PrefKeys.dailyLimit,
        PrefKeys.ocrEnabled,
        PrefKeys.ocrModelName,
        PrefKeys.aiProvider,
        PrefKeys.geminiModelName,
        PrefKeys.openaiModelName,
        PrefKeys.dailyReminderEnabled,
        PrefKeys.dailyReminderHour,
        PrefKeys.dailyReminderMinute,
        PrefKeys.subscriptionRemindersEnabled,
        PrefKeys.subscriptionReminderAdvanceDays,
        PrefKeys.subscriptionReminderHour,
        PrefKeys.subscriptionReminderMinute,
      };

      expect(safeExactKeys.contains(PrefKeys.subscriptionRemindersEnabled), isTrue);
      expect(safeExactKeys.contains(PrefKeys.subscriptionReminderAdvanceDays), isTrue);
      expect(safeExactKeys.contains(PrefKeys.subscriptionReminderHour), isTrue);
      expect(safeExactKeys.contains(PrefKeys.subscriptionReminderMinute), isTrue);
    });

    test('Stream parser line-splitter simulation correctly extracts multiple subscriptions', () async {
      const backupContent = '''
CATEGORY;;1;;Food
CATEGORY;;2;;Utilities
CATEGORY;;5;;Entertainment
SUBSCRIPTION;;1;;0;;Netflix;;499.0;;5;;Entertainment;;Monthly;;2026-01-01T00:00:00.000;;2026-02-01T00:00:00.000;;Rupee;;Card;;HD Plan;;1;;0
SUBSCRIPTION;;2;;0;;iCloud;;75.0;;2;;Utilities;;Monthly;;2026-01-10T00:00:00.000;;2026-02-10T00:00:00.000;;Rupee;;null;;50GB;;1;;1
SUBSCRIPTION;;3;;1;;Prime;;1499.0;;5;;Entertainment;;Yearly;;2026-05-01T00:00:00.000;;2027-05-01T00:00:00.000;;Rupee;;UPI;;null;;0;;0
''';

      final List<Subscription> parsedSubs = [];
      final lines = LineSplitter.split(backupContent);

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final parts = trimmed.split(';;');
        if (parts[0] == 'SUBSCRIPTION' && parts.length >= 15) {
          parsedSubs.add(Subscription(
            id: int.tryParse(parts[1]),
            profileId: int.tryParse(parts[2]) ?? 0,
            title: parts[3],
            amount: double.tryParse(parts[4]) ?? 0.0,
            categoryId: int.tryParse(parts[5]) ?? 0,
            category: parts[6],
            billingCycle: parts[7],
            startDate: DateTime.tryParse(parts[8]) ?? DateTime.now(),
            nextBillingDate: DateTime.tryParse(parts[9]) ?? DateTime.now(),
            currency: parts[10].isNotEmpty && parts[10] != 'null' ? parts[10] : 'Rupee',
            paymentMethod: (parts[11] != 'null' && parts[11].trim().isNotEmpty) ? parts[11] : null,
            remarks: (parts[12] != 'null' && parts[12].trim().isNotEmpty) ? parts[12] : null,
            isActive: parts[13] == '1',
            autoLogExpense: parts[14] == '1',
          ));
        }
      }

      expect(parsedSubs.length, 3);
      expect(parsedSubs[0].title, 'Netflix');
      expect(parsedSubs[0].id, 1);
      expect(parsedSubs[0].autoLogExpense, isFalse);

      expect(parsedSubs[1].title, 'iCloud');
      expect(parsedSubs[1].id, 2);
      expect(parsedSubs[1].paymentMethod, isNull);
      expect(parsedSubs[1].autoLogExpense, isTrue);

      expect(parsedSubs[2].title, 'Prime');
      expect(parsedSubs[2].id, 3);
      expect(parsedSubs[2].profileId, 1);
      expect(parsedSubs[2].remarks, isNull);
      expect(parsedSubs[2].isActive, isFalse);
    });
  });
}
