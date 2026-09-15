import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/domain/board_underlay.dart';
import 'package:lighthouse/domain/physical_point.dart';

void main() {
  test('wheel exposes forty snap locations', () {
    final points = BoardUnderlay.wheel.snapPoints(
      boardWidthMm: 300,
      boardHeightMm: 300,
    );
    expect(points, hasLength(40));
  });

  test('Launchpad 23 exposes a centered 3 by 3 snap grid', () {
    final points = BoardUnderlay.launchpad23.snapPoints(
      boardWidthMm: 200,
      boardHeightMm: 300,
    );
    expect(points, hasLength(9));
    expect(points[4], const PhysicalPoint(100, 150));
  });

  test('special boards expose useful snap locations', () {
    expect(
      BoardUnderlay.lunarInvaders1.snapPoints(
        boardWidthMm: 300,
        boardHeightMm: 300,
      ),
      hasLength(9),
    );
    expect(
      BoardUnderlay.lunarInvaders2.snapPoints(
        boardWidthMm: 300,
        boardHeightMm: 300,
      ),
      hasLength(18),
    );
    expect(
      BoardUnderlay.petalBattle.snapPoints(
        boardWidthMm: 300,
        boardHeightMm: 300,
      ),
      hasLength(10),
    );
    expect(
      BoardUnderlay.sandships.snapPoints(boardWidthMm: 300, boardHeightMm: 300),
      hasLength(5),
    );
    expect(
      BoardUnderlay.martianBackgammon.snapPoints(
        boardWidthMm: 300,
        boardHeightMm: 300,
      ),
      hasLength(25),
    );
    expect(
      BoardUnderlay.worldWar5.snapPoints(boardWidthMm: 300, boardHeightMm: 300),
      hasLength(18),
    );
  });

  test('Petal Battle moves its petal centers inward', () {
    final points = BoardUnderlay.petalBattle.snapPoints(
      boardWidthMm: 300,
      boardHeightMm: 300,
    );
    expect(points.first.yMm, closeTo(104, 0.001));
  });

  test('World War 5 is oriented sideways', () {
    final points = BoardUnderlay.worldWar5.snapPoints(
      boardWidthMm: 300,
      boardHeightMm: 300,
    );
    final xs = points.map((p) => p.xMm);
    final ys = points.map((p) => p.yMm);
    final xSpan = xs.reduce(math.max) - xs.reduce(math.min);
    final ySpan = ys.reduce(math.max) - ys.reduce(math.min);
    expect(ySpan, greaterThan(xSpan));
  });

  test('Looney Ludo four-board start exposes four 3 by 3 grids', () {
    final points = BoardUnderlay.looneyLudo4.snapPoints(
      boardWidthMm: 300,
      boardHeightMm: 300,
    );
    expect(points, hasLength(36));
  });
}
