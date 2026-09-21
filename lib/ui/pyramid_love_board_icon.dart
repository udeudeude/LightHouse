import 'dart:math' as math;

import 'package:flutter/material.dart';

enum PyramidLoveBoardIconKind {
  wheel,
  launchpad,
  ludo,
  petal,
  volcano,
  worldWar,
  twinWin,
  martianChess,
  lunar,
}

/// Compact board marks redrawn from the corresponding Pyramid Love 3.1
/// component SVGs. They intentionally remain native Canvas geometry so the
/// menu does not depend on an SVG renderer at runtime.
class PyramidLoveBoardIcon extends StatelessWidget {
  const PyramidLoveBoardIcon(
    this.kind, {
    super.key,
    this.size = 19,
    this.color,
  });

  final PyramidLoveBoardIconKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _PyramidLoveBoardIconPainter(
        kind,
        color ?? IconTheme.of(context).color ?? Colors.white,
      ),
    ),
  );
}

class _PyramidLoveBoardIconPainter extends CustomPainter {
  const _PyramidLoveBoardIconPainter(this.kind, this.color);

  final PyramidLoveBoardIconKind kind;
  final Color color;

  Paint get _stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.35
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get _fill => Paint()..color = color;

  Offset _polar(Offset center, double radius, double angle) =>
      center + Offset(math.cos(angle), math.sin(angle)) * radius;

  Path _regularPolygon(
    Offset center,
    double radius,
    int sides, {
    double start = -math.pi / 2,
  }) {
    final path = Path();
    for (var i = 0; i < sides; i += 1) {
      final point = _polar(center, radius, start + i * 2 * math.pi / sides);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale, scale);
    switch (kind) {
      case PyramidLoveBoardIconKind.wheel:
        _paintWheel(canvas);
      case PyramidLoveBoardIconKind.launchpad:
        _paintGrid(canvas, 3, 3, accentCorners: true);
      case PyramidLoveBoardIconKind.ludo:
        _paintGrid(canvas, 3, 3, centerDot: true);
      case PyramidLoveBoardIconKind.petal:
        _paintPetal(canvas);
      case PyramidLoveBoardIconKind.volcano:
        _paintVolcano(canvas);
      case PyramidLoveBoardIconKind.worldWar:
        _paintWorldWar(canvas);
      case PyramidLoveBoardIconKind.twinWin:
        _paintTwinWin(canvas);
      case PyramidLoveBoardIconKind.martianChess:
        _paintGrid(canvas, 4, 4);
      case PyramidLoveBoardIconKind.lunar:
        _paintLunar(canvas);
    }
    canvas.restore();
  }

  void _paintWheel(Canvas canvas) {
    const center = Offset(12, 12);
    canvas.drawPath(_regularPolygon(center, 10.2, 10), _stroke);
    canvas.drawPath(_regularPolygon(center, 5.3, 10), _stroke);
    final star = Path();
    for (var i = 0; i < 20; i += 1) {
      final radius = i.isEven ? 8.7 : 5.3;
      final point = _polar(center, radius, -math.pi / 2 + i * math.pi / 10);
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(star..close(), _stroke);
  }

  void _paintGrid(
    Canvas canvas,
    int columns,
    int rows, {
    bool accentCorners = false,
    bool centerDot = false,
  }) {
    const rect = Rect.fromLTWH(2.5, 2.5, 19, 19);
    canvas.drawRect(rect, _stroke);
    final cellW = rect.width / columns;
    final cellH = rect.height / rows;
    for (var c = 1; c < columns; c += 1) {
      final x = rect.left + c * cellW;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), _stroke);
    }
    for (var r = 1; r < rows; r += 1) {
      final y = rect.top + r * cellH;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), _stroke);
    }
    if (accentCorners) {
      for (final point in const [
        Offset(5.7, 5.7),
        Offset(18.3, 5.7),
        Offset(5.7, 18.3),
        Offset(18.3, 18.3),
      ]) {
        canvas.drawCircle(point, 1.15, _fill);
      }
    }
    if (centerDot) canvas.drawCircle(const Offset(12, 12), 1.7, _fill);
  }

  void _paintPetal(Canvas canvas) {
    const center = Offset(12, 12);
    for (var i = 0; i < 10; i += 1) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final petalCenter = _polar(center, 6.7, angle);
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle + math.pi / 2);
      canvas.drawOval(
        const Rect.fromCenter(center: Offset.zero, width: 3.6, height: 7.2),
        _stroke,
      );
      canvas.restore();
    }
    canvas.drawCircle(center, 2.25, _stroke);
  }

  void _paintVolcano(Canvas canvas) {
    _paintGrid(canvas, 5, 5);
    for (final point in const [
      Offset(7.7, 7.7),
      Offset(12, 7.7),
      Offset(16.3, 7.7),
      Offset(7.7, 12),
      Offset(12, 12),
      Offset(16.3, 12),
      Offset(7.7, 16.3),
      Offset(12, 16.3),
      Offset(16.3, 16.3),
    ]) {
      final triangle = Path()
        ..moveTo(point.dx, point.dy - 0.9)
        ..lineTo(point.dx + 0.8, point.dy + 0.7)
        ..lineTo(point.dx - 0.8, point.dy + 0.7)
        ..close();
      canvas.drawPath(triangle, _fill);
    }
  }

  void _paintWorldWar(Canvas canvas) {
    const centers = [
      Offset(5, 7),
      Offset(5.5, 17),
      Offset(10.2, 9),
      Offset(11.2, 16),
      Offset(17, 7.5),
      Offset(18.3, 16.8),
    ];
    for (var i = 0; i < centers.length; i += 1) {
      for (var j = 0; j < 3; j += 1) {
        canvas.drawCircle(
          _polar(centers[i], 1.55, -math.pi / 2 + j * 2 * math.pi / 3),
          0.65,
          _fill,
        );
      }
    }
    const links = [(0, 2), (1, 3), (2, 4), (3, 5), (2, 3), (4, 5)];
    for (final link in links) {
      canvas.drawLine(centers[link.$1], centers[link.$2], _stroke);
    }
  }

  void _paintTwinWin(Canvas canvas) {
    const center = Offset(12, 12);
    for (var row = -1; row <= 1; row += 1) {
      for (var column = -1; column <= 1; column += 1) {
        final point = center + Offset(column * 6.0, row * 6.0);
        canvas.drawCircle(point, row == 0 && column == 0 ? 2.2 : 1.65, _stroke);
      }
    }
    canvas.drawLine(const Offset(6, 6), const Offset(18, 18), _stroke);
    canvas.drawLine(const Offset(18, 6), const Offset(6, 18), _stroke);
  }

  void _paintLunar(Canvas canvas) {
    const center = Offset(12, 12);
    canvas.drawCircle(center, 9.6, _stroke);
    canvas.drawCircle(center, 2.0, _stroke);
    for (var i = 0; i < 8; i += 1) {
      final point = _polar(center, 6.2, -math.pi / 2 + i * math.pi / 4);
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromCenter(center: point, width: 2.5, height: 2.5),
          _stroke,
        );
      } else {
        canvas.drawCircle(point, 1.25, _stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PyramidLoveBoardIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
