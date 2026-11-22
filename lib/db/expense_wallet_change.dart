import 'dart:convert';

import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records enough information to reconcile SQLite and wallet preferences after
/// an interrupted expense debit or refund. This preference is local recovery data.
class ExpenseWalletChange {
  const ExpenseWalletChange(this.prefs);

  final SharedPreferences prefs;

  static String? accountFor(String? paymentMethod) => switch (paymentMethod) {
    'cash' => PrefKeys.cashAmount,
    'bank' => PrefKeys.bankAmount,
    _ => null,
  };

  double balanceFor(String account, int profileId) {
    final cash = prefs.getDouble('${PrefKeys.cashAmount}-$profileId');
    final bank = prefs.getDouble('${PrefKeys.bankAmount}-$profileId');
    if (account == PrefKeys.bankAmount) return bank ?? 0;
    // A legacy wallet without account keys holds its total in cash.
    return cash ??
        (bank == null
            ? prefs.getDouble('${PrefKeys.walletAmount}-$profileId') ?? 0
            : 0);
  }

  /// Returns false without changing preferences when the account cannot pay.
  Future<bool> apply({
    required String account,
    required int profileId,
    required int expenseId,
    required String entryDate,
    required double amount,
    bool refund = false,
  }) async {
    final accountKey = '$account-$profileId';
    final walletKey = '${PrefKeys.walletAmount}-$profileId';
    final otherAccount = account == PrefKeys.cashAmount
        ? PrefKeys.bankAmount
        : PrefKeys.cashAmount;
    final otherKey = '$otherAccount-$profileId';
    final savedBalance = prefs.getDouble(accountKey);
    final savedOtherBalance = prefs.getDouble(otherKey);
    final savedTotal = prefs.getDouble(walletKey);
    final balance = balanceFor(account, profileId);
    final otherBalance = balanceFor(otherAccount, profileId);
    if (!balance.isFinite || !otherBalance.isFinite) {
      throw StateError('Invalid wallet balance');
    }
    if (!refund && balance < amount) return false;

    final updatedBalance = refund ? balance + amount : balance - amount;
    final total = updatedBalance + otherBalance;
    if (!total.isFinite || (savedTotal != null && !savedTotal.isFinite)) {
      throw StateError('Invalid wallet total');
    }
    final restoreCash =
        otherAccount == PrefKeys.cashAmount &&
        savedOtherBalance == null &&
        otherBalance != 0;
    final before = {
      accountKey: savedBalance,
      walletKey: savedTotal,
      if (restoreCash) otherKey: savedOtherBalance,
    };
    final after = {
      accountKey: updatedBalance,
      walletKey: total,
      if (restoreCash) otherKey: otherBalance,
    };
    final saved = await prefs.setString(
      PrefKeys.pendingSubscriptionWalletDebit,
      jsonEncode({
        'expenseId': expenseId,
        'profileId': profileId,
        'entryDate': entryDate,
        if (refund) 'refund': true,
        'before': before,
      }),
    );
    if (!saved) throw StateError('Unable to record wallet update');
    await _writeBalances(after);
    return true;
  }

  Future<void> recover(
    Future<bool> Function(int expenseId, int profileId, String entryDate)
    expenseExists,
  ) async {
    final pending = prefs.getString(PrefKeys.pendingSubscriptionWalletDebit);
    if (pending == null) return;
    final record = jsonDecode(pending) as Map<String, dynamic>;
    if (record['resolved'] != true) {
      final exists = await expenseExists(
        record['expenseId'] as int,
        record['profileId'] as int,
        record['entryDate'] as String,
      );
      final committed = record['refund'] == true ? !exists : exists;
      // Balance writes finish before SQLite can commit. Only a rollback needs
      // a balance write during recovery.
      if (!committed) {
        final before = record['before'] as Map<String, dynamic>;
        await _writeBalances(
          before.map(
            (key, value) => MapEntry(key, (value as num?)?.toDouble()),
          ),
        );
      }
    }
    await finish();
  }

  Future<void> finish() async {
    const key = PrefKeys.pendingSubscriptionWalletDebit;
    if (!prefs.containsKey(key)) return;
    try {
      if (await prefs.remove(key)) return;
    } on Exception {
      // Retirement still needs to be recorded when removal throws.
    }

    // A durable marker lets recovery retry cleanup without replaying balances,
    // even if the expense is edited or deleted before the next startup.
    try {
      if (await prefs.setString(key, '{"resolved":true}')) return;
    } on Exception {
      // Reload below because SharedPreferences updates its cache optimistically.
    }
    await prefs.reload();
    throw StateError('Unable to retire the wallet recovery record');
  }

  Future<void> _writeBalances(Map<String, double?> balances) async {
    for (final entry in balances.entries) {
      final value = entry.value;
      final saved = value == null
          ? await prefs.remove(entry.key)
          : await prefs.setDouble(entry.key, value);
      if (!saved) throw StateError('Unable to persist wallet balance');
    }
  }
}
