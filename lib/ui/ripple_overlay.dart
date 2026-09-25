import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/remote_control_state.dart';
import '../domain/convex_geometry.dart';
import '../domain/light_element.dart';
import '../domain/physical_point.dart';
import '../domain/pyramid_geometry.dart';

const remoteRipplePeriodSeconds = 2.25;
const remoteRippleNormalTravelMm = 16.0;
const remoteRippleDimTravelMm = 10.4;
const remoteRippleNormalAlpha = 0.78;
const remoteRippleDimAlpha = 0.42;
const remoteRippleFadePower = 1.25;

class RippleOverlayPainter extends CustomPainter {
  const RippleOverlayPainter({
    required this.elements,
    required this.levels,
    required this.logicalPixelsPerMm,
    required this.phaseSeconds,
    required this.geometry,
  });

  final List<LightElement> elements;
  final Map<String, RemoteRippleLevel> levels;
  final double logicalPixelsPerMm;
  final double phaseSeconds;
  final PyramidGeometryProfile geometry;

  Offset _px(PhysicalPoint point) =>
      Offset(point.xMm * logicalPixelsPerMm, point.yMm * logicalPixelsPerMm);

  Path _expandedPerimeter(LightElement element, double expansionMm) {
    final polygon = polygonForElement(element, geometry);
    final center = element.position;
    final path = Path();
    for (var i = 0; i < polygon.length; i += 1) {
      final point = polygon[i];
      final dx = point.xMm - center.xMm;
      final dy = point.yMm - center.yMm;
      final length = math.sqrt(dx * dx + dy * dy);
      final expanded = length <= 0.0001
          ? point
          : PhysicalPoint(
              point.xMm + dx / length * expansionMm,
              point.yMm + dy / length * expansionMm,
            );
      final pixel = _px(expanded);
      if (i == 0) {
        path.moveTo(pixel.dx, pixel.dy);
      } else {
        path.lineTo(pixel.dx, pixel.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final t =
        (phaseSeconds % remoteRipplePeriodSeconds) /
        remoteRipplePeriodSeconds;
    final fade = math.pow(1 - t, remoteRippleFadePower).toDouble();

    for (final element in elements) {
      final level = levels[element.id];
      if (level == null) continue;
      final normal = level == RemoteRippleLevel.normal;
      final travelMm = normal
          ? remoteRippleNormalTravelMm
          : remoteRippleDimTravelMm;
      final alpha =
          (normal ? remoteRippleNormalAlpha : remoteRippleDimAlpha) * fade;
      canvas.drawPath(
        _expandedPerimeter(element, travelMm * t),
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = normal ? 1.6 : 1.0
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RippleOverlayPainter oldDelegate) =>
      oldDelegate.elements != elements ||
      oldDelegate.levels != levels ||
      oldDelegate.logicalPixelsPerMm != logicalPixelsPerMm ||
      oldDelegate.phaseSeconds != phaseSeconds ||
      oldDelegate.geometry != geometry;
}
