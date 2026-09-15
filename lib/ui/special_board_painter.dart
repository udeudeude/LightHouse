import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/board_underlay.dart';

class SpecialBoardPainter {
  const SpecialBoardPainter(this.logicalPixelsPerMm);

  final double logicalPixelsPerMm;

  Paint _linePaint([double opacity = 0.32]) => Paint()
    ..color = Colors.white.withValues(alpha: opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.7, logicalPixelsPerMm * 0.18);

  void paintSandships(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final cityCentersMm = BoardUnderlay.sandships.snapPoints(
      boardWidthMm: size.width / logicalPixelsPerMm,
      boardHeightMm: size.height / logicalPixelsPerMm,
    );
    final cityCenters = [
      for (final point in cityCentersMm)
        Offset(point.xMm * logicalPixelsPerMm, point.yMm * logicalPixelsPerMm),
    ];
    final cityRadius = 15.0 * logicalPixelsPerMm;
    final boardRadius = math.min(size.width, size.height) * 0.47;

    // The published board has a central city, four corner cities and eight
    // wasteland zones. Canals radiate between the zones; ports open from each
    // city into the neighboring zones.
    final canal = _linePaint(0.30);
    for (var i = 0; i < 8; i += 1) {
      final angle = math.pi / 8 + i * math.pi / 4;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * cityRadius,
        center + direction * boardRadius,
        canal,
      );
    }

    void paintPort(Offset cityCenter, double angle) {
      final direction = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-direction.dy, direction.dx);
      final tip = cityCenter + direction * cityRadius * 1.02;
      final base = cityCenter + direction * cityRadius * 0.70;
      final half = 3.2 * logicalPixelsPerMm;
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base.dx + normal.dx * half, base.dy + normal.dy * half)
        ..lineTo(base.dx - normal.dx * half, base.dy - normal.dy * half)
        ..close();
      canvas.drawPath(path, _linePaint(0.46));
    }

    for (var city = 0; city < cityCenters.length; city += 1) {
      final cityCenter = cityCenters[city];
      canvas.drawCircle(
        cityCenter,
        cityRadius,
        _linePaint(city == 0 ? 0.66 : 0.52),
      );
      if (city == 0) {
        for (var port = 0; port < 8; port += 1) {
          paintPort(cityCenter, port * math.pi / 4);
        }
      } else {
        final inward = math.atan2(
          center.dy - cityCenter.dy,
          center.dx - cityCenter.dx,
        );
        for (final offset in const [-math.pi / 4, 0.0, math.pi / 4]) {
          paintPort(cityCenter, inward + offset);
        }
      }
    }
  }

  void paintMartianBackgammon(Canvas canvas, Size size) {
    final cell = BoardUnderlay.cellMm * logicalPixelsPerMm;
    final width = cell * 5;
    final height = cell * 5;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2;
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.38);
    final dotRadius = math.max(0.7, logicalPixelsPerMm * 0.23);
    final dotStep = math.max(4.0, logicalPixelsPerMm * 1.7);

    void dottedLine(Offset a, Offset b) {
      final distance = (b - a).distance;
      final count = math.max(1, (distance / dotStep).round());
      for (var i = 0; i <= count; i += 1) {
        final t = i / count;
        canvas.drawCircle(Offset.lerp(a, b, t)!, dotRadius, dotPaint);
      }
    }

    for (var column = 0; column <= 5; column += 1) {
      final x = left + column * cell;
      dottedLine(Offset(x, top), Offset(x, top + height));
    }
    for (var row = 0; row <= 5; row += 1) {
      final y = top + row * cell;
      dottedLine(Offset(left, y), Offset(left + width, y));
    }

    final blockers = Paint()..color = Colors.white.withValues(alpha: 0.48);
    for (var column = 1; column <= 3; column += 1) {
      canvas.drawRect(
        Rect.fromLTWH(
          left + column * cell + cell * 0.17,
          top + 2 * cell + cell * 0.17,
          cell * 0.66,
          cell * 0.66,
        ),
        blockers,
      );
    }

    final dark = Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final light = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Match the supplied reference: two opposed rounded tracks weave around
    // the three central blocks, each starting at a circle and ending in an
    // arrowhead.
    final darkStart = Offset(left + cell * 0.48, top + cell * 3.55);
    final darkPath = Path()
      ..moveTo(darkStart.dx, darkStart.dy)
      ..lineTo(left + cell * 4.30, darkStart.dy)
      ..cubicTo(
        left + cell * 4.72,
        darkStart.dy,
        left + cell * 4.66,
        top + cell * 1.65,
        left + cell * 4.25,
        top + cell * 1.65,
      )
      ..lineTo(left + cell * 0.88, top + cell * 1.65)
      ..cubicTo(
        left + cell * 0.40,
        top + cell * 1.65,
        left + cell * 0.34,
        top + cell * 0.75,
        left + cell * 0.42,
        top + cell * 0.38,
      );
    canvas.drawPath(darkPath, dark);
    canvas.drawCircle(
      darkStart,
      cell * 0.13,
      Paint()..color = Colors.white.withValues(alpha: 0.62),
    );

    final lightStart = Offset(left + cell * 4.55, top + cell * 1.35);
    final lightPath = Path()
      ..moveTo(lightStart.dx, lightStart.dy)
      ..lineTo(left + cell * 0.78, lightStart.dy)
      ..cubicTo(
        left + cell * 0.31,
        lightStart.dy,
        left + cell * 0.30,
        top + cell * 3.35,
        left + cell * 0.76,
        top + cell * 3.35,
      )
      ..lineTo(left + cell * 4.16, top + cell * 3.35)
      ..cubicTo(
        left + cell * 4.60,
        top + cell * 3.35,
        left + cell * 4.64,
        top + cell * 4.35,
        left + cell * 4.60,
        top + cell * 4.62,
      );
    canvas.drawPath(lightPath, light);
    canvas.drawCircle(
      lightStart,
      cell * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.34),
    );

    void arrow(Offset tip, double angle, Paint paint) {
      final length = cell * 0.34;
      final half = cell * 0.20;
      final back = tip - Offset(math.cos(angle), math.sin(angle)) * length;
      final normal = Offset(-math.sin(angle), math.cos(angle));
      final arrowPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(back.dx + normal.dx * half, back.dy + normal.dy * half)
        ..lineTo(back.dx - normal.dx * half, back.dy - normal.dy * half)
        ..close();
      canvas.drawPath(arrowPath, Paint()..color = paint.color);
    }

    arrow(Offset(left + cell * 0.42, top + cell * 0.16), -math.pi / 2, dark);
    arrow(Offset(left + cell * 4.60, top + cell * 4.84), math.pi / 2, light);

    void cornerTriangle(Offset triangleCenter, bool pointsDown) {
      final radius = cell * 0.20;
      final initialAngle = pointsDown ? math.pi / 2 : -math.pi / 2;
      final triangle = Path();
      for (var i = 0; i < 3; i += 1) {
        final angle = initialAngle + i * 2 * math.pi / 3;
        final point =
            triangleCenter + Offset(math.cos(angle), math.sin(angle)) * radius;
        if (i == 0) {
          triangle.moveTo(point.dx, point.dy);
        } else {
          triangle.lineTo(point.dx, point.dy);
        }
      }
      triangle.close();
      canvas.drawPath(triangle, _linePaint(0.46));
    }

    cornerTriangle(Offset(left + cell * 4.55, top + cell * 0.45), true);
    cornerTriangle(Offset(left + cell * 0.55, top + cell * 4.55), false);
  }
}
