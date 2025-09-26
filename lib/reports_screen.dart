import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'db/persistence_context.dart';

class ReportsScreen extends StatefulWidget {
  final int profileId;
  final String currencySymbol;

  const ReportsScreen({Key? key, required this.profileId, required this.currencySymbol}) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<Map<String, double>> _categorySpendingFuture;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _updateFuture();
  }

  void _updateFuture() {
    _categorySpendingFuture = PersistenceContext().getCategorySpendingForMonth(_selectedDate, widget.profileId);
  }

  void _changeMonth(int month) {
    setState(() {
            _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + month, 1);
      _updateFuture();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Category Report'),
      ),
      body: Column(
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
          Expanded(
            child: FutureBuilder<Map<String, double>>(
              future: _categorySpendingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No data for this month.'));
                } else {
                  final categorySpending = snapshot.data!;
                  final totalSpending = categorySpending.values.reduce((a, b) => a + b);

                  return Column(
                    children: [
                      SizedBox(
                        height: 300,
                        child: PieChart(
                          PieChartData(
                            sections: categorySpending.entries.map((entry) {
                              final percentage = (entry.value / totalSpending) * 100;
                              return PieChartSectionData(
                                color: Colors.primaries[categorySpending.keys.toList().indexOf(entry.key) % Colors.primaries.length],
                                value: entry.value,
                                title: '${percentage.toStringAsFixed(1)}%',
                                radius: 100,
                                titleStyle: const TextStyle(
                                  fontSize: 16,
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
                      Expanded(
                        child: ListView.builder(
                          itemCount: categorySpending.length,
                          itemBuilder: (context, index) {
                            final entry = categorySpending.entries.elementAt(index);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    color: Colors.primaries[index % Colors.primaries.length],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(entry.key, style: const TextStyle(fontSize: 16)),
                                  const Spacer(),
                                  Text('${widget.currencySymbol}${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
