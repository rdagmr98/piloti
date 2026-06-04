class FlightActivity {
  final int id;
  final DateTime date;
  final int aircraftTypeId;
  final String aircraftCode;
  final String aircraftName;
  final int? durationMinutes;
  final List<String> pilotIds;
  final String? notes;
  final String? insertedByUserId;
  final DateTime createdAt;

  const FlightActivity({
    required this.id,
    required this.date,
    required this.aircraftTypeId,
    this.aircraftCode = '',
    this.aircraftName = '',
    this.durationMinutes,
    required this.pilotIds,
    this.notes,
    this.insertedByUserId,
    required this.createdAt,
  });

  factory FlightActivity.fromJson(
    Map<String, dynamic> j,
    Map<String, dynamic>? aircraft,
  ) => FlightActivity(
    id: j['id'] as int,
    date: DateTime.parse(j['date'] as String),
    aircraftTypeId: j['aircraft_type_id'] as int,
    aircraftCode: aircraft?['code'] as String? ?? '',
    aircraftName: aircraft?['name'] as String? ?? '',
    durationMinutes: j['duration_minutes'] as int?,
    pilotIds: List<String>.from(j['pilot_ids'] as List? ?? []),
    notes: j['notes'] as String?,
    insertedByUserId: j['inserted_by_user_id'] as String?,
    createdAt: DateTime.parse(
      j['created_at'] as String? ?? DateTime.now().toIso8601String(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String().split('T').first,
    'aircraft_type_id': aircraftTypeId,
    'duration_minutes': durationMinutes,
    'pilot_ids': pilotIds,
    'notes': notes,
    'inserted_by_user_id': insertedByUserId,
    'created_at': createdAt.toIso8601String(),
  };
}
