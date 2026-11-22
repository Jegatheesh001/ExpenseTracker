import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/persistence_context.dart';
import 'package:expense_tracker/screens/expenses/expenses_screen.dart';
import 'package:expense_tracker/screens/reports/reports_screen.dart';
import 'package:expense_tracker/widgets/expense_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final edit in [true, false]) {
    testWidgets('Expenses ${edit ? 'edit' : 'delete'} refreshes Reports', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final store = _Store();
      await tester.pumpWidget(MaterialApp(home: _Harness(store: store)));
      await tester.pumpAndSettle();
      expect(
        find.text('Total: AED 55.00', skipOffstage: false),
        findsOneWidget,
      );
      final list = tester.widget<ExpenseListView>(find.byType(ExpenseListView));
      if (edit) {
        list.onEdit(store.expense);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save test edit'));
      } else {
        await list.onDelete(store.expense);
      }
      await tester.pumpAndSettle();
      expect(
        find.text(
          edit ? 'Total: AED 75.00' : 'No data for this month.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(store.reportQueries, 2);
    });
  }
}

class _Harness extends StatefulWidget {
  const _Harness({required this.store});
  final _Store store;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int revision = 0;
  final expensesKey = GlobalKey<ExpensesScreenState>();
  void changed() {
    setState(() => revision++);
    expensesKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: 0,
      children: [
        ExpensesScreen(
          key: expensesKey,
          profileId: 1,
          currencySymbol: 'AED ',
          onWalletAmountChange: () {},
          onAddExpense: () {},
          onExpenseChanged: changed,
          persistence: widget.store,
          expenseEditorBuilder: (expense) => Scaffold(
            body: TextButton(
              onPressed: () {
                widget.store.total = 75;
                Navigator.pop(context, true);
              },
              child: const Text('Save test edit'),
            ),
          ),
        ),
        ReportsScreen(
          profileId: 1,
          currencySymbol: 'AED ',
          dataRevision: revision,
          persistence: widget.store,
        ),
      ],
    ),
  );
}

class _Store extends PersistenceContext {
  double total = 55;
  int reportQueries = 0;
  final expense = Expense(
    id: 41,
    profileId: 1,
    categoryId: 1,
    category: 'Food',
    remarks: 'Lunch',
    amount: 55,
    expenseDate: DateTime.now(),
    entryDate: DateTime.now(),
  );
  @override
  Future<List<Category>> getCategories() async => [];
  @override
  Future<List<Expense>> getExpensesByDate(
    DateTime start,
    DateTime end,
    int profileId,
  ) async => total == 0 ? [] : [expense];
  @override
  Future<double> getExpenseSumByDate(DateTime date, int profileId) async => 0;
  @override
  Future<int> deleteExpense(int id, int profileId) async {
    total = 0;
    return 1;
  }

  @override
  Future<Map<String, double>> getCategorySpendingForMonth(
    DateTime date,
    int profileId,
  ) async {
    reportQueries++;
    return total == 0 ? {} : {'Food': total};
  }

  @override
  Future<Map<String, double>> getExpensesForLastFiveMonths(
    int profileId,
  ) async => {};
  @override
  Future<Map<String, double>> getExpensesForLast15Days(int profileId) async =>
      {};
}
