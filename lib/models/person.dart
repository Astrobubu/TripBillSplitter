class Person {
  final String id;
  final String name;
  final String tripId;
  final String? phoneNumber;

  Person({
    required this.id,
    required this.name,
    required this.tripId,
    this.phoneNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tripId': tripId,
      'phone_number': phoneNumber,
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      name: map['name'] as String,
      tripId: map['tripId'] as String,
      phoneNumber: map['phone_number'] as String?,
    );
  }

  Person copyWith({
    String? id,
    String? name,
    String? tripId,
    String? phoneNumber,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      tripId: tripId ?? this.tripId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
