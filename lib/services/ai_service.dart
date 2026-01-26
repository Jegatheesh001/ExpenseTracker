import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:expense_tracker/db/entity.dart';

class AIService {
  final String _apiKey;
  final String _modelName;
  late final GenerativeModel _model;

  AIService(this._apiKey, {String modelName = 'gemini-1.5-flash-latest'}) : _modelName = modelName {
    _model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
    );
  }

  Future<String> getSpendingInsights(List<Expense> expenses, String currencySymbol) async {
    if (expenses.isEmpty) {
      return "No expense data available for analysis. Start adding expenses to see AI-powered insights!";
    }

    final expenseSummary = _prepareExpenseSummary(expenses, currencySymbol);

    final prompt = '''
    You are a professional financial advisor. Analyze the following expense data and provide:
    1. A brief summary of spending (top categories and total).
    2. Key trends or observations (e.g., unusual spikes, recurring costs).
    3. Three actionable tips to save money based on this specific data.
    4. A motivational closing statement.

    Keep the tone encouraging, concise, and professional. Use markdown for formatting.
    Use the currency symbol: $currencySymbol

    Expense Data:
    $expenseSummary
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "Sorry, I couldn't generate insights at this moment.";
    } catch (e) {
      print('Gemini API Error: $e');
      return "Error generating insights: $e";
    }
  }

  String _prepareExpenseSummary(List<Expense> expenses, String currencySymbol) {
    final Map<String, double> categoryTotals = {};
    double totalAmount = 0;

    for (var expense in expenses) {
      categoryTotals[expense.category] = (categoryTotals[expense.category] ?? 0) + expense.amount;
      totalAmount += expense.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String summary = "Total Spending: \$currencySymbol\${totalAmount.toStringAsFixed(2)}\n\n";
    summary += "Breakdown by Category:\n";
    for (var entry in sortedCategories) {
      summary += "- \${entry.key}: \$currencySymbol\${entry.value.toStringAsFixed(2)}\n";
    }

    summary += "\nRecent Transactions:\n";
    // Include last 10 transactions for context
    final recentExpenses = expenses.take(10);
    for (var expense in recentExpenses) {
      summary += "- \${DateFormat('yyyy-MM-dd').format(expense.expenseDate)}: \$currencySymbol\${expense.amount} on \${expense.category} (\${expense.remarks})\n";
    }

    return summary;
  }
}
