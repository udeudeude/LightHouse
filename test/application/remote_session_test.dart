import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/application/remote_session.dart';

void main() {
  test('pairing link keeps the secret in the URL fragment', () {
    final session = RemoteSession.create(RemoteRole.display);
    final uri = session.joinUri(
      Uri.parse('https://example.test/LightHouse/?v=5'),
    );

    expect(uri.queryParameters['v'], '5');
    expect(uri.queryParameters.containsKey(RemoteLaunch.roomParameter), isFalse);
    expect(uri.queryParameters.containsKey(RemoteLaunch.keyParameter), isFalse);
    expect(uri.queryParameters.containsKey(RemoteLaunch.roleParameter), isFalse);
    expect(uri.fragment, isNotEmpty);

    final fragment = Uri.splitQueryString(uri.fragment);
    expect(fragment[RemoteLaunch.roomParameter], session.roomId);
    expect(fragment[RemoteLaunch.keyParameter], isNotEmpty);
    expect(fragment[RemoteLaunch.roleParameter], RemoteRole.controller.name);

    final launch = RemoteLaunch.fromUri(uri);
    expect(launch, isNotNull);
    expect(launch!.roomId, session.roomId);
    expect(launch.role, RemoteRole.controller);
    expect(launch.keyBytes, hasLength(32));
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
}
