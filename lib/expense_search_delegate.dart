import 'package:flutter/material.dart';

import 'db/persistence_context.dart';
import 'db/entity.dart';
import 'expense_list_view.dart';
import 'package:intl/intl.dart';

class ExpenseSearchDelegate extends SearchDelegate {
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
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return Container();
    }

    return FutureBuilder<List<Expense>>(
      future: PersistenceContext().searchExpenses(query, profileId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No expenses found.'));
        }
        return ExpenseListView(
          expenses: snapshot.data!,
          currencySymbol: currencySymbol,
          onEdit: onEdit,
          onDelete: onDelete,
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Show suggestions as the user types
    return FutureBuilder<List<Expense>>(
      future: query.isEmpty
          ? Future.value([])
          : PersistenceContext().searchExpenses(query, profileId),
      builder: (context, snapshot) {
        if (query.isEmpty) {
          return Container();
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No suggestions.'));
        }

        final expenses = snapshot.data!;
        return ListView.builder(
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
              onTap: () {
                query = expense.remarks;
                showResults(context);
              },
            );
          },
        );
      },
    );
  }
}
