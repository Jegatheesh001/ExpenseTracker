import 'dart:async';

import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/persistence_context.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/screens/reports/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Reports refreshes its totals on profile and data changes', (
    tester,
  ) async {
    final persistence = _ReportPersistence();

    Future<void> showReports(int profileId, int revision) => tester.pumpWidget(
      MaterialApp(
        home: ReportsScreen(
          profileId: profileId,
          currencySymbol: profileId == 0 ? 'â‚¹' : 'AED ',
          dataRevision: revision,
          persistence: persistence,
        ),
      ),
    );

    await showReports(0, 0);
    await showReports(1, 0);
    await tester.pumpAndSettle();
    expect(find.text('Total: AED 55.00'), findsOneWidget);

    persistence.oldProfile.complete({'Groceries': 999});
    await tester.pumpAndSettle();
    expect(find.text('Total: AED 55.00'), findsOneWidget);
    expect(find.textContaining('999.00'), findsNothing);

    persistence.activeTotal += 20;
    await showReports(1, 1);
    await tester.pumpAndSettle();
    expect(find.text('Total: AED 75.00'), findsOneWidget);
    expect(persistence.dailyProfiles, [0, 1, 1]);
    expect(persistence.monthlyProfiles, [0, 1, 1]);
  });
  for (final byTag in [false, true]) {
    testWidgets(
      'Report deletion refreshes totals through ${byTag ? 'Tags' : 'Category'}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({'profileId': 0});
        final persistence = _ReportPersistence();
        await tester.pumpWidget(
          MaterialApp(
            home: ReportsScreen(
              profileId: 1,
              currencySymbol: 'AED ',
              persistence: persistence,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (byTag) {
          await tester.tap(find.text('Tags'));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.textContaining(byTag ? 'subscription:' : 'Groceries:'),
        );
        await tester.pumpAndSettle();
        if (byTag) {
          await tester.tap(find.byType(ExpansionTile));
          await tester.pumpAndSettle();
          await tester.drag(
            find.text('Recurring Subscription: Example'),
            const Offset(-450, 0),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete'));
        } else {
          await tester.longPress(find.text('Recurring Subscription: Example'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Confirm Delete'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(persistence.deleted, [(41, 1)]);
        expect(find.text('Recurring Subscription: Example'), findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.textContaining(byTag ? 'subscription:' : 'Groceries:'),
          findsNothing,
        );
        expect(find.text('No data for this month.'), findsOneWidget);
      },
    );
  }
}

class _ReportPersistence extends PersistenceContext {
  final oldProfile = Completer<Map<String, double>>();
  final dailyProfiles = <int>[];
  final monthlyProfiles = <int>[];
  double activeTotal = 55;
  final deleted = <(int, int)>[];
  final expense = Expense(
    id: 41,
    profileId: 1,
    categoryId: 1,
    category: 'Groceries',
    remarks: 'Recurring Subscription: Example',
    expenseDate: DateTime(2026, 11, 22),
    entryDate: DateTime(2026, 11, 22),
    amount: 55,
    paymentMethod: 'bank',
  );

  @override
  Future<int> deleteExpense(int id, int profileId) async {
    deleted.add((id, profileId));
    return 1;
  }

  @override
  Future<Map<String, double>> getTagSpendingForMonth(
    DateTime date,
    int profileId,
  ) async => deleted.isEmpty ? {'subscription': activeTotal} : {};

  @override
  Future<List<Expense>> getExpensesByCategoryForMonth(
    String category,
    DateTime month,
    int profileId,
  ) async => deleted.isEmpty ? [expense] : [];

  @override
  Future<List<Expense>> getExpensesByTagAndMonth(
    String tag,
    DateTime month,
    int profileId,
  ) async {
    expect(profileId, 1);
    return deleted.isEmpty ? [expense] : [];
  }

  @override
  Future<Map<String, double>> getCategorySpendingForMonth(
    DateTime date,
    int profileId,
  ) async => profileId == 0
      ? oldProfile.future
      : (deleted.isEmpty ? {'Groceries': activeTotal} : {});

  @override
  Future<Map<String, double>> getExpensesForLastFiveMonths(
    int profileId,
  ) async {
    monthlyProfiles.add(profileId);
    return {};
  }

  @override
  Future<Map<String, double>> getExpensesForLast15Days(int profileId) async {
    dailyProfiles.add(profileId);
    return {};
  }
}
