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

  test('polyhedral dice expose the expected face counts', () {
    expect(arcadeDieSides(ArcadeDieKind.d4), 4);
    expect(arcadeDieSides(ArcadeDieKind.d8), 8);
    expect(arcadeDieSides(ArcadeDieKind.d10), 10);
    expect(arcadeDieSides(ArcadeDieKind.d12), 12);
    expect(arcadeDieSides(ArcadeDieKind.d20), 20);
  });

  test('D10 kite short edges are about three quarters of long edges', () {
    expect(d10KiteTargetEdgeRatio, 0.75);
    expect(d10KiteShortToLongEdgeRatio(), closeTo(0.75, 0.002));
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
  testWidgets('two-finger pinch resizes the Dice Bubble', (tester) async {
    DiceBubbleSnapshot? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 640,
          child: DiceBubble(
            snapshot: const DiceBubbleSnapshot(
              revision: 20,
              rollSerial: 0,
              selectedIds: ['standard#1'],
              faces: {'standard#1': 0},
              xFraction: 0.5,
              yFraction: 0.4,
            ),
            onChanged: (snapshot) => latest = snapshot,
          ),
        ),
      ),
    );

    final target = find.byKey(const Key('dice-bubble-gesture'));
    final center = tester.getCenter(target);
    final first = await tester.startGesture(
      center + const Offset(-20, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveTo(center + const Offset(-42, 0));
    await second.moveTo(center + const Offset(42, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(latest, isNotNull);
    expect(latest!.sizeScale, greaterThan(1.0));
  });

  testWidgets('polyhedral dice render together without painter errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 360,
          height: 640,
          child: DiceBubble(
            snapshot: DiceBubbleSnapshot(
              revision: 21,
              rollSerial: 7,
              selectedIds: ['d4#1', 'd10#2', 'd20#3'],
              faces: {'d4#1': 3, 'd10#2': 9, 'd20#3': 19},
              xFraction: 0.5,
              yFraction: 0.4,
              sizeScale: 1.9,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('d8 and d12 render together without painter errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 360,
          height: 640,
          child: DiceBubble(
            snapshot: DiceBubbleSnapshot(
              revision: 22,
              rollSerial: 8,
              selectedIds: ['d8#1', 'd12#2'],
              faces: {'d8#1': 7, 'd12#2': 11},
              xFraction: 0.5,
              yFraction: 0.4,
              sizeScale: 0.7,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('every polyhedral result orientation paints without errors', (
    tester,
  ) async {
    const cases = <(String, int)>[
      ('d4', 4),
      ('d8', 8),
      ('d10', 10),
      ('d12', 12),
      ('d20', 20),
    ];

    var revision = 100;
    for (final dieCase in cases) {
      for (var face = 0; face < dieCase.$2; face += 1) {
        final id = '${dieCase.$1}#1';
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 360,
              height: 640,
              child: DiceBubble(
                snapshot: DiceBubbleSnapshot(
                  revision: revision,
                  rollSerial: revision,
                  selectedIds: [id],
                  faces: {id: face},
                  xFraction: 0.5,
                  yFraction: 0.4,
                  sizeScale: face.isEven ? 0.7 : 1.9,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${dieCase.$1} face ${face + 1} should paint cleanly',
        );
        revision += 1;
      }
    }
  });

  testWidgets('zero-dice selector renders all die artwork and closes cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 360,
          height: 640,
          child: DiceBubble(
            snapshot: DiceBubbleSnapshot(
              revision: 10,
              rollSerial: 2,
              selectedIds: [],
              faces: {},
              xFraction: 0.5,
              yFraction: 0.35,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('dice-selector-latch')));
    await tester.pumpAndSettle();

    expect(find.text('Dice · 0/3 selected'), findsOneWidget);
    for (final choice in arcadeDiceChoices) {
      await tester.ensureVisible(find.byTooltip(choice.label));
      expect(find.byTooltip(choice.label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    Navigator.of(tester.element(find.text('Dice · 0/3 selected'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Dice · 0/3 selected'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
