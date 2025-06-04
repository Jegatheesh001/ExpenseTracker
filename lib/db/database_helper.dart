import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:expense_tracker/db/entity.dart'; // Assuming Expense model is in main.dart
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
    String path = join(
      (await getApplicationDocumentsDirectory()).path,
      'expenses.db',
    ); // Use getApplicationDocumentsDirectory from path_provider
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create expenses table
    await db.execute(
      'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, remarks TEXT, amount REAL, categoryId INTEGER, category TEXT, entryDate TEXT)',
    );

    await version2DbChanges(db);
  }

  Future<void> version2DbChanges(Database db) async {
    // Create categories table
    await db.execute(
      'CREATE TABLE categories(categoryId INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT NOT NULL UNIQUE)',
    );
    // Insert initial categories
    final List<Category> initialCategories = [
      Category(1, 'Food'),
      Category(2, 'Transport'),
      Category(3, 'Shopping'),
      Category(4, 'Utilities'),
      Category(5, 'Entertainment'),
      Category(6, 'Health'),
      Category(7, 'Education'),
      Category(8, 'Others'),
    ];

    for (final c in initialCategories) {
      await db.insert('categories', {
        'categoryId': c.categoryId,
        'category': c.category,
      });
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (1 == oldVersion) {
      await db.execute('ALTER TABLE expenses ADD COLUMN categoryId INTEGER');
      await version2DbChanges(db);
    }
  }

  Future<int> insertExpense(Expense expense) async {
    Database db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  // Method to get expenses (all)
  Future<List<Expense>> getExpenses() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      orderBy: 'entryDate desc',
    );
    return _mapMapsToExpenses(maps);
  }

  // Method to get expenses by date range
  Future<List<Expense>> getExpensesByDate(
    DateTime startDate,
    DateTime endDate,
  ) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'date(entryDate) BETWEEN ? AND ?',
      whereArgs: [
        startDate.toIso8601String().substring(0, 10),
        endDate.toIso8601String().substring(0, 10),
      ],
      orderBy: 'entryDate desc',
    );
    return _mapMapsToExpenses(maps);
  }

  // Method to get all categories
  Future<List<Category>> getCategories() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) {
      return Category(maps[i]['categoryId'], maps[i]['category']);
    });
  }

  Future<int> deleteExpense(int id) async {
    final Database db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateExpense(Expense expense) async {
    final Database db = await database;
    return await db.update('expenses', expense.toMap(),
        where: 'id = ?', whereArgs: [expense.id]);
  }

  // Helper function to map database results to Expense objects
  List<Expense> _mapMapsToExpenses(List<Map<String, dynamic>> maps) {
    return List.generate(maps.length, (i) {
      return Expense(
        id: maps[i]['id'],
        amount: maps[i]['amount'],
        categoryId: maps[i]['categoryId'],
        category: maps[i]['category'],
        remarks: maps[i]['remarks'],
        entryDate: DateTime.parse(maps[i]['entryDate']),
      );
    });
  }

  Future<void> saveCategory(Category cat) async {
    Database db = await database;
    await db.insert('categories', {
      'category': cat.category,
    });
  }
}
