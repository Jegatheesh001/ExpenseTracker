import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/pref_keys.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/persistence_context.dart';
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
    final tools = [
      Tool(functionDeclarations: [
        FunctionDeclaration(
          'getExpensesByDate',
          'Retrieves expenses within a specific date range.',
          Schema.object(properties: {
            'startDate': Schema.string(
                description: 'The start date in ISO 8601 format (YYYY-MM-DD).'),
            'endDate': Schema.string(
                description: 'The end date in ISO 8601 format (YYYY-MM-DD).'),
            'profileId': Schema.integer(
                description: 'The user profile ID.'),
          }, requiredProperties: [
            'startDate',
            'endDate',
            'profileId'
          ]),
        ),
        FunctionDeclaration(
          'getCategorySpendingForMonth',
          'Retrieves category-wise spending for a specific month.',
          Schema.object(properties: {
            'date': Schema.string(
                description: 'Any date within the month in ISO 8601 format (YYYY-MM-DD).'),
            'profileId': Schema.integer(
                description: 'The user profile ID.'),
          }, requiredProperties: [
            'date',
            'profileId'
          ]),
        ),
        FunctionDeclaration(
          'searchExpensesByProfileId',
          'Searches for expenses by a query string.',
          Schema.object(properties: {
            'query': Schema.string(
                description: 'The search query (e.g., category, remarks).'),
            'profileId': Schema.integer(
                description: 'The user profile ID.'),
          }, requiredProperties: [
            'query',
            'profileId'
          ]),
        ),
        FunctionDeclaration(
          'getExpenseSumByMonth',
          'Retrieves the total expense sum for a specific month.',
          Schema.object(properties: {
            'date': Schema.string(
                description: 'Any date within the month in ISO 8601 format (YYYY-MM-DD).'),
            'profileId': Schema.integer(
                description: 'The user profile ID.'),
          }, requiredProperties: [
            'date',
            'profileId'
          ]),
        ),
        FunctionDeclaration(
          'getCurrentDateInfo',
          'Retrieves the current date information (year, month, day, etc.). Use this to find the related date info. For example, if the user doesn\'t mention a year, include the current year; if the month is not specified, use the current month; similarly for last week, last month, next month, etc.',
          Schema.object(properties: {}),
        ),
        FunctionDeclaration(
          'googleWebSearch',
          'Performs a web search using Google Custom Search API. Use this ONLY if the internal tools and MCP data are insufficient to answer the user\'s query. Always prioritize internal data and expense-related tools first. THIS TOOL REQUIRES USER CONFIRMATION.',
          Schema.object(properties: {
            'query': Schema.string(
                description: 'The search query to look up on the web.'),
          }, requiredProperties: [
            'query'
          ]),
        ),
        FunctionDeclaration(
          'createExpense',
          'Creates a new expense entry. Use this when the user wants to record a spend.',
          Schema.object(properties: {
            'amount': Schema.number(
                description: 'The amount spent.'),
            'remarks': Schema.string(
                description: 'A brief description or remark about the expense.'),
            'category': Schema.string(
                description: 'The category of the expense (e.g., Food, Transport). Optional if category can be inferred.'),
            'date': Schema.string(
                description: 'The date of the expense in ISO 8601 format (YYYY-MM-DD). Use current date if today, or ask user if not provided.'),
            'profileId': Schema.integer(
                description: 'The user profile ID.'),
          }, requiredProperties: [
            'amount',
            'remarks',
            'profileId'
          ]),
        ),
      ])
    ];

    _model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
    );

    _chatModel = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      tools: tools,
      systemInstruction: Content.system(
      '# ROLE\n'
      'Your name is Anila, a helpful and professional AI financial assistant for the Expense Tracker app.\n\n'

      '# TOOL USAGE POLICY\n'
      '- SEARCH: Only use the web search tool if the user asks for real-time data (e.g., current exchange rates, stock prices) or if the query is outside your internal knowledge base. Do NOT search for general knowledge, basic math, or app-related logic.\n'
      '- EXPENSE TOOLS: Prioritize using local tools for any task involving the user’s financial data.\n\n'

      '# STRICT CONSTRAINTS\n'
      '- LANGUAGE: Always respond in English. This is mandatory, even if the user greets or questions you in other languages.\n'
      '- BREVITY: Be concise. Avoid long-winded explanations unless specifically asked for deep insights.\n\n'

      '# RESPONSIBILITIES\n'
      '1. Manage and track user expenses using the provided tools.\n'
      '2. Provide actionable spending insights and financial advice.\n'
      '3. Answer general knowledge questions using your internal knowledge first. After answering, pivot back to how you can help with their budget.\n'
      '4. DATA INTEGRITY: When creating expenses, if the user provides an expense without a date, ask for it unless "today" or a specific day is implied. If a category is missing or ambiguous, the tool will try to find a similar one, but you should confirm with the user if it\'s unsure. \n\n'

      '# TONE\n'
      'Maintain a professional, encouraging, and supportive personality.'
    ),
    );

    _chatSession = _chatModel.startChat();
  }

  Future<String> getSpendingInsights(List<Expense> expenses, String currencySymbol) async {
    if (expenses.isEmpty) {
      return "No expense data available for analysis. Start adding expenses to see AI-powered insights!";
    }

    final expenseSummary = _prepareExpenseSummary(expenses, currencySymbol);

    final prompt = '''
    Your name is Anila, a professional financial advisor. Analyze the following expense data and provide:
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

  Future<Map<String, dynamic>> executeFunctionCall(FunctionCall functionCall) async {
    final persistenceContext = PersistenceContext();
    final prefs = await SharedPreferences.getInstance();
    debugPrint("Executing function call: ${functionCall.name} with args: ${functionCall.args}");

    switch (functionCall.name) {
      case 'getExpensesByDate':
        final startDate = DateTime.parse(functionCall.args['startDate'] as String);
        final endDate = DateTime.parse(functionCall.args['endDate'] as String);
        final profileId = functionCall.args['profileId'] as int;
        final expenses = await persistenceContext.getExpensesByDate(startDate, endDate, profileId);
        return {'expenses': expenses.map((e) => e.toMap()).toList()};

      case 'getCategorySpendingForMonth':
        final date = DateTime.parse(functionCall.args['date'] as String);
        final profileId = functionCall.args['profileId'] as int;
        final spending = await persistenceContext.getCategorySpendingForMonth(date, profileId);
        return {'categorySpending': spending};

      case 'searchExpensesByProfileId':
        final query = functionCall.args['query'] as String;
        final profileId = functionCall.args['profileId'] as int;
        final expenses = await persistenceContext.searchExpensesByProfileId(query, profileId);
        return {'expenses': expenses.map((e) => e.toMap()).toList()};

      case 'getExpenseSumByMonth':
        final date = DateTime.parse(functionCall.args['date'] as String);
        final profileId = functionCall.args['profileId'] as int;
        final total = await persistenceContext.getExpenseSumByMonth(date, profileId);
        return {'totalExpense': total};

      case 'getCurrentDateInfo':
        final now = DateTime.now();
        return {
          'year': now.year,
          'month': now.month,
          'day': now.day,
          'weekday': DateFormat('EEEE').format(now),
          'monthName': DateFormat('MMMM').format(now),
          'fullDate': DateFormat('yyyy-MM-dd').format(now),
        };

      case 'googleWebSearch':
        final query = functionCall.args['query'] as String;
        final apiKey = _apiKey;
        final cx = prefs.getString(PrefKeys.googleSearchEngineId) ?? '';

        if (apiKey.isEmpty || cx.isEmpty) {
          return {'error': 'Gemini API Key or Google Search Engine ID is not configured in AI Settings.'};
        }

        try {
          final url = Uri.parse(
              'https://www.googleapis.com/customsearch/v1?key=$apiKey&cx=$cx&q=${Uri.encodeComponent(query)}');
          final response = await http.get(url);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final items = data['items'] as List<dynamic>?;
            if (items == null || items.isEmpty) {
              return {'results': [], 'message': 'No results found.'};
            }
            final results = items.take(5).map((item) {
              return {
                'title': item['title'],
                'link': item['link'],
                'snippet': item['snippet'],
              };
            }).toList();
            return {'results': results};
          } else {
            final data = jsonDecode(response.body);
            final error = data['error']?['message'] ?? 'Unknown error';
            return {'error': 'Google Search API error: ${response.statusCode} - $error'};
          }
        } catch (e) {
          return {'error': 'Failed to perform web search: $e'};
        }

      case 'createExpense':
        final amount = (functionCall.args['amount'] as num).toDouble();
        final remarks = functionCall.args['remarks'] as String;
        final profileId = functionCall.args['profileId'] as int;
        String? categoryName = functionCall.args['category'] as String?;
        String? dateStr = functionCall.args['date'] as String?;

        if (dateStr == null) {
          return {
            'status': 'missing_info',
            'message': 'Please ask the user for the date of this expense.'
          };
        }

        DateTime expenseDate;
        try {
          expenseDate = DateTime.parse(dateStr);
        } catch (e) {
          return {
            'status': 'error',
            'message': 'Invalid date format. Please provide date in YYYY-MM-DD format.'
          };
        }

        Category? category;
        if (categoryName == null || categoryName.isEmpty) {
          // Try to look for similar expense
          category = await persistenceContext.getCategoryForRemark(remarks);
          if (category == null) {
            return {
              'status': 'missing_info',
              'message': 'Category not found for similar expenses. Please ask the user for the category.'
            };
          }
          categoryName = category.category;
        } else {
          // Find category by name or create/use fallback
          final categories = await persistenceContext.getCategories();
          category = categories.firstWhere(
            (c) => c.category.toLowerCase() == categoryName!.toLowerCase(),
            orElse: () => Category(0, categoryName!),
          );
        }

        final expense = Expense(
          profileId: profileId,
          categoryId: category.categoryId,
          category: category.category,
          amount: amount,
          remarks: remarks,
          expenseDate: expenseDate,
          entryDate: DateTime.now(),
        );

        final id = await persistenceContext.saveOrUpdateExpense(expense);
        return {
          'status': 'success',
          'message': 'Expense created successfully with ID: $id',
          'expense': expense.toMap(),
          'inferredCategory': category.categoryId == 0 ? false : (functionCall.args['category'] == null)
        };

      default:
        throw UnimplementedError('Function ${functionCall.name} not implemented');
    }
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
