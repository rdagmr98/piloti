import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/flight_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/flight_service.dart';
import '../../services/user_service.dart';

class UserDashboard extends ConsumerStatefulWidget {
  const UserDashboard({super.key});
  @override
  ConsumerState<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends ConsumerState<UserDashboard> {
  final _flightService = FlightService();
  final _userService = UserService();
  List<FlightActivity> _flights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _loading = true);
    _flights = _flightService.getFlightsForPilot(
      ref.read(authProvider).currentUser!.id,
    );
    setState(() => _loading = false);
  }

  Color _expiryColor(DateTime? expiry) {
    if (expiry == null) return Colors.grey;
    final days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.red;
    if (days <= 60) return Colors.orange;
    return Colors.green;
  }

  String _expiryLabel(DateTime? expiry) {
    if (expiry == null) return 'Non impostata';
    final days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) return 'Scaduta il ${_fmt(expiry)}';
    if (days == 0) return 'Scade oggi';
    return 'Scade il ${_fmt(expiry)} (tra $days gg)';
  }

  String _fmt(DateTime? d) =>
      d == null ? '-' : DateFormat('dd/MM/yyyy').format(d);

  Future<void> _editExpiry() async {
    final user = ref.read(authProvider).currentUser!;
    final picked = await showDatePicker(
      context: context,
      initialDate: user.fitnessExpiry ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    await _userService.updateFitnessExpiry(user.id, picked);
    ref.read(authProvider).refreshUser();
    setState(() {});
  }

  Future<void> _addFlight() async {
    final auth = ref.read(authProvider);
    final aircraftTypes = auth.aircraftTypes;
    DateTime? date = DateTime.now();
    int? selectedAircraftId = aircraftTypes.isEmpty ? null : aircraftTypes.first.id;
    final durationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aggiungi volo',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('dd/MM/yyyy').format(date!)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date!,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setModalState(() => date = d);
                },
              ),
              DropdownButtonFormField<int>(
                value: selectedAircraftId,
                decoration: const InputDecoration(labelText: 'Aeromobile'),
                items: aircraftTypes
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.code)),
                    )
                    .toList(),
                onChanged: (v) => setModalState(() => selectedAircraftId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durata (minuti)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (opzionale)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (selectedAircraftId == null) return;
                    Navigator.of(ctx).pop();
                    await _flightService.insertFlight(
                      date: date!,
                      aircraftTypeId: selectedAircraftId!,
                      pilotIds: [auth.currentUser!.id],
                      durationMinutes: int.tryParse(durationCtrl.text),
                      notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                      insertedByUserId: auth.currentUser!.id,
                    );
                    _load();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0),
                  ),
                  child: const Text('Salva'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return const SizedBox.shrink();
    final expiryColor = _expiryColor(user.fitnessExpiry);

    return Scaffold(
      appBar: AppBar(
        title: Text(user.fullName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: expiryColor, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.medical_information, color: expiryColor, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Idoneità al volo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _expiryLabel(user.fitnessExpiry),
                            style: TextStyle(color: expiryColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: _editExpiry,
                      tooltip: 'Modifica scadenza',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'I miei voli',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_flights.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nessun volo inserito.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._flights.map(
                (f) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.flight_takeoff),
                    title: Text(
                      '${f.aircraftCode}  •  ${_fmt(f.date)}',
                    ),
                    subtitle: f.durationMinutes != null
                        ? Text('${f.durationMinutes} min')
                        : null,
                    trailing: f.notes != null
                        ? Tooltip(
                            message: f.notes!,
                            child: const Icon(Icons.notes, size: 18),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFlight,
        backgroundColor: const Color(0xFF5C6BC0),
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi volo'),
      ),
    );
  }
}
