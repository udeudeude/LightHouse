import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/dice_bubble.dart';
import 'package:lighthouse/ui/zendo_stones.dart';

void main() {
  test('dice bubble snapshot round trips duplicate die kinds', () {
    const source = DiceBubbleSnapshot(
      revision: 7,
      rollSerial: 3,
      selectedIds: ['standard#4', 'standard#5', 'pyramid#6'],
      faces: {'standard#4': 5, 'standard#5': 1, 'pyramid#6': 2},
      xFraction: 0.37,
      yFraction: 0.61,
    );
    final decoded = DiceBubbleSnapshot.fromJson(source.toJson());
    expect(decoded, isNotNull);
    expect(decoded!.revision, 7);
    expect(decoded.rollSerial, 3);
    expect(decoded.selectedIds, ['standard#4', 'standard#5', 'pyramid#6']);
    expect(decoded.faces['standard#4'], 5);
    expect(decoded.faces['standard#5'], 1);
    expect(decoded.xFraction, closeTo(0.37, 0.0001));
  });

  test('dice selector exposes each die kind once', () {
    expect(arcadeDiceChoices, hasLength(6));
    expect(
      arcadeDiceChoices.map((choice) => choice.kind).toSet(),
      hasLength(6),
    );
    expect(arcadeDiceChoices.map((choice) => choice.id), contains('fate'));
  });

  test('legacy physical dice identifiers remain readable', () {
    expect(arcadeDieBaseId('standard-3'), 'standard');
    expect(arcadeDieBaseId('lightning-2'), 'lightning');
    expect(isKnownArcadeDieInstance('standard-1'), isTrue);
    expect(isKnownArcadeDieInstance('lightning-3'), isTrue);

    const legacy = DiceBubbleSnapshot(
      revision: 2,
      rollSerial: 1,
      selectedIds: ['standard-1', 'lightning-2', 'color'],
      faces: {'standard-1': 4, 'lightning-2': 3, 'color': 1},
      xFraction: 0.2,
      yFraction: 0.3,
    );
    final decoded = DiceBubbleSnapshot.fromJson(legacy.toJson());

    expect(decoded, isNotNull);
    expect(decoded!.selectedIds, legacy.selectedIds);
  });

  test('zendo stones snapshot round trips', () {
    const source = ZendoStonesSnapshot(
      revision: 4,
      stones: [
        ZendoStoneSnapshot(
          id: 9,
          kind: 'green',
          xFraction: 0.2,
          yFraction: 0.8,
        ),
      ],
    );
    final decoded = ZendoStonesSnapshot.fromJson(source.toJson());
    expect(decoded, isNotNull);
    expect(decoded!.revision, 4);
    expect(decoded.stones.single.kind, 'green');
    expect(decoded.stones.single.id, 9);
  });
}
