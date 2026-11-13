import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/db/persistence_context.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/widgets/expense_list_view.dart';
import 'package:expense_tracker/screens/expenses/add_expense_screen.dart';
import 'package:expense_tracker/widgets/month_view.dart';
import 'package:expense_tracker/utils/expense_category_filter.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:expense_tracker/widgets/expense_search_delegate.dart';
import 'package:expense_tracker/widgets/expense_action_menu.dart';

class ExpensesScreen extends StatefulWidget {
  final int profileId;
  final String currencySymbol;
  final VoidCallback onWalletAmountChange;
  final VoidCallback onAddExpense;
  final int initialTabIndex;

  const ExpensesScreen({
    super.key,
    required this.profileId,
    required this.currencySymbol,
    required this.onWalletAmountChange,
    required this.onAddExpense,
    this.initialTabIndex = 0,
  });

  @override
  State<ExpensesScreen> createState() => ExpensesScreenState();
}

class ExpensesScreenState extends State<ExpensesScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Expense> _expenses = [];
  double _expensesTotal = 0;
  double _percentageChange = 0;
  bool _isMonthView = false;
  Key _monthViewKey = UniqueKey();
  bool _showExpStatusBar = false;
  double _monthlyLimit = 0;
  double _monthlyLimitPerc = 0;
  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _isInitialized = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _isMonthView = widget.initialTabIndex == 1;
    _initData();
  }

  @override
  void didUpdateWidget(ExpensesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized && widget.profileId != oldWidget.profileId) {
      refresh();
    }
  }

  void setTab(int index) {
    setState(() {
      _isMonthView = index == 1;
    });
    refresh();
  }

  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    await _loadCategories();
    if (!mounted) return;
    await _loadExpStatusBar();
    if (!mounted) return;
    refresh();
  }

  void refresh() {
    if (!_isInitialized) return;

    _loadCategories();
    _loadExpenses();
    _calculateSelectedMonthSpending();
  }

  Future<void> _loadCategories() async {
    final categories = await PersistenceContext().getCategories();
    if (!mounted) return;

    final selectedCategoryWasRemoved =
        _selectedCategoryId != null &&
        !categories.any(
          (category) => category.categoryId == _selectedCategoryId,
        );
    setState(() {
      _categories = categories;
      if (selectedCategoryWasRemoved) {
        _selectedCategoryId = null;
      }
    });
    if (selectedCategoryWasRemoved) {
      _loadExpenses();
    }
  }

  String? get _selectedCategoryName {
    final selectedCategoryId = _selectedCategoryId;
    if (selectedCategoryId == null) return null;

    for (final category in _categories) {
      if (category.categoryId == selectedCategoryId) {
        return category.category;
      }
    }
    return null;
  }

  Future<void> _loadExpStatusBar() async {
    bool status = _prefs.getBool(PrefKeys.showExpStatusBar) ?? false;
    if (!mounted) return;
    setState(() {
      _showExpStatusBar = status;
    });
  }

  Future<void> _loadExpenses() async {
    if (_isMonthView) {
      setState(() {
        _monthViewKey = UniqueKey();
      });
    } else {
      await _loadSelectedDateExpense();
    }
  }

  Future<void> _loadSelectedDateExpense() async {
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final loadedExpenses = await PersistenceContext().getExpensesByDate(
      startOfDay,
      startOfDay,
      widget.profileId,
    );
    if (!mounted ||
        startOfDay !=
            DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            )) {
      return;
    }
    final filteredExpenses = filterExpensesByCategory(
      loadedExpenses,
      _selectedCategoryId,
    );
    setState(() {
      _expensesTotal = filteredExpenses.fold(
        0.0,
        (sum, item) => sum + item.amount,
      );
      _expenses = filteredExpenses;
    });
    _showPreviousDayPercentageChange(startOfDay, _selectedCategoryId);
  }

  Future<void> _showPreviousDayPercentageChange(
    DateTime selectedDay,
    int? categoryId,
  ) async {
    final previousDay = selectedDay.subtract(const Duration(days: 1));
    final double previousDayTotal;
    if (categoryId == null) {
      previousDayTotal = await PersistenceContext().getExpenseSumByDate(
        previousDay,
        widget.profileId,
      );
    } else {
      final previousDayExpenses = await PersistenceContext().getExpensesByDate(
        previousDay,
        previousDay,
        widget.profileId,
      );
      previousDayTotal = filterExpensesByCategory(
        previousDayExpenses,
        categoryId,
      ).fold(0.0, (sum, expense) => sum + expense.amount);
    }
    if (!mounted ||
        selectedDay !=
            DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            ) ||
        categoryId != _selectedCategoryId) {
      return;
    }
    double percentageChange = 0;
    if (previousDayTotal == 0 && _expensesTotal > 0) {
      percentageChange = 100;
    } else if (_expensesTotal > 0.0) {
      percentageChange =
          ((_expensesTotal - previousDayTotal) / previousDayTotal) * 100;
    }
    setState(() {
      _percentageChange = percentageChange;
    });
  }

  Future<void> _showCategoryFilter() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text(
                    'Filter by category',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.category_outlined),
                        title: const Text('All categories'),
                        trailing: _selectedCategoryId == null
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _selectCategory(null);
                        },
                      ),
                      for (final category in _categories)
                        ListTile(
                          leading: const Icon(Icons.label_outline),
                          title: Text(category.category),
                          trailing: _selectedCategoryId == category.categoryId
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _selectCategory(category.categoryId);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;

    setState(() {
      _selectedCategoryId = categoryId;
    });
    refresh();
  }

  Future<void> _calculateSelectedMonthSpending() async {
    String monthlyLimitStr = _prefs.getString(PrefKeys.monthlyLimit) ?? '';
    if (monthlyLimitStr != '') {
      double monthlyExp = await PersistenceContext().getExpenseSumByMonth(
        _selectedDate,
        widget.profileId,
      );
      double monthlyLimit = double.parse(monthlyLimitStr);
      double monthlyLimitPerc = 1.0;
      if (monthlyExp < monthlyLimit) {
        monthlyLimitPerc = monthlyExp / monthlyLimit;
      }
      setState(() {
        _monthlyLimit = monthlyLimit;
        _monthlyLimitPerc = monthlyLimitPerc;
      });
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          expenseToEdit: expense,
          onWalletAmountChange: () {
            widget.onWalletAmountChange();
          },
        ),
      ),
    );
    if (result == true) {
      refresh();
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    await PersistenceContext().deleteExpense(expense.id!);
    await _updateWalletOnExpenseDeletion(expense);
    refresh();
  }

  Future<void> _updateWalletOnExpenseDeletion(Expense expense) async {
    if (expense.paymentMethod != null &&
        expense.paymentMethod != PaymentMethod.none.name) {
      String prefKey = expense.paymentMethod == PaymentMethod.cash.name
          ? PrefKeys.cashAmount
          : PrefKeys.bankAmount;
      double currentAmount =
          _prefs.getDouble('$prefKey-${widget.profileId}') ?? 0.0;
      double newAmount = currentAmount + expense.amount;
      await _prefs.setDouble('$prefKey-${widget.profileId}', newAmount);

      double totalWalletAmount =
          _prefs.getDouble('${PrefKeys.walletAmount}-${widget.profileId}') ??
          0.0;
      double newTotalWalletAmount = totalWalletAmount + expense.amount;
      await _prefs.setDouble(
        '${PrefKeys.walletAmount}-${widget.profileId}',
        newTotalWalletAmount,
      );

      widget.onWalletAmountChange();
    }
  }

  void _addDayToCurrent(int daysToAdd) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: daysToAdd));
    });
    refresh();
  }

  void _addMonthToCurrent(int monthsToAdd) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + monthsToAdd,
        _selectedDate.day,
      );
    });
    refresh();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      refresh();
    }
  }

  void _updateMonthlyTotal(double total) {
    setState(() {
      _expensesTotal = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  bottom: 4,
                ),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: 16.0,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Total Expenses',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${widget.currencySymbol} ${_expensesTotal.toStringAsFixed(2)}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (!_isMonthView) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _percentageChange > 0
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : _percentageChange < 0
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.05,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _percentageChange > 0
                                          ? Icons.arrow_upward
                                          : _percentageChange < 0
                                          ? Icons.arrow_downward
                                          : Icons.remove,
                                      color: _percentageChange > 0
                                          ? Colors.red
                                          : _percentageChange < 0
                                          ? Colors.green
                                          : theme.colorScheme.onSurfaceVariant,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_percentageChange.abs().toStringAsFixed(1)}%',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: _percentageChange > 0
                                                ? Colors.red
                                                : _percentageChange < 0
                                                ? Colors.green
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showExpStatusBar)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Tooltip(
                    message:
                        'Monthly Limit: $_monthlyLimit Used: ${(_monthlyLimitPerc * 100).toStringAsFixed(2)}%',
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0,
                        thumbShape: SliderComponentShape.noThumb,
                      ),
                      child: Slider(
                        value: _monthlyLimitPerc,
                        onChanged: (double value) {},
                        activeColor: _monthlyLimitPerc > 0.8
                            ? Colors.red
                            : Colors.green,
                        inactiveColor: Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(value: false, label: Text('Day')),
                    ButtonSegment<bool>(value: true, label: Text('Month')),
                  ],
                  selected: <bool>{_isMonthView},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _isMonthView = newSelection.first;
                    });
                    refresh();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _isMonthView
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _addMonthToCurrent(-1),
                          ),
                          TextButton(
                            onPressed: () => _selectDate(context),
                            child: Text(
                              DateFormat('MMMM yyyy').format(_selectedDate),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _addMonthToCurrent(1),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _addDayToCurrent(-1),
                          ),
                          TextButton(
                            onPressed: () => _selectDate(context),
                            child: Text(
                              DateFormat('dd MMMM yyyy').format(_selectedDate),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _addDayToCurrent(1),
                          ),
                        ],
                      ),
              ),
              //const SizedBox(height: 8.0),
              if (_isMonthView)
                Expanded(
                  child: MonthView(
                    key: _monthViewKey,
                    selectedDate: _selectedDate,
                    currencySymbol: widget.currencySymbol,
                    profileId: widget.profileId,
                    categoryId: _selectedCategoryId,
                    categoryName: _selectedCategoryName,
                    onEdit: _editExpense,
                    onTotalChanged: _updateMonthlyTotal,
                    updateWalletOnExpenseDeletion:
                        _updateWalletOnExpenseDeletion,
                  ),
                )
              else
                ExpenseListView(
                  expenses: _expenses,
                  currencySymbol: widget.currencySymbol,
                  onDelete: _deleteExpense,
                  onEdit: _editExpense,
                  emptyMessage: _selectedCategoryName == null
                      ? 'No expenses yet'
                      : 'No $_selectedCategoryName expenses for this day.',
                ),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: ExpenseActionMenu(
              activeCategoryName: _selectedCategoryName,
              onAdd: widget.onAddExpense,
              onFilter: _showCategoryFilter,
              onSearch: () {
                showSearch(
                  context: context,
                  delegate: ExpenseSearchDelegate(
                    profileId: widget.profileId,
                    currencySymbol: widget.currencySymbol,
                    onEdit: _editExpense,
                    onDelete: _deleteExpense,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
