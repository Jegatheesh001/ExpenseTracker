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

  // Provides access to the database instance, initializing it if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initializes the database.
  Future<Database> _initDatabase() async {
    String path = join(
      (await getApplicationDocumentsDirectory()).path,
      'expenses.db',
    ); // Use getApplicationDocumentsDirectory from path_provider
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Creates database tables when the database is first created.
  Future<void> _onCreate(Database db, int version) async {
    // Create expenses table
    await db.execute(
      'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, remarks TEXT, amount REAL, categoryId INTEGER, category TEXT, expenseDate TEXT, entryDate TEXT)',
    );

    await version2DbChanges(db);
  }

  // Applies database changes for version 2.
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

  // Handles database upgrades between versions.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (1 == oldVersion) {
      await db.execute('ALTER TABLE expenses ADD COLUMN categoryId INTEGER');
      await version2DbChanges(db);
    }
    // Version 3 changes
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE expenses ADD COLUMN expenseDate TEXT');
      await db.execute(
        'UPDATE expenses SET expenseDate=date(entryDate) where expenseDate is null',
      );
    }
  }

  // Inserts a new expense into the database.
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

  // Method to get expenses for a specific date
  Future<double> getExpenseSumByDate(DateTime date) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'expenses',
      // Specify the 'amount' column to be summed.
      columns: ['SUM(amount) as total'],
      where: 'date(expenseDate) = ?',
      whereArgs: [date.toIso8601String().substring(0, 10)],
    );

    // Safely extract the sum from the result.
    // The result of a SUM query is a list with one map, e.g., [{'total': 123.45}].
    final double sum = result.first['total'] ?? 0.0;

    return sum;
  }

  // Method to get expenses by date range
  Future<List<Expense>> getExpensesByDate(
    DateTime startDate,
    DateTime endDate,
  ) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'date(expenseDate) BETWEEN ? AND ?',
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

  // Deletes an expense from the database by its ID.
  Future<int> deleteExpense(int id) async {
    final Database db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // Updates an existing expense in the database.
  Future<int> updateExpense(Expense expense) async {
    final Database db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
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
        expenseDate: DateTime.parse(maps[i]['expenseDate']),
        entryDate: DateTime.parse(maps[i]['entryDate']),
      );
    });
  }

  // Saves a new category to the database.
  Future<void> saveCategory(Category cat) async {
    Database db = await database;
    await db.insert('categories', {'category': cat.category});
  }

  // Deletes a category from the database by its ID, if no expenses are associated with it.
  Future<bool> deleteCategory(int id) async {
    Database db = await database;
    final expenseCountQuery = '''
      SELECT COUNT(*) AS expenseCount
      FROM expenses
      WHERE categoryId = ?
    ''';
    final expenseCountResult = await db.rawQuery(expenseCountQuery, [id]);
    final expenseCount = expenseCountResult.first['expenseCount'] as int;
    if (expenseCount == 0) {
      await db.delete('categories', where: 'categoryId = ?', whereArgs: [id]);
      return true;
    }
    return false;
  }

  // Calculates the sum of expenses for a given month.
  Future<double> getExpenseSumByMonth(DateTime date) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'expenses',
      // Specify the 'amount' column to be summed.
      columns: ['SUM(amount) as total'],
      where: "strftime('%Y-%m', expenseDate) = ?",
      whereArgs: [date.toIso8601String().substring(0, 7)],
    );
    final double sum = result.first['total'] ?? 0.0;
    return sum;
  }

  // Deletes all data from expenses and categories tables, then re-inserts initial categories.
  Future<void> deleteAllExpenseData() async {
    final Database db = await database;
    await db.transaction((txn) async {
      await txn.delete('expenses');
      await txn.delete('categories');
    });
  }
}
