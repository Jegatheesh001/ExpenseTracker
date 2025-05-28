import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  final List<Expense> _expenses = [];

  void _addExpense() {
    final category = _categoryController.text;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final remarks = _remarksController.text;
    final entryDate = DateTime.now();

    if (category.isNotEmpty && amount > 0) {
      setState(() {
        _expenses.add(Expense(
          category: category,
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
    _categoryController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
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