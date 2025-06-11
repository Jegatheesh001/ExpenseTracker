import 'package:expense_tracker/db/persistence_context.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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