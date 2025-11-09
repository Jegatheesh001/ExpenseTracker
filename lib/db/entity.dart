class Expense {
  final int? id;
  final int profileId;
  final int? categoryId;
  final String category;
  final double amount;
  final String remarks;
  final DateTime expenseDate;
  final DateTime entryDate;
  final List<String> tags;

  // Factory constructor to create an Expense from a Map
  factory Expense.fromMap(Map<String, dynamic> map, {List<String>? tags}) {
    return Expense(
      id: map['id'],
      profileId: map['profileId'],
      categoryId: map['categoryId'],
      category: map['category'],
      amount: map['amount'],
      remarks: map['remarks'],
      expenseDate: DateTime.parse(
        map['expenseDate'],
      ),
      entryDate: DateTime.parse(
        map['entryDate'],
      ),
      tags: tags ?? [],
    );
  }

  // Convert an Expense object into a Map
  Map<String, dynamic> toMap() {
    return {
      'profileId': profileId,
      'categoryId': categoryId,
      'category': category,
      'amount': amount,
      'remarks': remarks,
      'expenseDate': expenseDate.toIso8601String(),
      'entryDate': entryDate.toIso8601String(),
    };
  }

  // Constructor for Expense.
  Expense({
    this.id,
    required this.profileId,
    this.categoryId,
    required this.category,
    required this.amount,
    required this.remarks,
    required this.expenseDate,
    required this.entryDate,
    this.tags = const [],
  });
}

class Category {
  final int categoryId;
  final String category;

  // Constructor for Category.
  Category(this.categoryId, this.category);

  Map<String, dynamic> toMap() {
    return {'categoryId': categoryId, 'category': category};
  }
}

class Tag {
  final int tagId;
  final String tagName;

  Tag(this.tagId, this.tagName);

  Map<String, dynamic> toMap() {
    return {'tagId': tagId, 'tagName': tagName};
  }
}
