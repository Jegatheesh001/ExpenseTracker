import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/pref_keys.dart';

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
    setState(() {
      _aiProvider = _prefs.getString(PrefKeys.aiProvider) ?? 'gemini';
      _geminiApiKeyController.text = _prefs.getString(PrefKeys.geminiApiKey) ?? '';
      _geminiModelNameController.text = _prefs.getString(PrefKeys.geminiModelName) ?? 'gemini-1.5-flash-latest';

      _openaiBaseUrlController.text = _prefs.getString(PrefKeys.openaiBaseUrl) ?? 'https://api.openai.com/v1';
      _openaiApiKeyController.text = _prefs.getString(PrefKeys.openaiApiKey) ?? '';
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

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      await _prefs.setString(PrefKeys.aiProvider, _aiProvider);
      await _prefs.setString(PrefKeys.geminiApiKey, _geminiApiKeyController.text.trim());
      await _prefs.setString(PrefKeys.geminiModelName, _geminiModelNameController.text.trim());

      await _prefs.setString(PrefKeys.openaiBaseUrl, _openaiBaseUrlController.text.trim());
      await _prefs.setString(PrefKeys.openaiApiKey, _openaiApiKeyController.text.trim());
      await _prefs.setString(PrefKeys.openaiModelName, _openaiModelNameController.text.trim());

      await _prefs.setString(PrefKeys.ocrModelName, _ocrModelNameController.text.trim());
      await _prefs.setBool(PrefKeys.ocrEnabled, _ocrEnabled);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Settings saved successfully')),
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
                    if (_aiProvider == 'openai' && (value == null || value.trim().isEmpty)) {
                      return 'Please enter a Base URL';
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
              const SizedBox(height: 32),
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
