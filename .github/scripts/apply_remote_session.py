from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, found {count}: {old[:120]!r}")
    path.write_text(text.replace(old, new, 1))


# Dependencies.
pubspec = Path('pubspec.yaml')
replace_once(
    pubspec,
    "  wakelock_plus: ^1.8.0\n",
    "  wakelock_plus: ^1.8.0\n"
    "  cryptography: ^2.8.1\n"
    "  flutter_webrtc: ^1.6.2+hotfix.3\n"
    "  mqtt_client: ^10.11.11\n"
    "  qr_flutter: ^4.1.0\n",
)


Path('lib/platform/remote_mqtt.dart').write_text(r'''export 'remote_mqtt_io.dart'
    if (dart.library.js_interop) 'remote_mqtt_web.dart';
''')

Path('lib/platform/remote_mqtt_web.dart').write_text(r'''import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createRemoteMqttClient(String clientId) {
  final client = MqttBrowserClient(
    'wss://broker.hivemq.com:8884/mqtt',
    clientId,
  );
  client.useWebSocket = true;
  client.port = 8884;
  client.websocketProtocols = const ['mqtt'];
  return client;
}
''')

Path('lib/platform/remote_mqtt_io.dart').write_text(r'''import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createRemoteMqttClient(String clientId) {
  final client = MqttServerClient(
    'wss://broker.hivemq.com:8884/mqtt',
    clientId,
  );
  client.useWebSocket = true;
  client.port = 8884;
  client.websocketProtocols = const ['mqtt'];
  return client;
}
''')

Path('lib/application/remote_session.dart').write_text(r'''import 'dart:async';
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
    final role = RemoteRole.values.where((value) => value.name == roleName).firstOrNull;
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
  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>? _mqttSubscription;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  String? _peerId;
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

  String get _encodedKey =>
      base64UrlEncode(_keyBytes).replaceAll('=', '');

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
    if (_closed || phase == RemoteConnectionPhase.connecting || _mqttConnected) {
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
    _peerId = sender;
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
    await _publishSignal('offer', {
      'sdp': offer.sdp,
      'type': offer.type,
    });
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
    await _publishSignal('answer', {
      'sdp': answer.sdp,
      'type': answer.type,
    });
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

  Future<void> _publishSignal(
    String kind,
    Map<String, Object?> payload,
  ) async {
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
    return base64UrlEncode([
      ...nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]).replaceAll('=', '');
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
''')


# Main app: a controller opened from a pairing link does not need physical
# calibration because its board view is scaled to the remote display.
main = Path('lib/main.dart')
replace_once(
    main,
    "import 'application/display_calibration.dart';\n",
    "import 'application/display_calibration.dart';\n"
    "import 'application/remote_session.dart';\n",
)
replace_once(
    main,
    "  final BoardStore _store = BoardStore();\n",
    "  final BoardStore _store = BoardStore();\n"
    "  late final RemoteLaunch? _remoteLaunch = RemoteLaunch.fromUri(Uri.base);\n",
)
replace_once(
    main,
    "    final result = await DisplayCalibrationService.resolve(context);\n"
    "    if (!mounted) return;\n"
    "    setState(() {\n"
    "      _calibration = result;\n"
    "      _resolvingCalibration = false;\n"
    "      if (result == null) _forceManualCalibration = true;\n"
    "    });\n",
    "    var result = await DisplayCalibrationService.resolve(context);\n"
    "    if (result == null && _remoteLaunch?.role == RemoteRole.controller) {\n"
    "      result = const CalibrationResult(\n"
    "        logicalPixelsPerMm: 4.8,\n"
    "        source: 'Remote controller',\n"
    "      );\n"
    "    }\n"
    "    if (!mounted) return;\n"
    "    setState(() {\n"
    "      _calibration = result;\n"
    "      _resolvingCalibration = false;\n"
    "      if (result == null) _forceManualCalibration = true;\n"
    "    });\n",
)
replace_once(
    main,
    "      onRecalibrate: _recalibrate,\n"
    "    );\n",
    "      onRecalibrate: _recalibrate,\n"
    "      remoteLaunch: _remoteLaunch,\n"
    "    );\n",
)


