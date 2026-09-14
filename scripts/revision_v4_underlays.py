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


underlay = r'''import 'dart:math' as math;

import 'physical_point.dart';

enum BoardUnderlayGroup { grids, chess, games }

enum BoardUnderlay {
  none,
  grid3x3,
  grid3x4,
  grid4x4,
  grid5x5,
  grid5x6,
  martianChessHalf,
  martianChess2,
  chess8x8,
  wheel,
  launchpad23,
  twinWin,
  looneyLudo1,
  looneyLudo4,
  volcano,
  lunarInvaders1,
  lunarInvaders2,
  petalBattle,
  worldWar5;

  static const double cellMm = 27;
  static const double coasterMm = 101.6;
  static const double wheelOuterRadiusMm = 127;
  static const double wheelPlayableRadiusMm = 112;
  static const double moonRadiusMm = 48;
  static const double petalRadiusMm = 54;

  bool get isVisible => this != BoardUnderlay.none;

  BoardUnderlayGroup? get group => switch (this) {
    BoardUnderlay.none => null,
    BoardUnderlay.grid3x3 ||
    BoardUnderlay.grid3x4 ||
    BoardUnderlay.grid4x4 ||
    BoardUnderlay.grid5x5 ||
    BoardUnderlay.grid5x6 => BoardUnderlayGroup.grids,
    BoardUnderlay.martianChessHalf ||
    BoardUnderlay.martianChess2 ||
    BoardUnderlay.chess8x8 => BoardUnderlayGroup.chess,
    _ => BoardUnderlayGroup.games,
  };

  bool get supportsChecker => switch (this) {
    BoardUnderlay.grid3x3 ||
    BoardUnderlay.grid3x4 ||
    BoardUnderlay.grid4x4 ||
    BoardUnderlay.grid5x5 ||
    BoardUnderlay.grid5x6 ||
    BoardUnderlay.martianChessHalf ||
    BoardUnderlay.martianChess2 ||
    BoardUnderlay.chess8x8 ||
    BoardUnderlay.volcano => true,
    _ => false,
  };

  bool get isRectangularGrid => switch (this) {
    BoardUnderlay.grid3x3 ||
    BoardUnderlay.grid3x4 ||
    BoardUnderlay.grid4x4 ||
    BoardUnderlay.grid5x5 ||
    BoardUnderlay.grid5x6 ||
    BoardUnderlay.martianChessHalf ||
    BoardUnderlay.martianChess2 ||
    BoardUnderlay.chess8x8 ||
    BoardUnderlay.volcano => true,
    _ => false,
  };

  int get columns => switch (this) {
    BoardUnderlay.grid3x3 => 3,
    BoardUnderlay.grid3x4 => 3,
    BoardUnderlay.grid4x4 => 4,
    BoardUnderlay.grid5x5 => 5,
    BoardUnderlay.grid5x6 => 5,
    BoardUnderlay.martianChessHalf => 4,
    BoardUnderlay.martianChess2 => 4,
    BoardUnderlay.chess8x8 => 8,
    BoardUnderlay.volcano => 5,
    _ => 0,
  };

  int get rows => switch (this) {
    BoardUnderlay.grid3x3 => 3,
    BoardUnderlay.grid3x4 => 4,
    BoardUnderlay.grid4x4 => 4,
    BoardUnderlay.grid5x5 => 5,
    BoardUnderlay.grid5x6 => 6,
    BoardUnderlay.martianChessHalf => 4,
    BoardUnderlay.martianChess2 => 8,
    BoardUnderlay.chess8x8 => 8,
    BoardUnderlay.volcano => 5,
    _ => 0,
  };

  String get menuLabel => switch (this) {
    BoardUnderlay.none => 'None',
    BoardUnderlay.grid3x3 => '3×3 grid',
    BoardUnderlay.grid3x4 => '3×4 bank',
    BoardUnderlay.grid4x4 => '4×4 grid',
    BoardUnderlay.grid5x5 => '5×5 grid',
    BoardUnderlay.grid5x6 => '5×6 grid',
    BoardUnderlay.martianChessHalf => 'Martian Chess · half board · 4×4',
    BoardUnderlay.martianChess2 => 'Martian Chess · 2 players · 4×8',
    BoardUnderlay.chess8x8 => 'Martian Chess · full · 8×8',
    BoardUnderlay.wheel => 'The Wheel',
    BoardUnderlay.launchpad23 => 'Launchpad 23',
    BoardUnderlay.twinWin => 'Twin Win',
    BoardUnderlay.looneyLudo1 => 'Looney Ludo · single board',
    BoardUnderlay.looneyLudo4 => 'Looney Ludo · four-board start',
    BoardUnderlay.volcano => 'Volcano · 5×5',
    BoardUnderlay.lunarInvaders1 => 'Lunar Invaders · one moon',
    BoardUnderlay.lunarInvaders2 => 'Lunar Invaders · two moons',
    BoardUnderlay.petalBattle => 'Petal Battle',
    BoardUnderlay.worldWar5 => 'World War 5',
  };

  List<PhysicalPoint> snapPoints({
    required double boardWidthMm,
    required double boardHeightMm,
  }) {
    final center = PhysicalPoint(boardWidthMm / 2, boardHeightMm / 2);
    if (isRectangularGrid) {
      return _rectGridPoints(center, columns, rows);
    }
    return switch (this) {
      BoardUnderlay.launchpad23 ||
      BoardUnderlay.twinWin ||
      BoardUnderlay.looneyLudo1 => _rectGridPoints(center, 3, 3),
      BoardUnderlay.looneyLudo4 => _ludoFourBoardPoints(center),
      BoardUnderlay.wheel => _wheelPoints(center),
      BoardUnderlay.lunarInvaders1 => _moonPoints(center),
      BoardUnderlay.lunarInvaders2 => _twoMoonPoints(center),
      BoardUnderlay.petalBattle => _petalPoints(center),
      BoardUnderlay.worldWar5 => _worldWarPoints(center),
      _ => const <PhysicalPoint>[],
    };
  }

  PhysicalPoint? nearestSnapPoint(
    PhysicalPoint point, {
    required double boardWidthMm,
    required double boardHeightMm,
  }) {
    final points = snapPoints(
      boardWidthMm: boardWidthMm,
      boardHeightMm: boardHeightMm,
    );
    if (points.isEmpty) return null;
    var nearest = points.first;
    var distance = point.distanceTo(nearest);
    for (final candidate in points.skip(1)) {
      final nextDistance = point.distanceTo(candidate);
      if (nextDistance < distance) {
        nearest = candidate;
        distance = nextDistance;
      }
    }
    return nearest;
  }

  static BoardUnderlay fromName(Object? value) {
    if (value is! String) return BoardUnderlay.none;
    for (final underlay in BoardUnderlay.values) {
      if (underlay.name == value) return underlay;
    }
    return BoardUnderlay.none;
  }
}

List<PhysicalPoint> _rectGridPoints(
  PhysicalPoint center,
  int columns,
  int rows,
) {
  final left = center.xMm - columns * BoardUnderlay.cellMm / 2;
  final top = center.yMm - rows * BoardUnderlay.cellMm / 2;
  return [
    for (var row = 0; row < rows; row += 1)
      for (var column = 0; column < columns; column += 1)
        PhysicalPoint(
          left + (column + 0.5) * BoardUnderlay.cellMm,
          top + (row + 0.5) * BoardUnderlay.cellMm,
        ),
  ];
}

List<PhysicalPoint> _ludoFourBoardPoints(PhysicalPoint center) {
  final half = BoardUnderlay.coasterMm / 2;
  final points = <PhysicalPoint>[];
  for (final dx in [-half, half]) {
    for (final dy in [-half, half]) {
      points.addAll(
        _rectGridPoints(PhysicalPoint(center.xMm + dx, center.yMm + dy), 3, 3),
      );
    }
  }
  return points;
}

List<PhysicalPoint> _moonPoints(PhysicalPoint center) {
  final points = <PhysicalPoint>[center];
  const ring = BoardUnderlay.moonRadiusMm * 0.63;
  for (var i = 0; i < 8; i += 1) {
    final angle = -math.pi / 2 + i * math.pi / 4;
    points.add(
      PhysicalPoint(
        center.xMm + ring * math.cos(angle),
        center.yMm + ring * math.sin(angle),
      ),
    );
  }
  return points;
}

List<PhysicalPoint> _twoMoonPoints(PhysicalPoint center) {
  final separation = BoardUnderlay.moonRadiusMm * 1.12;
  return [
    ..._moonPoints(PhysicalPoint(center.xMm - separation, center.yMm)),
    ..._moonPoints(PhysicalPoint(center.xMm + separation, center.yMm)),
  ];
}

List<PhysicalPoint> _petalPoints(PhysicalPoint center) {
  const radius = BoardUnderlay.petalRadiusMm;
  return [
    for (var i = 0; i < 10; i += 1)
      PhysicalPoint(
        center.xMm + radius * math.cos(-math.pi / 2 + i * math.pi / 5),
        center.yMm + radius * math.sin(-math.pi / 2 + i * math.pi / 5),
      ),
  ];
}

List<PhysicalPoint> _worldWarPoints(PhysicalPoint center) {
  const horizontal = 52.0;
  const vertical = 38.0;
  const spread = 12.0;
  final continentCenters = <PhysicalPoint>[
    PhysicalPoint(center.xMm - horizontal, center.yMm - vertical),
    PhysicalPoint(center.xMm - horizontal * 0.72, center.yMm + vertical),
    PhysicalPoint(center.xMm - 8, center.yMm - vertical * 1.12),
    PhysicalPoint(center.xMm + 1, center.yMm + vertical * 0.60),
    PhysicalPoint(center.xMm + horizontal * 0.70, center.yMm - vertical * 0.86),
    PhysicalPoint(center.xMm + horizontal, center.yMm + vertical * 1.06),
  ];
  return [
    for (var c = 0; c < continentCenters.length; c += 1)
      for (var i = 0; i < 3; i += 1)
        PhysicalPoint(
          continentCenters[c].xMm + spread * math.cos((i + c * 0.2) * 2 * math.pi / 3),
          continentCenters[c].yMm + spread * math.sin((i + c * 0.2) * 2 * math.pi / 3),
        ),
  ];
}

List<PhysicalPoint> _wheelPoints(PhysicalPoint center) {
  final points = <PhysicalPoint>[];
  const count = 10;
  final step = 2 * math.pi / count;
  final vertices = <PhysicalPoint>[
    for (var i = 0; i < count; i += 1)
      PhysicalPoint(
        center.xMm +
            BoardUnderlay.wheelPlayableRadiusMm *
                math.cos(-math.pi / 2 + i * step),
        center.yMm +
            BoardUnderlay.wheelPlayableRadiusMm *
                math.sin(-math.pi / 2 + i * step),
      ),
  ];

  for (var i = 0; i < count; i += 1) {
    final a = vertices[i];
    final b = vertices[(i + 1) % count];
    final ca = _midpoint(center, a);
    final cb = _midpoint(center, b);
    final ab = _midpoint(a, b);

    points
      ..add(_centroid(center, ca, cb))
      ..add(_centroid(ca, a, ab))
      ..add(_centroid(cb, ab, b))
      ..add(_centroid(ca, ab, cb));
  }
  return points;
}

PhysicalPoint _midpoint(PhysicalPoint a, PhysicalPoint b) =>
    PhysicalPoint((a.xMm + b.xMm) / 2, (a.yMm + b.yMm) / 2);

PhysicalPoint _centroid(PhysicalPoint a, PhysicalPoint b, PhysicalPoint c) =>
    PhysicalPoint((a.xMm + b.xMm + c.xMm) / 3, (a.yMm + b.yMm + c.yMm) / 3);
'''
write('lib/domain/board_underlay.dart', underlay)

