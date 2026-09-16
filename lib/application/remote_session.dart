import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../platform/remote_mqtt.dart';

enum RemoteRole {
  display,
  controller;

  RemoteRole get other =>
      this == RemoteRole.display ? RemoteRole.controller : RemoteRole.display;

  String get label =>
      this == RemoteRole.display ? 'Board Display' : 'Controller';
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
    final room = uri.queryParameters[roomParameter];
    final encodedKey = uri.queryParameters[keyParameter];
    final roleName = uri.queryParameters[roleParameter];
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

  static String _paddedBase64(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) return value;
    return value + ('=' * (4 - remainder));
  }
}

class RemoteAppMessage {
  const RemoteAppMessage(this.kind, this.payload);

  final String kind;
  final Map<String, Object?> payload;
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
  }) : _keyBytes = List<int>.unmodifiable(keyBytes),
       _clientId = _newToken(9);

  factory RemoteSession.create(RemoteRole role) => RemoteSession._(
    roomId: _newToken(12),
    keyBytes: _randomBytes(32),
    role: role,
    isCreator: true,
  );

  factory RemoteSession.fromLaunch(RemoteLaunch launch) => RemoteSession._(
    roomId: launch.roomId,
    keyBytes: launch.keyBytes,
    role: launch.role,
    isCreator: false,
  );

  static final math.Random _random = math.Random.secure();
  static final AesGcm _cipher = AesGcm.with256bits();

  final String roomId;
  final List<int> _keyBytes;
  final String _clientId;
  final bool isCreator;
  final StreamController<RemoteAppMessage> _messages =
      StreamController<RemoteAppMessage>.broadcast();

  RemoteRole role;
  RemoteConnectionPhase phase = RemoteConnectionPhase.disconnected;
  String? errorMessage;
  bool peerSeen = false;
  bool directConnected = false;

  MqttClient? _mqtt;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>?
  _mqttSubscription;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _closed = false;
  int _signalSequence = 0;

  Stream<RemoteAppMessage> get messages => _messages.stream;

  String get transportLabel {
    if (directConnected) return 'Direct';
    if (peerSeen && _mqttConnected) return 'Encrypted relay';
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
    cleanParameters.addAll({
      RemoteLaunch.roomParameter: roomId,
      RemoteLaunch.keyParameter: _encodedKey,
      RemoteLaunch.roleParameter: role.other.name,
    });
    return current.replace(queryParameters: cleanParameters, fragment: '');
  }

  Future<void> connect() async {
    if (_closed ||
        phase == RemoteConnectionPhase.connecting ||
        _mqttConnected) {
      return;
    }
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
    await _announceOnSignalChannel();
  }

  Future<void> _announceOnSignalChannel() async {
    await _publishSignal('presence', const {});
    if (!isCreator) await _publishSignal('join', const {});
  }

  void _handleMqttDisconnected() {
    if (_closed) return;
    if (!directConnected) {
      phase = RemoteConnectionPhase.disconnected;
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
    if (!peerSeen) {
      peerSeen = true;
      phase = RemoteConnectionPhase.connected;
      notifyListeners();
    }

    switch (kind) {
      case 'presence':
        if (!isCreator && !directConnected) {
          await _publishSignal('join', const {});
        }
      case 'join':
        if (isCreator && !directConnected) {
          await _makeOffer();
        }
      case 'offer':
        if (!isCreator) await _acceptOffer(payload);
      case 'answer':
        if (isCreator) await _acceptAnswer(payload);
      case 'candidate':
        await _acceptCandidate(payload);
      case 'app':
        _deliverAppPayload(payload);
    }
  }

  Future<void> _makeOffer() async {
    if (_closed || _peerConnection != null && directConnected) return;
    await _resetPeerConnection();
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
    final sdp = payload['sdp'];
    final type = payload['type'];
    final pc = _peerConnection;
    if (pc == null || sdp is! String || type is! String) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
  }

  Future<void> _acceptCandidate(Map<String, Object?> payload) async {
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
      if (_closed) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        directConnected = false;
        if (_mqttConnected && peerSeen) phase = RemoteConnectionPhase.connected;
        notifyListeners();
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
      directConnected = open;
      if (open) {
        peerSeen = true;
        phase = RemoteConnectionPhase.connected;
      }
      notifyListeners();
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
      if (kind is String && payload is Map) {
        _messages.add(RemoteAppMessage(kind, payload.cast<String, Object?>()));
      }
    } on FormatException {
      // Ignore malformed peer messages.
    }
  }

  void _deliverAppPayload(Map<String, Object?> payload) {
    final kind = payload['kind'];
    final raw = payload['payload'];
    if (kind is String && raw is Map) {
      _messages.add(RemoteAppMessage(kind, raw.cast<String, Object?>()));
    }
  }

  Future<void> sendApp(String kind, Map<String, Object?> payload) async {
    if (_closed) return;
    final direct = _dataChannel;
    if (directConnected && direct != null) {
      try {
        await direct.send(
          RTCDataChannelMessage(jsonEncode({'kind': kind, 'payload': payload})),
        );
        return;
      } on Object {
        directConnected = false;
        notifyListeners();
      }
    }
    await _publishSignal('app', {'kind': kind, 'payload': payload});
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
    } on Object {
      // Best-effort notification.
    }
    _closed = true;
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
