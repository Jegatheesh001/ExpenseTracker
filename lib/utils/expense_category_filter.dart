import 'package:expense_tracker/db/entity.dart';

List<Expense> filterExpensesByCategory(
  Iterable<Expense> expenses,
  int? categoryId,
) {
  if (categoryId == null) {
    return expenses.toList(growable: false);
  }

  return expenses
      .where((expense) => expense.categoryId == categoryId)
      .toList(growable: false);
}
