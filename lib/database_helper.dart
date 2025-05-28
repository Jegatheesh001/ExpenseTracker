import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'entity.dart'; // Assuming Expense model is in main.dart
import 'package:path_provider/path_provider.dart'; // Import path_provider

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join((await getApplicationDocumentsDirectory()).path, 'expenses.db'); // Use getApplicationDocumentsDirectory from path_provider
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, remarks TEXT, amount REAL, category TEXT, entryDate TEXT)'
    );
  }

  Future<int> insertExpense(Expense expense) async {
    Database db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getExpenses() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expenses', orderBy: 'entryDate desc');
    return List.generate(maps.length, (i) {
      return Expense(
        id: maps[i]['id'], // Include id
        amount: maps[i]['amount'],
        category: maps[i]['category'],
        remarks: maps[i]['remarks'], // Include remarks
        entryDate: DateTime.parse(maps[i]['entryDate']), // Include entryDate
      );
    });
  }

  Future<int> deleteExpense(int id) async {
    Database db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}