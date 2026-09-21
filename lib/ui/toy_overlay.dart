import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/light_element.dart';
import '../domain/physical_point.dart';
import '../domain/pyramid_geometry.dart';

class ToyProjectile {
  const ToyProjectile({
    required this.position,
    required this.velocity,
    required this.radiusMm,
    this.ricochet = false,
    this.edgeHits = 0,
    this.escaping = false,
  });

  final PhysicalPoint position;
  final PhysicalPoint velocity;
  final double radiusMm;
  final bool ricochet;
  final int edgeHits;
  final bool escaping;

  ToyProjectile copyWith({
    PhysicalPoint? position,
    PhysicalPoint? velocity,
    int? edgeHits,
    bool? escaping,
  }) => ToyProjectile(
    position: position ?? this.position,
    velocity: velocity ?? this.velocity,
    radiusMm: radiusMm,
    ricochet: ricochet,
    edgeHits: edgeHits ?? this.edgeHits,
    escaping: escaping ?? this.escaping,
  );
}

class ToyImpact {
  const ToyImpact({required this.position, required this.lifeSeconds});
  final PhysicalPoint position;
  final double lifeSeconds;

  ToyImpact copyWith({double? lifeSeconds}) => ToyImpact(
    position: position,
    lifeSeconds: lifeSeconds ?? this.lifeSeconds,
  );
}

class _V3 {
  const _V3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  _V3 operator +(_V3 other) => _V3(x + other.x, y + other.y, z + other.z);
  _V3 scale(double amount) => _V3(x * amount, y * amount, z * amount);
}

class ToyOverlayPainter extends CustomPainter {
  const ToyOverlayPainter({
    required this.logicalPixelsPerMm,
    required this.geometry,
    required this.elements,
    required this.ghostTrails,
    required this.ghostTrailsVisible,
    required this.eventZoneCenter,
    required this.eventZoneRadiusMm,
    required this.eventZoneProgress,
    required this.eventZoneDismiss,
    required this.turnTimerProgress,
    required this.radarAngleDegrees,
    required this.redSweepY,
    required this.dieValue,
    required this.dieRollPhase,
    required this.dieRollProgress,
    required this.diePressed,
    required this.projectiles,
    required this.impacts,
    required this.sideGunsVisible,
    required this.sideGunAnglesDegrees,
    required this.sideGunAmmo,
    required this.cornerGunsVisible,
    required this.constellation,
    this.uiScale = 1,
  });

  final double logicalPixelsPerMm;
  final double uiScale;
  final PyramidGeometryProfile geometry;
  final List<LightElement> elements;
  final Map<String, List<PhysicalPoint>> ghostTrails;
  final bool ghostTrailsVisible;
  final PhysicalPoint? eventZoneCenter;
  final double? eventZoneRadiusMm;
  final double? eventZoneProgress;
  final double eventZoneDismiss;
  final double? turnTimerProgress;
  final double? radarAngleDegrees;
  final double? redSweepY;
  final int? dieValue;
  final double dieRollPhase;
  final double dieRollProgress;
  final bool diePressed;
  final List<ToyProjectile> projectiles;
  final List<ToyImpact> impacts;
  final bool sideGunsVisible;
  final List<double> sideGunAnglesDegrees;
  final List<int> sideGunAmmo;
  final bool cornerGunsVisible;
  final List<PhysicalPoint> constellation;

  Offset _px(PhysicalPoint point) =>
      Offset(point.xMm * logicalPixelsPerMm, point.yMm * logicalPixelsPerMm);

  @override
  void paint(Canvas canvas, Size size) {
    _paintGhostTrails(canvas);
    _paintEventZone(canvas);
    _paintTurnTimer(canvas, size);
    _paintRadar(canvas, size);
    _paintRedSweep(canvas, size);
    _paintWireDie(canvas, size);
    _paintGuns(canvas, size);
    _paintProjectiles(canvas);
    _paintImpacts(canvas);
    _paintConstellation(canvas);
  }

