import 'package:expense_tracker/attach_image_screen.dart';
import 'package:expense_tracker/common/widgets.dart';
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
          final formattedDate = DateFormat('dd MMM').format(expense.expenseDate);

          return Slidable(
            key: ValueKey(expense.id),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => onEdit(expense),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: Icons.edit,
                  label: 'Edit',
                ),
                SlidableAction(
                  onPressed: (context) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AttachImageScreen(expenseId: expense.id!),
                      ),
                    );
                  },
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  icon: Icons.attach_file,
                  label: 'Attach',
                ),
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
                elevation: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(getIconForCategory(expense.category)),
                  ),
                  title: Text(expense.remarks, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${expense.category} • $formattedDate'),
                  if (expense.tags.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showTagsDialog(context, expense.tags),
                      child: Icon(Icons.label_outline, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ],
              ),
                  trailing: Text(
                    '$currencySymbol${expense.amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}