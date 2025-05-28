import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

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
  bool _isDarkMode = ThemeMode.system == ThemeMode.dark; 

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
    );
  }
}

class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({super.key});

  @override
  _ExpenseHomePageState createState() => _ExpenseHomePageState();
}

class Expense {
  final String category;
  final double amount;
  final String remarks;
  final DateTime entryDate;

  Expense({
    required this.category,
    required this.amount,
    required this.remarks,
    required this.entryDate,
  });
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  String? _selectedCategory;
  final List<String> _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Utilities',
  ];
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  final List<Expense> _expenses = [];

  void _addExpense() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final remarks = _remarksController.text;
    final entryDate = DateTime.now();
 final category = _selectedCategory;

 if (category == null || category.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Please select a category')),
 );
    } else if (amount <= 0) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Please enter a valid amount')),
 );
    } else if (remarks.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Please enter remarks')),
 );
    } else {
      setState(() {
        _expenses.add(Expense(
          category: _selectedCategory!,
          amount: amount,
          remarks: remarks,

          entryDate: entryDate,
        ));
      });
      _categoryController.clear();
      _amountController.clear();
      _remarksController.clear();
    }
  }

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
          icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
          onPressed: () {
            context.findAncestorStateOfType<_MyAppState>()?._toggleTheme();
          },
        ),
      ], // IconButton
      ), // AppBar
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('Select Category'),
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
            TextField(
              controller: _remarksController,
              decoration: const InputDecoration(labelText: 'Remarks'),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _addExpense,
              child: const Text('Add Expense'),
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Expenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: ListView.builder(
                itemCount: _expenses.length,
                itemBuilder: (context, index) {
                  final expense = _expenses[index];
                  final formattedDate =
                      DateFormat('yyyy-MM-dd HH:mm').format(expense.entryDate);
                  return Card(
                    child: ListTile(
                      title: Text(expense.category),
                      subtitle: Text(
                          'Amount: \$${expense.amount.toStringAsFixed(2)}\nRemarks: ${expense.remarks}\nDate: $formattedDate'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}