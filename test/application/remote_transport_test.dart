import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/application/remote_transport.dart';

void main() {
  test('direct transport is preferred over relay', () async {
    final calls = <String>[];
    final direct = CallbackRemoteAppTransport(
      kind: RemoteTransportKind.direct,
      label: 'Direct',
      isAvailable: () => true,
      sender: (message) async {
        calls.add('direct:${message.kind}');
      },
    );
    final relay = CallbackRemoteAppTransport(
      kind: RemoteTransportKind.encryptedRelay,
      label: 'Encrypted relay',
      isAvailable: () => true,
      sender: (message) async {
        calls.add('relay:${message.kind}');
      },
    );
    final router = RemoteTransportRouter([direct, relay]);

    final used = await router.send(
      const RemoteTransportMessage('state', {'xMm': 12.5, 'role': 'controller'}),
    );

    expect(used, RemoteTransportKind.direct);
    expect(calls, ['direct:state']);
  });

  test('relay is used when direct transport is unavailable', () async {
    final messages = <RemoteTransportMessage>[];
    final router = RemoteTransportRouter([
      CallbackRemoteAppTransport(
        kind: RemoteTransportKind.direct,
        label: 'Direct',
        isAvailable: () => false,
        sender: (_) async {},
      ),
      CallbackRemoteAppTransport(
        kind: RemoteTransportKind.encryptedRelay,
        label: 'Encrypted relay',
        isAvailable: () => true,
        sender: (message) async {
          messages.add(message);
        },
      ),
    ]);

    const message = RemoteTransportMessage('state', {
      'xMm': 17.25,
      'yMm': 44.0,
      'role': 'display',
    });
    final used = await router.send(message);

    expect(used, RemoteTransportKind.encryptedRelay);
    expect(messages, hasLength(1));
    expect(identical(messages.single, message), isTrue);
    expect(messages.single.payload['xMm'], 17.25);
    expect(messages.single.payload['role'], 'display');
  });

  test('router falls through when the preferred transport fails', () async {
    var relayCalls = 0;
    final router = RemoteTransportRouter([
      CallbackRemoteAppTransport(
        kind: RemoteTransportKind.direct,
        label: 'Direct',
        isAvailable: () => true,
        sender: (_) async => throw StateError('direct link dropped'),
      ),
      CallbackRemoteAppTransport(
        kind: RemoteTransportKind.encryptedRelay,
        label: 'Encrypted relay',
        isAvailable: () => true,
        sender: (_) async {
          relayCalls += 1;
        },
      ),
    ]);

    final used = await router.send(
      const RemoteTransportMessage('runtime', {'toyClock': 3.5}),
    );

    expect(used, RemoteTransportKind.encryptedRelay);
    expect(relayCalls, 1);
  });
}
