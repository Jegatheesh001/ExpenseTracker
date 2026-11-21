import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/utils/currency_symbol.dart';
import 'package:expense_tracker/utils/pref_keys.dart';

/// Represents a cached exchange rate record between two currencies.
class CurrencyRate {
  final String base;
  final String quote;
  final double rate;
  final DateTime date;
  final DateTime fetchedAt;

  CurrencyRate({
    required this.base,
    required this.quote,
    required this.rate,
    required this.date,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
    'base': base,
    'quote': quote,
    'rate': rate,
    'date': date.toIso8601String(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory CurrencyRate.fromJson(Map<String, dynamic> json) => CurrencyRate(
    base: json['base'] as String,
    quote: json['quote'] as String,
    rate: (json['rate'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    fetchedAt: DateTime.parse(json['fetchedAt'] as String),
  );
}

/// Service that interacts with frankfurter-api (https://api.frankfurter.dev)
/// to fetch live currency conversion rates, caching them in-memory and persistently.
class CurrencyConversionService {
  static CurrencyConversionService? _instance;
  final http.Client _client;
  final Map<String, CurrencyRate> _cache = {};
  final Map<String, Future<double?>> _pendingRates = {};
  Future<void>? _cacheLoad;

  CurrencyConversionService({http.Client? client})
    : _client = client ?? http.Client();

  static CurrencyConversionService get instance =>
      _instance ??= CurrencyConversionService();

  @visibleForTesting
  static void setMockInstance(CurrencyConversionService? mock) {
    _instance = mock;
  }

  String _formatKey(String base, String quote) => '$base/$quote';

  /// Returns 1.0 if [fromCurrency] equals [toCurrency].
  /// Otherwise fetches from Frankfurter API (`https://api.frankfurter.dev/v2/rate/{base}/{quote}`)
  /// with memory and local cache fallbacks.
  Future<double?> getRate(
    String fromCurrency,
    String toCurrency, {
    bool forceRefresh = false,
  }) async {
    final currencyHelper = CurrencySymbol();
    final base = currencyHelper.getCode(fromCurrency);
    final quote = currencyHelper.getCode(toCurrency);
    if (base == null || quote == null) return null;
    if (base == quote) return 1.0;

    final key = _formatKey(base, quote);
    await (_cacheLoad ??= _loadCache());
    final cached = _cache[key];
    if (!forceRefresh && cached != null) {
      final age = DateTime.now().difference(cached.fetchedAt);
      if (!age.isNegative && age < const Duration(hours: 12)) {
        return cached.rate;
      }
    }

    return _pendingRates[key] ??= _fetchRate(base, quote, key).whenComplete(() {
      _pendingRates.remove(key);
    });
  }

  Future<double?> _fetchRate(String base, String quote, String key) async {
    try {
      final uri = Uri.https('api.frankfurter.dev', '/v2/rate/$base/$quote');

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> &&
            data['base'] == base &&
            data['quote'] == quote &&
            data['rate'] is num &&
            _isValidRate(data['rate'] as num)) {
          final rate = (data['rate'] as num).toDouble();
          DateTime rateDate = DateTime.now();
          if (data['date'] is String) {
            try {
              rateDate = DateTime.parse(data['date'] as String);
            } catch (_) {}
          }

          final currencyRate = CurrencyRate(
            base: base,
            quote: quote,
            rate: rate,
            date: rateDate,
            fetchedAt: DateTime.now(),
          );

          _cache[key] = currencyRate;
          await _persistCache();
          return rate;
        }
      } else {
        debugPrint(
          'Frankfurter API returned HTTP ${response.statusCode} for $key',
        );
      }
    } catch (e) {
      debugPrint(
        'Failed to fetch currency rate for $key from Frankfurter API: $e',
      );
    }

    // Fallback to cached rate if available even if older
    if (_cache.containsKey(key)) {
      return _cache[key]!.rate;
    }

    return null;
  }

  static bool _isValidRate(num rate) => rate.isFinite && rate > 0;

  /// Fetches each distinct foreign pair required by the caller.
  Future<Map<String, double>> getRatesForProfile({
    required Iterable<String> fromCurrencies,
    required String profileCurrency,
    bool forceRefresh = false,
  }) async {
    final currencyHelper = CurrencySymbol();
    final quote = currencyHelper.getCode(profileCurrency);
    if (quote == null) return {};

    final bases = fromCurrencies
        .map(currencyHelper.getCode)
        .whereType<String>()
        .where((base) => base != quote)
        .toSet();
    final entries = await Future.wait(
      bases.map((base) async {
        final rate = await getRate(base, quote, forceRefresh: forceRefresh);
        return MapEntry(base, rate);
      }),
    );
    return {
      for (final entry in entries)
        if (entry.value case final rate?) entry.key: rate,
    };
  }

  static ({double total, int unavailable, bool converted}) monthlyEstimate(
    Iterable<Subscription> subscriptions,
    String profileCurrency,
    Map<String, double> rates,
  ) {
    final currencies = CurrencySymbol();
    final target = currencies.getCode(profileCurrency);
    double total = 0;
    int unavailable = 0;
    bool converted = false;
    for (final subscription in subscriptions) {
      final amount = subscription.monthlyAmount;
      if (amount == 0) continue;
      final source = currencies.getCode(subscription.currency);
      final isLocal = source != null && source == target;
      final rate = target == null ? null : rates[source];
      final value = isLocal ? amount : (rate == null ? null : amount * rate);
      if (value == null || !value.isFinite || !(total + value).isFinite) {
        unavailable++;
        continue;
      }
      total += value;
      converted |= !isLocal;
    }
    return (total: total, unavailable: unavailable, converted: converted);
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(PrefKeys.cachedCurrencyRates);
      if (jsonStr == null || jsonStr.isEmpty) return;
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        if (entry.value case final Map<String, dynamic> value) {
          try {
            final record = CurrencyRate.fromJson(value);
            if (entry.key == _formatKey(record.base, record.quote) &&
                _isValidRate(record.rate) &&
                !record.fetchedAt.isAfter(DateTime.now())) {
              _cache[entry.key] = record;
            }
          } on FormatException {
            // Skip individual malformed records.
          } on TypeError {
            // Skip individual malformed records.
          }
        }
      }
    } catch (_) {
      debugPrint('Error loading cached currency rates');
    }
  }

  Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _cache.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(PrefKeys.cachedCurrencyRates, jsonEncode(map));
    } catch (e) {
      debugPrint('Error saving cached currency rates: $e');
    }
  }
}
