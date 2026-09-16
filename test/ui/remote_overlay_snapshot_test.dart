import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/dice_bubble.dart';
import 'package:lighthouse/ui/zendo_stones.dart';

void main() {
  test('dice bubble snapshot round trips', () {
    const source = DiceBubbleSnapshot(
      revision: 7,
      rollSerial: 3,
      selectedIds: ['standard-1', 'pyramid'],
      faces: {'standard-1': 5, 'pyramid': 2},
      xFraction: 0.37,
      yFraction: 0.61,
    );
    final decoded = DiceBubbleSnapshot.fromJson(source.toJson());
    expect(decoded, isNotNull);
    expect(decoded!.revision, 7);
    expect(decoded.rollSerial, 3);
    expect(decoded.selectedIds, ['standard-1', 'pyramid']);
    expect(decoded.faces['standard-1'], 5);
    expect(decoded.xFraction, closeTo(0.37, 0.0001));
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
