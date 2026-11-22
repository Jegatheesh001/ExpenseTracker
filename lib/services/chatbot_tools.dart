import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/persistence_context.dart';
import 'package:expense_tracker/services/ai_service.dart';
import 'package:expense_tracker/services/currency_conversion_service.dart';
import 'package:expense_tracker/utils/currency_symbol.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionAction {
  add('Add subscription'),
  edit('Edit subscription'),
  pause('Pause subscription'),
  resume('Resume subscription'),
  skip('Skip renewal'),
  delete('Delete subscription'),
  logPayment('Log payment');

  const SubscriptionAction(this.label);
  final String label;
}

typedef SubscriptionReview = ({
  SubscriptionAction action,
  int? subscriptionId,
  String? title,
});

class ChatbotTools {
  ChatbotTools({
    required this.profileId,
    required this.prefs,
    required this.isCurrent,
    required this.confirmExpense,
    required this.offerSubscriptionReview,
    required this.onExpenseSaved,
    PersistenceContext? persistence,
    DateTime Function()? now,
  }) : _db = persistence ?? PersistenceContext(),
       _now = now ?? DateTime.now;

  final int profileId;
  final SharedPreferences prefs;
  final bool Function() isCurrent;
  final Future<bool> Function(Expense expense, String currency) confirmExpense;
  final void Function(SubscriptionReview review) offerSubscriptionReview;
  final void Function() onExpenseSaved;
  final PersistenceContext _db;
  final DateTime Function() _now;

  bool get _active =>
      isCurrent() && (prefs.getInt(PrefKeys.profileId) ?? 0) == profileId;

  String get _profileCurrency =>
      prefs.getString('${PrefKeys.selectedCurrency}-$profileId') ?? 'Rupee';

  String get _currency => _currencyCode(_profileCurrency);

  Future<Map<String, dynamic>> execute(AIFunctionCall call) async {
    if (!_active) return _error('The active chat profile changed.');
    try {
      final result = await _execute(call);
      return _active ? result : _error('The active chat profile changed.');
    } on FormatException catch (error) {
      return _error(error.message);
    } catch (_) {
      return _error('Unable to complete this tool call. Try again.');
    }
  }

  Future<Map<String, dynamic>> _execute(AIFunctionCall call) async {
    final args = call.args;
    switch (call.name) {
      case 'getExpensesByDate':
        final (start, end) = _dateRange(args);
        return _expenseList(await _db.getExpensesByDate(start, end, profileId));

      case 'getCategorySpendingForMonth':
        final totals = await _db.getCategorySpendingForMonth(
          _date(args, 'date'),
          profileId,
        );
        return {
          'currency': _currency,
          'categorySpending': totals.map(
            (name, total) => MapEntry(_text(name), total),
          ),
        };

      case 'searchExpensesByProfileId':
        return _expenseList(
          await _db.searchExpensesByProfileId(
            _string(args, 'query'),
            profileId,
          ),
        );

      case 'getExpenseSumByMonth':
        final date = _date(args, 'date');
        return {
          'currency': _currency,
          'totalExpense': await _db.getExpenseSumByMonth(date, profileId),
        };

      case 'getCurrentDateInfo':
        final now = _now();
        return {
          'year': now.year,
          'month': now.month,
          'day': now.day,
          'weekday': DateFormat('EEEE').format(now),
          'monthName': DateFormat('MMMM').format(now),
          'fullDate': _dateString(now),
        };

      case 'listCategories':
        return {
          'categories': [
            for (final category in await _db.getCategories())
              {
                'categoryId': category.categoryId,
                'category': _text(category.category),
              },
          ],
        };

      case 'createExpense':
        return _createExpense(args);

      case 'listSubscriptions':
        return _listSubscriptions(args);

      case 'getSubscriptionSummary':
        return _subscriptionSummary();

      case 'getWalletBalance':
        final cash = prefs.getDouble('${PrefKeys.cashAmount}-$profileId');
        final bank = prefs.getDouble('${PrefKeys.bankAmount}-$profileId');
        final hasBreakdown = cash != null || bank != null;
        return {
          'currency': _currency,
          'total': hasBreakdown
              ? (cash ?? 0) + (bank ?? 0)
              : prefs.getDouble('${PrefKeys.walletAmount}-$profileId') ?? 0,
          'breakdownAvailable': hasBreakdown,
          if (hasBreakdown) ...{'cash': cash ?? 0, 'bank': bank ?? 0},
        };

      case 'getBudgetStatus':
        return _budgetStatus(args);

      case 'getSpendingBreakdown':
        final (start, end) = _dateRange(args);
        final grouping = _string(args, 'groupBy');
        final group = _option(SpendingGroup.values, grouping, (g) => g.name);
        if (group == null) {
          throw const FormatException(
            'groupBy must be category, tag, or paymentMethod.',
          );
        }
        final totals = await _db.getSpendingBreakdown(
          start,
          end,
          profileId,
          group,
        );
        return {
          'currency': _currency,
          'startDate': _dateString(start),
          'endDate': _dateString(end),
          'groupBy': group.name,
          'groups': [
            for (final entry in totals.entries.take(50))
              {'label': _text(entry.key), 'total': entry.value},
          ],
          'groupCount': totals.length,
          'truncated': totals.length > 50,
          if (group == SpendingGroup.tag)
            'note': 'Tag groups overlap and exclude untagged expenses.',
        };

      case 'getExpenseDetails':
        final expense = await _db.getExpenseById(
          _integer(args, 'expenseId', min: 1),
          profileId,
        );
        if (expense == null) {
          return _error('Expense not found in the active profile.');
        }
        return {
          'currency': _currency,
          ..._expenseSummary(expense),
          'tags': expense.tags.take(100).map(_text).toList(),
          'tagCount': expense.tags.length,
          'billedItems': [
            for (final item in expense.billedItems.take(100))
              {
                'name': _text(item.itemName),
                'quantity': item.quantity,
                'price': item.price,
              },
          ],
          'billedItemCount': expense.billedItems.length,
          'truncated':
              expense.tags.length > 100 || expense.billedItems.length > 100,
        };

      case 'prepareSubscriptionAction':
        return _prepareSubscriptionAction(args);

      case 'convertCurrency':
        return _convertCurrency(args);

      default:
        return _error('Unknown tool.');
    }
  }

