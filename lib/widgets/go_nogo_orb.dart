import 'package:flutter/material.dart';
import 'hud_painters.dart';

enum PilotStatus { go, noGo, warning, noData }

PilotStatus fitnessStatus(DateTime? expiry) {
  if (expiry == null) return PilotStatus.noData;
  final days = expiry.difference(DateTime.now()).inDays;
  if (days < 0) return PilotStatus.noGo;
  if (days <= 60) return PilotStatus.warning;
  return PilotStatus.go;
}

Color statusColor(PilotStatus s) => switch (s) {
  PilotStatus.go => kGo,
  PilotStatus.noGo => kNoGo,
  PilotStatus.warning => kWarning,
  PilotStatus.noData => Colors.grey,
};

String statusLabel(PilotStatus s) => switch (s) {
  PilotStatus.go => 'GO',
  PilotStatus.noGo => 'NO GO',
  PilotStatus.warning => 'CAUTION',
  PilotStatus.noData => 'N/D',
};

class GoNoGoOrb extends StatefulWidget {
  final PilotStatus status;
  final double size;

  const GoNoGoOrb({super.key, required this.status, this.size = 64});

  @override
  State<GoNoGoOrb> createState() => _GoNoGoOrbState();
}

class _GoNoGoOrbState extends State<GoNoGoOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor(widget.status);
    final label = statusLabel(widget.status);
    final s = widget.size;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => SizedBox(
        width: s,
        height: s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(
                      alpha: 0.15 + 0.25 * _pulse.value,
                    ),
                    blurRadius: 20 + 10 * _pulse.value,
                    spreadRadius: 4 + 6 * _pulse.value,
                  ),
                ],
              ),
            ),
            // Hex ring
            CustomPaint(
              size: Size(s, s),
              painter: HexRingPainter(color: color, progress: _pulse.value),
            ),
            // Inner circle
            Container(
              width: s * 0.68,
              height: s * 0.68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(
                  color: color.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: s * 0.16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniStatusDot extends StatefulWidget {
  final PilotStatus status;

  const MiniStatusDot({super.key, required this.status});

  @override
  State<MiniStatusDot> createState() => _MiniStatusDotState();
}

class _MiniStatusDotState extends State<MiniStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor(widget.status);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4 + 0.5 * _ctrl.value),
              blurRadius: 6 + 4 * _ctrl.value,
              spreadRadius: 1 + 2 * _ctrl.value,
            ),
          ],
        ),
      ),
    );
  }
}
