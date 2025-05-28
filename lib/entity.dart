class Expense {
  final int? id;
  final String category;
  final double amount;
  final String remarks;
  final DateTime entryDate;

  // Factory constructor to create an Expense from a Map
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      category: map['category'],
      amount: map['amount'],
      remarks: map['remarks'],
      entryDate: DateTime.parse(map['entryDate']), // Assuming entryDate is stored as a String
    );
  }

  // Convert an Expense object into a Map
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'remarks': remarks,
      'entryDate': entryDate.toIso8601String(), // Store DateTime as ISO 8601 string
    };
  }

  Expense({
    this.id,
    required this.category,
    required this.amount,
    required this.remarks,
    required this.entryDate,
  });
}