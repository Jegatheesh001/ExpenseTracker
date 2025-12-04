import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db/database_helper.dart';
import 'db/entity.dart';

class MonthView extends StatefulWidget {
  final DateTime selectedDate;
  final String currencySymbol;
  final int profileId;
  final Future<void> Function(Expense) onEdit;
  final void Function(double) onTotalChanged;

  const MonthView({
    Key? key,
    required this.selectedDate,
    required this.currencySymbol,
    required this.profileId,
    required this.onEdit,
    required this.onTotalChanged,
  }) : super(key: key);

  @override
  _MonthViewState createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  late Future<Map<DateTime, List<Expense>>> _groupedExpenses;

  @override
  void initState() {
    super.initState();
    _groupedExpenses = _fetchAndGroupExpenses();
  }

  @override
  void didUpdateWidget(MonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _groupedExpenses = _fetchAndGroupExpenses();
    }
  }

  Future<Map<DateTime, List<Expense>>> _fetchAndGroupExpenses() async {
    final firstDayOfMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    final lastDayOfMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0);

    final expenses = await DatabaseHelper().getExpensesByDate(firstDayOfMonth, lastDayOfMonth, widget.profileId);
    final groupedExpenses = <DateTime, List<Expense>>{};
    double total = 0;

    for (final expense in expenses) {
      total += expense.amount;
      final day = DateTime(expense.expenseDate.year, expense.expenseDate.month, expense.expenseDate.day);
      if (groupedExpenses.containsKey(day)) {
        groupedExpenses[day]!.add(expense);
      } else {
        groupedExpenses[day] = [expense];
      }
    }
    widget.onTotalChanged(total);
    return groupedExpenses;
  }

  Future<void> _deleteExpense(int id) async {
    await DatabaseHelper().deleteExpense(id);
    setState(() {
      _groupedExpenses = _fetchAndGroupExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<DateTime, List<Expense>>>(
      future: _groupedExpenses,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No expenses for this month.'));
        }

        final groupedExpenses = snapshot.data!;
        final sortedDates = groupedExpenses.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final date = sortedDates[index];
            final expensesForDay = groupedExpenses[date]!;
            final totalForDay = expensesForDay.fold(0.0, (sum, item) => sum + item.amount);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          label: Text(
                            DateFormat('dd MMM, yyyy').format(date),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '${widget.currencySymbol}${totalForDay.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expensesForDay.length,
                    itemBuilder: (context, expenseIndex) {
                      final expense = expensesForDay[expenseIndex];
                      return GestureDetector(
                        onLongPress: () => _showDeleteConfirmation(context, expense),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(left: 16.0, right: 0.0),
                          title: Text(expense.remarks),
                          subtitle: Row(
                            children: [
                              Text(
                                '${widget.currencySymbol}${expense.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('[${expense.category}]'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => widget.onEdit(expense),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
                _deleteExpense(expense.id!);
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
