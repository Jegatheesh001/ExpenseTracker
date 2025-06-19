import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/entity.dart';
import 'db/persistence_context.dart';
import 'attach_image_screen.dart';
import 'pref_keys.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({Key? key, this.expenseToEdit, required this.onWalletAmountChange,}) : super(key: key);

  final Expense? expenseToEdit;
  final VoidCallback onWalletAmountChange;

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
  DateTime _selectedDate = DateTime.now();
  bool _deductFromWallent = true;

  @override
  void initState() {
    expenseToEdit = widget.expenseToEdit;
    super.initState();
    _loadCategories().then((_) {
      if (expenseToEdit != null) {
        setState(() {
          _selectedDate = expenseToEdit!.expenseDate;
        });
        _loadExpense(expenseToEdit!);
      }
    });
  }

  // Loads categories from the persistence context.
  Future<void> _loadCategories() async {
    final loadedCategories = await PersistenceContext().getCategories();
    setState(() {
      _categories.addAll(loadedCategories);
    });
  }

  // Loads expense data into the form fields.
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

  // Adds or updates an expense.
  void _addExpense(BuildContext context) async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final remarks = _remarksController.text;
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
        expenseDate: _selectedDate,
        entryDate: DateTime.now(),
      );
      await PersistenceContext().saveOrUpdateExpense(newExpense);
      deductFromWallet(amount);
      Navigator.pop(context, true);
    }
  }

  // Deletes the current expense being edited.
  Future<void> _deleteCurrentExpense(BuildContext context) async {
    if (widget.expenseToEdit == null || widget.expenseToEdit!.id == null) return;

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      if (_deductFromWallent) { // If the checkbox is currently checked
        final prefs = await SharedPreferences.getInstance();
        double walletAmount = prefs.getDouble(PrefKeys.walletAmount) ?? 0.0;
        walletAmount += widget.expenseToEdit!.amount; // Add back the amount
        await prefs.setDouble(PrefKeys.walletAmount, walletAmount);
        widget.onWalletAmountChange(); // Update wallet display on home screen
      }
      await PersistenceContext().deleteExpense(widget.expenseToEdit!.id!);
      Navigator.pop(context, true); // Signal deletion
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
        title: Row(
          mainAxisSize: MainAxisSize.min, // To keep the Row compact around its children
          children: <Widget>[
            Text((expenseToEdit != null && expenseToEdit!.id != null) ? 'Edit Expense' : 'Add New Expense'),
            if (expenseToEdit != null && expenseToEdit!.id != null) // Show icon only in edit mode and if id exists
              Padding(
                padding: const EdgeInsets.only(left: 4.0), // Reduced padding slightly for IconButton
                child: IconButton(
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Attach Image',
                  // Constraints can be added to control tap target size if needed
                  // constraints: const BoxConstraints(), 
                  // padding: EdgeInsets.zero, // If you want to remove default IconButton padding
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttachImageScreen(
                          expenseId: widget.expenseToEdit!.id!,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
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
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null && pickedDate != _selectedDate) {
                        setState(() {
                          _selectedDate = pickedDate;
                        });
                      }
                    },
                    child: const Text('Select Date'),
                  ),
                ],
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
              const SizedBox(
                height: 20.0,
              ), // Add some spacing if the attach button is shown
              CheckboxListTile(
                title: const Text("Deduct from wallet"),
                value: _deductFromWallent,
                onChanged: (bool? value) => deductFromWalletState(value),
                controlAffinity: ListTileControlAffinity.leading, // Checkbox on the left
                contentPadding: EdgeInsets.zero, // Remove default padding
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _addExpense(context),
                child: Text(
                  (expenseToEdit != null && expenseToEdit!.id != null) ? 'Update Expense' : 'Add Expense',
                ),
              ),
              if (expenseToEdit != null && expenseToEdit!.id != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _deleteCurrentExpense(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Set button color to red
                  ),
                  child: const Text('Delete Expense'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  void deductFromWalletState(bool? value) {
    setState(() {
      _deductFromWallent = value ?? false;
    });
  }
  void deductFromWallet(double amount) async {
    if(_deductFromWallent) {
      final prefs = await SharedPreferences.getInstance();
      double walletAmount = prefs.getDouble(PrefKeys.walletAmount) ?? 0.0;
      if(expenseToEdit == null) {
        if(walletAmount > 0) {
          walletAmount -= amount;
          prefs.setDouble(PrefKeys.walletAmount, walletAmount);
          widget.onWalletAmountChange();
        }
      } else {
        double oldExpAmt = expenseToEdit!.amount;
        if(oldExpAmt != amount) {
          walletAmount -= amount - oldExpAmt;
          prefs.setDouble(PrefKeys.walletAmount, walletAmount);
          widget.onWalletAmountChange();
        }
      }
    }
  }
}
