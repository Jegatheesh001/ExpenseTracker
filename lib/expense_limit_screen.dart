import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseLimitScreen extends StatefulWidget {
  final VoidCallback onStatusBarToggle;
  const ExpenseLimitScreen({Key? key, required this.onStatusBarToggle}) : super(key: key);
  @override
  _ExpenseLimitScreenState createState() => _ExpenseLimitScreenState();
}

class _ExpenseLimitScreenState extends State<ExpenseLimitScreen> {
  final monthlyLimitController = TextEditingController();
  final dailyLimitController = TextEditingController();
  bool _isStatusBarEnabled = true; // For the "Show Status Bar" toggle

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Load existing limits and status bar setting
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Limits')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 10.0), // Add some spacing at the top
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
            const SizedBox(height: 16.0),
            SwitchListTile(
              title: const Text('Show Expense Status Bar'),
              value: _isStatusBarEnabled,
              onChanged: (bool value) {
                widget.onStatusBarToggle(); // Call the callback from ExpenseHomePage
                setState(() {
                  _isStatusBarEnabled = value; // Update local state for the switch
                });
              },
              contentPadding: EdgeInsets.zero, // Adjust padding as needed
            ),
            const SizedBox(height: 20.0), // Add some spacing before the button
            
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
                }, // Add some spacing before the button
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

  // Loads existing limits and status bar setting from SharedPreferences.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    monthlyLimitController.text = prefs.getString('monthlyLimit') ?? '';
    dailyLimitController.text = prefs.getString('dailyLimit') ?? '';
    if (mounted) {
      setState(() {
        _isStatusBarEnabled = prefs.getBool('showExpStatusBar') ?? true;
      });
    }
  }
}
