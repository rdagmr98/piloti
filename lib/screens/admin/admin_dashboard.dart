import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/flight_models.dart';
import '../../models/user_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/flight_service.dart';
import '../../services/user_service.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});
  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  final _userService = UserService();
  final _flightService = FlightService();
  List<UserProfile> _pilots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _loading = true);
    _pilots = _userService.getAllUsers().where((u) => !u.isAdmin).toList();
    setState(() => _loading = false);
  }

  String _fmt(DateTime? d) =>
      d == null ? '-' : DateFormat('dd/MM/yyyy').format(d);

  Color _expiryColor(DateTime? expiry) {
    if (expiry == null) return Colors.grey;
    final days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.red;
    if (days <= 60) return Colors.orange;
    return Colors.green;
  }

  String _expiryStatus(DateTime? expiry) {
    if (expiry == null) return 'Non impostata';
    final days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) return 'Scaduta';
    if (days == 0) return 'Scade oggi';
    if (days <= 60) return 'In scadenza';
    return 'Valida';
  }

  Future<void> _editExpiry(UserProfile pilot) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: pilot.fitnessExpiry ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    await _userService.updateFitnessExpiry(pilot.id, picked);
    _load();
  }

  Future<void> _showFlights(UserProfile pilot) async {
    final flights = _flightService.getFlightsForPilot(pilot.id);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Voli di ${pilot.fullName}'),
        content: SizedBox(
          width: 400,
          child: flights.isEmpty
              ? const Text('Nessun volo registrato.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: flights.length,
                  itemBuilder: (_, i) {
                    final f = flights[i];
                    return ListTile(
                      leading: const Icon(Icons.flight_takeoff),
                      title: Text('${f.aircraftCode}  •  ${_fmt(f.date)}'),
                      subtitle: f.durationMinutes != null
                          ? Text('${f.durationMinutes} min')
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _addFlight() async {
    final auth = ref.read(authProvider);
    final aircraftTypes = auth.aircraftTypes;
    DateTime date = DateTime.now();
    int? selectedAircraftId = aircraftTypes.isEmpty ? null : aircraftTypes.first.id;
    final durationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final selectedPilotIds = <String>{};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Inserisci volo'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(DateFormat('dd/MM/yyyy').format(date)),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) setDialogState(() => date = d);
                    },
                  ),
                  DropdownButtonFormField<int>(
                    value: selectedAircraftId,
                    decoration: const InputDecoration(labelText: 'Aeromobile'),
                    items: aircraftTypes
                        .map(
                          (a) =>
                              DropdownMenuItem(value: a.id, child: Text(a.code)),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedAircraftId = v),
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
                  const SizedBox(height: 16),
                  const Text(
                    'Piloti',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ..._pilots.map(
                    (p) => CheckboxListTile(
                      dense: true,
                      title: Text(p.fullName),
                      value: selectedPilotIds.contains(p.id),
                      onChanged: (v) => setDialogState(() {
                        if (v == true) {
                          selectedPilotIds.add(p.id);
                        } else {
                          selectedPilotIds.remove(p.id);
                        }
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: selectedPilotIds.isEmpty || selectedAircraftId == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await _flightService.insertFlight(
                        date: date,
                        aircraftTypeId: selectedAircraftId!,
                        pilotIds: selectedPilotIds.toList(),
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
          ],
        ),
      ),
    );
  }

  Future<void> _addPilot() async {
    final nomeCtrl = TextEditingController();
    final cognomeCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuovo pilota'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: cognomeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cognome *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email (opzionale)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              if (nomeCtrl.text.isEmpty ||
                  cognomeCtrl.text.isEmpty ||
                  usernameCtrl.text.isEmpty ||
                  passCtrl.text.isEmpty) {
                return;
              }
              Navigator.of(ctx).pop();
              await _userService.createUser(
                nome: nomeCtrl.text.trim(),
                cognome: cognomeCtrl.text.trim(),
                username: usernameCtrl.text.trim(),
                password: passCtrl.text,
                email: emailCtrl.text.isEmpty ? null : emailCtrl.text.trim(),
              );
              _load();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5C6BC0),
            ),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Piloti'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _addPilot,
            tooltip: 'Aggiungi pilota',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _load(),
              child: _pilots.isEmpty
                  ? const Center(
                      child: Text('Nessun pilota registrato.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _pilots.length,
                      itemBuilder: (_, i) {
                        final p = _pilots[i];
                        final color = _expiryColor(p.fitnessExpiry);
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.2),
                              child: Text(
                                p.cognome.isNotEmpty
                                    ? p.cognome[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              p.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    _expiryStatus(p.fitnessExpiry),
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  p.fitnessExpiry != null
                                      ? _fmt(p.fitnessExpiry)
                                      : '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.flight_takeoff, size: 20),
                                  onPressed: () => _showFlights(p),
                                  tooltip: 'Voli',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_calendar, size: 20),
                                  onPressed: () => _editExpiry(p),
                                  tooltip: 'Modifica scadenza',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFlight,
        backgroundColor: const Color(0xFF5C6BC0),
        icon: const Icon(Icons.add),
        label: const Text('Inserisci volo'),
      ),
    );
  }
}
