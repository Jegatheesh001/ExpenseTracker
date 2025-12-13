import 'dart:io'; // For File operations
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/persistence_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataBackup {
  Future<void> importData(BuildContext context, VoidCallback refreshMainPage) async {
    // 1. Pick file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      try {
        String content = await file.readAsString();
        List<String> lines = content.split('\n');

        List<Category> categoriesToInsert = [];
        List<Expense> expensesToInsert = [];
        List<String> errors = [];

        final prefs = await SharedPreferences.getInstance();

        // 2. Parse content
        for (String line in lines) {
          String trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue; // Skip empty lines

          List<String> parts = trimmedLine.split(';;');
          try {
            if (parts.length == 2) { // SharedPreferences: Key;;Value
              final key = parts[0];
              final valueStr = parts[1];
              if (valueStr.toLowerCase() == 'true' || valueStr.toLowerCase() == 'false') {
                await prefs.setBool(key, valueStr.toLowerCase() == 'true');
              } else if (int.tryParse(valueStr) != null) {
                await prefs.setInt(key, int.parse(valueStr));
              } else if (double.tryParse(valueStr) != null) {
                await prefs.setDouble(key, double.parse(valueStr));
              } else {
                await prefs.setString(key, valueStr);
              }
            } else if (parts.length == 3) { // Category: ID;;Name;;ActiveFlag
              final category = Category(int.parse(parts[0]), parts[1]);
              categoriesToInsert.add(category);
            } else if (parts.length == 9) { // Expense: ExpenseID;;CategoryID;;Amount;;ExpenseDate;;Timestamp;;Description;;ActiveFLag;;ProfileId;;PaymentMethod
              bool isActive = parts[6].toUpperCase() == 'Y';
              if(isActive) {
                int categoryId = int.parse(parts[1]);
                Category category = categoriesToInsert.firstWhere(
                    (cat) => cat.categoryId == categoryId,
                    orElse: () {
                      return Category(categoryId, 'Unknown Category');
                    },
                );
                final expense = Expense(
                  categoryId: categoryId,
                  category: category.category,
                  amount: double.parse(parts[2]),
                  expenseDate: DateTime.parse(parts[3]),
                  entryDate: DateTime.parse(parts[4]),
                  remarks: parts[5],
                  profileId: int.parse(parts[7]),
                  paymentMethod: parts[8] != 'null' ? parts[8] : null,
                );
                //print("expense: \n${expense.toMap()}");
                expensesToInsert.add(expense);
              }
            } else {
              errors.add('Skipping malformed line (incorrect number of parts): $trimmedLine');
            }
          } catch (e) {
            errors.add('Error parsing line "$trimmedLine": $e');
          }
        }

        if (errors.isNotEmpty) {
          // Optionally show detailed errors to the user
          print("Import errors: \n${errors.join('\n')}");
        }

        // 3. Insert into DB
        final db = PersistenceContext();
        for (Category cat in categoriesToInsert) {
          await db.saveCategory(cat); // Replace with your actual method
        }
        //print("Expense count: ${expensesToInsert.length}");
        for (Expense exp in expensesToInsert) {
          await db.saveOrUpdateExpense(exp); // Replace with your actual method
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data imported successfully! ${errors.isEmpty ? "" : "Some lines had issues."}')),
        );
        refreshMainPage(); // Callback to refresh data on home screen
        Navigator.of(context).pop(); // Close settings screen
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error importing data: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File selection cancelled.')));
    }
  }

  Future<void> exportData(BuildContext context) async {
    try {
      // 1. Fetch data from DB
      final db = PersistenceContext();
      List<Category> categories = await db.getCategories();
      List<Expense> expenses = await db.getExpenses();

      // 2. Format data into a string
      StringBuffer exportContent = StringBuffer();

      // Add SharedPreferences data
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (String key in keys) {
        final value = prefs.get(key);
        exportContent.writeln('$key;;$value');
      }

      // Add categories
      for (Category cat in categories) {
        exportContent.writeln('${cat.categoryId};;${cat.category};;Y');
      }

      // Add expenses
      for (Expense exp in expenses) {
        // Format: ExpenseID;;CategoryID;;Amount;;ExpenseDate;;Timestamp;;Description;;ActiveFlag;;ProfileId;;PaymentMethod
        // Note: ActiveFlag is not stored in the current Expense entity. Showing 'Y' as default.
        exportContent.writeln(
            '${exp.id};;${exp.categoryId};;${exp.amount};;${exp.expenseDate.toIso8601String()};;${exp.entryDate.toIso8601String()};;${exp.remarks};;Y;;${exp.profileId};;${exp.paymentMethod}'
        );
      }

      // 3. Save the file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Expense Data',
        fileName: 'expense_data_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
        bytes: utf8.encode(exportContent.toString())
      );

      if (outputFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data exported successfully to $outputFile')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export cancelled.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting data: $e')));
    }
  }
}