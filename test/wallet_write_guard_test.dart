import 'dart:async';

import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/db/wallet_write_queue.dart';
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

  for (final refund in [false, true]) {
    test(
      'blocks wallet edits when rollback retirement fails (refund: $refund)',
      () async {
        SharedPreferences.resetStatic();
        final disk = <String, Object>{
          'flutter.$cash': 100.0,
          'flutter.$total': 100.0,
        };
        var failRetirement = false;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getAll') return disk;
          final key = call.arguments['key'] as String;
          if (failRetirement && key == 'flutter.$pending') return false;
          if (call.method == 'remove') {
            disk.remove(key);
          } else {
            disk[key] = call.arguments['value'] as Object;
          }
          return true;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final prefs = await SharedPreferences.getInstance();
        final helper = DatabaseHelper.forTesting(
          (wallet) => wallet.recover((_, _, _) async => refund),
        );
        await expectLater(
          helper.withWalletWrite(() async {
            // Model a failed SQLite transaction after wallet writes.
            final wallet = await SharedPreferences.getInstance();
            // Set up the same recovery record as apply() without depending on SQLite.
            await wallet.setString(
              pending,
              '{"expenseId":41,"profileId":1,"entryDate":"date","refund":$refund,"before":{"$cash":100.0,"$total":100.0}}',
            );
            await wallet.setDouble(cash, refund ? 120 : 80);
            await wallet.setDouble(total, refund ? 120 : 80);
            failRetirement = true;
            throw StateError('database rollback');
          }),
          throwsStateError,
        );
        var wrote = false;
        await expectLater(
          helper.withWalletWrite(() async {
            wrote = true;
            await prefs.setDouble(cash, 70);
          }),
          throwsStateError,
        );
        expect(wrote, isFalse);
        expect(prefs.getDouble(cash), 100);
        failRetirement = false;
        await helper.withWalletWrite(() async {
          await prefs.setDouble(cash, 70);
          await prefs.setDouble(total, 70);
        });
        await helper.recoverExpenseWallet();
        expect(prefs.getDouble(cash), 70);
        expect(prefs.getDouble(total), 70);
      },
    );
  }

  test('queue keeps later writes behind an in-flight operation', () async {
    final queue = WalletWriteQueue();
    final started = Completer<void>();
    final release = Completer<void>();
    final events = <String>[];
    final first = queue.run(() async {
      events.add('first');
      started.complete();
      await release.future;
      events.add('finished');
    });
    await started.future;
    final second = queue.run(() async {
      events.add('second');
    });
    await Future<void>.delayed(Duration.zero);
    expect(events, ['first']);
    release.complete();
    await Future.wait([first, second]);
    expect(events, ['first', 'finished', 'second']);
  });
}
