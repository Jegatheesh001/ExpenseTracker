import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:expense_tracker/utils/secure_storage_helper.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  String _aiProvider = 'gemini'; // 'gemini' or 'openai'
  final TextEditingController _geminiApiKeyController = TextEditingController();
  final TextEditingController _geminiModelNameController = TextEditingController();

  final TextEditingController _openaiBaseUrlController = TextEditingController();
  final TextEditingController _openaiApiKeyController = TextEditingController();
  final TextEditingController _openaiModelNameController = TextEditingController();

  final TextEditingController _ocrModelNameController = TextEditingController();
  bool _ocrEnabled = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    final geminiKey = await SecureStorageHelper.getApiKey(PrefKeys.geminiApiKey);
    final openaiKey = await SecureStorageHelper.getApiKey(PrefKeys.openaiApiKey);

    if (mounted) {
      setState(() {
        _aiProvider = _prefs.getString(PrefKeys.aiProvider) ?? 'gemini';
        _geminiApiKeyController.text = geminiKey;
        _geminiModelNameController.text = _prefs.getString(PrefKeys.geminiModelName) ?? 'gemini-1.5-flash-latest';

        _openaiBaseUrlController.text = _prefs.getString(PrefKeys.openaiBaseUrl) ?? 'https://api.openai.com/v1';
        _openaiApiKeyController.text = openaiKey;
        _openaiModelNameController.text = _prefs.getString(PrefKeys.openaiModelName) ?? 'gpt-4o-mini';

        final savedOcrModel = _prefs.getString(PrefKeys.ocrModelName);
        if (savedOcrModel != null && savedOcrModel.isNotEmpty) {
          _ocrModelNameController.text = savedOcrModel;
        } else {
          _ocrModelNameController.text = _aiProvider == 'openai' ? 'gpt-4o-mini' : 'gemini-1.5-flash-latest';
        }

        _ocrEnabled = _prefs.getBool(PrefKeys.ocrEnabled) ?? false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      await _prefs.setString(PrefKeys.aiProvider, _aiProvider);
      await SecureStorageHelper.setApiKey(PrefKeys.geminiApiKey, _geminiApiKeyController.text.trim());
      await _prefs.setString(PrefKeys.geminiModelName, _geminiModelNameController.text.trim());

      await _prefs.setString(PrefKeys.openaiBaseUrl, _openaiBaseUrlController.text.trim());
      await SecureStorageHelper.setApiKey(PrefKeys.openaiApiKey, _openaiApiKeyController.text.trim());
      await _prefs.setString(PrefKeys.openaiModelName, _openaiModelNameController.text.trim());

      await _prefs.setString(PrefKeys.ocrModelName, _ocrModelNameController.text.trim());
      await _prefs.setBool(PrefKeys.ocrEnabled, _ocrEnabled);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Settings saved securely')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _geminiModelNameController.dispose();
    _openaiBaseUrlController.dispose();
    _openaiApiKeyController.dispose();
    _openaiModelNameController.dispose();
    _ocrModelNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Select and configure your AI Provider to enable AI features like Spending Insights and Chatbot Assistant.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              
              DropdownButtonFormField<String>(
                value: _aiProvider,
                decoration: const InputDecoration(
                  labelText: 'AI Provider',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.smart_toy),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'gemini',
                    child: Text('Google Gemini'),
                  ),
                  DropdownMenuItem(
                    value: 'openai',
                    child: Text('OpenAI Endpoint'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _aiProvider = value;
                      if (_ocrModelNameController.text.isEmpty ||
                          _ocrModelNameController.text == 'gemini-1.5-flash-latest' ||
                          _ocrModelNameController.text == 'gpt-4o-mini') {
                        _ocrModelNameController.text = value == 'openai' ? 'gpt-4o-mini' : 'gemini-1.5-flash-latest';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              if (_aiProvider == 'gemini') ...[
                const Text(
                  'Google Gemini Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _geminiApiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'Enter your Gemini API Key',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                  validator: (value) {
                    if (_aiProvider == 'gemini' && (value == null || value.trim().isEmpty)) {
                      return 'Please enter your Gemini API Key';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _geminiModelNameController,
                  decoration: const InputDecoration(
                    labelText: 'Gemini Model Name',
                    hintText: 'e.g., gemini-1.5-flash-latest or gemini-2.5-flash',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.model_training),
                  ),
                  validator: (value) {
                    if (_aiProvider == 'gemini' && (value == null || value.trim().isEmpty)) {
                      return 'Please enter a Gemini model name';
                    }
                    return null;
                  },
                ),
              ] else if (_aiProvider == 'openai') ...[
                const Text(
                  'OpenAI Compatible Endpoint Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _openaiBaseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'e.g., https://api.openai.com/v1 or http://localhost:11434/v1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns),
                  ),
                  validator: (value) {
                    if (_aiProvider == 'openai') {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a Base URL';
                      }
                      final uri = Uri.tryParse(value.trim());
                      if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
                        return 'Please enter a valid HTTP/HTTPS URL';
                      }
                      final isLocal = uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '10.0.2.2';
                      if (!isLocal && uri.scheme != 'https') {
                        return 'Remote endpoints must use HTTPS to protect your data';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _openaiApiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key (Optional for local endpoints)',
                    hintText: 'Enter API Key (sk-...)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _openaiModelNameController,
                  decoration: const InputDecoration(
                    labelText: 'Model Name',
                    hintText: 'e.g., gpt-4o-mini, deepseek-chat, llama3',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.model_training),
                  ),
                  validator: (value) {
                    if (_aiProvider == 'openai' && (value == null || value.trim().isEmpty)) {
                      return 'Please enter a Model Name';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 24),
              const Text(
                'OCR Settings (Receipt Scanning)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Enable AI OCR'),
                subtitle: const Text('Use AI to scan receipts and auto-fill details'),
                value: _ocrEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _ocrEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ocrModelNameController,
                enabled: _ocrEnabled,
                decoration: const InputDecoration(
                  labelText: 'OCR Model Name',
                  hintText: 'e.g., gemini-1.5-flash-latest or gpt-4o-mini',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.center_focus_weak),
                ),
                validator: (value) {
                  if (_ocrEnabled && (value == null || value.trim().isEmpty)) {
                    return 'Please enter a model name for OCR';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Privacy Note: Using AI features transmits selected expense amounts, categories, and receipt images to your configured AI provider. API keys are stored in device secure hardware.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save Settings', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              Text(
                _aiProvider == 'openai'
                    ? 'Compatible with OpenAI, OpenRouter, Ollama, LM Studio, DeepSeek, Groq, and other OpenAI API compatible providers.'
                    : 'Get a free API key from Google AI Studio (aistudio.google.com).',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
