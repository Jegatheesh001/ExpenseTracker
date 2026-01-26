import 'dart:io'; // For File operations
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:expense_tracker/pref_keys.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/persistence_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataBackup {
  Future<void> importData(BuildContext context, VoidCallback refreshMainPage) async {
    // Picking a file from the device
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
        List<Tag> tagsToInsert = [];
        List<Map<String, int>> expenseTagsToInsert = [];
        List<String> errors = [];

        final prefs = await SharedPreferences.getInstance();
        final db = PersistenceContext();

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
            } else if (parts.length == 3) {
              if (parts[0] == 'CATEGORY') {
                categoriesToInsert.add(Category(int.parse(parts[1]), parts[2]));
              } else if (parts[0] == 'TAG') {
                tagsToInsert.add(Tag(int.parse(parts[1]), parts[2]));
              } else if (parts[0] == 'EXPENSE_TAG') {
                expenseTagsToInsert.add({
                  'expenseId': int.parse(parts[1]),
                  'tagId': int.parse(parts[2]),
                });
              }
            } else if (parts.length == 4 && parts[0] == 'IMAGE') {
              final expenseId = int.parse(parts[1]);
              final imageName = parts[2];
              final base64String = parts[3];

              final decodedBytes = base64Decode(base64String);
              final directory = await getApplicationDocumentsDirectory();
              final imagesDirectory = Directory(join(directory.path, 'attachments', expenseId.toString()));
              if (!await imagesDirectory.exists()) {
                await imagesDirectory.create(recursive: true);
              }
              final imageFile = File(join(imagesDirectory.path, imageName));
              await imageFile.writeAsBytes(decodedBytes);

            } else if (parts.length == 9) {
              bool isActive = parts[6].toUpperCase() == 'Y';
              if(isActive) {
                int categoryId = int.parse(parts[1]);
                Category category = categoriesToInsert.firstWhere(
                    (cat) => cat.categoryId == categoryId,
                    orElse: () => Category(categoryId, 'Unknown Category'),
                );
                final expense = Expense(
                  id: int.parse(parts[0]),
                  categoryId: categoryId,
                  category: category.category,
                  amount: double.parse(parts[2]),
                  expenseDate: DateTime.parse(parts[3]),
                  entryDate: DateTime.parse(parts[4]),
                  remarks: parts[5],
                  profileId: int.parse(parts[7]),
                  paymentMethod: parts[8] != 'null' ? parts[8] : null,
                );
                expensesToInsert.add(expense);
              }
            } else {
              errors.add('Skipping malformed line: $trimmedLine');
            }
          } catch (e) {
            errors.add('Error parsing line "$trimmedLine": $e');
          }
        }

        if (errors.isNotEmpty) {
          print("Import errors: \n${errors.join('\n')}");
        }

        for (Category cat in categoriesToInsert) {
          await db.saveCategory(cat);
        }
        for (Expense exp in expensesToInsert) {
          await db.saveExpense(exp);
        }
        for (Tag tag in tagsToInsert) {
          await db.saveTag(tag);
        }
        for (var et in expenseTagsToInsert) {
          await db.saveExpenseTag(et['expenseId']!, et['tagId']!);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data imported successfully! ${errors.isEmpty ? "" : "Some lines had issues."}')),
        );
        refreshMainPage();
        Navigator.of(context).pop();
      } catch (e) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error importing data: $e',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File selection cancelled.')));
    }
  }

  Future<void> exportData(BuildContext context, {bool includeImages = false}) async {
    try {
      final theme = Theme.of(context);
      // 1. Fetch data from DB
      final db = PersistenceContext();
      List<Category> categories = await db.getCategories();
      List<Expense> expenses = await db.getExpenses();
      List<Tag> tags = await db.getAllTagsWithId();
      List<Map<String, dynamic>> expenseTags = await db.getAllExpenseTags();

      StringBuffer exportContent = StringBuffer();

      // 2. Fetch data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith('${PrefKeys.lastAIInsights}_')) {
          continue;
        }
        final value = prefs.get(key);
        exportContent.writeln('$key;;$value');
      }

      // Inserting categories, tags, expenses, and expense-tags
      for (Category cat in categories) {
        exportContent.writeln('CATEGORY;;${cat.categoryId};;${cat.category}');
      }

      for (Tag tag in tags) {
        exportContent.writeln('TAG;;${tag.tagId};;${tag.tagName}');
      }

      for (Expense exp in expenses) {
        // Format: ExpenseID;;CategoryID;;Amount;;ExpenseDate;;Timestamp;;Description;;ActiveFlag;;ProfileId;;PaymentMethod
        // Note: ActiveFlag is not stored in the current Expense entity. Showing 'Y' as default.
        exportContent.writeln(
            '${exp.id};;${exp.categoryId};;${exp.amount};;${exp.expenseDate.toIso8601String()};;${exp.entryDate.toIso8601String()};;${exp.remarks};;Y;;${exp.profileId};;${exp.paymentMethod}');
      }

      for (var et in expenseTags) {
        exportContent.writeln('EXPENSE_TAG;;${et['expenseId']};;${et['tagId']}');
      }

      if (includeImages) {
        final directory = await getApplicationDocumentsDirectory();
        for (Expense exp in expenses) {
          if (exp.id == null) continue;
          final imagesDirectory = Directory(join(directory.path, 'attachments', exp.id.toString()));
          if (await imagesDirectory.exists()) {
            final files = imagesDirectory.listSync().whereType<File>().toList();
            for (var file in files) {
              final bytes = await file.readAsBytes();
              final base64String = base64Encode(bytes);
              exportContent.writeln('IMAGE;;${exp.id};;${basename(file.path)};;$base64String');
            }
          }
        }
      }

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Expense Data',
        fileName: 'expense_data_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
        bytes: utf8.encode(exportContent.toString())
      );

      if (outputFile != null) {
        prefs.setInt(PrefKeys.lastBackupTimestamp, DateTime.now().millisecondsSinceEpoch);
        prefs.setInt(PrefKeys.lastBackupReminderTimestamp, DateTime.now().millisecondsSinceEpoch);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data exported successfully to $outputFile')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export cancelled.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting data: $e')));
    }
  }
}