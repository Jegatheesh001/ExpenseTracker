import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pref_keys.dart';
import 'currency_symbol.dart';

class BankCashTransferScreen extends StatefulWidget {
  final int profileId;
  final VoidCallback onBalanceUpdate;

  const BankCashTransferScreen({
    super.key,
    required this.profileId,
    required this.onBalanceUpdate,
  });

  @override
  State<BankCashTransferScreen> createState() => _BankCashTransferScreenState();
}

class _BankCashTransferScreenState extends State<BankCashTransferScreen> {
  final _amountController = TextEditingController();
  double _bankBalance = 0.0;
  double _cashBalance = 0.0;
  String _currencySymbol = '₹';
  late SharedPreferences _prefs;
  bool _isLoading = true;
  bool _isWithdrawal = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    final currency = _prefs.getString('${PrefKeys.selectedCurrency}-${widget.profileId}') ?? 'Rupee';
    setState(() {
      _bankBalance = _prefs.getDouble('${PrefKeys.bankAmount}-${widget.profileId}') ?? 0.0;
      _cashBalance = _prefs.getDouble('${PrefKeys.cashAmount}-${widget.profileId}') ?? 0.0;
      _currencySymbol = CurrencySymbol().getSymbol(currency);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _processTransaction() async {
    final amountText = _amountController.text;
    if (amountText.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (_isWithdrawal) {
      if (amount > _bankBalance) {
        _showError('Insufficient bank balance');
        return;
      }
    } else {
      if (amount > _cashBalance) {
        _showError('Insufficient cash balance');
        return;
      }
    }

    // Process transaction
    final newBankBalance = _isWithdrawal ? _bankBalance - amount : _bankBalance + amount;
    final newCashBalance = _isWithdrawal ? _cashBalance + amount : _cashBalance - amount;

    await _prefs.setDouble('${PrefKeys.bankAmount}-${widget.profileId}', newBankBalance);
    await _prefs.setDouble('${PrefKeys.cashAmount}-${widget.profileId}', newCashBalance);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isWithdrawal
                ? 'Successfully withdrawn $_currencySymbol${amount.toStringAsFixed(2)}'
                : 'Successfully deposited $_currencySymbol${amount.toStringAsFixed(2)} into bank',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onBalanceUpdate();
      Navigator.of(context).pop(true);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank & Cash Transfer'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBalanceCard(theme),
            const SizedBox(height: 24),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Withdraw'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Deposit'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_isWithdrawal},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _isWithdrawal = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              _isWithdrawal ? 'Enter Withdrawal Amount' : 'Enter Deposit Amount',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                prefixText: _currencySymbol,
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),
            _buildQuickAmountButtons(theme),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: _processTransaction,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(_isWithdrawal ? Icons.account_balance_wallet : Icons.account_balance),
              label: Text(_isWithdrawal ? 'Withdraw Cash' : 'Deposit into Bank', style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
            Text(
              _isWithdrawal
                  ? 'This will deduct from your Bank Balance and add to your Cash Balance.'
                  : 'This will deduct from your Cash Balance and add to your Bank Balance.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBalanceInfo('Bank Balance', _bankBalance, Colors.white, theme),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
              ),
              _buildBalanceInfo('Cash Balance', _cashBalance, Colors.white, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo(String label, double amount, Color textColor, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: textColor.withOpacity(0.8)),
        ),
        const SizedBox(height: 4),
        Text(
          '$_currencySymbol${amount.toStringAsFixed(2)}',
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAmountButtons(ThemeData theme) {
    final amounts = [100, 200, 500, 1000, 2000, 5000];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: amounts.map((amount) {
        return InkWell(
          onTap: () {
            _amountController.text = amount.toString();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_currencySymbol$amount',
              style: theme.textTheme.labelLarge,
            ),
          ),
        );
      }).toList(),
    );
  }
}
