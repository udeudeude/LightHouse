class RemoteTransportMessage {
  const RemoteTransportMessage(this.kind, this.payload);

  final String kind;
  final Map<String, Object?> payload;
}

enum RemoteTransportKind { direct, encryptedRelay }

abstract interface class RemoteAppTransport {
  RemoteTransportKind get kind;
  String get label;
  bool get isAvailable;

  Future<void> send(RemoteTransportMessage message);
}

typedef RemoteTransportAvailability = bool Function();
typedef RemoteTransportSender = Future<void> Function(
  RemoteTransportMessage message,
);

class CallbackRemoteAppTransport implements RemoteAppTransport {
  const CallbackRemoteAppTransport({
    required this.kind,
    required this.label,
    required RemoteTransportAvailability isAvailable,
    required RemoteTransportSender sender,
  }) : _isAvailable = isAvailable,
       _sender = sender;

  @override
  final RemoteTransportKind kind;

  @override
  final String label;

  final RemoteTransportAvailability _isAvailable;
  final RemoteTransportSender _sender;

  @override
  bool get isAvailable => _isAvailable();

  @override
  Future<void> send(RemoteTransportMessage message) => _sender(message);
}

class RemoteTransportRouter {
  const RemoteTransportRouter(this.transports);

  final List<RemoteAppTransport> transports;

  RemoteAppTransport? get preferredAvailable {
    for (final transport in transports) {
      if (transport.isAvailable) return transport;
    }
    return null;
  }

  Future<RemoteTransportKind?> send(RemoteTransportMessage message) async {
    for (final transport in transports) {
      if (!transport.isAvailable) continue;
      try {
        await transport.send(message);
        return transport.kind;
      } on Object {
        // Try the next available transport.
      }
    }
    return null;
  }
}