painter = read('lib/ui/board_painter.dart')
painter = replace_once(
    painter,
    '    this.roundTriangleTips = false,\n  });',
    '    this.roundTriangleTips = false,\n    this.checkerUnderlays = false,\n  });',
    'painter constructor checker',
)
painter = replace_once(
    painter,
    '  final bool roundTriangleTips;\n',
    '  final bool roundTriangleTips;\n  final bool checkerUnderlays;\n',
    'painter checker field',
)
painter = replace_regex(
    painter,
    r"  void _paintUnderlay\(Canvas canvas, Size size, BoardUnderlay underlay\) \{.*?\n  \}\n\n  void _paintRectGrid",
    r'''  void _paintUnderlay(Canvas canvas, Size size, BoardUnderlay underlay) {
    if (!underlay.isVisible) return;
    switch (underlay) {
      case BoardUnderlay.none:
        return;
      case BoardUnderlay.wheel:
        _paintWheel(canvas, size);
        return;
      case BoardUnderlay.launchpad23:
        _paintLaunchpad23(canvas, size);
        return;
      case BoardUnderlay.twinWin:
        _paintTwinWin(canvas, size);
        return;
      case BoardUnderlay.looneyLudo1:
        _paintLudoSingle(canvas, size);
        return;
      case BoardUnderlay.looneyLudo4:
        _paintLudoFour(canvas, size);
        return;
      case BoardUnderlay.volcano:
        _paintVolcano(canvas, size);
        return;
      case BoardUnderlay.lunarInvaders1:
        _paintLunarInvaders(canvas, size, twoMoons: false);
        return;
      case BoardUnderlay.lunarInvaders2:
        _paintLunarInvaders(canvas, size, twoMoons: true);
        return;
      case BoardUnderlay.petalBattle:
        _paintPetalBattle(canvas, size);
        return;
      case BoardUnderlay.worldWar5:
        _paintWorldWar5(canvas, size);
        return;
      default:
        _paintRectGrid(canvas, size, underlay);
        return;
    }
  }

  void _paintRectGrid''',
    'underlay dispatch',
)
painter = painter.replace(
    '    if (underlay.isChessLike) {',
    '    if (checkerUnderlays && underlay.supportsChecker) {',
)

