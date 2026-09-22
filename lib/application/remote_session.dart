import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../platform/remote_mqtt.dart';
import 'remote_transport.dart';

enum RemoteRole {
  display,
  controller;

  RemoteRole get other =>
      this == RemoteRole.display ? RemoteRole.controller : RemoteRole.display;

  String get label =>
      this == RemoteRole.display ? 'Table Display' : 'Controller';
}

class RemoteLaunch {
  const RemoteLaunch({
    required this.roomId,
    required this.keyBytes,
    required this.role,
  });

  static const roomParameter = 'lhRoom';
  static const keyParameter = 'lhKey';
  static const roleParameter = 'lhRole';

  final String roomId;
  final List<int> keyBytes;
  final RemoteRole role;

  static RemoteLaunch? fromUri(Uri uri) {
    final fragmentParameters = _fragmentParameters(uri);
    final room =
        fragmentParameters[roomParameter] ?? uri.queryParameters[roomParameter];
    final encodedKey =
        fragmentParameters[keyParameter] ?? uri.queryParameters[keyParameter];
    final roleName =
        fragmentParameters[roleParameter] ?? uri.queryParameters[roleParameter];
    if (room == null || encodedKey == null || roleName == null) return null;
    final role = RemoteRole.values
        .where((value) => value.name == roleName)
        .firstOrNull;
    if (role == null) return null;
    try {
      final key = base64Url.decode(_paddedBase64(encodedKey));
      if (key.length != 32 || room.length < 12) return null;
      return RemoteLaunch(roomId: room, keyBytes: key, role: role);
    } on FormatException {
      return null;
    }
  }

  static Map<String, String> _fragmentParameters(Uri uri) {
    if (uri.fragment.isEmpty) return const {};
    try {
      return Uri.splitQueryString(uri.fragment);
    } on FormatException {
      return const {};
    }
  }

  static String _paddedBase64(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) return value;
    return value + ('=' * (4 - remainder));
  }
}

class RemoteAppMessage {
  const RemoteAppMessage(this.kind, this.payload, {this.senderId});

  final String kind;
  final Map<String, Object?> payload;
  final String? senderId;
}

enum RemoteConnectionPhase {
  disconnected,
  connecting,
  waiting,
  connected,
  failed,
}

class RemoteSession extends ChangeNotifier {
  RemoteSession._({
    required this.roomId,
    required List<int> keyBytes,
    required this.role,
    required this.isCreator,
    this.pairingCode,
  }) : _keyBytes = List<int>.unmodifiable(keyBytes),
       _clientId = _newToken(9) {
    _transportRouter = RemoteTransportRouter([
      CallbackRemoteAppTransport(
        kind: RemoteTransportKind.direct,
        label: 'Direct',
        isAvailable: () =>
            !multipleControllers && directConnected && _dataChannel != null,
        sender: _sendDirectTransport,
      ),
      CallbackRemoteAppTransport(
        kind: RemoteTransportKind.encryptedRelay,
        label: 'Encrypted relay',
        isAvailable: () => _mqttConnected,
        sender: _sendRelayTransport,
      ),
    ]);
  }

  factory RemoteSession.create(RemoteRole role) => RemoteSession._(
    roomId: _newToken(12),
    keyBytes: _randomBytes(32),
    role: role,
    isCreator: true,
    pairingCode: null,
  );

