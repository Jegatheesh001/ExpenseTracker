import 'dart:async';

import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/db/entity.dart';

class PersistenceContext {
  Future<List<Category>> getCategories() async {
    return DatabaseHelper().getCategories();
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