# Board screen integration.
board = Path('lib/ui/board_screen.dart')
replace_once(
    board,
    "import 'package:flutter/scheduler.dart';\n",
    "import 'package:flutter/scheduler.dart';\n"
    "import 'package:qr_flutter/qr_flutter.dart';\n",
)
replace_once(
    board,
    "import '../application/board_store.dart';\n",
    "import '../application/board_store.dart';\n"
    "import '../application/remote_session.dart';\n",
)
replace_once(
    board,
    "    required this.onRecalibrate,\n"
    "  });\n",
    "    required this.onRecalibrate,\n"
    "    this.remoteLaunch,\n"
    "  });\n",
)
replace_once(
    board,
    "  final ValueChanged<BoardState> onRecalibrate;\n",
    "  final ValueChanged<BoardState> onRecalibrate;\n"
    "  final RemoteLaunch? remoteLaunch;\n",
)
replace_once(
    board,
    "  BoardState? _pendingSaveState;\n",
    "  BoardState? _pendingSaveState;\n"
    "  RemoteSession? _remoteSession;\n"
    "  StreamSubscription<RemoteAppMessage>? _remoteMessageSubscription;\n"
    "  Timer? _remotePublishTimer;\n"
    "  BoardState? _remotePendingState;\n"
    "  bool _applyingRemoteState = false;\n"
    "  bool _remoteSeedReceived = false;\n"
    "  double? _remoteDisplayWidthMm;\n"
    "  double? _remoteDisplayHeightMm;\n",
)
replace_once(
    board,
    "      if (!kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {\n"
    "        _startFaceDownMonitoring();\n"
    "      }\n"
    "    });\n",
    "      if (!kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {\n"
    "        _startFaceDownMonitoring();\n"
    "      }\n"
    "      final launch = widget.remoteLaunch;\n"
    "      if (launch != null) {\n"
    "        unawaited(_startRemoteSession(RemoteSession.fromLaunch(launch)));\n"
    "      }\n"
    "    });\n",
)
replace_once(
    board,
    "    _saveDebounceTimer?.cancel();\n"
    "    unawaited(_flushPendingSave());\n",
    "    _saveDebounceTimer?.cancel();\n"
    "    _remotePublishTimer?.cancel();\n"
    "    _remoteMessageSubscription?.cancel();\n"
    "    unawaited(_remoteSession?.close());\n"
    "    unawaited(_flushPendingSave());\n",
)

# Replace physical pixel scale references with an effective scale which can
# shrink a large remote display into a controller device viewport.
text = board.read_text()
text = text.replace('widget.logicalPixelsPerMm', '_pixelsPerMm')
board.write_text(text)

