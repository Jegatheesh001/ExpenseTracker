import 'package:expense_tracker/db/expense_wallet_change.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const cash = '${PrefKeys.cashAmount}-1';
  const total = '${PrefKeys.walletAmount}-1';
  const pending = PrefKeys.pendingSubscriptionWalletDebit;

  for (final committed in [true, false]) {
    test(
      'failed cleanup cannot replay a resolved change (committed: $committed)',
      () async {
        SharedPreferences.resetStatic();
        final disk = <String, Object>{
          'flutter.$cash': 100.0,
          'flutter.$total': 100.0,
        };
        var failCleanup = true;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getAll') return disk;
          final key = call.arguments['key'] as String;
          if (call.method == 'remove') {
            if (failCleanup && key == 'flutter.$pending') return false;
            disk.remove(key);
          } else {
            disk[key] = call.arguments['value'] as Object;
          }
          return true;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

        var prefs = await SharedPreferences.getInstance();
        var wallet = ExpenseWalletChange(prefs);
        await wallet.apply(
          account: PrefKeys.cashAmount,
          profileId: 1,
          expenseId: 41,
          entryDate: '2026-11-22T09:30:00.000',
          amount: 20,
        );
        if (committed) {
          await wallet.finish();
        } else {
          await wallet.recover((_, _, _) async => false);
          expect(prefs.getDouble(cash), 100.0);
          expect(prefs.getDouble(total), 100.0);
        }
        expect(disk['flutter.$pending'], '{"resolved":true}');

        await prefs.setDouble(cash, 70);
        await prefs.setDouble(total, 70);
        SharedPreferences.resetStatic();
        prefs = await SharedPreferences.getInstance();
        wallet = ExpenseWalletChange(prefs);
        failCleanup = false;
        await wallet.recover(
          (_, _, _) async => throw StateError('Already resolved'),
        );

        expect(prefs.getDouble(cash), 70.0);
        expect(prefs.getDouble(total), 70.0);
        expect(prefs.containsKey(pending), isFalse);
      },
    );
  }
}