launchpad = r'''  void _paintLaunchpad23(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final cell = BoardUnderlay.cellMm * logicalPixelsPerMm;
    final gap = cell * 1.08;
    final node = cell * 0.70;
    final paint = _linePaint(0.42);
    final centers = <Offset>[
      for (var row = 0; row < 3; row += 1)
        for (var column = 0; column < 3; column += 1)
          Offset(center.dx + (column - 1) * gap, center.dy + (row - 1) * gap),
    ];

    for (var row = 0; row < 3; row += 1) {
      for (var column = 0; column < 3; column += 1) {
        final index = row * 3 + column;
        if (column < 2) canvas.drawLine(centers[index], centers[index + 1], paint);
        if (row < 2) canvas.drawLine(centers[index], centers[index + 3], paint);
      }
    }

    for (var i = 0; i < centers.length; i += 1) {
      final isFactory = i == 4;
      final isLaunchpad = const {0, 2, 6, 8}.contains(i);
      final rect = Rect.fromCenter(center: centers[i], width: node, height: node);
      if (isFactory) {
        final oct = Path();
        for (var p = 0; p < 8; p += 1) {
          final angle = math.pi / 8 + p * math.pi / 4;
          final point = centers[i] + Offset(math.cos(angle), math.sin(angle)) * node * 0.53;
          if (p == 0) oct.moveTo(point.dx, point.dy); else oct.lineTo(point.dx, point.dy);
        }
        oct.close();
        canvas.drawPath(oct, _linePaint(0.62));
        _paintTinyLabel(canvas, centers[i], 'FACTORY');
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(node * 0.07)),
          _linePaint(isLaunchpad ? 0.64 : 0.40),
        );
        if (isLaunchpad) {
          final arrow = Path()
            ..moveTo(centers[i].dx, centers[i].dy - node * 0.18)
            ..lineTo(centers[i].dx + node * 0.14, centers[i].dy + node * 0.10)
            ..lineTo(centers[i].dx - node * 0.14, centers[i].dy + node * 0.10)
            ..close();
          canvas.drawPath(arrow, _linePaint(0.52));
        }
      }
    }
  }

'''
painter = replace_regex(
    painter,
    r"  void _paintLaunchpad23\(Canvas canvas, Size size\) \{.*?\n  \}\n\n  void _paintLudoFour",
    launchpad + '  void _paintLudoFour',
    'launchpad painter',
)