replace_once(
    board,
    "  ({double width, double height}) _physicalBoardSize() {\n"
    "    final size = MediaQuery.sizeOf(context);\n"
    "    final padding = MediaQuery.viewPaddingOf(context);\n"
    "    return (\n"
    "      width: math.max(\n"
    "        1.0,\n"
    "        (size.width - padding.horizontal) / _pixelsPerMm,\n"
    "      ),\n"
    "      height: math.max(\n"
    "        1.0,\n"
    "        (size.height - padding.vertical) / _pixelsPerMm,\n"
    "      ),\n"
    "    );\n"
    "  }\n",
    "  bool get _remoteDisplayMode =>\n"
    "      _remoteSession?.role == RemoteRole.display;\n"
    "\n"
    "  bool get _remoteControllerMode =>\n"
    "      _remoteSession?.role == RemoteRole.controller;\n"
    "\n"
    "  double get _pixelsPerMm {\n"
    "    final widthMm = _remoteDisplayWidthMm;\n"
    "    final heightMm = _remoteDisplayHeightMm;\n"
    "    if (!_remoteControllerMode || widthMm == null || heightMm == null) {\n"
    "      return widget.logicalPixelsPerMm;\n"
    "    }\n"
    "    final size = MediaQuery.sizeOf(context);\n"
    "    final safe = MediaQuery.viewPaddingOf(context);\n"
    "    final availableWidth = math.max(1.0, size.width - safe.horizontal);\n"
    "    final availableHeight = math.max(1.0, size.height - safe.vertical);\n"
    "    return math.max(\n"
    "      0.1,\n"
    "      math.min(availableWidth / widthMm, availableHeight / heightMm),\n"
    "    );\n"
    "  }\n"
    "\n"
    "  EdgeInsets _boardSurfacePadding(BuildContext surfaceContext) {\n"
    "    final safe = MediaQuery.viewPaddingOf(surfaceContext);\n"
    "    final widthMm = _remoteDisplayWidthMm;\n"
    "    final heightMm = _remoteDisplayHeightMm;\n"
    "    if (!_remoteControllerMode || widthMm == null || heightMm == null) {\n"
    "      return safe;\n"
    "    }\n"
    "    final size = MediaQuery.sizeOf(surfaceContext);\n"
    "    final availableWidth = math.max(1.0, size.width - safe.horizontal);\n"
    "    final availableHeight = math.max(1.0, size.height - safe.vertical);\n"
    "    final scale = math.max(\n"
    "      0.1,\n"
    "      math.min(availableWidth / widthMm, availableHeight / heightMm),\n"
    "    );\n"
    "    final extraX = math.max(0.0, (availableWidth - widthMm * scale) / 2);\n"
    "    final extraY = math.max(0.0, (availableHeight - heightMm * scale) / 2);\n"
    "    return EdgeInsets.fromLTRB(\n"
    "      safe.left + extraX,\n"
    "      safe.top + extraY,\n"
    "      safe.right + extraX,\n"
    "      safe.bottom + extraY,\n"
    "    );\n"
    "  }\n"
    "\n"
    "  ({double width, double height}) _physicalBoardSize() {\n"
    "    final remoteWidth = _remoteDisplayWidthMm;\n"
    "    final remoteHeight = _remoteDisplayHeightMm;\n"
    "    if (_remoteControllerMode &&\n"
    "        remoteWidth != null &&\n"
    "        remoteHeight != null) {\n"
    "      return (width: remoteWidth, height: remoteHeight);\n"
    "    }\n"
    "    final size = MediaQuery.sizeOf(context);\n"
    "    final padding = MediaQuery.viewPaddingOf(context);\n"
    "    return (\n"
    "      width: math.max(\n"
    "        1.0,\n"
    "        (size.width - padding.horizontal) / _pixelsPerMm,\n"
    "      ),\n"
    "      height: math.max(\n"
    "        1.0,\n"
    "        (size.height - padding.vertical) / _pixelsPerMm,\n"
    "      ),\n"
    "    );\n"
    "  }\n",
)

# Snap calculations use the target board dimensions, not the controller phone's
# letterboxed viewport.
replace_once(
    board,
    "    final mediaSize = MediaQuery.sizeOf(context);\n"
    "    final padding = MediaQuery.viewPaddingOf(context);\n"
    "    final widthPx = mediaSize.width - padding.horizontal;\n"
    "    final heightPx = mediaSize.height - padding.vertical;\n"
    "    final snap = _controller.state.underlay.nearestSnapPoint(\n"
    "      target.position,\n"
    "      boardWidthMm: widthPx / _pixelsPerMm,\n"
    "      boardHeightMm: heightPx / _pixelsPerMm,\n"
    "    );\n",
    "    final board = _physicalBoardSize();\n"
    "    final snap = _controller.state.underlay.nearestSnapPoint(\n"
    "      target.position,\n"
    "      boardWidthMm: board.width,\n"
    "      boardHeightMm: board.height,\n"
    "    );\n",
)

