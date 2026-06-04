import 'dart:math';
import 'package:flutter/material.dart';

const kBg = Color(0xFF060A14);
const kBgCard = Color(0xFF0C1628);
const kCyan = Color(0xFF00CFFF);
const kCyanDim = Color(0xFF003A50);
const kGo = Color(0xFF00FF88);
const kNoGo = Color(0xFFFF2255);
const kWarning = Color(0xFFFFAA00);
const kGrid = Color(0xFF0A1E35);
const kOrange = Color(0xFFFF6600);

class HudGridPainter extends CustomPainter {
  final double scan; // 0..1 animated

  HudGridPainter(this.scan);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = kGrid
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Diagonal accent lines
    final diagPaint = Paint()
      ..color = kCyan.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (double i = -size.height; i < size.width; i += 80) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        diagPaint,
      );
    }

    // Scan line
    final scanY = scan * (size.height + 120) - 60;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          kCyan.withValues(alpha: 0),
          kCyan.withValues(alpha: 0.15),
          kCyan.withValues(alpha: 0.06),
          kCyan.withValues(alpha: 0),
        ],
        stops: const [0, 0.4, 0.7, 1],
      ).createShader(
        Rect.fromLTWH(0, scanY - 60, size.width, 120),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 60, size.width, 120),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(HudGridPainter old) => old.scan != scan;
}

class HudCornerPainter extends CustomPainter {
  final Color color;
  final double size;

  HudCornerPainter({required this.color, this.size = 20});

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final l = size;
    // top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, 0)
        ..lineTo(l, 0),
      paint,
    );
    // top-right
    canvas.drawPath(
      Path()
        ..moveTo(s.width - l, 0)
        ..lineTo(s.width, 0)
        ..lineTo(s.width, l),
      paint,
    );
    // bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, s.height - l)
        ..lineTo(0, s.height)
        ..lineTo(l, s.height),
      paint,
    );
    // bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(s.width - l, s.height)
        ..lineTo(s.width, s.height)
        ..lineTo(s.width, s.height - l),
      paint,
    );
  }

  @override
  bool shouldRepaint(HudCornerPainter old) => false;
}

class HexRingPainter extends CustomPainter {
  final Color color;
  final double progress;

  HexRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(cx, cy) - 4;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.3 + 0.7 * progress)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = pi / 3 * i - pi / 6;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HexRingPainter old) => old.progress != progress;
}
