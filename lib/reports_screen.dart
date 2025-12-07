import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'db/persistence_context.dart';

enum ReportType { category, tag }

class ReportsScreen extends StatefulWidget {
  final int profileId;
  final String currencySymbol;

  const ReportsScreen({super.key, required this.profileId, required this.currencySymbol});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<Map<String, double>> _spendingFuture;
  late Future<Map<String, double>> _lastFiveMonthsSpendingFuture;
  late DateTime _selectedDate;
  bool _showMonthlyReport = true;
  ReportType _reportType = ReportType.category;
  int _touchedIndex = -1;

  final List<Color> _colors = [
    Colors.blue[400]!,
    Colors.red[400]!,
    Colors.green[400]!,
    Colors.yellow[700]!,
    Colors.purple[400]!,
    Colors.orange[400]!,
    Colors.teal[400]!,
    Colors.pink[400]!,
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _updateFutures();
  }

  void _updateFutures() {
    if (_reportType == ReportType.category) {
      _spendingFuture = PersistenceContext().getCategorySpendingForMonth(_selectedDate, widget.profileId);
    } else {
      _spendingFuture = PersistenceContext().getTagSpendingForMonth(_selectedDate, widget.profileId);
    }
    _lastFiveMonthsSpendingFuture = PersistenceContext().getExpensesForLastFiveMonths(widget.profileId);
  }

  void _changeMonth(int month) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + month, 1);
      _updateFutures();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showMonthlyReport ? 'Monthly Expense Chart' : 'Expense Trend'),
        actions: [
          IconButton(
            icon: Icon(_showMonthlyReport ? Icons.bar_chart : Icons.pie_chart),
            onPressed: () {
              setState(() {
                _showMonthlyReport = !_showMonthlyReport;
                _updateFutures();
              });
            },
          ),
        ],
      ),
      body: _showMonthlyReport ? _buildMonthlyReport() : _buildLastFiveMonthsReport(),
    );
  }

  Widget _buildMonthlyReport() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
        ),
        SegmentedButton<ReportType>(
          segments: const <ButtonSegment<ReportType>>[
            ButtonSegment<ReportType>(value: ReportType.category, label: Text('Category')),
            ButtonSegment<ReportType>(value: ReportType.tag, label: Text('Tags')),
          ],
          selected: <ReportType>{_reportType},
          onSelectionChanged: (Set<ReportType> newSelection) {
            setState(() {
              _reportType = newSelection.first;
              _updateFutures();
            });
          },
        ),
        Expanded(
          child: FutureBuilder<Map<String, double>>(
            future: _spendingFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No data for this month.'));
              } else {
                final spendingData = snapshot.data!;
                final totalSpending = spendingData.values.reduce((a, b) => a + b);

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 300,
                        child: PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                setState(() {
                                  if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                    _touchedIndex = -1;
                                    return;
                                  }
                                  _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                });
                              },
                            ),
                            sections: spendingData.entries.map((entry) {
                              final index = spendingData.keys.toList().indexOf(entry.key);
                              final isTouched = index == _touchedIndex;
                              final fontSize = isTouched ? 25.0 : 16.0;
                              final radius = isTouched ? 110.0 : 100.0;
                              final percentage = (entry.value / totalSpending) * 100;
                              return PieChartSectionData(
                                color: _colors[index % _colors.length],
                                value: entry.value,
                                title: '${percentage.toStringAsFixed(1)}%',
                                radius: radius,
                                titleStyle: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        margin: const EdgeInsets.all(16.0),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Wrap(
                            spacing: 16.0,
                            runSpacing: 8.0,
                            children: spendingData.entries.map((entry) {
                              final index = spendingData.keys.toList().indexOf(entry.key);
                              return Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: _colors[index % _colors.length],
                                  child: Text(
                                    entry.key.substring(0, 1),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                label: Text('${entry.key}: ${widget.currencySymbol}${entry.value.toStringAsFixed(2)}'),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Total: ${widget.currencySymbol}${totalSpending.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLastFiveMonthsReport() {
    return FutureBuilder<Map<String, double>>(
      future: _lastFiveMonthsSpendingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No data for the last five months.'));
        } else {
          final monthlyTotals = snapshot.data!;
          final sortedMonths = monthlyTotals.keys.toList()..sort();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: monthlyTotals.values.reduce((a, b) => a > b ? a : b) * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final month = sortedMonths[group.x.toInt()];
                      final total = rod.toY;
                      return BarTooltipItem(
                        '${DateFormat('MMM yyyy').format(DateTime.parse('$month-01'))}\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: '${widget.currencySymbol}${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.yellow,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final month = sortedMonths[value.toInt()];
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(DateFormat('MMM').format(DateTime.parse('$month-01'))),
                        );
                      },
                      reservedSize: 38,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Colors.grey,
                      strokeWidth: 0.5,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: sortedMonths.asMap().entries.map((entry) {
                  final index = entry.key;
                  final month = entry.value;
                  final total = monthlyTotals[month]!;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: total,
                        gradient: LinearGradient(
                          colors: [
                            _colors[index % _colors.length].withOpacity(0.8),
                            _colors[index % _colors.length],
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 22,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        }
      },
    );
  }
}