# Remote synchronization and pairing UI are inserted immediately before the
# existing persistence scheduler.
replace_once(
    board,
    "  void _scheduleSave() {\n",
    r'''  Future<void> _startRemoteSession(RemoteSession session) async {
    final old = _remoteSession;
    if (old != null && old != session) {
      await _remoteMessageSubscription?.cancel();
      _remoteMessageSubscription = null;
      await old.close();
    }
    if (!mounted) return;
    setState(() {
      _remoteSession = session;
      _remoteSeedReceived = false;
      _remoteDisplayWidthMm = null;
      _remoteDisplayHeightMm = null;
    });
    session.addListener(_remoteSessionChanged);
    _remoteMessageSubscription = session.messages.listen(_handleRemoteMessage);
    await session.connect();
    if (!mounted) return;
    await _sendRemoteHello();
    if (session.isCreator) {
      await _showPairingDialog(session);
    }
  }

  void _remoteSessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _sendRemoteHello() async {
    final session = _remoteSession;
    if (session == null) return;
    final board = _physicalBoardSize();
    await session.sendApp('hello', {
      'role': session.role.name,
      'creator': session.isCreator,
      if (session.role == RemoteRole.display) 'widthMm': board.width,
      if (session.role == RemoteRole.display) 'heightMm': board.height,
    });
  }

  Future<void> _handleRemoteMessage(RemoteAppMessage message) async {
    final session = _remoteSession;
    if (session == null || !mounted) return;
    switch (message.kind) {
      case 'hello':
        final peerRoleName = message.payload['role'];
        final peerRole = RemoteRole.values
            .where((value) => value.name == peerRoleName)
            .firstOrNull;
        if (peerRole == RemoteRole.display) {
          final width = (message.payload['widthMm'] as num?)?.toDouble();
          final height = (message.payload['heightMm'] as num?)?.toDouble();
          if (width != null && height != null && width > 0 && height > 0) {
            setState(() {
              _remoteDisplayWidthMm = width;
              _remoteDisplayHeightMm = height;
            });
          }
        }
        if (session.isCreator) {
          await _sendRemoteHello();
          await _sendRemoteState('seed');
        }
      case 'seed':
        await _applyRemoteState(message.payload, force: true);
        _remoteSeedReceived = true;
        if (session.role == RemoteRole.controller) {
          await _sendRemoteState('state');
        }
      case 'state':
        if (session.role == RemoteRole.display) {
          await _applyRemoteState(message.payload);
        }
      case 'role':
        final peerRoleName = message.payload['role'];
        final peerRole = RemoteRole.values
            .where((value) => value.name == peerRoleName)
            .firstOrNull;
        if (peerRole == null) return;
        await session.setRole(peerRole.other, announce: false);
        setState(() {
          _remoteDisplayWidthMm = null;
          _remoteDisplayHeightMm = null;
        });
        await _sendRemoteHello();
        if (session.role == RemoteRole.controller) {
          await _sendRemoteState('state');
        }
      case 'disconnect':
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Remote device disconnected.')),
          );
        }
    }
  }

  Future<void> _applyRemoteState(
    Map<String, Object?> payload, {
    bool force = false,
  }) async {
    final rawState = payload['state'];
    if (rawState is! Map) return;
    if (!force && _remoteSession?.role != RemoteRole.display) return;
    try {
      final state = BoardState.fromJson(rawState.cast<String, Object?>());
      _applyingRemoteState = true;
      _controller.replaceState(state);
      final selected = payload['selectedId'];
      setState(() => _selectedId = selected is String ? selected : null);
    } on Object {
      // Ignore malformed or incompatible remote state.
    } finally {
      _applyingRemoteState = false;
    }
  }

  void _scheduleRemotePublish() {
    final session = _remoteSession;
    if (session == null ||
        session.role != RemoteRole.controller ||
        _applyingRemoteState ||
        !_remoteSeedReceived && !session.isCreator) {
      return;
    }
    _remotePendingState = _controller.state;
    if (_remotePublishTimer != null) return;
    _remotePublishTimer = Timer(const Duration(milliseconds: 50), () {
      _remotePublishTimer = null;
      unawaited(_flushRemotePublish());
    });
  }

  Future<void> _flushRemotePublish() async {
    final state = _remotePendingState;
    _remotePendingState = null;
    final session = _remoteSession;
    if (state == null || session == null || session.role != RemoteRole.controller) {
      return;
    }
    await _sendRemoteState('state', state: state);
  }

  Future<void> _sendRemoteState(
    String kind, {
    BoardState? state,
  }) async {
    final session = _remoteSession;
    if (session == null) return;
    final board = _physicalBoardSize();
    await session.sendApp(kind, {
      'state': (state ?? _controller.state).toJson(),
      'selectedId': _selectedId,
      'widthMm': board.width,
      'heightMm': board.height,
    });
  }

  Future<void> _showPairingDialog(RemoteSession session) async {
    if (!mounted || _remoteSession != session) return;
    final join = session.joinUri(Uri.base).toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: session,
        builder: (context, _) => AlertDialog(
          title: Text('Pair ${session.role.label}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(data: join, size: 230),
                ),
                const SizedBox(height: 14),
                Text(
                  session.peerSeen
                      ? 'Paired · ${session.transportLabel}'
                      : 'Scan this with the other device. It will open as ${session.role.other.label}.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: join));
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Pairing link copied.')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Link'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(session.peerSeen ? 'Done' : 'Hide'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disconnectRemote() async {
    final session = _remoteSession;
    if (session == null) return;
    session.removeListener(_remoteSessionChanged);
    await _remoteMessageSubscription?.cancel();
    _remoteMessageSubscription = null;
    _remotePublishTimer?.cancel();
    _remotePublishTimer = null;
    _remotePendingState = null;
    await session.close();
    if (!mounted) return;
    setState(() {
      _remoteSession = null;
      _remoteSeedReceived = false;
      _remoteDisplayWidthMm = null;
      _remoteDisplayHeightMm = null;
    });
  }

  Future<void> _swapRemoteRoles() async {
    final session = _remoteSession;
    if (session == null) return;
    await session.setRole(session.role.other);
    setState(() {
      _remoteDisplayWidthMm = null;
      _remoteDisplayHeightMm = null;
    });
    await _sendRemoteHello();
    if (session.role == RemoteRole.controller) {
      await _sendRemoteState('state');
    }
  }

  Future<void> _showRemoteMenu() async {
    final session = _remoteSession;
    if (session == null) {
      final choice = await _showCompactMenu([
        _compactMenuItem(
          'display',
          Icons.desktop_windows_outlined,
          'This Device: Board Display',
        ),
        _compactMenuItem(
          'controller',
          Icons.tune,
          'This Device: Controller',
        ),
      ]);
      if (!mounted || choice == null) return;
      final role = choice == 'display'
          ? RemoteRole.display
          : RemoteRole.controller;
      await _startRemoteSession(RemoteSession.create(role));
      return;
    }

    final choice = await _showCompactMenu([
      _compactMenuItem(
        'status',
        Icons.link,
        '${session.role.label} · ${session.transportLabel}',
        enabled: false,
      ),
      _compactMenuItem('pair', Icons.qr_code_2, 'Show Pairing QR'),
      _compactMenuItem('swap', Icons.swap_horiz, 'Swap Roles'),
      _compactMenuItem('disconnect', Icons.link_off, 'Disconnect'),
    ]);
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'pair':
        await _showPairingDialog(session);
      case 'swap':
        await _swapRemoteRoles();
      case 'disconnect':
        await _disconnectRemote();
    }
  }

  Widget _remoteStatusButton() {
    final session = _remoteSession;
    if (session == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: '${session.role.label} · ${session.transportLabel}',
      onPressed: _showRemoteMenu,
      icon: Icon(
        session.peerSeen ? Icons.link : Icons.link_off,
        color: session.peerSeen ? Colors.white70 : Colors.orangeAccent,
      ),
    );
  }

  void _scheduleSave() {
''',
)