  Future<Map<String, dynamic>> _listSubscriptions(
    Map<String, dynamic> args,
  ) async {
    final status = args['status'] == null
        ? 'all'
        : _string(args, 'status').toLowerCase();
    if (!{'all', 'active', 'paused', 'overdue'}.contains(status)) {
      throw const FormatException(
        'status must be all, active, paused, or overdue.',
      );
    }
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final start = args['startDate'] == null ? null : _date(args, 'startDate');
    final end = args['endDate'] == null ? null : _date(args, 'endDate');
    if (start != null && end != null && end.isBefore(start)) {
      throw const FormatException('endDate must be on or after startDate.');
    }
    final days = args['dueWithinDays'] == null
        ? null
        : _integer(args, 'dueWithinDays', min: 0, max: 3660);
    final cutoff = days == null
        ? null
        : DateTime(today.year, today.month, today.day + days);
    final query = args['query'] == null
        ? null
        : _string(args, 'query').toLowerCase();
    final subscriptions = await _db.getSubscriptions(profileId);
    final matches = subscriptions.where((sub) {
      final date = sub.nextBillingDate;
      final renewal = DateTime(date.year, date.month, date.day);
      if (query != null && !sub.title.toLowerCase().contains(query)) {
        return false;
      }
      if ((start != null && renewal.isBefore(start)) ||
          (end != null && renewal.isAfter(end))) {
        return false;
      }
      if (cutoff != null && (!sub.isActive || renewal.isAfter(cutoff))) {
        return false;
      }
      return switch (status) {
        'active' => sub.isActive,
        'paused' => !sub.isActive,
        'overdue' => sub.isActive && renewal.isBefore(today),
        _ => true,
      };
    }).toList();
    return {
      'subscriptions': [
        for (final sub in matches.take(50))
          {
            'subscriptionId': sub.id,
            'title': _text(sub.title),
            'amount': sub.amount.isFinite ? sub.amount : null,
            'currency': _currencyCode(sub.currency),
            'billingCycle': sub.billingCycle,
            'nextBillingDate': _dateString(sub.nextBillingDate),
            'status': sub.isActive ? 'active' : 'paused',
            'overdue':
                sub.isActive &&
                _dateString(sub.nextBillingDate).compareTo(_dateString(today)) <
                    0,
          },
      ],
      'matchCount': matches.length,
      'truncated': matches.length > 50,
    };
  }