  static const int pairingCodeLength = 6;
  static final Pbkdf2 _pairingCodeKdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 384,
  );

  static String normalizePairingCode(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValidPairingCode(String value) =>
      normalizePairingCode(value).length == pairingCodeLength;

  static Future<RemoteSession> fromPairingCode(
    String code,
    RemoteRole role,
  ) async {
    final normalized = normalizePairingCode(code);
    if (normalized.length != pairingCodeLength) {
      throw ArgumentError.value(
        code,
        'code',
        'Pairing codes must contain exactly $pairingCodeLength letters or digits.',
      );
    }
    final derived = await _pairingCodeKdf.deriveKeyFromPassword(
      password: normalized,
      nonce: utf8.encode('LightHouse Remote pairing code v1'),
    );
    final bytes = await derived.extractBytes();
    final roomId = base64UrlEncode(bytes.sublist(0, 12)).replaceAll('=', '');
    return RemoteSession._(
      roomId: roomId,
      keyBytes: bytes.sublist(16, 48),
      role: role,
      // Manual-code pairing has no link opener to establish creator status.
      // The Table Display is the stable authority, so it initiates WebRTC.
      isCreator: role == RemoteRole.display,
      pairingCode: normalized,
    );
  }

  factory RemoteSession.fromLaunch(RemoteLaunch launch) => RemoteSession._(
    roomId: launch.roomId,
    keyBytes: launch.keyBytes,
    role: launch.role,
    isCreator: false,
    pairingCode: null,
  );

  static final math.Random _random = math.Random.secure();
  static final AesGcm _cipher = AesGcm.with256bits();

  final String roomId;
  final List<int> _keyBytes;
  final String _clientId;
  final bool isCreator;
  final String? pairingCode;
  final StreamController<RemoteAppMessage> _messages =
      StreamController<RemoteAppMessage>.broadcast();
  late final RemoteTransportRouter _transportRouter;

  RemoteRole role;
  RemoteConnectionPhase phase = RemoteConnectionPhase.disconnected;
  String? errorMessage;
  bool peerSeen = false;
  bool directConnected = false;
  bool multipleControllers = false;

  MqttClient? _mqtt;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>?
  _mqttSubscription;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _closed = false;
  int _signalSequence = 0;
  Future<void>? _relayConnectFuture;
  Timer? _pairingAnnouncementTimer;
  final Set<String> _knownControllerIds = <String>{};
  String? _directPeerId;

  Stream<RemoteAppMessage> get messages => _messages.stream;
  String get clientId => _clientId;
  int get controllerCount => role == RemoteRole.display
      ? _knownControllerIds.length
      : (multipleControllers ? 2 : (peerSeen ? 1 : 0));

  String get transportLabel {
    if (multipleControllers && _mqttConnected) {
      if (role == RemoteRole.display) {
        return 'Encrypted relay · ${controllerCount} controllers';
      }
      return 'Encrypted relay · multiple controllers';
    }
    final preferred = _transportRouter.preferredAvailable;
    if (preferred?.kind == RemoteTransportKind.direct) return preferred!.label;
    if (peerSeen && preferred?.kind == RemoteTransportKind.encryptedRelay) {
      return preferred!.label;
    }
    if (_mqttConnected) return 'Waiting for peer';
    if (phase == RemoteConnectionPhase.connecting) return 'Connecting';
    return 'Offline';
  }

  bool get _mqttConnected =>
      _mqtt?.connectionStatus?.state == MqttConnectionState.connected;

  String get _encodedKey => base64UrlEncode(_keyBytes).replaceAll('=', '');

  String get _topic => 'lighthouse/remote/v1/$roomId';

  Uri joinUri(Uri current) {
    final cleanParameters = Map<String, String>.from(current.queryParameters)
      ..remove(RemoteLaunch.roomParameter)
      ..remove(RemoteLaunch.keyParameter)
      ..remove(RemoteLaunch.roleParameter);
    final fragment = Uri(
      queryParameters: {
        RemoteLaunch.roomParameter: roomId,
        RemoteLaunch.keyParameter: _encodedKey,
        RemoteLaunch.roleParameter: role.other.name,
      },
    ).query;
    return current.replace(
      queryParameters: cleanParameters,
      fragment: fragment,
    );
  }

  Future<void> connect() {
    if (_closed || directConnected || _mqttConnected) {
      return Future<void>.value();
    }
    final pending = _relayConnectFuture;
    if (pending != null) return pending;
    final future = _connectRelay();
    _relayConnectFuture = future;
    return future.whenComplete(() {
      if (identical(_relayConnectFuture, future)) {
        _relayConnectFuture = null;
      }
    });
  }

  Future<void> _connectRelay() async {
    if (_closed || directConnected || _mqttConnected) return;
    phase = RemoteConnectionPhase.connecting;
    errorMessage = null;
    notifyListeners();

    final client = createRemoteMqttClient('lh-${_clientId.substring(0, 9)}');
    _mqtt = client;
    client
      ..logging(on: false)
      ..setProtocolV311()
      ..keepAlivePeriod = 20
      ..connectTimeoutPeriod = 6000
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true;
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('lh-${_clientId.substring(0, 9)}')
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    client.onDisconnected = _handleMqttDisconnected;
    client.onAutoReconnected = () {
      if (_closed) return;
      phase = peerSeen
          ? RemoteConnectionPhase.connected
          : RemoteConnectionPhase.waiting;
      notifyListeners();
      if (!peerSeen) {
        _startPairingAnnouncements();
      }
      unawaited(_announceOnSignalChannel());
    };
    client.onSubscribed = (topic) {
      if (_closed || topic != _topic) return;
      if (!peerSeen) {
        _startPairingAnnouncements();
      }
      unawaited(_announceOnSignalChannel());
    };

    try {
      await client.connect();
    } on Object catch (error) {
      if (_closed) return;
      phase = RemoteConnectionPhase.failed;
      errorMessage = 'Could not reach the pairing service: $error';
      notifyListeners();
      return;
    }

    if (!_mqttConnected) {
      phase = RemoteConnectionPhase.failed;
      errorMessage = 'Could not reach the pairing service.';
      notifyListeners();
      return;
    }

    client.subscribe(_topic, MqttQos.atLeastOnce);
    final updates = client.updates;
    if (updates != null) {
      _mqttSubscription = updates.listen((batch) {
        for (final received in batch) {
          final message = received.payload;
          if (message is! MqttPublishMessage) continue;
          final payload = MqttPublishPayload.bytesToStringAsString(
            message.payload.message,
          );
          unawaited(_handleEncryptedSignal(payload));
        }
      });
    }
    phase = RemoteConnectionPhase.waiting;
    notifyListeners();
    _startPairingAnnouncements();
    await _announceOnSignalChannel();
  }

  void _startPairingAnnouncements() {
    _pairingAnnouncementTimer?.cancel();
    if (_closed || peerSeen || !_mqttConnected) return;
    _pairingAnnouncementTimer = Timer.periodic(
      const Duration(milliseconds: 1400),
      (_) {
        if (_closed || peerSeen || !_mqttConnected) {
          _stopPairingAnnouncements();
          return;
        }
        unawaited(_announceOnSignalChannel());
      },
    );
  }

  void _stopPairingAnnouncements() {
    _pairingAnnouncementTimer?.cancel();
    _pairingAnnouncementTimer = null;
  }

  Future<void> _announceOnSignalChannel() async {
    final identity = {'role': role.name};
    await _publishSignal('presence', identity);
    if (!isCreator) await _publishSignal('join', identity);
    if (multipleControllers) {
      await _publishSignal('multi', identity);
    }
  }

  void _handleMqttDisconnected() {
    _stopPairingAnnouncements();
    if (_closed) return;
    if (!directConnected) {
      phase = RemoteConnectionPhase.disconnected;
    }
    notifyListeners();
  }

  Future<void> _suspendRelayForDirect() async {
    if (_closed ||
        !directConnected ||
        role == RemoteRole.display ||
        multipleControllers) {
      return;
    }
    final subscription = _mqttSubscription;
    _mqttSubscription = null;
    if (subscription != null) await subscription.cancel();

    final client = _mqtt;
    _mqtt = null;
    if (client != null) {
      client.autoReconnect = false;
      try {
        client.disconnect();
      } on Object {
        // Direct transport is already active; relay cleanup is best-effort.
      }
    }
  }

  void _handleDirectUnavailable() {
    if (!directConnected) return;
    directConnected = false;
    final peerId = _directPeerId;
    _directPeerId = null;
    if (role == RemoteRole.display &&
        peerId != null &&
        _knownControllerIds.remove(peerId)) {
      notifyListeners();
    } else {
      notifyListeners();
    }
    if (!_closed) unawaited(connect());
  }

  Future<void> _rememberRelayPeer(
    String sender,
    Map<String, Object?> payload,
  ) async {
    final roleName = payload['role'];
    final peerRole = RemoteRole.values
        .where((value) => value.name == roleName)
        .firstOrNull;
    if (role != RemoteRole.display || peerRole != RemoteRole.controller) return;
    final added = _knownControllerIds.add(sender);
    if (added) notifyListeners();
    if (multipleControllers) {
      await _publishSignal('multi', {'role': role.name});
      return;
    }
    if (added && _knownControllerIds.length > 1) {
      await _enterMultipleControllerMode();
    }
  }

  Future<void> _enterMultipleControllerMode({bool announce = true}) async {
    if (multipleControllers || _closed) return;
    multipleControllers = true;

    final direct = _dataChannel;
    if (directConnected && direct != null) {
      try {
        await direct.send(
          RTCDataChannelMessage(
            jsonEncode({
              'sender': _clientId,
              'kind': '__transport_multi__',
              'payload': const <String, Object?>{},
            }),
          ),
        );
      } on Object {
        // The relay transition below still recovers the session.
      }
    }

    await _resetPeerConnection();
    if (!_mqttConnected) await connect();
    if (announce && _mqttConnected) {
      await _publishSignal('multi', {'role': role.name});
    }
    notifyListeners();
  }

  Future<void> _handleEncryptedSignal(String encoded) async {
    if (_closed) return;
    final envelope = await _decryptMap(encoded);
    if (envelope == null || envelope['sender'] == _clientId) return;
    final sender = envelope['sender'];
    final kind = envelope['kind'];
    final rawPayload = envelope['payload'];
    if (sender is! String || kind is! String || rawPayload is! Map) return;
    final payload = rawPayload.cast<String, Object?>();
    if (kind == 'presence' || kind == 'join') {
      final roleName = payload['role'];
      final peerRole = RemoteRole.values
          .where((value) => value.name == roleName)
          .firstOrNull;
      if (peerRole == role) {
        errorMessage =
            'Both devices are set to ${role.label}. Choose opposite roles.';
        notifyListeners();
        return;
      }
      await _rememberRelayPeer(sender, payload);
      if (peerRole == role.other && !peerSeen) {
        peerSeen = true;
        _stopPairingAnnouncements();
        phase = RemoteConnectionPhase.connected;
        errorMessage = null;
        notifyListeners();
      }
    } else if (!peerSeen) {
      peerSeen = true;
      _stopPairingAnnouncements();
      phase = RemoteConnectionPhase.connected;
      errorMessage = null;
      notifyListeners();
    }

    switch (kind) {
      case 'presence':
        if (!isCreator && !directConnected) {
          await _publishSignal('join', {'role': role.name});
        }
      case 'join':
        if (isCreator && !directConnected && !multipleControllers) {
          await _makeOffer();
        }
      case 'offer':
        if (!isCreator && !multipleControllers) await _acceptOffer(payload);
      case 'answer':
        if (isCreator && !multipleControllers) await _acceptAnswer(payload);
      case 'candidate':
        if (!multipleControllers) await _acceptCandidate(payload);
      case 'multi':
        await _enterMultipleControllerMode(announce: false);
      case 'bye':
        if (_knownControllerIds.remove(sender)) notifyListeners();
      case 'app':
        _deliverAppPayload(payload, senderId: sender);
    }
  }

  Future<void> _makeOffer() async {
    if (_closed || multipleControllers || _peerConnection != null) {
      return;
    }
    final pc = await _createPeerConnection();
    _peerConnection = pc;
    final channel = await pc.createDataChannel(
      'lighthouse-board',
      RTCDataChannelInit()..ordered = true,
    );
    _attachDataChannel(channel);
    final offer = await pc.createOffer({});
    await pc.setLocalDescription(offer);
    await _publishSignal('offer', {'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> _acceptOffer(Map<String, Object?> payload) async {
    if (multipleControllers) return;
    final sdp = payload['sdp'];
    final type = payload['type'];
    if (sdp is! String || type is! String) return;
    await _resetPeerConnection();
    final pc = await _createPeerConnection();
    _peerConnection = pc;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await _publishSignal('answer', {'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> _acceptAnswer(Map<String, Object?> payload) async {
    if (multipleControllers) return;
    final sdp = payload['sdp'];
    final type = payload['type'];
    final pc = _peerConnection;
    if (pc == null || sdp is! String || type is! String) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
  }

  Future<void> _acceptCandidate(Map<String, Object?> payload) async {
    if (multipleControllers) return;
    final candidateText = payload['candidate'];
    if (candidateText is! String || candidateText.isEmpty) return;
    final candidate = RTCIceCandidate(
      candidateText,
      payload['sdpMid'] as String?,
      (payload['sdpMLineIndex'] as num?)?.toInt(),
    );
    final pc = _peerConnection;
    if (pc == null || !_remoteDescriptionSet) {
      _pendingCandidates.add(candidate);
      return;
    }
    await pc.addCandidate(candidate);
  }

  Future<void> _flushPendingCandidates() async {
    final pc = _peerConnection;
    if (pc == null || !_remoteDescriptionSet) return;
    for (final candidate in List<RTCIceCandidate>.from(_pendingCandidates)) {
      await pc.addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302',
          ],
        },
      ],
      'sdpSemantics': 'unified-plan',
    });
    pc.onIceCandidate = (candidate) {
      if (multipleControllers) return;
      final text = candidate.candidate;
      if (text == null || text.isEmpty) return;
      unawaited(
        _publishSignal('candidate', {
          'candidate': text,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }),
      );
    };
    pc.onDataChannel = _attachDataChannel;
    pc.onConnectionState = (state) {
      if (_closed || !identical(_peerConnection, pc)) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (directConnected) {
          _handleDirectUnavailable();
        } else {
          unawaited(_resetPeerConnection());
        }
      }
    };
    return pc;
  }

  void _attachDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    channel.onDataChannelState = (state) {
      if (_closed) return;
      final open = state == RTCDataChannelState.RTCDataChannelOpen;
      if (directConnected == open) return;
      if (open) {
        directConnected = true;
        peerSeen = true;
        _stopPairingAnnouncements();
        phase = RemoteConnectionPhase.connected;
        notifyListeners();
        unawaited(_suspendRelayForDirect());
      } else {
        _handleDirectUnavailable();
      }
    };
    channel.onMessage = (message) {
      if (_closed || message.isBinary) return;
      _handleDirectApp(message.text);
    };
  }

  void _handleDirectApp(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return;
      final map = decoded.cast<String, Object?>();
      final kind = map['kind'];
      final payload = map['payload'];
      final sender = map['sender'];
      if (sender is String) {
        _directPeerId = sender;
        if (payload is Map) {
          unawaited(
            _rememberRelayPeer(sender, payload.cast<String, Object?>()),
          );
        }
      }
      if (kind == '__transport_multi__') {
        unawaited(_enterMultipleControllerMode(announce: false));
        return;
      }
      if (kind is String && payload is Map) {
        _messages.add(
          RemoteAppMessage(
            kind,
            payload.cast<String, Object?>(),
            senderId: sender is String ? sender : null,
          ),
        );
      }
    } on FormatException {
      // Ignore malformed peer messages.
    }
  }

  void _deliverAppPayload(Map<String, Object?> payload, {String? senderId}) {
    final kind = payload['kind'];
    final raw = payload['payload'];
    if (kind is String && raw is Map) {
      final appPayload = raw.cast<String, Object?>();
      if (senderId != null && kind == 'hello') {
        unawaited(_rememberRelayPeer(senderId, appPayload));
      }
      if (senderId != null &&
          kind == 'disconnect' &&
          _knownControllerIds.remove(senderId)) {
        notifyListeners();
      }
      _messages.add(RemoteAppMessage(kind, appPayload, senderId: senderId));
    }
  }

  Future<void> _sendDirectTransport(RemoteTransportMessage message) async {
    final direct = _dataChannel;
    if (!directConnected || direct == null) {
      throw StateError('Direct transport is unavailable.');
    }
    try {
      await direct.send(
        RTCDataChannelMessage(
          jsonEncode({
            'sender': _clientId,
            'kind': message.kind,
            'payload': message.payload,
          }),
        ),
      );
    } on Object {
      _handleDirectUnavailable();
      rethrow;
    }
  }

  Future<void> _sendRelayTransport(RemoteTransportMessage message) async {
    if (!_mqttConnected) {
      throw StateError('Relay transport is unavailable.');
    }
    await _publishSignal('app', {
      'kind': message.kind,
      'payload': message.payload,
    });
  }

  Future<void> sendApp(String kind, Map<String, Object?> payload) async {
    if (_closed) return;
    final message = RemoteTransportMessage(kind, payload);
    final sent = await _transportRouter.send(message);
    if (sent != null || _closed || directConnected) return;

    await connect();
    await _transportRouter.send(message);
  }

  Future<void> _publishSignal(String kind, Map<String, Object?> payload) async {
    final client = _mqtt;
    if (_closed ||
        client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final envelope = <String, Object?>{
      'sender': _clientId,
      'sequence': ++_signalSequence,
      'kind': kind,
      'payload': payload,
    };
    final encoded = await _encryptMap(envelope);
    final builder = MqttClientPayloadBuilder()..addString(encoded);
    final bytes = builder.payload;
    if (bytes == null) return;
    client.publishMessage(_topic, MqttQos.atMostOnce, bytes);
  }

  Future<String> _encryptMap(Map<String, Object?> value) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(value)),
      secretKey: SecretKey(_keyBytes),
      nonce: nonce,
    );
    return base64UrlEncode([...nonce, ...box.mac.bytes, ...box.cipherText])
        .replaceAll('=', '');
  }

  Future<Map<String, Object?>?> _decryptMap(String value) async {
    try {
      final bytes = base64Url.decode(_paddedBase64(value));
      if (bytes.length < 29) return null;
      final clear = await _cipher.decrypt(
        SecretBox(
          bytes.sublist(28),
          nonce: bytes.sublist(0, 12),
          mac: Mac(bytes.sublist(12, 28)),
        ),
        secretKey: SecretKey(_keyBytes),
      );
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map) return null;
      return decoded.cast<String, Object?>();
    } on Object {
      return null;
    }
  }

  static String _paddedBase64(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) return value;
    return value + ('=' * (4 - remainder));
  }

  Future<void> setRole(RemoteRole next, {bool announce = true}) async {
    if (role == next) return;
    role = next;
    notifyListeners();
    if (announce) {
      await sendApp('role', {'role': next.name});
    }
  }

  Future<void> _resetPeerConnection() async {
    directConnected = false;
    _directPeerId = null;
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();
    final channel = _dataChannel;
    _dataChannel = null;
    if (channel != null) {
      try {
        await channel.close();
      } on Object {
        // Best-effort cleanup.
      }
    }
    final pc = _peerConnection;
    _peerConnection = null;
    if (pc != null) {
      try {
        await pc.close();
        await pc.dispose();
      } on Object {
        // Best-effort cleanup.
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    try {
      await sendApp('disconnect', const {});
      if (_mqttConnected) {
        await _publishSignal('bye', {'role': role.name});
      }
    } on Object {
      // Best-effort notification.
    }
    _closed = true;
    _stopPairingAnnouncements();
    phase = RemoteConnectionPhase.disconnected;
    peerSeen = false;
    await _resetPeerConnection();
    await _mqttSubscription?.cancel();
    _mqttSubscription = null;
    _mqtt?.disconnect();
    _mqtt = null;
    await _messages.close();
    notifyListeners();
  }

  static List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256), growable: false);

  static String _newToken(int bytes) =>
      base64UrlEncode(_randomBytes(bytes)).replaceAll('=', '');
}
