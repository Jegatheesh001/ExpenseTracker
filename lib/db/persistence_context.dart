import 'dart:async';

import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/db/entity.dart';

class PersistenceContext {
  Future<List<Category>> getCategories() async {
    return DatabaseHelper().getCategories();
  }

  Future<void> saveOrUpdateExpense(Expense expense) async {
    if (expense.id == null) {
      await DatabaseHelper().insertExpense(expense);
    } else {
      await DatabaseHelper().updateExpense(expense);
    }
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

  Future<void> saveCategory(Category newCategory) async {
    await DatabaseHelper().saveCategory(newCategory);
  }

  Future<bool> deleteCategory(int id) async {
    return await DatabaseHelper().deleteCategory(id);
  }
}
