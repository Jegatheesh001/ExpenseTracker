import 'package:expense_tracker/pref_keys.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'currency_symbol.dart';
import 'db/persistence_context.dart';
import 'db/entity.dart';

class ExpenseSearchDelegate extends SearchDelegate {
  final ScrollController _scrollController = ScrollController();

  final int profileId;
  final String currencySymbol;
  final Future<void> Function(Expense) onEdit;
  final Future<void> Function(Expense) onDelete;

  final Map<int, String> _currencySymbolsCache = {};

  ExpenseSearchDelegate({
    required this.profileId,
    required this.currencySymbol,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return const SizedBox.shrink();
  }

  void _fetchAndCacheCurrencySymbol(int profileId, SharedPreferences prefs) {
    if (!_currencySymbolsCache.containsKey(profileId)) {
      final currency = prefs.getString('${PrefKeys.selectedCurrency}-$profileId') ?? 'Rupee';
      _currencySymbolsCache[profileId] = CurrencySymbol().getSymbol(currency);
    }
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final expenses = await PersistenceContext().searchExpenses(query);
    final prefs = await SharedPreferences.getInstance();

    for (var expense in expenses) {
      _fetchAndCacheCurrencySymbol(expense.profileId, prefs);
    }

    return {
      'expenses': expenses,
      'currencySymbols': _currencySymbolsCache,
    };
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || (snapshot.data!['expenses'] as List).isEmpty) {
          return const Center(child: Text('No suggestions.'));
        }

        final expenses = snapshot.data!['expenses'] as List<Expense>;
        final currencySymbols = snapshot.data!['currencySymbols'] as Map<int, String>;

        return ListView.builder(
          key: PageStorageKey<String>('expense_search_$query'),
          controller: _scrollController,
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            final formattedDate = DateFormat('dd-MM-yyyy hh:mm a').format(expense.expenseDate);
            final symbol = currencySymbols[expense.profileId] ?? currencySymbol ?? '';
            
            return ListTile(
              title: Text(expense.remarks),
              subtitle: Text('${expense.category} • $formattedDate'),
              trailing: Text(
                '$symbol${expense.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                await onEdit(expense);

                if (context.mounted) {
                  showSuggestions(context);
                }
              },
            );
          },
        );
      },
    );
  }
}
