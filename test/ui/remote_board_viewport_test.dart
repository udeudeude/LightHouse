import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/remote_board_viewport.dart';

void main() {
  test('fits a landscape remote display inside a portrait controller', () {
    final rect = fitRemoteBoardRect(
      hostSize: const Size(390, 844),
      safePadding: const EdgeInsets.fromLTRB(0, 47, 0, 34),
      remoteSize: const Size(160, 100),
    );

    expect(rect.width / rect.height, closeTo(1.6, 0.0001));
    expect(rect.width, closeTo(390, 0.0001));
    expect(rect.height, closeTo(243.75, 0.0001));
    expect(rect.left, closeTo(0, 0.0001));
    expect(rect.center.dy, closeTo((47 + (844 - 34)) / 2, 0.0001));
  });

  test(
    'preserves controller safe padding while centering the remote display',
    () {
      final rect = fitRemoteBoardRect(
        hostSize: const Size(1000, 700),
        safePadding: const EdgeInsets.fromLTRB(20, 10, 30, 40),
        remoteSize: const Size(4, 3),
      );

      expect(rect.top, closeTo(10, 0.0001));
      expect(rect.height, closeTo(650, 0.0001));
      expect(rect.width, closeTo(650 * 4 / 3, 0.0001));
      expect(rect.center.dx, closeTo((20 + (1000 - 30)) / 2, 0.0001));
    },
  );

  test(
    'zoom holds the chosen point fixed and clamps the pan to the screen',
    () {
      const size = Size(320, 180);
      const focal = Offset(240, 90);
      const original = RemoteViewTransform();
      final zoomed = original.zoomAt(size, 2, focal);

      expect(zoomed.boardPointAt(size, focal), focal);
      expect(zoomed.zoom, 2);
      expect(zoomed.pan.dx, -80);
      expect(zoomed.pan.dy, 0);

      final moved = zoomed.panBy(size, const Offset(900, -900));
      expect(moved.pan, const Offset(160, -90));
      expect(moved.boardPointAt(size, const Offset(0, 0)), const Offset(0, 90));
      expect(moved.zoomAt(size, 1, size.center(Offset.zero)).pan, Offset.zero);
    },
  );
  testWidgets('visual zoom maps taps back to unzoomed board coordinates', (
    tester,
  ) async {
    final frameKey = GlobalKey();
    Offset? localTap;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: frameKey,
            width: 300,
            height: 200,
            child: ClipRect(
              child: Transform.translate(
                offset: const Offset(-50, 0),
                child: Transform.scale(
                  scale: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => localTap = details.localPosition,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byKey(frameKey)) + const Offset(150, 100),
    );
    expect(localTap, isNotNull);
    expect(localTap!.dx, closeTo(175, 0.01));
    expect(localTap!.dy, closeTo(100, 0.01));
  });
}
