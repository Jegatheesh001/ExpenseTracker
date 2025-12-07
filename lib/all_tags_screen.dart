import 'package:expense_tracker/pref_keys.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/persistence_context.dart';
import 'tag_expenses_screen.dart';

class TagInfo {
  final String tagName;
  final bool isRecent;

  TagInfo(this.tagName, this.isRecent);
}

class AllTagsScreen extends StatefulWidget {
  const AllTagsScreen({Key? key}) : super(key: key);

  @override
  _AllTagsScreenState createState() => _AllTagsScreenState();
}

class _AllTagsScreenState extends State<AllTagsScreen> {
  List<TagInfo> _tags = [];
  int _profileId = 0;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    _profileId = prefs.getInt(PrefKeys.profileId) ?? 0;
    final List<Map<String, dynamic>> loadedTags = await PersistenceContext().getAllTagsByProfile(_profileId);
    setState(() {
      _tags = loadedTags.map((tagData) {
        return TagInfo(
          tagData['tagName'],
          tagData['isRecent'] == 1,
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _tags.map((tagInfo) {
              return ChoiceChip(
                label: Text(tagInfo.tagName),
                selected: false,
                backgroundColor: tagInfo.isRecent ? Colors.green.withOpacity(0.25) : null,
                onSelected: (selected) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TagExpensesScreen(tag: tagInfo.tagName),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
