import 'package:expense_tracker/all_tags_screen.dart';
import 'package:expense_tracker/common/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'db/entity.dart';
import 'db/persistence_context.dart';
import 'add_expense_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pref_keys.dart';
import 'currency_symbol.dart';

class TagExpensesScreen extends StatefulWidget {
  final String tag;
  final DateTime? selectedDate;

  const TagExpensesScreen({Key? key, required this.tag, this.selectedDate}) : super(key: key);

  @override
  _TagExpensesScreenState createState() => _TagExpensesScreenState();
}

class _TagExpensesScreenState extends State<TagExpensesScreen> {
  Map<String, List<Expense>> _groupedExpenses = {};
  Map<String, double> _monthlyTotals = {};
  String _currencySymbol = '₹';
  int _profileId = 0;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    _profileId = prefs.getInt(PrefKeys.profileId) ?? 0;
    final currency = prefs.getString('${PrefKeys.selectedCurrency}-$_profileId') ?? 'Rupee';
    _currencySymbol = CurrencySymbol().getSymbol(currency);
    List<Expense> loadedExpenses = [];
    if (widget.selectedDate != null) {
      loadedExpenses = await PersistenceContext().getExpensesByTagAndMonth(widget.tag, widget.selectedDate!, _profileId);
    } else {
      loadedExpenses = await PersistenceContext().getExpensesByTag(widget.tag, _profileId);
    }

    Map<String, List<Expense>> grouped = {};
    Map<String, double> totals = {};
    for (var expense in loadedExpenses) {
      String month = DateFormat('yyyy-MM').format(expense.expenseDate);
      if (grouped[month] == null) {
        grouped[month] = [];
        totals[month] = 0.0;
      }
      grouped[month]!.add(expense);
      totals[month] = totals[month]! + expense.amount;
    }

    setState(() {
      _groupedExpenses = grouped;
      _monthlyTotals = totals;
    });
  }

  Future<void> _editExpense(Expense expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(expenseToEdit: expense, onWalletAmountChange: () {}),
      ),
    );
    if (result == true) {
      _loadExpenses();
    }
  }

  Future<void> _deleteExpense(int id) async {
    await PersistenceContext().deleteExpense(id);
    _loadExpenses();
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
        title: Text('Expenses for #${widget.tag}'),
      ),
      body: ListView.builder(
        itemCount: _groupedExpenses.keys.length,
        itemBuilder: (context, index) {
          String month = _groupedExpenses.keys.elementAt(index);
          List<Expense> expenses = _groupedExpenses[month]!;
          double total = _monthlyTotals[month]!;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: ExpansionTile(
              collapsedBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(DateTime.parse('$month-01')),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '$_currencySymbol${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              children: expenses.map((expense) {
                return Slidable(
                  key: ValueKey(expense.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) => _editExpense(expense),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        icon: Icons.edit,
                        label: 'Edit',
                      ),
                      // You can add an Attach action here if desired
                      SlidableAction(
                        onPressed: (context) => _showDeleteConfirmation(context, expense),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        icon: Icons.delete,
                        label: 'Delete',
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onDoubleTap: () => _editExpense(expense),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(getIconForCategory(expense.category)),
                      ),
                      title: Text(expense.remarks, style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text('${expense.category} • ${DateFormat('dd MMM').format(expense.expenseDate)}'),
                      trailing: Text(
                        '$_currencySymbol${expense.amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AllTagsScreen()),
          );
        },
        label: const Text('All Tags'),
        icon: const Icon(Icons.list),
      ),
    );
  }
}
