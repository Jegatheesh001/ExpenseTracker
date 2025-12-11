import 'package:expense_tracker/currency_symbol.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/entity.dart';
import 'db/persistence_context.dart';
import 'attach_image_screen.dart';
import 'pref_keys.dart';

enum PaymentMethod { cash, bank, none }

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
  final TextEditingController _tagsController = TextEditingController();
  final FocusNode _tagsFocusNode = FocusNode();
  DateTime _selectedDate = DateTime.now();
  PaymentMethod? _selectedPaymentMethod;
  int _profileId = 0;
  String _previousTagText = '';
  List<String> _suggestedTags = [];
  bool _userManuallySelectedCategory = false;
  String _currencySymbol = '';

  @override
  void initState() {
    expenseToEdit = widget.expenseToEdit;
    super.initState();
    _loadCategories().then((_) {
      if (expenseToEdit != null) {
        setState(() {
          _selectedDate = expenseToEdit!.expenseDate;
          if (expenseToEdit!.paymentMethod != null) {
            try {
              _selectedPaymentMethod = PaymentMethod.values.firstWhere((e) => e.toString() == 'PaymentMethod.${expenseToEdit!.paymentMethod}');
            } catch (e) {
              _selectedPaymentMethod = null;
            }
          } else if (expenseToEdit != null && expenseToEdit!.paymentMethod == null) {
            _selectedPaymentMethod = PaymentMethod.none;
          }
        });
        _loadExpense(expenseToEdit!);
      } else {
        _selectedPaymentMethod = PaymentMethod.cash;
      }
    });
    _loadSelectedProfile().then((_) {
      _loadCurrencySymbol();
    });
    _remarksController.addListener(_updateSuggestedTags);
  }

  void _updateCategoryFromRemarks() {
    // If the user has manually selected a category, don't auto-update it
    if (!_userManuallySelectedCategory) {
      if (_remarksController.text.isEmpty) {
        setState(() {
          _selectedCategory = null;
        });
        return;
      }
    }
    autoSuggestCategoryBasedOnRemarks();
  }
  Future<void> autoSuggestCategoryBasedOnRemarks() async {
    // If no category is selected, suggest one based on remarks
    if (_remarksController.text.isNotEmpty && _selectedCategory == null) {
      final category = await PersistenceContext().getCategoryForRemark(_remarksController.text);
      if (mounted) {
        setState(() {
          _selectedCategory = category;
        });
      }
    }
  }

  Future<void> _loadCurrencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCurrency = prefs.getString('${PrefKeys.selectedCurrency}-$_profileId') ?? 'Rupee';
    setState(() {
      _currencySymbol = CurrencySymbol().getSymbol(currentCurrency);
    });
  }

  // Loads categories from the persistence context.
  Future<void> _loadCategories() async {
    final loadedCategories = await PersistenceContext().getCategories();
    setState(() {
      _categories.addAll(loadedCategories);
    });
  }

  Future<void> _loadSelectedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileId = prefs.getInt(PrefKeys.profileId) ?? 0;
    });
  }

  // Loads expense data into the form fields.
  Future<void> _loadExpense(Expense expense) async {
    _amountController.text = expense.amount.toString();
    _remarksController.text = expense.remarks;
    _tagsController.text = expense.tags.join(', ');
    if (expense.paymentMethod != null) {
      try {
        _selectedPaymentMethod = PaymentMethod.values.firstWhere((e) => e.toString() == 'PaymentMethod.${expense.paymentMethod}');
      } catch (e) {
        _selectedPaymentMethod = null;
      }
    }
    Category selectedCategory;
    if (expense.categoryId != null && expense.categoryId != 0) {
      selectedCategory = _categories.firstWhere(
        (category) => category.categoryId == expense.categoryId,
      );
      _userManuallySelectedCategory = true;
    } else {
      _updateCategoryFromRemarks();
      selectedCategory = _categories.firstWhere(
        (category) => category.category == expense.category,
      );
    }
    setState(() {
      _selectedCategory = selectedCategory;
    });
  }

  void _updateSuggestedTags() async {
    final remarks = _remarksController.text;
    if (remarks.length < 3) {
      setState(() {
        _suggestedTags = [];
      });
      return;
    }

    final suggestions = await PersistenceContext().getTagsForRemark(remarks);
    final currentTags = _tagsController.text.split(',').map((t) => t.trim().toLowerCase()).toSet();

    final filteredSuggestions = suggestions.where((tag) => !currentTags.contains(tag.toLowerCase())).toList();

    setState(() {
      _suggestedTags = filteredSuggestions;
    });
  }

  void _addTagToController(String tag) {
    final currentTags = _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (!currentTags.map((t) => t.toLowerCase()).contains(tag.toLowerCase())) {
      currentTags.add(tag);
      final newText = '${currentTags.join(', ')}, ';
      _tagsController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      // After adding a tag, we might want to re-evaluate suggestions
      _updateSuggestedTags();
    }
  }

  // Adds or updates an expense.
  void _addExpense(BuildContext context) async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final remarks = _remarksController.text;
    final tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    await autoSuggestCategoryBasedOnRemarks();
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
        id: expenseToEdit?.id, // Use existing ID if editing
        categoryId: _selectedCategory!.categoryId, // Selected category ID
        category: category, // Selected category name
        amount: amount, // Entered amount
        remarks: remarks, // Entered remarks
        expenseDate: _selectedDate, // Selected date
        entryDate: DateTime.now(), // Current date/time for entry
        profileId: _profileId, // Current profile ID
        tags: tags,
        paymentMethod: _selectedPaymentMethod?.name,
      );

      // Show confirmation dialog only if it's an update (expenseToEdit is not null)
      bool confirmUpdate = true;
      if (expenseToEdit != null && expenseToEdit!.id != null) {
        confirmUpdate = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Update'),
              content: const Text('Are you sure you want to update this expense?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false); // User cancelled
                  },
                ),
                TextButton(
                  child: const Text('Update'),
                  onPressed: () {
                    Navigator.of(context).pop(true); // User confirmed
                  },
                ),
              ],
            );
          },
        ) ?? false; // Default to false if dialog is dismissed
      }

      if (confirmUpdate) {
        await PersistenceContext().saveOrUpdateExpense(newExpense);
        _updateBalances(amount);
        Navigator.pop(context, true);
      }
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
      final prefs = await SharedPreferences.getInstance();
      final amountToRefund = widget.expenseToEdit!.amount;
      final paymentMethod = widget.expenseToEdit!.paymentMethod;

      if (paymentMethod != null) {
        String? amountKey;
        if (paymentMethod == PaymentMethod.cash.name) {
          amountKey = '${PrefKeys.cashAmount}-$_profileId';
        } else if (paymentMethod == PaymentMethod.bank.name) {
          amountKey = '${PrefKeys.bankAmount}-$_profileId';
        }
        if (amountKey != null) {
          double currentAmount = prefs.getDouble(amountKey) ?? 0.0;
          await prefs.setDouble(amountKey, currentAmount + amountToRefund);

          // also update the combined wallet amount
          double cashAmount = prefs.getDouble('${PrefKeys.cashAmount}-$_profileId') ?? 0.0;
          double bankAmount = prefs.getDouble('${PrefKeys.bankAmount}-$_profileId') ?? 0.0;
          await prefs.setDouble('${PrefKeys.walletAmount}-$_profileId', cashAmount + bankAmount);

          widget.onWalletAmountChange(); // Update wallet display on home screen
        }
      }
      
      await PersistenceContext().deleteExpense(widget.expenseToEdit!.id!);
      Navigator.pop(context, true); // Signal deletion
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _remarksController.removeListener(_updateSuggestedTags);
    _remarksController.dispose();
    _tagsController.dispose();
    _tagsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((expenseToEdit != null && expenseToEdit!.categoryId != null && expenseToEdit!.categoryId != 0) 
                        ? 'Edit Expense' : 'Add Expense'),
        actions: [
          if (expenseToEdit != null)
            IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: 'Attachments',
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          // Using a Form widget is good practice for validation
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Category and Date Card ---
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: InputBorder.none, // Cleaner look inside a card
                        ),
                        initialValue: _selectedCategory?.categoryId,
                        items: _categories
                            .map((Category category) => DropdownMenuItem<int>(
                                  value: category.categoryId,
                                  child: Text(category.category),
                                ))
                            .toList(),
                        onChanged: (int? newValue) {
                          setState(() {
                            _userManuallySelectedCategory = true;
                            _selectedCategory = _categories.firstWhere((cat) => cat.categoryId == newValue);
                          });
                        },
                      ),
                      const Divider(height: 16),
                      TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          suffixIcon: Icon(Icons.calendar_today),
                          border: InputBorder.none,
                        ),
                        controller: TextEditingController(
                            text: DateFormat('dd MMMM yyyy').format(_selectedDate)),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null) {
                            setState(() => _selectedDate = pickedDate);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // --- Amount Field ---
              TextFormField(
                controller: _amountController,
                style: Theme.of(context).textTheme.headlineMedium,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$_currencySymbol ',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16.0),

              // --- Remarks Field ---
              Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    _updateCategoryFromRemarks();
                  }
                },
                child: TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                ),
              ),
              if (_suggestedTags.isNotEmpty) // Keep the tag suggestions
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 8.0,
                    children: _suggestedTags
                        .map((tag) => ActionChip(
                              label: Text(tag),
                              onPressed: () => _addTagToController(tag),
                            ))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 16.0),
              
              // --- Tags Field (using RawAutocomplete as before) ---
              RawAutocomplete<String>(
                textEditingController: _tagsController,
                focusNode: _tagsFocusNode,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  String currentTag = textEditingValue.text.split(',').last.trim();
                  if (currentTag.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return PersistenceContext().searchTags(currentTag);
                },
                onSelected: (String selection) {
                  final text = _previousTagText;
                  List<String> tags = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  if (!text.endsWith(', ') && tags.isNotEmpty) {
                    tags.removeLast();
                  }
                  if (!tags.contains(selection)) {
                    tags.add(selection);
                  }
                  final newText = '${tags.join(', ')}, ';
                  _tagsController.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: newText.length),
                  );
                },
                fieldViewBuilder: (BuildContext context, TextEditingController textEditingController,
                    FocusNode focusNode, VoidCallback onFieldSubmitted) {
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma-separated)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  );
                },
                optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: SizedBox(
                        height: 200.0,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () {
                                _previousTagText = _tagsController.text;
                                onSelected(option);
                              },
                              child: ListTile(
                                title: Text(option),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16.0),

              // --- Payment Method ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ToggleButtons(
                    isSelected: [
                      _selectedPaymentMethod == PaymentMethod.cash,
                      _selectedPaymentMethod == PaymentMethod.bank,
                      _selectedPaymentMethod == PaymentMethod.none,
                    ],
                    onPressed: (int index) {
                      setState(() {
                        _selectedPaymentMethod = PaymentMethod.values[index];
                      });
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Cash'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Wallet'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('None'),
                      )
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Action Buttons ---
              FilledButton(
                onPressed: () => _addExpense(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  (expenseToEdit != null && expenseToEdit!.categoryId != null && expenseToEdit!.categoryId != 0) ? 'Update Expense' : 'Add Expense',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              if (expenseToEdit != null && expenseToEdit!.categoryId != null && expenseToEdit!.categoryId != 0) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => _deleteCurrentExpense(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Delete Expense', style: TextStyle(fontSize: 16)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _updateBalances(double amount) async {
    if (_selectedPaymentMethod == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    String cashAmountKey = '${PrefKeys.cashAmount}-$_profileId';
    String bankAmountKey = '${PrefKeys.bankAmount}-$_profileId';

    double cashAmount = prefs.getDouble(cashAmountKey) ?? 0.0;
    double bankAmount = prefs.getDouble(bankAmountKey) ?? 0.0;

    if (expenseToEdit != null && expenseToEdit!.categoryId != null && expenseToEdit!.categoryId != 0) {
      // This is an edit. Refund the old amount first.
      final oldAmount = expenseToEdit!.amount;
      final oldPaymentMethod = expenseToEdit!.paymentMethod;

      if (oldPaymentMethod != null) {
        if (oldPaymentMethod == PaymentMethod.cash.name) {
          cashAmount += oldAmount;
        } else if (oldPaymentMethod == PaymentMethod.bank.name) {
          bankAmount += oldAmount;
        }
      }
    }

    // Deduct the new amount from the selected source
    if (_selectedPaymentMethod == PaymentMethod.cash) {
      cashAmount -= amount;
    } else if (_selectedPaymentMethod == PaymentMethod.bank) {
      bankAmount -= amount;
    }

    // Save the updated amounts
    await prefs.setDouble(cashAmountKey, cashAmount);
    await prefs.setDouble(bankAmountKey, bankAmount);
    await prefs.setDouble('${PrefKeys.walletAmount}-$_profileId', cashAmount + bankAmount);
    
    widget.onWalletAmountChange();
  }
}