import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db/database_helper.dart';
import 'db/entity.dart';
import 'common/widgets.dart';
import 'add_expense_screen.dart';

class CategoryMonthViewScreen extends StatefulWidget {
  final String category;
  final DateTime selectedDate;
  final int profileId;
  final String currencySymbol;

  const CategoryMonthViewScreen({
    Key? key,
    required this.category,
    required this.selectedDate,
    required this.profileId,
    required this.currencySymbol,
  }) : super(key: key);

  @override
  _CategoryMonthViewScreenState createState() => _CategoryMonthViewScreenState();
}

class _CategoryMonthViewScreenState extends State<CategoryMonthViewScreen> {
  late Future<List<Expense>> _expensesFuture;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    _expensesFuture = DatabaseHelper().getExpensesByCategoryForMonth(
      widget.category,
      widget.selectedDate,
      widget.profileId,
    );
  }

  Future<void> _editExpense(Expense expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(expenseToEdit: expense, onWalletAmountChange: () {}),
      ),
    );
    if (result == true) {
      setState(() {
        _loadExpenses();
      });
    }
  }

  Future<void> _deleteExpense(int id) async {
    await DatabaseHelper().deleteExpense(id);
    setState(() {
      _loadExpenses();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} - ${DateFormat('MMMM yyyy').format(widget.selectedDate)}'),
      ),
      body: FutureBuilder<List<Expense>>(
        future: _expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No expenses for this category this month.'));
          }

          final expenses = snapshot.data!;
          final groupedExpenses = _groupExpensesByDate(expenses);
          final sortedDates = groupedExpenses.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final expensesForDay = groupedExpenses[date]!;
              final totalForDay = expensesForDay.fold(0.0, (sum, item) => sum + item.amount);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd EEEE').format(date),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${widget.currencySymbol}${totalForDay.toStringAsFixed(2)}',
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...expensesForDay.map((expense) {
                      final tagsString = expense.tags?.map((t) => '#$t').join(' ') ?? '';
                      final timeString = DateFormat.jm().format(expense.expenseDate);
                      final subtitle = tagsString.isNotEmpty ? '$tagsString @ $timeString' : timeString;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(getIconForCategory(widget.category)),
                        ),
                        title: Text(expense.remarks),
                        subtitle: Text(subtitle),
                        trailing: Text(
                          '${widget.currencySymbol}${expense.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => _editExpense(expense),
                        onLongPress: () => _showDeleteConfirmation(context, expense),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Map<DateTime, List<Expense>> _groupExpensesByDate(List<Expense> expenses) {
    final grouped = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      final day = DateTime(expense.expenseDate.year, expense.expenseDate.month, expense.expenseDate.day);
      if (grouped[day] == null) {
        grouped[day] = [];
      }
      grouped[day]!.add(expense);
    }
    return grouped;
  }
}
