class Expense {
  final String id;
  final String description;
  final double amount;
  final String payerId;
  final String tripId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.payerId,
    required this.tripId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'payerId': payerId,
      'tripId': tripId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      description: map['description'] as String,
      amount: map['amount'] as double,
      payerId: map['payerId'] as String,
      tripId: map['tripId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
    );
  }

  Expense copyWith({
    String? id,
    String? description,
    double? amount,
    String? payerId,
    String? tripId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      payerId: payerId ?? this.payerId,
      tripId: tripId ?? this.tripId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
