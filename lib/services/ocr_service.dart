import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/pref_keys.dart';
import 'package:expense_tracker/db/entity.dart';

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
    final apiKey = prefs.getString(PrefKeys.geminiApiKey) ?? '';
    final modelName = prefs.getString(PrefKeys.ocrModelName) ?? 'gemini-1.5-flash-latest';

    if (apiKey.isEmpty) {
      throw Exception('Gemini API Key is not configured in AI Settings.');
    }

    final model = GenerativeModel(model: modelName, apiKey: apiKey);
    
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
    final text = response.text;

    if (text == null || text.isEmpty) {
      throw Exception('Failed to get a response from Gemini OCR.');
    }

    try {
      // Extract JSON from response (sometimes Gemini adds markdown blocks)
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (jsonMatch == null) {
        throw Exception('Invalid response format from Gemini.');
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
        rawText: text,
      );
    } catch (e) {
      throw Exception('Failed to parse receipt data: $e');
    }
  }

  void dispose() {
    // No specific disposal needed for Gemini service
  }
}
