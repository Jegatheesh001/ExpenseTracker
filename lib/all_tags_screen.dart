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
        title: const Text('All Tags'),
      ),
      body: ListView.builder(
        itemCount: _tags.length,
        itemBuilder: (context, index) {
          final tag = _tags[index];
          return ListTile(
            title: Text(tag),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TagExpensesScreen(tag: tag),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
