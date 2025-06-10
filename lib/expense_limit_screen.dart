import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseLimitScreen extends StatefulWidget {
  const ExpenseLimitScreen({super.key});
  @override
  _ExpenseLimitScreenState createState() => _ExpenseLimitScreenState();
}

class _ExpenseLimitScreenState extends State<ExpenseLimitScreen> {
  final monthlyLimitController = TextEditingController();
  final dailyLimitController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    _loadLimits(); // Load existing limits when the screen is built

    return Scaffold(
      appBar: AppBar(title: Text('Expense Limits')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            SizedBox(height: 10.0), // Add some spacing at the top
            TextFormField(
              keyboardType: TextInputType.number,
              controller: monthlyLimitController,
              decoration: InputDecoration(labelText: 'Monthly Limit'),
            ),
            SizedBox(height: 10.0), // Add some spacing between text fields
            TextFormField(
              keyboardType: TextInputType.number,
              controller: dailyLimitController,
              decoration: InputDecoration(labelText: 'Daily Limit'),
            ),
            SizedBox(height: 20.0), // Add some spacing before the button
            Center(
              // Center the button
              child: ElevatedButton(
                onPressed: () async {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  prefs.setString('monthlyLimit', monthlyLimitController.text);
                  prefs.setString('dailyLimit', dailyLimitController.text);

                  // Show a confirmation message

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Limits saved!')));
                },
                child: Text('Save Limits'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    monthlyLimitController.dispose();
    dailyLimitController.dispose();
    super.dispose();
  }

  // Loads existing limits from SharedPreferences and populates the text fields.
  Future<void> _loadLimits() async {
    final prefs = await SharedPreferences.getInstance();
    monthlyLimitController.text = prefs.getString('monthlyLimit') ?? '';
    dailyLimitController.text = prefs.getString('dailyLimit') ?? '';
  }
}
