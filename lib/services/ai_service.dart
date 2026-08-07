import 'dart:io';
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

class AIFunctionCall {
  final String id;
  final String name;
  final Map<String, dynamic> args;

  AIFunctionCall({
    this.id = '',
    required this.name,
    required this.args,
  });
}

class AIFunctionResponse {
  final String id;
  final String name;
  final Map<String, dynamic> response;

  AIFunctionResponse({
    this.id = '',
    required this.name,
    required this.response,
  });
}

class AIChatResponse {
  final String? text;
  final List<AIFunctionCall> functionCalls;

  AIChatResponse({
    this.text,
    this.functionCalls = const [],
  });

  bool get hasFunctionCalls => functionCalls.isNotEmpty;
}

class AIService {
  final String provider; // 'gemini' or 'openai'
  final String apiKey;
  final String modelName;
  final String baseUrl;

  GenerativeModel? _geminiModel;
  GenerativeModel? _geminiChatModel;
  ChatSession? _geminiChatSession;

  final List<Map<String, dynamic>> _openAIMessages = [];

  AIService({
    required this.provider,
    required this.apiKey,
    required this.modelName,
    this.baseUrl = 'https://api.openai.com/v1',
  }) {
    if (provider == 'gemini') {
      _initGemini();
    } else {
      _initOpenAI();
    }
  }

  // Factory constructor from SharedPreferences
  factory AIService.fromPrefs(SharedPreferences prefs) {
    final provider = prefs.getString(PrefKeys.aiProvider) ?? 'gemini';
    if (provider == 'openai') {
      return AIService(
        provider: 'openai',
        baseUrl: prefs.getString(PrefKeys.openaiBaseUrl) ?? 'https://api.openai.com/v1',
        apiKey: prefs.getString(PrefKeys.openaiApiKey) ?? '',
        modelName: prefs.getString(PrefKeys.openaiModelName) ?? 'gpt-4o-mini',
      );
    } else {
      return AIService(
        provider: 'gemini',
        apiKey: prefs.getString(PrefKeys.geminiApiKey) ?? '',
        modelName: prefs.getString(PrefKeys.geminiModelName) ?? 'gemini-1.5-flash-latest',
      );
    }
  }

  // Positional constructor for backwards compatibility
  AIService.legacy(String apiKey, String modelName)
      : this(provider: 'gemini', apiKey: apiKey, modelName: modelName);

  bool get isConfigured {
    if (provider == 'openai') {
      return baseUrl.trim().isNotEmpty && modelName.trim().isNotEmpty;
    }
    return apiKey.trim().isNotEmpty;
  }

  static const String _systemInstruction = '''
# ROLE
Your name is Anila, a helpful and professional AI financial assistant for the Expense Tracker app.

# TOOL USAGE POLICY
- EXPENSE TOOLS: Prioritize using local tools for any task involving the user’s financial data.

# STRICT CONSTRAINTS
- LANGUAGE: Always respond in English. This is mandatory, even if the user greets or questions you in other languages.
- BREVITY: Be concise. Avoid long-winded explanations unless specifically asked for deep insights.

# RESPONSIBILITIES
1. Manage and track user expenses using the provided tools.
2. Provide actionable spending insights and financial advice.
3. Answer general knowledge questions using your internal knowledge first. After answering, pivot back to how you can help with their budget.
4. CATEGORY MANAGEMENT: When the user provides a category name for an expense, always use the `listCategories` tool to find the matching `categoryId`. If the category does not exist, you can use the categoryId from similar expense by search.
5. DATA INTEGRITY: When creating expenses, if the user provides an expense without a date, ask for it unless "today" or a specific day is implied. If a category is missing or ambiguous, confirm with the user.

# TONE
Maintain a professional, encouraging, and supportive personality.
''';

