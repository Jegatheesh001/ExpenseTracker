import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'db/persistence_context.dart';
import 'db/entity.dart';

class ExpenseSearchDelegate extends SearchDelegate {
  final ScrollController _scrollController = ScrollController();

  final int profileId;
  final String currencySymbol;
  final Future<void> Function(Expense) onEdit;
  final Future<void> Function(Expense) onDelete;

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

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Expense>>(
      future: PersistenceContext().searchExpenses(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No suggestions.'));
        }

        final expenses = snapshot.data!;

        return ListView.builder(
          key: PageStorageKey<String>('expense_search_$query'),
          controller: _scrollController,
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            final formattedDate = DateFormat('dd-MM-yyyy hh:mm a').format(expense.expenseDate);
            return ListTile(
              title: Text(expense.remarks),
              subtitle: Text('${expense.category} • $formattedDate'),
              trailing: Text(
                '$currencySymbol${expense.amount.toStringAsFixed(2)}',
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