# Board changes from the controller are coalesced to 20 Hz for remote display.
replace_once(
    board,
    "    _scheduleSave();\n"
    "  }\n"
    "\n"
    "  PhysicalPoint _toPhysical",
    "    _scheduleSave();\n"
    "    _scheduleRemotePublish();\n"
    "  }\n"
    "\n"
    "  PhysicalPoint _toPhysical",
)

# Add Remote to the main menu and route it.
replace_once(
    board,
    "      _compactMenuItem('display', Icons.display_settings, 'Display'),\n"
    "      _compactMenuItem('instructions', Icons.help_outline, 'Instructions'),\n",
    "      _compactMenuItem('display', Icons.display_settings, 'Display'),\n"
    "      _compactMenuItem('remote', Icons.devices_outlined, 'Remote'),\n"
    "      _compactMenuItem('instructions', Icons.help_outline, 'Instructions'),\n",
)
replace_once(
    board,
    "      case 'display':\n"
    "        await _showDisplayMenu();\n"
    "      case 'instructions':\n",
    "      case 'display':\n"
    "        await _showDisplayMenu();\n"
    "      case 'remote':\n"
    "        await _showRemoteMenu();\n"
    "      case 'instructions':\n",
)

# A display device becomes a clean, read-only board. A controller retains the
# existing interface. The controller board is letterboxed to the display's exact
# aspect ratio and physical coordinate space.
replace_once(
    board,
    "    final safePadding = MediaQuery.viewPaddingOf(surfaceContext);\n",
    "    final safePadding = _boardSurfacePadding(surfaceContext);\n",
)
replace_once(
    board,
    "          child: Listener(\n",
    "          child: IgnorePointer(\n"
    "            ignoring: _remoteDisplayMode,\n"
    "            child: Listener(\n",
)
# Close the new IgnorePointer after the GestureDetector/ValueListenable tree.
needle = "              ),\n            ),\n          ),\n        ),\n        Padding(\n          padding: safePadding,\n          child: IgnorePointer(\n            child: ValueListenableBuilder<int>("
replacement = "              ),\n            ),\n          ),\n            ),\n        ),\n        Padding(\n          padding: safePadding,\n          child: IgnorePointer(\n            child: ValueListenableBuilder<int>("
replace_once(board, needle, replacement)

