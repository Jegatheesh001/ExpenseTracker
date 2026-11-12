import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/utils/expense_category_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final expenses = <Expense>[
    Expense(
      id: 1,
      profileId: 0,
      categoryId: 1,
      category: 'Food',
      amount: 12,
      remarks: 'Lunch',
      expenseDate: DateTime(2026, 11, 12, 12),
      entryDate: DateTime(2026, 11, 12, 12),
    ),
    Expense(
      id: 2,
      profileId: 0,
      categoryId: 2,
      category: 'Transport',
      amount: 8,
      remarks: 'Taxi',
      expenseDate: DateTime(2026, 11, 12, 18),
      entryDate: DateTime(2026, 11, 12, 18),
    ),
  ];

  test('no category selection keeps every expense', () {
    final filtered = filterExpensesByCategory(expenses, null);

    expect(filtered.map((expense) => expense.id), [1, 2]);
  });

  test('category selection filters by stable category id', () {
    final filtered = filterExpensesByCategory(expenses, 2);

    expect(filtered.map((expense) => expense.id), [2]);
  });

  test('category with no expenses returns an empty list', () {
    expect(filterExpensesByCategory(expenses, 99), isEmpty);
  });
}
