import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db/entity.dart';
import 'db/persistence_context.dart';
import 'add_expense_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pref_keys.dart';
import 'currency_symbol.dart';

class TagExpensesScreen extends StatefulWidget {
  final String tag;

  const TagExpensesScreen({Key? key, required this.tag}) : super(key: key);

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
    final loadedExpenses = await PersistenceContext().getExpensesByTag(widget.tag, _profileId);

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
            margin: const EdgeInsets.all(8.0),
            child: ExpansionTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('MMMM yyyy').format(DateTime.parse('$month-01'))),
                  Text('$_currencySymbol${total.toStringAsFixed(2)}'),
                ],
              ),
              children: expenses.map((expense) {
                return ListTile(
                  title: Text(expense.remarks),
                  subtitle: Text(DateFormat('dd-MM-yyyy').format(expense.expenseDate)),
                  trailing: Text('$_currencySymbol${expense.amount.toStringAsFixed(2)}'),
                  onTap: () => _editExpense(expense),
                  onLongPress: () => _showDeleteConfirmation(context, expense),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
