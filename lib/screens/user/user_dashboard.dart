import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/flight_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/flight_service.dart';
import '../../services/user_service.dart';
import '../../widgets/go_nogo_orb.dart';
import '../../widgets/hud_painters.dart';

class UserDashboard extends ConsumerStatefulWidget {
  const UserDashboard({super.key});
  @override
  ConsumerState<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends ConsumerState<UserDashboard>
    with TickerProviderStateMixin {
  final _flightService = FlightService();
  final _userService = UserService();
  List<FlightActivity> _flights = [];
  bool _loading = true;

  late AnimationController _scanCtrl;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _load();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _load() {
    setState(() => _loading = true);
    _flights = _flightService.getFlightsForPilot(
      ref.read(authProvider).currentUser!.id,
    );
    setState(() => _loading = false);
  }

  String _fmt(DateTime? d) =>
      d == null ? '---' : DateFormat('dd/MM/yyyy').format(d);

  String _countdown(DateTime? expiry) {
    if (expiry == null) return 'SCADENZA NON IMPOSTATA';
    final days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) return 'IDONEITÀ SCADUTA ${-days} GIORNI FA';
    if (days == 0) return 'IDONEITÀ SCADE OGGI';
    return 'IDONEITÀ VALIDA — SCADE TRA $days GIORNI';
  }

  Future<void> _editExpiry() async {
    final user = ref.read(authProvider).currentUser!;
    final picked = await showDatePicker(
      context: context,
      initialDate: user.fitnessExpiry ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: kCyan),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    await _userService.updateFitnessExpiry(user.id, picked);
    ref.read(authProvider).refreshUser();
    setState(() {});
  }

