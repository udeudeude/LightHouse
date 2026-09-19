import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/remote_control_state.dart';
import '../domain/light_element.dart';

class RippleOverlayPainter extends CustomPainter {
  const RippleOverlayPainter({
    required this.elements,
    required this.levels,
    required this.logicalPixelsPerMm,
    required this.phaseSeconds,
  });

  final List<LightElement> elements;
  final Map<String, RemoteRippleLevel> levels;
  final double logicalPixelsPerMm;
  final double phaseSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    const period = 1.18;
    final t = (phaseSeconds % period) / period;
    final fade = math.pow(1 - t, 2).toDouble();

    for (final element in elements) {
      final level = levels[element.id];
      if (level == null) continue;
      final normal = level == RemoteRippleLevel.normal;
      final startMm = normal ? 2.4 : 1.7;
      final travelMm = normal ? 5.2 : 3.4;
      final alpha = (normal ? 0.42 : 0.20) * fade;
      final center = Offset(
        element.position.xMm * logicalPixelsPerMm,
        element.position.yMm * logicalPixelsPerMm,
      );
      canvas.drawCircle(
        center,
        (startMm + travelMm * t) * logicalPixelsPerMm,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = normal ? 1.25 : 0.85,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RippleOverlayPainter oldDelegate) =>
      oldDelegate.elements != elements ||
      oldDelegate.levels != levels ||
      oldDelegate.logicalPixelsPerMm != logicalPixelsPerMm ||
      oldDelegate.phaseSeconds != phaseSeconds;
}