# Insert additional specialized board painters before the existing four-board Ludo painter.
insert_marker = '  void _paintLudoFour(Canvas canvas, Size size) {'
extra = r'''  void _paintTwinWin(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final cell = BoardUnderlay.cellMm * logicalPixelsPerMm;
    final gap = cell * 1.02;
    final radius = cell * 0.27;
    final centers = <Offset>[
      for (var row = 0; row < 3; row += 1)
        for (var column = 0; column < 3; column += 1)
          Offset(center.dx + (column - 1) * gap, center.dy + (row - 1) * gap),
    ];
    final route = <int>[0, 1, 2, 5, 8, 7, 6, 3, 0];
    for (var i = 0; i < route.length - 1; i += 1) {
      final a = centers[route[i]];
      final b = centers[route[i + 1]];
      canvas.drawLine(a, b, _linePaint(0.42));
      _paintArrowBetween(canvas, a, b, 0.58);
    }
    for (final edge in const [(1, 4), (3, 4), (5, 4), (7, 4)]) {
      final a = centers[edge.$1];
      final b = centers[edge.$2];
      canvas.drawLine(a, b, _linePaint(0.42));
      _paintArrowBetween(canvas, a, b, 0.58);
    }
    for (var i = 0; i < centers.length; i += 1) {
      canvas.drawCircle(centers[i], radius, _linePaint(i == 4 ? 0.66 : 0.48));
    }
  }

  void _paintLudoSingle(Canvas canvas, Size size) {
    _paintLudoTile(canvas, Offset(size.width / 2, size.height / 2), quarterTurns: 0);
  }

  void _paintVolcano(Canvas canvas, Size size) {
    _paintRectGrid(canvas, size, BoardUnderlay.volcano);
    final cell = BoardUnderlay.cellMm * logicalPixelsPerMm;
    final board = cell * 5;
    final left = (size.width - board) / 2;
    final top = (size.height - board) / 2;
    final guide = _linePaint(0.36);
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 8; i += 1) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final inner = board * 0.53;
      final outer = board * 0.60;
      final a = center + Offset(math.cos(angle), math.sin(angle)) * inner;
      final b = center + Offset(math.cos(angle), math.sin(angle)) * outer;
      canvas.drawLine(a, b, guide);
      _paintArrowBetween(canvas, a, b, 0.78);
    }
    final centerCell = Rect.fromCenter(center: center, width: cell, height: cell);
    canvas.drawRect(centerCell.deflate(cell * 0.09), _linePaint(0.20));
    canvas.drawRect(Rect.fromLTWH(left, top, board, board), _linePaint(0.46));
  }

  void _paintLunarInvaders(Canvas canvas, Size size, {required bool twoMoons}) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = BoardUnderlay.moonRadiusMm * logicalPixelsPerMm;
    final separation = radius * 1.12;
    final centers = twoMoons
        ? [Offset(center.dx - separation, center.dy), Offset(center.dx + separation, center.dy)]
        : [center];
    for (final moon in centers) {
      _paintMoon(canvas, moon, radius);
    }
  }

  void _paintMoon(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, _linePaint(0.46));
    final ring = radius * 0.63;
    final points = <Offset>[
      for (var i = 0; i < 8; i += 1)
        center + Offset(math.cos(-math.pi / 2 + i * math.pi / 4), math.sin(-math.pi / 2 + i * math.pi / 4)) * ring,
    ];
    for (var i = 0; i < 8; i += 1) {
      canvas.drawLine(points[i], points[(i + 1) % 8], _linePaint(0.28));
      if (i.isOdd) canvas.drawLine(center, points[i], _linePaint(0.26));
    }
    canvas.drawCircle(center, radius * 0.17, _linePaint(0.64));
    for (var i = 0; i < points.length; i += 1) {
      if (i.isEven) {
        final side = radius * 0.24;
        canvas.drawRect(Rect.fromCenter(center: points[i], width: side, height: side), _linePaint(0.50));
      } else {
        final r = radius * 0.14;
        final angle = -math.pi / 2 + i * math.pi / 4;
        final triangle = Path();
        for (var p = 0; p < 3; p += 1) {
          final a = angle + p * 2 * math.pi / 3;
          final q = points[i] + Offset(math.cos(a), math.sin(a)) * r;
          if (p == 0) triangle.moveTo(q.dx, q.dy); else triangle.lineTo(q.dx, q.dy);
        }
        triangle.close();
        canvas.drawPath(triangle, _linePaint(0.50));
      }
    }
  }

  void _paintPetalBattle(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbit = BoardUnderlay.petalRadiusMm * logicalPixelsPerMm;
    final petalLength = orbit * 0.58;
    final petalWidth = orbit * 0.31;
    for (var i = 0; i < 10; i += 1) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final petalCenter = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle + math.pi / 2);
      final rect = Rect.fromCenter(center: Offset.zero, width: petalWidth, height: petalLength);
      canvas.drawOval(rect, _linePaint(0.46));
      canvas.restore();
    }
    canvas.drawCircle(center, orbit * 0.25, _linePaint(0.24));
  }

  void _paintWorldWar5(Canvas canvas, Size size) {
    final centerMm = PhysicalPoint(size.width / logicalPixelsPerMm / 2, size.height / logicalPixelsPerMm / 2);
    final pointsMm = BoardUnderlay.worldWar5.snapPoints(
      boardWidthMm: size.width / logicalPixelsPerMm,
      boardHeightMm: size.height / logicalPixelsPerMm,
    );
    final points = [for (final p in pointsMm) Offset(p.xMm * logicalPixelsPerMm, p.yMm * logicalPixelsPerMm)];
    const labels = ['N AM', 'S AM', 'EUR', 'AFR', 'ASIA', 'OCE'];
    for (var continent = 0; continent < 6; continent += 1) {
      final trio = points.sublist(continent * 3, continent * 3 + 3);
      final path = Path()..moveTo(trio[0].dx, trio[0].dy);
      path.lineTo(trio[1].dx, trio[1].dy);
      path.lineTo(trio[2].dx, trio[2].dy);
      path.close();
      canvas.drawPath(path, _linePaint(0.34));
      for (final p in trio) canvas.drawCircle(p, 8, _linePaint(0.55));
      final labelCenter = Offset(
        trio.map((p) => p.dx).reduce((a, b) => a + b) / 3,
        trio.map((p) => p.dy).reduce((a, b) => a + b) / 3,
      );
      _paintTinyLabel(canvas, labelCenter, labels[continent]);
    }
    const links = <(int, int)>[
      (1, 6), (2, 3), (3, 9), (4, 10), (5, 9), (6, 9),
      (7, 12), (8, 13), (10, 13), (11, 15), (12, 15), (14, 16),
      (2, 10), (11, 16),
    ];
    final routePaint = _linePaint(0.24);
    for (final link in links) canvas.drawLine(points[link.$1], points[link.$2], routePaint);
    // Two corrected sea routes called out in Looney Labs' notes on the Arcade board.
    final special = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, logicalPixelsPerMm * 0.16);
    canvas.drawLine(points[2], points[10], special);
    canvas.drawLine(points[11], points[16], special);
    // Keep center reference implicit; this avoids a large decorative map consuming space.
    final _ = centerMm;
  }

  void _paintTinyLabel(Canvas canvas, Offset center, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white54, fontSize: 7)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  void _paintArrowBetween(Canvas canvas, Offset from, Offset to, double fraction) {
    final point = Offset.lerp(from, to, fraction)!;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const length = 7.0;
    const width = 3.0;
    final back = point - Offset(math.cos(angle), math.sin(angle)) * length;
    final normal = Offset(-math.sin(angle), math.cos(angle));
    final path = Path()
      ..moveTo(point.dx, point.dy)
      ..lineTo(back.dx + normal.dx * width, back.dy + normal.dy * width)
      ..moveTo(point.dx, point.dy)
      ..lineTo(back.dx - normal.dx * width, back.dy - normal.dy * width);
    canvas.drawPath(path, _linePaint(0.48));
  }

'''
painter = replace_once(painter, insert_marker, extra + insert_marker, 'extra board painters')

