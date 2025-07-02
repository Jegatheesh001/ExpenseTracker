import 'package:expense_tracker/db/persistence_context.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'categories_screen.dart'; // Import the new categories screen
import 'expense_limit_screen.dart';
import 'pref_keys.dart';
import 'currency_symbol.dart';
import 'data_backup.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final VoidCallback onCurrencyToggle; // Callback for currency change
  final VoidCallback onStatusBarToggle;
  final Function(String) onMonthlyLimitSaved; // Callback for when monthly limit is saved
  final VoidCallback onWalletAmountUpdated; // Callback for when wallet amount is updated
  final VoidCallback onDeleteAllData; // New callback for data deletion
  final VoidCallback onProfileChange;
  const SettingsScreen({
    Key? key,
    required this.onDeleteAllData, // Add the new callback
    required this.onThemeToggle,
    required this.onCurrencyToggle,
    required this.onWalletAmountUpdated,
    required this.onStatusBarToggle,
    required this.onMonthlyLimitSaved, 
    required this.onProfileChange}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  final List<String> _currencies = ['Rupee', 'Dirham', 'Dollar'];
  String _currentCurrency = 'Rupee'; // This will hold the loaded currency

  // Wallet settings
  double _currentWalletAmount = 0.0;
  int _profileId = 0;

  final TextEditingController _walletAmountController = TextEditingController();
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
      _isDarkMode = prefs.getBool(PrefKeys.isDarkMode) ?? (ThemeMode.system == ThemeMode.dark);
      _currentCurrency = prefs.getString(PrefKeys.selectedCurrency) ?? 'Rupee';
      _currentWalletAmount = prefs.getDouble(PrefKeys.walletAmount) ?? 0.0;
      _profileId = prefs.getInt(PrefKeys.profileId) ?? 0;
    });
  }

  // Saves the selected theme mode to shared preferences.
  Future<void> _saveThemeMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.isDarkMode, value);
  }

  // Saves the selected currency to shared preferences.
  Future<void> _saveCurrency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.selectedCurrency, value);
    setState(() {
      _currentCurrency = value;
    });
    widget.onCurrencyToggle();
  }

  // Saves the wallet amount to shared preferences.
  Future<void> _saveWalletAmount(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(PrefKeys.walletAmount, amount);
    setState(() {
      _currentWalletAmount = amount;
    });
    widget.onWalletAmountUpdated.call();
  }

  @override
  void dispose() {
    _deleteConfirmationController.dispose(); // Dispose the controller
    _walletAmountController.dispose(); // Dispose wallet controller
    super.dispose();
  }

  Future<void> _showSetWalletAmountDialog() async {
    _walletAmountController.text = _currentWalletAmount.toStringAsFixed(2); // Pre-fill with current amount
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Set Wallet Balance'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Enter your current wallet balance.'),
                TextField(
                  controller: _walletAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: '${CurrencySymbol().getSymbol(_currentCurrency)} ',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                final double? newAmount = double.tryParse(_walletAmountController.text);
                if (newAmount != null && newAmount >= 0) {
                  _saveWalletAmount(newAmount);
                  Navigator.of(dialogContext).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid non-negative amount.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _switchProfileId() async {
    if(_profileId == 0) {
      _profileId = 1;
    } else {
      _profileId = 0;
    }
    setState(() {
      _profileId = _profileId;
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(PrefKeys.profileId, _profileId);
    widget.onProfileChange();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logic not implemented yet')));
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
            title: const Text('Wallet Balance'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  NumberFormat.currency(
                    symbol: CurrencySymbol().getSymbol(_currentCurrency),
                    decimalDigits: 2,
                  ).format(_currentWalletAmount),
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
              ],
            ),
            onTap: _showSetWalletAmountDialog,
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            title: const Text('Switch Profile'),
            trailing: Text(
              CurrencySymbol().getLabel(_currentCurrency),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
            onTap: () {
              _switchProfileId();
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            title: const Text('Export Data'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
             DataBackup().exportData(context);
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            title: const Text('Import Data'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              DataBackup().importData(context, widget.onDeleteAllData);
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