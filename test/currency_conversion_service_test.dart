import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/services/currency_conversion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CurrencyConversionService Tests', () {
    test('Identical currencies return 1.0 without network calls', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('{"error": "should not be called"}', 500);
      });

      final service = CurrencyConversionService(client: mockClient);

      final rateSameCode = await service.getRate('INR', 'INR');
      expect(rateSameCode, 1.0);

      final rateSameName = await service.getRate('Rupee', 'Rupee');
      expect(rateSameName, 1.0);

      final rateMixed = await service.getRate('Dirham', 'AED');
      expect(rateMixed, 1.0);

      expect(requestCount, 0);
    });

    test('Fetches rate for AED/INR from Frankfurter API correctly', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.frankfurter.dev/v2/rate/AED/INR',
        );
        return http.Response(
          jsonEncode({
            'date': '2026-11-21',
            'base': 'AED',
            'quote': 'INR',
            'rate': 25.308,
          }),
          200,
        );
      });

      final service = CurrencyConversionService(client: mockClient);
      final rate = await service.getRate('AED', 'INR');
      expect(rate, 25.308);

      final rateUsingNames = await service.getRate('Dirham', 'Rupee');
      expect(rateUsingNames, 25.308);
    });

    test(
      'Caches fetched rate in memory and reuses it without re-fetching',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          return http.Response(
            jsonEncode({
              'date': '2026-11-21',
              'base': 'USD',
              'quote': 'INR',
              'rate': 92.5,
            }),
            200,
          );
        });

        final service = CurrencyConversionService(client: mockClient);

        final rate1 = await service.getRate('USD', 'INR');
        expect(rate1, 92.5);
        expect(requestCount, 1);

        // Second call should use in-memory cache
        final rate2 = await service.getRate('USD', 'INR');
        expect(rate2, 92.5);
        expect(requestCount, 1);

        // Force refresh should trigger new network request
        final rate3 = await service.getRate('USD', 'INR', forceRefresh: true);
        expect(rate3, 92.5);
        expect(requestCount, 2);
      },
    );

    test(
      'Persists rate to SharedPreferences and falls back on network error',
      () async {
        // First service fetches and persists rate
        final successClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'date': '2026-11-21',
              'base': 'EUR',
              'quote': 'INR',
              'rate': 98.2,
            }),
            200,
          );
        });

        final service1 = CurrencyConversionService(client: successClient);
        await service1.getRate('EUR', 'INR');

        // Second service has failing client and empty memory cache
        final failingClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        final service2 = CurrencyConversionService(client: failingClient);
        // Force refresh bypasses memory cache, triggers failing network, then falls back to persistent cache
        final fallbackRate = await service2.getRate(
          'EUR',
          'INR',
          forceRefresh: true,
        );
        expect(fallbackRate, 98.2);
      },
    );

    test('Handles malformed JSON or network exceptions gracefully', () async {
      final badJsonClient = MockClient((request) async {
        return http.Response('Not a JSON string', 200);
      });

      final service = CurrencyConversionService(client: badJsonClient);
      final rate = await service.getRate('GBP', 'INR');
      expect(rate, isNull);
    });

    test(
      'Rejects malformed currencies and invalid or mismatched rates',
      () async {
        var calls = 0;
        final responses = <String>[
          '{"base":"USD","quote":"INR","rate":0}',
          '{"base":"USD","quote":"INR","rate":-1}',
          '{"base":"USD","quote":"INR","rate":1e999}',
          '{"base":"AED","quote":"INR","rate":25}',
        ];
        final service = CurrencyConversionService(
          client: MockClient((request) async {
            return http.Response(responses[calls++], 200);
          }),
        );

        expect(await service.getRate('///', 'INR'), isNull);
        expect(await service.getRate('unknown currency', 'Rupee'), isNull);
        expect(calls, 0);
        for (final _ in responses) {
          expect(await service.getRate('USD', 'INR'), isNull);
        }
        expect(calls, responses.length);
      },
    );

    test('Shares one request for overlapping lookups and refreshes', () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      var calls = 0;
      final service = CurrencyConversionService(
        client: MockClient((request) async {
          if (calls++ == 0) started.complete();
          await finish.future;
          return http.Response('{"base":"AED","quote":"INR","rate":25}', 200);
        }),
      );

      final dashboard = service.getRate('Dirham', 'Rupee');
      await started.future;
      final refresh = service.getRate('AED', 'INR', forceRefresh: true);
      final form = service.getRate('AED', 'INR');
      finish.complete();
      expect(await Future.wait([dashboard, refresh, form]), [25.0, 25.0, 25.0]);
      expect(calls, 1);
    });

    test(
      'getRatesForProfile batch fetches unique foreign currencies',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('/AED/INR')) {
            return http.Response(
              jsonEncode({'base': 'AED', 'quote': 'INR', 'rate': 25.0}),
              200,
            );
          } else if (request.url.path.endsWith('/USD/INR')) {
            return http.Response(
              jsonEncode({'base': 'USD', 'quote': 'INR', 'rate': 90.0}),
              200,
            );
          }
          return http.Response('Not found', 404);
        });

        final service = CurrencyConversionService(client: mockClient);
        final rates = await service.getRatesForProfile(
          fromCurrencies: ['Dirham', 'Dollar', 'Rupee', 'AED'],
          profileCurrency: 'Rupee',
        );

        expect(rates.containsKey('INR'), isFalse);
        expect(rates['AED'], 25.0);
        expect(rates['USD'], 90.0);
      },
    );
  });
}
