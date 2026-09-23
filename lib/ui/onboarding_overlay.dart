import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/light_element.dart';
import '../domain/pyramid_geometry.dart';

const onboardingHaiku =
    'No video game.\n'
    'Just bespoke lamps trapped in glass.\n'
    'Glowing pyramids.';

class OnboardingOverlay extends StatelessWidget {
  const OnboardingOverlay({
    super.key,
    required this.animation,
    required this.logicalPixelsPerMm,
    required this.geometry,
    required this.showHaiku,
    required this.showTapTap,
    this.tipTarget,
    this.hollowTarget,
  });

  final Animation<double> animation;
  final double logicalPixelsPerMm;
  final PyramidGeometryProfile geometry;
  final bool showHaiku;
  final bool showTapTap;
  final LightElement? tipTarget;
  final LightElement? hollowTarget;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AnimatedOpacity(
            opacity: showHaiku ? 1 : 0,
            duration: const Duration(seconds: 3),
            curve: Curves.easeOut,
            child: const Text(
              onboardingHaiku,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 19,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final phase = animation.value;
            final tapOpacity = showTapTap
                ? 0.18 + 0.58 * (0.5 - 0.5 * math.cos(phase * math.pi * 2))
                : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: OnboardingGesturePainter(
                    logicalPixelsPerMm: logicalPixelsPerMm,
                    geometry: geometry,
                    phase: phase,
                    tipTarget: tipTarget,
                    hollowTarget: hollowTarget,
                  ),
                ),
                if (showTapTap)
                  Center(
                    child: Opacity(
                      opacity: tapOpacity,
                      child: const Text(
                        'Tap. Tap.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class OnboardingGesturePainter extends CustomPainter {
  const OnboardingGesturePainter({
    required this.logicalPixelsPerMm,
    required this.geometry,
    required this.phase,
    this.tipTarget,
    this.hollowTarget,
  });

  final double logicalPixelsPerMm;
  final PyramidGeometryProfile geometry;
  final double phase;
  final LightElement? tipTarget;
  final LightElement? hollowTarget;

  double get _drawProgress => (phase / 0.68).clamp(0.0, 1.0).toDouble();

  double get _alpha {
    if (phase <= 0.82) return 1;
    return ((1 - phase) / 0.18).clamp(0.0, 1.0).toDouble();
  }

  Offset _center(LightElement element) => Offset(
    element.position.xMm * logicalPixelsPerMm,
    element.position.yMm * logicalPixelsPerMm,
  );

  Paint get _paint => Paint()
    ..color = Colors.white.withValues(alpha: 0.38 * _alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.4, logicalPixelsPerMm * 0.48)
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final tip = tipTarget;
    if (tip != null) _paintTipHint(canvas, size, tip);

    final hollow = hollowTarget;
    if (hollow != null) _paintHollowHint(canvas, hollow);
  }

  void _paintTipHint(Canvas canvas, Size size, LightElement element) {
    final center = _center(element);
    final base = geometry.baseMm(element.size) * logicalPixelsPerMm;
    final direction = center.dx < size.width * 0.62
        ? const Offset(1, 0)
        : const Offset(-1, 0);
    final fullEnd = center + direction * (base * 0.92);
    final end = Offset.lerp(center, fullEnd, _drawProgress)!;
    canvas.drawLine(center, end, _paint);

    if (_drawProgress < 0.42) return;
    final angle = math.atan2(direction.dy, direction.dx);
    final arrowLength = math.max(6.0, base * 0.18);
    final arrowWidth = arrowLength * 0.48;
    final back = end - Offset(math.cos(angle), math.sin(angle)) * arrowLength;
    final normal = Offset(-math.sin(angle), math.cos(angle));
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        back.dx + normal.dx * arrowWidth,
        back.dy + normal.dy * arrowWidth,
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        back.dx - normal.dx * arrowWidth,
        back.dy - normal.dy * arrowWidth,
      );
    canvas.drawPath(path, _paint);
  }

  void _paintHollowHint(Canvas canvas, LightElement element) {
    final center = _center(element);
    final base = geometry.baseMm(element.size) * logicalPixelsPerMm;
    final radius = base * 0.82;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * _drawProgress,
      false,
      _paint,
    );
  }

  @override
  bool shouldRepaint(covariant OnboardingGesturePainter oldDelegate) =>
      oldDelegate.logicalPixelsPerMm != logicalPixelsPerMm ||
      oldDelegate.geometry != geometry ||
      oldDelegate.phase != phase ||
      oldDelegate.tipTarget != tipTarget ||
      oldDelegate.hollowTarget != hollowTarget;
}
