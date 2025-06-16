import 'dart:io'; // For File operations
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/persistence_context.dart';

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

        // 2. Parse content
        for (String line in lines) {
          String trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue; // Skip empty lines

          List<String> parts = trimmedLine.split(';;');
          try {
            if (parts.length == 2) { // Category: ID;;Name
              final category = Category(int.parse(parts[0]), parts[1]);
              categoriesToInsert.add(category);
            } else if (parts.length == 8) { // Expense: ExpenseID;;CategoryID;;Amount;;ExpenseDate;;Timestamp;;Description;;ActiveFLag;;ProfileId
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
                  //profileId: int.parse(parts[7]),
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

      // Add categories first
      for (Category cat in categories) {
        exportContent.writeln('${cat.categoryId};;${cat.category}');
      }

      // Add expenses
      for (Expense exp in expenses) {
        // Format: ExpenseID;;CategoryID;;Amount;;ExpenseDate;;Timestamp;;Description;;ActiveFLag;;ProfileId
        // Note: ActiveFLag and ProfileId are not stored in the current Expense entity.
        // Exporting 'Y' for ActiveFLag and '0' for ProfileId to match the import format example.
        exportContent.writeln(
            '${exp.id};;${exp.categoryId};;${exp.amount};;${exp.expenseDate.toIso8601String()};;${exp.entryDate.toIso8601String()};;${exp.remarks};;Y;;0'
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