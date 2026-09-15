import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ArcadeDieKind { standard, lightning, pyramid, treehouse, color }

class ArcadeDieChoice {
  const ArcadeDieChoice(this.id, this.kind, this.label);

  final String id;
  final ArcadeDieKind kind;
  final String label;
}

const arcadeDiceChoices = <ArcadeDieChoice>[
  ArcadeDieChoice('standard-1', ArcadeDieKind.standard, 'Regular D6 1'),
  ArcadeDieChoice('standard-2', ArcadeDieKind.standard, 'Regular D6 2'),
  ArcadeDieChoice('standard-3', ArcadeDieKind.standard, 'Regular D6 3'),
  ArcadeDieChoice('lightning-1', ArcadeDieKind.lightning, 'Lightning 1'),
  ArcadeDieChoice('lightning-2', ArcadeDieKind.lightning, 'Lightning 2'),
  ArcadeDieChoice('lightning-3', ArcadeDieKind.lightning, 'Lightning 3'),
  ArcadeDieChoice('pyramid', ArcadeDieKind.pyramid, 'Pyramid die'),
  ArcadeDieChoice('treehouse', ArcadeDieKind.treehouse, 'Treehouse die'),
  ArcadeDieChoice('color', ArcadeDieKind.color, 'Color die'),
];

class DiceBubble extends StatefulWidget {
  const DiceBubble({super.key});

  @override
  State<DiceBubble> createState() => _DiceBubbleState();
}

class _Rotation3 {
  const _Rotation3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static _Rotation3 lerp(_Rotation3 a, _Rotation3 b, double t) => _Rotation3(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.z + (b.z - a.z) * t,
  );
}

class _SpinPlan {
  const _SpinPlan({
    required this.start,
    required this.end,
    required this.bounceAngle,
    required this.bouncePhase,
  });

  final _Rotation3 start;
  final _Rotation3 end;
  final double bounceAngle;
  final double bouncePhase;

  _Rotation3 rotationAt(double progress) {
    final eased = 1 - math.pow(1 - progress.clamp(0.0, 1.0), 3).toDouble();
    return _Rotation3.lerp(start, end, eased);
  }
}

