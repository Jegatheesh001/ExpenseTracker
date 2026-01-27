import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expense_tracker/db/persistence_context.dart';
import 'package:expense_tracker/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/pref_keys.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AIInsightsScreen extends StatefulWidget {
  final int profileId;
  final String currencySymbol;

  const AIInsightsScreen({
    super.key,
    required this.profileId,
    required this.currencySymbol,
  });

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen> {
  bool _isLoading = false;
  String _insights = '';
  String? _error;
  DateTime? _lastRun;

  @override
  void initState() {
    super.initState();
    _loadCachedInsights();
  }

  Future<void> _loadCachedInsights() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final cachedInsights = prefs.getString('${PrefKeys.lastAIInsights}_${widget.profileId}');
    final timestamp = prefs.getInt('${PrefKeys.lastAIInsightsTimestamp}_${widget.profileId}');

    setState(() {
      if (cachedInsights != null) {
        _insights = cachedInsights;
      }
      if (timestamp != null) {
        _lastRun = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      _isLoading = false;
    });

    if (_insights.isEmpty) {
      _fetchAIInsights();
    }
  }

  Future<void> _fetchAIInsights() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString(PrefKeys.geminiApiKey);
      final modelName = prefs.getString(PrefKeys.geminiModelName) ?? 'gemini-1.5-flash-latest';

      if (apiKey == null || apiKey.isEmpty) {
        setState(() {
          _error = 'Please set your Gemini API Key in Settings to use AI Insights.';
          _isLoading = false;
        });
        return;
      }

      // Fetch expenses for the last 3 months for context
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
      final expenses = await PersistenceContext().getExpensesByDate(
        threeMonthsAgo,
        now,
        widget.profileId,
      );

      final aiService = AIService(apiKey, modelName);
      final result = await aiService.getSpendingInsights(expenses, widget.currencySymbol);

      final nowTimestamp = DateTime.now();
      await prefs.setString('${PrefKeys.lastAIInsights}_${widget.profileId}', result);
      await prefs.setInt('${PrefKeys.lastAIInsightsTimestamp}_${widget.profileId}', nowTimestamp.millisecondsSinceEpoch);

      setState(() {
        _insights = result;
        _lastRun = nowTimestamp;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch insights: \$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Spending Insights'),
      ),
      body: Column(
        children: [
          if (_lastRun != null || _isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _lastRun != null
                        ? 'Last run: ${DateFormat('dd MMM yyyy, hh:mm aa').format(_lastRun!)}'
                        : 'First analysis in progress...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!_isLoading)
                    TextButton.icon(
                      onPressed: _fetchAIInsights,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Rerun', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading && _insights.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Analyzing your spending patterns...'),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Go to Settings'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          Card(
                            elevation: 2,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: MarkdownBody(
                                data: _insights,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(fontSize: 16, height: 1.5),
                                  h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  listBullet: const TextStyle(fontSize: 16),
                                  blockSpacing: 10,
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Text(
                              'AI insights are generated based on your expense data. Always verify with your actual financial situation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
