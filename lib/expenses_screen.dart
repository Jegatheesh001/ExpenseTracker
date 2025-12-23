import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/persistence_context.dart';
import 'db/entity.dart';
import 'expense_list_view.dart';
import 'add_expense_screen.dart';
import 'month_view.dart';
import 'pref_keys.dart';
import 'expense_search_delegate.dart';

class ExpensesScreen extends StatefulWidget {
  final int profileId;
  final String currencySymbol;
  final VoidCallback onWalletAmountChange;

  const ExpensesScreen({
    super.key,
    required this.profileId,
    required this.currencySymbol,
    required this.onWalletAmountChange,
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
  double _walletAmount = 0.0;
  bool _showExpStatusBar = false;
  double _monthlyLimit = 0;
  double _monthlyLimitPerc = 0;
  double _currMonthExp = 0;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();
    _loadExpStatusBar();
    _loadWalletAmount();
    refresh();
  }

  void refresh() {
    _loadExpenses();
    _calculateSelectedMonthSpending();
  }

  Future<void> _loadExpStatusBar() async {
    bool status = _prefs.getBool(PrefKeys.showExpStatusBar) ?? false;
    setState(() {
      _showExpStatusBar = status;
    });
  }

  Future<void> _loadWalletAmount() async {
    setState(() {
      _walletAmount = _prefs.getDouble('${PrefKeys.walletAmount}-${widget.profileId}') ?? 0.0;
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
    setState(() {
      _expensesTotal = loadedExpenses.fold(0.0, (sum, item) => sum + item.amount);
      _expenses = loadedExpenses;
    });
    _showPreviousDayPercentageChange();
  }

  void _showPreviousDayPercentageChange() async {
    final previousDay = _selectedDate.subtract(const Duration(days: 1));
    final previousDayTotal = await PersistenceContext().getExpenseSumByDate(
      previousDay, widget.profileId
    );
    double percentageChange = 0;
    if (previousDayTotal == 0 && _expensesTotal > 0) {
      percentageChange = 100;
    } else if (_expensesTotal > 0.0) {
      percentageChange = ((_expensesTotal - previousDayTotal) / previousDayTotal) * 100;
    }
    setState(() {
      _percentageChange = percentageChange;
    });
  }

  Future<void> _calculateSelectedMonthSpending() async {
    String monthlyLimitStr = _prefs.getString(PrefKeys.monthlyLimit) ?? '';
    if (monthlyLimitStr != '') {
      double monthlyExp = await PersistenceContext().getExpenseSumByMonth(
        _selectedDate, widget.profileId
      );
      double monthlyLimit = double.parse(monthlyLimitStr);
      double monthlyLimitPerc = 1.0;
      if (monthlyExp < monthlyLimit) {
        monthlyLimitPerc = monthlyExp / monthlyLimit;
      }
      setState(() {
        _monthlyLimit = monthlyLimit;
        _monthlyLimitPerc = monthlyLimitPerc;
        _currMonthExp = monthlyExp;
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
            _loadWalletAmount();
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
    if (expense.paymentMethod != null && expense.paymentMethod != PaymentMethod.none.name) {
      String prefKey = expense.paymentMethod == PaymentMethod.cash.name
          ? PrefKeys.cashAmount
          : PrefKeys.bankAmount;
      double currentAmount = _prefs.getDouble('$prefKey-${widget.profileId}') ?? 0.0;
      double newAmount = currentAmount + expense.amount;
      await _prefs.setDouble('$prefKey-${widget.profileId}', newAmount);

      double totalWalletAmount = _prefs.getDouble('${PrefKeys.walletAmount}-${widget.profileId}') ?? 0.0;
      double newTotalWalletAmount = totalWalletAmount + expense.amount;
      await _prefs.setDouble('${PrefKeys.walletAmount}-${widget.profileId}', newTotalWalletAmount);
      
      _loadWalletAmount();
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
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + monthsToAdd, _selectedDate.day);
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

  Future<void> _showWalletDetailsDialog() async {
    final double cashAmount = _prefs.getDouble('${PrefKeys.cashAmount}-${widget.profileId}') ?? 0.0;
    final double bankAmount = _prefs.getDouble('${PrefKeys.bankAmount}-${widget.profileId}') ?? 0.0;
    final double totalAmount = cashAmount + bankAmount;
    final theme = Theme.of(context);

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 24,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      'Total Balance',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.currencySymbol} ${totalAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: -10,
                  right: -10,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.money_outlined),
                    const SizedBox(width: 10),
                    const Text('Cash'),
                    const Spacer(),
                    Text('${widget.currencySymbol}${cashAmount.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.account_balance_outlined),
                    const SizedBox(width: 10),
                    const Text('Bank'),
                    const Spacer(),
                    Text('${widget.currencySymbol}${bankAmount.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _percentageChange > 0
                                      ? Colors.red.withOpacity(0.1)
                                      : _percentageChange < 0
                                          ? Colors.green.withOpacity(0.1)
                                          : theme.colorScheme.onSurface.withOpacity(0.05),
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
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: _percentageChange > 0
                                            ? Colors.red
                                            : _percentageChange < 0
                                                ? Colors.green
                                                : theme.colorScheme.onSurfaceVariant,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Tooltip(
                    message: 'Monthly Limit: $_monthlyLimit Used: ${(_monthlyLimitPerc * 100).toStringAsFixed(2)}%',
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0,
                        thumbShape: SliderComponentShape.noThumb,
                      ),
                      child: Slider(
                        value: _monthlyLimitPerc,
                        onChanged: (double value) {},
                        activeColor: _monthlyLimitPerc > 0.8 ? Colors.red : Colors.green,
                        inactiveColor: Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(value: false, label: Text('Day')),
                    ButtonSegment<bool>(value: true, label: Text('Month')),
                  ],
                  selected: <bool>{_isMonthView},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _isMonthView = newSelection.first;
                      refresh();
                    });
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
              const SizedBox(height: 8.0),
              if (_isMonthView)
                Expanded(
                  child: MonthView(
                    key: _monthViewKey,
                    selectedDate: _selectedDate,
                    currencySymbol: widget.currencySymbol,
                    profileId: widget.profileId,
                    onEdit: _editExpense,
                    onTotalChanged: _updateMonthlyTotal,
                    updateWalletOnExpenseDeletion: _updateWalletOnExpenseDeletion,
                  ),
                )
              else
                ExpenseListView(
                  expenses: _expenses,
                  currencySymbol: widget.currencySymbol,
                  onDelete: _deleteExpense,
                  onEdit: _editExpense,
                ),
            ],
          ),
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'expenses_search_fab',
              onPressed: () {
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
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              child: const Icon(Icons.search),
            ),
          ),
        ],
      ),
    );
  }
}
