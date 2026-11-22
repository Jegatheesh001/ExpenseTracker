import 'dart:async';
import 'dart:convert';

import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/persistence_context.dart';
import 'package:expense_tracker/services/ai_service.dart';
import 'package:expense_tracker/services/chatbot_tool_catalog.dart';
import 'package:expense_tracker/services/chatbot_tools.dart';
import 'package:expense_tracker/services/currency_conversion_service.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _TestPersistence db;
  late ChatbotTools tools;
  late List<SubscriptionReview> reviews;
  late Future<bool> Function() confirm;
  late int refreshes;

  setUp(() async {
    db = _TestPersistence();
    reviews = [];
    refreshes = 0;
    confirm = () async => false;
    SharedPreferences.setMockInitialValues({
      PrefKeys.profileId: 1,
      '${PrefKeys.selectedCurrency}-1': 'Rupee',
      '${PrefKeys.walletAmount}-1': 999.0,
      '${PrefKeys.cashAmount}-1': 25.0,
      '${PrefKeys.bankAmount}-1': 75.0,
      '${PrefKeys.cashAmount}-0': 5000.0,
      PrefKeys.monthlyLimit: '150',
    });
    prefs = await SharedPreferences.getInstance();
    tools = ChatbotTools(
      profileId: 1,
      prefs: prefs,
      isCurrent: () => true,
      confirmExpense: (_, _) => confirm(),
      offerSubscriptionReview: reviews.add,
      onExpenseSaved: () => refreshes++,
      persistence: db,
      now: () => DateTime(2026, 11, 21, 14),
    );
  });

  tearDown(() => CurrencyConversionService.setMockInstance(null));

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> args = const {},
  ]) => tools.execute(AIFunctionCall(name: name, args: args));

  test(
    'both providers expose the same 15 tools without a model profile ID',
    () {
      final openAI = {
        for (final item in chatbotOpenAITools)
          (item['function'] as Map)['name']: item['function'] as Map,
      };
      expect(openAI, hasLength(15));
      expect(
        openAI.keys,
        unorderedEquals(chatbotGeminiTools.map((tool) => tool.name)),
      );
      for (final tool in chatbotGeminiTools) {
        final openAIParams = openAI[tool.name]!['parameters'] as Map;
        final geminiParams = tool.parameters!.toJson();
        final keys = (openAIParams['properties'] as Map).keys;
        expect(keys, unorderedEquals((geminiParams['properties'] as Map).keys));
        expect(keys, isNot(contains('profileId')));
        expect(openAIParams['required'] ?? [], geminiParams['required']);
      }
    },
  );

  test(
    'subscription listing separates overdue and windowed renewals',
    () async {
      final result = await call('listSubscriptions', {
        'dueWithinDays': 7,
        'profileId': 0,
      });
      final matches = result['subscriptions'] as List;
      expect(matches.map((s) => s['subscriptionId']), [1, 2, 3]);
      expect(matches.map((s) => s['overdue']), [true, false, false]);
      expect(matches.first['currency'], 'AED');
      expect(matches.first['amount'], 10);
      final range = await call('listSubscriptions', {
        'startDate': '2026-11-21',
        'endDate': '2026-11-28',
        'status': 'active',
      });
      expect((range['subscriptions'] as List).map((s) => s['subscriptionId']), [
        2,
        3,
      ]);
      final paused = await call('listSubscriptions', {
        'status': 'paused',
        'query': 'TRIAL',
      });
      expect((paused['subscriptions'] as List).single['subscriptionId'], 4);
      expect(
        (await call('listSubscriptions', {'dueWithinDays': -1}))['status'],
        'error',
      );
    },
  );

  test(
    'summary returns the normalized active cost and marks missing rates',
    () async {
      final requests = <String>[];
      CurrencyConversionService.setMockInstance(
        CurrencyConversionService(
          client: MockClient((request) async {
            requests.add(request.url.path);
            if (request.url.path.endsWith('/AED/INR')) {
              return http.Response(
                jsonEncode({'base': 'AED', 'quote': 'INR', 'rate': 25}),
                200,
              );
            }
            return http.Response('{}', 503);
          }),
        ),
      );
      final result = await call('getSubscriptionSummary');
      expect(result, containsPair('estimatedMonthlyTotal', 350));
      expect(result, containsPair('currency', 'INR'));
      expect(result, containsPair('activeCount', 3));
      expect(result, containsPair('pausedCount', 1));
      expect(result, containsPair('unavailableCount', 1));
      expect(result, containsPair('partial', true));
      expect(
        requests,
        unorderedEquals(['/v2/rate/AED/INR', '/v2/rate/EUR/INR']),
      );
    },
  );

  test(
    'wallet uses the matching profile and supports older total-only profiles',
    () async {
      expect(await call('getWalletBalance', {'profileId': 0}), {
        'currency': 'INR',
        'total': 100,
        'breakdownAvailable': true,
        'cash': 25,
        'bank': 75,
      });
      await prefs.remove('${PrefKeys.cashAmount}-1');
      await prefs.remove('${PrefKeys.bankAmount}-1');
      expect(await call('getWalletBalance'), {
        'currency': 'INR',
        'total': 999,
        'breakdownAvailable': false,
      });
    },
  );

  test(
    'budget reads existing global limits and sums only the active profile',
    () async {
      expect(await call('getBudgetStatus', {'period': 'monthly'}), {
        'currency': 'INR',
        'period': 'monthly',
        'date': '2026-11-21',
        'spent': 100,
        'limitConfigured': true,
        'limit': 150,
        'remaining': 50,
        'overLimit': false,
      });
      await prefs.setString(PrefKeys.dailyLimit, 'Infinity');
      expect(await call('getBudgetStatus', {'period': 'daily'}), {
        'currency': 'INR',
        'period': 'daily',
        'date': '2026-11-21',
        'spent': 40,
        'limitConfigured': false,
      });
    },
  );

  test(
    'spending range uses typed grouping and rejects normalized invalid dates',
    () async {
      final args = {
        'startDate': '2026-11-01',
        'endDate': '2026-11-21',
        'groupBy': 'tag',
      };
      final result = await call('getSpendingBreakdown', args);
      expect(result['groups'], [
        {'label': 'groceries', 'total': 40},
      ]);
      expect(result['note'], contains('overlap'));
      expect(
        (await call('getSpendingBreakdown', {
          ...args,
          'endDate': '2026-11-31',
        }))['status'],
        'error',
      );
      expect(
        (await call('getSpendingBreakdown', {
          ...args,
          'groupBy': 'invalid',
        }))['status'],
        'error',
      );
    },
  );

  test(
    'expense details send item quantities, prices, and tags without relational IDs',
    () async {
      final result = await call('getExpenseDetails', {
        'expenseId': 90,
        'profileId': 0,
      });
      expect(result['tags'], ['groceries']);
      expect(result['billedItems'], [
        {'name': 'Tea', 'quantity': 2, 'price': 20},
      ]);
      expect(
        (await call('getExpenseDetails', {'expenseId': 91}))['status'],
        'error',
      );
      await prefs.setInt(PrefKeys.profileId, 0);
      expect(
        (await call('getExpenseDetails', {'expenseId': 90}))['status'],
        'error',
      );
    },
  );

  test(
    'subscription actions require a matching target and create only a review',
    () async {
      expect(
        (await call('prepareSubscriptionAction', {
          'action': 'logPayment',
          'subscriptionId': 4,
        }))['status'],
        'error',
      );
      expect(
        (await call('prepareSubscriptionAction', {
          'action': 'pause',
          'subscriptionId': 999,
        }))['status'],
        'error',
      );
      expect(
        (await call('prepareSubscriptionAction', {
          'action': 'pause',
        }))['status'],
        'error',
      );
      final prepared = await call('prepareSubscriptionAction', {
        'action': 'pause',
        'subscriptionId': 1,
      });
      expect(prepared['status'], 'prepared');
      expect(reviews.single, (
        action: SubscriptionAction.pause,
        subscriptionId: 1,
        title: 'Streaming',
      ));
      expect(
        (await call('prepareSubscriptionAction', {'action': 'add'}))['status'],
        'prepared',
      );
      expect(reviews.last.subscriptionId, isNull);
      expect(db.saved, isEmpty);
    },
  );

  test(
    'expense requires explicit approval and cancels on profile change',
    () async {
      final args = {
        'amount': 20,
        'remarks': 'Tea',
        'categoryId': 10,
        'date': '2026-11-21',
        'profileId': 0,
      };
      expect((await call('createExpense', args))['status'], 'cancelled');
      expect(db.saved, isEmpty);
      confirm = () async => true;
      expect((await call('createExpense', args))['status'], 'success');
      expect(db.saved.single.profileId, 1);
      expect(refreshes, 1);
      confirm = () async {
        await prefs.setInt(PrefKeys.profileId, 0);
        return true;
      };
      await call('createExpense', args);
      expect(db.saved, hasLength(1));
      expect(refreshes, 1);
    },
  );

  test(
    'currency converter defaults to active profile currency and reuses cache',
    () async {
      var requests = 0;
      CurrencyConversionService.setMockInstance(
        CurrencyConversionService(
          client: MockClient((request) async {
            requests++;
            if (request.url.path.endsWith('/AED/INR')) {
              return http.Response(
                jsonEncode({'base': 'AED', 'quote': 'INR', 'rate': 25.0}),
                200,
              );
            }
            if (request.url.path.endsWith('/USD/EUR')) {
              return http.Response(
                jsonEncode({'base': 'USD', 'quote': 'EUR', 'rate': 0.9}),
                200,
              );
            }
            return http.Response('{}', 503);
          }),
        ),
      );

      // Defaults to active profile currency (INR for profile 1) and ignores model profileId.
      final toProfile = await call('convertCurrency', {
        'amount': 10,
        'fromCurrency': 'Dirham',
        'profileId': 0,
      });
      expect(toProfile, {
        'fromCurrency': 'AED',
        'toCurrency': 'INR',
        'amount': 10.0,
        'rate': 25.0,
        'convertedAmount': 250.0,
      });
      expect(requests, 1);

      // Repeat lookup uses 12h memory cache without another HTTP request.
      final cached = await call('convertCurrency', {
        'fromCurrency': 'AED',
        'toCurrency': 'Rupee',
      });
      expect(cached, {
        'fromCurrency': 'AED',
        'toCurrency': 'INR',
        'amount': 1.0,
        'rate': 25.0,
        'convertedAmount': 25.0,
      });
      expect(requests, 1);

      // Same-currency lookup returns 1.0 with zero network calls.
      final same = await call('convertCurrency', {
        'amount': 12.5,
        'fromCurrency': 'Dirham',
        'toCurrency': 'AED',
      });
      expect(same, {
        'fromCurrency': 'AED',
        'toCurrency': 'AED',
        'amount': 12.5,
        'rate': 1.0,
        'convertedAmount': 12.5,
      });
      expect(requests, 1);

      // Explicit target currency fetches and caches USD/EUR.
      final explicit = await call('convertCurrency', {
        'amount': 20,
        'fromCurrency': 'USD',
        'toCurrency': 'EUR',
      });
      expect(explicit, {
        'fromCurrency': 'USD',
        'toCurrency': 'EUR',
        'amount': 20.0,
        'rate': 0.9,
        'convertedAmount': 18.0,
      });
      expect(requests, 2);

      // Fresh service with failing client loads persisted SharedPreferences cache.
      CurrencyConversionService.setMockInstance(
        CurrencyConversionService(
          client: MockClient((_) async => http.Response('offline', 503)),
        ),
      );
      final persisted = await call('convertCurrency', {
        'amount': 4,
        'fromCurrency': 'AED',
        'toCurrency': 'INR',
      });
      expect(persisted, {
        'fromCurrency': 'AED',
        'toCurrency': 'INR',
        'amount': 4.0,
        'rate': 25.0,
        'convertedAmount': 100.0,
      });

      // Stale persisted cache (older than 12h) still serves fallback when network fails.
      final staleFetchedAt = DateTime.now()
          .subtract(const Duration(hours: 24))
          .toIso8601String();
      await prefs.setString(
        PrefKeys.cachedCurrencyRates,
        jsonEncode({
          'GBP/INR': {
            'base': 'GBP',
            'quote': 'INR',
            'rate': 110.0,
            'date': '2026-11-20',
            'fetchedAt': staleFetchedAt,
          },
        }),
      );
      CurrencyConversionService.setMockInstance(
        CurrencyConversionService(
          client: MockClient((_) async => http.Response('offline', 503)),
        ),
      );
      final staleFallback = await call('convertCurrency', {
        'amount': 2,
        'fromCurrency': 'GBP',
      });
      expect(staleFallback, {
        'fromCurrency': 'GBP',
        'toCurrency': 'INR',
        'amount': 2.0,
        'rate': 110.0,
        'convertedAmount': 220.0,
      });
    },
  );

  test(
    'currency converter validates arguments and rejects profile switches',
    () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      CurrencyConversionService.setMockInstance(
        CurrencyConversionService(
          client: MockClient((request) async {
            started.complete();
            await finish.future;
            return http.Response(
              jsonEncode({'base': 'EUR', 'quote': 'INR', 'rate': 95.0}),
              200,
            );
          }),
        ),
      );

      expect(
        (await call('convertCurrency', {
          'amount': 0,
          'fromCurrency': 'USD',
        }))['status'],
        'error',
      );
      expect(
        (await call('convertCurrency', {
          'amount': -5,
          'fromCurrency': 'USD',
        }))['status'],
        'error',
      );
      expect(
        (await call('convertCurrency', {'fromCurrency': 'INVALID'}))['status'],
        'error',
      );
      expect(
        (await call('convertCurrency', {
          'fromCurrency': 'USD',
          'toCurrency': '??',
        }))['status'],
        'error',
      );

      final pending = call('convertCurrency', {
        'amount': 10,
        'fromCurrency': 'EUR',
      });
      await started.future;
      await prefs.setInt(PrefKeys.profileId, 0);
      finish.complete();
      expect((await pending)['status'], 'error');
    },
  );
}

