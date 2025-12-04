import 'dart:async';
import 'package:expense_tracker/pref_keys.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/services.dart';

import 'db/persistence_context.dart';
import 'db/entity.dart';
import 'expense_list_view.dart';
import 'add_expense_screen.dart'; // Import the new screen
import 'settings_screen.dart'; // Import the new settings screen
import 'currency_symbol.dart';
import 'reports_screen.dart';
import 'month_view.dart';

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
  DateTime _selectedDate = DateTime.now();
  String _currencySymbol = '₹'; // Default currency symbol
  double _monthlyLimit = 0;
  double _monthlyLimitPerc = 0; // Variable to store the monthly limit percentage
  double _currMonthExp = 0;
  double _walletAmount = 0.0; // To store wallet amount
  bool _showExpStatusBar = false;
  late SharedPreferences _prefs;
  int _profileId = 0;
  bool _isMonthView = false;
  Key _monthViewKey = UniqueKey();


  static const platform = MethodChannel('com.jegatheesh.expenseTracker/channel');

  @override
  void initState() {
    super.initState();
    _loadPageContent();
    _handleCopiedTextFromSharing();

    platform.setMethodCallHandler(_handleMethod);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'getWalletAmount':
        final prefs = await SharedPreferences.getInstance();
        final profileId = prefs.getInt(PrefKeys.profileId) ?? 0;
        final walletAmount = prefs.getDouble('${PrefKeys.walletAmount}-$profileId') ?? 0.0;
        debugPrint('Wallet Amount: $walletAmount');
        // Here you could show a dialog or update the UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wallet Amount: $_currencySymbol$walletAmount')),
        );
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
    _loadTodaysExpenses();
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
  }

  // Calculates the total spending for the current month and updates the progress.
  Future<void> _calculateSelectedMonthSpending() async {
    String monthlyLimitStr = _prefs.getString(PrefKeys.monthlyLimit) ?? '';
    if (monthlyLimitStr != '') {
      double monthlyExp = await PersistenceContext().getExpenseSumByMonth(
        _selectedDate, _profileId
      );
      double monthlyLimit = double.parse(monthlyLimitStr);
      double monthlyLimitPerc = getMonthlyLimitPerc(monthlyLimit, monthlyExp);
      setState(() {
        _monthlyLimit = monthlyLimit;
        _monthlyLimitPerc = monthlyLimitPerc;
        _currMonthExp = monthlyExp;
      });
    }
  }

  // Callback to reload data after deletion from settings
  void _handleDataDeletion() {
    // Reload all relevant data for the home screen
    _loadTodaysExpenses();
  }

  double getMonthlyLimitPerc(double monthlyLimit, double monthlyExp) {
    double monthlyLimitPerc = 1;
    if (monthlyExp < monthlyLimit) {
      monthlyLimitPerc = monthlyExp / monthlyLimit;
    }
    return monthlyLimitPerc;
  }

  Future<void> _handleMonthlyLimitUpdate(String newLimit) async {
    double monthlyLimit = double.parse(newLimit);
    double monthlyLimitPerc = getMonthlyLimitPerc(monthlyLimit, _currMonthExp);
    setState(() {
      _monthlyLimit = monthlyLimit;
      _monthlyLimitPerc = monthlyLimitPerc;
    });
  }

  // Loads expenses for the selected date from the database.
  Future<void> _loadSelectedDateExpense() async {
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final loadedExpenses = await PersistenceContext().getExpensesByDate(
      startOfDay,
      startOfDay,
      _profileId
    );
    _expensesTotal = loadedExpenses.fold(0.0, (sum, item) => sum + item.amount);
    _updateExpenseList(loadedExpenses);
    _showPreviousDayPercentageChange();
  }

  // Loads expenses for the selected date from the database.
  Future<void> _loadTodaysExpenses() async {
    if (_isMonthView) {
      setState(() {
        _monthViewKey = UniqueKey();
      });
    } else {
      _loadSelectedDateExpense();
    }
    _calculateSelectedMonthSpending();
  }

  // Method to load all expenses from the database (currently unused).
  /* Future<void> _loadExpenses() async {
    final loadedExpenses = await PersistenceContext().getExpenses();
    setState(() {
      _expenses.clear();
      _expenses.addAll(loadedExpenses);
    });
  } */

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
  Future<void> _deleteExpense(int id) async {
    await PersistenceContext().deleteExpense(id);
    _loadTodaysExpenses(); // Refresh the list after deleting
  }

  // Updates the state of the expense list.
  void _updateExpenseList(List<Expense> expenses) {
    setState(() {
      _expenses.clear();
      _expenses.addAll(expenses);
    });
  }

  // Navigates to the next day and loads its expenses.
  void _addDayToCurrent(int daysToAdd) {
    final DateTime oldDay = _selectedDate;
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: daysToAdd));
    });
    _loadSelectedDateExpense();
    if(oldDay.month != _selectedDate.month) {
      _calculateSelectedMonthSpending();
    }
  }

  void _addMonthToCurrent(int monthsToAdd) {
    final DateTime oldDay = _selectedDate;
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + monthsToAdd, _selectedDate.day);
    });
    if(oldDay.month != _selectedDate.month) {
      _calculateSelectedMonthSpending();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadSelectedDateExpense();
    }
  }

  void _updateMonthlyTotal(double total) {
    setState(() {
      _expensesTotal = total;
    });
  }

  List<Expense> _expenses = [];
  double _expensesTotal = 0;
  double _percentageChange = 0;

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  // Calculates and displays the percentage change in expenses compared to the previous day.
  void _showPreviousDayPercentageChange() async {
    final previousDay = _selectedDate.subtract(const Duration(days: 1));
    final previousDayTotal = await PersistenceContext().getExpenseSumByDate(
      previousDay, _profileId
    );
    _percentageChange = 0;
    if (previousDayTotal == 0 && _expensesTotal > 0) {
      _percentageChange = 100; // other-wise this will be infinity
    } else if (_expensesTotal > 0.0) {
      _percentageChange =
          ((_expensesTotal - previousDayTotal) / previousDayTotal) * 100;
    }
    setState(() {
      _percentageChange = _percentageChange;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportsScreen(profileId: _profileId, currencySymbol: _currencySymbol),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    final myAppState = context.findAncestorStateOfType<_MyAppState>();
                    return SettingsScreen(
                      onThemeToggle: myAppState?._toggleTheme ?? () {},
                      onCurrencyToggle: _loadCurrency,
                      onStatusBarToggle: _toggleExpStatusBar,
                      onMonthlyLimitSaved: _handleMonthlyLimitUpdate,
                      onDeleteAllData: _handleDataDeletion, // Pass the new callback
                      onWalletAmountUpdated: _loadWalletAmount, // Pass callback to update wallet amount
                      onProfileChange: _onProfileChange, // Pass callback to update profile
                    );
                  },
                ),
              );
            },
          ), // IconButtonpdownButtonHideUnderline
        ], // IconButton
      ), // AppBar
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 4.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Expenses',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_currencySymbol${_expensesTotal.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            if (!_isMonthView) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${_percentageChange.abs().toStringAsFixed(1)}%'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Icon(
                                  _percentageChange > 0
                                      ? Icons.arrow_upward
                                      : _percentageChange < 0
                                          ? Icons.arrow_downward
                                          : Icons.remove,
                                  color: _percentageChange > 0
                                      ? Colors.red
                                      : _percentageChange < 0
                                          ? Colors.green
                                          : Colors.grey,
                                  size: 18,
                                ),
                              )
                            ],
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Wallet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                            const SizedBox(width: 8.0),
                            Text(
                              '$_currencySymbol${_walletAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5.0), // Add some spacing
            // Add a FutureBuilder to display the current month's spending and the progress slider
            // Display the current month's spending and the progress slider
            if(_showExpStatusBar)
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Aligns text to the left
                children: [
                  Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: Tooltip(
                      // 1. The message to display on hover or long-press
                      message:
                          'Monthly Limit: $_monthlyLimit Used: ${(_monthlyLimitPerc * 100).toStringAsFixed(2)}%',
                      // 2. Wrap Slider with SliderTheme to customize its appearance
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.0,
                        ),
                        child: Slider(
                          value: _monthlyLimitPerc,
                          onChanged: (double value) {}, // Slider is for display only
                          activeColor:
                              _monthlyLimitPerc > 0.8 ? Colors.red : Colors.green,
                          inactiveColor: Colors.grey[300],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: false, label: Text('Day')),
                  ButtonSegment<bool>(value: true, label: Text('Month')),
                ],
                selected: <bool>{_isMonthView},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isMonthView = newSelection.first;
                    _loadTodaysExpenses();
                  });
                },
              ),
            ),
            if (_isMonthView)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _addMonthToCurrent(-1),
                  ),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: Text(
                      DateFormat('MMMM yyyy').format(_selectedDate),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _addMonthToCurrent(1),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _addDayToCurrent(-1),
                  ),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: Text(
                      DateFormat('dd MMMM yyyy').format(_selectedDate),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _addDayToCurrent(1),
                  ),
                ],
              ),
            const SizedBox(height: 8.0),
            if (_isMonthView)
              Expanded(
                child: MonthView(
                  key: _monthViewKey,
                  selectedDate: _selectedDate,
                  currencySymbol: _currencySymbol,
                  profileId: _profileId,
                  onEdit: _editExpense,
                  onTotalChanged: _updateMonthlyTotal,
                ),
              )
            else
              ExpenseListView(
                expenses: _expenses,
                currencySymbol: _currencySymbol,
                onDelete: _deleteExpense,
                onEdit: _editExpense,
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddExpenseScreen(
              onWalletAmountChange: _loadWalletAmount,
            )),
          );
          if (result == true) {
            // Or whatever condition you expect
            _loadTodaysExpenses();
          }
        },
        tooltip: 'Add Expense',
        child: const Icon(Icons.add),
      ),
    );
  }

  late StreamSubscription _intentSub;
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
        );
        _editExpense(expense);
      }
    }
  }
}