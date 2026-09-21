import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/pyramid_love_toy_icon.dart';

void main() {
  testWidgets('requested Pyramid Love toy icons render without path errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            PyramidLoveToyIcon(
              PyramidLoveToyIconKind.nest,
              color: Colors.white,
            ),
            PyramidLoveToyIcon(
              PyramidLoveToyIconKind.zendoMarkers,
              color: Colors.white,
            ),
            PyramidLoveToyIcon(
              PyramidLoveToyIconKind.eastQueen,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
