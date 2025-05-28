import 'dart:async';

class PersistenceContext {
  Future<List<String>> getCategories() async {
    return Future.value([
      'Food',
      'Transport',
      'Shopping',
      'Utilities',
      'Entertainment',
      'Health',
      'Education',
      'Others',
    ]);
  }
}