import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/persistence_context.dart';
import 'pref_keys.dart';
import 'currency_symbol.dart';

class DashboardScreen extends StatefulWidget {
  final int profileId;
  final Function(int) navigateToExpensesTab;

  const DashboardScreen({
    super.key,
    required this.profileId,
    required this.navigateToExpensesTab,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  double _todayExpense = 0.0;
  double _monthlyExpense = 0.0;
  double _todayChange = 0.0;
  double _monthlyChange = 0.0;
  double _cashBalance = 0.0;
  double _bankBalance = 0.0;
  String _currencySymbol = '₹';
  late SharedPreferences _prefs;

  // New text editing controllers for balance management dialog
  late final TextEditingController _cashAmountController = TextEditingController();
  late final TextEditingController _bankAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _cashAmountController.dispose();
    _bankAmountController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadBalances();
    await _loadExpenses();
    _loadCurrency();
  }

  Future<void> _loadBalances() async {
    setState(() {
      _cashBalance = _prefs.getDouble('${PrefKeys.cashAmount}-${widget.profileId}') ?? 0.0;
      _bankBalance = _prefs.getDouble('${PrefKeys.bankAmount}-${widget.profileId}') ?? 0.0;
    });
  }

  void _loadCurrency() {
    final currency = _prefs.getString('${PrefKeys.selectedCurrency}-${widget.profileId}') ?? 'Rupee';
    setState(() {
      _currencySymbol = CurrencySymbol().getSymbol(currency);
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    } else if (hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
  }

  Future<void> _loadExpenses() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastMonth = DateTime(now.year, now.month - 1, now.day);

    final todayExp = await PersistenceContext().getExpenseSumByDate(today, widget.profileId);
    final yesterdayExp = await PersistenceContext().getExpenseSumByDate(yesterday, widget.profileId);
    
    final currentMonthExp = await PersistenceContext().getExpenseSumByMonth(now, widget.profileId);
    final lastMonthExp = await PersistenceContext().getExpenseSumByMonth(lastMonth, widget.profileId);

    setState(() {
      _todayExpense = todayExp;
      _monthlyExpense = currentMonthExp;
      
      if (yesterdayExp > 0) {
        _todayChange = ((todayExp - yesterdayExp) / yesterdayExp) * 100;
      } else if (todayExp > 0) {
        _todayChange = 100.0;
      }

      if (lastMonthExp > 0) {
        _monthlyChange = ((currentMonthExp - lastMonthExp) / lastMonthExp) * 100;
      } else if (currentMonthExp > 0) {
        _monthlyChange = 100.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Jegatheesh',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildTodayCard()),
                    const SizedBox(width: 15),
                    Expanded(child: _buildMonthlyCard()),
                  ],
                ),
                const SizedBox(height: 30),
                _buildBalancesHeader(),
                const SizedBox(height: 15),
                _buildBalanceItem(
                  icon: Icons.wallet_rounded,
                  title: 'Cash Balance',
                  subtitle: 'Wallet & Pocket',
                  amount: _cashBalance,
                  iconColor: Colors.orange,
                ),
                const SizedBox(height: 15),
                _buildBalanceItem(
                  icon: Icons.account_balance_rounded,
                  title: 'Bank Account',
                  subtitle: '*****', // Placeholder as per design
                  amount: _bankBalance,
                  iconColor: Colors.blueAccent,
                ),
                const SizedBox(height: 30),
                _buildFinancialWisdomHeader(),
                const SizedBox(height: 15),
                _buildTipCard(),
                const SizedBox(
                    height: 100), // Extra space for FAB and Bottom Nav
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCard() {
    return InkWell(
      onTap: () => widget.navigateToExpensesTab(0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1F2B36) // A slightly darker, appealing blue-grey shade for card surface
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16), // Softer, more modern corners
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Icon(Icons.calendar_today_outlined,
                    color: Theme.of(context).colorScheme.onSurface, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$_currencySymbol ${_todayExpense.toStringAsFixed(1)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _todayChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Theme.of(context).colorScheme.primary,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_todayChange.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCard() {
    return InkWell(
      onTap: () => widget.navigateToExpensesTab(1),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1F2B36) // Consistent card color
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16), // Consistent border radius
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Icon(Icons.bar_chart_rounded,
                    color: Theme.of(context).colorScheme.onSurface, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$_currencySymbol ${_monthlyExpense.toStringAsFixed(1)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _monthlyChange <= 0
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _monthlyChange <= 0
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: _monthlyChange <= 0 ? Colors.green : Colors.red,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_monthlyChange.abs().toStringAsFixed(0)}%',
                          style: TextStyle(
                            color:
                                _monthlyChange <= 0 ? Colors.green : Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'vs last month',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Your Balance',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: _showBalanceManagementDialog,
          child: Text(
            'Manage',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required double amount,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1F2B36) // Consistent card color
            : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16), // Consistent border radius
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '$_currencySymbol${amount.toStringAsFixed(2)}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialWisdomHeader() {
    return Text(
      'Financial Wisdom',
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1F2B36) // Consistent card color
            : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16), // Consistent border radius
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Tip of the Day',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            'Track small purchases like coffee and snacks. They add up quickly and are the easiest expenses to reduce!',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('READ MORE',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward,
                    color: Theme.of(context).colorScheme.primary, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New method to show the balance management dialog, similar to SettingsScreen
  Future<void> _showBalanceManagementDialog() async {
    _cashAmountController.text = _cashBalance.toStringAsFixed(2);
    _bankAmountController.text = _bankBalance.toStringAsFixed(2);

    double tempCashAmount = _cashBalance;
    double tempBankAmount = _bankBalance;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (context, setState) {
            final total = (tempCashAmount + tempBankAmount).toStringAsFixed(2);

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
                child: Column(
                  children: [
                    Text(
                      'Total Balance',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_currencySymbol $total',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
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
                    // CASH INPUT
                    TextField(
                      controller: _cashAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText: 'Cash Amount',
                        prefixText: '$_currencySymbol ',
                        prefixIcon: const Icon(Icons.money_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      onChanged: (value) {
                        setState(() {
                          tempCashAmount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // BANK INPUT
                    TextField(
                      controller: _bankAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText: 'Bank Amount',
                        prefixText: '$_currencySymbol ',
                        prefixIcon: const Icon(Icons.account_balance_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      onChanged: (value) {
                        setState(() {
                          tempBankAmount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              actions: <Widget>[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                        ),
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Update'),
                        onPressed: () async {
                          final double? newCashAmount = double.tryParse(
                            _cashAmountController.text,
                          );
                          final double? newBankAmount = double.tryParse(
                            _bankAmountController.text,
                          );

                          if (newCashAmount != null &&
                              newCashAmount >= 0 &&
                              newBankAmount != null &&
                              newBankAmount >= 0) {
                            await _saveNewAmounts(newCashAmount, newBankAmount);
                            Navigator.of(dialogContext).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Please enter valid non-negative amounts.',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                )
              ],
            );
          },
        );
      },
      // Dispose controllers after the dialog is closed.
    ).then((_) {
      // Controllers are now disposed in the dispose method of the State
    });
  }

  // Helper function to save amounts and refresh state
  Future<void> _saveNewAmounts(double newCashAmount, double newBankAmount) async {
    await _prefs.setDouble('${PrefKeys.cashAmount}-${widget.profileId}', newCashAmount);
    await _prefs.setDouble('${PrefKeys.bankAmount}-${widget.profileId}', newBankAmount);
    await _prefs.setDouble('${PrefKeys.walletAmount}-${widget.profileId}', newCashAmount + newBankAmount);
    
    // Update local state and refresh dashboard data
    await _loadBalances(); // This will call setstate
  }
}
