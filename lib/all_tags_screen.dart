import 'package:flutter/material.dart';
import 'db/persistence_context.dart';
import 'tag_expenses_screen.dart';

class AllTagsScreen extends StatefulWidget {
  const AllTagsScreen({Key? key}) : super(key: key);

  @override
  _AllTagsScreenState createState() => _AllTagsScreenState();
}

class _AllTagsScreenState extends State<AllTagsScreen> {
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final loadedTags = await PersistenceContext().getAllTags();
    setState(() {
      _tags = loadedTags;
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
            children: _tags.map((tag) {
              return ChoiceChip(
                label: Text(tag),
                selected: false,
                onSelected: (selected) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TagExpensesScreen(tag: tag),
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