replace_once(
    board,
    "        if (_activeToys.contains(_ToyKind.wireDie)) const DiceBubble(),\n"
    "        if (_activeToys.contains(_ToyKind.zendoStones))\n"
    "          const ZendoStonesWidget(),\n"
    "        if (_activeToys.contains(_ToyKind.sideGuns))\n"
    "          Padding(padding: safePadding, child: _sideGunAimHandles()),\n",
    "        if (_activeToys.contains(_ToyKind.wireDie))\n"
    "          IgnorePointer(\n"
    "            ignoring: _remoteDisplayMode,\n"
    "            child: const DiceBubble(),\n"
    "          ),\n"
    "        if (_activeToys.contains(_ToyKind.zendoStones))\n"
    "          IgnorePointer(\n"
    "            ignoring: _remoteDisplayMode,\n"
    "            child: const ZendoStonesWidget(),\n"
    "          ),\n"
    "        if (_activeToys.contains(_ToyKind.sideGuns) && !_remoteDisplayMode)\n"
    "          Padding(padding: safePadding, child: _sideGunAimHandles()),\n",
)
replace_once(
    board,
    "                children: [_menu(), _historyControls()],\n",
    "                children: [\n"
    "                  if (_remoteDisplayMode)\n"
    "                    _remoteStatusButton()\n"
    "                  else ...[\n"
    "                    _menu(),\n"
    "                    _historyControls(),\n"
    "                    if (_remoteSession != null) _remoteStatusButton(),\n"
    "                  ],\n"
    "                ],\n",
)
replace_once(
    board,
    "        SafeArea(\n"
    "          child: Align(\n"
    "            alignment: Alignment.bottomRight,\n"
    "            child: Padding(\n"
    "              padding: const EdgeInsets.all(8),\n"
    "              child: _toyControls(),\n"
    "            ),\n"
    "          ),\n"
    "        ),\n",
    "        if (!_remoteDisplayMode)\n"
    "          SafeArea(\n"
    "            child: Align(\n"
    "              alignment: Alignment.bottomRight,\n"
    "              child: Padding(\n"
    "                padding: const EdgeInsets.all(8),\n"
    "                child: _toyControls(),\n"
    "              ),\n"
    "            ),\n"
    "          ),\n",
)

# Regression/unit tests for the QR link contract and role complement.
Path('test/application/remote_session_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
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
''')

# Documentation.
readme = Path('README.md')
text = readme.read_text()
marker = '## Development\n'
if marker in text and 'Remote sessions' not in text:
    text = text.replace(
        marker,
        "## Remote sessions\n\n"
        "Any two LightHouse-capable devices can pair as a Board Display and a Controller. "
        "Start Remote from either device, choose that device's role, and scan the QR code on the other device. "
        "The controller renders the display's full physical board as a scaled control surface. Pairing and fallback relay messages are encrypted; after pairing LightHouse prefers a direct WebRTC data channel.\n\n"
        + marker,
        1,
    )
readme.write_text(text)

changelog = Path('CHANGELOG.md')
replace_once(
    changelog,
    '## Unreleased\n',
    '## Unreleased\n'
    '- Added two-device Remote sessions: either device can be the Board Display or Controller, pairing uses a QR/link, controller coordinates scale to the display board, WebRTC is preferred for direct transport, and encrypted relay messaging provides pairing/fallback.\n',
)

# Remove the one-shot editing machinery from the validated feature commit.
Path('.github/scripts/apply_remote_session.py').unlink()
Path('.github/workflows/remote-session.yml').unlink()
