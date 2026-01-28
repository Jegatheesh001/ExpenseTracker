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
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelNameController = TextEditingController();
  final TextEditingController _googleSearchEngineIdController = TextEditingController();
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = _prefs.getString(PrefKeys.geminiApiKey) ?? '';
      _modelNameController.text = _prefs.getString(PrefKeys.geminiModelName) ?? 'gemini-1.5-flash-latest';
      _googleSearchEngineIdController.text = _prefs.getString(PrefKeys.googleSearchEngineId) ?? '';
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      await _prefs.setString(PrefKeys.geminiApiKey, _apiKeyController.text.trim());
      await _prefs.setString(PrefKeys.geminiModelName, _modelNameController.text.trim());
      await _prefs.setString(PrefKeys.googleSearchEngineId, _googleSearchEngineIdController.text.trim());
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
    _apiKeyController.dispose();
    _modelNameController.dispose();
    _googleSearchEngineIdController.dispose();
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
                'Configure your Google Gemini settings to enable AI features like Spending Insights.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Gemini API Key',
                  hintText: 'Enter your API Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your Gemini API Key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelNameController,
                decoration: const InputDecoration(
                  labelText: 'Model Name',
                  hintText: 'e.g., gemini-2.5-flash',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.model_training),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a model name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Google Custom Search settings (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _googleSearchEngineIdController,
                decoration: const InputDecoration(
                  labelText: 'Google Search Engine ID (CX)',
                  hintText: 'Enter your Search Engine ID (CX)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.travel_explore),
                ),
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
              const Text(
                'You can get an API key for free from the Google AI Studio website. The same key is used for Google Search if configured.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
