import 'dart:async';

import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/db/entity.dart';

class PersistenceContext {
  // Retrieves all categories from the database.
  Future<List<Category>> getCategories() async {
    return DatabaseHelper().getCategories();
  }

  // Saves a new expense or updates an existing one.
  Future<void> saveOrUpdateExpense(Expense expense) async {
    if (expense.id == null) {
      await DatabaseHelper().insertExpense(expense);
    } else {
      await DatabaseHelper().updateExpense(expense);
    }
  }

  // Retrieves all expenses from the database.
  Future<List<Expense>> getExpenses() async {
    return await DatabaseHelper().getExpenses();
  }

  // Deletes an expense by its ID.
  Future<int> deleteExpense(int id) async {
    return await DatabaseHelper().deleteExpense(id);
  }

  // Retrieves expenses within a specific date range.
  Future<List<Expense>> getExpensesByDate(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await DatabaseHelper().getExpensesByDate(startDate, endDate);
  }

  // Saves a new category to the database.
  Future<void> saveCategory(Category newCategory) async {
    await DatabaseHelper().saveCategory(newCategory);
  }

  // Deletes a category by its ID.
  Future<bool> deleteCategory(int id) async {
    return await DatabaseHelper().deleteCategory(id);
  }

  // Retrieves the sum of expenses for a specific date.
  Future<double> getExpenseSumByDate(DateTime date) async {
    return await DatabaseHelper().getExpenseSumByDate(date);
  }

  Future<double> getExpenseSumByMonth(DateTime date) async {
    return await DatabaseHelper().getExpenseSumByMonth(date);
  }
}
