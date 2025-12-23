import 'dart:async';
import 'package:expense_tracker/pref_keys.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';

import 'db/persistence_context.dart';
import 'db/entity.dart';
import 'add_expense_screen.dart'; // Import the new screen
import 'settings_screen.dart'; // Import the new settings screen
import 'currency_symbol.dart';
import 'reports_screen.dart';
import 'data_backup.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This boolean will eventually be controlled by a theme switch
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  // Loads the saved theme mode (dark/light) from shared preferences.
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode =
          prefs.getBool('isDarkMode') ?? (ThemeMode.system == ThemeMode.dark);
    });
  }

  // Toggles the theme between dark and light mode.
  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        useMaterial3: true, // Enable Material 3
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true, // Enable Material 3
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
      ),
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const ExpenseHomePage(),
    ); // MaterialApp
  }
}

class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({super.key});

  @override
  _ExpenseHomePageState createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  final GlobalKey<ExpensesScreenState> _expensesKey = GlobalKey<ExpensesScreenState>();
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();
  String _currencySymbol = '₹'; // Default currency symbol
  double _walletAmount = 0.0; // To store wallet amount
  bool _showExpStatusBar = false;
  late SharedPreferences _prefs;
  int _profileId = 0;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _uriLinkSubscription;
  late StreamSubscription _intentSub;


  static const platform = MethodChannel('com.jegatheesh.expenseTracker/channel');

  @override
  void initState() {
    super.initState();
    _loadPageContent();
    _handleCopiedTextFromSharing();
    _initAppLinks();
    platform.setMethodCallHandler(_handleMethod);
  }

  Future<void> _initAppLinks() async {
    // Handle incoming links when the app is already running
    _uriLinkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (!mounted) return;
      _handleUri(uri);
    }, onError: (err) {
      debugPrint('uriLinkStream error: $err');
    });

    // Handle the initial link when the app is opened from a cold start
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (!mounted) return;
      _handleUri(initialUri);
    } on PlatformException {
      debugPrint('Failed to get initial URI.');
    } on FormatException catch (e) {
      debugPrint('Malformed initial URI: ${e.message}');
    }
  }

  void _handleUri(Uri? uri) {
    if (uri != null && uri.scheme == 'app' && uri.host == 'com.jegatheesh.expenseTracker') {
      if (uri.path == '/open' && uri.queryParameters['featureName'] == 'wallet') {
        _showWalletBalance();
      }
    }
  }

  void _showWalletBalance() {
    // This reuses the logic you already had for displaying the wallet amount
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wallet Amount: $_currencySymbol${_walletAmount.toStringAsFixed(2)}')),
    );
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'getWalletAmount':
        _showWalletBalance();
        break;
      default:
        throw MissingPluginException();
    }
  }

  /// Initializes all the necessary data for the home page.
  void _loadPageContent() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSelectedProfile();
    await _loadCurrency();
    _loadWalletAmount();
    _loadExpStatusBar();
    _checkBackupReminder();
  }

  /// Handles profile change event from settings.
  Future<void> _onProfileChange() async {
    await _loadSelectedProfile();
    await _loadCurrency();
    _loadWalletAmount();
    // Reload today's expenses to reflect the new profile's data.
    _loadTodaysExpenses();
  }

  // Loads the selected currency from shared preferences.
  Future<void> _loadCurrency() async {
    final currency = _prefs.getString('${PrefKeys.selectedCurrency}-$_profileId') ?? 'Rupee';
    _loadCurrencySymbol(currency);
  }

  // Loads the wallet amount from shared preferences.
  Future<void> _loadWalletAmount() async {
    setState(() {
      // Using the same key as in SettingsScreen
      _walletAmount = _prefs.getDouble('${PrefKeys.walletAmount}-$_profileId') ?? 0.0;
    });
  }

  // Determines the currency symbol based on the selected currency.
  Future<void> _loadCurrencySymbol(currency) async {
    String currencySymbol = CurrencySymbol().getSymbol(currency);
    setState(() {
      _currencySymbol = currencySymbol;
    });
  }

  Future<void> _loadExpStatusBar() async {
    bool status = _prefs.getBool(PrefKeys.showExpStatusBar) ?? false;
    setState(() {
      _showExpStatusBar = status;
    });
  }

  Future<void> _loadSelectedProfile() async {
    setState(() {
      _profileId = _prefs.getInt(PrefKeys.profileId) ?? 0;
    });
  }

  Future<void> _toggleExpStatusBar() async {
    bool flag = !_showExpStatusBar;
    _prefs.setBool('showExpStatusBar', flag);
    setState(() {
      _showExpStatusBar = flag;
    });
    _expensesKey.currentState?.refresh();
  }

  // Callback to reload data after deletion from settings
  void _handleDataDeletion() {
    // Reload all relevant data for the home screen
    _loadTodaysExpenses();
  }

  Future<void> _handleMonthlyLimitUpdate(String newLimit) async {
    _expensesKey.currentState?.refresh();
  }

  // Loads expenses for the selected date from the database.
  Future<void> _loadTodaysExpenses() async {
    _dashboardKey.currentState?.refresh();
    _expensesKey.currentState?.refresh();
  }

 Future<void> _editExpense(Expense expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(expenseToEdit: expense, onWalletAmountChange: _loadWalletAmount),
      ),
    );
    if (result == true) {
      _loadTodaysExpenses();
    }
  }

  // Deletes an expense from the database and refreshes the list.
  Future<void> _deleteExpense(Expense expense) async {
    await PersistenceContext().deleteExpense(expense.id!);
    _updateWalletOnExpenseDeletion(expense);
    _loadTodaysExpenses(); // Refresh the list after deleting
  }

  Future<void> _updateWalletOnExpenseDeletion(Expense expense) async {
    if (expense.paymentMethod != null && expense.paymentMethod != PaymentMethod.none.name) {
      String prefKey = expense.paymentMethod == PaymentMethod.cash.name
          ? PrefKeys.cashAmount
          : PrefKeys.bankAmount;
      double currentAmount = _prefs.getDouble('$prefKey-$_profileId') ?? 0.0;
      double newAmount = currentAmount + expense.amount;
      await _prefs.setDouble('$prefKey-$_profileId', newAmount);

      // also update the total wallet amount
      double totalWalletAmount = _prefs.getDouble('${PrefKeys.walletAmount}-$_profileId') ?? 0.0;
      double newTotalWalletAmount = totalWalletAmount + expense.amount;
      await _prefs.setDouble('${PrefKeys.walletAmount}-$_profileId', newTotalWalletAmount);
      
      _loadWalletAmount();
    }
  }

  @override
  void dispose() {
    _intentSub.cancel();
    _uriLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(
            key: _dashboardKey,
            profileId: _profileId,
          ),
          ExpensesScreen(
            key: _expensesKey,
            profileId: _profileId,
            currencySymbol: _currencySymbol,
            onWalletAmountChange: _loadWalletAmount,
          ),
          ReportsScreen(profileId: _profileId, currencySymbol: _currencySymbol),
          SettingsScreen(
            onThemeToggle: context.findAncestorStateOfType<_MyAppState>()?._toggleTheme ?? () {},
            onCurrencyToggle: _loadCurrency,
            onStatusBarToggle: _toggleExpStatusBar,
            onMonthlyLimitSaved: _handleMonthlyLimitUpdate,
            onDeleteAllData: _handleDataDeletion,
            onWalletAmountUpdated: _loadWalletAmount,
            onProfileChange: _onProfileChange,
          ),
        ],
      ),
      floatingActionButton: _selectedIndex != 3
          ? FloatingActionButton(
              onPressed: () async {
                final bool result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddExpenseScreen(
                            onWalletAmountChange: _loadWalletAmount,
                          )),
                );
                if (result == true) {
                  _loadTodaysExpenses();
                }
              },
              tooltip: 'Add Expense',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            _dashboardKey.currentState?.refresh();
          } else if (index == 1) {
            _expensesKey.currentState?.refresh();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Expenses'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_rounded), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  // Method to handle shared text
  void _handleCopiedTextFromSharing() {
    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      retrieveSharedContent(value);
    }, onError: (err) {});

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      retrieveSharedContent(value);
      ReceiveSharingIntent.instance.reset();
    });
  }
  
  void retrieveSharedContent(List<SharedMediaFile> value) {
    if (value.isEmpty) return;
    String content = value.first.path;
    ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(content)));
    final RegExp regExp = RegExp(
      r"^Purchase of ([A-Z]{3}) (\d+\.\d{2}) with (Debit|Credit|Visa|MasterCard) Card ending (\d{4}) at (.*?), (DXB|SHJ|AUH|DUBAI|SHARJAH|ESHARJAH|ABU DHABI|LONDON)\..*",
      caseSensitive: false,
    );
    final RegExpMatch? match = regExp.firstMatch(content);
    if (match != null) {
      var expense = Expense(
        categoryId: 0,
        category: '',
        amount: double.parse(match.group(2)!),
        remarks: match.group(5)!,
        expenseDate: _selectedDate,
        entryDate: DateTime.now(),
        profileId: _profileId,
        paymentMethod: PaymentMethod.bank.name,
      );
      _editExpense(expense);
    } else {
      final RegExp upiTransRegex = RegExp(r'Sent Rs\.(?<amount>\d+\.\d{2})\s*\nFrom (?<from>.*?)\nTo (?<to>.*?)\nOn (?<date>\d{2}/\d{2}/\d{2})', multiLine: true);
      final RegExpMatch? matchFound = upiTransRegex.firstMatch(content);
      if (matchFound != null) {
        var expense = Expense(
          categoryId: 0,
          category: '',
          amount: double.parse(matchFound.namedGroup('amount')!),
          remarks: matchFound.namedGroup('to')!,
          expenseDate: _selectedDate,
          entryDate: DateTime.now(),
          profileId: _profileId,
          paymentMethod: PaymentMethod.bank.name,
        );
        _editExpense(expense);
      }
    }
  }

  void _checkBackupReminder() async {
    bool isBackupReminderEnabled = _prefs.getBool(PrefKeys.dailyBackupReminderEnabled) ?? false;
    if (isBackupReminderEnabled) {
      int? lastReminderTimestamp = _prefs.getInt(PrefKeys.lastBackupReminderTimestamp);
      if (lastReminderTimestamp == null || DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastReminderTimestamp)).inHours >= 24) {
        _showBackupReminderDialog();
      }
    }
  }

  void _showBackupReminderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Backup Reminder'),
          content: const Text('It\'s been a while since your last backup. Would you like to back up your data now?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Backup Now'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showExportOptionsDialog();
              },
            ),
            TextButton(
              child: const Text('Remind Later'),
              onPressed: () {
                _prefs.setInt(PrefKeys.lastBackupReminderTimestamp, DateTime.now().millisecondsSinceEpoch);
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Disable'),
              onPressed: () {
                _prefs.setBool(PrefKeys.dailyBackupReminderEnabled, false);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showExportOptionsDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
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
              onPressed: () {
                Navigator.of(dialogContext).pop();
                DataBackup().exportData(context, includeImages: false);
              },
            ),
            TextButton(
              child: const Text('With Images'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                DataBackup().exportData(context, includeImages: true);
              },
            ),
          ],
        );
      },
    );
  }
}
