import 'dart:async';

import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/db/entity.dart';

class PersistenceContext {
  // Retrieves all categories from the database.
  Future<List<Category>> getCategories() async {
    return DatabaseHelper().getCategories();
  }

  // Saves a new expense or updates an existing one.
  Future<int> saveOrUpdateExpense(Expense expense) async {
    return await DatabaseHelper().saveOrUpdateExpense(expense);
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
    int profileId
  ) async {
    return await DatabaseHelper().getExpensesByDate(startDate, endDate, profileId);
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
  Future<double> getExpenseSumByDate(DateTime date, int profileId) async {
    return await DatabaseHelper().getExpenseSumByDate(date, profileId);
  }

  Future<List<String>> searchTags(String query) async {
    return await DatabaseHelper().searchTags(query);
  }

  Future<double> getExpenseSumByMonth(DateTime date, int profileId) async {
    return await DatabaseHelper().getExpenseSumByMonth(date, profileId);
  }

  Future<void> deleteAllExpenseData() async {
    await DatabaseHelper().deleteAllExpenseData();
  }

  Future<Map<String, double>> getCategorySpendingForMonth(DateTime date, int profileId) async {
    return await DatabaseHelper().getCategorySpendingForMonth(date, profileId);
  }

  Future<Map<String, double>> getTagSpendingForMonth(DateTime date, int profileId) async {
    return await DatabaseHelper().getTagSpendingForMonth(date, profileId);
  }

  Future<Map<String, double>> getExpensesForLastFiveMonths(int profileId) async {
    return await DatabaseHelper().getExpensesForLastFiveMonths(profileId);
  }

  Future<List<Expense>> getExpensesByTag(String tag, int profileId) async {
    return await DatabaseHelper().getExpensesByTag(tag, profileId);
  }

  Future<List<String>> getAllTags() async {
    return await DatabaseHelper().getAllTags();
  }

  Future<List<Map<String, dynamic>>> getAllTagsByProfile(int profileId) async {
    return await DatabaseHelper().getAllTagsByProfile(profileId);
  }

  Future<List<String>> getTagsForRemark(String remarkQuery) async {
    return await DatabaseHelper().getTagsForRemark(remarkQuery);
  }

  Future<Category?> getCategoryForRemark(String remarks) async {
    return await DatabaseHelper().getCategoryForRemark(remarks);
  }

  Future<Map<String, double>> getExpensesForLast15Days(int profileId) async {
    return await DatabaseHelper().getExpensesForLast15Days(profileId);
  }
}
