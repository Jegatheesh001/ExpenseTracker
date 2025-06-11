import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_expense_screen.dart'; // Import the new screen
import 'db/persistence_context.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_screen.dart'; // Import the new settings screen
import 'db/entity.dart';

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
  bool _showExpStatusBar = false;

  @override
  void initState() {
    super.initState();
    _loadTodaysExpenses(); // Load today's expenses by default
    _loadCurrency();
    setExpStatusBar();
  }

  // Loads the selected currency from shared preferences.
  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final currency = prefs.getString('selectedCurrency') ?? 'Rupee';
    _loadCurrencySymbol(currency);
  }

  // Determines the currency symbol based on the selected currency.
  Future<void> _loadCurrencySymbol(currency) async {
    String currencySymbol;
    switch (currency) {
      case 'Rupee':
        currencySymbol = '₹';
        break;
      case 'Dirham':
        currencySymbol = 'د.إ';
        break;
      case 'Dollar':
        currencySymbol = '\$';
        break;
      default:
        currencySymbol = '₹'; // Default to dollar if currency is unknown
    }
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
  Future<void> _loadTodaysExpenses() async {
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

  // Navigates to the previous day and loads its expenses.
  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadTodaysExpenses(); // Load expenses for the previous day
  }

  // Navigates to the next day and loads its expenses.
  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    _loadTodaysExpenses(); // Load expenses for the next day
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
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
              ), // Row
            ),
            const SizedBox(height: 8.0), // Add some spacing
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
                          'Monthly Limit: $_monthlyLimit Used: ${_monthlyLimitPerc * 100}%',

                      // 2. The widget that triggers the tooltip
                      child: Slider(
                        value: _monthlyLimitPerc,
                        onChanged: (double value) {},
                        activeColor:
                            _monthlyLimitPerc > 0.8 ? Colors.red : Colors.green,
                        inactiveColor: Colors.grey[300],
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
                  onPressed: _previousDay,
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
                  onPressed: _nextDay,
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: ListView.builder(
                itemCount: _expenses.length,
                itemBuilder: (context, index) {
                  final expense = _expenses[index];
                  final formattedDate = DateFormat(
                    'dd-MM-yyyy HH:mm:ss',
                  ).format(expense.entryDate);

                  return GestureDetector(
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Confirm Delete'),
                            content: const Text(
                              'Are you sure you want to delete this expense?',
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _deleteExpense(expense.id!);
                                  Navigator.of(context).pop(true);
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Stack(
                      children: [
                        ListTile(
                          title: Text(expense.remarks),
                          subtitle: Text(
                            'Amount: $_currencySymbol${expense.amount.toStringAsFixed(2)}\nCategory: ${expense.category}\nDate: $formattedDate',
                          ),
                        ), // ListTile
                        Positioned(
                          top: 0,
                          right:
                              0, // Adjust position to make space for edit button
                          child: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final bool result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AddExpenseScreen(
                                        expenseToEdit: expense,
                                      ),
                                ),
                              );
                              // Refresh the expense list after the dialog is closed
                              if (result == true) {
                                _loadTodaysExpenses();
                              }
                            },
                          ),
                        ),
                      ],
                    ), // Stack
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
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
