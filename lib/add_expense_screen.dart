import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'entity.dart';
import 'persistence_context.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({Key? key}) : super(key: key);

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  String? _selectedCategory;
  final List<String> _categories = [];
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final loadedCategories = await PersistenceContext().getCategories();
    setState(() {
      _categories.addAll(loadedCategories);
    });
  }

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
      final newExpense = Expense(
        category: _selectedCategory!,
        amount: amount,
        remarks: remarks,
        entryDate: entryDate,
      );
      PersistenceContext().saveExpense(newExpense);
      Navigator.pop(context, true);
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
        title: const Text('Add New Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Category'),
                value: _selectedCategory,
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
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _remarksController,
                decoration: const InputDecoration(labelText: 'Remarks'),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _addExpense,
                child: const Text('Add Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}