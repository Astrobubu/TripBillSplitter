enum PaymentStatus {
  pending,
  completed,
  cancelled,
}

class Payment {
  final String id;
  final String tripId;
  final String fromPersonId;
  final String toPersonId;
  final double amount;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? note;

  Payment({
    required this.id,
    required this.tripId,
    required this.fromPersonId,
    required this.toPersonId,
    required this.amount,
    this.status = PaymentStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'fromPersonId': fromPersonId,
      'toPersonId': toPersonId,
      'amount': amount,
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'note': note,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String,
      tripId: map['tripId'] as String,
      fromPersonId: map['fromPersonId'] as String,
      toPersonId: map['toPersonId'] as String,
      amount: map['amount'] as double,
      status: PaymentStatus.values[map['status'] as int],
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt'] as String) : null,
      note: map['note'] as String?,
    );
  }

  Payment copyWith({
    String? id,
    String? tripId,
    String? fromPersonId,
    String? toPersonId,
    double? amount,
    PaymentStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? note,
  }) {
    return Payment(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      fromPersonId: fromPersonId ?? this.fromPersonId,
      toPersonId: toPersonId ?? this.toPersonId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
    );
  }
}
