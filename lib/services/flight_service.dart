import '../models/flight_models.dart';
import 'gh_db_service.dart';

class FlightService {
  final _db = GhDbService();

  Map<String, dynamic>? _findAircraft(int id) {
    final list = List<Map<String, dynamic>>.from(
      (_db.referenceData['aircraftTypes'] as List? ?? []),
    );
    for (final a in list) {
      if ('${a['id']}' == '$id') return a;
    }
    return null;
  }

  List<FlightActivity> getAllFlights() {
    final flights = _db.flights
        .map((j) => FlightActivity.fromJson(j, _findAircraft(j['aircraft_type_id'] as int? ?? 0)))
        .toList();
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
