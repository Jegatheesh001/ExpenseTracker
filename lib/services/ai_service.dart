import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

class AIService {
  final String _apiKey;
  final String _modelName;
  late final GenerativeModel _model;
  late final GenerativeModel _chatModel;
  ChatSession? _chatSession;

  AIService(this._apiKey, this._modelName) {
    _model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
    );

    _chatSession = _chatModel.startChat();
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
    // Sort expenses by date descending once at the beginning
    final sortedExpenses = List<Expense>.from(expenses)
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    final Map<String, double> categoryTotals = {};
    double totalAmount = 0;

    // Filter for current month's breakdown to make it more relevant to "recent"
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    
    final currentMonthExpenses = sortedExpenses.where((e) => e.expenseDate.isAfter(currentMonthStart.subtract(const Duration(days: 1)))).toList();

    for (var expense in currentMonthExpenses) {
      categoryTotals[expense.category] = (categoryTotals[expense.category] ?? 0) + expense.amount;
      totalAmount += expense.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String summary = "Current Month's Spending (${DateFormat('MMMM yyyy').format(now)}):\n";
    summary += "Total Spending: $currencySymbol${totalAmount.toStringAsFixed(2)}\n\n";
    summary += "Current Month Breakdown by Category:\n";
    for (var entry in sortedCategories) {
      summary += "- ${entry.key}: $currencySymbol${entry.value.toStringAsFixed(2)}\n";
    }

    summary += "\nRecent Transactions (Latest 20):\n";
    for (var expense in sortedExpenses.take(20)) {
      summary += "- ${DateFormat('yyyy-MM-dd').format(expense.expenseDate)}: $currencySymbol${expense.amount} on ${expense.category} (${expense.remarks})\n";
    }
    
    // Add context about the date range provided
    if (expenses.isNotEmpty) {
      final oldest = expenses.reduce((a, b) => a.expenseDate.isBefore(b.expenseDate) ? a : b);
      final newest = sortedExpenses.first;
      summary += "\nData Range Analyzed: ${DateFormat('yyyy-MM-dd').format(oldest.expenseDate)} to ${DateFormat('yyyy-MM-dd').format(newest.expenseDate)}\n";
    }

    // print('Prepared Expense Summary for AI:\n$summary');
    return summary;
  }

  Future<Uint8List?> generateSpeech(String text) async {
    try {
      // Step 1: Detect the language of the input text
      final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
      final String languageCode = await languageIdentifier.identifyLanguage(text);
      
      // Cleanup: release resources
      await languageIdentifier.close();

      // Default to English if detection fails or returns 'und' (undetermined)
      String targetLanguage = (languageCode == 'und') ? 'en-US' : languageCode;

      // Step 2: Call Google Cloud TTS with the detected language
      final url = Uri.parse(
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
      );

      // We map simple codes (e.g., 'fr') to full locale codes (e.g., 'fr-FR')
      // Google requires the full locale (language-REGION).
      String fullLanguageCode = _mapToFullLocale(targetLanguage);

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "input": {"text": text},
          "voice": {
            "languageCode": fullLanguageCode,
            "ssmlGender": "FEMALE" 
          },
          "audioConfig": {
            "audioEncoding": "MP3"
          }
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['audioContent'] != null) {
          return base64Decode(jsonResponse['audioContent']);
        }
      } else {
        print("TTS API Error: ${response.statusCode} - ${response.body}");
      }
      
      return null;
    } catch (e) {
      print('Error in AIService.generateSpeech: $e');
      return null;
    }
  }

  ChatSession get chatSession {
    return _chatSession ??= _chatModel.startChat();
  }

  void resetChat() {
    _chatSession = _chatModel.startChat();
  }

  String _mapToFullLocale(String shortCode) {
    const localeMap = {
      'en': 'en-US',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'it': 'it-IT',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'pt': 'pt-BR',
      'ru': 'ru-RU',
      'ta': 'ta-IN',
      'zh': 'cmn-CN',
      'ar': 'ar-XA',
      'hi': 'hi-IN',
    };
    return localeMap[shortCode] ?? 'en-US';
  }
}
