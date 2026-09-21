import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/dice_bubble.dart';

void main() {
  test('Lightning and Treehouse dice use dark bodies', () {
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.lightning), isTrue);
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.treehouse), isTrue);
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.standard), isFalse);
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.pyramid), isFalse);
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.color), isFalse);
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.fate), isFalse);
  });

  test('Lightning die exposes the Pyramid Love symbol set', () {
    expect(
      [for (var face = 0; face < 6; face += 1) lightningDieFaceSymbol(face)],
      ['bolt', 'atom', 'split-circle', 'arrow', 'pyramids', 'recycle'],
    );
  });

  test('Pyramid die exposes the source size combinations', () {
    expect(
      [for (var face = 0; face < 6; face += 1) pyramidDieFaceSymbol(face)],
      [
        'small',
        'medium',
        'large',
        'small-medium',
        'small-large',
        'medium-large',
      ],
    );
    expect(pyramidDieHeightToBaseRatio, closeTo(1.75, 0.001));
  });

  test('Fudge / Fate die has two plus, two minus, and two blank faces', () {
    expect(
      [for (var face = 0; face < 6; face += 1) fateDieFaceSymbol(face)],
      ['+', '+', '-', '-', '', ''],
    );
    expect(isKnownArcadeDieInstance('fate#17'), isTrue);
  });

  test('selector tile cycle respects remaining three-die capacity', () {
    expect(
      [
        for (var value = 0; value < 4; value += 1)
          nextArcadeDieCount(current: value, otherSelected: 0),
      ],
      [1, 2, 3, 0],
    );
    expect(
      [
        for (var value = 0; value < 3; value += 1)
          nextArcadeDieCount(current: value, otherSelected: 1),
      ],
      [1, 2, 0],
    );
    expect(
      [
        for (var value = 0; value < 2; value += 1)
          nextArcadeDieCount(current: value, otherSelected: 2),
      ],
      [1, 0],
    );
    expect(nextArcadeDieCount(current: 0, otherSelected: 3), 0);
  });

  test('empty Dice Bubble spider stays inside its normalized roaming area', () {
    expect(diceBubbleSpiderPoint(0), Offset.zero);
    for (var serial = 1; serial <= 50; serial += 1) {
      expect(diceBubbleSpiderPoint(serial).distance, lessThanOrEqualTo(0.47));
    }
  });
  testWidgets('Dice Bubble paints the spider and revised special dice', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 320,
          child: DiceBubble(
            snapshot: DiceBubbleSnapshot(
              revision: 1,
              rollSerial: 3,
              selectedIds: [],
              faces: {},
              xFraction: 0.5,
              yFraction: 0.5,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 320,
          child: DiceBubble(
            snapshot: DiceBubbleSnapshot(
              revision: 2,
              rollSerial: 4,
              selectedIds: ['pyramid#1', 'treehouse#2', 'fate#3'],
              faces: {'pyramid#1': 2, 'treehouse#2': 3, 'fate#3': 0},
              xFraction: 0.5,
              yFraction: 0.5,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

}