# Make Ludo spaces separated instead of a conventional continuous grid.
painter = replace_regex(
    painter,
    r"    final paint = _linePaint\(0\.3\);\n    for \(var i = 0; i <= 3; i \+= 1\) \{.*?\n    \}\n\n    // Direction topology",
    r'''    final paint = _linePaint(0.34);
    final space = cell * 0.78;
    for (var row = 0; row < 3; row += 1) {
      for (var column = 0; column < 3; column += 1) {
        final c = Offset(left + (column + 0.5) * cell, top + (row + 0.5) * cell);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: space, height: space),
            Radius.circular(cell * 0.08),
          ),
          paint,
        );
      }
    }

    // Direction topology''',
    'ludo separated spaces',
)

# Round only the apex of flat triangles, and a little more strongly.
apex_helper = r'''  Path _apexRoundedTriangle(List<Offset> points, double radius) {
    final apex = points[0];
    final right = points[1];
    final left = points[2];
    final incoming = _toward(apex, left, radius);
    final outgoing = _toward(apex, right, radius);
    return Path()
      ..moveTo(incoming.dx, incoming.dy)
      ..quadraticBezierTo(apex.dx, apex.dy, outgoing.dx, outgoing.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
  }

'''
painter = replace_once(painter, '  Path _roundedPolygon(List<Offset> points, double radius) {', apex_helper + '  Path _roundedPolygon(List<Offset> points, double radius) {', 'apex helper')
painter = painter.replace(
    '? _roundedPolygon(points, math.min(base, flatLength) * 0.075)',
    '? _apexRoundedTriangle(points, math.min(base, flatLength) * 0.12)',
)