  void _paintGhostTrails(Canvas canvas) {
    if (!ghostTrailsVisible) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.26)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final points in ghostTrails.values) {
      if (points.length < 2) continue;
      final first = _px(points.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in points.skip(1)) {
        final o = _px(point);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
      for (var i = 0; i < points.length; i += 5) {
        canvas.drawCircle(_px(points[i]), 1.6, paint);
      }
    }
  }

  void _paintEventZone(Canvas canvas) {
    final center = eventZoneCenter;
    final radiusMm = eventZoneRadiusMm;
    final progress = eventZoneProgress;
    if (center == null || radiusMm == null || progress == null) return;
    final c = _px(center);
    final dismiss = eventZoneDismiss.clamp(0, 1).toDouble();
    final radius = radiusMm * logicalPixelsPerMm * (1 - dismiss * 0.18);
    final alpha = 1 - dismiss;
    canvas.drawCircle(
      c,
      radius,
      Paint()..color = Colors.white.withValues(alpha: 0.08 * alpha),
    );
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.70 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, radius, ring);

    final markPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.48 * alpha)
      ..strokeWidth = 1.0;
    for (var i = 0; i < 4; i += 1) {
      final angle = i * math.pi / 2;
      final inner = radius - 3.0;
      final outer = radius + 3.0;
      canvas.drawLine(
        Offset(c.dx + math.cos(angle) * inner, c.dy + math.sin(angle) * inner),
        Offset(c.dx + math.cos(angle) * outer, c.dy + math.sin(angle) * outer),
        markPaint,
      );
    }

    // A fixed black gap travels counter-clockwise around the otherwise intact
    // ring. The amount of black never grows with elapsed time.
    final elapsed = 1 - progress.clamp(0, 1).toDouble();
    const gap = math.pi / 8;
    final centerAngle = -math.pi / 2 - math.pi * 2 * elapsed;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      centerAngle - gap / 2,
      gap,
      false,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.butt,
    );

    if (dismiss > 0) {
      final shard = Paint()
        ..color = Colors.white.withValues(alpha: (1 - dismiss) * 0.65)
        ..strokeWidth = 1.5;
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + dismiss * 0.45;
        final inner = radius * (0.65 + dismiss * 0.15);
        final outer = radius * (0.90 + dismiss * 0.35);
        canvas.drawLine(
          Offset(c.dx + math.cos(a) * inner, c.dy + math.sin(a) * inner),
          Offset(c.dx + math.cos(a) * outer, c.dy + math.sin(a) * outer),
          shard,
        );
      }
    }
  }

  void _paintTurnTimer(Canvas canvas, Size size) {
    final progress = turnTimerProgress;
    if (progress == null) return;
    final inset = math.max(19.0, logicalPixelsPerMm * 4.5);
    final rect = Rect.fromLTWH(
      inset,
      inset,
      math.max(1.0, size.width - inset * 2),
      math.max(1.0, size.height - inset * 2),
    );
    final path = Path()..addRect(rect);
    final metric = path.computeMetrics().first;
    final length = metric.length * progress.clamp(0, 1).toDouble();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      metric.extractPath(0, length),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.square,
    );
  }

  void _paintRadar(Canvas canvas, Size size) {
    final degrees = radarAngleDegrees;
    if (degrees == null) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    // A stack of fading rays gives a phosphor-like radar persistence trail.
    for (var i = 12; i >= 0; i -= 1) {
      final radians = (degrees - i * 2.4) * math.pi / 180;
      final alpha = i == 0 ? 0.72 : 0.025 + (1 - i / 12) * 0.23;
      final end = Offset(
        center.dx + math.cos(radians) * radius,
        center.dy + math.sin(radians) * radius,
      );
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = const Color(0xFF35FF67).withValues(alpha: alpha)
          ..strokeWidth = i == 0 ? 1.5 : 1.1,
      );
    }
  }

  void _paintRedSweep(Canvas canvas, Size size) {
    final y = redSweepY;
    if (y == null) return;
    canvas.drawLine(
      Offset(0, size.height * y),
      Offset(size.width, size.height * y),
      Paint()
        ..color = const Color(0xFFFF3030).withValues(alpha: 0.82)
        ..strokeWidth = 1.5,
    );
  }

  _V3 _rotate(_V3 p, double rx, double ry, double rz) {
    final cx = math.cos(rx);
    final sx = math.sin(rx);
    final cy = math.cos(ry);
    final sy = math.sin(ry);
    final cz = math.cos(rz);
    final sz = math.sin(rz);
    var x = p.x;
    var y = p.y * cx - p.z * sx;
    var z = p.y * sx + p.z * cx;
    final x2 = x * cy + z * sy;
    final z2 = -x * sy + z * cy;
    x = x2;
    z = z2;
    return _V3(x * cz - y * sz, x * sz + y * cz, z);
  }

  Offset _project3(_V3 p, Offset center, double scale) {
    const camera = 4.6;
    final perspective = camera / (camera - p.z);
    return Offset(
      center.dx + p.x * scale * perspective,
      center.dy + p.y * scale * perspective,
    );
  }

  ({double rx, double ry}) _dieTargetRotation(int value) => switch (value) {
    1 => (rx: 0, ry: 0),
    2 => (rx: -math.pi / 2, ry: 0),
    3 => (rx: 0, ry: -math.pi / 2),
    4 => (rx: 0, ry: math.pi / 2),
    5 => (rx: math.pi / 2, ry: 0),
    _ => (rx: 0, ry: math.pi),
  };

  List<Offset> _pipPattern(int value) {
    const a = 0.46;
    const b = 0.0;
    return switch (value) {
      1 => const [Offset(b, b)],
      2 => const [Offset(-a, -a), Offset(a, a)],
      3 => const [Offset(-a, -a), Offset(b, b), Offset(a, a)],
      4 => const [Offset(-a, -a), Offset(a, -a), Offset(-a, a), Offset(a, a)],
      5 => const [
        Offset(-a, -a),
        Offset(a, -a),
        Offset(b, b),
        Offset(-a, a),
        Offset(a, a),
      ],
      _ => const [
        Offset(-a, -a),
        Offset(-a, b),
        Offset(-a, a),
        Offset(a, -a),
        Offset(a, b),
        Offset(a, a),
      ],
    };
  }

  void _paintWireDie(Canvas canvas, Size size) {
    final value = dieValue;
    if (value == null) return;
    const center = Offset(43, 43);
    final baseScale = (logicalPixelsPerMm * 5.8).clamp(18.0, 28.0).toDouble();
    final scale = baseScale * (diePressed ? 0.76 : 1.0);
    final target = _dieTargetRotation(value);
    final eased = 1 - math.pow(1 - dieRollProgress.clamp(0, 1), 3).toDouble();
    final residual = 1 - eased;
    final rx = target.rx + dieRollPhase * 1.10 * residual;
    final ry = target.ry + dieRollPhase * 0.87 * residual;
    final rz = dieRollPhase * 0.61 * residual;

    const vertices = <_V3>[
      _V3(-1, -1, -1),
      _V3(1, -1, -1),
      _V3(1, 1, -1),
      _V3(-1, 1, -1),
      _V3(-1, -1, 1),
      _V3(1, -1, 1),
      _V3(1, 1, 1),
      _V3(-1, 1, 1),
    ];
    final rotated = [for (final v in vertices) _rotate(v, rx, ry, rz)];
    final projected = [for (final v in rotated) _project3(v, center, scale)];

    const faces =
        <({int value, List<int> vertices, _V3 normal, _V3 xAxis, _V3 yAxis})>[
          (
            value: 1,
            vertices: [4, 5, 6, 7],
            normal: _V3(0, 0, 1),
            xAxis: _V3(1, 0, 0),
            yAxis: _V3(0, 1, 0),
          ),
          (
            value: 6,
            vertices: [1, 0, 3, 2],
            normal: _V3(0, 0, -1),
            xAxis: _V3(-1, 0, 0),
            yAxis: _V3(0, 1, 0),
          ),
          (
            value: 2,
            vertices: [0, 1, 5, 4],
            normal: _V3(0, -1, 0),
            xAxis: _V3(1, 0, 0),
            yAxis: _V3(0, 0, 1),
          ),
          (
            value: 5,
            vertices: [3, 7, 6, 2],
            normal: _V3(0, 1, 0),
            xAxis: _V3(1, 0, 0),
            yAxis: _V3(0, 0, -1),
          ),
          (
            value: 3,
            vertices: [1, 2, 6, 5],
            normal: _V3(1, 0, 0),
            xAxis: _V3(0, 0, -1),
            yAxis: _V3(0, 1, 0),
          ),
          (
            value: 4,
            vertices: [0, 4, 7, 3],
            normal: _V3(-1, 0, 0),
            xAxis: _V3(0, 0, 1),
            yAxis: _V3(0, 1, 0),
          ),
        ];

    final visible =
        <
          ({
            int value,
            List<int> vertices,
            _V3 normal,
            _V3 xAxis,
            _V3 yAxis,
            double depth,
            _V3 rotatedNormal,
          })
        >[];
    for (final face in faces) {
      final normal = _rotate(face.normal, rx, ry, rz);
      if (normal.z <= 0.015) continue;
      final depth =
          face.vertices
              .map((index) => rotated[index].z)
              .reduce((a, b) => a + b) /
          face.vertices.length;
      visible.add((
        value: face.value,
        vertices: face.vertices,
        normal: face.normal,
        xAxis: face.xAxis,
        yAxis: face.yAxis,
        depth: depth,
        rotatedNormal: normal,
      ));
    }
    visible.sort((a, b) => a.depth.compareTo(b.depth));

    for (final face in visible) {
      final path = Path();
      for (var i = 0; i < face.vertices.length; i += 1) {
        final p = projected[face.vertices[i]];
        if (i == 0)
          path.moveTo(p.dx, p.dy);
        else
          path.lineTo(p.dx, p.dy);
      }
      path.close();
      final brightness = (0.72 + face.rotatedNormal.z * 0.25)
          .clamp(0.72, 0.98)
          .toDouble();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: brightness)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25,
      );

      for (final pip in _pipPattern(face.value)) {
        final local =
            face.normal.scale(1.018) +
            face.xAxis.scale(pip.dx) +
            face.yAxis.scale(pip.dy);
        final point = _project3(_rotate(local, rx, ry, rz), center, scale);
        canvas.drawCircle(
          point,
          math.max(1.4, scale * 0.095),
          Paint()..color = Colors.black.withValues(alpha: 0.86),
        );
      }
    }
  }

  void _paintGun(Canvas canvas, Offset center, double angleDegrees) {
    final scale = uiScale.clamp(0.25, 4.0);
    final radians = angleDegrees * math.pi / 180;
    final direction = Offset(math.cos(radians), math.sin(radians));
    final normal = Offset(-direction.dy, direction.dx);
    final body = Path()
      ..moveTo(
        center.dx + normal.dx * 6.4 * scale,
        center.dy + normal.dy * 6.4 * scale,
      )
      ..lineTo(
        center.dx - normal.dx * 6.4 * scale,
        center.dy - normal.dy * 6.4 * scale,
      )
      ..lineTo(
        center.dx + direction.dx * 14 * scale - normal.dx * 4.2 * scale,
        center.dy + direction.dy * 14 * scale - normal.dy * 4.2 * scale,
      )
      ..lineTo(
        center.dx + direction.dx * 14 * scale + normal.dx * 4.2 * scale,
        center.dy + direction.dy * 14 * scale + normal.dy * 4.2 * scale,
      )
      ..close();
    canvas.drawPath(
      body,
      Paint()..color = Colors.white.withValues(alpha: 0.34),
    );
    canvas.drawLine(
      center + direction * (10 * scale),
      center + direction * (26 * scale),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.60)
        ..strokeWidth = 4 * scale,
    );
  }

  void _paintRounds(Canvas canvas, Offset gunCenter, int gunIndex, int count) {
    if (count <= 0) return;
    final scale = uiScale.clamp(0.25, 4.0);
    final visible = math.min(5, count);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.68);
    for (var i = 0; i < visible; i += 1) {
      final delta = (i - (visible - 1) / 2) * 6.2 * scale;
      final point = switch (gunIndex) {
        0 => gunCenter + Offset(20 * scale + delta, 22 * scale),
        1 => gunCenter + Offset(-20 * scale + delta, 22 * scale),
        2 => gunCenter + Offset(20 * scale + delta, -22 * scale),
        _ => gunCenter + Offset(-20 * scale + delta, -22 * scale),
      };
      canvas.drawCircle(point, 2.15 * scale, paint);
    }
  }

  void _paintGuns(Canvas canvas, Size size) {
    final scale = uiScale.clamp(0.25, 4.0);
    if (sideGunsVisible && sideGunAnglesDegrees.length >= 4) {
      final inset = 16 * scale;
      final centers = <Offset>[
        Offset(inset, inset),
        Offset(size.width - inset, inset),
        Offset(inset, size.height - inset),
        Offset(size.width - inset, size.height - inset),
      ];
      for (var i = 0; i < 4; i += 1) {
        _paintGun(canvas, centers[i], sideGunAnglesDegrees[i]);
        if (i < sideGunAmmo.length) {
          _paintRounds(canvas, centers[i], i, sideGunAmmo[i]);
        }
      }
    }
    if (cornerGunsVisible) {
      final d = 7.0 * scale;
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.22);
      for (final p in [
        Offset(d, d),
        Offset(size.width - d, d),
        Offset(d, size.height - d),
        Offset(size.width - d, size.height - d),
      ]) {
        canvas.drawCircle(p, 3.2 * scale, paint);
      }
    }
  }

  void _paintProjectiles(Canvas canvas) {
    for (final p in projectiles) {
      canvas.drawCircle(
        _px(p.position),
        math.max(1.4, p.radiusMm * logicalPixelsPerMm),
        Paint()
          ..color = p.ricochet
              ? Colors.white.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.88),
      );
    }
  }

  void _paintImpacts(Canvas canvas) {
    for (final impact in impacts) {
      final t = (impact.lifeSeconds / 0.8).clamp(0, 1).toDouble();
      final c = _px(impact.position);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: t * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawCircle(c, 3 + (1 - t) * 9, paint);
      canvas.drawLine(c + const Offset(-4, -4), c + const Offset(4, 4), paint);
      canvas.drawLine(c + const Offset(-4, 4), c + const Offset(4, -4), paint);
    }
  }

  void _paintConstellation(Canvas canvas) {
    if (constellation.length < 2) return;
    final path = Path();
    final first = _px(constellation.first);
    path.moveTo(first.dx, first.dy);
    for (final point in constellation.skip(1)) {
      final o = _px(point);
      path.lineTo(o.dx, o.dy);
    }
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, paint);
    for (final point in constellation) {
      canvas.drawCircle(_px(point), 3.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ToyOverlayPainter oldDelegate) =>
      oldDelegate.logicalPixelsPerMm != logicalPixelsPerMm ||
      oldDelegate.uiScale != uiScale ||
      oldDelegate.geometry != geometry ||
      !listEquals(oldDelegate.elements, elements) ||
      oldDelegate.ghostTrailsVisible != ghostTrailsVisible ||
      (ghostTrailsVisible && oldDelegate.ghostTrails != ghostTrails) ||
      oldDelegate.eventZoneCenter != eventZoneCenter ||
      oldDelegate.eventZoneRadiusMm != eventZoneRadiusMm ||
      oldDelegate.eventZoneProgress != eventZoneProgress ||
      oldDelegate.eventZoneDismiss != eventZoneDismiss ||
      oldDelegate.turnTimerProgress != turnTimerProgress ||
      oldDelegate.radarAngleDegrees != radarAngleDegrees ||
      oldDelegate.redSweepY != redSweepY ||
      oldDelegate.dieValue != dieValue ||
      oldDelegate.dieRollPhase != dieRollPhase ||
      oldDelegate.dieRollProgress != dieRollProgress ||
      oldDelegate.diePressed != diePressed ||
      !listEquals(oldDelegate.projectiles, projectiles) ||
      !listEquals(oldDelegate.impacts, impacts) ||
      oldDelegate.sideGunsVisible != sideGunsVisible ||
      !listEquals(oldDelegate.sideGunAnglesDegrees, sideGunAnglesDegrees) ||
      !listEquals(oldDelegate.sideGunAmmo, sideGunAmmo) ||
      oldDelegate.cornerGunsVisible != cornerGunsVisible ||
      !listEquals(oldDelegate.constellation, constellation);
}
