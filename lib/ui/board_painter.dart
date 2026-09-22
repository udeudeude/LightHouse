import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/board_state.dart';
import '../domain/board_underlay.dart';
import '../domain/light_element.dart';
import '../domain/physical_point.dart';
import 'special_board_painter.dart';
import '../domain/pyramid_geometry.dart';

class BoardPainter extends CustomPainter {
  const BoardPainter({
    required this.state,
    required this.logicalPixelsPerMm,
    required this.geometry,
    this.selectedId,
    this.elementOpacities = const {},
    this.burstCenter,
    this.burstProgress,
    this.triangleBouncePhase,
    this.squareChasePhase,
    this.squareChaseSeed = 0,
    this.roundTriangleTips = false,
    this.checkerUnderlays = false,
  });

  final BoardState state;
  final double logicalPixelsPerMm;
  final PyramidGeometryProfile geometry;
  final String? selectedId;
  final Map<String, double> elementOpacities;
  final PhysicalPoint? burstCenter;
  final double? burstProgress;
  final double? triangleBouncePhase;
  final double? squareChasePhase;
  final int squareChaseSeed;
  final bool roundTriangleTips;
  final bool checkerUnderlays;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    _paintUnderlay(canvas, size, state.underlay);
    for (var index = 0; index < state.elements.length; index += 1) {
      final element = state.elements[index];
      _paintElement(
        canvas,
        element,
        elementOpacities[element.id] ?? 1,
        chaseIndex: index,
      );
    }
    _paintBurst(canvas, size);
  }

  Paint _linePaint([double alpha = 0.34]) => Paint()
    ..color = Color.fromRGBO(255, 255, 255, alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.7, logicalPixelsPerMm * 0.18);

  void _paintUnderlay(Canvas canvas, Size size, BoardUnderlay underlay) {
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
      case BoardUnderlay.sandships:
        SpecialBoardPainter(logicalPixelsPerMm).paintSandships(canvas, size);
        return;
      case BoardUnderlay.martianBackgammon:
        SpecialBoardPainter(logicalPixelsPerMm)
            .paintMartianBackgammon(canvas, size);
        return;
      case BoardUnderlay.worldWar5:
        _paintWorldWar5(canvas, size);
        return;
      case BoardUnderlay.infiniteSquare:
        _paintInfiniteSquareGrid(canvas, size);
        return;
      case BoardUnderlay.infiniteHex:
        _paintInfiniteHexGrid(canvas, size);
        return;
      default:
        _paintRectGrid(canvas, size, underlay);
        return;
    }
  }

  void _paintInfiniteSquareGrid(Canvas canvas, Size size) {
    final cell = BoardUnderlay.cellMm * logicalPixelsPerMm;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = _linePaint();

    final firstVertical =
        center.dx - (center.dx / cell).ceil() * cell - cell / 2;
    for (var x = firstVertical; x <= size.width + cell; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final firstHorizontal =
        center.dy - (center.dy / cell).ceil() * cell - cell / 2;

    if (checkerUnderlays) {
      final shade = Paint()..color = const Color(0x18FFFFFF);
      var row = 0;
      for (
        var y = firstHorizontal;
        y <= size.height + cell;
        y += cell, row += 1
      ) {
        var column = 0;
        for (
          var x = firstVertical;
          x <= size.width + cell;
          x += cell, column += 1
        ) {
          if ((row + column).isOdd) {
            canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), shade);
          }
        }
      }
    }

    for (var y = firstHorizontal; y <= size.height + cell; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintInfiniteHexGrid(Canvas canvas, Size size) {
    final radius = BoardUnderlay.cellMm / math.sqrt(3) * logicalPixelsPerMm;
    final horizontalStep = radius * 1.5;
    final verticalStep = BoardUnderlay.cellMm * logicalPixelsPerMm;
    final center = Offset(size.width / 2, size.height / 2);
    final maxColumns = (size.width / horizontalStep).ceil() + 4;
    final maxRows = (size.height / verticalStep).ceil() + 4;
    final paint = _linePaint();

    for (var column = -maxColumns; column <= maxColumns; column += 1) {
      final cx = center.dx + column * horizontalStep;
      final yOffset = column.isOdd ? verticalStep / 2 : 0.0;
      for (var row = -maxRows; row <= maxRows; row += 1) {
        final cy = center.dy + row * verticalStep + yOffset;
        if (cx < -radius ||
            cx > size.width + radius ||
            cy < -verticalStep ||
            cy > size.height + verticalStep) {
          continue;
        }
        final path = Path();
        for (var i = 0; i < 6; i += 1) {
          final angle = math.pi / 3 * i;
          final point = Offset(
            cx + math.cos(angle) * radius,
            cy + math.sin(angle) * radius,
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  void _paintRectGrid(Canvas canvas, Size size, BoardUnderlay underlay) {
    final cell = BoardUnderlay.cellMm * logicalPixelsPerMm;
    final boardWidth = underlay.columns * cell;
    final boardHeight = underlay.rows * cell;
    final left = (size.width - boardWidth) / 2;
    final top = (size.height - boardHeight) / 2;
    final gridPaint = _linePaint();

    if (checkerUnderlays && underlay.supportsChecker) {
      final shade = Paint()..color = const Color(0x18FFFFFF);
      for (var row = 0; row < underlay.rows; row += 1) {
        for (var column = 0; column < underlay.columns; column += 1) {
          if ((row + column).isEven) continue;
          canvas.drawRect(
            Rect.fromLTWH(left + column * cell, top + row * cell, cell, cell),
            shade,
          );
        }
      }
    }

    for (var column = 0; column <= underlay.columns; column += 1) {
      final x = left + column * cell;
      canvas.drawLine(Offset(x, top), Offset(x, top + boardHeight), gridPaint);
    }
    for (var row = 0; row <= underlay.rows; row += 1) {
      final y = top + row * cell;
      canvas.drawLine(Offset(left, y), Offset(left + boardWidth, y), gridPaint);
    }
  }

  void _paintLaunchpad23(Canvas canvas, Size size) {
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
        if (column < 2)
          canvas.drawLine(centers[index], centers[index + 1], paint);
        if (row < 2) canvas.drawLine(centers[index], centers[index + 3], paint);
      }
    }

    for (var i = 0; i < centers.length; i += 1) {
      final isFactory = i == 4;
      final isLaunchpad = const {0, 2, 6, 8}.contains(i);
      final rect = Rect.fromCenter(
        center: centers[i],
        width: node,
        height: node,
      );
      if (isFactory) {
        final oct = Path();
        for (var p = 0; p < 8; p += 1) {
          final angle = math.pi / 8 + p * math.pi / 4;
          final point =
              centers[i] +
              Offset(math.cos(angle), math.sin(angle)) * node * 0.53;
          if (p == 0) {
            oct.moveTo(point.dx, point.dy);
          } else {
            oct.lineTo(point.dx, point.dy);
          }
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
          const launchpadLabels = <int, String>{
            0: 'LAUNCH PAD 23-A',
            2: 'LAUNCH PAD 23-B',
            8: 'LAUNCH PAD 23-C',
            6: 'LAUNCH PAD 23-D',
          };
          final arrow = Path()
            ..moveTo(centers[i].dx, centers[i].dy - node * 0.24)
            ..lineTo(centers[i].dx + node * 0.11, centers[i].dy - node * 0.02)
            ..lineTo(centers[i].dx - node * 0.11, centers[i].dy - node * 0.02)
            ..close();
          canvas.drawPath(arrow, _linePaint(0.52));
          _paintTinyLabel(
            canvas,
            centers[i] + Offset(0, node * 0.19),
            launchpadLabels[i]!,
            fontSize: 5.5,
          );
        } else {
          _paintTinyLabel(canvas, centers[i], 'STORAGE DEPOT', fontSize: 5.5);
        }
      }
    }
  }

  void _paintTwinWin(Canvas canvas, Size size) {
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
      _paintArrowBetween(canvas, a, b, 0.62);
      _paintArrowBetween(canvas, b, a, 0.62);
    }
    for (var i = 0; i < centers.length; i += 1) {
      canvas.drawCircle(centers[i], radius, _linePaint(i == 4 ? 0.66 : 0.48));
    }
  }

  void _paintLudoSingle(Canvas canvas, Size size) {
    _paintLudoTile(
      canvas,
      Offset(size.width / 2, size.height / 2),
      quarterTurns: 0,
    );
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
    final centerCell = Rect.fromCenter(
      center: center,
      width: cell,
      height: cell,
    );
    canvas.drawRect(centerCell.deflate(cell * 0.09), _linePaint(0.20));
    canvas.drawRect(Rect.fromLTWH(left, top, board, board), _linePaint(0.46));
  }

  void _paintLunarInvaders(Canvas canvas, Size size, {required bool twoMoons}) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = BoardUnderlay.moonRadiusMm * logicalPixelsPerMm;
    final separation = radius * 1.12;
    final centers = twoMoons
        ? [
            Offset(center.dx - separation, center.dy),
            Offset(center.dx + separation, center.dy),
          ]
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
        center +
            Offset(
                  math.cos(-math.pi / 2 + i * math.pi / 4),
                  math.sin(-math.pi / 2 + i * math.pi / 4),
                ) *
                ring,
    ];
    for (var i = 0; i < 8; i += 1) {
      canvas.drawLine(points[i], points[(i + 1) % 8], _linePaint(0.28));
      if (i.isOdd) canvas.drawLine(center, points[i], _linePaint(0.26));
    }
    canvas.drawCircle(center, radius * 0.17, _linePaint(0.64));
    for (var i = 0; i < points.length; i += 1) {
      if (i.isEven) {
        final side = radius * 0.24;
        canvas.drawRect(
          Rect.fromCenter(center: points[i], width: side, height: side),
          _linePaint(0.50),
        );
      } else {
        final r = radius * 0.14;
        final angle = -math.pi / 2 + i * math.pi / 4;
        final triangle = Path();
        for (var p = 0; p < 3; p += 1) {
          final a = angle + p * 2 * math.pi / 3;
          final q = points[i] + Offset(math.cos(a), math.sin(a)) * r;
          if (p == 0)
            triangle.moveTo(q.dx, q.dy);
          else
            triangle.lineTo(q.dx, q.dy);
        }
        triangle.close();
        canvas.drawPath(triangle, _linePaint(0.50));
      }
    }
  }

  void _paintPetalBattle(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbit = BoardUnderlay.petalRadiusMm * logicalPixelsPerMm;
    final petalLength = 31.3 * logicalPixelsPerMm;
    final petalWidth = 16.7 * logicalPixelsPerMm;
    for (var i = 0; i < 10; i += 1) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final petalCenter =
          center + Offset(math.cos(angle), math.sin(angle)) * orbit;
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle + math.pi / 2);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: petalWidth,
        height: petalLength,
      );
      canvas.drawOval(rect, _linePaint(0.46));
      canvas.restore();
    }
    canvas.drawCircle(center, 13.5 * logicalPixelsPerMm, _linePaint(0.24));
  }

  void _paintWorldWar5(Canvas canvas, Size size) {
    final centerMm = PhysicalPoint(
      size.width / logicalPixelsPerMm / 2,
      size.height / logicalPixelsPerMm / 2,
    );
    final pointsMm = BoardUnderlay.worldWar5.snapPoints(
      boardWidthMm: size.width / logicalPixelsPerMm,
      boardHeightMm: size.height / logicalPixelsPerMm,
    );
    final points = [
      for (final p in pointsMm)
        Offset(p.xMm * logicalPixelsPerMm, p.yMm * logicalPixelsPerMm),
    ];
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
      _paintTinyLabel(
        canvas,
        labelCenter,
        labels[continent],
        angleRadians: math.pi / 2,
      );
    }
    const links = <(int, int)>[
      (1, 6),
      (2, 3),
      (3, 9),
      (4, 10),
      (5, 9),
      (6, 9),
      (7, 12),
      (8, 13),
      (10, 13),
      (11, 15),
      (12, 15),
      (14, 16),
      (2, 10),
      (11, 16),
    ];
    final routePaint = _linePaint(0.24);
    for (final link in links)
      canvas.drawLine(points[link.$1], points[link.$2], routePaint);
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

  void _paintTinyLabel(
    Canvas canvas,
    Offset center,
    String text, {
    double angleRadians = 0,
    double fontSize = 7,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.white54, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (angleRadians == 0) {
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
      return;
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angleRadians);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  void _paintArrowBetween(
    Canvas canvas,
    Offset from,
    Offset to,
    double fraction,
  ) {
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

  void _paintLudoFour(Canvas canvas, Size size) {
    final boardCenter = Offset(size.width / 2, size.height / 2);
    final tile = BoardUnderlay.coasterMm * logicalPixelsPerMm;
    for (var row = 0; row < 2; row += 1) {
      for (var column = 0; column < 2; column += 1) {
        final center = Offset(
          boardCenter.dx + (column == 0 ? -tile / 2 : tile / 2),
          boardCenter.dy + (row == 0 ? -tile / 2 : tile / 2),
        );
        // The reference tile's dot is at its upper-left corner. Rotate each
        // tile so the four dots meet at the center of the starting layout.
        final quarterTurns = switch ((row, column)) {
          (0, 0) => 2,
          (0, 1) => 3,
          (1, 0) => 1,
          _ => 0,
        };
        _paintLudoTile(canvas, center, quarterTurns: quarterTurns);
      }
    }
  }

  void _paintLudoTile(
    Canvas canvas,
    Offset center, {
    required int quarterTurns,
  }) {
    final tile = BoardUnderlay.coasterMm * logicalPixelsPerMm;
    final cell = BoardUnderlay.cellMm * logicalPixelsPerMm;
    final gridSize = 3 * cell;
    final left = -gridSize / 2;
    final top = -gridSize / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(quarterTurns * math.pi / 2);

    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: tile, height: tile),
      _linePaint(0.22),
    );

    final paint = _linePaint(0.34);
    final space = cell * 0.78;
    for (var row = 0; row < 3; row += 1) {
      for (var column = 0; column < 3; column += 1) {
        final c = Offset(
          left + (column + 0.5) * cell,
          top + (row + 0.5) * cell,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: space, height: space),
            Radius.circular(cell * 0.08),
          ),
          paint,
        );
      }
    }

    // Direction topology from the Looney Ludo board. The art is intentionally
    // reduced to small line arrowheads so this remains a functional underlay,
    // not a reproduction of the printed board artwork.
    const arrows = <List<int>>[
      [1 | 2 | 4, 8 | 2 | 4, 8 | 1 | 2],
      [8 | 1 | 2, 1 | 2 | 4, 1 | 2 | 4],
      [8 | 2 | 4, 8 | 1 | 2 | 4, 8 | 1 | 2],
    ];
    const up = 1;
    const right = 2;
    const down = 4;
    const leftDirection = 8;
    for (var row = 0; row < 3; row += 1) {
      for (var column = 0; column < 3; column += 1) {
        final mask = arrows[row][column];
        final cellCenter = Offset(
          left + (column + 0.5) * cell,
          top + (row + 0.5) * cell,
        );
        if ((mask & up) != 0) {
          _paintArrowhead(canvas, cellCenter, cell, -math.pi / 2);
        }
        if ((mask & right) != 0) {
          _paintArrowhead(canvas, cellCenter, cell, 0);
        }
        if ((mask & down) != 0) {
          _paintArrowhead(canvas, cellCenter, cell, math.pi / 2);
        }
        if ((mask & leftDirection) != 0) {
          _paintArrowhead(canvas, cellCenter, cell, math.pi);
        }
      }
    }

    final homePaint = _linePaint(0.46);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: cell * 0.58,
        height: cell * 0.58,
      ),
      homePaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: cell * 0.34,
        height: cell * 0.34,
      ),
      homePaint,
    );
    canvas.drawCircle(Offset.zero, cell * 0.12, homePaint);

    final dot = Offset(-tile / 2 + 5, -tile / 2 + 5);
    canvas.drawCircle(
      dot,
      math.max(1.4, logicalPixelsPerMm * 1.1),
      Paint()..color = const Color(0x66FFFFFF),
    );
    canvas.restore();
  }

  void _paintArrowhead(
    Canvas canvas,
    Offset cellCenter,
    double cell,
    double angle,
  ) {
    final edge = cell * 0.43;
    final tip = Offset(
      cellCenter.dx + edge * math.cos(angle),
      cellCenter.dy + edge * math.sin(angle),
    );
    final inward = Offset(
      cellCenter.dx + cell * 0.26 * math.cos(angle),
      cellCenter.dy + cell * 0.26 * math.sin(angle),
    );
    final normal = Offset(-math.sin(angle), math.cos(angle));
    final halfWidth = cell * 0.07;
    final arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        inward.dx + normal.dx * halfWidth,
        inward.dy + normal.dy * halfWidth,
      )
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        inward.dx - normal.dx * halfWidth,
        inward.dy - normal.dy * halfWidth,
      );
    canvas.drawPath(arrow, _linePaint(0.52));
  }

  void _paintWheel(Canvas canvas, Size size) {
    // Topology transcribed from Pyramid Love 3.1's WheelBoard.svg and scaled
    // to LightHouse's existing physical outer radius. SVG coordinates are
    // reference geometry only, not physical measurements.
    const sourceCenter = Offset(147.6495, 146.4045);
    const sourceHalfWidth = 141.2275;
    const outer = <Offset>[
      Offset(192.044, 280.474),
      Offset(104.760, 280.964),
      Offset(33.858, 230.056),
      Offset(6.422, 147.194),
      Offset(32.930, 64.032),
      Offset(103.256, 12.333),
      Offset(190.540, 11.845),
      Offset(261.441, 62.753),
      Offset(288.877, 145.614),
      Offset(262.369, 228.774),
    ];
    const inner = <Offset>[
      Offset(123.665, 74.585),
      Offset(170.458, 74.203),
      Offset(208.540, 101.397),
      Offset(223.366, 145.784),
      Offset(209.271, 190.407),
      Offset(171.636, 218.221),
      Offset(124.843, 218.604),
      Offset(86.759, 191.410),
      Offset(71.933, 147.022),
      Offset(86.030, 102.400),
    ];
    const star = <Offset>[
      Offset(86.030, 102.400),
      Offset(68.483, 38.823),
      Offset(123.743, 74.203),
      Offset(146.487, 12.333),
      Offset(170.798, 73.778),
      Offset(225.163, 36.751),
      Offset(208.604, 101.585),
      Offset(274.461, 102.751),
      Offset(223.310, 145.614),
      Offset(275.551, 185.125),
      Offset(209.526, 189.596),
      Offset(228.017, 252.406),
      Offset(171.431, 218.223),
      Offset(150.013, 278.896),
      Offset(124.674, 218.485),
      Offset(71.334, 254.477),
      Offset(86.194, 189.712),
      Offset(22.037, 188.476),
      Offset(71.933, 147.194),
      Offset(20.948, 106.104),
    ];
    const diameters = <(Offset, Offset)>[
      (Offset(103.256, 12.333), Offset(192.044, 280.474)),
      (Offset(190.540, 11.845), Offset(104.760, 280.964)),
      (Offset(33.858, 230.056), Offset(262.639, 61.858)),
      (Offset(288.877, 145.614), Offset(6.422, 147.194)),
      (Offset(262.369, 228.774), Offset(32.930, 64.032)),
    ];

    final center = Offset(size.width / 2, size.height / 2);
    final sourceToPixels =
        BoardUnderlay.wheelOuterRadiusMm * logicalPixelsPerMm / sourceHalfWidth;

    Offset mapPoint(Offset point) =>
        center + (point - sourceCenter) * sourceToPixels;

    Path polygon(List<Offset> points) {
      final path = Path();
      for (var i = 0; i < points.length; i += 1) {
        final point = mapPoint(points[i]);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      return path..close();
    }

    canvas.drawPath(polygon(outer), _linePaint(0.24));
    canvas.drawPath(polygon(inner), _linePaint(0.38));
    canvas.drawPath(polygon(star), _linePaint(0.38));
    final diameterPaint = _linePaint(0.38);
    for (final line in diameters) {
      canvas.drawLine(mapPoint(line.$1), mapPoint(line.$2), diameterPaint);
    }
  }

  Offset _toward(Offset from, Offset to, double distance) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length <= 0.001) return from;
    final t = math.min(0.45, distance / length);
    return Offset(from.dx + dx * t, from.dy + dy * t);
  }

  Path _apexRoundedTriangle(List<Offset> points, double radius) {
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

  void _paintElement(
    Canvas canvas,
    LightElement element,
    double opacity, {
    required int chaseIndex,
  }) {
    if (opacity <= 0) return;
    final alpha = opacity.clamp(0.0, 1.0).toDouble();
    final white = Color.fromRGBO(255, 255, 255, alpha);
    final center = Offset(
      element.position.xMm * logicalPixelsPerMm,
      element.position.yMm * logicalPixelsPerMm,
    );
    final base = geometry.baseMm(element.size) * logicalPixelsPerMm;
    final flatLength = geometry.flatLengthMm(element.size) * logicalPixelsPerMm;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(element.headingDegrees * math.pi / 180);

    if (element.pose == PyramidPose.upright) {
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: base,
        height: base,
      );
      if (element.illumination == IlluminationPattern.full) {
        canvas.drawRect(rect, Paint()..color = white);
      } else {
        final band = geometry.wallBandMm * logicalPixelsPerMm;
        final inner = rect.deflate(band.clamp(0, base / 2).toDouble());
        final ring = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect)
          ..addRect(inner);
        final chase = squareChasePhase;
        if (chase == null) {
          canvas.drawPath(ring, Paint()..color = white);
        } else {
          canvas.drawPath(
            ring,
            Paint()..color = Color.fromRGBO(255, 255, 255, 0.055 * alpha),
          );
          final chasePath = Path()..addRect(rect.deflate(band / 2));
          final metric = chasePath.computeMetrics().first;
          final seed =
              (element.id.hashCode ^ squareChaseSeed ^ (chaseIndex * 0x45d9f3b)) &
              0x7fffffff;
          final offset = (seed % 1000) / 1000;
          final clockwise = ((seed ~/ 1000) & 1) == 0;
          final localPhase = clockwise
              ? (chase + offset) % 1
              : (offset - chase) % 1;
          final start = metric.length * localPhase;
          final span = metric.length * 0.19;
          final chasePaint = Paint()
            ..color = white
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, band)
            ..strokeCap = StrokeCap.round;
          if (start + span <= metric.length) {
            canvas.drawPath(
              metric.extractPath(start, start + span),
              chasePaint,
            );
          } else {
            canvas.drawPath(
              metric.extractPath(start, metric.length),
              chasePaint,
            );
            canvas.drawPath(
              metric.extractPath(0, start + span - metric.length),
              chasePaint,
            );
          }
        }
      }
      if (element.id == selectedId && alpha > 0.15) {
        canvas.drawRect(
          rect.inflate(3),
          Paint()
            ..color = Color.fromRGBO(255, 255, 255, 0.34 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    } else {
      final footprintLength = switch (element.kind) {
        LightPieceKind.pyramid || LightPieceKind.block => flatLength,
        LightPieceKind.wedge =>
          element.wedgeFlatFace == WedgeFlatFace.rectangle
              ? math.sqrt(base * base + flatLength * flatLength)
              : flatLength,
      };
      final triangular =
          element.kind == LightPieceKind.pyramid ||
          (element.kind == LightPieceKind.wedge &&
              element.wedgeFlatFace == WedgeFlatFace.triangle);

      if (triangular) {
        final points = <Offset>[
          Offset(0, -footprintLength / 2),
          Offset(base / 2, footprintLength / 2),
          Offset(-base / 2, footprintLength / 2),
        ];
        final triangle = roundTriangleTips
            ? _apexRoundedTriangle(
                points,
                math.min(base, footprintLength) * 0.18,
              )
            : (Path()
                ..moveTo(points[0].dx, points[0].dy)
                ..lineTo(points[1].dx, points[1].dy)
                ..lineTo(points[2].dx, points[2].dy)
                ..close());
        final bounce = triangleBouncePhase;
        if (bounce == null || element.kind != LightPieceKind.pyramid) {
          canvas.drawPath(triangle, Paint()..color = white);
        } else {
          canvas.drawPath(
            triangle,
            Paint()..color = Color.fromRGBO(255, 255, 255, 0.045 * alpha),
          );
          final y = -footprintLength / 2 + footprintLength * bounce.clamp(0, 1);
          final band = math.max(3.0, footprintLength * 0.16);
          canvas.save();
          canvas.clipPath(triangle);
          canvas.drawRect(
            Rect.fromLTWH(-base, y - band / 2, base * 2, band),
            Paint()..color = white,
          );
          canvas.restore();
        }
        if (element.id == selectedId && alpha > 0.15) {
          canvas.drawPath(
            triangle,
            Paint()
              ..color = Color.fromRGBO(255, 255, 255, 0.34 * alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      } else {
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: base,
          height: footprintLength,
        );
        canvas.drawRect(rect, Paint()..color = white);
        if (element.id == selectedId && alpha > 0.15) {
          canvas.drawRect(
            rect.inflate(3),
            Paint()
              ..color = Color.fromRGBO(255, 255, 255, 0.34 * alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }

    canvas.restore();
  }

  void _paintBurst(Canvas canvas, Size size) {
    final centerMm = burstCenter;
    final progress = burstProgress;
    if (centerMm == null || progress == null || progress < 0 || progress > 1) {
      return;
    }
    final center = Offset(
      centerMm.xMm * logicalPixelsPerMm,
      centerMm.yMm * logicalPixelsPerMm,
    );
    final farthest = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final radius = farthest * (0.04 + progress * 0.96);
    final alpha = (1 - progress).clamp(0.0, 1.0).toDouble();
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, 0.78 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, 4 * (1 - progress));
    canvas.drawCircle(center, radius, paint);

    const rays = 20;
    for (var i = 0; i < rays; i += 1) {
      final angle = 2 * math.pi * i / rays;
      final inner = radius * 0.7;
      final outer = radius * (0.94 + 0.12 * (i.isEven ? 1 : 0));
      canvas.drawLine(
        Offset(
          center.dx + inner * math.cos(angle),
          center.dy + inner * math.sin(angle),
        ),
        Offset(
          center.dx + outer * math.cos(angle),
          center.dy + outer * math.sin(angle),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.logicalPixelsPerMm != logicalPixelsPerMm ||
      oldDelegate.geometry != geometry ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.elementOpacities != elementOpacities ||
      oldDelegate.burstCenter != burstCenter ||
      oldDelegate.burstProgress != burstProgress ||
      oldDelegate.roundTriangleTips != roundTriangleTips ||
      oldDelegate.checkerUnderlays != checkerUnderlays ||
      oldDelegate.triangleBouncePhase != triangleBouncePhase ||
      oldDelegate.squareChasePhase != squareChasePhase;
}
