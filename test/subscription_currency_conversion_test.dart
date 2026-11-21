import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/services/currency_conversion_service.dart';
import 'package:expense_tracker/widgets/add_subscription_dialog.dart';
import 'package:expense_tracker/db/entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => CurrencyConversionService.setMockInstance(null));

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AddSubscriptionSheet(
              profileId: 0,
              currencySymbol: '₹',
              currentCurrency: 'Rupee',
              initialCategories: [Category(1, 'Entertainment')],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectCurrency(WidgetTester tester, String name) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    // Pump the dropdown animation without waiting on any rate indicator.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text(name).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  http.Response rateResponse(String base, num rate) => http.Response(
    jsonEncode({'base': base, 'quote': 'INR', 'rate': rate}),
    200,
  );

  testWidgets(
    'Looks up only valid foreign amounts and reuses rates while typing',
    (tester) async {
      final requests = <Uri>[];
      CurrencyConversionService.setMockInstance(
        CurrencyConversionService(
          client: MockClient((request) async {
            requests.add(request.url);
            return rateResponse('AED', 25.308);
          }),
        ),
      );

      await openSheet(tester);
      final field = find.widgetWithText(TextFormField, 'Amount *');
      await tester.enterText(field, '10');
      await tester.pumpAndSettle();
      expect(requests, isEmpty);

      await tester.enterText(field, '');
      await selectCurrency(tester, 'د.إ Dirham');
      expect(requests, isEmpty);
      await tester.enterText(field, 'Infinity');
      await tester.pumpAndSettle();
      expect(requests, isEmpty);

      await tester.enterText(field, '10');
      await tester.pumpAndSettle();
      expect(find.textContaining('≈ ₹253.08 INR'), findsOneWidget);

      await tester.enterText(field, '20');
      await tester.pumpAndSettle();
      expect(find.textContaining('≈ ₹506.16 INR'), findsOneWidget);
      expect(requests.single.path, '/v2/rate/AED/INR');

      await selectCurrency(tester, '₹ Rupee');
      expect(find.textContaining('via Frankfurter'), findsNothing);
      expect(requests, hasLength(1));
    },
  );

  testWidgets('Ignores an older rate after the selected currency changes', (
    tester,
  ) async {
    final dirham = Completer<http.Response>();
    CurrencyConversionService.setMockInstance(
      CurrencyConversionService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/AED/INR')) return dirham.future;
          return rateResponse('USD', 90);
        }),
      ),
    );

    await openSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount *'),
      '10',
    );
    await selectCurrency(tester, 'د.إ Dirham');
    await selectCurrency(tester, r'$ Dollar');
    await tester.pumpAndSettle();
    expect(find.textContaining('≈ ₹900.00 INR'), findsOneWidget);

    dirham.complete(rateResponse('AED', 25));
    await tester.pumpAndSettle();
    expect(find.textContaining('≈ ₹900.00 INR'), findsOneWidget);
    expect(find.textContaining('≈ ₹250.00 INR'), findsNothing);
  });

  test('Monthly estimate omits foreign amounts with no rate', () {
    Subscription subscription(double amount, String currency) => Subscription(
      profileId: 0,
      title: currency,
      amount: amount,
      categoryId: 1,
      category: 'Bills',
      billingCycle: 'Monthly',
      startDate: DateTime(2026, 1, 1),
      nextBillingDate: DateTime(2026, 2, 1),
      currency: currency,
    );

    final estimate = CurrencyConversionService.monthlyEstimate(
      [
        subscription(500, 'INR'),
        subscription(10, 'Dirham'),
        subscription(20, 'Dollar'),
        subscription(0, 'GBP'),
        subscription(10, 'unrecognized'),
      ],
      'Rupee',
      {'AED': 25.0},
    );
    expect(estimate, (total: 750.0, unavailable: 2, converted: true));
  });
}
