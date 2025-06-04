import 'dart:async';

import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/db/entity.dart';

class PersistenceContext {
  Future<List<Category>> getCategories() async {
    return Future.value([
      Category(1, 'Food'),
      Category(2, 'Transport'),
      Category(3, 'Shopping'),
      Category(4, 'Utilities'),
      Category(5, 'Entertainment'),
      Category(6, 'Health'),
      Category(7, 'Education'),
      Category(8, 'Others'),
    ]);
  }

  Future<void> saveExpense(Expense expense) async {
    await DatabaseHelper().insertExpense(expense);
  }

  Future<List<Expense>> getExpenses() async {
    return await DatabaseHelper().getExpenses();
  }

  Future<int> deleteExpense(int id) async {
    return await DatabaseHelper().deleteExpense(id);
  }

  Future<List<Expense>> getExpensesByDate(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await DatabaseHelper().getExpensesByDate(startDate, endDate);
  }
}
