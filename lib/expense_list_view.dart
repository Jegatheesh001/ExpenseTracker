import 'package:expense_tracker/attach_image_screen.dart';
import 'package:expense_tracker/tag_expenses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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

  void _showTagsDialog(BuildContext context, List<String> tags) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Tags'),
          contentPadding: const EdgeInsets.all(12.0),
          children: [
            Wrap(
              spacing: 2.0,
              runSpacing: 0.0,
              children: tags
                  .map((tag) => RawChip(
                label: Text(tag),
                labelStyle: const TextStyle(fontSize: 12),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TagExpensesScreen(tag: tag),
                    ),
                  );
                },
              ))
                  .toList(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            )
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

          return Slidable(
            key: ValueKey(expense.id),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) {
                    _showDeleteConfirmation(context, expense);
                  },
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: 'Delete',
                ),
              ],
            ),
            child: GestureDetector(
              onDoubleTap: () => onEdit(expense),
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: Stack(
                  children: [
                    ListTile(
                      title: Text(expense.remarks),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount: $currencySymbol${expense.amount.toStringAsFixed(2)}\nCategory: ${expense.category}\nDate: $formattedDate',
                          ),
                          if (expense.tags.isNotEmpty)
                            InkWell(
                              onTap: () {
                                _showTagsDialog(context, expense.tags);
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Icon(Icons.label_outline, size: 20),
                              ),
                            ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.only(
                          left: 16, right: 56, top: 8, bottom: 8),
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 8,
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit(expense);
                          } else if (value == 'delete') {
                            _showDeleteConfirmation(context, expense);
                          } else if (value == 'attachments') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AttachImageScreen(expenseId: expense.id!),
                              ),
                            );
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'attachments',
                            child: Text('Attachments'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}