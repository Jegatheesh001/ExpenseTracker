import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db/entity.dart';
import 'db/persistence_context.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({Key? key, this.expenseToEdit}) : super(key: key);

  final Expense? expenseToEdit;

  @override
  // ignore: library_private_types_in_public_api
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  Expense? expenseToEdit;
  Category? _selectedCategory;
  final List<Category> _categories = [];
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    expenseToEdit = widget.expenseToEdit;
    super.initState();
    _loadCategories().then((_) {
      if (expenseToEdit != null) {
        _loadExpense(expenseToEdit!);
      }
    });
  }

  Future<void> _loadCategories() async {
    final loadedCategories = await PersistenceContext().getCategories();
    setState(() {
      _categories.addAll(loadedCategories);
    });
  }

  Future<void> _loadExpense(Expense expense) async {
    _amountController.text = expense.amount.toString();
    _remarksController.text = expense.remarks;
    Category selectedCategory;
    if (expense.categoryId != null) {
      selectedCategory = _categories.firstWhere(
        (category) => category.categoryId == expense.categoryId,
      );
    } else {
      selectedCategory = _categories.firstWhere(
        (category) => category.category == expense.category,
      );
    }
    setState(() {
      _selectedCategory = selectedCategory;
    });
  }

  void _addExpense() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final remarks = _remarksController.text;
    final entryDate = DateTime.now();
    final category = _selectedCategory?.category;

    if (category == null || category.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
    } else if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
    } else if (remarks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter remarks')));
    } else {
      final newExpense = Expense(
        id: expenseToEdit?.id,
        categoryId: _selectedCategory!.categoryId,
        category: category,
        amount: amount,
        remarks: remarks,
        entryDate: entryDate,
      );
      PersistenceContext().saveOrUpdateExpense(newExpense);
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
      appBar: AppBar(title: Text(expenseToEdit == null ? 'Add New Expense' : 'Edit Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Category'),
                value: _selectedCategory?.categoryId,
                items:
                    _categories.map((Category category) {
                      return DropdownMenuItem<int>(
                        value: category.categoryId,
                        child: Text(category.category),
                      );
                    }).toList(),
                onChanged: (int? newValue) {
                  final Category selectedCat = _categories.firstWhere(
                    (category) => category.categoryId == newValue,
                  );
                  setState(() {
                    _selectedCategory = selectedCat;
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
                child: Text(expenseToEdit == null ? 'Add Expense' : 'Update Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
