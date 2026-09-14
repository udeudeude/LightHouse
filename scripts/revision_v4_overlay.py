from pathlib import Path
import re


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"missing marker: {label}")
    return text.replace(old, new, 1)


def replace_regex(text, pattern, replacement, label):
    next_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"missing regex marker: {label} ({count})")
    return next_text


overlay = read('lib/ui/toy_overlay.dart')
overlay = replace_once(
    overlay,
    '    required this.dieRollProgress,\n    required this.projectiles,\n',
    '    required this.dieRollProgress,\n    required this.diePressed,\n    required this.projectiles,\n',
    'die pressed constructor',
)
overlay = replace_once(
    overlay,
    '    required this.sideGunAnglesDegrees,\n    required this.cornerGunsVisible,\n',
    '    required this.sideGunAnglesDegrees,\n    required this.sideGunAmmo,\n    required this.cornerGunsVisible,\n',
    'gun ammo constructor',
)
overlay = replace_once(
    overlay,
    '  final double dieRollProgress;\n  final List<ToyProjectile> projectiles;\n',
    '  final double dieRollProgress;\n  final bool diePressed;\n  final List<ToyProjectile> projectiles;\n',
    'die pressed field',
)
overlay = replace_once(
    overlay,
    '  final List<double> sideGunAnglesDegrees;\n  final bool cornerGunsVisible;\n',
    '  final List<double> sideGunAnglesDegrees;\n  final List<int> sideGunAmmo;\n  final bool cornerGunsVisible;\n',
    'gun ammo field',
)

# Cardinal registration marks around Random Event Zone.
marker_code = '''    final markPaint = Paint()
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

'''
overlay = replace_once(
    overlay,
    '    canvas.drawCircle(c, radius, ring);\n\n    // A fixed black gap',
    '    canvas.drawCircle(c, radius, ring);\n\n' + marker_code + '    // A fixed black gap',
    'event cardinal marks',
)

# Keep the leading radar sweep legible while making the phosphor trail subtler.
overlay = replace_once(
    overlay,
    '      final alpha = 0.03 + (1 - i / 12) * 0.72;\n',
    '      final alpha = i == 0 ? 0.68 : 0.01 + (1 - i / 12) * 0.18;\n',
    'radar trail brightness',
)

# Opaque perspective D6 in the upper-left. Only front-facing faces and their edges are drawn.
new_die = r'''  void _paintWireDie(Canvas canvas, Size size) {
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

    const faces = <({
      int value,
      List<int> vertices,
      _V3 normal,
      _V3 xAxis,
      _V3 yAxis,
    })>[
      (value: 1, vertices: [4, 5, 6, 7], normal: _V3(0, 0, 1), xAxis: _V3(1, 0, 0), yAxis: _V3(0, 1, 0)),
      (value: 6, vertices: [1, 0, 3, 2], normal: _V3(0, 0, -1), xAxis: _V3(-1, 0, 0), yAxis: _V3(0, 1, 0)),
      (value: 2, vertices: [0, 1, 5, 4], normal: _V3(0, -1, 0), xAxis: _V3(1, 0, 0), yAxis: _V3(0, 0, 1)),
      (value: 5, vertices: [3, 7, 6, 2], normal: _V3(0, 1, 0), xAxis: _V3(1, 0, 0), yAxis: _V3(0, 0, -1)),
      (value: 3, vertices: [1, 2, 6, 5], normal: _V3(1, 0, 0), xAxis: _V3(0, 0, -1), yAxis: _V3(0, 1, 0)),
      (value: 4, vertices: [0, 4, 7, 3], normal: _V3(-1, 0, 0), xAxis: _V3(0, 0, 1), yAxis: _V3(0, 1, 0)),
    ];

    final visible = <({
      int value,
      List<int> vertices,
      _V3 normal,
      _V3 xAxis,
      _V3 yAxis,
      double depth,
      _V3 rotatedNormal,
    })>[];
    for (final face in faces) {
      final normal = _rotate(face.normal, rx, ry, rz);
      if (normal.z <= 0.015) continue;
      final depth = face.vertices
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
        if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
      }
      path.close();
      final brightness = (0.72 + face.rotatedNormal.z * 0.25).clamp(0.72, 0.98).toDouble();
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
'''
overlay = replace_regex(
    overlay,
    r"  void _paintWireDie\(Canvas canvas, Size size\) \{.*?\n  \}\n\n  void _paintGun",
    new_die + '\n  void _paintGun',
    'opaque d6 painter',
)

# Draw loaded rounds as a compact line beside each side gun.
rounds_method = r'''  void _paintRounds(
    Canvas canvas,
    Offset gunCenter,
    double angleDegrees,
    int count,
  ) {
    if (count <= 0) return;
    final radians = angleDegrees * math.pi / 180;
    final direction = Offset(math.cos(radians), math.sin(radians));
    final normal = Offset(-direction.dy, direction.dx);
    final start = gunCenter - direction * 5 + normal * 8;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.62);
    for (var i = 0; i < count; i += 1) {
      final row = i ~/ 10;
      final column = i % 10;
      final p = start - direction * (column * 3.2) + normal * (row * 3.4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 2.0, height: 3.4),
          const Radius.circular(0.8),
        ),
        paint,
      );
    }
  }

'''
overlay = replace_once(overlay, '  void _paintGuns(Canvas canvas, Size size) {', rounds_method + '  void _paintGuns(Canvas canvas, Size size) {', 'round painter')
overlay = replace_once(
    overlay,
    '''      _paintGun(canvas, Offset(8, size.height / 2), sideGunAnglesDegrees[0]);
      _paintGun(
        canvas,
        Offset(size.width - 8, size.height / 2),
        sideGunAnglesDegrees[1],
      );
      _paintGun(canvas, Offset(size.width / 2, 8), sideGunAnglesDegrees[2]);
      _paintGun(
        canvas,
        Offset(size.width / 2, size.height - 8),
        sideGunAnglesDegrees[3],
      );
''',
    '''      final centers = <Offset>[
        Offset(8, size.height / 2),
        Offset(size.width - 8, size.height / 2),
        Offset(size.width / 2, 8),
        Offset(size.width / 2, size.height - 8),
      ];
      for (var i = 0; i < 4; i += 1) {
        _paintGun(canvas, centers[i], sideGunAnglesDegrees[i]);
        if (i < sideGunAmmo.length) {
          _paintRounds(
            canvas,
            centers[i],
            sideGunAnglesDegrees[i],
            sideGunAmmo[i],
          );
        }
      }
''',
    'ammo display beside guns',
)

write('lib/ui/toy_overlay.dart', overlay)
print('revision v4 overlay applied')
