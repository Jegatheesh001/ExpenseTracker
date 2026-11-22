import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/widgets/subscription_payment_options_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required PaymentMethod alternative,
    required double balance,
    required ValueChanged<PaymentMethod?> onClose,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                onClose(
                  await showDialog<PaymentMethod>(
                    context: context,
                    builder: (_) => SubscriptionPaymentOptionsDialog(
                      subscriptionTitle: 'Example subscription',
                      alternative: alternative,
                      alternativeBalance: balance,
                      amount: 20,
                      currency: 'AED',
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('suggests a funded bank account when cash is insufficient', (
    tester,
  ) async {
    PaymentMethod? choice;
    await open(
      tester,
      alternative: PaymentMethod.bank,
      balance: 20,
      onClose: (value) => choice = value,
    );
    expect(find.text('Insufficient cash balance'), findsOneWidget);
    expect(find.text('AED 20.00 available in bank'), findsOneWidget);
    await tester.tap(find.text('Use bank'));
    await tester.pumpAndSettle();
    expect(choice, PaymentMethod.bank);
  });

  testWidgets('offers None when the alternative account is also short', (
    tester,
  ) async {
    PaymentMethod? choice;
    await open(
      tester,
      alternative: PaymentMethod.cash,
      balance: 10,
      onClose: (value) => choice = value,
    );
    expect(find.text('Insufficient bank balance'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Use cash'))
          .enabled,
      isFalse,
    );
    expect(find.text('Log the expense without a wallet debit'), findsOneWidget);
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    expect(choice, PaymentMethod.none);
  });

  testWidgets('Cancel returns without a payment choice', (tester) async {
    PaymentMethod? choice = PaymentMethod.none;
    await open(
      tester,
      alternative: PaymentMethod.bank,
      balance: 30,
      onClose: (value) => choice = value,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(choice, isNull);
  });
}
