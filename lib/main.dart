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

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode =
          prefs.getBool('isDarkMode') ?? (ThemeMode.system == ThemeMode.dark);
    });
  }

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
  String _currentCurrency = 'Rupee'; // This will hold the loaded currency
  String _currencySymbol = '₹';

  @override
  void initState() {
    super.initState();
    _loadTodaysExpenses(); // Load today's expenses by default
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentCurrency = prefs.getString('selectedCurrency') ?? 'Rupee';
    });
    _loadCurrencySymbol();
  }

  // Determine the currency symbol based on the selected currency
  Future<void> _loadCurrencySymbol() async {
    String currencySymbol;
    switch (_currentCurrency) {
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
        currencySymbol = '\$'; // Default to dollar if currency is unknown
    }
    setState(() {
      _currencySymbol = currencySymbol;
    });
  }

  // Method to load today's expenses from the database
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
    _updateExpenseList(loadedExpenses);
  }

  // Method to load expenses from the database (unused)
  /* Future<void> _loadExpenses() async {
    final loadedExpenses = await PersistenceContext().getExpenses();
    setState(() {
      _expenses.clear();
      _expenses.addAll(loadedExpenses);
    });
  } */

  // Method to delete an expense from the database
  Future<void> _deleteExpense(int id) async {
    await PersistenceContext().deleteExpense(id);
    _loadTodaysExpenses(); // Refresh the list after deleting
  }

  // Helper method to update the expense list state
  void _updateExpenseList(List<Expense> expenses) {
    setState(() {
      _expenses.clear();
      _expenses.addAll(expenses);
    });
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadTodaysExpenses(); // Load expenses for the previous day
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    _loadTodaysExpenses(); // Load expenses for the next day
  }

  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  List<Expense> _expenses = [];

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
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
                    final myAppState =
                        context.findAncestorStateOfType<_MyAppState>();
                    return SettingsScreen(
                      onThemeToggle: myAppState?._toggleTheme ?? () {},
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
              child: Text(
                'Total: $_currencySymbol${_expenses.fold(0.0, (sum, item) => sum + item.amount).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 8.0), // Add some spacing
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
                          right: 0, // Adjust position to make space for edit button
                          child: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final bool result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AddExpenseScreen(expenseToEdit: expense),
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
