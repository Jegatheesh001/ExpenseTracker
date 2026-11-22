import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/expense_wallet_change.dart';
import 'package:expense_tracker/utils/currency_symbol.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SubscriptionPaymentResult> logSubscriptionPaymentWithOptions(
  BuildContext context, {
  required Subscription subscription,
  required Expense expense,
  required DateTime nextDue,
  required String ownerCurrency,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final activeProfile = prefs.getInt(PrefKeys.profileId) ?? 0;
  final profileId = subscription.profileId;
  final currencyKey = '${PrefKeys.selectedCurrency}-$profileId';
  PaymentMethod? paymentOverride;
  while (context.mounted &&
      (prefs.getInt(PrefKeys.profileId) ?? 0) == activeProfile &&
      (prefs.getString(currencyKey) ?? 'Rupee') == ownerCurrency) {
    final result = await DatabaseHelper().logSubscriptionPayment(
      subscription: subscription,
      expense: expense,
      nextDue: nextDue,
      paymentOverride: paymentOverride,
    );
    if (result != SubscriptionPaymentResult.insufficientBalance ||
        !context.mounted) {
      return result;
    }
    final failedMethod = paymentOverride?.name ?? expense.paymentMethod;
    final alternative = failedMethod == PaymentMethod.cash.name
        ? PaymentMethod.bank
        : PaymentMethod.cash;
    final account = alternative == PaymentMethod.cash
        ? PrefKeys.cashAmount
        : PrefKeys.bankAmount;
    final balance = ExpenseWalletChange(prefs).balanceFor(account, profileId);
    final currency = CurrencySymbol().getCode(ownerCurrency) ?? ownerCurrency;
    paymentOverride = await showDialog<PaymentMethod>(
      context: context,
      builder: (context) => SubscriptionPaymentOptionsDialog(
        subscriptionTitle: subscription.title,
        otherProfileId: profileId == activeProfile ? null : profileId,
        alternative: alternative,
        alternativeBalance: balance,
        amount: expense.amount,
        currency: currency,
      ),
    );
    if (paymentOverride == null) return result;
  }
  return SubscriptionPaymentResult.stale;
}

class SubscriptionPaymentOptionsDialog extends StatelessWidget {
  const SubscriptionPaymentOptionsDialog({
    super.key,
    required this.subscriptionTitle,
    this.otherProfileId,
    required this.alternative,
    required this.alternativeBalance,
    required this.amount,
    required this.currency,
  });

  final String subscriptionTitle;
  final int? otherProfileId;
  final PaymentMethod alternative;
  final double alternativeBalance;
  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final useCash = alternative == PaymentMethod.cash;
    final funded = alternativeBalance.isFinite && alternativeBalance >= amount;
    final account = useCash ? 'cash' : 'bank';
    final profile = otherProfileId;
    return AlertDialog(
      title: Text('Insufficient ${useCash ? 'bank' : 'cash'} balance'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$subscriptionTitle · $currency ${amount.toStringAsFixed(2)}'),
            if (profile != null) Text('Profile #$profile'),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: funded,
              title: Text(useCash ? 'Use cash' : 'Use bank'),
              subtitle: Text(
                alternativeBalance.isFinite
                    ? '$currency ${alternativeBalance.toStringAsFixed(2)} available in $account'
                    : 'Balance unavailable',
              ),
              onTap: funded ? () => Navigator.pop(context, alternative) : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('None'),
              subtitle: const Text('Log the expense without a wallet debit'),
              onTap: () => Navigator.pop(context, PaymentMethod.none),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
