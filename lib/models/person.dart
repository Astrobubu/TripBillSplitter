class Person {
  final String id;
  final String name;
  final String tripId;

  Person({
    required this.id,
    required this.name,
    required this.tripId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tripId': tripId,
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      name: map['name'] as String,
      tripId: map['tripId'] as String,
    );
  }

  Person copyWith({
    String? id,
    String? name,
    String? tripId,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      tripId: tripId ?? this.tripId,
    );
  }
}
