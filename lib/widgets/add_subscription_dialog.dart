import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expense_tracker/utils/currency_symbol.dart';
import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/utils/subscription_date_utils.dart';
import 'package:expense_tracker/services/currency_conversion_service.dart';

class AddSubscriptionSheet extends StatefulWidget {
  final int profileId;
  final String currencySymbol;
  final String? currentCurrency;
  final Subscription? subscriptionToEdit;
  final List<Category>? initialCategories;

  const AddSubscriptionSheet({
    super.key,
    required this.profileId,
    required this.currencySymbol,
    this.currentCurrency,
    this.subscriptionToEdit,
    this.initialCategories,
  });

  @override
  State<AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _remarksController;

  String _selectedCycle = 'Monthly';
  final List<String> _billingCycles = ['Monthly', 'Yearly', 'Weekly'];

  String _selectedCurrency = 'Rupee';
  final List<String> _currencies = CurrencySymbol().getCurrencies();

  List<Category> _categories = [];
  Category? _selectedCategory;

  DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime _nextBillingDate = DateTime.now().add(const Duration(days: 30));

  String? _selectedPaymentMethod;
  final List<String> _paymentMethods = [
    'Cash',
    'Debit Card',
    'Credit Card',
    'UPI',
    'Bank Transfer',
    'Other',
  ];

  bool _autoLogExpense = false;
  bool _isLoadingCategories = true;
  double? _conversionRate;
  bool _isLoadingRate = false;
  String? _requestedPair;
  int _rateGeneration = 0;

  double? get _positiveAmount {
    final amount = double.tryParse(_amountController.text.trim());
    return amount != null && amount.isFinite && amount > 0 ? amount : null;
  }

  @override
  void initState() {
    super.initState();
    final edit = widget.subscriptionToEdit;

    _titleController = TextEditingController(text: edit?.title ?? '');
    _amountController = TextEditingController(
      text: edit != null ? edit.amount.toString() : '',
    );
    _amountController.addListener(_onAmountChanged);
    _remarksController = TextEditingController(text: edit?.remarks ?? '');

    if (edit != null) {
      _selectedCycle = edit.billingCycle;
      _selectedCurrency = edit.currency;
      _startDate = edit.startDate;
      _nextBillingDate = edit.nextBillingDate;
      _selectedPaymentMethod = edit.paymentMethod;
      _autoLogExpense = edit.autoLogExpense;
    } else {
      _selectedCurrency = widget.currentCurrency ?? 'Rupee';
      _recalculateNextBillingDate();
    }

    if (!_currencies.contains(_selectedCurrency)) {
      _currencies.add(_selectedCurrency);
    }
    if (widget.initialCategories != null &&
        widget.initialCategories!.isNotEmpty) {
      _categories = widget.initialCategories!;
      _isLoadingCategories = false;
      _selectedCategory = _categories.first;
    } else {
      _loadCategories();
    }
    _updateLiveConversion();
  }

  void _onAmountChanged() {
    _updateLiveConversion();
    if (mounted) setState(() {});
  }