  static final List<Map<String, dynamic>> _openAITools = [
    {
      'type': 'function',
      'function': {
        'name': 'getExpensesByDate',
        'description': 'Retrieves expenses within a specific date range.',
        'parameters': {
          'type': 'object',
          'properties': {
            'startDate': {'type': 'string', 'description': 'The start date in ISO 8601 format (YYYY-MM-DD).'},
            'endDate': {'type': 'string', 'description': 'The end date in ISO 8601 format (YYYY-MM-DD).'},
            'profileId': {'type': 'integer', 'description': 'The user profile ID.'},
          },
          'required': ['startDate', 'endDate', 'profileId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getCategorySpendingForMonth',
        'description': 'Retrieves category-wise spending for a specific month.',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Any date within the month in ISO 8601 format (YYYY-MM-DD).'},
            'profileId': {'type': 'integer', 'description': 'The user profile ID.'},
          },
          'required': ['date', 'profileId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'searchExpensesByProfileId',
        'description': 'Searches for expenses by a query string.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': 'The search query (e.g., category, remarks).'},
            'profileId': {'type': 'integer', 'description': 'The user profile ID.'},
          },
          'required': ['query', 'profileId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getExpenseSumByMonth',
        'description': 'Retrieves the total expense sum for a specific month.',
        'parameters': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'Any date within the month in ISO 8601 format (YYYY-MM-DD).'},
            'profileId': {'type': 'integer', 'description': 'The user profile ID.'},
          },
          'required': ['date', 'profileId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getCurrentDateInfo',
        'description': 'Retrieves the current date information (year, month, day, etc.). Use this to find the related date info.',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'createExpense',
        'description': 'Creates a new expense entry. Use this when the user wants to record a spend.',
        'parameters': {
          'type': 'object',
          'properties': {
            'amount': {'type': 'number', 'description': 'The amount spent.'},
            'remarks': {'type': 'string', 'description': 'A brief description or remark about the expense.'},
            'category': {'type': 'string', 'description': 'The category of the expense (e.g., Food, Transport).'},
            'categoryId': {'type': 'integer', 'description': 'The ID of the category.'},
            'date': {'type': 'string', 'description': 'The date of the expense in ISO 8601 format (YYYY-MM-DD).'},
            'profileId': {'type': 'integer', 'description': 'The user profile ID.'},
          },
          'required': ['amount', 'remarks', 'profileId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'listCategories',
        'description': 'Retrieves a list of all available categories with their IDs and names.',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
  ];

  void _initGemini() {
    final tools = [
      Tool(functionDeclarations: [
        FunctionDeclaration(
          'getExpensesByDate',
          'Retrieves expenses within a specific date range.',
          Schema.object(properties: {
            'startDate': Schema.string(description: 'The start date in ISO 8601 format (YYYY-MM-DD).'),
            'endDate': Schema.string(description: 'The end date in ISO 8601 format (YYYY-MM-DD).'),
            'profileId': Schema.integer(description: 'The user profile ID.'),
          }, requiredProperties: ['startDate', 'endDate', 'profileId']),
        ),
        FunctionDeclaration(
          'getCategorySpendingForMonth',
          'Retrieves category-wise spending for a specific month.',
          Schema.object(properties: {
            'date': Schema.string(description: 'Any date within the month in ISO 8601 format (YYYY-MM-DD).'),
            'profileId': Schema.integer(description: 'The user profile ID.'),
          }, requiredProperties: ['date', 'profileId']),
        ),
        FunctionDeclaration(
          'searchExpensesByProfileId',
          'Searches for expenses by a query string.',
          Schema.object(properties: {
            'query': Schema.string(description: 'The search query (e.g., category, remarks).'),
            'profileId': Schema.integer(description: 'The user profile ID.'),
          }, requiredProperties: ['query', 'profileId']),
        ),
        FunctionDeclaration(
          'getExpenseSumByMonth',
          'Retrieves the total expense sum for a specific month.',
          Schema.object(properties: {
            'date': Schema.string(description: 'Any date within the month in ISO 8601 format (YYYY-MM-DD).'),
            'profileId': Schema.integer(description: 'The user profile ID.'),
          }, requiredProperties: ['date', 'profileId']),
        ),
        FunctionDeclaration(
          'getCurrentDateInfo',
          'Retrieves the current date information (year, month, day, etc.).',
          Schema.object(properties: {}),
        ),
        FunctionDeclaration(
          'createExpense',
          'Creates a new expense entry.',
          Schema.object(properties: {
            'amount': Schema.number(description: 'The amount spent.'),
            'remarks': Schema.string(description: 'A brief description or remark about the expense.'),
            'category': Schema.string(description: 'The category of the expense (e.g., Food, Transport).'),
            'categoryId': Schema.integer(description: 'The ID of the category.'),
            'date': Schema.string(description: 'The date of the expense in ISO 8601 format (YYYY-MM-DD).'),
            'profileId': Schema.integer(description: 'The user profile ID.'),
          }, requiredProperties: ['amount', 'remarks', 'profileId']),
        ),
        FunctionDeclaration(
          'listCategories',
          'Retrieves a list of all available categories with their IDs and names.',
          Schema.object(properties: {}),
        ),
      ])
    ];

    _geminiModel = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
    );

    _geminiChatModel = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      tools: tools,
      systemInstruction: Content.system(_systemInstruction),
    );

    _geminiChatSession = _geminiChatModel!.startChat();
  }

  void _initOpenAI() {
    resetChat();
  }

  String _getOpenAICompletionsEndpoint() {
    var url = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.endsWith('/chat/completions')) return url;
    if (url.endsWith('/v1')) return '$url/chat/completions';
    return '$url/v1/chat/completions';
  }

  Map<String, String> _getOpenAIHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }
    return headers;
  }

  Future<String> getSpendingInsights(List<Expense> expenses, String currencySymbol) async {
    if (expenses.isEmpty) {
      return "No expense data available for analysis. Start adding expenses to see AI-powered insights!";
    }

    final expenseSummary = _prepareExpenseSummary(expenses, currencySymbol);

    final prompt = '''
    You are a professional financial advisor. Analyze the following expense data (including individual items/sub-items under expenses if available) and provide:
    1. A brief summary of spending (top categories and total).
    2. Key trends or observations (e.g., unusual spikes, recurring costs, or specific items/sub-items contributing to high spending).
    3. Three actionable tips to save money based on this specific data, taking into account the individual items purchased.
    4. A motivational closing statement.

    Keep the tone encouraging, concise, and professional. Use markdown for formatting.
    Use the currency symbol: $currencySymbol

    Expense Data:
    $expenseSummary
    ''';

    if (provider == 'openai') {
      try {
        final endpoint = _getOpenAICompletionsEndpoint();
        final response = await http.post(
          Uri.parse(endpoint),
          headers: _getOpenAIHeaders(),
          body: jsonEncode({
            'model': modelName,
            'messages': [
              {'role': 'user', 'content': prompt}
            ]
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['choices']?[0]?['message']?['content'] as String?;
          return text ?? "Sorry, I couldn't generate insights at this moment.";
        } else {
          return "OpenAI API Error (${response.statusCode}): ${response.body}";
        }
      } catch (e) {
        return "Error generating insights: $e";
      }
    } else {
      try {
        final content = [Content.text(prompt)];
        final response = await _geminiModel!.generateContent(content);
        return response.text ?? "Sorry, I couldn't generate insights at this moment.";
      } catch (e) {
        print('Gemini API Error: $e');
        return "Error generating insights: $e";
      }
    }
  }

  String _prepareExpenseSummary(List<Expense> expenses, String currencySymbol) {
    final sortedExpenses = List<Expense>.from(expenses)
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    final Map<String, double> categoryTotals = {};
    double totalAmount = 0;

    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    
    final currentMonthExpenses = sortedExpenses
        .where((e) => e.expenseDate.isAfter(currentMonthStart.subtract(const Duration(days: 1))))
        .toList();

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

    summary += "\nRecent Transactions (Latest 150):\n";
    for (var expense in sortedExpenses.take(150)) {
      String itemDetails = "";
      if (expense.billedItems.isNotEmpty) {
        final itemsList = expense.billedItems.map((item) {
          final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString();
          final priceStr = item.price % 1 == 0 ? item.price.toInt().toString() : item.price.toStringAsFixed(2);
          return "${item.itemName} (Qty: $qtyStr, Price: $currencySymbol$priceStr)";
        }).join(", ");
        itemDetails = " [Items: $itemsList]";
      }
      summary += "- ${DateFormat('yyyy-MM-dd').format(expense.expenseDate)}: $currencySymbol${expense.amount} on ${expense.category} (${expense.remarks})$itemDetails\n";
    }
    
    if (expenses.isNotEmpty) {
      final oldest = expenses.reduce((a, b) => a.expenseDate.isBefore(b.expenseDate) ? a : b);
      final newest = sortedExpenses.first;
      summary += "\nData Range Analyzed: ${DateFormat('yyyy-MM-dd').format(oldest.expenseDate)} to ${DateFormat('yyyy-MM-dd').format(newest.expenseDate)}\n";
    }

    return summary;
  }

  Future<String> getTrendInsights(Map<String, double> trendData, String currencySymbol, String trendType) async {
    if (trendData.isEmpty) {
      return "No trend data available for analysis.";
    }

    final trendSummary = trendData.entries.map((e) => "${e.key}: $currencySymbol${e.value.toStringAsFixed(2)}").join("\n");

    final prompt = '''
    You are a professional financial advisor. Analyze the following $trendType expense trend data and provide:
    1. A brief analysis of the trend (is it increasing, decreasing, or stable?).
    2. Identification of any significant peaks or drops and what they might imply.
    3. Two actionable suggestions to improve financial health based on this specific trend.
    4. A concise, encouraging conclusion.

    Keep the tone professional and concise. Use markdown for formatting.
    Use the currency symbol: $currencySymbol

    Trend Data ($trendType):
    $trendSummary
    ''';

    if (provider == 'openai') {
      try {
        final endpoint = _getOpenAICompletionsEndpoint();
        final response = await http.post(
          Uri.parse(endpoint),
          headers: _getOpenAIHeaders(),
          body: jsonEncode({
            'model': modelName,
            'messages': [
              {'role': 'user', 'content': prompt}
            ]
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['choices']?[0]?['message']?['content'] as String?;
          return text ?? "Sorry, I couldn't generate trend insights at this moment.";
        } else {
          return "OpenAI API Error (${response.statusCode}): ${response.body}";
        }
      } catch (e) {
        return "Error generating trend insights: $e";
      }
    } else {
      try {
        final content = [Content.text(prompt)];
        final response = await _geminiModel!.generateContent(content);
        return response.text ?? "Sorry, I couldn't generate trend insights at this moment.";
      } catch (e) {
        print('Gemini API Error: $e');
        return "Error generating trend insights: $e";
      }
    }
  }

  Future<Uint8List?> generateSpeech(String text) async {
    try {
      final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
      final String languageCode = await languageIdentifier.identifyLanguage(text);
      await languageIdentifier.close();

      String targetLanguage = (languageCode == 'und') ? 'en-US' : languageCode;

      // Check OpenAI TTS endpoint first if provider is openai and key present
      if (provider == 'openai' && apiKey.isNotEmpty) {
        try {
          var cleanBaseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
          if (cleanBaseUrl.endsWith('/v1')) {
            cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 3);
          }
          final ttsUrl = Uri.parse('$cleanBaseUrl/v1/audio/speech');
          final response = await http.post(
            ttsUrl,
            headers: _getOpenAIHeaders(),
            body: jsonEncode({
              "model": "tts-1",
              "input": text,
              "voice": "alloy"
            }),
          );
          if (response.statusCode == 200) {
            return response.bodyBytes;
          }
        } catch (_) {}
      }

      // Fallback to Google Cloud TTS if apiKey is available
      if (apiKey.isNotEmpty) {
        final url = Uri.parse(
          'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey',
        );

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
        }
      }
      
      return null;
    } catch (e) {
      print('Error in AIService.generateSpeech: $e');
      return null;
    }
  }

  void resetChat() {
    if (provider == 'gemini') {
      _geminiChatSession = _geminiChatModel?.startChat();
    } else {
      _openAIMessages.clear();
      _openAIMessages.add({
        'role': 'system',
        'content': _systemInstruction,
      });
    }
  }

  Future<AIChatResponse> sendMessage(String text, {String? audioPath}) async {
    if (provider == 'openai') {
      _openAIMessages.add({
        'role': 'user',
        'content': text,
      });
      return await _sendOpenAIMessageRequest();
    } else {
      final List<Part> parts = [];
      if (audioPath != null) {
        final bytes = await File(audioPath).readAsBytes();
        parts.add(DataPart('audio/m4a', bytes));
      }
      parts.add(TextPart(text));

      _geminiChatSession ??= _geminiChatModel!.startChat();
      final response = await _geminiChatSession!.sendMessage(Content.multi(parts));
      return _parseGeminiResponse(response);
    }
  }

  Future<AIChatResponse> sendFunctionResponses(List<AIFunctionResponse> functionResponses) async {
    if (provider == 'openai') {
      for (final resp in functionResponses) {
        _openAIMessages.add({
          'role': 'tool',
          'tool_call_id': resp.id,
          'content': jsonEncode(resp.response),
        });
      }
      return await _sendOpenAIMessageRequest();
    } else {
      final geminiResponses = functionResponses.map((r) => FunctionResponse(r.name, r.response)).toList();
      final response = await _geminiChatSession!.sendMessage(Content.model(geminiResponses));
      return _parseGeminiResponse(response);
    }
  }

  Future<AIChatResponse> _sendOpenAIMessageRequest() async {
    try {
      final endpoint = _getOpenAICompletionsEndpoint();
      final response = await http.post(
        Uri.parse(endpoint),
        headers: _getOpenAIHeaders(),
        body: jsonEncode({
          'model': modelName,
          'messages': _openAIMessages,
          'tools': _openAITools,
          'tool_choice': 'auto',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choice = data['choices']?[0];
        if (choice == null) {
          return AIChatResponse(text: "No choice returned from OpenAI API.");
        }

        final messageObj = choice['message'] as Map<String, dynamic>;
        _openAIMessages.add(messageObj);

        final toolCallsList = messageObj['tool_calls'] as List<dynamic>?;
        if (toolCallsList != null && toolCallsList.isNotEmpty) {
          final calls = toolCallsList.map((tc) {
            final fn = tc['function'] as Map<String, dynamic>? ?? {};
            Map<String, dynamic> args = {};
            try {
              if (fn['arguments'] != null) {
                args = jsonDecode(fn['arguments'] as String);
              }
            } catch (_) {}
            return AIFunctionCall(
              id: tc['id'] as String? ?? '',
              name: fn['name'] as String? ?? '',
              args: args,
            );
          }).toList();

          return AIChatResponse(functionCalls: calls);
        }

        final text = messageObj['content'] as String?;
        return AIChatResponse(text: text ?? '');
      } else {
        return AIChatResponse(text: "Error from OpenAI API (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      return AIChatResponse(text: "Error communicating with AI Service: $e");
    }
  }

  AIChatResponse _parseGeminiResponse(GenerateContentResponse response) {
    if (response.candidates.isEmpty) {
      return AIChatResponse(text: "No response from Gemini.");
    }
    final contentParts = response.candidates.first.content.parts;
    final geminiFunctionCalls = contentParts.whereType<FunctionCall>().toList();

    if (geminiFunctionCalls.isNotEmpty) {
      final calls = geminiFunctionCalls.map((fc) {
        return AIFunctionCall(
          name: fc.name,
          args: fc.args,
        );
      }).toList();
      return AIChatResponse(functionCalls: calls);
    }

    return AIChatResponse(text: response.text ?? '');
  }

  Future<Map<String, dynamic>> executeFunctionCall(AIFunctionCall functionCall) async {
    final persistenceContext = PersistenceContext();
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

      case 'listCategories':
        final categories = await persistenceContext.getCategories();
        return {'categories': categories.map((c) => c.toMap()).toList()};

      case 'createExpense':
        final amount = (functionCall.args['amount'] as num).toDouble();
        final remarks = functionCall.args['remarks'] as String;
        final profileId = functionCall.args['profileId'] as int;
        String? categoryName = functionCall.args['category'] as String?;
        int? categoryId = functionCall.args['categoryId'] as int?;
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
        if (categoryId != null && categoryId != 0) {
          final categories = await persistenceContext.getCategories();
          category = categories.firstWhere(
            (c) => c.categoryId == categoryId,
            orElse: () => Category(0, categoryName ?? 'Uncategorized'),
          );
          categoryName = category.category;
        } else if (categoryName == null || categoryName.isEmpty) {
          category = await persistenceContext.getCategoryForRemark(remarks);
          if (category == null) {
            return {
              'status': 'missing_info',
              'message': 'Category not found for similar expenses. Please ask the user for the category.'
            };
          }
          categoryName = category.category;
        } else {
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
        return {'error': 'Function ${functionCall.name} not implemented'};
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
