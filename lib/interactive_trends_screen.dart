import 'package:expense_tracker/services/ai_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/persistence_context.dart';
import 'pref_keys.dart';

class InteractiveTrendsScreen extends StatefulWidget {
  final int profileId;
  final String currencySymbol;

  const InteractiveTrendsScreen({
    super.key,
    required this.profileId,
    required this.currencySymbol,
  });

  @override
  State<InteractiveTrendsScreen> createState() => _InteractiveTrendsScreenState();
}

class _InteractiveTrendsScreenState extends State<InteractiveTrendsScreen> {
  late Future<Map<String, double>> _last15DaysSpendingFuture;
  late Future<Map<String, double>> _lastFiveMonthsSpendingFuture;
  String _dailyTrendAIInsight = "";
  String _monthlyTrendAIInsight = "";
  bool _isLoadingDailyInsight = false;
  bool _isLoadingMonthlyInsight = false;
  int _selectedChartIndex = 0; // 0 for daily, 1 for monthly

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _last15DaysSpendingFuture = PersistenceContext().getExpensesForLast15Days(widget.profileId);
      _lastFiveMonthsSpendingFuture = PersistenceContext().getExpensesForLastFiveMonths(widget.profileId);
    });
  }

  Future<void> _generateDailyAIInsight(Map<String, double> data) async {
    if (_dailyTrendAIInsight.isNotEmpty || _isLoadingDailyInsight) return;
    setState(() => _isLoadingDailyInsight = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString(PrefKeys.geminiApiKey) ?? '';
      final modelName = prefs.getString(PrefKeys.geminiModelName) ?? 'gemini-1.5-flash-latest';
      
      if (apiKey.isNotEmpty) {
        final aiService = AIService(apiKey, modelName);
        final insight = await aiService.getTrendInsights(data, widget.currencySymbol, "Daily (Last 15 Days)");
        setState(() => _dailyTrendAIInsight = insight);
      } else {
        setState(() => _dailyTrendAIInsight = "AI Key not configured. Please check AI Settings.");
      }
    } catch (e) {
      setState(() => _dailyTrendAIInsight = "Error generating insight: $e");
    } finally {
      setState(() => _isLoadingDailyInsight = false);
    }
  }

  Future<void> _generateMonthlyAIInsight(Map<String, double> data) async {
    if (_monthlyTrendAIInsight.isNotEmpty || _isLoadingMonthlyInsight) return;
    setState(() => _isLoadingMonthlyInsight = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString(PrefKeys.geminiApiKey) ?? '';
      final modelName = prefs.getString(PrefKeys.geminiModelName) ?? 'gemini-1.5-flash-latest';

      if (apiKey.isNotEmpty) {
        final aiService = AIService(apiKey, modelName);
        final insight = await aiService.getTrendInsights(data, widget.currencySymbol, "Monthly (Last 5 Months)");
        setState(() => _monthlyTrendAIInsight = insight);
      } else {
        setState(() => _monthlyTrendAIInsight = "AI Key not configured. Please check AI Settings.");
      }
    } catch (e) {
      setState(() => _monthlyTrendAIInsight = "Error generating insight: $e");
    } finally {
      setState(() => _isLoadingMonthlyInsight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Spending Trends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChartSelector(),
              const SizedBox(height: 20),
              _selectedChartIndex == 0 ? _buildDailyTrend(theme) : _buildMonthlyTrend(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartSelector() {
    return Center(
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Daily (15d)'), icon: Icon(Icons.show_chart)),
          ButtonSegment(value: 1, label: Text('Monthly (5m)'), icon: Icon(Icons.bar_chart)),
        ],
        selected: {_selectedChartIndex},
        onSelectionChanged: (set) {
          setState(() {
            _selectedChartIndex = set.first;
          });
        },
      ),
    );
  }

  Widget _buildDailyTrend(ThemeData theme) {
    final labelStyle = TextStyle(color: theme.colorScheme.onSurface, fontSize: 10);
    return FutureBuilder<Map<String, double>>(
      future: _last15DaysSpendingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
        }
        
        final data = snapshot.data ?? {};
        final sortedKeys = data.keys.toList()..sort();
        final hasData = data.values.any((v) => v > 0);

        if (!hasData) {
          return const SizedBox(
            height: 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No spending data found for the last 15 days.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        final spots = sortedKeys.asMap().entries.map((e) => FlSpot(e.key.toDouble(), data[e.value]!)).toList();
        final maxVal = data.values.reduce((a, b) => a > b ? a : b);
        final maxY = maxVal == 0 ? 100.0 : maxVal * 1.2;

        return Column(
          children: [
            Container(
              height: 300,
              padding: const EdgeInsets.only(right: 16, top: 16),
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 4,
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withOpacity(0.2),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          NumberFormat.compact().format(value),
                          style: labelStyle,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < sortedKeys.length && idx % 3 == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('dd').format(DateTime.parse(sortedKeys[idx])),
                                style: labelStyle,
                              ),
                            );
                          }
                          return const Text("");
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true, 
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.dividerColor.withOpacity(0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => theme.colorScheme.surfaceVariant,
                      getTooltipItems: (spots) => spots.map((s) {
                        return LineTooltipItem(
                          '${DateFormat('dd MMM').format(DateTime.parse(sortedKeys[s.x.toInt()]))}\n${widget.currencySymbol}${s.y.toStringAsFixed(2)}',
                          TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildAIInsightSection(
              theme: theme,
              insight: _dailyTrendAIInsight,
              isLoading: _isLoadingDailyInsight,
              onGenerate: () => _generateDailyAIInsight(data),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyTrend(ThemeData theme) {
    final labelStyle = TextStyle(color: theme.colorScheme.onSurface, fontSize: 10);
    return FutureBuilder<Map<String, double>>(
      future: _lastFiveMonthsSpendingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data ?? {};
        final sortedKeys = data.keys.toList()..sort();
        final hasData = data.values.any((v) => v > 0);

        if (!hasData) {
          return const SizedBox(
            height: 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No spending data found for the last 5 months.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        final maxVal = data.values.reduce((a, b) => a > b ? a : b);
        final maxY = maxVal == 0 ? 100.0 : maxVal * 1.2;

        return Column(
          children: [
            Container(
              height: 300,
              padding: const EdgeInsets.only(right: 16, top: 16),
              child: BarChart(
                BarChartData(
                  barGroups: sortedKeys.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: data[e.value]!,
                          color: theme.colorScheme.primary,
                          width: 25,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          NumberFormat.compact().format(value),
                          style: labelStyle,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < sortedKeys.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MMM').format(DateTime.parse('${sortedKeys[idx]}-01')),
                                style: labelStyle,
                              ),
                            );
                          }
                          return const Text("");
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true, 
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.dividerColor.withOpacity(0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => theme.colorScheme.surfaceVariant,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${DateFormat('MMM yyyy').format(DateTime.parse('${sortedKeys[group.x.toInt()]}-01'))}\n${widget.currencySymbol}${rod.toY.toStringAsFixed(2)}',
                          TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildAIInsightSection(
              theme: theme,
              insight: _monthlyTrendAIInsight,
              isLoading: _isLoadingMonthlyInsight,
              onGenerate: () => _generateMonthlyAIInsight(data),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAIInsightSection({
    required ThemeData theme,
    required String insight,
    required bool isLoading,
    required VoidCallback onGenerate,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  'AI Trend Analysis',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (insight.isEmpty && !isLoading)
                  TextButton.icon(
                    onPressed: onGenerate,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate'),
                  ),
              ],
            ),
            const Divider(),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (insight.isNotEmpty)
              MarkdownBody(
                data: insight,
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyMedium,
                  h1: theme.textTheme.headlineMedium,
                  h2: theme.textTheme.headlineSmall,
                ),
              )
            else
              Text('Click Generate to analyze these trends with AI.', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
