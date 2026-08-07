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

class Subscription {
  final int? id;
  final int profileId;
  final String title;
  final double amount;
  final int categoryId;
  final String category;
  final String billingCycle; // 'Monthly', 'Yearly', 'Weekly'
  final DateTime startDate;
  final DateTime nextBillingDate;
  final String currency; // 'Rupee', 'Dollar', 'Euro', 'Pound', 'Dirham'
  final String? paymentMethod;
  final String? remarks;
  final bool isActive;
  final bool autoLogExpense;

  Subscription({
    this.id,
    required this.profileId,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.category,
    required this.billingCycle,
    required this.startDate,
    required this.nextBillingDate,
    this.currency = 'Rupee',
    this.paymentMethod,
    this.remarks,
    this.isActive = true,
    this.autoLogExpense = false,
  });

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'],
      profileId: map['profileId'] ?? 0,
      title: map['title'],
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] ?? 0,
      category: map['category'] ?? 'Others',
      billingCycle: map['billingCycle'] ?? 'Monthly',
      startDate: DateTime.parse(map['startDate']),
      nextBillingDate: DateTime.parse(map['nextBillingDate']),
      currency: map['currency'] ?? 'Rupee',
      paymentMethod: map['paymentMethod'],
      remarks: map['remarks'],
      isActive: (map['isActive'] ?? 1) == 1,
      autoLogExpense: (map['autoLogExpense'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'category': category,
      'billingCycle': billingCycle,
      'startDate': startDate.toIso8601String(),
      'nextBillingDate': nextBillingDate.toIso8601String(),
      'currency': currency,
      'paymentMethod': paymentMethod,
      'remarks': remarks,
      'isActive': isActive ? 1 : 0,
      'autoLogExpense': autoLogExpense ? 1 : 0,
    };
  }

  double get monthlyAmount {
    switch (billingCycle.toLowerCase()) {
      case 'yearly':
        return amount / 12.0;
      case 'weekly':
        return amount * 4.333;
      case 'monthly':
      default:
        return amount;
    }
  }

  Subscription copyWith({
    int? id,
    int? profileId,
    String? title,
    double? amount,
    int? categoryId,
    String? category,
    String? billingCycle,
    DateTime? startDate,
    DateTime? nextBillingDate,
    String? currency,
    String? paymentMethod,
    String? remarks,
    bool? isActive,
    bool? autoLogExpense,
  }) {
    return Subscription(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      billingCycle: billingCycle ?? this.billingCycle,
      startDate: startDate ?? this.startDate,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      remarks: remarks ?? this.remarks,
      isActive: isActive ?? this.isActive,
      autoLogExpense: autoLogExpense ?? this.autoLogExpense,
    );
  }
}

