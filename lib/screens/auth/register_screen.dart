import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/hud_painters.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _callsignCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _cogCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  int? _orgUnitId;
  String _orgUnitName = '';
  final Set<int> _selectedAircraft = {};
  bool _obscure = true;
  bool _saving = false;
  String? _error;
  int _step = 0; // 0=identità, 1=reparto+aeromobili, 2=credenziali

  late AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _ensureDbInit();
  }

  Future<void> _ensureDbInit() async {
    await ref.read(authProvider).initDb();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _callsignCtrl.dispose();
    _nomeCtrl.dispose();
    _cogCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _validateStep() {
    setState(() => _error = null);
    if (_step == 0) {
      if (_callsignCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Inserisci il tuo callsign');
        return false;
      }
      if (_nomeCtrl.text.trim().isEmpty || _cogCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Nome e cognome obbligatori');
        return false;
      }
    }
    if (_step == 1) {
      if (_orgUnitId == null) {
        setState(() => _error = 'Seleziona il reparto');
        return false;
      }
      if (_selectedAircraft.isEmpty) {
        setState(() => _error = 'Seleziona almeno un aeromobile');
        return false;
      }
    }
    if (_step == 2) {
      if (_usernameCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Username obbligatorio');
        return false;
      }
      if (_passCtrl.text.length < 6) {
        setState(() => _error = 'Password minimo 6 caratteri');
        return false;
      }
      if (_passCtrl.text != _pass2Ctrl.text) {
        setState(() => _error = 'Le password non coincidono');
        return false;
      }
    }
    return true;
  }

  Future<void> _register() async {
    if (!_validateStep()) return;
    final userService = UserService();
    if (userService.usernameExists(_usernameCtrl.text.trim())) {
      setState(() => _error = 'Username già in uso');
      return;
    }
    setState(() => _saving = true);
    try {
      await userService.registerUser(
        nome: _nomeCtrl.text.trim(),
        cognome: _cogCtrl.text.trim(),
        callsign: _callsignCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passCtrl.text,
        email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text.trim(),
        orgUnitId: _orgUnitId,
        orgUnitName: _orgUnitName,
        aircraftQualificationIds: _selectedAircraft.toList(),
      );
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => _SuccessDialog(callsign: _callsignCtrl.text.trim()),
        );
        if (mounted) context.go('/login');
      }
    } catch (e) {
      setState(() => _error = 'Errore: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final aircraftTypes = auth.aircraftTypes;
    final orgUnits = auth.orgUnits;

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 16),
                          color: kCyan,
                          onPressed: () => _step > 0
                              ? setState(() => _step--)
                              : context.go('/login'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'REGISTRAZIONE PILOTA',
                                style: TextStyle(
                                  color: kCyan,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                  shadows: [Shadow(color: kCyan.withValues(alpha: 0.5), blurRadius: 8)],
                                ),
                              ),
                              Text(
                                'PASSO ${_step + 1} DI 3',
                                style: TextStyle(color: kCyan.withValues(alpha: 0.4), fontSize: 9, letterSpacing: 2),
                              ),
                            ],
                          ),
                        ),
                        // Step indicators
                        Row(
                          children: List.generate(3, (i) => Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: i == _step ? 20 : 8,
                            height: 4,
                            color: i <= _step ? kCyan : kCyan.withValues(alpha: 0.2),
                          )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Card
                    CustomPaint(
                      painter: HudCornerPainter(color: kCyan, size: 14),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: kBgCard.withValues(alpha: 0.95),
                          border: Border.all(color: kCyan.withValues(alpha: 0.2)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _step == 0
                              ? _buildStep0()
                              : _step == 1
                                  ? _buildStep1(aircraftTypes, orgUnits)
                                  : _buildStep2(),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber, color: kNoGo, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: kNoGo, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () {
                                if (!_validateStep()) return;
                                if (_step < 2) {
                                  setState(() => _step++);
                                } else {
                                  _register();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kCyan.withValues(alpha: 0.15),
                          foregroundColor: kCyan,
                          side: const BorderSide(color: kCyan),
                          shape: const RoundedRectangleBorder(),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kCyan),
                              )
                            : Text(
                                _step < 2 ? 'AVANTI ›' : 'INVIA RICHIESTA',
                                style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // STEP 0 — Identità
  Widget _buildStep0() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('IDENTITÀ DI VOLO'),
        const SizedBox(height: 16),
        _hudField(
          _callsignCtrl,
          'CALLSIGN *',
          hint: 'es. Maverick, Ghost, Ice...',
          icon: Icons.tag,
        ),
        const SizedBox(height: 4),
        Text(
          'Il tuo nome di battaglia univoco',
          style: TextStyle(color: kCyan.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 1),
        ),
        const SizedBox(height: 16),
        _hudField(_cogCtrl, 'COGNOME *', icon: Icons.person_outline),
        const SizedBox(height: 12),
        _hudField(_nomeCtrl, 'NOME *', icon: Icons.person_outline),
        const SizedBox(height: 12),
        _hudField(
          _emailCtrl,
          'EMAIL (opzionale)',
          icon: Icons.email_outlined,
          type: TextInputType.emailAddress,
        ),
      ],
    );
  }

  // STEP 1 — Reparto + Aeromobili
  Widget _buildStep1(aircraftTypes, orgUnits) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('REPARTO & QUALIFICHE'),
        const SizedBox(height: 16),
        // Reparto dropdown
        DropdownButtonFormField<int>(
          value: _orgUnitId,
          dropdownColor: kBgCard,
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _dec('REPARTO *'),
          items: orgUnits
              .map<DropdownMenuItem<int>>(
                (u) => DropdownMenuItem(
                  value: u.id,
                  child: Text(u.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) {
            final unit = orgUnits.firstWhere((u) => u.id == v);
            setState(() {
              _orgUnitId = v;
              _orgUnitName = unit.name;
            });
          },
        ),
        const SizedBox(height: 20),
        _sectionLabel('AEROMOBILI ABILITATO *'),
        const SizedBox(height: 8),
        ...aircraftTypes.map<Widget>(
          (a) => _HudCheckTile(
            label: a.code,
            subtitle: a.name,
            value: _selectedAircraft.contains(a.id),
            onChanged: (v) => setState(() {
              if (v) _selectedAircraft.add(a.id);
              else _selectedAircraft.remove(a.id);
            }),
          ),
        ),
      ],
    );
  }

  // STEP 2 — Credenziali
  Widget _buildStep2() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CREDENZIALI DI ACCESSO'),
        const SizedBox(height: 16),
        _hudField(
          _usernameCtrl,
          'USERNAME *',
          hint: 'Identificativo univoco di login',
          icon: Icons.alternate_email,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          style: const TextStyle(color: Colors.white),
          decoration: _dec('PASSWORD *').copyWith(
            prefixIcon: Icon(Icons.lock_outline, color: kCyan.withValues(alpha: 0.6), size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                color: kCyan.withValues(alpha: 0.5),
                size: 18,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass2Ctrl,
          obscureText: _obscure,
          style: const TextStyle(color: Colors.white),
          decoration: _dec('CONFERMA PASSWORD *').copyWith(
            prefixIcon: Icon(Icons.lock_outline, color: kCyan.withValues(alpha: 0.6), size: 18),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: kWarning.withValues(alpha: 0.4)),
            color: kWarning.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: kWarning, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La richiesta sarà revisionata dall\'amministratore. '
                  'Riceverai accesso una volta approvato.',
                  style: TextStyle(color: kWarning.withValues(alpha: 0.8), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(color: kCyan.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.bold),
  );

  Widget _hudField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    IconData? icon,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: _dec(label, hint: hint).copyWith(
        prefixIcon: icon != null
            ? Icon(icon, color: kCyan.withValues(alpha: 0.6), size: 18)
            : null,
      ),
    );
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
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
}

class _HudCheckTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _HudCheckTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: value ? kCyan.withValues(alpha: 0.6) : kCyan.withValues(alpha: 0.15),
          ),
          color: value ? kCyan.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                border: Border.all(color: value ? kCyan : kCyan.withValues(alpha: 0.3)),
                color: value ? kCyan.withValues(alpha: 0.2) : Colors.transparent,
              ),
              child: value
                  ? const Icon(Icons.check, size: 12, color: kCyan)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: value ? kCyan : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(color: Colors.white38, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final String callsign;
  const _SuccessDialog({required this.callsign});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: kBgCard,
          border: Border.all(color: kGo.withValues(alpha: 0.5)),
        ),
        child: CustomPaint(
          painter: HudCornerPainter(color: kGo, size: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: kGo, size: 48),
              const SizedBox(height: 16),
              Text(
                'RICHIESTA INVIATA',
                style: TextStyle(
                  color: kGo,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  shadows: [Shadow(color: kGo.withValues(alpha: 0.5), blurRadius: 8)],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Callsign: $callsign',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'La tua richiesta è in attesa di approvazione.\nAttendi il via libera dall\'amministratore.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGo.withValues(alpha: 0.15),
                  foregroundColor: kGo,
                  side: BorderSide(color: kGo.withValues(alpha: 0.5)),
                  shape: const RoundedRectangleBorder(),
                ),
                child: const Text('OK', style: TextStyle(letterSpacing: 3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
