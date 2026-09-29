import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/application/remote_session.dart';

void main() {
  test('legacy fragment links can still admit multiple controllers', () {
    final key = base64UrlEncode(List<int>.generate(32, (index) => index))
        .replaceAll('=', '');
    final uri = Uri.parse(
      'https://example.test/LightHouse/'
      '#lhRoom=abcdefghijkl&lhKey=$key&lhRole=controller',
    );
    final first = RemoteLaunch.fromUri(uri);
    final second = RemoteLaunch.fromUri(uri);

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.roomId, 'abcdefghijkl');
    expect(second!.roomId, 'abcdefghijkl');
    expect(first.role, RemoteRole.controller);
    expect(second.role, RemoteRole.controller);
    expect(first.keyBytes, second.keyBytes);
  });

  test('legacy query-string pairing links remain compatible', () {
    final key = base64UrlEncode(List<int>.generate(32, (index) => index))
        .replaceAll('=', '');
    final launch = RemoteLaunch.fromUri(
      Uri.parse(
        'https://example.test/LightHouse/'
        '?lhRoom=abcdefghijkl&lhKey=$key&lhRole=display',
      ),
    );

    expect(launch, isNotNull);
    expect(launch!.roomId, 'abcdefghijkl');
    expect(launch.role, RemoteRole.display);
    expect(launch.keyBytes, hasLength(32));
  });

  test('fragment pairing data takes precedence over legacy query data', () {
    final oldKey = base64UrlEncode(List<int>.filled(32, 1)).replaceAll('=', '');
    final newKey = base64UrlEncode(List<int>.filled(32, 2)).replaceAll('=', '');
    final launch = RemoteLaunch.fromUri(
      Uri.parse(
        'https://example.test/LightHouse/'
        '?lhRoom=oldoldoldold&lhKey=$oldKey&lhRole=display'
        '#lhRoom=newnewnewnew&lhKey=$newKey&lhRole=controller',
      ),
    );

    expect(launch, isNotNull);
    expect(launch!.roomId, 'newnewnewnew');
    expect(launch.role, RemoteRole.controller);
    expect(launch.keyBytes, everyElement(2));
  });

  test('invalid pairing keys are rejected', () {
    final launch = RemoteLaunch.fromUri(
      Uri.parse(
        'https://example.test/#lhRoom=abcdefghijkl&lhKey=bad&lhRole=display',
      ),
    );
    expect(launch, isNull);
  });

  test(
    'shared pairing code derives the same room and secret on both devices',
    () async {
      final display = await RemoteSession.fromPairingCode(
        'k7m-4q2',
        RemoteRole.display,
      );
      final controller = await RemoteSession.fromPairingCode(
        'K7M4Q2',
        RemoteRole.controller,
      );

      expect(display.roomId, controller.roomId);
      expect(display.isCreator, isTrue);
      expect(controller.isCreator, isFalse);

      expect(display.pairingCode, 'K7M4Q2');
      expect(controller.pairingCode, display.pairingCode);
    },
  );

  test('pairing codes normalize case and separators', () {
    expect(RemoteSession.normalizePairingCode(' k7m-4q2 '), 'K7M4Q2');
    expect(RemoteSession.isValidPairingCode('K7M 4Q2'), isTrue);
    expect(RemoteSession.isValidPairingCode('12345'), isFalse);
  });

  test('invalid shared pairing code is rejected', () async {
    expect(
      () => RemoteSession.fromPairingCode('12345', RemoteRole.display),
      throwsArgumentError,
    );
  });
}
