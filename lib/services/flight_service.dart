import '../models/flight_models.dart';
import 'gh_db_service.dart';

class FlightService {
  final _db = GhDbService();

  Map<String, dynamic>? _findRef(String key, int? id) {
    if (id == null) return null;
    final list = List<Map<String, dynamic>>.from(
      (_db.referenceData[key] as List? ?? []),
    );
    for (final item in list) {
      if ('${item['id']}' == '$id') return item;
    }
    return null;
  }

  List<FlightActivity> getAllFlights() {
    final flights = _db.flights.map((j) => FlightActivity.fromJson(
      j,
      _findRef('aircraftTypes', j['aircraft_type_id'] as int?),
      _findRef('flightTypes',   j['flight_type_id']   as int?),
    )).toList();
    flights.sort((a, b) => b.date.compareTo(a.date));
    return flights;
  }

  List<FlightActivity> getFlightsForPilot(String userId) {
    return getAllFlights()
        .where((f) => f.pilotIds.contains(userId))
        .toList();
  }

  Future<void> insertFlight({
    required DateTime date,
    required int aircraftTypeId,
    int? flightTypeId,
    required List<String> pilotIds,
    int? durationMinutes,
    String? notes,
    required String insertedByUserId,
  }) async {
    final flights = _db.flights.toList();
    final newFlight = FlightActivity(
      id: _db.nextId(flights),
      date: date,
      aircraftTypeId: aircraftTypeId,
      flightTypeId: flightTypeId,
      pilotIds: pilotIds,
      durationMinutes: durationMinutes,
      notes: notes,
      insertedByUserId: insertedByUserId,
      createdAt: DateTime.now(),
    );
    flights.insert(0, newFlight.toJson());
    await _db.saveFlights(flights);
  }

  Future<void> deleteFlight(int flightId) async {
    final flights = _db.flights.where((f) => f['id'] != flightId).toList();
    await _db.saveFlights(flights);
  }
}
