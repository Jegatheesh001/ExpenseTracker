import 'package:expense_tracker/category_month_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'db/persistence_context.dart';
import 'tag_expenses_screen.dart';

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
  late Future<Map<String, double>> _last15DaysSpendingFuture;
  late DateTime _selectedDate;
  ReportType _reportType = ReportType.category;
  int _touchedIndex = -1;
  bool _showMonthlyReport = true;

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
    _last15DaysSpendingFuture = PersistenceContext().getExpensesForLast15Days(widget.profileId);
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
        title: Text(_showMonthlyReport ? 'Expense Chart' : 'Expense Trend'),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: _showMonthlyReport ? Theme.of(context).highlightColor : Colors.transparent,
            ),
            icon: Icon(Icons.pie_chart, color: _showMonthlyReport ? Colors.white : Colors.grey),
            onPressed: () {
              setState(() {
                _showMonthlyReport = true;
              });
            },
          ),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: !_showMonthlyReport ? Theme.of(context).highlightColor : Colors.transparent,
            ),
            icon: Icon(Icons.bar_chart, color: !_showMonthlyReport ? Colors.white : Colors.grey),
            onPressed: () {
              setState(() {
                _showMonthlyReport = false;
              });
            },
          ),
        ],
      ),
      body: _showMonthlyReport
          ? _buildMonthlyReport()
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 4,
                      child: _buildLast15DaysReport(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      elevation: 4,
                      child: _buildMonthWiseTrendReport(),
                    ),
                  ),
                ],
              ),
            ),
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
                        child: _reportType == ReportType.category
                            ? PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection == null) {
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
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: RotatedBox(
                                  quarterTurns: 1,
                                  child: BarChart(
                                    BarChartData(
                                      barTouchData: BarTouchData(
                                        touchTooltipData: BarTouchTooltipData(
                                          rotateAngle: -90,
                                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                            return BarTooltipItem(
                                              '${spendingData.keys.elementAt(group.x)}: ${widget.currencySymbol}${rod.toY.toStringAsFixed(2)}',
                                              const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      barGroups: spendingData.entries.toList().asMap().entries.map((entry) {
                                        return BarChartGroupData(
                                          x: entry.key,
                                          barRods: [
                                            BarChartRodData(
                                              fromY: 0,
                                              toY: entry.value.value,
                                              color: _colors[entry.key % _colors.length],
                                              width: 15,
                                              borderRadius: BorderRadius.zero,
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (double value, TitleMeta meta) {
                                              return RotatedBox(
                                                quarterTurns: -1,
                                                child: Text(NumberFormat.compact().format(value), style: const TextStyle(fontSize: 10)),
                                              );
                                            },
                                            reservedSize: 28,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (double value, TitleMeta meta) {
                                              final index = value.toInt();
                                              if (index >= 0 && index < spendingData.keys.length) {
                                                return RotatedBox(
                                                  quarterTurns: -1,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _colors[index % _colors.length],
                                                      borderRadius: BorderRadius.circular(25),
                                                    ),
                                                    child: Text(
                                                      spendingData.keys.elementAt(index)[0],
                                                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const Text('');
                                            },
                                            reservedSize: 25,
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      gridData: const FlGridData(
                                        show: true,
                                        drawHorizontalLine: false,
                                        drawVerticalLine: true,
                                      ),
                                      alignment: BarChartAlignment.spaceAround,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      if (_reportType != ReportType.tag)
                        Chip(
                          label: Text(
                            'Total: ${widget.currencySymbol}${totalSpending.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      Card(
                        margin: const EdgeInsets.all(8.0),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Wrap(
                            spacing: 10.0,
                            runSpacing: 8.0,
                            children: spendingData.entries.map((entry) {
                              final index = spendingData.keys.toList().indexOf(entry.key);
                              return GestureDetector(
                                onTap: () {
                                  if (_reportType == ReportType.tag) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TagExpensesScreen(tag: entry.key, selectedDate: _selectedDate),
                                      ),
                                    );
                                  } else if (_reportType == ReportType.category) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CategoryMonthViewScreen(
                                          category: entry.key,
                                          selectedDate: _selectedDate,
                                          profileId: widget.profileId,
                                          currencySymbol: widget.currencySymbol,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Chip(
                                  avatar: CircleAvatar(
                                    backgroundColor: _colors[index % _colors.length],
                                    child: Text(
                                      entry.key.substring(0, 1),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  label: Text('${entry.key}: ${widget.currencySymbol}${entry.value.toStringAsFixed(2)}'),
                                ),
                              );
                            }).toList(),
                          ),
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

  Widget _buildLast15DaysReport() {
    return Column(
      children: [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Last 15 Days Expense Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, double>>(
            future: _last15DaysSpendingFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No data for the last 15 days.'));
              } else {
                final dailyTotals = snapshot.data!;
                final sortedDays = dailyTotals.keys.toList()..sort();
                final spots = sortedDays.asMap().entries.map((entry) {
                  final index = entry.key;
                  final day = entry.value;
                  final total = dailyTotals[day]!;
                  return FlSpot(index.toDouble(), total);
                }).toList();

                final maxY = dailyTotals.values.reduce((a, b) => a > b ? a : b) * 1.2;

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LineChart(
                    LineChartData(
                      maxY: maxY,
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() % 2 == 1) {
                                return Container();
                              }
                              final day = sortedDays[value.toInt()];
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(DateFormat('dd').format(DateTime.parse(day))),
                              );
                            },
                            reservedSize: 38,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) {
                                return Container();
                              }
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4.0,
                                child: Text(
                                  NumberFormat.compact().format(value),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                            reservedSize: 40,
                            interval: maxY > 0 ? maxY / 4 : 1,
                          ),
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
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              final day = sortedDays[barSpot.x.toInt()];
                              return LineTooltipItem(
                                '${DateFormat('dd MMM').format(DateTime.parse(day))}: ${widget.currencySymbol}${barSpot.y.toStringAsFixed(2)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [
                              _colors[0].withOpacity(0.8),
                              _colors[0],
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                _colors[0].withOpacity(0.3),
                                _colors[0].withOpacity(0.0),
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthWiseTrendReport() {
    return Column(
      children: [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Last 5 Months Expense Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, double>>(
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
                final maxY = monthlyTotals.values.reduce((a, b) => a > b ? a : b) * 1.2;

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
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
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) {
                                return Container();
                              }

                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4.0,
                                child: Text(
                                  NumberFormat.compact().format(value),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                            reservedSize: 40,
                            interval: maxY > 0 ? maxY / 4 : 1,
                          ),
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
          ),
        ),
      ],
    );
  }
}