import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db/entity.dart';

class ExpenseListView extends StatelessWidget {
  final List<Expense> expenses;
  final String currencySymbol;
  final Future<void> Function(int) onDelete;
  final Future<void> Function(Expense) onEdit;

  const ExpenseListView({
    Key? key,
    required this.expenses,
    required this.currencySymbol,
    required this.onDelete,
    required this.onEdit,
  }) : super(key: key);

  void _showDeleteConfirmation(BuildContext context, Expense expense) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this expense?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onDelete(expense.id!);
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];
          final formattedDate =
              DateFormat('dd-MM-yyyy HH:mm:ss').format(expense.entryDate);

          return GestureDetector(
            onLongPress: () => _showDeleteConfirmation(context, expense),
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: Stack(
                children: [
                  ListTile(
                    title: Text(expense.remarks),
                    subtitle: Text(
                      'Amount: $currencySymbol${expense.amount.toStringAsFixed(2)}\nCategory: ${expense.category}\nDate: $formattedDate',
                    ),
                    contentPadding: const EdgeInsets.only(left: 16, right: 56, top: 8, bottom: 8),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => onEdit(expense),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}