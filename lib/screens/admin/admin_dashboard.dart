import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/user_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/flight_service.dart';
import '../../services/user_service.dart';
import '../../widgets/go_nogo_orb.dart';
import '../../widgets/hud_painters.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});
  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with TickerProviderStateMixin {
  final _userService = UserService();
  final _flightService = FlightService();
  List<UserProfile> _pilots = [];
  bool _loading = true;

  late AnimationController _scanCtrl;
  late AnimationController _headerCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  void _load() {
    setState(() => _loading = true);
    _pilots = _userService.getAllUsers().where((u) => !u.isAdmin).toList();
    _pilots.sort((a, b) {
      final sa = fitnessStatus(a.fitnessExpiry);
      final sb = fitnessStatus(b.fitnessExpiry);
      final order = [PilotStatus.noGo, PilotStatus.warning, PilotStatus.noData, PilotStatus.go];
      return order.indexOf(sa).compareTo(order.indexOf(sb));
    });
    setState(() => _loading = false);
  }

  String _fmt(DateTime? d) =>
      d == null ? '---' : DateFormat('dd/MM/yyyy').format(d);

  String _countdown(DateTime? expiry) {
    if (expiry == null) return 'N/D';
    final days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) return 'SCADUTO ${-days}gg fa';
    if (days == 0) return 'SCADE OGGI';
    return 'SCADE TRA ${days}gg';
  }

  Future<void> _editExpiry(UserProfile pilot) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: pilot.fitnessExpiry ?? DateTime.now(),
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
    await _userService.updateFitnessExpiry(pilot.id, picked);
    _load();
  }

  Future<void> _showFlights(UserProfile pilot) async {
    final flights = _flightService.getFlightsForPilot(pilot.id);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _HudDialog(
        title: 'VOLI — ${pilot.fullName.toUpperCase()}',
        child: flights.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nessun volo registrato.',
                    style: TextStyle(color: Colors.white54)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: flights
                    .take(20)
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.flight_takeoff, color: kCyan, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              f.aircraftCode,
                              style: const TextStyle(color: kCyan, fontSize: 13),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _fmt(f.date),
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            if (f.durationMinutes != null) ...[
                              const SizedBox(width: 12),
                              Text(
                                '${f.durationMinutes}min',
                                style: TextStyle(color: kCyan.withValues(alpha: 0.6), fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
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

    // Eligibility helpers
    bool isQualified(UserProfile p) =>
        selectedAircraftId == null ||
        p.aircraftQualificationIds.contains(selectedAircraftId);

    bool isCurrent(UserProfile p) {
      final s = fitnessStatus(p.fitnessExpiry);
      return s == PilotStatus.go || s == PilotStatus.warning;
    }

    bool isEligible(UserProfile p) => isQualified(p) && isCurrent(p);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          // Remove any selected pilots who became ineligible after aircraft change
          selectedPilotIds.removeWhere((id) {
            final p = _pilots.firstWhere((x) => x.id == id, orElse: () => _pilots.first);
            return !isEligible(p);
          });

          final eligiblePilots   = _pilots.where(isEligible).toList();
          final ineligiblePilots = _pilots.where((p) => !isEligible(p)).toList();

          return _HudDialog(
            title: 'INSERISCI VOLO',
            action: FilledButton(
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
              style: FilledButton.styleFrom(backgroundColor: kCyan.withValues(alpha: 0.2)),
              child: const Text('SALVA', style: TextStyle(color: kCyan, letterSpacing: 2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HudTile(
                  label: 'DATA',
                  value: DateFormat('dd/MM/yyyy').format(date),
                  icon: Icons.calendar_today,
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
                _hudDropdown<int>(
                  label: 'AEROMOBILE',
                  value: selectedAircraftId,
                  items: aircraftTypes
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.code)))
                      .toList(),
                  onChanged: (v) => set(() {
                    selectedAircraftId = v;
                    // deselect pilots no longer eligible
                    selectedPilotIds.removeWhere((id) {
                      final p = _pilots.firstWhere((x) => x.id == id,
                          orElse: () => _pilots.first);
                      return !isEligible(p);
                    });
                  }),
                ),
                const SizedBox(height: 12),
                _hudTextField(durationCtrl, 'DURATA (MIN)', TextInputType.number),
                const SizedBox(height: 12),
                _hudTextField(notesCtrl, 'NOTE', TextInputType.text),
                const SizedBox(height: 16),

                // ── Piloti idonei ──
                Row(children: [
                  Container(width: 3, height: 12, color: kGo),
                  const SizedBox(width: 6),
                  Text(
                    'PILOTI IDONEI (${eligiblePilots.length})',
                    style: TextStyle(color: kGo, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ]),
                const SizedBox(height: 6),
                if (eligiblePilots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nessun pilota abilitato e current su questo aeromobile.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                else
                  ...eligiblePilots.map((p) {
                    final status = fitnessStatus(p.fitnessExpiry);
                    final color  = statusColor(status);
                    return CheckboxListTile(
                      dense: true,
                      title: Row(children: [
                        Text(
                          p.callsign != null ? p.callsign! : p.fullName,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        if (p.callsign != null) ...[
                          const SizedBox(width: 6),
                          Text(p.fullName, style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ]),
                      subtitle: Row(children: [
                        MiniStatusDot(status: status),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel(status),
                          style: TextStyle(color: color, fontSize: 10, letterSpacing: 1),
                        ),
                      ]),
                      value: selectedPilotIds.contains(p.id),
                      activeColor: kCyan,
                      checkColor: kBg,
                      onChanged: (v) => set(() {
                        if (v == true) selectedPilotIds.add(p.id);
                        else selectedPilotIds.remove(p.id);
                      }),
                    );
                  }),

                // ── Piloti non idonei ──
                if (ineligiblePilots.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Container(width: 3, height: 12, color: Colors.white24),
                    const SizedBox(width: 6),
                    Text(
                      'NON IDONEI (${ineligiblePilots.length})',
                      style: const TextStyle(color: Colors.white38, letterSpacing: 2, fontSize: 11),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  ...ineligiblePilots.map((p) {
                    final qualified = isQualified(p);
                    final current   = isCurrent(p);
                    return Opacity(
                      opacity: 0.45,
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.block, color: Colors.white38, size: 18),
                        title: Text(
                          p.callsign != null ? p.callsign! : p.fullName,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        trailing: Wrap(spacing: 4, children: [
                          if (!qualified)
                            _MicroBadge('NON ABILITATO', kNoGo),
                          if (!current)
                            _MicroBadge('NON CURRENT', kWarning),
                        ]),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addPilot() async {
    final auth = ref.read(authProvider);
    final aircraftTypes = auth.aircraftTypes;
    final nomeCtrl     = TextEditingController();
    final cogCtrl      = TextEditingController();
    final callsignCtrl = TextEditingController();
    final usrCtrl      = TextEditingController();
    final pwdCtrl      = TextEditingController();
    final mailCtrl     = TextEditingController();
    final selectedAc   = <int>{};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => _HudDialog(
          title: 'NUOVO PILOTA',
          action: FilledButton(
            onPressed: () async {
              if (cogCtrl.text.isEmpty || nomeCtrl.text.isEmpty ||
                  usrCtrl.text.isEmpty || pwdCtrl.text.isEmpty) return;
              Navigator.of(ctx).pop();
              await _userService.createUser(
                nome: nomeCtrl.text.trim(),
                cognome: cogCtrl.text.trim(),
                callsign: callsignCtrl.text.trim().isEmpty ? null : callsignCtrl.text.trim(),
                username: usrCtrl.text.trim(),
                password: pwdCtrl.text,
                email: mailCtrl.text.isEmpty ? null : mailCtrl.text.trim(),
                aircraftQualificationIds: selectedAc.toList(),
              );
              _load();
            },
            style: FilledButton.styleFrom(backgroundColor: kCyan.withValues(alpha: 0.2)),
            child: const Text('CREA', style: TextStyle(color: kCyan, letterSpacing: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hudTextField(cogCtrl, 'COGNOME *', TextInputType.text),
              const SizedBox(height: 12),
              _hudTextField(nomeCtrl, 'NOME *', TextInputType.text),
              const SizedBox(height: 12),
              _hudTextField(callsignCtrl, 'CALLSIGN', TextInputType.text),
              const SizedBox(height: 12),
              _hudTextField(usrCtrl, 'USERNAME *', TextInputType.text),
              const SizedBox(height: 12),
              _hudTextField(pwdCtrl, 'PASSWORD *', TextInputType.visiblePassword),
              const SizedBox(height: 12),
              _hudTextField(mailCtrl, 'EMAIL', TextInputType.emailAddress),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 3, height: 12, color: kCyan),
                const SizedBox(width: 6),
                Text(
                  'AEROMOBILI ABILITATO',
                  style: TextStyle(color: kCyan, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
                ),
              ]),
              const SizedBox(height: 8),
              ...aircraftTypes.map((a) => CheckboxListTile(
                dense: true,
                title: Row(children: [
                  Text(a.code, style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(a.name, style: const TextStyle(color: Colors.white38, fontSize: 11), overflow: TextOverflow.ellipsis)),
                ]),
                value: selectedAc.contains(a.id),
                activeColor: kCyan,
                checkColor: kBg,
                onChanged: (v) => set(() {
                  if (v == true) selectedAc.add(a.id);
                  else selectedAc.remove(a.id);
                }),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _manageCapabilities(UserProfile pilot) async {
    final auth = ref.read(authProvider);
    final allCaps = auth.capabilityTypes;
    final currentIds = _userService.getPilotCapabilityIds(pilot.id).toSet();
    final selected = Set<int>.from(currentIds);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => _HudDialog(
          title: 'CAPACITÀ — ${pilot.displayName.toUpperCase()}',
          action: FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _userService.updatePilotCapabilities(pilot.id, selected.toList());
              _load();
            },
            style: FilledButton.styleFrom(backgroundColor: kCyan.withValues(alpha: 0.2)),
            child: const Text('SALVA', style: TextStyle(color: kCyan, letterSpacing: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: allCaps.map((cap) => CheckboxListTile(
              dense: true,
              title: Text(cap.code, style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(cap.name, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              value: selected.contains(cap.id),
              activeColor: kCyan,
              checkColor: kBg,
              onChanged: (v) => set(() {
                if (v == true) selected.add(cap.id);
                else selected.remove(cap.id);
              }),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _approvePilot(UserProfile pilot) async {
    await _userService.approveUser(pilot.id);
    _load();
  }

  Future<void> _rejectPilot(UserProfile pilot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _HudDialog(
        title: 'RIFIUTA RICHIESTA',
        action: FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: kNoGo.withValues(alpha: 0.2)),
          child: const Text('RIFIUTA', style: TextStyle(color: kNoGo, letterSpacing: 2)),
        ),
        child: Text(
          'Rifiutare la richiesta di ${pilot.displayName}?',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
    if (confirmed == true) {
      await _userService.rejectUser(pilot.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _userService.getPendingPilots();
    final goCount = _pilots.where((p) => fitnessStatus(p.fitnessExpiry) == PilotStatus.go).length;
    final noGoCount = _pilots.where((p) => fitnessStatus(p.fitnessExpiry) == PilotStatus.noGo).length;
    final warnCount = _pilots.where((p) => fitnessStatus(p.fitnessExpiry) == PilotStatus.warning).length;

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
          child: Column(
            children: [
              // Header
              _buildHeader(goCount, noGoCount, warnCount),
              // Pilot grid
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: kCyan),
                      )
                    : _pilots.isEmpty
                        ? Center(
                            child: Text(
                              'NESSUN PILOTA REGISTRATO',
                              style: TextStyle(color: kCyan.withValues(alpha: 0.5), letterSpacing: 3),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async => _load(),
                            color: kCyan,
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                // Pending approvals
                                if (pending.isNotEmpty) ...[
                                  _SectionHeader(
                                    label: 'IN ATTESA DI APPROVAZIONE',
                                    count: pending.length,
                                    color: kWarning,
                                  ),
                                  const SizedBox(height: 8),
                                  ...pending.map((p) => _PendingCard(
                                    pilot: p,
                                    aircraftTypes: ref.read(authProvider).aircraftTypes,
                                    onApprove: () => _approvePilot(p),
                                    onReject: () => _rejectPilot(p),
                                  )),
                                  const SizedBox(height: 16),
                                  Divider(color: kCyan.withValues(alpha: 0.15)),
                                  const SizedBox(height: 16),
                                ],
                                // Active pilots grid
                                if (_pilots.isNotEmpty) ...[
                                  _SectionHeader(label: 'PILOTI ATTIVI', count: _pilots.length, color: kCyan),
                                  const SizedBox(height: 8),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 340,
                                      childAspectRatio: 1.55,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: _pilots.length,
                                    itemBuilder: (_, i) => _PilotCard(
                                      pilot: _pilots[i],
                                      onEditExpiry: () => _editExpiry(_pilots[i]),
                                      onShowFlights: () => _showFlights(_pilots[i]),
                                      onCapabilities: () => _manageCapabilities(_pilots[i]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'pilot',
            onPressed: _addPilot,
            backgroundColor: kBgCard,
            foregroundColor: kCyan,
            shape: const RoundedRectangleBorder(),
            mini: true,
            child: const Icon(Icons.person_add_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'flight',
            onPressed: _addFlight,
            backgroundColor: kCyan.withValues(alpha: 0.15),
            foregroundColor: kCyan,
            shape: const RoundedRectangleBorder(
              side: BorderSide(color: kCyan, width: 1),
            ),
            icon: const Icon(Icons.flight_takeoff),
            label: const Text('INSERISCI VOLO', style: TextStyle(letterSpacing: 2)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int go, int noGo, int warn) {
    return AnimatedBuilder(
      animation: _headerCtrl,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: kBgCard,
          border: Border(
            bottom: BorderSide(color: kCyan.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            // Logo
            SizedBox(
              width: 36,
              height: 36,
              child: Image.asset(
                'assets/images/aves_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.flight, color: kCyan),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SISTEMA PILOTI',
                    style: TextStyle(
                      color: kCyan,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      shadows: [Shadow(color: kCyan.withValues(alpha: 0.5), blurRadius: 8)],
                    ),
                  ),
                  Text(
                    'DASHBOARD OPERATIVA',
                    style: TextStyle(color: kCyan.withValues(alpha: 0.4), fontSize: 9, letterSpacing: 2),
                  ),
                ],
              ),
            ),
            // Stats
            _StatChip(value: go.toString(), label: 'GO', color: kGo),
            const SizedBox(width: 8),
            _StatChip(value: warn.toString(), label: 'CAU', color: kWarning),
            const SizedBox(width: 8),
            _StatChip(value: noGo.toString(), label: 'N/G', color: kNoGo),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              color: kCyan.withValues(alpha: 0.6),
              onPressed: _load,
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
    );
  }
}

class _StatChip extends StatefulWidget {
  final String value;
  final String label;
  final Color color;

  const _StatChip({required this.value, required this.label, required this.color});

  @override
  State<_StatChip> createState() => _StatChipState();
}

class _StatChipState extends State<_StatChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.color.withValues(alpha: 0.4 + 0.4 * _ctrl.value),
            width: 1.5,
          ),
          color: widget.color.withValues(alpha: 0.06 + 0.06 * _ctrl.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.1 + 0.15 * _ctrl.value),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.value,
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.w900,
                fontSize: 28,
                height: 1,
                shadows: [
                  Shadow(
                    color: widget.color.withValues(alpha: 0.6 + 0.4 * _ctrl.value),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.color.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 3, height: 14, color: color),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: color, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    ],
  );
}

class _PendingCard extends StatelessWidget {
  final UserProfile pilot;
  final List<dynamic> aircraftTypes;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCard({
    required this.pilot,
    required this.aircraftTypes,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final qualCodes = aircraftTypes
        .where((a) => pilot.aircraftQualificationIds.contains(a.id))
        .map((a) => a.code as String)
        .join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBgCard,
        border: Border.all(color: kWarning.withValues(alpha: 0.4)),
      ),
      child: CustomPaint(
        painter: HudCornerPainter(color: kWarning, size: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  pilot.callsign?.toUpperCase() ?? pilot.fullName.toUpperCase(),
                  style: const TextStyle(color: kWarning, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                ),
                const SizedBox(width: 8),
                Text(pilot.fullName, style: TextStyle(color: Colors.white54, fontSize: 12)),
                const Spacer(),
                _ActionBtn(label: 'APPROVA', color: kGo, onTap: onApprove),
                const SizedBox(width: 8),
                _ActionBtn(label: 'RIFIUTA', color: kNoGo, onTap: onReject),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              if (pilot.orgUnitName.isNotEmpty)
                _InfoTag(pilot.orgUnitName.split('"').length > 1
                    ? '"${pilot.orgUnitName.split('"')[1]}"'
                    : pilot.orgUnitName.split('-').first.trim()),
              if (qualCodes.isNotEmpty) _InfoTag(qualCodes),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.6)), color: color.withValues(alpha: 0.1)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
    ),
  );
}

class _InfoTag extends StatelessWidget {
  final String text;
  const _InfoTag(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(border: Border.all(color: kCyan.withValues(alpha: 0.25)), color: kCyan.withValues(alpha: 0.05)),
    child: Text(text, style: TextStyle(color: kCyan.withValues(alpha: 0.7), fontSize: 10), overflow: TextOverflow.ellipsis),
  );
}

class _PilotCard extends StatelessWidget {
  final UserProfile pilot;
  final VoidCallback onEditExpiry;
  final VoidCallback onShowFlights;
  final VoidCallback onCapabilities;

  const _PilotCard({
    required this.pilot,
    required this.onEditExpiry,
    required this.onShowFlights,
    required this.onCapabilities,
  });

  @override
  Widget build(BuildContext context) {
    final status = fitnessStatus(pilot.fitnessExpiry);
    final color = statusColor(status);
    final label = statusLabel(status);

    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(
        painter: HudCornerPainter(color: color, size: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status orb
              GoNoGoOrb(status: status, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pilot.cognome.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      pilot.nome.toUpperCase(),
                      style: TextStyle(color: kCyan.withValues(alpha: 0.7), fontSize: 11, letterSpacing: 1),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _countdown(pilot.fitnessExpiry),
                      style: TextStyle(color: color, fontSize: 10, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _IconBtn(Icons.flight_takeoff, onShowFlights, 'Voli'),
                  _IconBtn(Icons.edit_calendar, onEditExpiry, 'Scadenza'),
                  _IconBtn(Icons.military_tech, onCapabilities, 'Capacità'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _countdown(DateTime? expiry) {
    if (expiry == null) return 'SCADENZA N/D';
    final days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) return 'SCADUTO ${-days}gg FA';
    if (days == 0) return 'SCADE OGGI';
    return 'SCADE TRA ${days}gg';
  }
}

class _MicroBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _MicroBadge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.6)),
      color: color.withValues(alpha: 0.1),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _IconBtn(this.icon, this.onTap, this.tooltip);
  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 16),
    color: kCyan.withValues(alpha: 0.6),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    onPressed: onTap,
    tooltip: tooltip,
  );
}

// ── HUD-styled reusable dialog ───────────────────────────────────────────────

class _HudDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const _HudDialog({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        decoration: BoxDecoration(
          color: kBgCard,
          border: Border.all(color: kCyan.withValues(alpha: 0.4)),
        ),
        child: CustomPaint(
          painter: HudCornerPainter(color: kCyan, size: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: kCyan.withValues(alpha: 0.3))),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kCyan,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    if (action != null) ...[
                      const SizedBox(width: 12),
                      action!,
                    ],
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

// ── HUD reusable form widgets ────────────────────────────────────────────────

Widget _hudTextField(TextEditingController ctrl, String label, TextInputType kbType) {
  return TextField(
    controller: ctrl,
    keyboardType: kbType,
    obscureText: kbType == TextInputType.visiblePassword,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
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
    ),
  );
}

Widget _hudDropdown<T>({
  required String label,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return DropdownButtonFormField<T>(
    value: value,
    items: items,
    onChanged: onChanged,
    dropdownColor: kBgCard,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
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
    ),
  );
}

class _HudTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _HudTile({required this.label, required this.value, required this.icon, this.onTap});

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
            Icon(icon, size: 16, color: kCyan.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: kCyan.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 2)),
            const Spacer(),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 14, color: kCyan.withValues(alpha: 0.4)),
            ],
          ],
        ),
      ),
    );
  }
}
