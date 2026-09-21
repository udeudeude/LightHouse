import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/dice_bubble.dart';

void main() {
  test('Lightning and Treehouse dice use dark bodies', () {
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.lightning), isTrue);
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.treehouse), isTrue);
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.standard), isFalse);
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.pyramid), isFalse);
    expect(arcadeDieUsesDarkBody(ArcadeDieKind.color), isFalse);
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
  });
}
