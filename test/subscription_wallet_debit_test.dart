import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/expense_wallet_change.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cash = '${PrefKeys.cashAmount}-1';
  const bank = '${PrefKeys.bankAmount}-1';
  const total = '${PrefKeys.walletAmount}-1';
  const otherProfileCash = '${PrefKeys.cashAmount}-0';
  const pending = PrefKeys.pendingSubscriptionWalletDebit;
  late SharedPreferences prefs;
  late ExpenseWalletChange wallet;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      cash: 25.0,
      bank: 75.0,
      total: 100.0,
      otherProfileCash: 50.0,
    });
    prefs = await SharedPreferences.getInstance();
    wallet = ExpenseWalletChange(prefs);
  });

  Future<bool> debit(String account, double amount) => wallet.apply(
    account: account,
    profileId: 1,
    expenseId: 41,
    entryDate: '2026-11-22T09:30:00.000',
    amount: amount,
  );

  test('subscription payment labels map to the correct expense account', () {
    final methods = {
      'Cash': 'cash',
      'cash': 'cash',
      'Bank Transfer': 'bank',
      'Debit Card': 'bank',
      'UPI': 'bank',
      'bank': 'bank',
      'Credit Card': null,
      'Other': null,
      null: null,
    };
    for (final entry in methods.entries) {
      final subscription = Subscription(
        profileId: 1,
        title: 'Example',
        amount: 10.0,
        categoryId: 1,
        category: 'Food',
        billingCycle: 'Monthly',
        startDate: DateTime(2026, 10, 22),
        nextBillingDate: DateTime(2026, 11, 22),
        paymentMethod: entry.key,
      );
      expect(
        subscription.expensePaymentMethod,
        entry.value,
        reason: '${entry.key}',
      );
      expect(subscription.toMap()['paymentMethod'], entry.key);
    }
  });

  test('debits cash and the wallet total of the owning profile only', () async {
    expect(await debit(PrefKeys.cashAmount, 12.50), isTrue);
    await wallet.finish();
    expect(prefs.getDouble(cash), 12.50);
    expect(prefs.getDouble(bank), 75.0);
    expect(prefs.getDouble(total), 87.50);
    expect(prefs.getDouble(otherProfileCash), 50.0);
    expect(prefs.containsKey(pending), isFalse);
  });

  test(
    'bank can be debited to zero and untracked methods use no account',
    () async {
      expect(ExpenseWalletChange.accountFor('bank'), PrefKeys.bankAmount);
      expect(ExpenseWalletChange.accountFor('none'), isNull);
      expect(ExpenseWalletChange.accountFor(null), isNull);
      expect(await debit(PrefKeys.bankAmount, 75.0), isTrue);
      await wallet.finish();
      expect(prefs.getDouble(bank), 0.0);
      expect(prefs.getDouble(cash), 25.0);
      expect(prefs.getDouble(total), 25.0);
    },
  );

  test('insufficient funds leave balances and recovery state alone', () async {
    expect(await debit(PrefKeys.cashAmount, 30.0), isFalse);
    expect(prefs.getDouble(cash), 25.0);
    expect(prefs.getDouble(total), 100.0);
    expect(prefs.containsKey(pending), isFalse);
  });

  test('recovery restores balances when the SQL payment rolled back', () async {
    await prefs.remove(total);
    await debit(PrefKeys.cashAmount, 10.0);
    await prefs.reload();
    await wallet.recover((_, _, _) async => false);
    expect(prefs.getDouble(cash), 25.0);
    expect(prefs.getDouble(bank), 75.0);
    expect(prefs.containsKey(total), isFalse);
    expect(prefs.containsKey(pending), isFalse);
  });

  test('committed debit recovery preserves a newer wallet balance', () async {
    await debit(PrefKeys.bankAmount, 10.0);
    await prefs.setDouble(bank, 55.0);
    await prefs.setDouble(total, 80.0);
    await prefs.reload();
    await wallet.recover((expenseId, profileId, entryDate) async {
      expect(expenseId, 41);
      expect(profileId, 1);
      expect(entryDate, '2026-11-22T09:30:00.000');
      return true;
    });
    await wallet.recover(
      (_, _, _) async => throw StateError('Already recovered'),
    );
    expect(prefs.getDouble(bank), 55.0);
    expect(prefs.getDouble(total), 80.0);
    expect(prefs.containsKey(pending), isFalse);
  });
  for (final expenseExists in [false, true]) {
    test(
      'refund recovery checks whether the expense still exists ($expenseExists)',
      () async {
        expect(
          await wallet.apply(
            account: PrefKeys.bankAmount,
            profileId: 1,
            expenseId: 41,
            entryDate: '2026-11-22T09:30:00.000',
            amount: 20,
            refund: true,
          ),
          isTrue,
        );
        await wallet.recover((_, _, _) async => expenseExists);
        expect(prefs.getDouble(bank), expenseExists ? 75.0 : 95.0);
        expect(prefs.getDouble(total), expenseExists ? 100.0 : 120.0);
        expect(prefs.getDouble(otherProfileCash), 50.0);
        expect(prefs.containsKey(pending), isFalse);
      },
    );
  }

  test('total-only wallets can cover cash but not bank payments', () async {
    await prefs.remove(cash);
    await prefs.remove(bank);
    expect(wallet.balanceFor(PrefKeys.cashAmount, 1), 100.0);
    expect(wallet.balanceFor(PrefKeys.bankAmount, 1), 0.0);
    expect(await debit(PrefKeys.bankAmount, 20), isFalse);
    expect(prefs.containsKey(pending), isFalse);
    expect(await debit(PrefKeys.cashAmount, 20), isTrue);
    expect(prefs.getDouble(cash), 80.0);
    expect(prefs.getDouble(total), 80.0);

    await wallet.recover((_, _, _) async => false);
    expect(prefs.containsKey(cash), isFalse);
    expect(prefs.getDouble(total), 100.0);

    expect(await debit(PrefKeys.cashAmount, 20), isTrue);
    await wallet.finish();
    expect(prefs.getDouble(cash), 80.0);
    expect(prefs.getDouble(total), 80.0);
    expect(prefs.getDouble(otherProfileCash), 50.0);
  });

  test('refund preserves cash in a wallet with only a legacy total', () async {
    await prefs.remove(cash);
    await prefs.remove(bank);
    expect(
      await wallet.apply(
        account: PrefKeys.bankAmount,
        profileId: 1,
        expenseId: 41,
        entryDate: '2026-11-22T09:30:00.000',
        amount: 20,
        refund: true,
      ),
      isTrue,
    );
    expect(prefs.getDouble(cash), 100.0);
    expect(prefs.getDouble(bank), 20.0);
    expect(prefs.getDouble(total), 120.0);
    await wallet.recover((_, _, _) async => true);
    expect(prefs.containsKey(cash), isFalse);
    expect(prefs.containsKey(bank), isFalse);
    expect(prefs.getDouble(total), 100.0);
  });

  test('original subscription labels do not identify a debited account', () {
    for (final method in [
      'Cash',
      'Bank Transfer',
      'UPI',
      'Debit Card',
      'none',
    ]) {
      expect(ExpenseWalletChange.accountFor(method), isNull);
    }
  });
}
