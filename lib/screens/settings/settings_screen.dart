import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'package:expense_tracker/db/persistence_context.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'package:expense_tracker/screens/categories/categories_screen.dart'; // Import the new categories screen
import 'package:expense_tracker/screens/categories/all_tags_screen.dart';
import 'package:expense_tracker/screens/expenses/expense_limit_screen.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:expense_tracker/utils/currency_symbol.dart';
import 'package:expense_tracker/services/data_backup.dart';
import 'package:expense_tracker/screens/settings/developer_mode_screen.dart';
import 'package:expense_tracker/screens/ai/ai_settings_screen.dart';
import 'package:expense_tracker/screens/subscriptions/subscriptions_screen.dart';
import 'package:expense_tracker/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final VoidCallback onCurrencyToggle; // Callback for currency change
  final VoidCallback onStatusBarToggle;
  final Function(String) onMonthlyLimitSaved; // Callback for when monthly limit is saved
  final VoidCallback onWalletAmountUpdated; // Callback for when wallet amount is updated
  final VoidCallback onDeleteAllData; // New callback for data deletion
  final VoidCallback onProfileChange;
  final VoidCallback onUsernameChange;

  const SettingsScreen({
    super.key,
    required this.onDeleteAllData, // Add the new callback
    required this.onThemeToggle,
    required this.onCurrencyToggle,
    required this.onWalletAmountUpdated,
    required this.onStatusBarToggle,
    required this.onMonthlyLimitSaved, 
    required this.onProfileChange,
    required this.onUsernameChange
  });

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _isBackupReminderEnabled = false;
  final List<String> _currencies = CurrencySymbol().getCurrencies();
  String _currentCurrency = 'Rupee'; // This will hold the loaded currency

  // Wallet settings
  double _currentWalletAmount = 0.0;
  double _cashAmount = 0.0;
  double _bankAmount = 0.0;

  int _profileId = 0;
  late SharedPreferences _prefs;
  int? _lastBackupTimestamp;
  String _username = '';
  bool _isDeveloperMode = false;

  // Notification settings
  bool _isDailyReminderEnabled = false;
  int _dailyReminderHour = 21;
  int _dailyReminderMinute = 0;
  bool _isSubscriptionRemindersEnabled = true;
  int _subscriptionReminderAdvanceDays = 1;

  final TextEditingController _walletAmountController = TextEditingController();
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _bankAmountController = TextEditingController();
  final TextEditingController _deleteConfirmationController = TextEditingController(); // Controller for the delete confirmation text field

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> refresh() async {
    await _loadSettings();
  }

  // Loads saved settings (theme mode and currency) from shared preferences.
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    await _prefs.reload();
    setState(() {
      _profileId = _prefs.getInt(PrefKeys.profileId) ?? 0;
      _username = _prefs.getString(PrefKeys.username) ?? '';
      _isDarkMode = _prefs.getBool(PrefKeys.isDarkMode) ?? (ThemeMode.system == ThemeMode.dark);
      _isDeveloperMode = _prefs.getBool(PrefKeys.isDeveloperMode) ?? false;
      _isBackupReminderEnabled = _prefs.getBool(PrefKeys.dailyBackupReminderEnabled) ?? false;
      _currentCurrency = _prefs.getString('${PrefKeys.selectedCurrency}-$_profileId') ?? 'Rupee';
      _cashAmount = _prefs.getDouble('${PrefKeys.cashAmount}-$_profileId') ?? 0.0;
      _bankAmount = _prefs.getDouble('${PrefKeys.bankAmount}-$_profileId') ?? 0.0;
      _lastBackupTimestamp = _prefs.getInt(PrefKeys.lastBackupTimestamp);
      _isDailyReminderEnabled = _prefs.getBool(PrefKeys.dailyReminderEnabled) ?? false;
      _dailyReminderHour = _prefs.getInt(PrefKeys.dailyReminderHour) ?? 21;
      _dailyReminderMinute = _prefs.getInt(PrefKeys.dailyReminderMinute) ?? 0;
      _isSubscriptionRemindersEnabled = _prefs.getBool(PrefKeys.subscriptionRemindersEnabled) ?? true;
      _subscriptionReminderAdvanceDays = _prefs.getInt(PrefKeys.subscriptionReminderAdvanceDays) ?? 1;

      double walletAmount = _prefs.getDouble('${PrefKeys.walletAmount}-$_profileId') ?? 0.0;

      if (_cashAmount == 0.0 && _bankAmount == 0.0 && walletAmount > 0.0) {
        _cashAmount = walletAmount;
        _saveAmounts();
      }

      _currentWalletAmount = _cashAmount + _bankAmount;
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
  Future<void> _saveAmounts() async {
    await _prefs.setDouble('${PrefKeys.cashAmount}-$_profileId', _cashAmount);
    await _prefs.setDouble('${PrefKeys.bankAmount}-$_profileId', _bankAmount);
    await _prefs.setDouble('${PrefKeys.walletAmount}-$_profileId', _cashAmount + _bankAmount);
    setState(() {
      _currentWalletAmount = _cashAmount + _bankAmount;
    });
    widget.onWalletAmountUpdated.call();
  }

  @override
  void dispose() {
    _deleteConfirmationController.dispose(); // Dispose the controller
    _walletAmountController.dispose(); // Dispose wallet controller
    _cashAmountController.dispose();
    _bankAmountController.dispose();
    super.dispose();
  }

  Future<void> _showSetWalletAmountDialog() async {
    _cashAmountController.text = _cashAmount.toStringAsFixed(2);
    _bankAmountController.text = _bankAmount.toStringAsFixed(2);

    double tempCashAmount = _cashAmount;
    double tempBankAmount = _bankAmount;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // We get the theme once to keep code clean
        final theme = Theme.of(context);
        final currency = CurrencySymbol().getSymbol(_currentCurrency);

        return StatefulBuilder(
          builder: (context, setState) {
            // Calculate total for the display
            final total = (tempCashAmount + tempBankAmount).toStringAsFixed(2);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0), // Softer corners
              ),
              titlePadding: EdgeInsets.zero, // We will handle our own padding
              title: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Balance',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$currency $total',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 10),
                    // CASH INPUT
                    TextField(
                      controller: _cashAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Cash Amount',
                        prefixText: '$currency ',
                        prefixIcon: const Icon(Icons.money_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      onChanged: (value) {
                        setState(() {
                          tempCashAmount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // BANK INPUT
                    TextField(
                      controller: _bankAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Bank Amount',
                        prefixText: '$currency ',
                        prefixIcon: const Icon(Icons.account_balance_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      onChanged: (value) {
                        setState(() {
                          tempBankAmount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              actions: <Widget>[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                        ),
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Update'),
                        onPressed: () {
                          final double? newCashAmount = double.tryParse(
                            _cashAmountController.text,
                          );
                          final double? newBankAmount = double.tryParse(
                            _bankAmountController.text,
                          );

                          if (newCashAmount != null &&
                              newCashAmount >= 0 &&
                              newBankAmount != null &&
                              newBankAmount >= 0) {
                            _cashAmount = newCashAmount;
                            _bankAmount = newBankAmount;
                            _saveAmounts();
                            Navigator.of(dialogContext).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Please enter valid non-negative amounts.',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditUsernameDialog() async {
    final nameController = TextEditingController(text: _username);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Username'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: "Your Name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                final name = nameController.text;
                if (name.isNotEmpty) {
                  _prefs.setString(PrefKeys.username, name);
                  setState(() {
                    _username = name;
                  });
                  widget.onUsernameChange();
                  Navigator.of(context).pop();
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
    _prefs.setInt(PrefKeys.profileId, _profileId);
    widget.onProfileChange();
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
                          // Removing all data from the database
                          await PersistenceContext().deleteAllExpenseData();
                          // Removing SharedPreferences data
                          final prefs = await SharedPreferences.getInstance();
                          prefs.clear();
                          // Removing all attachments from folders
                          final directory = await getApplicationDocumentsDirectory();
                          final attachmentsDir = Directory(path.join(directory.path, 'attachments'));
                          if (await attachmentsDir.exists()) {
                            await attachmentsDir.delete(recursive: true);
                          }
                          await NotificationService().cancelAllNotifications();
                          
                          widget.onDeleteAllData();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
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

  Future<void> _showExportOptionsDialog() async {
    await _loadSettings();
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        String lastBackup = 'Never';
        if (_lastBackupTimestamp != null) {
          final lastBackupDate = DateTime.fromMillisecondsSinceEpoch(_lastBackupTimestamp!);
          lastBackup = DateFormat('dd-MM-yyyy hh:mm aa').format(lastBackupDate);
        }
        return AlertDialog(
          title: const Text('Export Data'),
          content: const Text('Include images in the backup?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Without Images'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await DataBackup().exportData(context, includeImages: false);
                await _prefs.reload();
                setState(() {
                  _lastBackupTimestamp = _prefs.getInt(PrefKeys.lastBackupTimestamp);
                });
              },
            ),
            TextButton(
              child: const Text('With Images'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await DataBackup().exportData(context, includeImages: true);
                await _prefs.reload();
                setState(() {
                  _lastBackupTimestamp = _prefs.getInt(PrefKeys.lastBackupTimestamp);
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
              child: Text(
                'Last backup: $lastBackup',
                style: Theme.of(context).textTheme.bodySmall, 
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatReminderTime(int hour, int minute) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, hour, minute);
    return DateFormat('hh:mm a').format(dt);
  }

  String _getAdvanceDaysLabel(int days) {
    if (days == 0) return 'On renewal day (9:00 AM)';
    if (days == 1) return '1 day before renewal (9:00 AM)';
    return '$days days before renewal (9:00 AM)';
  }

  Future<void> _toggleDailyReminder(bool value) async {
    setState(() {
      _isDailyReminderEnabled = value;
    });
    await _prefs.setBool(PrefKeys.dailyReminderEnabled, value);
    if (value) {
      await NotificationService().requestPermissions();
    }
    await NotificationService().scheduleDailyReminder(
      enabled: value,
      hour: _dailyReminderHour,
      minute: _dailyReminderMinute,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'Daily reminder scheduled for ${_formatReminderTime(_dailyReminderHour, _dailyReminderMinute)}'
              : 'Daily reminder turned off'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickDailyReminderTime() async {
    final TimeOfDay initialTime = TimeOfDay(
      hour: _dailyReminderHour,
      minute: _dailyReminderMinute,
    );
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null) {
      setState(() {
        _dailyReminderHour = pickedTime.hour;
        _dailyReminderMinute = pickedTime.minute;
      });
      await _prefs.setInt(PrefKeys.dailyReminderHour, pickedTime.hour);
      await _prefs.setInt(PrefKeys.dailyReminderMinute, pickedTime.minute);
      if (_isDailyReminderEnabled) {
        await NotificationService().scheduleDailyReminder(
          enabled: true,
          hour: pickedTime.hour,
          minute: pickedTime.minute,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reminder time set to ${_formatReminderTime(pickedTime.hour, pickedTime.minute)}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleSubscriptionReminders(bool value) async {
    setState(() {
      _isSubscriptionRemindersEnabled = value;
    });
    await _prefs.setBool(PrefKeys.subscriptionRemindersEnabled, value);
    if (value) {
      await NotificationService().requestPermissions();
    }
    await NotificationService().rescheduleAllSubscriptionReminders();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'Subscription renewal alerts enabled'
              : 'Subscription renewal alerts turned off'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showSubscriptionAdvanceDaysDialog() async {
    int tempDays = _subscriptionReminderAdvanceDays;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Subscription Alert Notice'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int>(
                    title: const Text('On renewal day (9:00 AM)'),
                    value: 0,
                    groupValue: tempDays,
                    onChanged: (val) => setDialogState(() => tempDays = val!),
                  ),
                  RadioListTile<int>(
                    title: const Text('1 day before renewal (9:00 AM)'),
                    value: 1,
                    groupValue: tempDays,
                    onChanged: (val) => setDialogState(() => tempDays = val!),
                  ),
                  RadioListTile<int>(
                    title: const Text('2 days before renewal (9:00 AM)'),
                    value: 2,
                    groupValue: tempDays,
                    onChanged: (val) => setDialogState(() => tempDays = val!),
                  ),
                  RadioListTile<int>(
                    title: const Text('3 days before renewal (9:00 AM)'),
                    value: 3,
                    groupValue: tempDays,
                    onChanged: (val) => setDialogState(() => tempDays = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {
        _subscriptionReminderAdvanceDays = tempDays;
      });
      await _prefs.setInt(
        PrefKeys.subscriptionReminderAdvanceDays,
        tempDays,
      );
      await NotificationService().rescheduleAllSubscriptionReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alert timing updated to ${_getAdvanceDaysLabel(tempDays)}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationService().requestPermissions();
    await NotificationService().showInstantNotification(
      title: 'Expense Tracker Alert 🔔',
      body: 'Notifications are working perfectly on your device!',
      payload: 'test_notification',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent! Check your notification bar.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.teal,
        ),
      );
    }
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
          _buildSectionTitle(context, 'Profile'),
          ListTile(
            title: const Text('Username'),
            trailing: Text(_username),
            onTap: _showEditUsernameDialog,
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
          ListTile(
            title: const Text('Switch Profile'),
            trailing: Text(
              CurrencySymbol().getLabel(_currentCurrency),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            onTap: _showProfileSwitchConfirmationDialog,
          ),
          _buildSectionTitle(context, 'Management'),
          ListTile(
            title: const Text('Subscriptions & Recurring'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionsScreen(
                    profileId: _profileId,
                    currencySymbol: CurrencySymbol().getSymbol(_currentCurrency),
                    onWalletAmountChange: widget.onWalletAmountUpdated,
                  ),
                ),
              );
            },
          ),
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
          _buildSectionTitle(context, 'Backup & Restore'),
          ListTile(
            title: const Text('Backup Data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showExportOptionsDialog,
          ),
          ListTile(
            title: const Text('Restore Data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => DataBackup().importData(context, widget.onDeleteAllData),
          ),
          SwitchListTile(
            title: const Text('Daily Backup Reminder'),
            value: _isBackupReminderEnabled,
            onChanged: (bool value) {
              setState(() {
                _isBackupReminderEnabled = value;
              });
              _prefs.setBool(PrefKeys.dailyBackupReminderEnabled, value);
            },
          ),
          _buildSectionTitle(context, 'Notifications'),
          SwitchListTile(
            title: const Text('Daily Expense Reminder'),
            subtitle: Text(
              _isDailyReminderEnabled
                  ? 'Daily at ${_formatReminderTime(_dailyReminderHour, _dailyReminderMinute)}'
                  : 'Get reminded to log today\'s expenses',
            ),
            secondary: const Icon(Icons.alarm),
            value: _isDailyReminderEnabled,
            onChanged: _toggleDailyReminder,
          ),
          if (_isDailyReminderEnabled)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 72, right: 16),
              title: const Text('Reminder Time'),
              trailing: TextButton.icon(
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(
                  _formatReminderTime(_dailyReminderHour, _dailyReminderMinute),
                ),
                onPressed: _pickDailyReminderTime,
              ),
              onTap: _pickDailyReminderTime,
            ),
          SwitchListTile(
            title: const Text('Subscription Due Alerts'),
            subtitle: Text(
              _isSubscriptionRemindersEnabled
                  ? _getAdvanceDaysLabel(_subscriptionReminderAdvanceDays)
                  : 'Notify before upcoming renewals',
            ),
            secondary: const Icon(Icons.notifications_active_outlined),
            value: _isSubscriptionRemindersEnabled,
            onChanged: _toggleSubscriptionReminders,
          ),
          if (_isSubscriptionRemindersEnabled)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 72, right: 16),
              title: const Text('Alert Notice Timing'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showSubscriptionAdvanceDaysDialog,
            ),
          ListTile(
            title: const Text('Send Test Notification'),
            subtitle: const Text('Test alert tone and notification banner'),
            leading: const Icon(Icons.notification_add_outlined),
            trailing: const Icon(Icons.send_rounded),
            onTap: _sendTestNotification,
          ),
          _buildSectionTitle(context, 'AI'),
          ListTile(
            title: const Text('AI Settings'),
            subtitle: const Text('Configure AI Provider, API Keys & Models'),
            trailing: const Icon(Icons.psychology),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AISettingsScreen()),
              );
            },
          ),
          _buildSectionTitle(context, 'Danger Zone'),
          ListTile(
            title: const Text('Developer Mode'),
            // if on show ON in green else OFF in default theme color
            trailing: Text(_isDeveloperMode ? 'ON' : 'OFF', style: _isDeveloperMode ? TextStyle(color: Colors.green) : TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const DeveloperModeScreen()),
              );
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                _isDeveloperMode = prefs.getBool(PrefKeys.isDeveloperMode) ?? false;
              });
            },
          ),
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
