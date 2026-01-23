class Trip {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String currency;
  final int totalParticipants;
  final bool isArchived;
  final int iconCodePoint;
  final int colorValue;

  Trip({
    required this.id,
    required this.name,
    required this.createdAt,
    this.updatedAt,
    this.currency = '\$',
    this.totalParticipants = 2,
    this.isArchived = false,
    this.iconCodePoint = 0xe540, // Icons.luggage
    this.colorValue = 0xFF2196F3, // Blue
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'currency': currency,
      'totalParticipants': totalParticipants,
      'isArchived': isArchived ? 1 : 0,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
      currency: map['currency'] as String? ?? '\$',
      totalParticipants: map['totalParticipants'] as int? ?? 0,
      isArchived: (map['isArchived'] as int?) == 1,
      iconCodePoint: map['iconCodePoint'] as int? ?? 0xe540,
      colorValue: map['colorValue'] as int? ?? 0xFF2196F3,
    );
  }

  Trip copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? currency,
    int? totalParticipants,
    bool? isArchived,
    int? iconCodePoint,
    int? colorValue,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currency: currency ?? this.currency,
      totalParticipants: totalParticipants ?? this.totalParticipants,
      isArchived: isArchived ?? this.isArchived,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