painter = replace_once(
    painter,
    '      oldDelegate.burstProgress != burstProgress;',
    '      oldDelegate.burstProgress != burstProgress ||\n      oldDelegate.roundTriangleTips != roundTriangleTips ||\n      oldDelegate.checkerUnderlays != checkerUnderlays ||\n      oldDelegate.triangleBouncePhase != triangleBouncePhase ||\n      oldDelegate.squareChasePhase != squareChasePhase;',
    'painter repaint flags',
)
write('lib/ui/board_painter.dart', painter)

# Extend snap-point regression coverage.
test = read('test/domain/board_underlay_test.dart')
test = replace_once(
    test,
    "  test('Looney Ludo four-board start exposes four 3 by 3 grids', () {",
    "  test('special boards expose useful snap locations', () {\n    expect(\n      BoardUnderlay.lunarInvaders1.snapPoints(\n        boardWidthMm: 300,\n        boardHeightMm: 300,\n      ),\n      hasLength(9),\n    );\n    expect(\n      BoardUnderlay.lunarInvaders2.snapPoints(\n        boardWidthMm: 300,\n        boardHeightMm: 300,\n      ),\n      hasLength(18),\n    );\n    expect(\n      BoardUnderlay.petalBattle.snapPoints(\n        boardWidthMm: 300,\n        boardHeightMm: 300,\n      ),\n      hasLength(10),\n    );\n    expect(\n      BoardUnderlay.worldWar5.snapPoints(\n        boardWidthMm: 300,\n        boardHeightMm: 300,\n      ),\n      hasLength(18),\n    );\n  });\n\n  test('Looney Ludo four-board start exposes four 3 by 3 grids', () {",
    'underlay tests',
)
write('test/domain/board_underlay_test.dart', test)

print('revision v4 underlays applied')
