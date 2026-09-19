import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/application/remote_control_state.dart';

void main() {
  test('ripple marking cycles normal to dim to off', () {
    const initial = RemoteBoardControlState();

    final normal = initial.cycleRipple('a');
    expect(normal.rippleLevels['a'], RemoteRippleLevel.normal);

    final dim = normal.cycleRipple('a');
    expect(dim.rippleLevels['a'], RemoteRippleLevel.dim);

    final off = dim.cycleRipple('a');
    expect(off.rippleLevels.containsKey('a'), isFalse);
  });

  test('control state round-trips and defaults safely', () {
    final state = RemoteBoardControlState(
      displayInteractionsEnabled: true,
      displayShapesVisible: false,
      rippleLevels: const {
        'a': RemoteRippleLevel.normal,
        'b': RemoteRippleLevel.dim,
      },
    );

    final decoded = RemoteBoardControlState.fromJson(state.toJson());

    expect(decoded.displayInteractionsEnabled, isTrue);
    expect(decoded.displayShapesVisible, isFalse);
    expect(decoded.rippleLevels, state.rippleLevels);
  });

  test('retainElementIds removes ripples for deleted shapes', () {
    final state = RemoteBoardControlState(
      rippleLevels: const {
        'keep': RemoteRippleLevel.normal,
        'remove': RemoteRippleLevel.dim,
      },
    );

    final retained = state.retainElementIds({'keep'});

    expect(retained.rippleLevels.keys, ['keep']);
  });
}