  Future<void> _updateLiveConversion() async {
    final currencies = CurrencySymbol();
    final base = currencies.getCode(_selectedCurrency);
    final quote = currencies.getCode(widget.currentCurrency ?? 'Rupee');
    if (base == null || quote == null || base == quote) {
      _requestedPair = null;
      _conversionRate = null;
      _isLoadingRate = false;
      _rateGeneration++;
      return;
    }

    final pair = '$base/$quote';
    if (_requestedPair != pair) {
      _requestedPair = null;
      _conversionRate = null;
      _isLoadingRate = false;
      _rateGeneration++;
    }
    if (_positiveAmount == null || _requestedPair == pair) return;

    final generation = _rateGeneration;
    _requestedPair = pair;
    _isLoadingRate = true;
    final rate = await CurrencyConversionService.instance.getRate(base, quote);
    if (!mounted || generation != _rateGeneration) return;

    setState(() {
      _conversionRate = rate;
      _isLoadingRate = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final loadedCategories = await DatabaseHelper().getCategories();
      if (mounted) {
        setState(() {
          _categories = loadedCategories;
          _isLoadingCategories = false;

          if (widget.subscriptionToEdit != null) {
            _selectedCategory = _categories.firstWhere(
              (c) => c.categoryId == widget.subscriptionToEdit!.categoryId,
              orElse: () => _categories.isNotEmpty
                  ? _categories.first
                  : Category(0, 'Others'),
            );
          } else if (_categories.isNotEmpty) {
            _selectedCategory = _categories.firstWhere(
              (c) =>
                  c.category.toLowerCase().contains('entertainment') ||
                  c.category.toLowerCase().contains('subscription'),
              orElse: () => _categories.first,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  void _recalculateNextBillingDate() {
    setState(() {
      _nextBillingDate = SubscriptionDateUtils.calculateNextBillingDate(
        _startDate,
        _selectedCycle,
        anchorDay: _startDate.day,
      );
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (mounted && picked != null) {
      setState(() {
        _startDate = picked;
        _recalculateNextBillingDate();
      });
    }
  }

  Future<void> _pickNextBillingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBillingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (mounted && picked != null) {
      setState(() {
        _nextBillingDate = picked;
      });
    }
  }

  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    if (_nextBillingDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Next due date cannot be before start date'),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final subscription = Subscription(
      id: widget.subscriptionToEdit?.id,
      profileId: widget.subscriptionToEdit?.profileId ?? widget.profileId,
      title: _titleController.text.trim(),
      amount: amount,
      categoryId: _selectedCategory!.categoryId,
      category: _selectedCategory!.category,
      billingCycle: _selectedCycle,
      startDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
      nextBillingDate: DateTime(
        _nextBillingDate.year,
        _nextBillingDate.month,
        _nextBillingDate.day,
      ),
      currency: _selectedCurrency,
      paymentMethod: _selectedPaymentMethod,
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      isActive: widget.subscriptionToEdit?.isActive ?? true,
      autoLogExpense: _autoLogExpense,
    );

    await DatabaseHelper().saveOrUpdateSubscription(subscription);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _buildLiveConversionHint(ThemeData theme) {
    final currencyHelper = CurrencySymbol();
    final profileCurrency = widget.currentCurrency ?? 'Rupee';
    final subCode = currencyHelper.getCode(_selectedCurrency);
    final profileCode = currencyHelper.getCode(profileCurrency);
    final profileSymbol = currencyHelper.getSymbol(profileCurrency);

    final amount = _positiveAmount;
    if (amount == null ||
        subCode == null ||
        profileCode == null ||
        subCode == profileCode) {
      return const SizedBox.shrink();
    }

    if (_isLoadingRate) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Fetching Frankfurter reference rate...',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final rate = _conversionRate;
    final converted = rate == null ? null : amount * rate;
    if (converted == null || !converted.isFinite) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Text(
          'Exchange rate unavailable',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.orange.shade800,
            fontSize: 11,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        children: [
          const Icon(Icons.currency_exchange, size: 14, color: Colors.teal),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '≈ $profileSymbol${converted.toStringAsFixed(2)} $profileCode via Frankfurter',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.teal.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subscriptionToEdit != null;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Subscription' : 'Add Subscription',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Subscription Title *',
                  hintText: 'e.g. Netflix, Spotify, Gym, Rent',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subscriptions_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Enter subscription name'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount *',
                        prefixText:
                            '${CurrencySymbol().getSymbol(_selectedCurrency)} ',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter amount';
                        }
                        final amount = double.tryParse(val.trim());
                        if (amount == null || !amount.isFinite || amount < 0) {
                          return 'Enter a valid amount of zero or more';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCurrency,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 15,
                        ),
                      ),
                      items: _currencies
                          .map(
                            (curr) => DropdownMenuItem(
                              value: curr,
                              child: Text(
                                '${CurrencySymbol().getSymbol(curr)} $curr',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCurrency = val;
                          });
                          _updateLiveConversion();
                        }
                      },
                    ),
                  ),
                ],
              ),
              _buildLiveConversionHint(theme),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCycle,
                decoration: const InputDecoration(
                  labelText: 'Billing Cycle',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: _billingCycles
                    .map(
                      (cycle) =>
                          DropdownMenuItem(value: cycle, child: Text(cycle)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCycle = val;
                      _recalculateNextBillingDate();
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              _isLoadingCategories
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<Category>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _categories
                          .map(
                            (cat) => DropdownMenuItem<Category>(
                              value: cat,
                              child: Text(cat.category),
                            ),
                          )
                          .toList(),
                      onChanged: (cat) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                    ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickStartDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          dateFormat.format(_startDate),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickNextBillingDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Next Due Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event),
                        ),
                        child: Text(
                          dateFormat.format(_nextBillingDate),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedPaymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payment),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None'),
                  ),
                  ..._paymentMethods.map(
                    (m) => DropdownMenuItem(value: m, child: Text(m)),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedPaymentMethod = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-flag for logging'),
                subtitle: const Text(
                  'Highlight on home screen when due for easy 1-tap logging',
                ),
                value: _autoLogExpense,
                onChanged: (val) {
                  setState(() {
                    _autoLogExpense = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveSubscription,
                  icon: const Icon(Icons.check),
                  label: Text(
                    isEditing ? 'Update Subscription' : 'Save Subscription',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
