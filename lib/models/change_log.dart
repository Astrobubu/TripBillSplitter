enum ChangeType {
  expenseAdded,
  expenseUpdated,
  expenseDeleted,
  personAdded,
  personRemoved,
  tripCreated,
  tripUpdated,
  paymentAdded,
  paymentUpdated,
}

class ChangeLogEntry {
  final String id;
  final String tripId;
  final ChangeType changeType;
  final DateTime timestamp;
  final String description;
  final Map<String, dynamic>? metadata;

  ChangeLogEntry({
    required this.id,
    required this.tripId,
    required this.changeType,
    required this.timestamp,
    required this.description,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'changeType': changeType.index,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
    };
  }

  factory ChangeLogEntry.fromMap(Map<String, dynamic> map) {
    return ChangeLogEntry(
      id: map['id'] as String,
      tripId: map['tripId'] as String,
      changeType: ChangeType.values[map['changeType'] as int],
      timestamp: DateTime.parse(map['timestamp'] as String),
      description: map['description'] as String,
      metadata: map['metadata'] != null ? _decodeMetadata(map['metadata'] as String) : null,
    );
  }

  static String _encodeMetadata(Map<String, dynamic> metadata) {
    // Simple JSON encoding for metadata
    return metadata.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  static Map<String, dynamic> _decodeMetadata(String encoded) {
    final map = <String, dynamic>{};
    if (encoded.isEmpty) return map;
    for (final pair in encoded.split(',')) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }
}
