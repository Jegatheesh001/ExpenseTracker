import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/db/entity.dart';

void main() {
  group('Subscription Model Tests', () {
    test('monthlyAmount calculation for Monthly cycle', () {
      final sub = Subscription(
        profileId: 1,
        title: 'Netflix',
        amount: 199.0,
        categoryId: 1,
        category: 'Entertainment',
        billingCycle: 'Monthly',
        startDate: DateTime(2026, 1, 1),
        nextBillingDate: DateTime(2026, 2, 1),
      );
      expect(sub.monthlyAmount, 199.0);
    });

    test('monthlyAmount calculation for Yearly cycle', () {
      final sub = Subscription(
        profileId: 1,
        title: 'Amazon Prime',
        amount: 1499.0,
        categoryId: 1,
        category: 'Entertainment',
        billingCycle: 'Yearly',
        startDate: DateTime(2026, 1, 1),
        nextBillingDate: DateTime(2027, 1, 1),
      );
      expect(sub.monthlyAmount, closeTo(124.91666, 0.001));
    });

    test('monthlyAmount calculation for Weekly cycle', () {
      final sub = Subscription(
        profileId: 1,
        title: 'Newspaper',
        amount: 50.0,
        categoryId: 2,
        category: 'News',
        billingCycle: 'Weekly',
        startDate: DateTime(2026, 1, 1),
        nextBillingDate: DateTime(2026, 1, 8),
      );
      expect(sub.monthlyAmount, closeTo(216.65, 0.01));
    });

    test('Subscription toMap and fromMap serialization', () {
      final original = Subscription(
        id: 42,
        profileId: 2,
        title: 'Spotify Premium',
        amount: 119.0,
        categoryId: 3,
        category: 'Music',
        billingCycle: 'Monthly',
        startDate: DateTime(2026, 3, 15, 10, 0),
        nextBillingDate: DateTime(2026, 4, 15, 10, 0),
        currency: 'Dollar',
        paymentMethod: 'Credit Card',
        remarks: 'Family Plan',
        isActive: true,
        autoLogExpense: true,
      );

      final map = original.toMap();
      final restored = Subscription.fromMap(map);

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
      expect(restored.paymentMethod, original.paymentMethod);
      expect(restored.remarks, original.remarks);
      expect(restored.isActive, true);
      expect(restored.autoLogExpense, true);
    });

    test('Subscription copyWith produces modified clone', () {
      final original = Subscription(
        id: 10,
        profileId: 1,
        title: 'Gym',
        amount: 1000.0,
        categoryId: 5,
        category: 'Health',
        billingCycle: 'Monthly',
        startDate: DateTime(2026, 1, 1),
        nextBillingDate: DateTime(2026, 2, 1),
      );

      final updated = original.copyWith(
        amount: 1200.0,
        nextBillingDate: DateTime(2026, 3, 1),
        isActive: false,
      );

      expect(updated.id, 10);
      expect(updated.title, 'Gym');
      expect(updated.amount, 1200.0);
      expect(updated.nextBillingDate, DateTime(2026, 3, 1));
      expect(updated.isActive, false);
    });
  });
}
