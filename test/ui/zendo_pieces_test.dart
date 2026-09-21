import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/zendo_pieces.dart';

void main() {
  test('boxed Zendo wedge uses right-triangle geometry', () {
    expect(zendoMediumBaseMm, closeTo(19.84375, 0.00001));
    expect(zendoMediumHeightMm, closeTo(34.925, 0.00001));
    expect(
      zendoWedgeSlopedLengthMm,
      closeTo(
        math.sqrt(
          zendoMediumBaseMm * zendoMediumBaseMm +
              zendoMediumHeightMm * zendoMediumHeightMm,
        ),
        0.00001,
      ),
    );
  });

  test('Zendo piece snapshots round-trip', () {
    const snapshot = ZendoPiecesSnapshot(
      revision: 4,
      pieces: [
        ZendoPieceSnapshot(
          id: 7,
          kind: 'wedge',
          pose: 'doorstop',
          size: 'medium',
          xFraction: 0.3,
          yFraction: 0.6,
          headingDegrees: 45,
        ),
      ],
    );
    final restored = ZendoPiecesSnapshot.fromJson(snapshot.toJson());
    expect(restored, isNotNull);
    expect(restored!.revision, 4);
    expect(restored.pieces.single.kind, 'wedge');
    expect(restored.pieces.single.pose, 'doorstop');
    expect(restored.pieces.single.size, 'medium');
    expect(restored.pieces.single.headingDegrees, 45);
  });

  testWidgets('all Zendo piece-set trays render', (tester) async {
    for (final set in ZendoPieceSet.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 480,
            height: 720,
            child: ZendoPiecesWidget(
              pixelsPerMm: 2,
              pieceSet: set,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
