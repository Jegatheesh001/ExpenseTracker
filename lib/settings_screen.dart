import 'package:expense_tracker/db/persistence_context.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'categories_screen.dart'; // Import the new categories screen
import 'all_tags_screen.dart';
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
  final List<String> _currencies = CurrencySymbol().getCurrencies();
  String _currentCurrency = 'Rupee'; // This will hold the loaded currency

  // Wallet settings
  double _currentWalletAmount = 0.0;
  int _profileId = 0;
  late SharedPreferences _prefs;

  final TextEditingController _walletAmountController = TextEditingController();
  final TextEditingController _deleteConfirmationController = TextEditingController(); // Controller for the delete confirmation text field

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Loads saved settings (theme mode and currency) from shared preferences.
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileId = _prefs.getInt(PrefKeys.profileId) ?? 0;
      _isDarkMode = _prefs.getBool(PrefKeys.isDarkMode) ?? (ThemeMode.system == ThemeMode.dark);
      _currentCurrency = _prefs.getString('${PrefKeys.selectedCurrency}-$_profileId') ?? 'Rupee';
      _currentWalletAmount = _prefs.getDouble('${PrefKeys.walletAmount}-$_profileId') ?? 0.0;
    });
  }

  // Saves the selected theme mode to shared preferences.
  Future<void> _saveThemeMode(bool value) async {
    await _prefs.setBool(PrefKeys.isDarkMode, value);
  }

  // Saves the selected currency to shared preferences.
  Future<void> _saveCurrency(String value) async {
    await _prefs.setString('${PrefKeys.selectedCurrency}-$_profileId', value);
    setState(() {
      _currentCurrency = value;
    });
    widget.onCurrencyToggle();
  }

  // Saves the wallet amount to shared preferences.
  Future<void> _saveWalletAmount(double amount) async {
    await _prefs.setDouble('${PrefKeys.walletAmount}-$_profileId', amount);
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
    _prefs.setInt(PrefKeys.profileId, _profileId);
    widget.onProfileChange();
    // Remove the SnackBar, as the logic is now implemented
    Navigator.pop(context); // Go back to the previous screen
  }
  
  Future<void> _showProfileSwitchConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Switch Profile'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to switch profile?'),
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
              child: const Text('Switch'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _switchProfileId();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
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
                    _deleteConfirmationController.clear();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _deleteConfirmationController.text == 'delete'
                      ? () async {
                          await PersistenceContext().deleteAllExpenseData();
                          widget.onDeleteAllData();
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _deleteConfirmationController.clear();
    });
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionTitle(context, 'Appearance'),
          ListTile(
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: _isDarkMode,
              onChanged: (value) {
                setState(() => _isDarkMode = value);
                widget.onThemeToggle();
                _saveThemeMode(value);
              },
            ),
          ),
          ListTile(
            title: const Text('Currency'),
            trailing: DropdownButton<String>(
              value: _currentCurrency,
              items: _currencies
                  .map((String currency) => DropdownMenuItem<String>(
                        value: currency,
                        child: Text(currency),
                      ))
                  .toList(),
              onChanged: (String? newValue) {
                if (newValue != null) _saveCurrency(newValue);
              },
            ),
          ),
          _buildSectionTitle(context, 'Management'),
          ListTile(
            title: const Text('Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoriesScreen()),
              );
            },
          ),
          ListTile(
            title: const Text('Tags'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AllTagsScreen()),
              );
            },
          ),
          ListTile(
            title: const Text('Expense Limit'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ExpenseLimitScreen(
                          onStatusBarToggle: widget.onStatusBarToggle,
                          onMonthlyLimitSaved: widget.onMonthlyLimitSaved,
                        )),
              );
            },
          ),
          ListTile(
            title: const Text('Wallet Balance'),
            trailing: Text(
              NumberFormat.currency(
                symbol: CurrencySymbol().getSymbol(_currentCurrency),
                decimalDigits: 2,
              ).format(_currentWalletAmount),
            ),
            onTap: _showSetWalletAmountDialog,
          ),
          ListTile(
            title: const Text('Export Data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => DataBackup().exportData(context),
          ),
          ListTile(
            title: const Text('Import Data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => DataBackup().importData(context, widget.onDeleteAllData),
          ),
          _buildSectionTitle(context, 'Profile'),
          ListTile(
            title: const Text('Switch Profile'),
            trailing: Text(
              CurrencySymbol().getLabel(_currentCurrency),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            onTap: _showProfileSwitchConfirmationDialog,
          ),
          _buildSectionTitle(context, 'Danger Zone'),
          ListTile(
            title: const Text('Delete All Data', style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.warning, color: Colors.red),
            onTap: _showDeleteConfirmationDialog,
          ),
        ],
      ),
    );
  }
}