
import 'package:expense_tracker/pref_keys.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeveloperModeScreen extends StatefulWidget {
  const DeveloperModeScreen({Key? key}) : super(key: key);

  @override
  State<DeveloperModeScreen> createState() => _DeveloperModeScreenState();
}

class _DeveloperModeScreenState extends State<DeveloperModeScreen> {
  late SharedPreferences _prefs;
  Map<String, dynamic> _prefsMap = {};
  bool _isDeveloperMode = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _isDeveloperMode = _prefs.getBool(PrefKeys.isDeveloperMode) ?? false;
    _prefsMap = {
      for (var key in _prefs.getKeys()) 
        key: _prefs.get(key),
    };
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPreferences,
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Developer Mode'),
            value: _isDeveloperMode,
            onChanged: (bool value) async {
              if (value) {
                _showEnableDeveloperModeDialog();
              } else {
                setState(() {
                  _isDeveloperMode = false;
                });
                await _prefs.setBool(PrefKeys.isDeveloperMode, false);
              }
            },
          ),
          if (_isDeveloperMode)
            Expanded(
              child: ListView.builder(
                itemCount: _prefsMap.length,
                itemBuilder: (context, index) {
                  final key = _prefsMap.keys.elementAt(index);
                  final value = _prefsMap[key];
                  return ListTile(
                    title: Text(key),
                    subtitle: Text(
                      value.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditDialog(key, value),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _showDeleteDialog(key),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _isDeveloperMode
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _showEnableDeveloperModeDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enable Developer Mode?'),
          content: const Text(
              'Enabling developer mode can expose sensitive information and is intended for development purposes only. Are you sure you want to continue?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Enable'),
              onPressed: () async {
                setState(() {
                  _isDeveloperMode = true;
                });
                await _prefs.setBool(PrefKeys.isDeveloperMode, true);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddDialog() async {
    final TextEditingController keyController = TextEditingController();
    final TextEditingController valueController = TextEditingController();
    String type = 'String';
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Key-Value Pair'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(hintText: 'Enter key'),
              ),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(hintText: 'Enter value'),
              ),
              DropdownButton<String>(
                value: type,
                items: <String>['String', 'int', 'double', 'bool']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    type = newValue;
                  }
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                final String key = keyController.text;
                final String value = valueController.text;
                if (key.isNotEmpty && value.isNotEmpty) {
                  if (type == 'int') {
                    await _prefs.setInt(key, int.parse(value));
                  } else if (type == 'double') {
                    await _prefs.setDouble(key, double.parse(value));
                  } else if (type == 'bool') {
                    await _prefs.setBool(key, value.toLowerCase() == 'true');
                  } else {
                    await _prefs.setString(key, value);
                  }
                  _loadPreferences();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteDialog(String key) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete $key?'),
          content: const Text('Are you sure you want to delete this key?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                await _prefs.remove(key);
                _loadPreferences();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(String key, dynamic value) async {
    final TextEditingController controller =
        TextEditingController(text: value.toString());
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit $key'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter new value'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                final String newValue = controller.text;
                if (value is int) {
                  await _prefs.setInt(key, int.parse(newValue));
                } else if (value is double) {
                  await _prefs.setDouble(key, double.parse(newValue));
                } else if (value is bool) {
                  await _prefs.setBool(key, newValue.toLowerCase() == 'true');
                } else if (value is String) {
                  await _prefs.setString(key, newValue);
                }
                _loadPreferences();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
