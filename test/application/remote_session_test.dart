import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/application/remote_session.dart';

void main() {
  test('pairing link round-trips session and complementary role', () {
    final session = RemoteSession.create(RemoteRole.display);
    final uri = session.joinUri(
      Uri.parse('https://example.test/LightHouse-StashBoard/?v=2'),
    );

    expect(uri.queryParameters['v'], '2');
    final launch = RemoteLaunch.fromUri(uri);
    expect(launch, isNotNull);
    expect(launch!.roomId, session.roomId);
    expect(launch.role, RemoteRole.controller);
    expect(launch.keyBytes, hasLength(32));
  });

  test('invalid pairing keys are rejected', () {
    final launch = RemoteLaunch.fromUri(
      Uri.parse(
        'https://example.test/?lhRoom=abcdefghijkl&lhKey=bad&lhRole=display',
      ),
    );
    expect(launch, isNull);
  });
}
