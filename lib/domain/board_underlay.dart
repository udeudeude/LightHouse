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
  sandships,
  martianBackgammon,
  worldWar5,
  infiniteSquare,
  infiniteHex;

  static const double cellMm = 27;
  static const double coasterMm = 101.6;
  static const double wheelOuterRadiusMm = 127;
  static const double moonRadiusMm = 48;
  static const double petalRadiusMm = 40;

  bool get isVisible => this != BoardUnderlay.none;

  BoardUnderlayGroup? get group => switch (this) {
    BoardUnderlay.none => null,
    BoardUnderlay.grid3x3 ||
    BoardUnderlay.grid3x4 ||
    BoardUnderlay.grid4x4 ||
    BoardUnderlay.grid5x5 ||
    BoardUnderlay.grid5x6 ||
    BoardUnderlay.infiniteSquare ||
    BoardUnderlay.infiniteHex => BoardUnderlayGroup.grids,
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
    BoardUnderlay.sandships => 'Sandships',
    BoardUnderlay.martianBackgammon => 'Martian Backgammon',
    BoardUnderlay.worldWar5 => 'World War 5',
    BoardUnderlay.infiniteSquare => 'Infinite square grid',
    BoardUnderlay.infiniteHex => 'Infinite hex grid',
  };

  List<PhysicalPoint> snapPoints({
    required double boardWidthMm,
    required double boardHeightMm,
  }) {
    final center = PhysicalPoint(boardWidthMm / 2, boardHeightMm / 2);
    if (isRectangularGrid) {
      return _rectGridPoints(center, columns, rows);
    }
    if (this == BoardUnderlay.infiniteSquare) {
      return _infiniteSquareGridPoints(
        boardWidthMm: boardWidthMm,
        boardHeightMm: boardHeightMm,
      );
    }
    if (this == BoardUnderlay.infiniteHex) {
      return _infiniteHexGridPoints(
        boardWidthMm: boardWidthMm,
        boardHeightMm: boardHeightMm,
      );
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
      BoardUnderlay.sandships => _sandshipsPoints(center),
      BoardUnderlay.martianBackgammon => _rectGridPoints(center, 5, 5),
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

List<PhysicalPoint> _infiniteSquareGridPoints({
  required double boardWidthMm,
  required double boardHeightMm,
}) {
  final centerX = boardWidthMm / 2;
  final centerY = boardHeightMm / 2;
  final maxColumns = (boardWidthMm / BoardUnderlay.cellMm).ceil() + 2;
  final maxRows = (boardHeightMm / BoardUnderlay.cellMm).ceil() + 2;
  return [
    for (var row = -maxRows; row <= maxRows; row += 1)
      for (var column = -maxColumns; column <= maxColumns; column += 1)
        PhysicalPoint(
          centerX + column * BoardUnderlay.cellMm,
          centerY + row * BoardUnderlay.cellMm,
        ),
  ];
}

List<PhysicalPoint> _infiniteHexGridPoints({
  required double boardWidthMm,
  required double boardHeightMm,
}) {
  final radius = BoardUnderlay.cellMm / math.sqrt(3);
  final horizontalStep = radius * 1.5;
  final verticalStep = BoardUnderlay.cellMm;
  final centerX = boardWidthMm / 2;
  final centerY = boardHeightMm / 2;
  final maxColumns = (boardWidthMm / horizontalStep).ceil() + 3;
  final maxRows = (boardHeightMm / verticalStep).ceil() + 3;
  return [
    for (var column = -maxColumns; column <= maxColumns; column += 1)
      for (var row = -maxRows; row <= maxRows; row += 1)
        PhysicalPoint(
          centerX + column * horizontalStep,
          centerY + row * verticalStep + (column.isOdd ? verticalStep / 2 : 0),
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

List<PhysicalPoint> _sandshipsPoints(PhysicalPoint center) => [
  center,
  PhysicalPoint(center.xMm - 58, center.yMm - 48),
  PhysicalPoint(center.xMm + 58, center.yMm - 48),
  PhysicalPoint(center.xMm + 58, center.yMm + 48),
  PhysicalPoint(center.xMm - 58, center.yMm + 48),
];

List<PhysicalPoint> _worldWarPoints(PhysicalPoint center) {
  const horizontal = 52.0;
  const vertical = 38.0;
  const spread = 12.0;
  final portraitCenters = <PhysicalPoint>[
    PhysicalPoint(center.xMm - horizontal, center.yMm - vertical),
    PhysicalPoint(center.xMm - horizontal * 0.72, center.yMm + vertical),
    PhysicalPoint(center.xMm - 8, center.yMm - vertical * 1.12),
    PhysicalPoint(center.xMm + 1, center.yMm + vertical * 0.60),
    PhysicalPoint(center.xMm + horizontal * 0.70, center.yMm - vertical * 0.86),
    PhysicalPoint(center.xMm + horizontal, center.yMm + vertical * 1.06),
  ];
  final continentCenters = [
    for (final point in portraitCenters)
      PhysicalPoint(
        center.xMm - (point.yMm - center.yMm),
        center.yMm + (point.xMm - center.xMm),
      ),
  ];
  return [
    for (var c = 0; c < continentCenters.length; c += 1)
      for (var i = 0; i < 3; i += 1)
        PhysicalPoint(
          continentCenters[c].xMm +
              spread * math.cos(math.pi / 2 + (i + c * 0.2) * 2 * math.pi / 3),
          continentCenters[c].yMm +
              spread * math.sin(math.pi / 2 + (i + c * 0.2) * 2 * math.pi / 3),
        ),
  ];
}

List<PhysicalPoint> _wheelPoints(PhysicalPoint center) {
  // Region centroids derived from the line topology in Pyramid Love 3.1's
  // UsefulSVG/WheelBoard.svg. The source drawing is scaled to LightHouse's
  // existing 254 mm outer width rather than treating SVG units as millimeters.
  const sourceCenter = PhysicalPoint(147.6495, 146.4045);
  const sourceHalfWidth = 141.2275;
  const sourceRegionCentroids = <PhysicalPoint>[
    PhysicalPoint(236.159564, 173.468715),
    PhysicalPoint(193.387726, 160.996004),
    PhysicalPoint(255.509074, 181.359971),
    PhysicalPoint(203.076805, 220.275369),
    PhysicalPoint(176.075398, 185.091698),
    PhysicalPoint(214.608130, 238.280786),
    PhysicalPoint(148.722688, 238.574446),
    PhysicalPoint(147.906025, 194.410607),
    PhysicalPoint(148.008944, 259.923083),
    PhysicalPoint(93.984964, 221.270510),
    PhysicalPoint(81.297373, 238.759558),
    PhysicalPoint(119.639308, 185.389094),
    PhysicalPoint(40.311932, 182.084593),
    PhysicalPoint(102.067394, 161.481484),
    PhysicalPoint(60.069751, 175.112984),
    PhysicalPoint(59.621840, 118.552678),
    PhysicalPoint(101.912618, 131.811778),
    PhysicalPoint(39.465759, 111.821460),
    PhysicalPoint(92.830267, 71.858206),
    PhysicalPoint(80.340799, 54.842708),
    PhysicalPoint(119.224770, 107.715177),
    PhysicalPoint(147.017949, 53.704377),
    PhysicalPoint(147.394187, 98.396393),
    PhysicalPoint(147.066937, 32.722905),
    PhysicalPoint(201.374554, 70.773129),
    PhysicalPoint(175.659878, 107.409972),
    PhysicalPoint(214.111690, 54.251864),
    PhysicalPoint(235.457072, 116.651759),
    PhysicalPoint(193.224683, 131.322936),
    PhysicalPoint(255.460011, 111.046028),
  ];
  final sourceToMm = BoardUnderlay.wheelOuterRadiusMm / sourceHalfWidth;
  return [
    for (final point in sourceRegionCentroids)
      PhysicalPoint(
        center.xMm + (point.xMm - sourceCenter.xMm) * sourceToMm,
        center.yMm + (point.yMm - sourceCenter.yMm) * sourceToMm,
      ),
  ];
}