  Future<Map<String, dynamic>> _subscriptionSummary() async {
    final currency = _profileCurrency;
    final subscriptions = await _db.getSubscriptions(profileId);
    final active = subscriptions.where((sub) => sub.isActive).toList();
    final rates = await CurrencyConversionService.instance.getRatesForProfile(
      fromCurrencies: active
          .where((sub) => sub.amount.isFinite && sub.amount != 0)
          .map((sub) => sub.currency),
      profileCurrency: currency,
    );
    final estimate = CurrencyConversionService.monthlyEstimate(
      active,
      currency,
      rates,
    );
    return {
      'currency': _currencyCode(currency),
      'estimatedMonthlyTotal': estimate.total,
      'activeCount': active.length,
      'pausedCount': subscriptions.length - active.length,
      'unavailableCount': estimate.unavailable,
      'partial': estimate.unavailable > 0,
      'includesCurrencyConversion': estimate.converted,
    };
  }

  Future<Map<String, dynamic>> _budgetStatus(Map<String, dynamic> args) async {
    final period = _string(args, 'period').toLowerCase();
    if (period != 'daily' && period != 'monthly') {
      throw const FormatException('period must be daily or monthly.');
    }
    final date = args['date'] == null ? _now() : _date(args, 'date');
    final daily = period == 'daily';
    final limitKey = daily ? PrefKeys.dailyLimit : PrefKeys.monthlyLimit;
    final limit = double.tryParse(prefs.getString(limitKey) ?? '');
    final spent = daily
        ? await _db.getExpenseSumByDate(date, profileId)
        : await _db.getExpenseSumByMonth(date, profileId);
    final configured = limit != null && limit.isFinite && limit > 0;
    return {
      'currency': _currency,
      'period': period,
      'date': _dateString(date),
      'spent': spent,
      'limitConfigured': configured,
      if (configured) ...{
        'limit': limit,
        'remaining': limit - spent,
        'overLimit': spent > limit,
      },
    };
  }

  Future<Map<String, dynamic>> _prepareSubscriptionAction(
    Map<String, dynamic> args,
  ) async {
    final requested = _string(args, 'action');
    final action = _option(
      SubscriptionAction.values,
      requested,
      (action) => action.name,
    );
    if (action == null) return _error('Unknown subscription action.');
    if (action == SubscriptionAction.add) {
      if (args['subscriptionId'] != null) {
        return _error('Add does not take a subscription ID.');
      }
      offerSubscriptionReview((
        action: action,
        subscriptionId: null,
        title: null,
      ));
      return {'status': 'prepared', 'action': action.name};
    }
    if (args['subscriptionId'] == null) {
      return _error(
        'Find the subscription with listSubscriptions and pass its ID.',
      );
    }
    final id = _integer(args, 'subscriptionId', min: 1);
    final subscriptions = await _db.getSubscriptions(profileId);
    final sub = subscriptions.where((sub) => sub.id == id).firstOrNull;
    if (sub == null || !_active) {
      return _error('Subscription not found in the active profile.');
    }
    final requiresActive = {
      SubscriptionAction.pause,
      SubscriptionAction.skip,
      SubscriptionAction.logPayment,
    }.contains(action);
    if (!sub.isActive && requiresActive ||
        sub.isActive && action == SubscriptionAction.resume) {
      return _error(
        'The action is unavailable for the subscription’s current status.',
      );
    }
    offerSubscriptionReview((
      action: action,
      subscriptionId: id,
      title: sub.title,
    ));
    return {
      'status': 'prepared',
      'action': action.name,
      'title': _text(sub.title),
    };
  }

  Future<Map<String, dynamic>> _convertCurrency(
    Map<String, dynamic> args,
  ) async {
    final rawAmount = args['amount'];
    final double amount;
    if (rawAmount == null) {
      amount = 1.0;
    } else if (rawAmount is! num || !rawAmount.isFinite || rawAmount <= 0) {
      throw const FormatException('Use a positive, finite amount.');
    } else {
      amount = rawAmount.toDouble();
    }

    final currencies = CurrencySymbol();
    final fromInput = _string(args, 'fromCurrency');
    final fromCode = currencies.getCode(fromInput);
    if (fromCode == null) {
      return _error(
        'Unsupported source currency. Use a 3-letter ISO code or known currency name.',
      );
    }

    final toInput = args['toCurrency'] == null
        ? _profileCurrency
        : _string(args, 'toCurrency');
    final toCode = currencies.getCode(toInput);
    if (toCode == null) {
      return _error(
        'Unsupported target currency. Use a 3-letter ISO code or known currency name.',
      );
    }

    final rate = await CurrencyConversionService.instance.getRate(
      fromCode,
      toCode,
    );
    if (rate == null || !rate.isFinite || rate <= 0) {
      return _error('Exchange rate unavailable for $fromCode to $toCode.');
    }
    final convertedAmount = amount * rate;
    if (!convertedAmount.isFinite) {
      return _error('Converted amount is out of range.');
    }
    return {
      'fromCurrency': fromCode,
      'toCurrency': toCode,
      'amount': amount,
      'rate': rate,
      'convertedAmount': convertedAmount,
    };
  }

