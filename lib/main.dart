import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/persistence_context.dart';
import 'db/entity.dart';
import 'expense_list_view.dart';
import 'add_expense_screen.dart'; // Import the new screen
import 'settings_screen.dart'; // Import the new settings screen
import 'currency_symbol.dart';

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
        brightness: Brightness.light,
        primarySwatch: Colors.teal, // Light theme color
        // Define other light theme properties
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey, // Dark theme color
        // Define other dark theme properties
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

  @override
  void initState() {
    super.initState();
    _loadTodaysExpenses(); // Load today's expenses by default
    _loadWalletAmount(); // Load wallet amount
    _loadCurrency();
    setExpStatusBar();
  }

  // Loads the selected currency from shared preferences.
  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final currency = prefs.getString('selectedCurrency') ?? 'Rupee';
    _loadCurrencySymbol(currency);
  }

  // Loads the wallet amount from shared preferences.
  Future<void> _loadWalletAmount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Using the same key as in SettingsScreen
      _walletAmount = prefs.getDouble('walletAmount') ?? 0.0;
    });
  }

  // Determines the currency symbol based on the selected currency.
  Future<void> _loadCurrencySymbol(currency) async {
    String currencySymbol = CurrencySymbol().getSymbol(currency);
    setState(() {
      _currencySymbol = currencySymbol;
    });
  }

  Future<void> setExpStatusBar() async {
    final prefs = await SharedPreferences.getInstance();
    bool status = prefs.getBool('showExpStatusBar') ?? false;
    setState(() {
      _showExpStatusBar = status;
    });
  }

  Future<void> _toggleExpStatusBar() async {
    _showExpStatusBar = !_showExpStatusBar;
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('showExpStatusBar', _showExpStatusBar);
  }

  // Calculates the total spending for the current month and updates the progress.
  Future<void> _calculateSelectedMonthSpending() async {
    final prefs = await SharedPreferences.getInstance();
    String monthlyLimitStr = prefs.getString('monthlyLimit') ?? '';
    if (monthlyLimitStr != '') {
      double monthlyExp = await PersistenceContext().getExpenseSumByMonth(
        _selectedDate,
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
    );
    _expensesTotal = loadedExpenses.fold(0.0, (sum, item) => sum + item.amount);
    _updateExpenseList(loadedExpenses);
    _showPreviousDayPercentageChange();
  }

  // Loads expenses for the selected date from the database.
  Future<void> _loadTodaysExpenses() async {
    _loadSelectedDateExpense();
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

  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();

  List<Expense> _expenses = [];
  double _expensesTotal = 0;
  double _percentageChange = 0;

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // Calculates and displays the percentage change in expenses compared to the previous day.
  void _showPreviousDayPercentageChange() async {
    final previousDay = _selectedDate.subtract(const Duration(days: 1));
    final previousDayTotal = await PersistenceContext().getExpenseSumByDate(
      previousDay,
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
            // Display Total Expenses and Wallet Amount on a single line
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: Total and Percentage Change
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total: $_currencySymbol${_expensesTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        '${_percentageChange > 0 ? '+' : ''}${_percentageChange.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          color: _percentageChange > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  // Right side: Wallet Icon and Amount
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.green, size: 24),
                      const SizedBox(width: 8.0),
                      Text(
                        '$_currencySymbol${_walletAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.green),
                      ),
                    ],
                  ),
                ],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => _addDayToCurrent(-1)
                ),
                Row(
                  children: [
                    Text(
                      DateFormat('dd-MM-yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () => _addDayToCurrent(1)
                ),
              ],
            ),
            const SizedBox(height: 8.0),
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
}