  Future<void> _addFlight() async {
    final auth = ref.read(authProvider);
    final aircraftTypes = auth.aircraftTypes;
    final flightTypes   = auth.flightTypes;
    DateTime date = DateTime.now();
    int? selectedAircraftId = aircraftTypes.isEmpty ? null : aircraftTypes.first.id;
    int? selectedFlightTypeId = flightTypes.isEmpty ? null : flightTypes.first.id;
    final durationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => _HudDialogSimple(
          title: 'REGISTRA VOLO',
          onSave: selectedAircraftId == null
              ? null
              : () async {
                  Navigator.of(ctx).pop();
                  await _flightService.insertFlight(
                    date: date,
                    aircraftTypeId: selectedAircraftId!,
                    flightTypeId: selectedFlightTypeId,
                    pilotIds: [auth.currentUser!.id],
                    durationMinutes: int.tryParse(durationCtrl.text),
                    notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                    insertedByUserId: auth.currentUser!.id,
                  );
                  _load();
                },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HudInfoRow(
                label: 'DATA',
                value: DateFormat('dd/MM/yyyy').format(date),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: kCyan),
                      ),
                      child: child!,
                    ),
                  );
                  if (d != null) set(() => date = d);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: selectedAircraftId,
                dropdownColor: kBgCard,
                style: const TextStyle(color: Colors.white),
                decoration: _hudInputDecoration('AEROMOBILE'),
                items: aircraftTypes
                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.code)))
                    .toList(),
                onChanged: (v) => set(() => selectedAircraftId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: selectedFlightTypeId,
                dropdownColor: kBgCard,
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _hudInputDecoration('TIPO VOLO'),
                items: flightTypes
                    .map((ft) => DropdownMenuItem(
                          value: ft.id,
                          child: Text(ft.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => set(() => selectedFlightTypeId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _hudInputDecoration('DURATA (MINUTI)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _hudInputDecoration('NOTE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _hudInputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: kCyan.withValues(alpha: 0.6), letterSpacing: 2, fontSize: 11),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: kCyan.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.zero,
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: kCyan),
      borderRadius: BorderRadius.zero,
    ),
    filled: true,
    fillColor: kCyan.withValues(alpha: 0.04),
  );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return const SizedBox.shrink();
    final status = fitnessStatus(user.fitnessExpiry);
    final color = statusColor(status);

    return Scaffold(
      backgroundColor: kBg,
      body: AnimatedBuilder(
        animation: _scanCtrl,
        builder: (_, child) => Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: HudGridPainter(_scanCtrl.value)),
            ),
            child!,
          ],
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeCtrl,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: kBgCard,
                    border: Border(
                      bottom: BorderSide(color: kCyan.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Image.asset(
                          'assets/images/aves_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.flight, color: kCyan, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName.toUpperCase(),
                              style: TextStyle(
                                color: kCyan,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                shadows: [Shadow(color: kCyan.withValues(alpha: 0.5), blurRadius: 6)],
                              ),
                            ),
                            Text(
                              'PILOTA — AVIAZIONE DELL\'ESERCITO',
                              style: TextStyle(color: kCyan.withValues(alpha: 0.4), fontSize: 9, letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 18),
                        color: kCyan.withValues(alpha: 0.6),
                        onPressed: () async {
                          await ref.read(authProvider).signOut();
                          if (context.mounted) context.go('/login');
                        },
                      ),
                    ],
                  ),
                ),

                // Fitness expiry panel
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: kBgCard,
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: HudCornerPainter(color: color, size: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            GoNoGoOrb(status: status, size: 80),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'IDONEITÀ AL VOLO',
                                    style: TextStyle(
                                      color: kCyan.withValues(alpha: 0.6),
                                      fontSize: 10,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _countdown(user.fitnessExpiry),
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (user.fitnessExpiry != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'SCADENZA: ${_fmt(user.fitnessExpiry)}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 11,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_calendar),
                              color: kCyan.withValues(alpha: 0.7),
                              onPressed: _editExpiry,
                              tooltip: 'Aggiorna scadenza',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Flights section header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 3, height: 14, color: kCyan),
                      const SizedBox(width: 8),
                      Text(
                        'I MIEI VOLI',
                        style: TextStyle(
                          color: kCyan,
                          letterSpacing: 3,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_flights.length} REGISTRATI',
                        style: TextStyle(color: kCyan.withValues(alpha: 0.4), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Flight list
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: kCyan))
                      : _flights.isEmpty
                          ? Center(
                              child: Text(
                                'NESSUN VOLO REGISTRATO',
                                style: TextStyle(
                                  color: kCyan.withValues(alpha: 0.3),
                                  letterSpacing: 3,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async => _load(),
                              color: kCyan,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _flights.length,
                                itemBuilder: (_, i) => _FlightRow(flight: _flights[i]),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFlight,
        backgroundColor: kCyan.withValues(alpha: 0.15),
        foregroundColor: kCyan,
        shape: const RoundedRectangleBorder(side: BorderSide(color: kCyan)),
        icon: const Icon(Icons.flight_takeoff),
        label: const Text('REGISTRA VOLO', style: TextStyle(letterSpacing: 2)),
      ),
    );
  }
}

class _FlightRow extends StatelessWidget {
  final FlightActivity flight;
  const _FlightRow({required this.flight});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kBgCard,
        border: Border.all(color: kCyan.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Aircraft image or icon
          Container(
            width: 48,
            height: 32,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: kCyan.withValues(alpha: 0.05),
              border: Border.all(color: kCyan.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.flight_takeoff, color: kCyan, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flight.aircraftCode.toUpperCase(),
                  style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (flight.flightTypeCode.isNotEmpty)
                  Text(
                    flight.flightTypeCode,
                    style: TextStyle(color: kCyan.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1),
                  ),
                if (flight.notes != null)
                  Text(
                    flight.notes!,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('dd/MM/yyyy').format(flight.date),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
              if (flight.durationMinutes != null)
                Text(
                  '${flight.durationMinutes} MIN',
                  style: TextStyle(color: kCyan.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HudInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _HudInfoRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: kCyan.withValues(alpha: 0.3)),
          color: kCyan.withValues(alpha: 0.04),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: kCyan.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 2)),
            const Spacer(),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.edit, size: 12, color: kCyan.withValues(alpha: 0.4)),
            ],
          ],
        ),
      ),
    );
  }
}

class _HudDialogSimple extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onSave;

  const _HudDialogSimple({required this.title, required this.child, this.onSave});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: kBgCard,
          border: Border.all(color: kCyan.withValues(alpha: 0.4)),
        ),
        child: CustomPaint(
          painter: HudCornerPainter(color: kCyan, size: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: kCyan.withValues(alpha: 0.3))),
                ),
                child: Row(
                  children: [
                    Text(title, style: const TextStyle(color: kCyan, letterSpacing: 3, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: kCyan.withValues(alpha: 0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('ANNULLA', style: TextStyle(color: kCyan.withValues(alpha: 0.5), letterSpacing: 2)),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: onSave,
                      style: FilledButton.styleFrom(backgroundColor: kCyan.withValues(alpha: 0.2)),
                      child: const Text('SALVA', style: TextStyle(color: kCyan, letterSpacing: 2)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
