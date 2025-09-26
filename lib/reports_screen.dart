import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'db/persistence_context.dart';

class ReportsScreen extends StatefulWidget {
  final int profileId;

  const ReportsScreen({Key? key, required this.profileId}) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<Map<String, double>> _categorySpendingFuture;

  @override
  void initState() {
    super.initState();
    _categorySpendingFuture = PersistenceContext().getCategorySpendingForMonth(DateTime.now(), widget.profileId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Category Report'),
      ),
      body: FutureBuilder<Map<String, double>>(
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
                            Text('₹${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    );
  }
}
