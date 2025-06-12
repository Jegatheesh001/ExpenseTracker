import 'dart:io'; // For File operations
import 'dart:convert';

import 'package:expense_tracker/db/persistence_context.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart'; // For file picking
import 'package:intl/intl.dart';

import 'package:expense_tracker/db/entity.dart'; // Import your Category and Expense entities

import 'categories_screen.dart'; // Import the new categories screen
import 'expense_limit_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final VoidCallback onCurrencyToggle; // Callback for currency change
  final VoidCallback onStatusBarToggle;
  final Function(String) onMonthlyLimitSaved; // Callback for when monthly limit is saved
  final VoidCallback onDeleteAllData; // New callback for data deletion
  const SettingsScreen({
    Key? key,
    required this.onDeleteAllData, // Add the new callback
    required this.onThemeToggle,
    required this.onCurrencyToggle,
    required this.onStatusBarToggle,
    required this.onMonthlyLimitSaved}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  final List<String> _currencies = ['Rupee', 'Dirham', 'Dollar'];
  String _currentCurrency = 'Rupee'; // This will hold the loaded currency
  final TextEditingController _deleteConfirmationController = TextEditingController(); // Controller for the delete confirmation text field

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Loads saved settings (theme mode and currency) from shared preferences.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? (ThemeMode.system == ThemeMode.dark);
      _currentCurrency = prefs.getString('selectedCurrency') ?? 'Rupee';
    });
  }

  // Saves the selected theme mode to shared preferences.
  Future<void> _saveThemeMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  // Saves the selected currency to shared preferences.
  Future<void> _saveCurrency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedCurrency', value);
    setState(() {
      _currentCurrency = value;
    });
    widget.onCurrencyToggle();
  }

  @override
  void dispose() {
    _deleteConfirmationController.dispose(); // Dispose the controller
    super.dispose();
  }

  Future<void> _importData() async {
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
        widget.onDeleteAllData(); // Callback to refresh data on home screen
        Navigator.of(context).pop(); // Close settings screen
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error importing data: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File selection cancelled.')));
    }
  }

  Future<void> _exportData() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dark Mode'),
              Switch(
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                  widget.onThemeToggle();
                  _saveThemeMode(value);
                },
              ),
            ],
          ),
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Currency'),
              DropdownButton<String>(
                value: _currentCurrency,
                items: _currencies.map((String currency) {
                  return DropdownMenuItem<String>(
                    value: currency,
                    child: Text(currency),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    _saveCurrency(newValue);
                  }
                },
              ),
            ],
          ),
           ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0), // Reduce horizontal padding
            title: const Text('Categories'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoriesScreen()),
              );
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0), // Reduce horizontal padding
            title: const Text('Expense Limit'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ExpenseLimitScreen(
                  onStatusBarToggle: widget.onStatusBarToggle, // Pass callback
                  onMonthlyLimitSaved: widget.onMonthlyLimitSaved, // Pass down the new callback
                )),
              );
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            title: const Text('Export Data'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              _exportData();
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            title: const Text('Import Data'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              _importData();
            },
          ),
          // New ListTile for deleting all data
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            title: const Text(
              'Delete All Data',
              style: TextStyle(color: Colors.red), // Mark as danger
            ),
            trailing: const Icon(Icons.warning, color: Colors.red), // Danger icon
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  // Use StatefulBuilder to manage the state of the text field and button
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: const Text('Confirm Data Deletion'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'This action will permanently delete ALL your expense and category data. This cannot be undone.',
                            ),
                            const SizedBox(height: 16.0),
                            const Text('To confirm, type "delete" below:'),
                            TextField(
                              controller: _deleteConfirmationController,
                              onChanged: (value) {
                                // Trigger a rebuild of the dialog to update button state
                                setState(() {});
                              },
                              decoration: const InputDecoration(
                                hintText: 'type "delete" here',
                              ),
                            ),
                          ],
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              _deleteConfirmationController.clear(); // Clear text field on cancel
                              Navigator.of(context).pop(); // Close the dialog
                            },
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            // Enable only if the text matches 'delete'
                            onPressed: _deleteConfirmationController.text == 'delete'
                                ? () async {
                                    await PersistenceContext().deleteAllExpenseData(); // Delete data
                                    widget.onDeleteAllData(); // Call the callback
                                    Navigator.of(context).pop(); // Close the dialog
                                    Navigator.of(context).pop(); // Pop the settings screen
                                  }
                                : null, // Disable the button
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                    },
                  );
                },
              ).then((_) {
                 // Clear the text field after the dialog is dismissed (either by cancel or delete)
                 _deleteConfirmationController.clear();
              });
            },
          ),
        ],
      ),
    );
  }
}