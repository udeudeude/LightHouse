import 'dart:math' as math;

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
          continentCenters[c].xMm +
              spread * math.cos((i + c * 0.2) * 2 * math.pi / 3),
          continentCenters[c].yMm +
              spread * math.sin((i + c * 0.2) * 2 * math.pi / 3),
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
