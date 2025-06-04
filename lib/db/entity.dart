class Expense {
  final int? id;
  final int? categoryId;
  final String category;
  final double amount;
  final String remarks;
  final DateTime entryDate;

  // Factory constructor to create an Expense from a Map
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      categoryId: map['categoryId'],
      category: map['category'],
      amount: map['amount'],
      remarks: map['remarks'],
      entryDate: DateTime.parse(
        map['entryDate'],
      ), // Assuming entryDate is stored as a String
    );
  }

  // Convert an Expense object into a Map
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'remarks': remarks,
      'entryDate':
          entryDate.toIso8601String(), // Store DateTime as ISO 8601 string
    };
  }

  Expense({
    this.id,
    this.categoryId,
    required this.category,
    required this.amount,
    required this.remarks,
    required this.entryDate,
  });
}

class Category {
  final int categoryId;
  final String category;

  Category(this.categoryId, this.category);

  Map<String, dynamic> toMap() {
    return {'categoryId': categoryId, 'category': category};
  }
}
