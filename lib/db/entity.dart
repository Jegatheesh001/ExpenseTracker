class BilledItem {
  final int? id;
  final int? expenseId;
  final String itemName;
  final double quantity;
  final double price;

  BilledItem({
    this.id,
    this.expenseId,
    required this.itemName,
    required this.quantity,
    required this.price,
  });

  factory BilledItem.fromMap(Map<String, dynamic> map) {
    return BilledItem(
      id: map['id'],
      expenseId: map['expenseId'],
      itemName: map['itemName'],
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expenseId': expenseId,
      'itemName': itemName,
      'quantity': quantity,
      'price': price,
    };
  }
}

class Expense {
  final int? id;
  final int profileId;
  final int categoryId;
  final String category;
  final double amount;
  final String remarks;
  final DateTime expenseDate;
  final DateTime entryDate;
  final List<String> tags;
  final String? paymentMethod;
  final List<BilledItem> billedItems;

  // Factory constructor to create an Expense from a Map
  factory Expense.fromMap(Map<String, dynamic> map, {List<String>? tags, List<BilledItem>? billedItems}) {
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
      paymentMethod: map['paymentMethod'],
      billedItems: billedItems ?? [],
    );
  }

  // Convert an Expense object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'categoryId': categoryId,
      'category': category,
      'amount': amount,
      'remarks': remarks,
      'expenseDate': expenseDate.toIso8601String(),
      'entryDate': entryDate.toIso8601String(),
      'paymentMethod': paymentMethod,
    };
  }

  // Constructor for Expense.
  Expense({
    this.id,
    required this.profileId,
    required this.categoryId,
    required this.category,
    required this.amount,
    required this.remarks,
    required this.expenseDate,
    required this.entryDate,
    this.tags = const [],
    this.paymentMethod,
    this.billedItems = const [],
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