class _TestPersistence extends PersistenceContext {
  final saved = <Expense>[];

  @override
  Future<List<Subscription>> getSubscriptions([int? profileId]) async {
    expect(profileId, 1);
    Subscription sub(
      int id,
      String title,
      double amount,
      String currency,
      int day, {
      bool active = true,
    }) => Subscription(
      id: id,
      profileId: 1,
      title: title,
      amount: amount,
      categoryId: 10,
      category: 'Food',
      billingCycle: 'Monthly',
      startDate: DateTime(2026, 10, day),
      nextBillingDate: DateTime(2026, 11, day),
      currency: currency,
      isActive: active,
    );
    return [
      sub(1, 'Streaming', 10, 'AED', 20),
      sub(2, 'Delivery', 100, 'Rupee', 21),
      sub(3, 'Storage', 2, 'EUR', 28),
      sub(4, 'Trial', 4, 'USD', 29, active: false),
    ];
  }

  @override
  Future<double> getExpenseSumByDate(DateTime date, int profileId) async {
    expect(profileId, 1);
    return 40;
  }

  @override
  Future<double> getExpenseSumByMonth(DateTime date, int profileId) async {
    expect(profileId, 1);
    return 100;
  }

  @override
  Future<Map<String, double>> getSpendingBreakdown(
    DateTime startDate,
    DateTime endDate,
    int profileId,
    SpendingGroup group,
  ) async {
    expect(startDate, DateTime(2026, 11, 1));
    expect(endDate, DateTime(2026, 11, 21));
    expect(profileId, 1);
    expect(group, SpendingGroup.tag);
    return {'groceries': 40};
  }

  @override
  Future<Expense?> getExpenseById(int expenseId, int profileId) async {
    expect(profileId, 1);
    if (expenseId != 90) return null;
    return Expense(
      id: expenseId,
      profileId: profileId,
      categoryId: 10,
      category: 'Food',
      amount: 40,
      remarks: 'Grocery store',
      expenseDate: DateTime(2026, 11, 21),
      entryDate: DateTime(2026, 11, 21),
      tags: ['groceries'],
      billedItems: [
        BilledItem(
          id: 999,
          expenseId: expenseId,
          itemName: 'Tea',
          quantity: 2,
          price: 20,
        ),
      ],
    );
  }

  @override
  Future<List<Category>> getCategories() async => [Category(10, 'Food')];

  @override
  Future<int> saveExpense(Expense expense) async {
    saved.add(expense);
    return 100;
  }
}
