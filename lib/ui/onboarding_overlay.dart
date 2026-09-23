import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/light_element.dart';
import '../domain/pyramid_geometry.dart';

const onboardingHaiku =
    'No video game.\n'
    'Just bespoke lamps trapped in glass.\n'
    'Glowing pyramids.';

const onboardingHaikuFadeDuration = Duration(milliseconds: 1500);

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
    this.transformTarget,
  });

  final Animation<double> animation;
  final double logicalPixelsPerMm;
  final PyramidGeometryProfile geometry;
  final bool showHaiku;
  final bool showTapTap;
  final LightElement? tipTarget;
  final LightElement? hollowTarget;
  final LightElement? transformTarget;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AnimatedOpacity(
            opacity: showHaiku ? 1 : 0,
            duration: onboardingHaikuFadeDuration,
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
                    transformTarget: transformTarget,
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
    this.transformTarget,
  });

  final double logicalPixelsPerMm;
  final PyramidGeometryProfile geometry;
  final double phase;
  final LightElement? tipTarget;
  final LightElement? hollowTarget;
  final LightElement? transformTarget;

  double get _drawProgress => (phase / 0.68).clamp(0.0, 1.0).toDouble();

  double get _hollowDrawProgress =>
      (phase / 0.42).clamp(0.0, 1.0).toDouble();

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
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final tip = tipTarget;
    if (tip != null) _paintTipHint(canvas, size, tip);

    final hollow = hollowTarget;
    if (hollow != null) _paintHollowHint(canvas, hollow);

    final transform = transformTarget;
    if (transform != null) _paintTransformHint(canvas, transform);
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
    _paintArrowHead(canvas, end, direction, base * 0.18);
  }

  Offset _ellipsePoint(
    Offset center,
    double radiusX,
    double radiusY,
    double rotation,
    double angle,
  ) {
    final x = radiusX * math.cos(angle);
    final y = radiusY * math.sin(angle);
    final cosR = math.cos(rotation);
    final sinR = math.sin(rotation);
    return center + Offset(x * cosR - y * sinR, x * sinR + y * cosR);
  }

  Offset _ellipseTangent(
    double radiusX,
    double radiusY,
    double rotation,
    double angle,
  ) {
    final x = -radiusX * math.sin(angle);
    final y = radiusY * math.cos(angle);
    final cosR = math.cos(rotation);
    final sinR = math.sin(rotation);
    final rotated = Offset(x * cosR - y * sinR, x * sinR + y * cosR);
    final length = rotated.distance;
    return length <= 0.001 ? const Offset(1, 0) : rotated / length;
  }

  void _paintHollowHint(Canvas canvas, LightElement element) {
    final center = _center(element);
    final base = geometry.baseMm(element.size) * logicalPixelsPerMm;
    final radiusX = base * 0.92;
    final radiusY = base * 0.70;
    const rotation = -math.pi / 9;
    const startAngle = -math.pi * 0.72;
    final progress = _hollowDrawProgress;
    if (progress <= 0) return;

    final path = Path();
    const fullSteps = 48;
    final steps = math.max(2, (fullSteps * progress).ceil());
    for (var index = 0; index <= steps; index += 1) {
      final fraction = progress * index / steps;
      final angle = startAngle + math.pi * 2 * fraction;
      final point = _ellipsePoint(
        center,
        radiusX,
        radiusY,
        rotation,
        angle,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, _paint);

    final endAngle = startAngle + math.pi * 2 * progress;
    final end = _ellipsePoint(center, radiusX, radiusY, rotation, endAngle);
    final tangent = _ellipseTangent(radiusX, radiusY, rotation, endAngle);
    _paintArrowHead(canvas, end, tangent, base * 0.16);
  }

  void _paintTransformHint(Canvas canvas, LightElement element) {
    final center = _center(element);
    final base = geometry.baseMm(element.size) * logicalPixelsPerMm;

    final moveProgress = Curves.easeInOut.transform(
      (phase / 0.48).clamp(0.0, 1.0).toDouble(),
    );
    final twistProgress = Curves.easeInOut.transform(
      ((phase - 0.34) / 0.44).clamp(0.0, 1.0).toDouble(),
    );
    final localAlpha = phase <= 0.84
        ? 1.0
        : ((1 - phase) / 0.16).clamp(0.0, 1.0).toDouble();

    final start = center + Offset(-base * 0.24, base * 0.12);
    final finish = center + Offset(base * 0.22, -base * 0.08);
    final midpoint = Offset.lerp(start, finish, moveProgress)!;
    final angle = math.pi * 0.24 + twistProgress * math.pi * 0.24;
    final halfSeparation = base * 0.24;
    final axis = Offset(math.cos(angle), math.sin(angle)) * halfSeparation;
    final dotRadius = math.max(4.0, base * 0.10);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30 * localAlpha);

    canvas.drawCircle(midpoint + axis, dotRadius, paint);
    canvas.drawCircle(midpoint - axis, dotRadius, paint);
  }

  void _paintArrowHead(
    Canvas canvas,
    Offset tip,
    Offset direction,
    double requestedLength,
  ) {
    final length = math.max(6.0, requestedLength);
    final magnitude = direction.distance;
    final unit = magnitude <= 0.001 ? const Offset(1, 0) : direction / magnitude;
    final normal = Offset(-unit.dy, unit.dx);
    final back = tip - unit * length;
    final halfWidth = length * 0.48;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        back.dx + normal.dx * halfWidth,
        back.dy + normal.dy * halfWidth,
      )
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        back.dx - normal.dx * halfWidth,
        back.dy - normal.dy * halfWidth,
      );
    canvas.drawPath(path, _paint);
  }

  @override
  bool shouldRepaint(covariant OnboardingGesturePainter oldDelegate) =>
      oldDelegate.logicalPixelsPerMm != logicalPixelsPerMm ||
      oldDelegate.geometry != geometry ||
      oldDelegate.phase != phase ||
      oldDelegate.tipTarget != tipTarget ||
      oldDelegate.hollowTarget != hollowTarget ||
      oldDelegate.transformTarget != transformTarget;
}
