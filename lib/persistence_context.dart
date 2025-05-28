import 'dart:async';

import 'package:expense_tracker/database_helper.dart';
import 'package:expense_tracker/entity.dart';

class PersistenceContext {
  Future<List<String>> getCategories() async {
    return Future.value([
      'Food',
      'Transport',
      'Shopping',
      'Utilities',
      'Entertainment',
      'Health',
      'Education',
      'Others',
    ]);
  }

  Future<void> saveExpense(Expense expense) async {
    await DatabaseHelper().insertExpense(expense);
  }

  Future<List<Expense>> getExpenses() async {
    return await DatabaseHelper().getExpenses();
  }
}