  Future<Map<String, dynamic>> _createExpense(Map<String, dynamic> args) async {
    final amount = args['amount'];
    if (amount is! num || !amount.isFinite || amount <= 0) {
      throw const FormatException('Use a positive, finite amount.');
    }
    final remarks = _string(args, 'remarks');
    final date = _date(args, 'date');
    final categoryId = args['categoryId'] == null
        ? null
        : _integer(args, 'categoryId', min: 1);
    final categoryName = args['category'] == null
        ? null
        : _string(args, 'category');
    final categories = await _db.getCategories();
    final category = categories.where((category) {
      return categoryId != null
          ? category.categoryId == categoryId &&
                (categoryName == null ||
                    category.category.toLowerCase() ==
                        categoryName.toLowerCase())
          : category.category.toLowerCase() == categoryName?.toLowerCase();
    }).firstOrNull;
    if (category == null) {
      return _error('Choose a valid category from listCategories.');
    }
    if (!_active) return _error('The active chat profile changed.');

    final expense = Expense(
      profileId: profileId,
      categoryId: category.categoryId,
      category: category.category,
      amount: amount.toDouble(),
      remarks: remarks,
      expenseDate: date,
      entryDate: _now(),
    );
    final currency = _currency;
    final confirmed = await confirmExpense(expense, currency);
    if (!confirmed || !_active || currency != _currency) {
      return {'status': 'cancelled'};
    }
    final id = await _db.saveExpense(expense);
    onExpenseSaved();
    return {'status': 'success', 'expenseId': id, 'currency': currency};
  }

  Map<String, dynamic> _expenseList(List<Expense> expenses) => {
    'currency': _currency,
    'expenses': expenses.take(50).map(_expenseSummary).toList(),
    'matchCount': expenses.length,
    'truncated': expenses.length > 50,
  };

  static Map<String, dynamic> _expenseSummary(Expense expense) => {
    'expenseId': expense.id,
    'category': _text(expense.category),
    'amount': expense.amount,
    'remarks': _text(expense.remarks),
    'expenseDate': _dateString(expense.expenseDate),
    'paymentMethod': expense.paymentMethod,
  };

  static Map<String, dynamic> _error(String message) => {
    'status': 'error',
    'message': message,
  };

  static String _currencyCode(String currency) =>
      CurrencySymbol().getCode(currency) ?? _text(currency);

  static String _text(String value) {
    final safe = AIService.sanitizePromptText(value);
    return String.fromCharCodes(safe.runes.take(240));
  }

  static String _string(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty || value.length > 500) {
      throw FormatException(
        '$key must be non-empty text of at most 500 characters.',
      );
    }
    return value.trim();
  }

  static int _integer(
    Map<String, dynamic> args,
    String key, {
    required int min,
    int max = 9007199254740991,
  }) {
    final value = args[key];
    if (value is! num ||
        !value.isFinite ||
        value < min ||
        value > max ||
        value != value.truncate()) {
      throw FormatException('$key must be an integer from $min to $max.');
    }
    return value.toInt();
  }

  static DateTime _date(Map<String, dynamic> args, String key) {
    final value = _string(args, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        _dateString(parsed) != value ||
        parsed.year == 0) {
      throw FormatException('$key must be a valid calendar date (YYYY-MM-DD).');
    }
    return parsed;
  }

  static (DateTime, DateTime) _dateRange(Map<String, dynamic> args) {
    final start = _date(args, 'startDate');
    final end = _date(args, 'endDate');
    if (end.isBefore(start)) {
      throw const FormatException('endDate must be on or after startDate.');
    }
    return (start, end);
  }

  static String _dateString(DateTime date) =>
      date.toIso8601String().substring(0, 10);

  static T? _option<T>(
    Iterable<T> values,
    String requested,
    String Function(T) name,
  ) => values
      .where((value) => name(value).toLowerCase() == requested.toLowerCase())
      .firstOrNull;
}
