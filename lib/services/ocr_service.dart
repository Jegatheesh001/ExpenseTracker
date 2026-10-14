import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:http/http.dart' as http;
import 'package:expense_tracker/utils/secure_storage_helper.dart';

class OCRResult {
  final double? amount;
  final DateTime? date;
  final String? time; // Format: "HH:mm"
  final String? merchant;
  final List<BilledItem>? items;
  final String rawText;

  OCRResult({
    this.amount,
    this.date,
    this.time,
    this.merchant,
    this.items,
    required this.rawText,
  });
}

class OCRService {
  Future<OCRResult> processImage(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString(PrefKeys.aiProvider) ?? 'gemini';
    final ocrModelName = prefs.getString(PrefKeys.ocrModelName) ??
        (provider == 'openai' ? 'gpt-4o-mini' : 'gemini-1.5-flash-latest');

    String rawText = '';

    if (provider == 'openai') {
      final baseUrl = prefs.getString(PrefKeys.openaiBaseUrl) ?? 'https://api.openai.com/v1';
      final apiKey = await SecureStorageHelper.getApiKey(PrefKeys.openaiApiKey);

      var endpoint = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      if (!endpoint.endsWith('/chat/completions')) {
        endpoint = endpoint.endsWith('/v1') ? '$endpoint/chat/completions' : '$endpoint/v1/chat/completions';
      }

      final uri = Uri.parse(endpoint);
      final isLocal = uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '10.0.2.2';
      if (!isLocal && uri.scheme != 'https') {
        throw Exception('Security Error: Insecure HTTP connection rejected. Remote AI endpoints must use HTTPS.');
      }

      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'model': ocrModelName,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Analyze this receipt image and extract the following details in JSON format: '
                      '{"amount": number, "date": "YYYY-MM-DD", "time": "HH:mm", "merchant": "string", "items": [{"name": "string", "quantity": number, "price": number}]}. '
                      'The "time" should be in 24-hour format (e.g., "14:30"). '
                      'If a detail is not found, use null. Only return the JSON object.'
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        rawText = data['choices']?[0]?['message']?['content'] as String? ?? '';
      } else {
        throw Exception('OpenAI OCR Error (${response.statusCode}): ${response.body}');
      }
    } else {
      final apiKey = await SecureStorageHelper.getApiKey(PrefKeys.geminiApiKey);
      if (apiKey.isEmpty) {
        throw Exception('Gemini API Key is not configured in AI Settings.');
      }

      final model = GenerativeModel(model: ocrModelName, apiKey: apiKey);
      final imageBytes = await File(imagePath).readAsBytes();

      final prompt = [
        Content.multi([
          TextPart('Analyze this receipt image and extract the following details in JSON format: '
                   '{"amount": number, "date": "YYYY-MM-DD", "time": "HH:mm", "merchant": "string", "items": [{"name": "string", "quantity": number, "price": number}]}. '
                   'The "time" should be in 24-hour format (e.g., "14:30"). '
                   'If a detail is not found, use null. Only return the JSON object.'),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await model.generateContent(prompt);
      rawText = response.text ?? '';
    }

    if (rawText.isEmpty) {
      throw Exception('Failed to get a response from AI OCR.');
    }

    try {
      // Extract JSON from response
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(rawText);
      if (jsonMatch == null) {
        throw Exception('Invalid response format from OCR.');
      }
      
      final data = jsonDecode(jsonMatch.group(0)!);
      
      double? amount;
      if (data['amount'] != null) {
        amount = (data['amount'] as num).toDouble();
      }

      DateTime? date;
      if (data['date'] != null) {
        try {
          date = DateTime.parse(data['date']);
        } catch (_) {}
      }

      List<BilledItem>? items;
      if (data['items'] != null && data['items'] is List) {
        items = (data['items'] as List).map((item) {
          return BilledItem(
            itemName: item['name']?.toString() ?? 'Unknown Item',
            quantity: (item['quantity'] as num?)?.toDouble() ?? 1.0,
            price: (item['price'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();
      }

      return OCRResult(
        amount: amount,
        date: date,
        time: data['time'],
        merchant: data['merchant'],
        items: items,
        rawText: rawText,
      );
    } catch (e) {
      throw Exception('Failed to parse receipt data: $e');
    }
  }

  void dispose() {
    // No specific disposal needed
  }
}
