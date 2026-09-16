import 'package:flutter/widgets.dart';
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
}
