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
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Creates database tables when the database is first created.
  Future<void> _onCreate(Database db, int version) async {
    // Create expenses table
    await db.execute(
      'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, remarks TEXT, amount REAL, categoryId INTEGER, category TEXT, expenseDate TEXT, profileId INTEGER, entryDate TEXT, paymentMethod TEXT)',
    );

    await version2DbChanges(db);
    await version5DbChanges(db);
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
    // Version 4 changes
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE expenses ADD COLUMN profileId INTEGER default 0');
    }
    // Version 5 changes
    if (oldVersion < 5) {
      await version5DbChanges(db);
    }
    // Version 6 changes
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE expenses ADD COLUMN paymentMethod TEXT');
    }
  }

  // Applies database changes for version 2.
  Future<void> version5DbChanges(Database db) async {
    await db.execute(
      'CREATE TABLE tags(tagId INTEGER PRIMARY KEY AUTOINCREMENT, tagName TEXT NOT NULL UNIQUE)',
    );
    await db.execute(
      'CREATE TABLE expense_tags(expenseId INTEGER, tagId INTEGER, FOREIGN KEY(expenseId) REFERENCES expenses(id), FOREIGN KEY(tagId) REFERENCES tags(tagId), PRIMARY KEY (expenseId, tagId))',
    );
  }

  // Insert/Update expense into the database.
  Future<int> saveOrUpdateExpense(Expense expense) async {
    Database db = await database;
    int expenseId = expense.id ?? 0;
    if (expenseId > 0) {
      await db.update(
        'expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );
    } else {
      expenseId = await db.insert('expenses', expense.toMap());
    }
    await _saveTagsForExpense(expenseId, expense.tags);
    return expenseId;
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
  Future<double> getExpenseSumByDate(DateTime date, int profileId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'expenses',
      // Specify the 'amount' column to be summed.
      columns: ['SUM(amount) as total'],
      where: 'date(expenseDate) = ? AND profileId = ?',
      whereArgs: [date.toIso8601String().substring(0, 10), profileId],
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
    int profileId
  ) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'date(expenseDate) BETWEEN ? AND ? AND profileId = ?',
      whereArgs: [
        startDate.toIso8601String().substring(0, 10),
        endDate.toIso8601String().substring(0, 10),
        profileId
      ],
      orderBy: 'expenseDate desc',
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
    await db.delete('expense_tags', where: 'expenseId = ?', whereArgs: [id]);
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
  Future<List<Expense>> _mapMapsToExpenses(List<Map<String, dynamic>> maps) async {
    List<Expense> expenses = [];
    for (var map in maps) {
      List<String> tags = await _getTagsForExpense(map['id']);
      expenses.add(Expense.fromMap(map, tags: tags));
    }
    return expenses;
  }

  Future<List<String>> _getTagsForExpense(int expenseId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT T.tagName
      FROM tags T
      JOIN expense_tags ET ON T.tagId = ET.tagId
      WHERE ET.expenseId = ?
    ''', [expenseId]);
    return List.generate(maps.length, (i) => maps[i]['tagName']);
  }

  Future<void> _saveTagsForExpense(int expenseId, List<String> tags) async {
    final Database db = await database;
    await db.delete('expense_tags', where: 'expenseId = ?', whereArgs: [expenseId]);
    for (String tagName in tags) {
      int tagId;
      var existingTag = await db.query('tags', where: 'tagName = ?', whereArgs: [tagName]);
      if (existingTag.isNotEmpty) {
        tagId = existingTag.first['tagId'] as int;
      } else {
        tagId = await db.insert('tags', {'tagName': tagName});
      }
      await db.insert('expense_tags', {'expenseId': expenseId, 'tagId': tagId});
    }
  }

  Future<List<String>> searchTags(String query) async {
    final Database db = await database;
    if (query.isEmpty) {
      return [];
    }
    final List<Map<String, dynamic>> maps = await db.query(
      'tags',
      where: 'tagName LIKE ?',
      whereArgs: ['$query%'],
      limit: 10,
    );
    return List.generate(maps.length, (i) => maps[i]['tagName'] as String);
  }

  // Saves a new category to the database.
  Future<void> saveCategory(Category cat) async {
    Database db = await database;
    if(cat.categoryId == 0) {
      await db.insert('categories', {'category': cat.category});
    } else {
      await db.insert('categories', {'categoryId': cat.categoryId, 'category': cat.category});
    }
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
  Future<double> getExpenseSumByMonth(DateTime date, int profileId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'expenses',
      // Specify the 'amount' column to be summed.
      columns: ['SUM(amount) as total'],
      where: "strftime('%Y-%m', expenseDate) = ? AND profileId = ?",
      whereArgs: [date.toIso8601String().substring(0, 7), profileId],
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

  // Retrieves the total spending for each category for a given month.
  Future<Map<String, double>> getCategorySpendingForMonth(DateTime date, int profileId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM expenses
      WHERE strftime('%Y-%m', expenseDate) = ? AND profileId = ?
      GROUP BY category
    ''', [date.toIso8601String().substring(0, 7), profileId]);

    final Map<String, double> categorySpending = {};
    for (var row in result) {
      categorySpending[row['category']] = row['total'];
    }

    return categorySpending;
  }

  // Retrieves the total spending for each tag for a given month.
  Future<Map<String, double>> getTagSpendingForMonth(DateTime date, int profileId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        COALESCE(T.tagName, '#') AS tagName,
        SUM(E.amount) AS total
      FROM
        expenses E
      LEFT JOIN
        expense_tags ET ON E.id = ET.expenseId
      LEFT JOIN
        tags T ON ET.tagId = T.tagId
      WHERE
        strftime('%Y-%m', E.expenseDate) = ? AND E.profileId = ?
      GROUP BY
        tagName
    ''', [date.toIso8601String().substring(0, 7), profileId]);

    final Map<String, double> tagSpending = {};
    for (var row in result) {
      tagSpending[row['tagName']] = row['total'];
    }

    return tagSpending;
  }

  // Retrieves the total expenses for the last five months.
  Future<Map<String, double>> getExpensesForLastFiveMonths(int profileId) async {
    final Database db = await database;
    final Map<String, double> monthlyTotals = {};
    final now = DateTime.now();

    for (int i = 0; i < 5; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = month.toIso8601String().substring(0, 7);
      final List<Map<String, dynamic>> result = await db.query(
        'expenses',
        columns: ['SUM(amount) as total'],
        where: "strftime('%Y-%m', expenseDate) = ? AND profileId = ?",
        whereArgs: [monthKey, profileId],
      );
      final double sum = result.first['total'] ?? 0.0;
      monthlyTotals[monthKey] = sum;
    }

    return monthlyTotals;
  }

  Future<List<Expense>> getExpensesByTag(String tagName, int profileId) async {
    final Database db = await database;
    // Find the tagId for the given tagName
    final List<Map<String, dynamic>> tagResult = await db.query(
      'tags',
      columns: ['tagId'],
      where: 'tagName = ?',
      whereArgs: [tagName],
    );

    if (tagResult.isEmpty) {
      // If the tag doesn't exist, return an empty list of expenses
      return [];
    }

    final int tagId = tagResult.first['tagId'] as int;

    // Use the tagId to get the expenses
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT E.*
      FROM expenses E
      JOIN expense_tags ET ON E.id = ET.expenseId
      WHERE ET.tagId = ? AND E.profileId = ?
      ORDER BY E.expenseDate DESC
    ''', [tagId, profileId]);

    return _mapMapsToExpenses(maps);
  }

  Future<List<String>> getAllTags() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tags',
      columns: ['tagName'],
      orderBy: 'tagName',
    );
    return List.generate(maps.length, (i) => maps[i]['tagName'] as String);
  }

  // Method to get all tags with recent usage flag (last 90 days) by profile
  Future<List<Map<String, dynamic>>> getAllTagsByProfile(int profileId) async {
    final Database db = await database;
    final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
    final ninetyDaysAgoStr = ninetyDaysAgo.toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> maps =  await db.rawQuery(
      '''
        SELECT 
          T.tagName,
          CASE 
            WHEN EXISTS (
              SELECT 1 
              FROM expense_tags ET
              JOIN expenses E ON ET.expenseId = E.id
              WHERE ET.tagId = T.tagId 
              AND E.expenseDate >= ? AND E.profileId = ?
            ) THEN 1 
            ELSE 0 
          END as isRecent
        FROM tags T
        ORDER BY isRecent DESC, T.tagName ASC
      ''', [ninetyDaysAgoStr, profileId]);

    return maps;
  }

  Future<List<String>> getTagsForRemark(String remarkQuery) async {
    final Database db = await database;
    if (remarkQuery.isEmpty) {
      return [];
    }

    // Find expenses with similar remarks
    final List<Map<String, dynamic>> expenseResult = await db.query(
      'expenses',
      columns: ['id'],
      where: 'remarks LIKE ?',
      whereArgs: ['%$remarkQuery%'],
      orderBy: 'id DESC', // Order by most recent
      limit: 10, // Limit to avoid too many results
    );

    if (expenseResult.isEmpty) {
      return [];
    }

    final List<int> expenseIds = expenseResult.map((e) => e['id'] as int).toList();

    // Get all tags for these expenses
    final List<Map<String, dynamic>> tagsResult = await db.rawQuery('''
      SELECT DISTINCT T.tagName
      FROM tags T
      JOIN expense_tags ET ON T.tagId = ET.tagId
      WHERE ET.expenseId IN (${expenseIds.map((_) => '?').join(',')})
    ''', expenseIds);

    return List.generate(tagsResult.length, (i) => tagsResult[i]['tagName'] as String);
  }

  Future<Category?> getCategoryForRemark(String remarks) async {
    final Database db = await database;
    if (remarks.isEmpty) {
      return null;
    }

    // Find expenses with similar remarks
    final List<Map<String, dynamic>> expenseResult = await db.query(
      'expenses',
      columns: ['categoryId', 'category'],
      where: 'remarks LIKE ?',
      whereArgs: [remarks.trim()],
      orderBy: 'id DESC', // Order by most recent
      limit: 1, // Limit to one result
    );

    if (expenseResult.isEmpty) {
      return null;
    }

    final int categoryId = expenseResult.first['categoryId'] as int;
    final String category = expenseResult.first['category'] as String;
    return Category(categoryId, category);
  }

  // Retrieves the total expenses for the last 15 days.
  Future<Map<String, double>> getExpensesForLast15Days(int profileId) async {
    final Database db = await database;
    final Map<String, double> dailyTotals = {};
    final now = DateTime.now();

    for (int i = 0; i < 15; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      final dayKey = day.toIso8601String().substring(0, 10);
      final List<Map<String, dynamic>> result = await db.query(
        'expenses',
        columns: ['SUM(amount) as total'],
        where: "date(expenseDate) = ? AND profileId = ?",
        whereArgs: [dayKey, profileId],
      );
      final double sum = result.first['total'] ?? 0.0;
      dailyTotals[dayKey] = sum;
    }

    return dailyTotals;
  }
}