class _DiceBubbleState extends State<DiceBubble>
    with SingleTickerProviderStateMixin {
  static const double _radius = 59;
  final math.Random _random = math.Random();
  final List<String> _selectedIds = ['standard-1'];
  final Map<String, int> _faces = {'standard-1': 0};
  final Map<String, _SpinPlan> _plans = {};
  late final AnimationController _rollController;

  Offset _center = const Offset(69, 69);
  bool _pressed = false;
  bool _twoFingerMove = false;

  @override
  void initState() {
    super.initState();
    _rollController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1180),
          value: 1,
        )..addListener(() {
          if (mounted) setState(() {});
        });
  }

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  ArcadeDieChoice _choice(String id) =>
      arcadeDiceChoices.firstWhere((choice) => choice.id == id);

  double _normalize(double radians) =>
      ((radians + math.pi) % (2 * math.pi)) - math.pi;

  _Rotation3 _targetForFace(int face) => switch (face) {
    0 => const _Rotation3(0, 0, 0),
    1 => const _Rotation3(-math.pi / 2, 0, 0),
    2 => const _Rotation3(0, -math.pi / 2, 0),
    3 => const _Rotation3(0, math.pi / 2, 0),
    4 => const _Rotation3(math.pi / 2, 0, 0),
    _ => const _Rotation3(0, math.pi, 0),
  };

  double _spunEnd(double target) {
    final turns = 2 + _random.nextInt(3);
    final sign = _random.nextBool() ? 1.0 : -1.0;
    return target + sign * turns * 2 * math.pi;
  }

  void _roll() {
    if (_selectedIds.isEmpty) return;
    for (final id in _selectedIds) {
      final old = _plans[id]?.rotationAt(1) ?? _targetForFace(_faces[id] ?? 0);
      final start = _Rotation3(
        _normalize(old.x),
        _normalize(old.y),
        _normalize(old.z),
      );
      final face = _random.nextInt(6);
      final target = _targetForFace(face);
      _faces[id] = face;
      _plans[id] = _SpinPlan(
        start: start,
        end: _Rotation3(
          _spunEnd(target.x),
          _spunEnd(target.y),
          _spunEnd(target.z),
        ),
        bounceAngle: _random.nextDouble() * 2 * math.pi,
        bouncePhase: _random.nextDouble() * 2 * math.pi,
      );
    }
    HapticFeedback.mediumImpact();
    _rollController.forward(from: 0);
  }

  Offset _clampCenter(Offset center, Size size) => Offset(
    center.dx
        .clamp(_radius + 2, math.max(_radius + 2, size.width - _radius - 2))
        .toDouble(),
    center.dy
        .clamp(_radius + 2, math.max(_radius + 2, size.height - _radius - 2))
        .toDouble(),
  );

  Future<void> _showPicker() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF202020),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final atLimit = _selectedIds.length >= 3;
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Text(
                    'Dice · ${_selectedIds.length}/3 selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final choice in arcadeDiceChoices)
                  CheckboxListTile(
                    value: _selectedIds.contains(choice.id),
                    title: Text(choice.label),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: !_selectedIds.contains(choice.id) && atLimit
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedIds.add(choice.id);
                                _faces[choice.id] = _random.nextInt(6);
                              } else {
                                _selectedIds.remove(choice.id);
                                _faces.remove(choice.id);
                                _plans.remove(choice.id);
                              }
                            });
                            setSheetState(() {});
                          },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      _center = _clampCenter(_center, size);
      final selected = [for (final id in _selectedIds) _choice(id)];
      return Stack(
        children: [
          Positioned(
            left: _center.dx - _radius,
            top: _center.dy - _radius,
            width: _radius * 2,
            height: _radius * 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _twoFingerMove = details.pointerCount >= 2;
                setState(() => _pressed = !_twoFingerMove);
                if (_pressed) HapticFeedback.selectionClick();
              },
              onScaleUpdate: (details) {
                if (details.pointerCount < 2) return;
                _twoFingerMove = true;
                setState(() {
                  _pressed = false;
                  _center = _clampCenter(
                    _center + details.focalPointDelta,
                    size,
                  );
                });
              },
              onScaleEnd: (_) {
                final roll = _pressed && !_twoFingerMove;
                setState(() => _pressed = false);
                if (roll) _roll();
                _twoFingerMove = false;
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _DiceBubblePainter(
                      choices: selected,
                      faces: _faces,
                      plans: _plans,
                      progress: _rollController.value,
                      pressed: _pressed,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showPicker,
                      child: Container(
                        width: 25,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          border: Border.all(color: Colors.white54),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(4),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_open_outlined,
                          size: 15,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
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

class _Face {
  const _Face({
    required this.index,
    required this.vertices,
    required this.normal,
    required this.xAxis,
    required this.yAxis,
  });

  final int index;
  final List<int> vertices;
  final _V3 normal;
  final _V3 xAxis;
  final _V3 yAxis;
}

class _DiceBubblePainter extends CustomPainter {
  const _DiceBubblePainter({
    required this.choices,
    required this.faces,
    required this.plans,
    required this.progress,
    required this.pressed,
  });

  final List<ArcadeDieChoice> choices;
  final Map<String, int> faces;
  final Map<String, _SpinPlan> plans;
  final double progress;
  final bool pressed;

  static const _vertices = <_V3>[
    _V3(-1, -1, -1),
    _V3(1, -1, -1),
    _V3(1, 1, -1),
    _V3(-1, 1, -1),
    _V3(-1, -1, 1),
    _V3(1, -1, 1),
    _V3(1, 1, 1),
    _V3(-1, 1, 1),
  ];

  static const _cubeFaces = <_Face>[
    _Face(
      index: 0,
      vertices: [4, 5, 6, 7],
      normal: _V3(0, 0, 1),
      xAxis: _V3(1, 0, 0),
      yAxis: _V3(0, 1, 0),
    ),
    _Face(
      index: 5,
      vertices: [1, 0, 3, 2],
      normal: _V3(0, 0, -1),
      xAxis: _V3(-1, 0, 0),
      yAxis: _V3(0, 1, 0),
    ),
    _Face(
      index: 1,
      vertices: [0, 1, 5, 4],
      normal: _V3(0, -1, 0),
      xAxis: _V3(1, 0, 0),
      yAxis: _V3(0, 0, 1),
    ),
    _Face(
      index: 4,
      vertices: [3, 7, 6, 2],
      normal: _V3(0, 1, 0),
      xAxis: _V3(1, 0, 0),
      yAxis: _V3(0, 0, -1),
    ),
    _Face(
      index: 2,
      vertices: [1, 2, 6, 5],
      normal: _V3(1, 0, 0),
      xAxis: _V3(0, 0, -1),
      yAxis: _V3(0, 1, 0),
    ),
    _Face(
      index: 3,
      vertices: [0, 4, 7, 3],
      normal: _V3(-1, 0, 0),
      xAxis: _V3(0, 0, 1),
      yAxis: _V3(0, 1, 0),
    ),
  ];

  _V3 _rotate(_V3 p, _Rotation3 rotation) {
    final cx = math.cos(rotation.x);
    final sx = math.sin(rotation.x);
    final cy = math.cos(rotation.y);
    final sy = math.sin(rotation.y);
    final cz = math.cos(rotation.z);
    final sz = math.sin(rotation.z);
    var x = p.x;
    var y = p.y * cx - p.z * sx;
    var z = p.y * sx + p.z * cx;
    final x2 = x * cy + z * sy;
    final z2 = -x * sy + z * cy;
    x = x2;
    z = z2;
    return _V3(x * cz - y * sz, x * sz + y * cz, z);
  }

  Offset _project(_V3 p, Offset center, double scale) {
    const camera = 4.6;
    final perspective = camera / (camera - p.z);
    return Offset(
      center.dx + p.x * scale * perspective,
      center.dy + p.y * scale * perspective,
    );
  }

  _Rotation3 _targetForFace(int face) => switch (face) {
    0 => const _Rotation3(0, 0, 0),
    1 => const _Rotation3(-math.pi / 2, 0, 0),
    2 => const _Rotation3(0, -math.pi / 2, 0),
    3 => const _Rotation3(0, math.pi / 2, 0),
    4 => const _Rotation3(math.pi / 2, 0, 0),
    _ => const _Rotation3(0, math.pi, 0),
  };

  List<Offset> _dieOffsets(int count) => switch (count) {
    1 => const [Offset.zero],
    2 => const [Offset(-18, 0), Offset(18, 0)],
    _ => const [Offset(-18, -10), Offset(18, -10), Offset(0, 19)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white.withValues(alpha: 0.035),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 5),
      math.pi * 1.12,
      math.pi * 0.64,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final offsets = _dieOffsets(choices.length);
    final squeeze = pressed ? 0.72 : 1.0;
    for (var i = 0; i < choices.length; i += 1) {
      final choice = choices[i];
      final face = faces[choice.id] ?? 0;
      final plan = plans[choice.id];
      final rotation = plan?.rotationAt(progress) ?? _targetForFace(face);
      var dieCenter = center + offsets[i] * squeeze;
      if (plan != null && progress < 1) {
        final decay = math.pow(1 - progress, 2).toDouble();
        final wobble =
            math.sin(progress * math.pi * 8 + plan.bouncePhase) * 5.5 * decay;
        dieCenter += Offset(
          math.cos(plan.bounceAngle) * wobble,
          math.sin(plan.bounceAngle) * wobble,
        );
      }
      _paintDie(canvas, dieCenter, 15.2 * squeeze, choice.kind, rotation);
    }
  }

  void _paintDie(
    Canvas canvas,
    Offset center,
    double scale,
    ArcadeDieKind kind,
    _Rotation3 rotation,
  ) {
    final rotated = [for (final vertex in _vertices) _rotate(vertex, rotation)];
    final projected = [
      for (final vertex in rotated) _project(vertex, center, scale),
    ];
    final visible = <({_Face face, double depth, _V3 normal})>[];
    for (final face in _cubeFaces) {
      final normal = _rotate(face.normal, rotation);
      if (normal.z <= 0.02) continue;
      final depth =
          face.vertices
              .map((index) => rotated[index].z)
              .reduce((a, b) => a + b) /
          4;
      visible.add((face: face, depth: depth, normal: normal));
    }
    visible.sort((a, b) => a.depth.compareTo(b.depth));

    for (final item in visible) {
      final face = item.face;
      final path = Path();
      for (var i = 0; i < face.vertices.length; i += 1) {
        final p = projected[face.vertices[i]];
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: 0.90),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      _paintFaceMark(canvas, center, scale, rotation, face, kind);
    }
  }

  Offset _facePoint(
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    double x,
    double y,
  ) {
    final local =
        face.normal.scale(1.012) + face.xAxis.scale(x) + face.yAxis.scale(y);
    return _project(_rotate(local, rotation), center, scale);
  }

  void _projectedDisc(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    double x,
    double y,
    double radius,
    Paint paint,
  ) {
    final path = Path();
    for (var i = 0; i <= 18; i += 1) {
      final angle = i * 2 * math.pi / 18;
      final p = _facePoint(
        center,
        scale,
        rotation,
        face,
        x + math.cos(angle) * radius,
        y + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  List<Offset> _pipPattern(int value) {
    const a = 0.45;
    return switch (value) {
      1 => const [Offset.zero],
      2 => const [Offset(-a, -a), Offset(a, a)],
      3 => const [Offset(-a, -a), Offset.zero, Offset(a, a)],
      4 => const [Offset(-a, -a), Offset(a, -a), Offset(-a, a), Offset(a, a)],
      5 => const [
        Offset(-a, -a),
        Offset(a, -a),
        Offset.zero,
        Offset(-a, a),
        Offset(a, a),
      ],
      _ => const [
        Offset(-a, -a),
        Offset(-a, 0),
        Offset(-a, a),
        Offset(a, -a),
        Offset(a, 0),
        Offset(a, a),
      ],
    };
  }

  void _paintFaceMark(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    ArcadeDieKind kind,
  ) {
    final black = Paint()
      ..color = Colors.black.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;
    switch (kind) {
      case ArcadeDieKind.standard:
        for (final pip in _pipPattern(face.index + 1)) {
          _projectedDisc(
            canvas,
            center,
            scale,
            rotation,
            face,
            pip.dx,
            pip.dy,
            0.145,
            black,
          );
        }
      case ArcadeDieKind.lightning:
        _paintLightningMark(canvas, center, scale, rotation, face, black);
      case ArcadeDieKind.pyramid:
        _paintPyramidMark(canvas, center, scale, rotation, face, black);
      case ArcadeDieKind.treehouse:
        const labels = ['AIM', 'DIG', 'SWAP', 'HOP', 'TIP', 'WILD'];
        _paintFaceText(
          canvas,
          center,
          scale,
          rotation,
          face,
          labels[face.index],
        );
      case ArcadeDieKind.color:
        if (face.index < 5) {
          final colors = [
            Colors.red,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.purple,
          ];
          _projectedDisc(
            canvas,
            center,
            scale,
            rotation,
            face,
            0,
            0,
            0.36,
            Paint()..color = colors[face.index],
          );
        } else {
          _paintAtom(canvas, center, scale, rotation, face, black);
        }
    }
  }

  void _lineOnFace(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    Offset a,
    Offset b,
    Paint paint,
  ) {
    canvas.drawLine(
      _facePoint(center, scale, rotation, face, a.dx, a.dy),
      _facePoint(center, scale, rotation, face, b.dx, b.dy),
      paint,
    );
  }

  void _paintLightningMark(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    Paint fill,
  ) {
    final stroke = Paint()
      ..color = fill.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, scale * 0.09)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (face.index) {
      case 0:
        final points = [
          const Offset(-0.10, -0.62),
          const Offset(0.22, -0.12),
          const Offset(0.02, -0.12),
          const Offset(0.18, 0.62),
          const Offset(-0.26, 0.08),
          const Offset(-0.04, 0.08),
        ];
        final path = Path();
        for (var i = 0; i < points.length; i += 1) {
          final p = _facePoint(
            center,
            scale,
            rotation,
            face,
            points[i].dx,
            points[i].dy,
          );
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, fill);
      case 1:
        const ring = [
          Offset(0, -0.52),
          Offset(0.45, 0.25),
          Offset(-0.45, 0.25),
          Offset(0, -0.52),
        ];
        for (var i = 0; i < ring.length - 1; i += 1) {
          _lineOnFace(
            canvas,
            center,
            scale,
            rotation,
            face,
            ring[i],
            ring[i + 1],
            stroke,
          );
        }
      case 2:
        _lineOnFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          const Offset(0, 0.58),
          const Offset(0, 0),
          stroke,
        );
        _lineOnFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          const Offset(0, 0),
          const Offset(-0.48, -0.48),
          stroke,
        );
        _lineOnFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          const Offset(0, 0),
          const Offset(0.48, -0.48),
          stroke,
        );
      case 3:
        _lineOnFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          const Offset(-0.55, 0),
          const Offset(0.48, 0),
          stroke,
        );
        _lineOnFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          const Offset(0.48, 0),
          const Offset(0.18, -0.28),
          stroke,
        );
        _lineOnFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          const Offset(0.48, 0),
          const Offset(0.18, 0.28),
          stroke,
        );
      case 4:
        _projectedTriangle(
          canvas,
          center,
          scale,
          rotation,
          face,
          -0.34,
          0.12,
          0.30,
          fill,
        );
        _projectedTriangle(
          canvas,
          center,
          scale,
          rotation,
          face,
          0.0,
          -0.18,
          0.42,
          fill,
        );
        _projectedTriangle(
          canvas,
          center,
          scale,
          rotation,
          face,
          0.36,
          0.12,
          0.25,
          fill,
        );
      case 5:
        _paintAtom(canvas, center, scale, rotation, face, fill);
    }
  }

  void _paintAtom(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    Paint fill,
  ) {
    final stroke = Paint()
      ..color = fill.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.9, scale * 0.07);
    for (var ring = 0; ring < 3; ring += 1) {
      final path = Path();
      final ringAngle = ring * math.pi / 3;
      for (var i = 0; i <= 24; i += 1) {
        final a = i * 2 * math.pi / 24;
        final x0 = math.cos(a) * 0.55;
        final y0 = math.sin(a) * 0.22;
        final x = x0 * math.cos(ringAngle) - y0 * math.sin(ringAngle);
        final y = x0 * math.sin(ringAngle) + y0 * math.cos(ringAngle);
        final p = _facePoint(center, scale, rotation, face, x, y);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, stroke);
    }
    _projectedDisc(canvas, center, scale, rotation, face, 0, 0, 0.10, fill);
  }

  void _projectedTriangle(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    double x,
    double y,
    double radius,
    Paint paint,
  ) {
    final path = Path();
    for (var i = 0; i < 3; i += 1) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 3;
      final p = _facePoint(
        center,
        scale,
        rotation,
        face,
        x + math.cos(angle) * radius,
        y + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _paintPyramidMark(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    Paint paint,
  ) {
    const sizes = <List<double>>[
      [0.28],
      [0.42],
      [0.58],
      [0.28, 0.42],
      [0.28, 0.58],
      [0.42, 0.58],
    ];
    final marks = sizes[face.index];
    for (var i = 0; i < marks.length; i += 1) {
      final x = marks.length == 1 ? 0.0 : (i == 0 ? -0.28 : 0.28);
      _projectedTriangle(
        canvas,
        center,
        scale,
        rotation,
        face,
        x,
        0.04,
        marks[i],
        paint,
      );
    }
  }

  void _paintFaceText(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    String text,
  ) {
    final c = _facePoint(center, scale, rotation, face, 0, 0);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.90),
          fontSize: math.max(5.5, scale * (text.length > 3 ? 0.32 : 0.38)),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(c.dx - painter.width / 2, c.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DiceBubblePainter oldDelegate) => true;
}
