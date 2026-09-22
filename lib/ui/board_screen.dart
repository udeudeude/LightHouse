import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../application/board_controller.dart';
import '../application/board_store.dart';
import '../application/remote_control_state.dart';
import '../application/remote_session.dart';
import '../domain/board_state.dart';
import '../domain/board_underlay.dart';
import '../domain/convex_geometry.dart';
import '../domain/geometry.dart';
import '../domain/light_element.dart';
import '../domain/light_structure.dart';
import '../domain/physical_point.dart';
import '../platform/motion_permission.dart';
import 'board_painter.dart';
import 'credits_overlay.dart';
import 'dice_bubble.dart';
import 'remote_board_viewport.dart';
import 'ripple_overlay.dart';
import 'pyramid_love_board_icon.dart';
import 'pyramid_love_toy_icon.dart';
import 'toy_overlay.dart';
import 'zendo_rule_library.dart';
import 'zendo_stones.dart';

enum _ToyKind {
  lightLottery('Light Lottery', Icons.auto_awesome, true),
  entropy('Entropy Delete', Icons.hourglass_bottom, true),
  ghostPaths('Ghost Paths', Icons.timeline, false),
  eventZone('Random Event Zone', Icons.adjust, false),
  turnTimer('Turn Timer', Icons.timer_outlined, false),
  breathing('Breathing', Icons.air, false),
  nestCycle('Nest Cycle', Icons.layers, false),
  radar('Radar', Icons.track_changes, false),
  redSweep('Red Sweep', Icons.swap_vert, false),
  wireDie('Dice Bubble', Icons.casino, false),
  sideGuns('Side Guns', Icons.gps_fixed, false),
  cornerRicochet('Corner Ricochet', Icons.radio_button_checked, false),
  hotPotato('Hot Potato', Icons.local_fire_department, false),
  constellationDraw('Constellation Draw', Icons.share, false),
  heartbeat('Heartbeat', Icons.favorite_border, false),
  triangleBounce('Triangle Bounce', Icons.change_history, false),
  squareChase('Square Chase', Icons.crop_square, false),
  zendoStones('Zendo Stones', Icons.circle_outlined, false);

  const _ToyKind(this.label, this.icon, this.defaultVisible);

  final String label;
  final IconData icon;
  final bool defaultVisible;

  String get preferenceKey => 'lighthouse.toy.$name.visible.v2';
}

class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.logicalPixelsPerMm,
    required this.initialState,
    required this.calibrationLabel,
    required this.onRecalibrate,
    this.remoteLaunch,
  });

  final double logicalPixelsPerMm;
  final BoardState initialState;
  final String calibrationLabel;
  final ValueChanged<BoardState> onRecalibrate;
  final RemoteLaunch? remoteLaunch;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> with WidgetsBindingObserver {
  static const double _interactionHaloMm = 7;
  static const double _tapTravelMm = 2;
  static const double _minimumLineGestureMm = 1.5;
  static const MethodChannel _displayChannel = MethodChannel(
    'lighthouse/display',
  );

  late final BoardController _controller;
  final BoardStore _store = BoardStore();

  LightElement? _transformTarget;
  LightElement? _preciseTarget;
  PhysicalPoint? _oneFingerStart;
  PhysicalPoint? _oneFingerLast;
  final List<PhysicalPoint> _oneFingerPath = [];
  double _lastRotation = 0;
  bool _transformStarted = false;

  String? _selectedId;
  String? _activeSavedId;

  bool _mouseTransform = false;
  PhysicalPoint? _mouseLast;

  bool _trackpadTransform = false;
  double _trackpadLastRotation = 0;
  bool _desktopScrollTransform = false;
  LightElement? _desktopScrollTarget;
  Timer? _desktopScrollEndTimer;

  double _brightness = 1.0;
  bool _orientationLocked = false;
  double? _rotationSnapDegrees;
  bool _gridSnapEnabled = false;
  bool _checkerUnderlays = false;
  bool _transformTranslated = false;
  PhysicalPoint _pendingTransformDelta = PhysicalPoint.zero;
  double _pendingTransformRotation = 0;
  bool _transformFrameScheduled = false;

  final math.Random _random = math.Random();
  Map<String, double> _effectOpacities = const {};
  PhysicalPoint? _burstCenter;
  double? _burstProgress;
  bool _randomizerRunning = false;
  bool _entropyEnabled = false;
  final Map<_ToyKind, bool> _toyVisible = {
    for (final toy in _ToyKind.values) toy: toy.defaultVisible,
  };
  final Set<_ToyKind> _activeToys = {};
  Timer? _entropyTimer;
  Timer? _toyTicker;
  DateTime? _lastToyTickAt;
  final ValueNotifier<int> _toyRevision = ValueNotifier<int>(0);
  int _effectGeneration = 0;
  int _entropyGeneration = 0;
  double _toyClock = 0;
  int _squareChaseSeed = 0;
  double _radarAngleDegrees = 0;
  double _redSweepY = 0;
  double _redSweepPeriodSeconds = 13.33;
  double _redSweepLongPressStartPeriod = 13.33;
  bool _redSweepNeedleVisible = false;
  DateTime? _eventZoneEndsAt;
  PhysicalPoint? _eventZoneCenter;
  double? _eventZoneRadiusMm;
  double? _eventZoneProgress;
  double _eventZoneDismiss = 0;
  DateTime? _turnTimerEndsAt;
  double? _turnTimerProgress;
  double _turnTimerDurationSeconds = 30;
  double _turnTimerActiveDurationSeconds = 30;
  double _timerLongPressStartDuration = 30;
  bool _timerNeedleVisible = false;
  List<ToyProjectile> _projectiles = const [];
  List<ToyImpact> _impacts = const [];
  final List<double> _sideGunAnglesDegrees = [45, 135, 315, 225];
  final List<int> _sideGunAmmo = [0, 0, 0, 0];
  List<String> _constellationElementIds = const [];
  String? _heartbeatOddId;
  double _heartbeatStartedAt = 0;
  final Map<String, List<PhysicalPoint>> _ghostTrails = {};
  final Map<String, ({double minY, double maxY})> _elementVerticalBounds = {};
  bool _ghostTrailActive = false;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _webMotionTimer;
  Timer? _faceDownTimer;
  bool _faceDownLatched = false;
  bool _creditsVisible = false;
  bool _instructionsVisible = false;
  bool _motionPermissionAttempted = false;
  bool _roundedTriangleTips = false;
  bool _historyControlsVisible = false;
  Timer? _historyControlsTimer;
  Timer? _saveDebounceTimer;
  BoardState? _pendingSaveState;
  RemoteSession? _remoteSession;
  StreamSubscription<RemoteAppMessage>? _remoteMessageSubscription;
  Timer? _remotePublishTimer;
  BoardState? _remotePendingState;
  Timer? _remoteRuntimeTimer;
  String? _lastRemoteRuntimeJson;
  RemoteBoardControlState _remoteControlState = const RemoteBoardControlState();
  bool _rippleTapEnabled = false;
  Timer? _rippleTimer;
  Timer? _rippleTapTimer;
  DateTime? _lastRippleTickAt;
  double _rippleClock = 0;
  DiceBubbleSnapshot _diceSnapshot = DiceBubbleSnapshot.initial;
  ZendoStonesSnapshot _zendoSnapshot = ZendoStonesSnapshot.initial;
  PieceCycleMode _zendoPieceMode = PieceCycleMode.classic;
  int _zendoRuleIndex = -1;
  bool _zendoRuleVisible = false;
  bool _zendoComplexRules = false;
  ZendoRuleDifficulty _zendoRuleDifficulty = ZendoRuleDifficulty.easy;
  bool _applyingRemoteState = false;
  bool _remoteSeedReceived = false;
  bool _remotePeerSeen = false;
  double? _remoteDisplayWidthMm;
  double? _remoteDisplayHeightMm;
  double? _remoteDisplayPixelsPerMm;
  double? _faceUpZSign;
  double? _faceUpCandidateSign;
  int _faceUpStableSamples = 0;
  double? _lastDominantZSign;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = BoardController(initialState: widget.initialState)
      ..addListener(_refresh);
    _restoreTableData(widget.initialState.tableData);
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyBrightness();
      _loadInteractionPreferences();
      if (!kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
        _startFaceDownMonitoring();
      }
      final launch = widget.remoteLaunch;
      if (launch != null) {
        unawaited(_startRemoteSession(RemoteSession.fromLaunch(launch)));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_orientationLocked || kIsWeb) return;
    _orientationLocked = true;
    final orientation = MediaQuery.orientationOf(context);
    SystemChrome.setPreferredOrientations([
      orientation == Orientation.portrait
          ? DeviceOrientation.portraitUp
          : DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!kIsWeb) unawaited(_applyBrightness());
      if (kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          _motionPermissionAttempted) {
        _startWebMotionMonitoring();
      } else if (!kIsWeb) {
        _startFaceDownMonitoring();
      }
      if (_needsToyTicker && !_remoteDisplayMode) _ensureToyTicker();
      return;
    }

    _webMotionTimer?.cancel();
    _webMotionTimer = null;
    final subscription = _accelerometerSubscription;
    _accelerometerSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _toyTicker?.cancel();
    _toyTicker = null;
    _lastToyTickAt = null;
    unawaited(_flushPendingSave());
    if (!kIsWeb) {
      unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceDownTimer?.cancel();
    _webMotionTimer?.cancel();
    _saveDebounceTimer?.cancel();
    _remotePublishTimer?.cancel();
    _remoteRuntimeTimer?.cancel();
    _rippleTimer?.cancel();
    _rippleTapTimer?.cancel();
    _remoteMessageSubscription?.cancel();
    unawaited(_remoteSession?.close());
    unawaited(_flushPendingSave());
    _desktopScrollEndTimer?.cancel();
    _historyControlsTimer?.cancel();
    _entropyTimer?.cancel();
    _toyTicker?.cancel();
    _toyRevision.dispose();
    _effectGeneration += 1;
    _entropyGeneration += 1;
    _accelerometerSubscription?.cancel();
    _controller.removeListener(_refresh);
    _controller.dispose();
    WakelockPlus.disable();
    if (!kIsWeb) {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Map<String, Object?> _persistentTableData() => {
    'activeToys': [for (final toy in _activeToys) toy.name],
    'dice': _diceSnapshot.toJson(),
    'zendo': _zendoSnapshot.toJson(),
    'zendoPieceMode': _zendoPieceMode.name,
    'zendoRuleIndex': _zendoRuleIndex,
    'zendoRuleVisible': _zendoRuleVisible,
    'zendoComplexRules': _zendoComplexRules,
    'zendoRuleDifficulty': _zendoRuleDifficulty.name,
    'checkerUnderlays': _checkerUnderlays,
    'roundedTriangleTips': _roundedTriangleTips,
    'sideGunAnglesDegrees': List<double>.from(_sideGunAnglesDegrees),
    'sideGunAmmo': List<int>.from(_sideGunAmmo),
    'turnTimerDurationSeconds': _turnTimerDurationSeconds,
    'redSweepPeriodSeconds': _redSweepPeriodSeconds,
  };

  BoardState _stateForPersistence() =>
      _controller.state.copyWith(tableData: _persistentTableData());

  void _restoreTableData(Map<String, Object?> data) {
    if (data.isEmpty) return;

    final activeNames =
        (data['activeToys'] as List?)?.whereType<String>() ?? const <String>[];
    _activeToys
      ..clear()
      ..addAll([
        for (final name in activeNames)
          if (_ToyKind.values.where((toy) => toy.name == name).firstOrNull
              case final toy?)
            toy,
      ]);

    final dice = DiceBubbleSnapshot.fromJson(data['dice']);
    if (dice != null) _diceSnapshot = dice;
    final zendo = ZendoStonesSnapshot.fromJson(data['zendo']);
    if (zendo != null) _zendoSnapshot = zendo;

    final pieceModeName = data['zendoPieceMode'];
    if (pieceModeName is String) {
      _zendoPieceMode = PieceCycleMode.values
              .where((value) => value.name == pieceModeName)
              .firstOrNull ??
          _zendoPieceMode;
    }
    _zendoRuleIndex = (data['zendoRuleIndex'] as num?)?.toInt() ?? -1;
    _zendoRuleVisible = data['zendoRuleVisible'] == true;
    _zendoComplexRules = data['zendoComplexRules'] == true;

    final difficultyName = data['zendoRuleDifficulty'];
    if (difficultyName is String) {
      _zendoRuleDifficulty = ZendoRuleDifficulty.values
              .where((value) => value.name == difficultyName)
              .firstOrNull ??
          _zendoRuleDifficulty;
    }

    _checkerUnderlays = data['checkerUnderlays'] == true;
    _roundedTriangleTips = data['roundedTriangleTips'] == true;
    _turnTimerDurationSeconds =
        ((data['turnTimerDurationSeconds'] as num?)?.toDouble() ??
                _turnTimerDurationSeconds)
            .clamp(10.0, 300.0)
            .toDouble();
    _turnTimerActiveDurationSeconds = _turnTimerDurationSeconds;
    _redSweepPeriodSeconds =
        ((data['redSweepPeriodSeconds'] as num?)?.toDouble() ??
                _redSweepPeriodSeconds)
            .clamp(2.0, 60.0)
            .toDouble();

    final angles = (data['sideGunAnglesDegrees'] as List?)
        ?.whereType<num>()
        .map((value) => value.toDouble())
        .toList();
    if (angles != null && angles.length == _sideGunAnglesDegrees.length) {
      for (var i = 0; i < angles.length; i += 1) {
        _sideGunAnglesDegrees[i] = angles[i];
      }
    }
    final ammo = (data['sideGunAmmo'] as List?)
        ?.whereType<num>()
        .map((value) => value.toInt())
        .toList();
    if (ammo != null && ammo.length == _sideGunAmmo.length) {
      for (var i = 0; i < ammo.length; i += 1) {
        _sideGunAmmo[i] = ammo[i];
      }
    }

    if (_activeToys.contains(_ToyKind.squareChase)) {
      _squareChaseSeed = _random.nextInt(0x7fffffff);
    }
  }

  Future<void> _applyBrightness() async {
    if (kIsWeb) return;
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(
        _brightness,
      );
    } on Object {
      // Brightness control is optional.
    }
  }

  void _startFaceDownMonitoring() {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _startWebMotionMonitoring();
      return;
    }
    if (_accelerometerSubscription != null) return;
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 180),
    ).listen(_handleAccelerometer, onError: (_) {});
  }

  void _startWebMotionMonitoring() {
    if (!kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _webMotionTimer?.cancel();
    _webMotionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final sample = currentWebMotionSample();
      if (sample != null) {
        _handleAcceleration(sample.x, sample.y, sample.z);
      }
    });
  }

  Future<void> _ensureMotionPermission({bool force = false}) async {
    if (!kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      _startFaceDownMonitoring();
      return;
    }
    if (_motionPermissionAttempted && !force) return;
    _motionPermissionAttempted = true;
    final granted = await requestWebMotionPermission();
    if (!mounted) return;
    if (granted) {
      _faceUpZSign = null;
      _faceUpCandidateSign = null;
      _faceUpStableSamples = 0;
      _startWebMotionMonitoring();
    } else {
      _motionPermissionAttempted = false;
      if (!force) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Motion access was not granted.')),
      );
    }
  }

  void _handleAccelerometer(AccelerometerEvent event) {
    _handleAcceleration(event.x, event.y, event.z);
  }

  void _handleAcceleration(double x, double y, double z) {
    final zDominant =
        z.abs() > 6.0 && z.abs() > x.abs() * 1.05 && z.abs() > y.abs() * 1.05;
    if (!zDominant) {
      _faceDownTimer?.cancel();
      _faceDownTimer = null;
      return;
    }

    final sign = z.sign;
    _lastDominantZSign = sign;
    if (_faceUpZSign == null) {
      if (_faceUpCandidateSign == sign) {
        _faceUpStableSamples += 1;
      } else {
        _faceUpCandidateSign = sign;
        _faceUpStableSamples = 1;
      }
      if (_faceUpStableSamples >= 3) {
        _faceUpZSign = sign;
      }
      return;
    }

    final faceDown = sign != _faceUpZSign;
    if (!faceDown) {
      _faceDownTimer?.cancel();
      _faceDownTimer = null;
      _faceDownLatched = false;
      if (_creditsVisible && mounted) {
        setState(() => _creditsVisible = false);
      }
      return;
    }
    if (_faceDownLatched || _faceDownTimer != null) return;

    _faceDownTimer = Timer(const Duration(milliseconds: 360), () {
      _faceDownTimer = null;
      if (!mounted) return;
      _faceDownLatched = true;
      setState(() => _creditsVisible = true);
    });
  }

  Future<void> _loadInteractionPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final snap = preferences.getDouble('lighthouse.rotationSnapDegrees.v1');
    setState(() {
      _rotationSnapDegrees = snap != null && snap > 0 ? snap : null;
      _gridSnapEnabled =
          preferences.getBool('lighthouse.gridSnapEnabled.v1') ?? false;
      _checkerUnderlays =
          preferences.getBool('lighthouse.checkerUnderlays.v1') ?? false;
      _roundedTriangleTips =
          preferences.getBool('lighthouse.roundedTriangleTips.v1') ?? false;
      _turnTimerDurationSeconds =
          (preferences.getDouble('lighthouse.turnTimerSeconds.v1') ?? 30)
              .clamp(10, 300)
              .toDouble();
      _turnTimerActiveDurationSeconds = _turnTimerDurationSeconds;
      _redSweepPeriodSeconds =
          (preferences.getDouble('lighthouse.redSweepPeriodSeconds.v1') ??
                  13.33)
              .clamp(2, 60)
              .toDouble();
      for (final toy in _ToyKind.values) {
        _toyVisible[toy] =
            preferences.getBool(toy.preferenceKey) ?? toy.defaultVisible;
      }
    });
    if (widget.initialState.tableData.isNotEmpty && mounted) {
      setState(() => _restoreTableData(widget.initialState.tableData));
      if (_needsToyTicker && !_remoteDisplayMode) _ensureToyTicker();
    }
  }

  Future<void> _setRotationSnap(double? degrees) async {
    setState(() => _rotationSnapDegrees = degrees);
    final preferences = await SharedPreferences.getInstance();
    if (degrees == null) {
      await preferences.remove('lighthouse.rotationSnapDegrees.v1');
    } else {
      await preferences.setDouble('lighthouse.rotationSnapDegrees.v1', degrees);
    }
  }

  Future<void> _toggleGridSnap() async {
    setState(() => _gridSnapEnabled = !_gridSnapEnabled);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      'lighthouse.gridSnapEnabled.v1',
      _gridSnapEnabled,
    );
  }

  Future<void> _toggleCheckerUnderlays() async {
    setState(() => _checkerUnderlays = !_checkerUnderlays);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      'lighthouse.checkerUnderlays.v1',
      _checkerUnderlays,
    );
    _scheduleSave();
  }

  Future<void> _toggleRoundedTriangleTips() async {
    setState(() => _roundedTriangleTips = !_roundedTriangleTips);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      'lighthouse.roundedTriangleTips.v1',
      _roundedTriangleTips,
    );
    _scheduleSave();
  }

  Future<void> _saveTurnTimerDuration() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(
      'lighthouse.turnTimerSeconds.v1',
      _turnTimerDurationSeconds,
    );
  }

  Future<void> _saveRedSweepPeriod() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(
      'lighthouse.redSweepPeriodSeconds.v1',
      _redSweepPeriodSeconds,
    );
  }

  Future<void> _toggleToyVisibility(_ToyKind toy) async {
    final next = !(_toyVisible[toy] ?? toy.defaultVisible);
    if (!next) _deactivateToy(toy);
    setState(() => _toyVisible[toy] = next);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(toy.preferenceKey, next);
  }

  static const Set<_ToyKind> _continuousLightToys = {
    _ToyKind.breathing,
    _ToyKind.nestCycle,
    _ToyKind.radar,
    _ToyKind.redSweep,
    _ToyKind.heartbeat,
    _ToyKind.triangleBounce,
    _ToyKind.squareChase,
  };

  void _deactivateToy(_ToyKind toy) {
    _activeToys.remove(toy);
    switch (toy) {
      case _ToyKind.lightLottery:
      case _ToyKind.hotPotato:
        _effectGeneration += 1;
        _randomizerRunning = false;
        _effectOpacities = const {};
        _burstCenter = null;
        _burstProgress = null;
      case _ToyKind.entropy:
        if (_entropyEnabled) _toggleEntropy();
      case _ToyKind.ghostPaths:
        _ghostTrailActive = false;
        _ghostTrails.clear();
      case _ToyKind.eventZone:
        _eventZoneEndsAt = null;
        _eventZoneCenter = null;
        _eventZoneRadiusMm = null;
        _eventZoneProgress = null;
        _eventZoneDismiss = 0;
      case _ToyKind.turnTimer:
        _turnTimerEndsAt = null;
        _turnTimerProgress = null;
        _timerNeedleVisible = false;
      case _ToyKind.wireDie:
      case _ToyKind.zendoStones:
      case _ToyKind.sideGuns:
        _projectiles = _projectiles.where((p) => p.ricochet).toList();
        for (var i = 0; i < _sideGunAmmo.length; i += 1) {
          _sideGunAmmo[i] = 0;
        }
      case _ToyKind.cornerRicochet:
        _projectiles = _projectiles.where((p) => !p.ricochet).toList();
      case _ToyKind.constellationDraw:
        _constellationElementIds = const [];
      case _ToyKind.breathing:
      case _ToyKind.nestCycle:
      case _ToyKind.radar:
      case _ToyKind.redSweep:
      case _ToyKind.heartbeat:
      case _ToyKind.triangleBounce:
      case _ToyKind.squareChase:
        if (!_randomizerRunning) _effectOpacities = const {};
    }
    _maybeStopToyTicker();
    if (mounted) setState(() {});
    _scheduleSave();
  }

  void _activateToy(_ToyKind toy) {
    switch (toy) {
      case _ToyKind.lightLottery:
        _runLightRandomizer();
      case _ToyKind.entropy:
        _toggleEntropy();
      case _ToyKind.ghostPaths:
        _toggleGhostPaths();
      case _ToyKind.eventZone:
        _placeRandomEventZone();
      case _ToyKind.turnTimer:
        _startTurnTimer();
      case _ToyKind.breathing:
      case _ToyKind.nestCycle:
      case _ToyKind.radar:
      case _ToyKind.redSweep:
      case _ToyKind.heartbeat:
      case _ToyKind.triangleBounce:
      case _ToyKind.squareChase:
        _toggleContinuousLightToy(toy);
      case _ToyKind.wireDie:
        _toggleDie();
      case _ToyKind.sideGuns:
        _loadSideGuns();
      case _ToyKind.cornerRicochet:
        _launchCornerRicochets();
      case _ToyKind.hotPotato:
        _runHotPotato();
      case _ToyKind.constellationDraw:
        _toggleConstellation();
      case _ToyKind.zendoStones:
        _toggleOverlayToy(toy);
    }
    _scheduleSave();
  }

  bool _toyIsActive(_ToyKind toy) {
    if (_activeToys.contains(toy)) return true;
    return switch (toy) {
      _ToyKind.lightLottery || _ToyKind.hotPotato => _randomizerRunning,
      _ToyKind.entropy => _entropyEnabled,
      _ToyKind.ghostPaths => _ghostTrailActive,
      _ToyKind.eventZone => _eventZoneCenter != null,
      _ToyKind.turnTimer => _turnTimerProgress != null,
      _ToyKind.wireDie => _activeToys.contains(_ToyKind.wireDie),
      _ToyKind.sideGuns => _activeToys.contains(_ToyKind.sideGuns),
      _ToyKind.cornerRicochet => _projectiles.any((p) => p.ricochet),
      _ToyKind.constellationDraw => _constellationElementIds.isNotEmpty,
      _ToyKind.zendoStones => _activeToys.contains(_ToyKind.zendoStones),
      _ToyKind.breathing ||
      _ToyKind.nestCycle ||
      _ToyKind.radar ||
      _ToyKind.redSweep ||
      _ToyKind.heartbeat ||
      _ToyKind.triangleBounce ||
      _ToyKind.squareChase => _activeToys.contains(toy),
    };
  }

  bool get _remoteDisplayMode => _remoteSession?.role == RemoteRole.display;

  bool get _remoteControllerMode =>
      _remoteSession?.role == RemoteRole.controller;

  bool get _remoteDisplayInputBlocked =>
      _remoteDisplayMode && !_remoteControlState.displayInteractionsEnabled;

  double get _remoteUiScale {
    if (!_remoteControllerMode) return 1;
    final displayPixelsPerMm = _remoteDisplayPixelsPerMm;
    if (displayPixelsPerMm == null || displayPixelsPerMm <= 0) return 1;
    return (_pixelsPerMm / displayPixelsPerMm).clamp(0.25, 4.0).toDouble();
  }

  Rect? _remoteBoardRect(BuildContext surfaceContext) {
    final widthMm = _remoteDisplayWidthMm;
    final heightMm = _remoteDisplayHeightMm;
    if (!_remoteControllerMode || widthMm == null || heightMm == null) {
      return null;
    }
    return fitRemoteBoardRect(
      hostSize: MediaQuery.sizeOf(surfaceContext),
      safePadding: MediaQuery.viewPaddingOf(surfaceContext),
      remoteSize: Size(widthMm, heightMm),
    );
  }

  double get _pixelsPerMm {
    final widthMm = _remoteDisplayWidthMm;
    final rect = _remoteBoardRect(context);
    if (!_remoteControllerMode || widthMm == null || rect == null) {
      return widget.logicalPixelsPerMm;
    }
    return math.max(0.1, rect.width / widthMm);
  }

  EdgeInsets _boardSurfacePadding(BuildContext surfaceContext) {
    final remoteRect = _remoteBoardRect(surfaceContext);
    if (remoteRect == null) return MediaQuery.viewPaddingOf(surfaceContext);
    final size = MediaQuery.sizeOf(surfaceContext);
    return EdgeInsets.fromLTRB(
      remoteRect.left,
      remoteRect.top,
      math.max(0.0, size.width - remoteRect.right),
      math.max(0.0, size.height - remoteRect.bottom),
    );
  }

  ({double width, double height}) _physicalBoardSize() {
    final remoteWidth = _remoteDisplayWidthMm;
    final remoteHeight = _remoteDisplayHeightMm;
    if (_remoteControllerMode && remoteWidth != null && remoteHeight != null) {
      return (width: remoteWidth, height: remoteHeight);
    }
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    return (
      width: math.max(1.0, (size.width - padding.horizontal) / _pixelsPerMm),
      height: math.max(1.0, (size.height - padding.vertical) / _pixelsPerMm),
    );
  }

  void _toggleContinuousLightToy(_ToyKind toy) {
    if (_activeToys.contains(toy)) {
      _activeToys.remove(toy);
      if (!_randomizerRunning) _effectOpacities = const {};
      _maybeStopToyTicker();
      setState(() {});
      _scheduleSave();
      return;
    }
    _activeToys.add(toy);
    if (toy == _ToyKind.squareChase) {
      _squareChaseSeed = _random.nextInt(0x7fffffff);
    }
    if (toy == _ToyKind.heartbeat) {
      final elements = _controller.state.elements;
      _heartbeatOddId = elements.isEmpty
          ? null
          : elements[_random.nextInt(elements.length)].id;
      _heartbeatStartedAt = _toyClock;
    }
    _ensureToyTicker();
    setState(() {});
    _scheduleSave();
  }

  void _toggleGhostPaths() {
    setState(() {
      _ghostTrailActive = !_ghostTrailActive;
      _ghostTrails.clear();
      if (_ghostTrailActive) {
        for (final element in _controller.state.elements) {
          _ghostTrails[element.id] = [element.position];
        }
      }
    });
  }

  void _placeRandomEventZone() {
    final board = _physicalBoardSize();
    final maximumRadius = math.max(
      6.0,
      math.min(board.width, board.height) * 0.24,
    );
    final radius = math.min(maximumRadius, 12 + _random.nextDouble() * 18);
    final xSpan = math.max(0.0, board.width - radius * 2);
    final ySpan = math.max(0.0, board.height - radius * 2);
    setState(() {
      _eventZoneCenter = PhysicalPoint(
        radius + _random.nextDouble() * xSpan,
        radius + _random.nextDouble() * ySpan,
      );
      _eventZoneRadiusMm = radius;
      _eventZoneProgress = 1;
      _eventZoneDismiss = 0;
      _eventZoneEndsAt = DateTime.now().add(const Duration(seconds: 12));
    });
    _ensureToyTicker();
  }

  void _startTurnTimer() {
    setState(() {
      _turnTimerActiveDurationSeconds = _turnTimerDurationSeconds;
      _turnTimerEndsAt = DateTime.now().add(
        Duration(milliseconds: (_turnTimerDurationSeconds * 1000).round()),
      );
      _turnTimerProgress = 1;
    });
    _ensureToyTicker();
  }

  void _beginTimerAdjustment(LongPressStartDetails details) {
    _timerLongPressStartDuration = _turnTimerDurationSeconds;
    setState(() => _timerNeedleVisible = true);
  }

  void _updateTimerAdjustment(LongPressMoveUpdateDetails details) {
    final multiplier = math
        .pow(2, -details.offsetFromOrigin.dx / 78)
        .toDouble();
    final next = (_timerLongPressStartDuration * multiplier)
        .clamp(10.0, 300.0)
        .toDouble();
    final progress = _turnTimerProgress;
    setState(() {
      _turnTimerDurationSeconds = next;
      if (_turnTimerEndsAt != null && progress != null) {
        _turnTimerActiveDurationSeconds = next;
        _turnTimerEndsAt = DateTime.now().add(
          Duration(milliseconds: (next * 1000 * progress).round()),
        );
      }
    });
  }

  void _endTimerAdjustment(LongPressEndDetails details) {
    setState(() => _timerNeedleVisible = false);
    unawaited(_saveTurnTimerDuration());
    _scheduleSave();
  }

  void _cancelTimerAdjustment() {
    if (!_timerNeedleVisible) return;
    setState(() => _timerNeedleVisible = false);
    unawaited(_saveTurnTimerDuration());
    _scheduleSave();
  }

  void _beginRedSweepAdjustment(LongPressStartDetails details) {
    _redSweepLongPressStartPeriod = _redSweepPeriodSeconds;
    setState(() => _redSweepNeedleVisible = true);
  }

  void _updateRedSweepAdjustment(LongPressMoveUpdateDetails details) {
    final multiplier = math
        .pow(2, -details.offsetFromOrigin.dx / 78)
        .toDouble();
    final next = (_redSweepLongPressStartPeriod * multiplier)
        .clamp(2.0, 60.0)
        .toDouble();
    setState(() => _redSweepPeriodSeconds = next);
  }

  void _endRedSweepAdjustment(LongPressEndDetails details) {
    setState(() => _redSweepNeedleVisible = false);
    unawaited(_saveRedSweepPeriod());
    _scheduleSave();
  }

  void _cancelRedSweepAdjustment() {
    if (!_redSweepNeedleVisible) return;
    setState(() => _redSweepNeedleVisible = false);
    unawaited(_saveRedSweepPeriod());
    _scheduleSave();
  }

  void _toggleOverlayToy(_ToyKind toy) {
    setState(() {
      if (!_activeToys.add(toy)) _activeToys.remove(toy);
    });
  }

  void _toggleDie() => _toggleOverlayToy(_ToyKind.wireDie);

  void _loadSideGuns() {
    final fullyLoaded =
        _activeToys.contains(_ToyKind.sideGuns) &&
        _sideGunAmmo.every((rounds) => rounds >= 5);
    if (fullyLoaded) {
      _deactivateToy(_ToyKind.sideGuns);
      unawaited(_sendRemoteRuntimeIfChanged(force: true));
      return;
    }
    _activeToys.add(_ToyKind.sideGuns);
    for (var i = 0; i < _sideGunAmmo.length; i += 1) {
      _sideGunAmmo[i] = 5;
    }
    HapticFeedback.selectionClick();
    setState(() {});
    unawaited(_sendRemoteRuntimeIfChanged(force: true));
  }

  PhysicalPoint _velocityForDegrees(double degrees, double speed) {
    final radians = degrees * math.pi / 180;
    return PhysicalPoint(math.cos(radians) * speed, math.sin(radians) * speed);
  }

  void _fireSideGun(int index) {
    if (!_activeToys.contains(_ToyKind.sideGuns) ||
        index < 0 ||
        index >= _sideGunAmmo.length ||
        _sideGunAmmo[index] <= 0) {
      HapticFeedback.selectionClick();
      return;
    }
    final table = _physicalBoardSize();
    const speed = 85.0;
    final scale = _remoteUiScale;
    final topInset = 18 * scale / _pixelsPerMm;
    final bottomInset = 68 * scale / _pixelsPerMm;
    final position = switch (index) {
      0 => PhysicalPoint(topInset, topInset),
      1 => PhysicalPoint(table.width - topInset, topInset),
      2 => PhysicalPoint(topInset, table.height - bottomInset),
      _ => PhysicalPoint(
        table.width - topInset,
        table.height - bottomInset,
      ),
    };
    _sideGunAmmo[index] -= 1;
    _projectiles = [
      ..._projectiles,
      ToyProjectile(
        position: position,
        velocity: _velocityForDegrees(_sideGunAnglesDegrees[index], speed),
        radiusMm: 0.8,
      ),
    ];
    HapticFeedback.lightImpact();
    _ensureToyTicker();
    setState(() {});
    _scheduleSave();
    unawaited(_sendRemoteRuntimeIfChanged(force: true));
  }

  void _aimGunFromLocal(int gunIndex, Offset localPosition) {
    final scale = _remoteUiScale;
    final box = 132.0 * scale;
    final topInset = 18.0 * scale;
    final bottomInset = 68.0 * scale;
    final center = switch (gunIndex) {
      0 => Offset(topInset, topInset),
      1 => Offset(box - topInset, topInset),
      2 => Offset(topInset, box - bottomInset),
      _ => Offset(box - topInset, box - bottomInset),
    };
    final base = <double>[45, 135, 315, 225][gunIndex];
    final raw = normalizeDegrees(
      math.atan2(localPosition.dy - center.dy, localPosition.dx - center.dx) *
          180 /
          math.pi,
    );
    final offset = ((raw - base + 540) % 360) - 180;
    setState(() {
      _sideGunAnglesDegrees[gunIndex] = normalizeDegrees(
        base + offset.clamp(-72, 72).toDouble(),
      );
    });
    unawaited(_sendRemoteRuntimeIfChanged());
  }

  void _launchCornerRicochets() {
    final board = _physicalBoardSize();
    const speed = 42.0;
    _projectiles = [
      ..._projectiles,
      ToyProjectile(
        position: const PhysicalPoint(2.25, 2.25),
        velocity: const PhysicalPoint(speed, speed * 0.73),
        radiusMm: 2.1,
        ricochet: true,
      ),
      ToyProjectile(
        position: PhysicalPoint(board.width - 2.25, 2.25),
        velocity: const PhysicalPoint(-speed * 0.81, speed),
        radiusMm: 2.1,
        ricochet: true,
      ),
      ToyProjectile(
        position: PhysicalPoint(2.25, board.height - 2.25),
        velocity: const PhysicalPoint(speed, -speed * 0.86),
        radiusMm: 2.1,
        ricochet: true,
      ),
      ToyProjectile(
        position: PhysicalPoint(board.width - 2.25, board.height - 2.25),
        velocity: const PhysicalPoint(-speed, -speed * 0.69),
        radiusMm: 2.1,
        ricochet: true,
      ),
    ];
    _ensureToyTicker();
    setState(() {});
    unawaited(_sendRemoteRuntimeIfChanged(force: true));
  }

  void _ensureToyTicker() {
    if (_remoteDisplayMode || _toyTicker != null) return;
    _lastToyTickAt = DateTime.now();
    _toyTicker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final now = DateTime.now();
      final previous = _lastToyTickAt;
      _lastToyTickAt = now;
      final elapsedSeconds = previous == null
          ? 0.033
          : now.difference(previous).inMicroseconds / 1000000;
      _tickToys(elapsedSeconds.clamp(0.0, 0.1).toDouble());
    });
  }

  bool get _needsToyTicker =>
      _activeToys.any(_continuousLightToys.contains) ||
      _eventZoneCenter != null ||
      _turnTimerProgress != null ||
      _projectiles.isNotEmpty ||
      _impacts.isNotEmpty;

  void _maybeStopToyTicker() {
    if (_needsToyTicker) return;
    _toyTicker?.cancel();
    _toyTicker = null;
    _lastToyTickAt = null;
  }

  void _tickToys(double dt) {
    if (!mounted) return;
    final eventWasActive = _eventZoneCenter != null;
    final timerWasActive = _turnTimerProgress != null;
    final ricochetWasActive = _projectiles.any((p) => p.ricochet);
    _toyClock += dt;
    final now = DateTime.now();

    final eventEnds = _eventZoneEndsAt;
    if (eventEnds != null) {
      final remaining = eventEnds.difference(now).inMilliseconds / 1000;
      if (remaining <= 0) {
        _eventZoneProgress = 0;
        _eventZoneDismiss += dt / 0.65;
        if (_eventZoneDismiss >= 1) {
          _eventZoneEndsAt = null;
          _eventZoneCenter = null;
          _eventZoneRadiusMm = null;
          _eventZoneProgress = null;
          _eventZoneDismiss = 0;
        }
      } else {
        _eventZoneProgress = (remaining / 12).clamp(0, 1).toDouble();
      }
    }

    final turnEnds = _turnTimerEndsAt;
    if (turnEnds != null) {
      final remaining = turnEnds.difference(now).inMilliseconds;
      if (remaining <= 0) {
        _turnTimerEndsAt = null;
        _turnTimerProgress = null;
        HapticFeedback.mediumImpact();
      } else {
        _turnTimerProgress =
            (remaining / (_turnTimerActiveDurationSeconds * 1000))
                .clamp(0, 1)
                .toDouble();
      }
    }

    _tickProjectiles(dt);
    _updateContinuousLighting(dt);
    _toyRevision.value += 1;
    _maybeStopToyTicker();

    final controlStateChanged =
        eventWasActive != (_eventZoneCenter != null) ||
        timerWasActive != (_turnTimerProgress != null) ||
        ricochetWasActive != _projectiles.any((p) => p.ricochet);
    if (controlStateChanged && mounted) setState(() {});
  }

  ({double minY, double maxY}) _verticalBoundsFor(LightElement element) {
    final cached = _elementVerticalBounds[element.id];
    if (cached != null) return cached;
    final polygon = polygonForElement(element, _controller.geometry);
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final point in polygon) {
      minY = math.min(minY, point.yMm);
      maxY = math.max(maxY, point.yMm);
    }
    final bounds = (minY: minY, maxY: maxY);
    _elementVerticalBounds[element.id] = bounds;
    return bounds;
  }

  void _updateContinuousLighting(double dt) {
    final elements = _controller.state.elements;
    if (elements.isEmpty) {
      _effectOpacities = const {};
      return;
    }
    if (_randomizerRunning) return;

    final radarOn = _activeToys.contains(_ToyKind.radar);
    final sweepOn = _activeToys.contains(_ToyKind.redSweep);
    final breathingOn = _activeToys.contains(_ToyKind.breathing);
    final heartbeatOn = _activeToys.contains(_ToyKind.heartbeat);
    if (!radarOn && !sweepOn && !breathingOn && !heartbeatOn) {
      _effectOpacities = const {};
      return;
    }

    final table = _physicalBoardSize();
    final center = PhysicalPoint(table.width / 2, table.height / 2);
    if (radarOn) {
      _radarAngleDegrees = normalizeDegrees(
        _radarAngleDegrees + (1.8 / 0.033) * dt,
      );
    }
    if (sweepOn) {
      final phase = (_toyClock * 2 / _redSweepPeriodSeconds) % 2;
      _redSweepY = phase <= 1 ? phase : 2 - phase;
    }
    final lineY = table.height * _redSweepY;
    final elapsedHeartbeat = _toyClock - _heartbeatStartedAt;

    final next = <String, double>{};
    for (final element in elements) {
      var opacity = 1.0;
      if (breathingOn) opacity = math.min(opacity, _breathOpacity(element));
      if (radarOn) {
        opacity = math.min(
          opacity,
          _radarOpacity(element.position, center, _radarAngleDegrees),
        );
      }
      if (sweepOn) {
        final bounds = _verticalBoundsFor(element);
        opacity = math.min(
          opacity,
          lineY >= bounds.minY && lineY <= bounds.maxY ? 1.0 : 0.035,
        );
      }
      if (heartbeatOn) {
        opacity = math.min(
          opacity,
          _heartbeatOpacity(element.id == _heartbeatOddId, elapsedHeartbeat),
        );
      }
      next[element.id] = opacity;
    }
    _effectOpacities = next;
  }

  Map<String, double> get _paintElementOpacities {
    final result = Map<String, double>.from(_effectOpacities);
    if (_activeToys.contains(_ToyKind.nestCycle)) {
      final phase = ((_toyClock / 0.58).floor()) % 3;
      final wanted = [
        PyramidSize.large,
        PyramidSize.medium,
        PyramidSize.small,
      ][phase];
      for (final structure in _controller.state.structures) {
        if (structure.kind != StructureKind.nest) continue;
        for (final id in structure.memberIds) {
          final element = _controller.state.elementById(id);
          if (element != null) {
            result[id] = element.size == wanted ? 1.0 : 0.025;
          }
        }
      }
    }
    if (_remoteDisplayMode && !_remoteControlState.displayShapesVisible) {
      for (final element in _controller.state.elements) {
        result[element.id] = 0;
      }
    }
    return result;
  }

  double _breathOpacity(LightElement element) {
    final period = switch (element.size) {
      PyramidSize.small => 2.5,
      PyramidSize.medium => 3.6,
      PyramidSize.large => 5.0,
    };
    final phase = (element.id.hashCode.abs() % 1000) / 1000 * math.pi * 2;
    final wave = 0.5 + 0.5 * math.sin(_toyClock * math.pi * 2 / period + phase);
    return 0.035 + 0.965 * wave;
  }

  double _radarOpacity(
    PhysicalPoint point,
    PhysicalPoint center,
    double angle,
  ) {
    final dx = point.xMm - center.xMm;
    final dy = point.yMm - center.yMm;
    final elementAngle = normalizeDegrees(math.atan2(dy, dx) * 180 / math.pi);
    final behind = normalizeDegrees(angle - elementAngle);
    if (behind <= 18) return 1;
    if (behind <= 62) return 1 - (behind - 18) / 44 * 0.965;
    return 0.035;
  }

  double _heartbeatOpacity(bool odd, double elapsed) {
    final separationTime = math.max(0.0, elapsed - 4.0);
    final drift = odd ? math.min(math.pi, separationTime * 0.23) : 0.0;
    final pulse = 0.5 + 0.5 * math.sin(_toyClock * math.pi * 1.7 + drift);
    return 0.04 + pulse * 0.96;
  }

  double _elementBoundingRadiusMm(LightElement element) {
    final halfBase = _controller.geometry.baseMm(element.size) / 2;
    if (element.pose == PyramidPose.upright) {
      return math.sqrt(halfBase * halfBase * 2);
    }
    final halfLength = _controller.geometry.flatLengthMm(element.size) / 2;
    return math.sqrt(halfBase * halfBase + halfLength * halfLength);
  }

  bool _couldProjectileTouch(
    LightElement element,
    PhysicalPoint point,
    double extraRadiusMm,
  ) =>
      element.position.distanceTo(point) <=
      _elementBoundingRadiusMm(element) + extraRadiusMm;

  ({PhysicalPoint contact, PhysicalPoint normal, double distance})
  _nearestBoundary(LightElement element, PhysicalPoint point) {
    final polygon = polygonForElement(element, _controller.geometry);
    var cx = 0.0;
    var cy = 0.0;
    for (final p in polygon) {
      cx += p.xMm;
      cy += p.yMm;
    }
    final centroid = PhysicalPoint(cx / polygon.length, cy / polygon.length);
    var bestDistance = double.infinity;
    var bestContact = polygon.first;
    var bestOutward = const PhysicalPoint(1, 0);
    for (var i = 0; i < polygon.length; i += 1) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      final ex = b.xMm - a.xMm;
      final ey = b.yMm - a.yMm;
      final length2 = ex * ex + ey * ey;
      final t = length2 <= 0
          ? 0.0
          : (((point.xMm - a.xMm) * ex + (point.yMm - a.yMm) * ey) / length2)
                .clamp(0.0, 1.0)
                .toDouble();
      final q = PhysicalPoint(a.xMm + ex * t, a.yMm + ey * t);
      final dx = point.xMm - q.xMm;
      final dy = point.yMm - q.yMm;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance >= bestDistance) continue;
      final edgeLength = math.max(0.0001, math.sqrt(length2));
      var nx = ey / edgeLength;
      var ny = -ex / edgeLength;
      final mx = (a.xMm + b.xMm) / 2;
      final my = (a.yMm + b.yMm) / 2;
      if ((centroid.xMm - mx) * nx + (centroid.yMm - my) * ny > 0) {
        nx = -nx;
        ny = -ny;
      }
      bestDistance = distance;
      bestContact = q;
      bestOutward = PhysicalPoint(nx, ny);
    }
    if (!_containsPoint(element, point) && bestDistance > 0.001) {
      final dx = point.xMm - bestContact.xMm;
      final dy = point.yMm - bestContact.yMm;
      bestOutward = PhysicalPoint(dx / bestDistance, dy / bestDistance);
    }
    return (contact: bestContact, normal: bestOutward, distance: bestDistance);
  }

  void _tickProjectiles(double dt) {
    if (_projectiles.isEmpty && _impacts.isEmpty) return;
    final table = _physicalBoardSize();
    final next = <ToyProjectile>[];
    final hitIds = <String>{};
    final impacts = <ToyImpact>[
      for (final impact in _impacts)
        if (impact.lifeSeconds - dt > 0)
          impact.copyWith(lifeSeconds: impact.lifeSeconds - dt),
    ];

    for (final projectile in _projectiles) {
      var position = projectile.position;
      var velocity = projectile.velocity;
      var edgeHits = projectile.edgeHits;
      var escaping = projectile.escaping;
      final speed = math.sqrt(
        velocity.xMm * velocity.xMm + velocity.yMm * velocity.yMm,
      );
      final stepDistance = math.max(0.55, projectile.radiusMm * 0.55);
      final steps = math.max(1, (speed * dt / stepDistance).ceil());
      final stepDt = dt / steps;
      var consumed = false;

      for (var step = 0; step < steps && !consumed; step += 1) {
        position =
            position +
            PhysicalPoint(velocity.xMm * stepDt, velocity.yMm * stepDt);

        if (projectile.ricochet) {
          if (!escaping) {
            final radius = projectile.radiusMm;
            final hitLeft = position.xMm <= radius;
            final hitRight = position.xMm >= table.width - radius;
            final hitTop = position.yMm <= radius;
            final hitBottom = position.yMm >= table.height - radius;
            if (hitLeft || hitRight || hitTop || hitBottom) {
              edgeHits += 1;
              if (edgeHits >= 4) {
                escaping = true;
              } else {
                if (hitLeft || hitRight) {
                  velocity = PhysicalPoint(-velocity.xMm, velocity.yMm);
                }
                if (hitTop || hitBottom) {
                  velocity = PhysicalPoint(velocity.xMm, -velocity.yMm);
                }
                position = PhysicalPoint(
                  position.xMm.clamp(radius, table.width - radius).toDouble(),
                  position.yMm.clamp(radius, table.height - radius).toDouble(),
                );
              }
            }

            if (!escaping) {
              for (final element in _controller.state.elements) {
                if (!_couldProjectileTouch(
                  element,
                  position,
                  projectile.radiusMm,
                )) {
                  continue;
                }
                final boundary = _nearestBoundary(element, position);
                final inside = _containsPoint(element, position);
                if (!inside && boundary.distance > projectile.radiusMm)
                  continue;
                final normal = boundary.normal;
                final dot =
                    velocity.xMm * normal.xMm + velocity.yMm * normal.yMm;
                if (dot < 0) {
                  velocity = PhysicalPoint(
                    velocity.xMm - 2 * dot * normal.xMm,
                    velocity.yMm - 2 * dot * normal.yMm,
                  );
                }
                position = PhysicalPoint(
                  boundary.contact.xMm +
                      normal.xMm * (projectile.radiusMm + 0.18),
                  boundary.contact.yMm +
                      normal.yMm * (projectile.radiusMm + 0.18),
                );
                break;
              }
            }
          }
        } else {
          for (final element in _controller.state.elements) {
            if (!_couldProjectileTouch(
              element,
              position,
              projectile.radiusMm,
            )) {
              continue;
            }
            if (!_containsPoint(element, position)) continue;
            hitIds.add(element.id);
            impacts.add(ToyImpact(position: position, lifeSeconds: 0.8));
            consumed = true;
            break;
          }
        }
      }

      if (consumed) continue;
      final margin = projectile.ricochet ? 7.0 : 2.0;
      final outside =
          position.xMm < -margin ||
          position.xMm > table.width + margin ||
          position.yMm < -margin ||
          position.yMm > table.height + margin;
      if (!outside) {
        next.add(
          projectile.copyWith(
            position: position,
            velocity: velocity,
            edgeHits: edgeHits,
            escaping: escaping,
          ),
        );
      }
    }

    _projectiles = next;
    _impacts = impacts;
    for (final id in hitIds) {
      final element = _controller.state.elementById(id);
      if (element != null) _controller.deleteElement(element);
    }
  }

  Future<void> _runHotPotato() async {
    if (_randomizerRunning || _controller.state.elements.isEmpty) return;
    final generation = ++_effectGeneration;
    _randomizerRunning = true;
    var current = _controller
        .state
        .elements[_random.nextInt(_controller.state.elements.length)];
    final recent = <String>[current.id];
    var delay = 390;
    for (var i = 0; i < 30; i += 1) {
      if (!mounted || generation != _effectGeneration) return;
      final elements = _controller.state.elements;
      if (elements.isEmpty) break;
      final available = elements.where((e) => e.id != current.id).toList()
        ..sort(
          (a, b) => current.position
              .distanceTo(a.position)
              .compareTo(current.position.distanceTo(b.position)),
        );
      if (available.isNotEmpty) {
        final fresh = available.where((e) => !recent.contains(e.id)).toList();
        final pool = fresh.isNotEmpty
            ? fresh.take(2).toList()
            : available.take(2).toList();
        current = pool[_random.nextInt(pool.length)];
      }
      recent.add(current.id);
      if (recent.length > 4) recent.removeAt(0);
      final previous = recent.length >= 2 ? recent[recent.length - 2] : null;
      setState(() {
        _effectOpacities = {
          for (final e in elements)
            e.id: e.id == current.id
                ? 1.0
                : e.id == previous
                ? 0.28
                : 0.035,
        };
      });
      await Future<void>.delayed(Duration(milliseconds: delay));
      delay = math.max(80, (delay * 0.92).round());
    }
    await Future<void>.delayed(const Duration(milliseconds: 1350));
    if (!mounted || generation != _effectGeneration) return;
    setState(() {
      _randomizerRunning = false;
      _effectOpacities = const {};
    });
  }

  void _toggleConstellation() {
    if (_constellationElementIds.isNotEmpty) {
      setState(() => _constellationElementIds = const []);
      return;
    }
    final elements = [..._controller.state.elements]..shuffle(_random);
    if (elements.length < 2) return;
    final count = math.min(elements.length, 2 + _random.nextInt(4));
    setState(() {
      _constellationElementIds = [for (final e in elements.take(count)) e.id];
    });
  }

  List<PhysicalPoint> get _constellationPoints => [
    for (final id in _constellationElementIds)
      if (_controller.state.elementById(id) case final element?)
        element.position,
  ];

  PhysicalPoint? _nearestUnderlaySnapPoint() {
    if (!_gridSnapEnabled || !_transformTranslated) return null;
    final targetId = _transformTarget?.id ?? _desktopScrollTarget?.id;
    if (targetId == null) return null;
    final target = _controller.state.elementById(targetId);
    if (target == null || !_controller.state.underlay.isVisible) return null;
    final board = _physicalBoardSize();
    final snap = _controller.state.underlay.nearestSnapPoint(
      target.position,
      boardWidthMm: board.width,
      boardHeightMm: board.height,
    );
    if (snap == null ||
        _controller.state.underlay != BoardUnderlay.wheel ||
        target.pose != PyramidPose.flat)
      return snap;
    final centroidOffset = rotateVector(
      PhysicalPoint(0, _controller.geometry.flatLengthMm(target.size) / 6),
      target.headingDegrees,
    );
    return snap - centroidOffset;
  }

  void _endTransformWithSnaps({bool includeGrid = true}) {
    _controller.endTransform(
      snapDegrees: _rotationSnapDegrees,
      snapPosition: includeGrid ? _nearestUnderlaySnapPoint() : null,
    );
    _transformTranslated = false;
  }

  Future<void> _runLightRandomizer() async {
    if (_randomizerRunning || _controller.state.elements.isEmpty) return;
    final generation = ++_effectGeneration;
    setState(() {
      _randomizerRunning = true;
      _effectOpacities = {
        for (final element in _controller.state.elements) element.id: 0.0,
      };
      _burstCenter = null;
      _burstProgress = null;
    });

    Future<bool> wait(Duration duration) async {
      await Future<void>.delayed(duration);
      return mounted && generation == _effectGeneration;
    }

    const beat = Duration(milliseconds: 120);
    if (!await wait(beat)) return;
    final milliseconds = 3000 + _random.nextInt(7001);
    final endAt = DateTime.now().add(Duration(milliseconds: milliseconds));
    String? previousId;
    while (DateTime.now().isBefore(endAt)) {
      final elements = _controller.state.elements;
      if (elements.isEmpty) break;
      final candidates = previousId == null || elements.length == 1
          ? elements
          : elements.where((element) => element.id != previousId).toList();
      final element = candidates[_random.nextInt(candidates.length)];
      if (!mounted || generation != _effectGeneration) return;
      setState(() {
        _effectOpacities = {
          for (final current in elements)
            current.id: current.id == element.id ? 1.0 : 0.0,
        };
      });
      previousId = element.id;
      if (!await wait(beat)) return;
    }
    final elements = _controller.state.elements;
    if (elements.isEmpty || !mounted || generation != _effectGeneration) {
      if (mounted) {
        setState(() {
          _randomizerRunning = false;
          _effectOpacities = const {};
        });
      }
      return;
    }

    setState(() {
      _effectOpacities = {for (final element in elements) element.id: 0};
    });
    if (!await wait(const Duration(milliseconds: 240))) return;

    final winner = elements[_random.nextInt(elements.length)];
    setState(() {
      _effectOpacities = {
        for (final element in elements)
          element.id: element.id == winner.id ? 1.0 : 0.0,
      };
      _burstCenter = winner.position;
      _burstProgress = 0.0;
    });

    for (var frame = 0; frame <= 42; frame += 1) {
      if (!mounted || generation != _effectGeneration) return;
      setState(() => _burstProgress = frame / 42);
      if (!await wait(const Duration(milliseconds: 20))) return;
    }
    setState(() => _burstProgress = null);

    for (var frame = 0; frame <= 36; frame += 1) {
      if (!mounted || generation != _effectGeneration) return;
      final opacity = frame / 36;
      final currentIds = _controller.state.elements.map((e) => e.id).toSet();
      setState(() {
        _effectOpacities = {
          for (final id in currentIds) id: id == winner.id ? 1 : opacity,
        };
      });
      if (!await wait(const Duration(milliseconds: 36))) return;
    }

    if (!mounted || generation != _effectGeneration) return;
    setState(() {
      _randomizerRunning = false;
      _effectOpacities = const {};
      _burstCenter = null;
      _burstProgress = null;
    });
  }

  void _toggleEntropy() {
    _entropyGeneration += 1;
    _entropyTimer?.cancel();
    setState(() => _entropyEnabled = !_entropyEnabled);
    if (!_entropyEnabled) return;
    _entropyTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fadeAndDeleteRandomElement(),
    );
  }

  Future<void> _fadeAndDeleteRandomElement() async {
    if (!_entropyEnabled || _randomizerRunning) return;
    final elements = _controller.state.elements;
    if (elements.isEmpty) return;
    final generation = _entropyGeneration;
    final victim = elements[_random.nextInt(elements.length)];
    for (var frame = 0; frame <= 24; frame += 1) {
      if (!mounted ||
          generation != _entropyGeneration ||
          !_entropyEnabled ||
          _randomizerRunning) {
        return;
      }
      final opacity = 1 - frame / 24;
      setState(() {
        _effectOpacities = {..._effectOpacities, victim.id: opacity};
      });
      await Future<void>.delayed(const Duration(milliseconds: 45));
    }
    if (!mounted || generation != _entropyGeneration || !_entropyEnabled)
      return;
    final current = _controller.state.elementById(victim.id);
    if (current != null) _controller.deleteElement(current);
    if (mounted) {
      setState(() {
        final next = Map<String, double>.from(_effectOpacities)
          ..remove(victim.id);
        _effectOpacities = next;
      });
    }
  }

  Map<String, Object?> _remotePoint(PhysicalPoint point) => {
    'x': point.xMm,
    'y': point.yMm,
  };

  PhysicalPoint? _pointFromRemote(Object? raw) {
    if (raw is! Map) return null;
    final x = raw['x'];
    final y = raw['y'];
    if (x is! num || y is! num) return null;
    return PhysicalPoint(x.toDouble(), y.toDouble());
  }

  void _syncRippleTicker() {
    if (_remoteControlState.rippleLevels.isEmpty) {
      _rippleTimer?.cancel();
      _rippleTimer = null;
      _lastRippleTickAt = null;
      return;
    }
    if (_rippleTimer != null) return;
    _lastRippleTickAt = DateTime.now();
    _rippleTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final now = DateTime.now();
      final previous = _lastRippleTickAt;
      _lastRippleTickAt = now;
      final dt = previous == null
          ? 0.033
          : now.difference(previous).inMicroseconds / 1000000;
      _rippleClock += dt.clamp(0.0, 0.1).toDouble();
      _toyRevision.value += 1;
    });
  }

  void _setRemoteControlState(RemoteBoardControlState next) {
    final liveIds = _controller.state.elements
        .map((element) => element.id)
        .toSet();
    final retained = next.retainElementIds(liveIds);
    setState(() => _remoteControlState = retained);
    _syncRippleTicker();
  }

  Future<void> _broadcastRemoteControlState() async {
    final session = _remoteSession;
    if (session == null || session.role != RemoteRole.display) return;
    await session.sendApp('controlState', {
      'role': session.role.name,
      'control': _remoteControlState.toJson(),
    });
  }

  Future<void> _sendRemoteControlCommand(
    String command, {
    Map<String, Object?> payload = const {},
  }) async {
    final session = _remoteSession;
    if (session == null || session.role != RemoteRole.controller) return;
    await session.sendApp('controlCommand', {'command': command, ...payload});
  }

  Future<void> _setBoardUnitInteractions(bool enabled) async {
    _setRemoteControlState(
      _remoteControlState.copyWith(displayInteractionsEnabled: enabled),
    );
    await _sendRemoteControlCommand(
      'setDisplayInteractions',
      payload: {'enabled': enabled},
    );
  }

  Future<void> _setBoardUnitShapesVisible(bool visible) async {
    _setRemoteControlState(
      _remoteControlState.copyWith(displayShapesVisible: visible),
    );
    await _sendRemoteControlCommand(
      'setDisplayShapesVisible',
      payload: {'visible': visible},
    );
  }

  Future<void> _cycleRipple(String elementId) async {
    final next = _remoteControlState.cycleRipple(elementId);
    _setRemoteControlState(next);
    final level = next.rippleLevels[elementId];
    await _sendRemoteControlCommand(
      'setRipple',
      payload: {'elementId': elementId, 'level': level?.wireValue ?? 0},
    );
    HapticFeedback.selectionClick();
  }

  void _queueRippleTap(String elementId) {
    _rippleTapTimer?.cancel();
    _rippleTapTimer = Timer(kDoubleTapTimeout, () {
      _rippleTapTimer = null;
      if (!mounted ||
          !_remoteControllerMode ||
          !_rippleTapEnabled ||
          _controller.state.elementById(elementId) == null) {
        return;
      }
      unawaited(_cycleRipple(elementId));
    });
  }

  Future<void> _clearAllRipples() async {
    _setRemoteControlState(_remoteControlState.clearRipples());
    await _sendRemoteControlCommand('clearRipples');
  }

  Future<void> _applyRemoteControlCommand(Map<String, Object?> payload) async {
    if (!_remoteDisplayMode) return;
    final command = payload['command'];
    var next = _remoteControlState;
    switch (command) {
      case 'setDisplayInteractions':
        next = next.copyWith(
          displayInteractionsEnabled: payload['enabled'] == true,
        );
      case 'setDisplayShapesVisible':
        next = next.copyWith(displayShapesVisible: payload['visible'] != false);
      case 'setRipple':
        final elementId = payload['elementId'];
        if (elementId is! String ||
            _controller.state.elementById(elementId) == null) {
          return;
        }
        final level = RemoteRippleLevel.fromWireValue(payload['level']);
        final ripples = Map<String, RemoteRippleLevel>.from(next.rippleLevels);
        if (level == null) {
          ripples.remove(elementId);
        } else {
          ripples[elementId] = level;
        }
        next = next.copyWith(rippleLevels: Map.unmodifiable(ripples));
      case 'clearRipples':
        next = next.clearRipples();
      default:
        return;
    }
    _setRemoteControlState(next);
    await _broadcastRemoteControlState();
  }

  void _applyRemoteControlState(Map<String, Object?> payload) {
    final raw = payload['control'];
    if (raw == null) return;
    _setRemoteControlState(RemoteBoardControlState.fromJson(raw));
  }

  Map<String, Object?> _remoteRuntimePayload() => {
    'origin': _remoteSession?.clientId,
    'activeToys': [for (final toy in _activeToys) toy.name],
    'toyClock': _toyClock,
    'effectOpacities': _effectOpacities,
    'burstCenter': _burstCenter == null ? null : _remotePoint(_burstCenter!),
    'burstProgress': _burstProgress,
    'ghostTrailActive': _ghostTrailActive,
    'ghostTrails': {
      for (final entry in _ghostTrails.entries)
        entry.key: [for (final point in entry.value) _remotePoint(point)],
    },
    'eventZoneCenter': _eventZoneCenter == null
        ? null
        : _remotePoint(_eventZoneCenter!),
    'eventZoneRadiusMm': _eventZoneRadiusMm,
    'eventZoneProgress': _eventZoneProgress,
    'eventZoneDismiss': _eventZoneDismiss,
    'turnTimerProgress': _turnTimerProgress,
    'radarAngleDegrees': _radarAngleDegrees,
    'redSweepY': _redSweepY,
    'projectiles': [
      for (final projectile in _projectiles)
        {
          'position': _remotePoint(projectile.position),
          'velocity': _remotePoint(projectile.velocity),
          'radiusMm': projectile.radiusMm,
          'ricochet': projectile.ricochet,
          'edgeHits': projectile.edgeHits,
          'escaping': projectile.escaping,
        },
    ],
    'impacts': [
      for (final impact in _impacts)
        {
          'position': _remotePoint(impact.position),
          'lifeSeconds': impact.lifeSeconds,
        },
    ],
    'sideGunAnglesDegrees': _sideGunAnglesDegrees,
    'sideGunAmmo': _sideGunAmmo,
    'constellationElementIds': _constellationElementIds,
    'checkerUnderlays': _checkerUnderlays,
    'roundedTriangleTips': _roundedTriangleTips,
    'dice': _diceSnapshot.toJson(),
    'zendo': _zendoSnapshot.toJson(),
  };

  void _startRemoteRuntimePublisher() {
    _remoteRuntimeTimer?.cancel();
    _remoteRuntimeTimer = null;
    _lastRemoteRuntimeJson = null;
    if (_remoteSession?.role != RemoteRole.controller) return;
    _remoteRuntimeTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => unawaited(_sendRemoteRuntimeIfChanged()),
    );
    unawaited(_sendRemoteRuntimeIfChanged(force: true));
  }

  Future<void> _sendRemoteRuntimeIfChanged({bool force = false}) async {
    final session = _remoteSession;
    if (session == null || session.role != RemoteRole.controller) return;
    if (!_remoteSeedReceived && !session.isCreator) return;
    final payload = _remoteRuntimePayload();
    final encoded = jsonEncode(payload);
    if (!force && encoded == _lastRemoteRuntimeJson) return;
    _lastRemoteRuntimeJson = encoded;
    await session.sendApp('runtimeProposal', payload);
  }

  void _handleDiceSnapshot(DiceBubbleSnapshot snapshot) {
    _diceSnapshot = snapshot;
    _scheduleSave();
    unawaited(_sendRemoteRuntimeIfChanged());
  }

  void _handleZendoSnapshot(ZendoStonesSnapshot snapshot) {
    _zendoSnapshot = snapshot;
    _scheduleSave();
    unawaited(_sendRemoteRuntimeIfChanged());
  }

  Future<void> _applyRemoteRuntime(Map<String, Object?> payload) async {
    if (_remoteSession == null || !mounted) return;
    final activeNames =
        (payload['activeToys'] as List?)?.whereType<String>() ??
        const Iterable<String>.empty();
    final active = <_ToyKind>{};
    for (final name in activeNames) {
      for (final toy in _ToyKind.values) {
        if (toy.name == name) active.add(toy);
      }
    }

    final opacities = <String, double>{};
    final rawOpacities = payload['effectOpacities'];
    if (rawOpacities is Map) {
      for (final entry in rawOpacities.entries) {
        if (entry.key is String && entry.value is num) {
          opacities[entry.key as String] = (entry.value as num).toDouble();
        }
      }
    }

    final trails = <String, List<PhysicalPoint>>{};
    final rawTrails = payload['ghostTrails'];
    if (rawTrails is Map) {
      for (final entry in rawTrails.entries) {
        if (entry.key is! String || entry.value is! List) continue;
        trails[entry.key as String] = [
          for (final rawPoint in entry.value as List)
            if (_pointFromRemote(rawPoint) case final point?) point,
        ];
      }
    }

    final projectiles = <ToyProjectile>[];
    final rawProjectiles = payload['projectiles'];
    if (rawProjectiles is List) {
      for (final raw in rawProjectiles) {
        if (raw is! Map) continue;
        final position = _pointFromRemote(raw['position']);
        final velocity = _pointFromRemote(raw['velocity']);
        final radius = raw['radiusMm'];
        if (position == null || velocity == null || radius is! num) continue;
        projectiles.add(
          ToyProjectile(
            position: position,
            velocity: velocity,
            radiusMm: radius.toDouble(),
            ricochet: raw['ricochet'] == true,
            edgeHits: (raw['edgeHits'] as num?)?.toInt() ?? 0,
            escaping: raw['escaping'] == true,
          ),
        );
      }
    }

    final impacts = <ToyImpact>[];
    final rawImpacts = payload['impacts'];
    if (rawImpacts is List) {
      for (final raw in rawImpacts) {
        if (raw is! Map) continue;
        final position = _pointFromRemote(raw['position']);
        final life = raw['lifeSeconds'];
        if (position == null || life is! num) continue;
        impacts.add(
          ToyImpact(position: position, lifeSeconds: life.toDouble()),
        );
      }
    }

    final angles = (payload['sideGunAnglesDegrees'] as List?)
        ?.whereType<num>()
        .map((value) => value.toDouble())
        .toList();
    final ammo = (payload['sideGunAmmo'] as List?)
        ?.whereType<num>()
        .map((value) => value.toInt())
        .toList();
    final constellation =
        (payload['constellationElementIds'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    final dice = DiceBubbleSnapshot.fromJson(payload['dice']);
    final zendo = ZendoStonesSnapshot.fromJson(payload['zendo']);

    _toyTicker?.cancel();
    _toyTicker = null;
    _lastToyTickAt = null;
    setState(() {
      _activeToys
        ..clear()
        ..addAll(active);
      _toyClock = (payload['toyClock'] as num?)?.toDouble() ?? _toyClock;
      _effectOpacities = opacities;
      _burstCenter = _pointFromRemote(payload['burstCenter']);
      _burstProgress = (payload['burstProgress'] as num?)?.toDouble();
      _ghostTrailActive = payload['ghostTrailActive'] == true;
      _ghostTrails
        ..clear()
        ..addAll(trails);
      _eventZoneCenter = _pointFromRemote(payload['eventZoneCenter']);
      _eventZoneRadiusMm = (payload['eventZoneRadiusMm'] as num?)?.toDouble();
      _eventZoneProgress = (payload['eventZoneProgress'] as num?)?.toDouble();
      _eventZoneDismiss =
          (payload['eventZoneDismiss'] as num?)?.toDouble() ?? 0;
      _turnTimerProgress = (payload['turnTimerProgress'] as num?)?.toDouble();
      _radarAngleDegrees =
          (payload['radarAngleDegrees'] as num?)?.toDouble() ?? 0;
      _redSweepY = (payload['redSweepY'] as num?)?.toDouble() ?? 0;
      _projectiles = projectiles;
      _impacts = impacts;
      if (angles != null && angles.length == _sideGunAnglesDegrees.length) {
        for (var i = 0; i < angles.length; i += 1) {
          _sideGunAnglesDegrees[i] = angles[i];
        }
      }
      if (ammo != null && ammo.length == _sideGunAmmo.length) {
        for (var i = 0; i < ammo.length; i += 1) {
          _sideGunAmmo[i] = ammo[i];
        }
      }
      _constellationElementIds = constellation;
      _checkerUnderlays = payload['checkerUnderlays'] == true;
      _roundedTriangleTips = payload['roundedTriangleTips'] == true;
      if (dice != null) _diceSnapshot = dice;
      if (zendo != null) _zendoSnapshot = zendo;
    });
    _toyRevision.value += 1;
  }

  Future<void> _startRemoteSession(
    RemoteSession session, {
    bool showPairingDialog = true,
    String? pairingCode,
  }) async {
    final old = _remoteSession;
    if (old != null && old != session) {
      await _remoteMessageSubscription?.cancel();
      _remoteMessageSubscription = null;
      await old.close();
    }
    if (!mounted) return;
    setState(() {
      _remoteSession = session;
      _remoteSeedReceived = session.role == RemoteRole.display;
      _remotePeerSeen = session.peerSeen;
      _remoteDisplayWidthMm = null;
      _remoteDisplayHeightMm = null;
      _remoteDisplayPixelsPerMm = null;
      _remoteControlState = const RemoteBoardControlState();
      _rippleTapEnabled = false;
    });
    _syncRippleTicker();
    session.addListener(_remoteSessionChanged);
    _remoteMessageSubscription = session.messages.listen(_handleRemoteMessage);
    await session.connect();
    if (!mounted) return;
    _startRemoteRuntimePublisher();
    await _sendRemoteHello();
    if (showPairingDialog && (session.isCreator || pairingCode != null)) {
      await _showPairingDialog(session, pairingCode: pairingCode);
    }
  }

  void _remoteSessionChanged() {
    if (!mounted) return;
    final session = _remoteSession;
    if (session == null) return;
    final peerJustAppeared = session.peerSeen && !_remotePeerSeen;
    _remotePeerSeen = session.peerSeen;
    setState(() {});
    if (peerJustAppeared) {
      unawaited(_resendRemoteHandshake(session));
    }
  }

  Future<void> _resendRemoteHandshake(RemoteSession session) async {
    if (!mounted || _remoteSession != session || !session.peerSeen) return;
    await _sendRemoteHello();
    if (!mounted || _remoteSession != session) return;
    if (session.role == RemoteRole.display) {
      await _sendRemoteState('seed');
      await session.sendApp('runtime', _remoteRuntimePayload());
      await _broadcastRemoteControlState();
    }
  }

  void _captureRemoteDisplayMetrics(
    Map<String, Object?> payload, {
    RemoteRole? senderRole,
  }) {
    if (!_remoteControllerMode) return;
    final payloadRoleName = payload['role'];
    final payloadRole = RemoteRole.values
        .where((value) => value.name == payloadRoleName)
        .firstOrNull;
    final effectiveRole = payloadRole ?? senderRole;
    if (effectiveRole != RemoteRole.display) return;
    final width = (payload['widthMm'] as num?)?.toDouble();
    final height = (payload['heightMm'] as num?)?.toDouble();
    final pixelsPerMm = (payload['pixelsPerMm'] as num?)?.toDouble();
    if (width == null || height == null || width <= 0 || height <= 0) {
      return;
    }
    if (_remoteDisplayWidthMm == width &&
        _remoteDisplayHeightMm == height &&
        _remoteDisplayPixelsPerMm == pixelsPerMm) {
      return;
    }
    setState(() {
      _remoteDisplayWidthMm = width;
      _remoteDisplayHeightMm = height;
      if (pixelsPerMm != null && pixelsPerMm > 0) {
        _remoteDisplayPixelsPerMm = pixelsPerMm;
      }
    });
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
      if (session.role == RemoteRole.display)
        'pixelsPerMm': widget.logicalPixelsPerMm,
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
        _captureRemoteDisplayMetrics(message.payload, senderRole: peerRole);
        if (session.role == RemoteRole.controller &&
            peerRole == RemoteRole.display) {
          await _sendRemoteHello();
        }
        if (session.role == RemoteRole.display &&
            peerRole == RemoteRole.controller) {
          await _sendRemoteState('seed');
          await session.sendApp('runtime', _remoteRuntimePayload());
          await _broadcastRemoteControlState();
        }

      case 'seed':
        if (session.role != RemoteRole.controller) return;
        _captureRemoteDisplayMetrics(
          message.payload,
          senderRole: RemoteRole.display,
        );
        await _applyRemoteState(message.payload);
        _applyRemoteControlState(message.payload);
        _remoteSeedReceived = true;
        _startRemoteRuntimePublisher();

      case 'proposal':
        if (session.role != RemoteRole.display) return;
        await _applyRemoteState(message.payload);
        await _sendRemoteState('state');

      case 'state':
        if (session.role != RemoteRole.controller) return;
        _captureRemoteDisplayMetrics(
          message.payload,
          senderRole: RemoteRole.display,
        );
        await _applyRemoteState(message.payload);
        _applyRemoteControlState(message.payload);
        _remoteSeedReceived = true;

      case 'runtimeProposal':
        if (session.role != RemoteRole.display) return;
        await _applyRemoteRuntime(message.payload);
        await session.sendApp('runtime', message.payload);

      case 'runtime':
        if (session.role != RemoteRole.controller) return;
        final origin = message.payload['origin'];
        if (origin != session.clientId) {
          await _applyRemoteRuntime(message.payload);
        }

      case 'controlCommand':
        if (session.role == RemoteRole.display) {
          await _applyRemoteControlCommand(message.payload);
        }

      case 'controlState':
        if (session.role == RemoteRole.controller) {
          _applyRemoteControlState(message.payload);
        }

      case 'role':
        if (session.multipleControllers) return;
        final peerRoleName = message.payload['role'];
        final peerRole = RemoteRole.values
            .where((value) => value.name == peerRoleName)
            .firstOrNull;
        if (peerRole == null) return;
        await session.setRole(peerRole.other, announce: false);
        setState(() {
          _remoteSeedReceived = session.role == RemoteRole.display;
          _remoteDisplayWidthMm = null;
          _remoteDisplayHeightMm = null;
          _remoteDisplayPixelsPerMm = null;
          _remoteControlState = const RemoteBoardControlState();
          _rippleTapEnabled = false;
        });
        _syncRippleTicker();
        _startRemoteRuntimePublisher();
        await _sendRemoteHello();
        if (session.role == RemoteRole.display) {
          await _sendRemoteState('seed');
          await session.sendApp('runtime', _remoteRuntimePayload());
          await _broadcastRemoteControlState();
        }

      case 'disconnect':
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                session.multipleControllers
                    ? 'A Remote controller disconnected.'
                    : 'Remote device disconnected.',
              ),
            ),
          );
        }
    }
  }

  Future<void> _applyRemoteState(Map<String, Object?> payload) async {
    final rawState = payload['state'];
    if (rawState is! Map) return;
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
    if (session == null || _applyingRemoteState) return;
    if (session.role == RemoteRole.controller && !_remoteSeedReceived) return;

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
    if (state == null || session == null) return;

    await _sendRemoteState(
      session.role == RemoteRole.display ? 'state' : 'proposal',
      state: state,
    );
  }

  Future<void> _sendRemoteState(String kind, {BoardState? state}) async {
    final session = _remoteSession;
    if (session == null) return;
    final board = _physicalBoardSize();
    await session.sendApp(kind, {
      'role': session.role.name,
      'origin': session.clientId,
      'state': (state ?? _controller.state).toJson(),
      'selectedId': _selectedId,
      if (session.role == RemoteRole.display) 'widthMm': board.width,
      if (session.role == RemoteRole.display) 'heightMm': board.height,
      if (session.role == RemoteRole.display)
        'pixelsPerMm': widget.logicalPixelsPerMm,
      if (session.role == RemoteRole.display)
        'control': _remoteControlState.toJson(),
    });
  }

  Future<void> _showPairingDialog(
    RemoteSession session, {
    String? pairingCode,
  }) async {
    if (!mounted || _remoteSession != session) return;
    final normalizedCode = pairingCode == null
        ? null
        : RemoteSession.normalizePairingCode(pairingCode);
    final join = session.joinUri(Uri.base).toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: session,
        builder: (context, _) => AlertDialog(
          title: Text(
            session.role == RemoteRole.display
                ? (session.peerSeen ? 'Add Controller' : 'Pair Controller')
                : 'Pair Table Display',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (normalizedCode != null) ...[
                  const Text(
                    'Enter this same code on the other device and choose the opposite role.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    normalizedCode,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 7,
                    ),
                  ),
                ] else ...[
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(data: join, size: 230),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 10),
                Text(
                  session.peerSeen
                      ? 'Paired · ${session.transportLabel}'
                      : session.phase == RemoteConnectionPhase.failed
                      ? 'Pairing service unavailable.'
                      : 'Waiting for the other device · ${session.transportLabel}',
                  textAlign: TextAlign.center,
                ),
                if (session.errorMessage case final error?) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (normalizedCode != null)
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: normalizedCode));
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Pairing code copied.')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Code'),
              )
            else
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

  Future<String?> _requestRemotePairingCode(RemoteRole role) async {
    final controller = TextEditingController();
    String? validationError;
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            final normalized = RemoteSession.normalizePairingCode(
              controller.text,
            );
            if (!RemoteSession.isValidPairingCode(normalized)) {
              setDialogState(() {
                validationError = 'Enter exactly 6 letters or digits.';
              });
              return;
            }
            Navigator.pop(dialogContext, normalized);
          }

          return AlertDialog(
            title: Text('${role.label} · Pair by Code'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: RemoteSession.pairingCodeLength,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(
                    RemoteSession.pairingCodeLength,
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Pairing code',
                  hintText: 'K7M4Q2',
                  errorText: validationError,
                  helperText: 'Type the same 6-character code on both devices.',
                ),
                onChanged: (_) {
                  if (validationError != null) {
                    setDialogState(() => validationError = null);
                  }
                },
                onSubmitted: (_) => submit(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: submit, child: const Text('Pair')),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return code;
  }

  Future<void> _startRemoteByCode(RemoteRole role) async {
    final code = await _requestRemotePairingCode(role);
    if (!mounted || code == null) return;
    final session = await RemoteSession.fromPairingCode(code, role);
    if (!mounted) {
      await session.close();
      return;
    }
    await _startRemoteSession(session, pairingCode: code);
  }

  Future<void> _showRemoteSetup(RemoteRole role) async {
    final method = await _showCompactMenu([
      _compactMenuItem(
        'code',
        Icons.pin_outlined,
        'Pair with 6-Character Code',
      ),
      _compactMenuItem('qr', Icons.qr_code_2, 'Pair with QR / Link'),
    ]);
    if (!mounted || method == null) return;
    switch (method) {
      case 'code':
        await _startRemoteByCode(role);
      case 'qr':
        final session = await RemoteSession.createShareable(role);
        if (!mounted) {
          await session.close();
          return;
        }
        await _startRemoteSession(session);
    }
  }

  Future<void> _disconnectRemote() async {
    final session = _remoteSession;
    if (session == null) return;
    session.removeListener(_remoteSessionChanged);
    await _remoteMessageSubscription?.cancel();
    _remoteMessageSubscription = null;
    _remotePublishTimer?.cancel();
    _remotePublishTimer = null;
    _remoteRuntimeTimer?.cancel();
    _remoteRuntimeTimer = null;
    _lastRemoteRuntimeJson = null;
    _remotePendingState = null;
    await session.close();
    if (!mounted) return;
    setState(() {
      _remoteSession = null;
      _remoteSeedReceived = false;
      _remotePeerSeen = false;
      _remoteDisplayWidthMm = null;
      _remoteDisplayHeightMm = null;
      _remoteDisplayPixelsPerMm = null;
      _remoteControlState = const RemoteBoardControlState();
      _rippleTapEnabled = false;
    });
    _syncRippleTicker();
  }

  Future<void> _swapRemoteRoles() async {
    final session = _remoteSession;
    if (session == null || session.multipleControllers) return;
    await session.setRole(session.role.other);
    setState(() {
      _remoteSeedReceived = session.role == RemoteRole.display;
      _remoteDisplayWidthMm = null;
      _remoteDisplayHeightMm = null;
      _remoteDisplayPixelsPerMm = null;
      _remoteControlState = const RemoteBoardControlState();
      _rippleTapEnabled = false;
    });
    _syncRippleTicker();
    _startRemoteRuntimePublisher();
    await _sendRemoteHello();
    if (session.role == RemoteRole.display) {
      await _sendRemoteState('seed');
      await session.sendApp('runtime', _remoteRuntimePayload());
      await _broadcastRemoteControlState();
    }
  }

  Future<void> _showAddControllerPairing(RemoteSession session) async {
    final code = session.pairingCode;
    if (code == null) {
      await _showPairingDialog(session);
      return;
    }
    final method = await _showCompactMenu([
      _compactMenuItem(
        'code',
        Icons.pin_outlined,
        '6-Character Code',
      ),
      _compactMenuItem('qr', Icons.qr_code_2, 'QR / Link'),
    ]);
    if (!mounted || method == null) return;
    if (method == 'code') {
      await _showPairingDialog(session, pairingCode: code);
    } else {
      await _showPairingDialog(session);
    }
  }

  Future<void> _showRemoteMenu() async {
    final session = _remoteSession;
    if (session == null) {
      final choice = await _showCompactMenu([
        _compactMenuItem(
          'display',
          Icons.desktop_windows_outlined,
          'This Device: Table Display',
        ),
        _compactMenuItem('controller', Icons.tune, 'This Device: Controller'),
      ]);
      if (!mounted || choice == null) return;
      final role = choice == 'display'
          ? RemoteRole.display
          : RemoteRole.controller;
      await _showRemoteSetup(role);
      return;
    }

    final items = <PopupMenuEntry<String>>[
      _compactMenuItem(
        'status',
        Icons.link,
        '${session.role.label} · ${session.transportLabel}',
        enabled: false,
      ),
      if (!session.peerSeen)
        _compactMenuItem(
          'code',
          Icons.pin_outlined,
          'Pair with 6-Character Code',
        ),
      if (session.role == RemoteRole.display || !session.peerSeen)
        _compactMenuItem(
          'pair',
          Icons.qr_code_2,
          session.role == RemoteRole.display && session.peerSeen
              ? 'Add Another Controller'
              : 'Show Pairing QR',
        ),
      if (session.role == RemoteRole.controller && session.peerSeen) ...[
        _compactMenuItem(
          'boardInteraction',
          Icons.touch_app_outlined,
          'Table Display Shape Interaction',
          checked: _remoteControlState.displayInteractionsEnabled,
        ),
        _compactMenuItem(
          'shapeVisibility',
          Icons.visibility_outlined,
          'Table Display Shapes Visible',
          checked: _remoteControlState.displayShapesVisible,
        ),
        _compactMenuItem(
          'rippleTap',
          Icons.radio_button_checked,
          'Tap Shapes to Cycle Ripples',
          checked: _rippleTapEnabled,
        ),
        _compactMenuItem(
          'clearRipples',
          Icons.waves_outlined,
          'Turn Off All Ripples',
          enabled: _remoteControlState.rippleLevels.isNotEmpty,
        ),
      ],
      _compactMenuItem(
        'swap',
        Icons.swap_horiz,
        'Swap Roles',
        enabled: !session.multipleControllers,
      ),
      _compactMenuItem('disconnect', Icons.link_off, 'Disconnect'),
    ];

    final choice = await _showCompactMenu(items);
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'code':
        await _disconnectRemote();
        if (!mounted) return;
        await _startRemoteByCode(session.role);
      case 'pair':
        if (session.role == RemoteRole.display && session.peerSeen) {
          await _showAddControllerPairing(session);
        } else {
          await _showPairingDialog(
            session,
            pairingCode: session.pairingCode,
          );
        }
      case 'boardInteraction':
        await _setBoardUnitInteractions(
          !_remoteControlState.displayInteractionsEnabled,
        );
      case 'shapeVisibility':
        await _setBoardUnitShapesVisible(
          !_remoteControlState.displayShapesVisible,
        );
      case 'rippleTap':
        setState(() => _rippleTapEnabled = !_rippleTapEnabled);
      case 'clearRipples':
        await _clearAllRipples();
      case 'swap':
        await _swapRemoteRoles();
      case 'disconnect':
        await _disconnectRemote();
    }
  }

  Widget _remoteStatusButton() {
    final session = _remoteSession;
    if (session == null) return const SizedBox.shrink();
    final status = IconButton(
      tooltip: '${session.role.label} · ${session.transportLabel}',
      onPressed: _showRemoteMenu,
      icon: Icon(
        session.peerSeen ? Icons.link : Icons.link_off,
        color: session.peerSeen ? Colors.white70 : Colors.orangeAccent,
      ),
    );
    if (session.role != RemoteRole.display) return status;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        status,
        IconButton(
          tooltip: 'Disconnect Table Display',
          visualDensity: VisualDensity.compact,
          onPressed: _disconnectRemote,
          icon: const Icon(Icons.link_off, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _remoteControllerQuickControls() {
    if (!_remoteControllerMode || _remoteSession?.peerSeen != true) {
      return const SizedBox.shrink();
    }
    return Material(
      color: const Color(0xAA171717),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Table Display shape interaction',
            visualDensity: VisualDensity.compact,
            onPressed: () => unawaited(
              _setBoardUnitInteractions(
                !_remoteControlState.displayInteractionsEnabled,
              ),
            ),
            icon: Icon(
              Icons.touch_app_outlined,
              color: _remoteControlState.displayInteractionsEnabled
                  ? Colors.white
                  : Colors.white54,
            ),
          ),
          IconButton(
            tooltip: 'Table Display shapes visible',
            visualDensity: VisualDensity.compact,
            onPressed: () => unawaited(
              _setBoardUnitShapesVisible(
                !_remoteControlState.displayShapesVisible,
              ),
            ),
            icon: Icon(
              _remoteControlState.displayShapesVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _remoteControlState.displayShapesVisible
                  ? Colors.white
                  : Colors.white54,
            ),
          ),
          IconButton(
            tooltip: 'Tap shapes to cycle ripples',
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                setState(() => _rippleTapEnabled = !_rippleTapEnabled),
            icon: Icon(
              Icons.radio_button_checked,
              color: _rippleTapEnabled ? Colors.white : Colors.white54,
            ),
          ),
          IconButton(
            tooltip: 'Turn off all ripples',
            visualDensity: VisualDensity.compact,
            onPressed: _remoteControlState.rippleLevels.isEmpty
                ? null
                : () => unawaited(_clearAllRipples()),
            icon: const Icon(Icons.waves_outlined),
          ),
        ],
      ),
    );
  }

  void _scheduleSave() {
    _pendingSaveState = _stateForPersistence();
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      _saveDebounceTimer = null;
      unawaited(_flushPendingSave());
    });
  }

  Future<void> _flushPendingSave() async {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;
    final state = _pendingSaveState;
    if (state == null) return;
    _pendingSaveState = null;
    try {
      await _store.save(state);
    } on Object {
      // Persistence must never block interaction. A later state change retries.
    }
  }

  void _refresh() {
    if (!mounted) return;
    _elementVerticalBounds.clear();
    if (_ghostTrailActive) {
      final liveIds = _controller.state.elements
          .map((element) => element.id)
          .toSet();
      _ghostTrails.removeWhere((id, _) => !liveIds.contains(id));
      for (final element in _controller.state.elements) {
        final trail = _ghostTrails.putIfAbsent(
          element.id,
          () => <PhysicalPoint>[],
        );
        if (trail.isEmpty || trail.last.distanceTo(element.position) >= 2.4) {
          trail.add(element.position);
          if (trail.length > 84) trail.removeAt(0);
        }
      }
    }
    final liveIds = _controller.state.elements.map((e) => e.id).toSet();
    _constellationElementIds = [
      for (final id in _constellationElementIds)
        if (liveIds.contains(id)) id,
    ];
    final retainedControls = _remoteControlState.retainElementIds(liveIds);
    final ripplesChanged = !identical(retainedControls, _remoteControlState);
    setState(() {
      if (_selectedId != null &&
          _controller.state.elementById(_selectedId!) == null) {
        _selectedId = null;
      }
      if (ripplesChanged) _remoteControlState = retainedControls;
    });
    if (ripplesChanged) {
      _syncRippleTicker();
      if (_remoteDisplayMode) unawaited(_broadcastRemoteControlState());
    }
    _scheduleSave();
    _scheduleRemotePublish();
  }

  PhysicalPoint _toPhysical(Offset point) =>
      PhysicalPoint(point.dx / _pixelsPerMm, point.dy / _pixelsPerMm);

  LightElement? get _selected =>
      _selectedId == null ? null : _controller.state.elementById(_selectedId!);

  bool _containsPoint(LightElement element, PhysicalPoint point) {
    final polygon = polygonForElement(element, _controller.geometry);
    double? sign;
    for (var i = 0; i < polygon.length; i += 1) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      final cross =
          (b.xMm - a.xMm) * (point.yMm - a.yMm) -
          (b.yMm - a.yMm) * (point.xMm - a.xMm);
      if (cross.abs() < 0.0001) continue;
      final currentSign = cross.sign;
      sign ??= currentSign;
      if (currentSign != sign) return false;
    }
    return true;
  }

  LightElement? _exactHit(PhysicalPoint point) {
    for (final element in _controller.state.elements.reversed) {
      if (_containsPoint(element, point)) return element;
    }
    return null;
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    if (_creditsVisible) return;
    _rippleTapTimer?.cancel();
    _rippleTapTimer = null;
    final point = _toPhysical(details.localPosition);
    final target = _controller.hitTest(point, haloMm: _interactionHaloMm);
    if (target == null) {
      _controller.createAt(point, mode: _zendoPieceMode);
    } else {
      _controller.cycleSizeOrDelete(target, mode: _zendoPieceMode);
    }
    HapticFeedback.selectionClick();
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_mouseTransform || _creditsVisible) return;
    final point = _toPhysical(details.localFocalPoint);
    _preciseTarget = _exactHit(point);
    _transformTarget = _controller.hitTest(point, haloMm: _interactionHaloMm);
    _oneFingerStart = point;
    _oneFingerLast = point;
    _oneFingerPath
      ..clear()
      ..add(point);
    _lastRotation = 0;
    _transformStarted = false;
    _transformTranslated = false;
    if (_transformTarget != null &&
        !(_remoteControllerMode && _rippleTapEnabled)) {
      setState(() => _selectedId = _transformTarget!.id);
    }

    if (details.pointerCount >= 2 && _transformTarget != null) {
      _controller.beginTransform(_transformTarget!);
      _transformStarted = true;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_mouseTransform || _creditsVisible) return;
    final current = _toPhysical(details.localFocalPoint);

    if (details.pointerCount >= 2) {
      _transformTarget ??= _controller.hitTest(
        current,
        haloMm: _interactionHaloMm,
      );
      final target = _transformTarget;
      if (target == null) return;
      if (!_transformStarted) {
        _controller.beginTransform(target);
        _transformStarted = true;
        _lastRotation = details.rotation;
        return;
      }
      final delta = PhysicalPoint(
        details.focalPointDelta.dx / _pixelsPerMm,
        details.focalPointDelta.dy / _pixelsPerMm,
      );
      final rotationDelta = details.rotation - _lastRotation;
      _lastRotation = details.rotation;
      if (delta.distanceTo(PhysicalPoint.zero) > 0.35) {
        _transformTranslated = true;
      }
      _queueTransform(delta, rotationDelta);
      return;
    }

    if (_transformStarted) return;
    _oneFingerLast = current;
    if (_oneFingerPath.isEmpty ||
        _oneFingerPath.last.distanceTo(current) >= 0.7) {
      _oneFingerPath.add(current);
    }
  }

  void _queueTransform(PhysicalPoint delta, double rotationDelta) {
    _pendingTransformDelta = _pendingTransformDelta + delta;
    _pendingTransformRotation += rotationDelta;
    if (_transformFrameScheduled) return;
    _transformFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _transformFrameScheduled = false;
      _flushQueuedTransform();
    });
  }

  void _flushQueuedTransform() {
    final delta = _pendingTransformDelta;
    final rotation = _pendingTransformRotation;
    _pendingTransformDelta = PhysicalPoint.zero;
    _pendingTransformRotation = 0;
    if (!_transformStarted ||
        (delta == PhysicalPoint.zero && rotation.abs() < 0.000001)) {
      return;
    }
    _controller.transformBy(delta, rotation);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_mouseTransform || _creditsVisible) return;
    if (_transformStarted) {
      _flushQueuedTransform();
      _endTransformWithSnaps();
      HapticFeedback.lightImpact();
      _clearGesture();
      return;
    }

    final start = _oneFingerStart;
    final end = _oneFingerLast;
    if (start == null || end == null) {
      _clearGesture();
      return;
    }

    final encircled = _recognizeEncirclement();
    if (encircled != null) {
      _controller.toggleIllumination(encircled);
      HapticFeedback.selectionClick();
      _clearGesture();
      return;
    }

    final drag = end - start;
    final displacement = start.distanceTo(end);
    final exact = _preciseTarget;

    if (exact != null &&
        exact.pose == PyramidPose.upright &&
        displacement >= _minimumLineGestureMm &&
        !_containsPoint(exact, end)) {
      // Tip: begin inside the actual square and cross its real edge. No halo.
      _controller.tipOrStand(exact, drag);
      HapticFeedback.mediumImpact();
      _clearGesture();
      return;
    }

    if (exact != null &&
        exact.pose == PyramidPose.flat &&
        displacement >= _minimumLineGestureMm &&
        _crossesFlatBaseEdge(exact, start, end)) {
      // Stand: begin inside the actual triangle and cross its short base
      // edge. This mirrors tipping: inside-to-outside, with no halo.
      _controller.tipOrStand(exact, drag);
      HapticFeedback.mediumImpact();
      _clearGesture();
      return;
    }

    if (displacement <= _tapTravelMm) {
      final tapped = _controller.hitTest(start, haloMm: _interactionHaloMm);
      if (_remoteControllerMode && _rippleTapEnabled) {
        if (tapped != null) _queueRippleTap(tapped.id);
      } else {
        setState(() => _selectedId = tapped?.id);
      }
    }
    _clearGesture();
  }

  double _flatFootprintLengthMm(LightElement element) {
    final base = _controller.geometry.baseMm(element.size);
    final height = _controller.geometry.flatLengthMm(element.size);
    return switch (element.kind) {
      LightPieceKind.pyramid || LightPieceKind.block => height,
      LightPieceKind.wedge =>
        element.wedgeFlatFace == WedgeFlatFace.rectangle
            ? math.sqrt(base * base + height * height)
            : height,
    };
  }

  bool _crossesFlatBaseEdge(
    LightElement element,
    PhysicalPoint start,
    PhysicalPoint end,
  ) {
    if (!_containsPoint(element, start) || _containsPoint(element, end)) {
      return false;
    }
    final localStart = rotateVector(
      start - element.position,
      -element.headingDegrees,
    );
    final localEnd = rotateVector(
      end - element.position,
      -element.headingDegrees,
    );
    final halfLength = _flatFootprintLengthMm(element) / 2;
    final halfBase = _controller.geometry.baseMm(element.size) / 2;
    final deltaY = localEnd.yMm - localStart.yMm;
    if (deltaY <= 0 || localEnd.yMm <= halfLength) return false;

    final crossing = (halfLength - localStart.yMm) / deltaY;
    if (crossing <= 0 || crossing >= 1) return false;
    final xAtBase = localStart.xMm + (localEnd.xMm - localStart.xMm) * crossing;
    return xAtBase.abs() <= halfBase;
  }

  LightElement? _recognizeEncirclement() {
    if (_oneFingerPath.length < 7) return null;

    LightElement? best;
    var bestScore = double.negativeInfinity;

    for (final element in _controller.state.elements.reversed) {
      if (element.pose != PyramidPose.upright) continue;
      final base = _controller.geometry.baseMm(element.size);
      var winding = 0.0;
      var pathLength = 0.0;
      var radiusTotal = 0.0;
      var minimumRadius = double.infinity;

      for (var i = 1; i < _oneFingerPath.length; i += 1) {
        final previous = _oneFingerPath[i - 1];
        final current = _oneFingerPath[i];
        pathLength += previous.distanceTo(current);

        final a = previous - element.position;
        final b = current - element.position;
        final radiusA = math.sqrt(a.xMm * a.xMm + a.yMm * a.yMm);
        final radiusB = math.sqrt(b.xMm * b.xMm + b.yMm * b.yMm);
        minimumRadius = math.min(minimumRadius, math.min(radiusA, radiusB));
        radiusTotal += radiusB;

        if (radiusA < 0.5 || radiusB < 0.5) continue;
        final angleA = math.atan2(a.yMm, a.xMm);
        final angleB = math.atan2(b.yMm, b.xMm);
        winding += normalizeRadians(angleB - angleA);
      }

      final closure = _oneFingerPath.first.distanceTo(_oneFingerPath.last);
      final averageRadius = radiusTotal / (_oneFingerPath.length - 1);
      final enoughTurn = winding.abs() >= math.pi * 1.55;
      final enoughPath = pathLength >= base * 2.4;
      final reasonablyClosed = closure <= math.max(14, base * 1.2);
      final staysAroundCenter = minimumRadius >= base * 0.28;
      final notRemote = averageRadius <= base * 1.8 + 18;

      if (!enoughTurn ||
          !enoughPath ||
          !reasonablyClosed ||
          !staysAroundCenter ||
          !notRemote) {
        continue;
      }

      // Winding angle is the important signal. Radius only breaks ties when a
      // loop happens to surround more than one footprint.
      final score = winding.abs() * 10 - averageRadius;
      if (score > bestScore) {
        best = element;
        bestScore = score;
      }
    }
    return best;
  }

  void _onPointerDown(PointerDownEvent event) {
    // Safari will not expose motion data until permission is requested from a
    // real user gesture. Piggyback that handshake on the first ordinary board
    // touch so the face-down behavior stays undisclosed in the interface.
    if (kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !_motionPermissionAttempted) {
      unawaited(_ensureMotionPermission());
    }

    if (_creditsVisible ||
        event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final point = _toPhysical(event.localPosition);
    _mouseTransform = true;
    _mouseLast = point;
    _preciseTarget = _exactHit(point);
    _transformTarget = _controller.hitTest(point, haloMm: _interactionHaloMm);
    _oneFingerStart = point;
    _oneFingerLast = point;
    _oneFingerPath
      ..clear()
      ..add(point);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_mouseTransform || event.kind != PointerDeviceKind.mouse) return;
    final current = _toPhysical(event.localPosition);
    final last = _mouseLast;
    if (last == null) return;
    _mouseLast = current;
    _oneFingerLast = current;
    if (_oneFingerPath.isEmpty ||
        _oneFingerPath.last.distanceTo(current) >= 0.7) {
      _oneFingerPath.add(current);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_mouseTransform || event.kind != PointerDeviceKind.mouse) return;
    final start = _oneFingerStart;
    final end = _oneFingerLast;
    final exact = _preciseTarget;

    if (start != null && end != null) {
      final encircled = _recognizeEncirclement();
      if (encircled != null) {
        _controller.toggleIllumination(encircled);
      } else {
        final drag = end - start;
        final displacement = start.distanceTo(end);
        if (exact != null &&
            exact.pose == PyramidPose.upright &&
            displacement >= _minimumLineGestureMm &&
            !_containsPoint(exact, end)) {
          _controller.tipOrStand(exact, drag);
        } else if (exact != null &&
            exact.pose == PyramidPose.flat &&
            displacement >= _minimumLineGestureMm &&
            _crossesFlatBaseEdge(exact, start, end)) {
          _controller.tipOrStand(exact, drag);
        } else if (displacement <= _tapTravelMm) {
          final tapped = _controller.hitTest(start, haloMm: _interactionHaloMm);
          if (_remoteControllerMode && _rippleTapEnabled) {
            if (tapped != null) _queueRippleTap(tapped.id);
          } else {
            setState(() => _selectedId = tapped?.id);
          }
        }
      }
    }

    _mouseTransform = false;
    _mouseLast = null;
    _clearGesture();
  }

  void _onPointerPanZoomStart(PointerPanZoomStartEvent event) {
    if (!kIsWeb || _creditsVisible) return;
    final point = _toPhysical(event.localPosition);
    final target =
        _controller.hitTest(point, haloMm: _interactionHaloMm) ?? _selected;
    if (target == null) return;
    _finishDesktopScrollTransform();
    _trackpadTransform = true;
    _trackpadLastRotation = 0;
    _transformTarget = target;
    setState(() => _selectedId = target.id);
    _controller.beginTransform(target);
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_trackpadTransform || !kIsWeb) return;
    final delta = PhysicalPoint(
      event.panDelta.dx / _pixelsPerMm,
      event.panDelta.dy / _pixelsPerMm,
    );
    final rotationDelta = event.rotation - _trackpadLastRotation;
    _trackpadLastRotation = event.rotation;
    if (delta.distanceTo(PhysicalPoint.zero) > 0.35) {
      _transformTranslated = true;
    }
    _controller.transformBy(delta, rotationDelta);
  }

  void _onPointerPanZoomEnd(PointerPanZoomEndEvent event) {
    if (!_trackpadTransform || !kIsWeb) return;
    _endTransformWithSnaps();
    _trackpadTransform = false;
    _trackpadLastRotation = 0;
    _transformTarget = null;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!kIsWeb ||
        _creditsVisible ||
        _trackpadTransform ||
        event is! PointerScrollEvent) {
      return;
    }
    final point = _toPhysical(event.localPosition);
    final target =
        _controller.hitTest(point, haloMm: _interactionHaloMm) ?? _selected;
    if (target == null) return;

    if (!_desktopScrollTransform || _desktopScrollTarget?.id != target.id) {
      _finishDesktopScrollTransform();
      _desktopScrollTransform = true;
      _desktopScrollTarget = target;
      setState(() => _selectedId = target.id);
      _controller.beginTransform(target);
    }

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final rotate =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    if (rotate) {
      final scroll = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
          ? event.scrollDelta.dy
          : event.scrollDelta.dx;
      _controller.transformBy(const PhysicalPoint(0, 0), -scroll * 0.008);
    } else {
      final delta = PhysicalPoint(
        -event.scrollDelta.dx / _pixelsPerMm,
        -event.scrollDelta.dy / _pixelsPerMm,
      );
      if (delta.distanceTo(PhysicalPoint.zero) > 0.35) {
        _transformTranslated = true;
      }
      _controller.transformBy(delta, 0);
    }
    _desktopScrollEndTimer?.cancel();
    _desktopScrollEndTimer = Timer(
      const Duration(milliseconds: 180),
      _finishDesktopScrollTransform,
    );
  }

  void _rotateSelected(double degrees) {
    final target = _selected;
    if (target == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tap a footprint first.')));
      return;
    }
    _finishDesktopScrollTransform();
    _controller.beginTransform(target);
    _controller.transformBy(PhysicalPoint.zero, degrees * math.pi / 180);
    _controller.endTransform(snapDegrees: _rotationSnapDegrees);
  }

  void _finishDesktopScrollTransform() {
    _desktopScrollEndTimer?.cancel();
    _desktopScrollEndTimer = null;
    if (!_desktopScrollTransform) return;
    _endTransformWithSnaps();
    _desktopScrollTransform = false;
    _desktopScrollTarget = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _controller.cancelTransform();
    _mouseTransform = false;
    _mouseLast = null;
    _clearGesture();
  }

  void _clearGesture() {
    _transformTarget = null;
    _preciseTarget = null;
    _oneFingerStart = null;
    _oneFingerLast = null;
    _oneFingerPath.clear();
    _lastRotation = 0;
    _transformStarted = false;
    _transformTranslated = false;
    _pendingTransformDelta = PhysicalPoint.zero;
    _pendingTransformRotation = 0;
  }

  Future<String?> _askForTitle(String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Table name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          selectAllOnFocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _restoreAutosaveBackup(BoardState backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore previous autosave?'),
        content: const Text(
          'Replace the current table with the previous autosaved snapshot? '
          'You can use Undo immediately afterward to return to the current table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _controller.restoreState(backup);
    setState(() {
      _restoreTableData(backup.tableData);
      _activeSavedId = null;
    });
    if (_needsToyTicker && !_remoteDisplayMode) _ensureToyTicker();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Previous autosave restored. Undo can reverse it.'),
      ),
    );
  }

  String _defaultTableTitle([DateTime? timestamp]) {
    final now = timestamp ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Table ${two(now.hour)}:${two(now.minute)} '
        '${two(now.month)}/${two(now.day)}/${now.year}';
  }

  bool _isUntitledTableName(String value) {
    final title = value.trim();
    return title.isEmpty || title == 'Untitled Board' || title == 'Untitled Table';
  }

  Future<void> _saveBoard({bool asCopy = false}) async {
    final currentTitle = _controller.state.title;
    final title = await _askForTitle(
      _isUntitledTableName(currentTitle)
          ? _defaultTableTitle()
          : currentTitle,
    );
    if (title == null || title.trim().isEmpty) return;
    _controller.renameBoard(title);
    final id = await _store.saveNamed(
      _stateForPersistence(),
      id: asCopy ? null : _activeSavedId,
    );
    if (!mounted) return;
    setState(() => _activeSavedId = id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(asCopy ? 'Saved a copy.' : 'Table saved.')),
    );
  }

  Future<void> _manageSavedBoards() async {
    final summaries = await _store.listSavedBoards();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: math.min(MediaQuery.sizeOf(context).height * 0.7, 520),
            child: summaries.isEmpty
                ? const Center(child: Text('No saved tables yet.'))
                : ListView.builder(
                    itemCount: summaries.length,
                    itemBuilder: (context, index) {
                      final item = summaries[index];
                      return ListTile(
                        title: Text(item.title),
                        subtitle: Text(item.updatedAt.toLocal().toString()),
                        onTap: () async {
                          final board = await _store.loadNamed(item.id);
                          if (board == null || !mounted) return;
                          _controller.replaceState(board);
                          setState(() {
                            _restoreTableData(board.tableData);
                            _activeSavedId = item.id;
                          });
                          if (_needsToyTicker && !_remoteDisplayMode) {
                            _ensureToyTicker();
                          }
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        trailing: IconButton(
                          tooltip: 'Delete saved table',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await _store.deleteNamed(item.id);
                            summaries.removeAt(index);
                            setSheetState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportTableFile() async {
    final raw = _store.exportJson(_stateForPersistence());
    final cleaned = _controller.state.title
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final name = cleaned.isEmpty ? 'lighthouse-table' : cleaned;
    final saved = await FileSaver.instance.saveAs(
      name: name,
      bytes: Uint8List.fromList(utf8.encode(raw)),
      fileExtension: 'json',
      mimeType: MimeType.json,
    );
    if (!mounted || saved == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Table JSON saved.')));
  }

  Future<void> _importTableFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return;
    try {
      final raw = utf8.decode(await file.readAsBytes());
      final table = _store.importJson(raw);
      if (!mounted) return;
      if (table == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That file is not a LightHouse table.')),
        );
        return;
      }
      _controller.replaceState(table);
      setState(() {
        _restoreTableData(table.tableData);
        _activeSavedId = null;
      });
      if (_needsToyTicker && !_remoteDisplayMode) _ensureToyTicker();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that table file.')),
      );
    }
  }

  Future<void> _renameBoard() async {
    final title = await _askForTitle(_controller.state.title);
    if (title == null) return;
    _controller.renameBoard(title);
  }

  void _setHeading(double angle) {
    final selected = _selected;
    if (selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tap a footprint first.')));
      return;
    }
    _controller.setHeading(selected, angle);
  }

  void _selectUnderlay(BoardUnderlay underlay) {
    _controller.setUnderlay(underlay);
  }

  Future<void> _openAndroidDisplaySettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _displayChannel.invokeMethod<bool>('openDisplaySettings');
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Android display settings.'),
        ),
      );
    }
  }

  Future<void> _showOrientationLockInfo() async {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Orientation lock'),
        content: Text(
          isAndroid
              ? 'LightHouse locks the table to one orientation while it is open. Android can open the system Display settings directly.'
              : isIos
              ? 'LightHouse locks the table while it is open. iOS does not provide a supported app link to Rotation Lock; change it in Control Center.'
              : 'Orientation locking depends on browser and platform support.',
        ),
        actions: [
          if (isAndroid)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openAndroidDisplaySettings();
              },
              child: const Text('Display settings'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBrightnessDialog() async {
    if (kIsWeb) {
      await showDialog<void>(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('Brightness'),
          content: Text(
            'Browsers cannot control screen brightness. Use the device brightness control.',
          ),
        ),
      );
      return;
    }

    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    var value = _brightness;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Table brightness'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0.25,
                max: 1,
                value: value,
                onChanged: (next) {
                  value = next;
                  setDialogState(() {});
                  setState(() => _brightness = next);
                  _applyBrightness();
                },
              ),
              if (defaultTargetPlatform == TargetPlatform.iOS)
                const Text(
                  'iOS does not expose a supported deep link to its Brightness panel; use Control Center for the system setting.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ScreenBrightness.instance
                    .resetApplicationScreenBrightness();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Use system'),
            ),
            if (isAndroid)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openAndroidDisplaySettings();
                },
                child: const Text('Display settings'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCalibrationCheck() async {
    final pixelsPerMm = _pixelsPerMm;
    final largeBase = _controller.geometry.baseMm(PyramidSize.large);
    final recalibrate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This bar should measure exactly 25 mm:'),
            const SizedBox(height: 12),
            Container(width: 25 * pixelsPerMm, height: 6, color: Colors.white),
            const SizedBox(height: 24),
            const Text('A Large upright pyramid should fit this square:'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: largeBase * pixelsPerMm,
                height: largeBase * pixelsPerMm,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.calibrationLabel),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recalibrate'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Looks right'),
          ),
        ],
      ),
    );
    if (recalibrate == true) widget.onRecalibrate(_controller.state);
  }

  Future<void> _showWebInstallHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Full-screen'),
        content: Text(
          'On iPhone or iPad, open this site in Safari, tap Share, then Add to Home Screen. On desktop browsers, use the browser install-app command when offered.',
        ),
      ),
    );
  }

  void _newBoard() {
    _controller.newBoard();
    setState(() {
      _activeSavedId = null;
      _selectedId = null;
    });
  }

  Widget _menu() => IconButton(
    tooltip: 'Menu',
    onPressed: _showMainMenu,
    icon: SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(
        painter: _MenuCirclePainter(snapDegrees: _rotationSnapDegrees),
      ),
    ),
  );

  PopupMenuItem<String> _compactMenuItem(
    String value,
    IconData icon,
    String label, {
    bool enabled = true,
    bool checked = false,
    Widget? leading,
  }) => PopupMenuItem<String>(
    value: value,
    enabled: enabled,
    height: 40,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (checked)
          const Icon(Icons.check, size: 19)
        else
          leading ?? Icon(icon, size: 19),
        const SizedBox(width: 10),
        Text(label),
      ],
    ),
  );

  Future<String?> _showCompactMenu(List<PopupMenuEntry<String>> items) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(sheetContext),
              child: const SizedBox.expand(),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 50),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Material(
                    color: const Color(0xFF202020),
                    elevation: 10,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: IntrinsicWidth(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.max(
                            120.0,
                            MediaQuery.sizeOf(sheetContext).height - 80,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: items,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _showMainMenu() async {
    await _ensureMotionPermission();
    if (!mounted) return;
    final choice = await _showCompactMenu([
      _compactMenuItem('file', Icons.folder_outlined, 'File'),
      _compactMenuItem('edit', Icons.edit_outlined, 'Edit'),
      _compactMenuItem('boards', Icons.grid_on, 'Boards'),
      _compactMenuItem('toys', Icons.toys_outlined, 'Toys'),
      _compactMenuItem('zendo', Icons.change_history_outlined, 'ZENDO'),
      _compactMenuItem('display', Icons.display_settings, 'Display'),
      _compactMenuItem('remote', Icons.devices_outlined, 'Remote'),
      _compactMenuItem('instructions', Icons.help_outline, 'Instructions'),
    ]);
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'file':
        await _showFileMenu();
      case 'edit':
        await _showEditMenu();
      case 'boards':
        await _showBoardsMenu();
      case 'toys':
        await _showToyMenu();
      case 'zendo':
        await _showZendoMenu();
      case 'display':
        await _showDisplayMenu();
      case 'remote':
        await _showRemoteMenu();
      case 'instructions':
        setState(() => _instructionsVisible = true);
    }
  }

  Future<void> _showZendoMenu() async {
    while (mounted) {
      final ruleActive = _zendoRuleIndex >= 0;
      final choice = await _showCompactMenu([
        _compactMenuItem(
          'zendoOff',
          Icons.power_settings_new,
          'Zendo Off · Normal LightHouse',
        ),
        const PopupMenuDivider(),
        _compactMenuItem(
          'stones',
          Icons.circle_outlined,
          'Zendo Stones',
          checked: _activeToys.contains(_ToyKind.zendoStones),
        ),
        const PopupMenuDivider(),
        _compactMenuItem(
          'classic',
          Icons.change_history_outlined,
          'Classic',
          checked: _zendoPieceMode == PieceCycleMode.classic,
        ),
        _compactMenuItem(
          'zendo20',
          Icons.category_outlined,
          'Zendo 2.0',
          checked: _zendoPieceMode == PieceCycleMode.zendo20,
        ),
        _compactMenuItem(
          'both',
          Icons.view_comfy_alt_outlined,
          'Classic + Zendo 2.0',
          checked: _zendoPieceMode == PieceCycleMode.both,
        ),
        const PopupMenuDivider(),
        _compactMenuItem(
          'newRule',
          Icons.shuffle,
          ruleActive ? 'Different Zendo Rule' : 'Zendo Rule',
        ),
        _compactMenuItem(
          'difficulty',
          Icons.tune,
          'Difficulty: ${_zendoRuleDifficulty.label}',
        ),
        _compactMenuItem(
          'complex',
          Icons.psychology_alt_outlined,
          'Complex Rules',
          checked: _zendoComplexRules,
        ),
        if (ruleActive)
          _compactMenuItem(
            'ruleVisibility',
            _zendoRuleVisible ? Icons.visibility_off : Icons.visibility,
            _zendoRuleVisible ? 'Hide Active Rule' : 'Show Active Rule',
          ),
      ]);
      if (!mounted || choice == null) return;
      switch (choice) {
        case 'zendoOff':
          _turnOffZendo();
          _scheduleSave();
          return;
        case 'stones':
          _toggleOverlayToy(_ToyKind.zendoStones);
          unawaited(_sendRemoteRuntimeIfChanged(force: true));
        case 'classic':
          setState(() => _zendoPieceMode = PieceCycleMode.classic);
        case 'zendo20':
          setState(() => _zendoPieceMode = PieceCycleMode.zendo20);
          _ensureRuleStillCompatible();
        case 'both':
          setState(() => _zendoPieceMode = PieceCycleMode.both);
        case 'newRule':
          _chooseNextZendoRule();
        case 'difficulty':
          await _showZendoDifficultyMenu();
        case 'complex':
          setState(() {
            _zendoComplexRules = !_zendoComplexRules;
            if (!_zendoComplexRules) {
              _zendoRuleDifficulty = ZendoRuleDifficulty.easy;
            }
          });
          _ensureRuleStillCompatible();
        case 'ruleVisibility':
          setState(() => _zendoRuleVisible = !_zendoRuleVisible);
      }
      _scheduleSave();
    }
  }

  void _turnOffZendo() {
    final stonesWereActive = _activeToys.remove(_ToyKind.zendoStones);
    setState(() {
      _zendoPieceMode = PieceCycleMode.classic;
      _zendoRuleIndex = -1;
      _zendoRuleVisible = false;
      _zendoComplexRules = false;
      _zendoRuleDifficulty = ZendoRuleDifficulty.easy;
    });
    if (stonesWereActive) {
      unawaited(_sendRemoteRuntimeIfChanged(force: true));
    }
  }

  Future<void> _showZendoDifficultyMenu() async {
    final available = _zendoComplexRules
        ? ZendoRuleDifficulty.values
        : const [ZendoRuleDifficulty.easy];
    final choice = await _showCompactMenu([
      for (final difficulty in available)
        _compactMenuItem(
          difficulty.name,
          Icons.radio_button_unchecked,
          difficulty.label,
          checked: _zendoRuleDifficulty == difficulty,
        ),
    ]);
    if (!mounted || choice == null) return;
    final difficulty = ZendoRuleDifficulty.values
        .where((value) => value.name == choice)
        .firstOrNull;
    if (difficulty == null) return;
    setState(() => _zendoRuleDifficulty = difficulty);
    _chooseNextZendoRule();
  }

  bool _ruleCompatible(ZendoRule rule) {
    if (rule.difficulty != _zendoRuleDifficulty) return false;
    if (!_zendoComplexRules && rule.difficulty != ZendoRuleDifficulty.easy) {
      return false;
    }
    if (_zendoPieceMode == PieceCycleMode.zendo20 && !rule.suitableForZendo20) {
      return false;
    }
    return true;
  }

  void _ensureRuleStillCompatible() {
    final index = _zendoRuleIndex;
    if (index < 0 || index >= zendoRules.length) return;
    if (_ruleCompatible(zendoRules[index])) return;
    _chooseNextZendoRule();
  }

  void _chooseNextZendoRule() {
    final compatible = <int>[
      for (var i = 0; i < zendoRules.length; i += 1)
        if (_ruleCompatible(zendoRules[i])) i,
    ];
    if (compatible.isEmpty) return;
    final withoutCurrent = compatible
        .where((index) => index != _zendoRuleIndex)
        .toList(growable: false);
    final pool = withoutCurrent.isEmpty ? compatible : withoutCurrent;
    final next = pool[_random.nextInt(pool.length)];
    setState(() {
      _zendoRuleIndex = next;
      _zendoRuleVisible = true;
    });
  }

  Widget _zendoRuleCard() {
    if (!_zendoRuleVisible ||
        _zendoRuleIndex < 0 ||
        _zendoRuleIndex >= zendoRules.length ||
        _remoteDisplayMode) {
      return const SizedBox.shrink();
    }
    final rule = zendoRules[_zendoRuleIndex];
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(70, 8, 70, 62),
          child: Material(
            color: const Color(0xED171717),
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 4, 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ZENDO RULE · ${rule.difficulty.label.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rule.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rule.source,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Different rule',
                      visualDensity: VisualDensity.compact,
                      onPressed: _chooseNextZendoRule,
                      icon: const Icon(Icons.shuffle, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Hide rule',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setState(() => _zendoRuleVisible = false),
                      icon: const Icon(Icons.visibility_off, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFileMenu() async {
    await _flushPendingSave();
    final backup = await _store.loadBackup();
    if (!mounted) return;
    final choice = await _showCompactMenu([
      _compactMenuItem('new', Icons.note_add_outlined, 'New'),
      _compactMenuItem('open', Icons.folder_open, 'Open…'),
      _compactMenuItem(
        'restore',
        Icons.history,
        'Restore Previous Autosave…',
        enabled: backup != null,
      ),
      _compactMenuItem('save', Icons.save_outlined, 'Save'),
      _compactMenuItem('copy', Icons.copy, 'Save a Copy…'),
      _compactMenuItem('rename', Icons.drive_file_rename_outline, 'Rename…'),
      _compactMenuItem(
        'import',
        Icons.file_open_outlined,
        'Import Table JSON…',
      ),
      _compactMenuItem('export', Icons.download_outlined, 'Export Table JSON…'),
    ]);
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'new':
        _newBoard();
      case 'open':
        await _manageSavedBoards();
      case 'restore':
        if (backup != null) await _restoreAutosaveBackup(backup);
      case 'save':
        await _saveBoard();
      case 'copy':
        await _saveBoard(asCopy: true);
      case 'rename':
        await _renameBoard();
      case 'import':
        await _importTableFile();
      case 'export':
        await _exportTableFile();
    }
  }

  Future<void> _showEditMenu() async {
    final choice = await _showCompactMenu([
      _compactMenuItem(
        'undo',
        Icons.undo,
        'Undo',
        enabled: _controller.canUndo,
      ),
      _compactMenuItem(
        'redo',
        Icons.redo,
        'Redo',
        enabled: _controller.canRedo,
      ),
      _compactMenuItem('left', Icons.rotate_left, 'Rotate Left 15°'),
      _compactMenuItem('right', Icons.rotate_right, 'Rotate Right 15°'),
      _compactMenuItem(
        'orientation',
        Icons.explore_outlined,
        'Set Orientation',
      ),
      _compactMenuItem('snap', Icons.rotate_90_degrees_ccw, 'Rotation Snap'),
    ]);
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'undo':
        _undoFromUi();
      case 'redo':
        _redoFromUi();
      case 'left':
        _rotateSelected(-15);
      case 'right':
        _rotateSelected(15);
      case 'orientation':
        await _showOrientationMenu();
      case 'snap':
        await _showRotationSnapMenu();
    }
  }

  PopupMenuItem<String> _angleMenuItem(double angle) => PopupMenuItem<String>(
    value: 'a${angle.toInt()}',
    height: 40,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Transform.rotate(
            angle: angle * math.pi / 180,
            child: const Icon(Icons.navigation, size: 19),
          ),
        ),
        const SizedBox(width: 10),
        Text('${angle.toInt()}°'),
      ],
    ),
  );

  Future<void> _showOrientationMenu() async {
    const angles = <double>[0, 45, 90, 135, 180, 225, 270, 315];
    final choice = await _showCompactMenu([
      for (final angle in angles) _angleMenuItem(angle),
    ]);
    if (choice == null) return;
    _setHeading(double.parse(choice.substring(1)));
  }

  Future<void> _showRotationSnapMenu() async {
    const options = <double>[15, 30, 45, 90];
    final choice = await _showCompactMenu([
      _compactMenuItem(
        'off',
        Icons.radio_button_unchecked,
        'Off',
        checked: _rotationSnapDegrees == null,
      ),
      for (final degrees in options)
        _compactMenuItem(
          's${degrees.toInt()}',
          Icons.radio_button_unchecked,
          '${degrees.toInt()}° increments',
          checked: _rotationSnapDegrees == degrees,
        ),
    ]);
    if (choice == null) return;
    if (choice == 'off') {
      await _setRotationSnap(null);
    } else {
      await _setRotationSnap(double.parse(choice.substring(1)));
    }
  }

  void _toggleUnderlaySelection(BoardUnderlay underlay) {
    _selectUnderlay(
      _controller.state.underlay == underlay ? BoardUnderlay.none : underlay,
    );
  }

  Future<void> _showBoardsMenu() async {
    final choice = await _showCompactMenu([
      _compactMenuItem(
        'games',
        Icons.dashboard_customize_outlined,
        'Game Boards',
      ),
      _compactMenuItem('grids', Icons.grid_4x4, 'Grids'),
      _compactMenuItem('chess', Icons.grid_view, 'Martian Chess'),
      const PopupMenuDivider(),
      _compactMenuItem(
        'snap',
        Icons.center_focus_strong,
        'Snap pieces to board',
        checked: _gridSnapEnabled,
      ),
      _compactMenuItem(
        'none',
        Icons.layers_clear_outlined,
        'None',
        checked: _controller.state.underlay == BoardUnderlay.none,
      ),
      _compactMenuItem(
        'checker',
        Icons.grid_on,
        'Checker Shading',
        checked: _checkerUnderlays,
      ),
    ]);
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'games':
        await _showBoardGroup(BoardUnderlayGroup.games);
      case 'grids':
        await _showBoardGroup(BoardUnderlayGroup.grids);
      case 'chess':
        await _showBoardGroup(BoardUnderlayGroup.chess);
      case 'checker':
        await _toggleCheckerUnderlays();
      case 'snap':
        await _toggleGridSnap();
      case 'none':
        _selectUnderlay(BoardUnderlay.none);
    }
  }

  PyramidLoveBoardIconKind? _boardMenuArtwork(BoardUnderlay underlay) =>
      switch (underlay) {
        BoardUnderlay.wheel => PyramidLoveBoardIconKind.wheel,
        BoardUnderlay.launchpad23 => PyramidLoveBoardIconKind.launchpad,
        BoardUnderlay.twinWin => PyramidLoveBoardIconKind.twinWin,
        BoardUnderlay.looneyLudo1 ||
        BoardUnderlay.looneyLudo4 => PyramidLoveBoardIconKind.ludo,
        BoardUnderlay.volcano => PyramidLoveBoardIconKind.volcano,
        BoardUnderlay.lunarInvaders1 ||
        BoardUnderlay.lunarInvaders2 => PyramidLoveBoardIconKind.lunar,
        BoardUnderlay.petalBattle => PyramidLoveBoardIconKind.petal,
        BoardUnderlay.worldWar5 => PyramidLoveBoardIconKind.worldWar,
        BoardUnderlay.martianChessHalf ||
        BoardUnderlay.martianChess2 ||
        BoardUnderlay.chess8x8 => PyramidLoveBoardIconKind.martianChess,
        _ => null,
      };

  Future<void> _showBoardGroup(BoardUnderlayGroup group) async {
    final boards = BoardUnderlay.values
        .where((underlay) => underlay.group == group)
        .toList();
    final choice = await _showCompactMenu([
      for (final underlay in boards)
        _compactMenuItem(
          'u${underlay.index}',
          group == BoardUnderlayGroup.chess
              ? Icons.grid_view
              : group == BoardUnderlayGroup.grids
              ? Icons.grid_4x4
              : Icons.dashboard_outlined,
          underlay.menuLabel,
          checked: _controller.state.underlay == underlay,
          leading: _boardMenuArtwork(underlay) == null
              ? null
              : PyramidLoveBoardIcon(_boardMenuArtwork(underlay)!),
        ),
    ]);
    if (!mounted || choice == null) return;
    final underlay = BoardUnderlay.values[int.parse(choice.substring(1))];
    _toggleUnderlaySelection(underlay);
  }

  Widget _toyIcon(_ToyKind toy, Color color, {required bool inMenu}) {
    final artwork = switch (toy) {
      _ToyKind.nestCycle => PyramidLoveToyIconKind.nest,
      _ToyKind.zendoStones => PyramidLoveToyIconKind.zendoMarkers,
      _ToyKind.triangleBounce => PyramidLoveToyIconKind.eastQueen,
      _ => null,
    };
    if (artwork != null) {
      final size = switch ((toy, inMenu)) {
        (_ToyKind.nestCycle, true) => 27.0,
        (_ToyKind.nestCycle, false) => 36.0,
        (_ToyKind.zendoStones, true) || (_ToyKind.triangleBounce, true) => 13.0,
        (_ToyKind.zendoStones, false) ||
        (_ToyKind.triangleBounce, false) => 21.0,
        _ => 21.0,
      };
      final icon = PyramidLoveToyIcon(artwork, color: color, size: size);
      if (toy == _ToyKind.nestCycle) {
        return Transform.translate(
          offset: Offset(0, inMenu ? -8.0 : -6.0),
          child: icon,
        );
      }
      return icon;
    }
    final icon = toy == _ToyKind.entropy
        ? (_entropyEnabled ? Icons.hourglass_top : Icons.hourglass_bottom)
        : toy.icon;
    return Icon(icon, size: 21, color: color);
  }

  Future<void> _showToyMenu() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Toys',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 56),
            child: StatefulBuilder(
              builder: (context, setDialogState) => Material(
                color: const Color(0xFF202020),
                elevation: 10,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: SizedBox(
                    width: 270,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children: [
                            for (final toy in _ToyKind.values)
                              Tooltip(
                                message: toy.label,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () async {
                                    await _toggleToyVisibility(toy);
                                    if (dialogContext.mounted)
                                      setDialogState(() {});
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          (_toyVisible[toy] ??
                                              toy.defaultVisible)
                                          ? Colors.white.withValues(alpha: 0.13)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color:
                                            (_toyVisible[toy] ??
                                                toy.defaultVisible)
                                            ? Colors.white38
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: _toyIcon(
                                      toy,
                                      (_toyVisible[toy] ?? toy.defaultVisible)
                                          ? Colors.white
                                          : Colors.white38,
                                      inMenu: true,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDisplayMenu() async {
    final choice = await _showCompactMenu([
      _compactMenuItem('size', Icons.straighten, 'Size'),
      _compactMenuItem('brightness', Icons.brightness_6_outlined, 'Brightness'),
      _compactMenuItem(
        'orientation',
        Icons.screen_lock_rotation,
        'Orientation Lock',
      ),
      _compactMenuItem(
        'round',
        Icons.change_history,
        'Safety Tips',
        checked: _roundedTriangleTips,
      ),
      if (kIsWeb)
        _compactMenuItem('fullscreen', Icons.fullscreen, 'Full-screen'),
    ]);
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'size':
        await _showCalibrationCheck();
      case 'brightness':
        await _showBrightnessDialog();
      case 'orientation':
        await _showOrientationLockInfo();
      case 'round':
        await _toggleRoundedTriangleTips();
      case 'fullscreen':
        await _showWebInstallHelp();
    }
  }

  void _showHistoryControls() {
    _historyControlsTimer?.cancel();
    setState(() => _historyControlsVisible = true);
    _historyControlsTimer = Timer(const Duration(seconds: 57), () {
      if (mounted) setState(() => _historyControlsVisible = false);
    });
  }

  void _undoFromUi() {
    if (!_controller.canUndo) return;
    _controller.undo();
    _showHistoryControls();
  }

  void _redoFromUi() {
    if (!_controller.canRedo) return;
    _controller.redo();
    _showHistoryControls();
  }

  Widget _instructionsPane() {
    final size = MediaQuery.sizeOf(context);
    final isDesktop =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final isTablet = size.shortestSide >= 600;
    final deviceName = isDesktop
        ? 'Desktop / trackpad'
        : isIos
        ? (isTablet ? 'iPad' : 'iPhone')
        : defaultTargetPlatform == TargetPlatform.android
        ? (isTablet ? 'Android tablet' : 'Android phone')
        : 'Touch device';

    final instructions = isDesktop
        ? <(String, String)>[
            ('Create / resize / delete', 'Double-click'),
            ('Tip / stand', 'Drag through the footprint edge'),
            ('Full / wall light', 'Draw a loop around an upright footprint'),
            ('Move', 'Two-finger scroll over a footprint'),
            ('Rotate', 'Shift + two-finger scroll'),
            ('Board snap', 'Boards > Snap pieces to board'),
            (
              'Dice bubble',
              'Press/release to roll; two-finger drag moves; latch tiles cycle die counts',
            ),
            (
              'Zendo stones',
              'Tap or drag from tray; drag stones; double-click to remove',
            ),
            ('Toys', 'Toys chooses controls; hold an icon for its name'),
          ]
        : <(String, String)>[
            ('Create / resize / delete', 'Double-tap'),
            ('Tip / stand', 'Drag through the footprint edge'),
            ('Full / wall light', 'Draw a loop around an upright footprint'),
            ('Move + rotate', 'Two-finger drag and twist'),
            ('Board snap', 'Boards > Snap pieces to board'),
            (
              'Dice bubble',
              'Tap or hold/release to roll; two-finger drag moves; latch tiles cycle die counts',
            ),
            (
              'Zendo stones',
              'Tap or drag from tray; drag stones; double-tap to remove',
            ),
            ('Toys', 'Toys chooses controls; hold an icon for its name'),
          ];

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 62),
          child: Material(
            color: const Color(0xEE171717),
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Instructions · $deviceName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close instructions',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _instructionsVisible = false),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final item in instructions)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Text.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      height: 1.25,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${item.$1}: ',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(text: item.$2),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toyControl(_ToyKind toy) {
    final active = _toyIsActive(toy);
    if (toy == _ToyKind.turnTimer) {
      return Tooltip(
        message: toy.label,
        triggerMode: TooltipTriggerMode.longPress,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Semantics(
                button: true,
                label:
                    'Turn Timer. Hold and drag left or right to adjust speed.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _startTurnTimer,
                  onLongPressStart: _beginTimerAdjustment,
                  onLongPressMoveUpdate: _updateTimerAdjustment,
                  onLongPressEnd: _endTimerAdjustment,
                  onLongPressCancel: _cancelTimerAdjustment,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      toy.icon,
                      size: 21,
                      color: active ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
              if (_timerNeedleVisible)
                Positioned(
                  bottom: 34,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 92,
                      height: 66,
                      child: CustomPaint(
                        painter: _TimerNeedlePainter(
                          durationSeconds: _turnTimerDurationSeconds,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (toy == _ToyKind.redSweep) {
      return Tooltip(
        message: toy.label,
        triggerMode: TooltipTriggerMode.longPress,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Semantics(
                button: true,
                label:
                    'Red Sweep. Hold and drag left or right to adjust speed.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _activateToy(toy),
                  onLongPressStart: _beginRedSweepAdjustment,
                  onLongPressMoveUpdate: _updateRedSweepAdjustment,
                  onLongPressEnd: _endRedSweepAdjustment,
                  onLongPressCancel: _cancelRedSweepAdjustment,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      toy.icon,
                      size: 21,
                      color: active ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
              if (_redSweepNeedleVisible)
                Positioned(
                  bottom: 34,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 92,
                      height: 66,
                      child: CustomPaint(
                        painter: _TimerNeedlePainter(
                          durationSeconds: _redSweepPeriodSeconds,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return IconButton(
      tooltip: toy.label,
      visualDensity: VisualDensity.compact,
      onPressed:
          _randomizerRunning &&
              {_ToyKind.lightLottery, _ToyKind.hotPotato}.contains(toy)
          ? null
          : () => _activateToy(toy),
      icon: _toyIcon(
        toy,
        active ? Colors.white : Colors.white70,
        inMenu: false,
      ),
    );
  }

  Widget _toyControls() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 260),
    child: Wrap(
      alignment: WrapAlignment.end,
      runAlignment: WrapAlignment.end,
      verticalDirection: VerticalDirection.up,
      spacing: 0,
      runSpacing: 0,
      children: [
        for (final toy in _ToyKind.values)
          if ((_toyVisible[toy] ?? toy.defaultVisible) &&
              toy != _ToyKind.turnTimer &&
              toy != _ToyKind.redSweep)
            _toyControl(toy),
      ],
    ),
  );

  Widget _adjustableToyControls() {
    final toys = [
      if (_toyVisible[_ToyKind.turnTimer] ??
          _ToyKind.turnTimer.defaultVisible)
        _ToyKind.turnTimer,
      if (_toyVisible[_ToyKind.redSweep] ?? _ToyKind.redSweep.defaultVisible)
        _ToyKind.redSweep,
    ];
    if (toys.isEmpty) return const SizedBox.shrink();
    return Material(
      color: const Color(0x55171717),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final toy in toys) _toyControl(toy)],
      ),
    );
  }

  Widget _gunAimHandle(int index, Alignment alignment) {
    final size = 132.0 * _remoteUiScale;
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: size,
        height: size,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanDown: (details) =>
              _aimGunFromLocal(index, details.localPosition),
          onPanUpdate: (details) =>
              _aimGunFromLocal(index, details.localPosition),
          onPanEnd: (_) => _fireSideGun(index),
          onTapUp: (_) => _fireSideGun(index),
        ),
      ),
    );
  }

  Widget _sideGunAimHandles() => Stack(
    children: [
      _gunAimHandle(0, Alignment.topLeft),
      _gunAimHandle(1, Alignment.topRight),
      _gunAimHandle(2, Alignment.bottomLeft),
      _gunAimHandle(3, Alignment.bottomRight),
    ],
  );

  Widget _historyControls() => AnimatedOpacity(
    opacity: _historyControlsVisible ? 1 : 0,
    duration: const Duration(seconds: 3),
    curve: Curves.easeOut,
    child: IgnorePointer(
      ignoring: !_historyControlsVisible,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Undo',
            visualDensity: VisualDensity.compact,
            onPressed: _controller.canUndo ? _undoFromUi : null,
            icon: const Icon(Icons.undo, size: 21),
          ),
          IconButton(
            tooltip: 'Redo',
            visualDensity: VisualDensity.compact,
            onPressed: _controller.canRedo ? _redoFromUi : null,
            icon: const Icon(Icons.redo, size: 21),
          ),
        ],
      ),
    ),
  );

  Future<void> _openGithub() async {
    final uri = Uri.parse('https://github.com/udeudeude/LightHouse');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _dismissCreditsAndRecalibrate() {
    _faceDownTimer?.cancel();
    _faceDownTimer = null;
    final sign = _lastDominantZSign;
    setState(() {
      if (sign != null) _faceUpZSign = sign;
      _faceUpCandidateSign = null;
      _faceUpStableSamples = 0;
      _faceDownLatched = false;
      _creditsVisible = false;
    });
  }

  Widget _credits() => CreditsOverlay(
    onCloseAndRecalibrate: _dismissCreditsAndRecalibrate,
    onOpenGithub: () => unawaited(_openGithub()),
  );

  Widget _buildBoardSurface(BuildContext surfaceContext) {
    final safePadding = _boardSurfacePadding(surfaceContext);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_remoteControllerMode &&
            _remoteDisplayWidthMm != null &&
            _remoteDisplayHeightMm != null)
          Padding(
            padding: safePadding,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white38, width: 1),
                ),
              ),
            ),
          ),
        Padding(
          padding: safePadding,
          child: IgnorePointer(
            ignoring: _remoteDisplayInputBlocked,
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              onPointerSignal: _onPointerSignal,
              onPointerPanZoomStart: _onPointerPanZoomStart,
              onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
              onPointerPanZoomEnd: _onPointerPanZoomEnd,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTapDown: _handleDoubleTapDown,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: ValueListenableBuilder<int>(
                  valueListenable: _toyRevision,
                  builder: (context, revision, child) => RepaintBoundary(
                    child: CustomPaint(
                      painter: BoardPainter(
                        state: _controller.state,
                        logicalPixelsPerMm: _pixelsPerMm,
                        geometry: _controller.geometry,
                        selectedId:
                            _remoteDisplayMode &&
                                !_remoteControlState.displayShapesVisible
                            ? null
                            : _selectedId,
                        elementOpacities: _paintElementOpacities,
                        burstCenter: _burstCenter,
                        triangleBouncePhase:
                            _activeToys.contains(_ToyKind.triangleBounce)
                            ? 0.5 - 0.5 * math.cos(_toyClock * math.pi * 0.9)
                            : null,
                        squareChasePhase:
                            _activeToys.contains(_ToyKind.squareChase)
                            ? (_toyClock * 0.24) % 1
                            : null,
                        squareChaseSeed: _squareChaseSeed,
                        roundTriangleTips: _roundedTriangleTips,
                        checkerUnderlays: _checkerUnderlays,
                        burstProgress: _burstProgress,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_remoteControlState.rippleLevels.isNotEmpty)
          Padding(
            padding: safePadding,
            child: IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: _toyRevision,
                builder: (context, revision, child) => RepaintBoundary(
                  child: CustomPaint(
                    painter: RippleOverlayPainter(
                      elements: _controller.state.elements,
                      levels: _remoteControlState.rippleLevels,
                      logicalPixelsPerMm: _pixelsPerMm,
                      phaseSeconds: _rippleClock,
                      geometry: _controller.geometry,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: safePadding,
          child: IgnorePointer(
            child: ValueListenableBuilder<int>(
              valueListenable: _toyRevision,
              builder: (context, revision, child) => RepaintBoundary(
                child: CustomPaint(
                  painter: ToyOverlayPainter(
                    logicalPixelsPerMm: _pixelsPerMm,
                    geometry: _controller.geometry,
                    elements: _controller.state.elements,
                    ghostTrails: _ghostTrails,
                    ghostTrailsVisible: _ghostTrailActive,
                    eventZoneCenter: _eventZoneCenter,
                    eventZoneRadiusMm: _eventZoneRadiusMm,
                    eventZoneProgress: _eventZoneProgress,
                    eventZoneDismiss: _eventZoneDismiss,
                    turnTimerProgress: _turnTimerProgress,
                    radarAngleDegrees: _activeToys.contains(_ToyKind.radar)
                        ? _radarAngleDegrees
                        : null,
                    redSweepY: _activeToys.contains(_ToyKind.redSweep)
                        ? _redSweepY
                        : null,
                    dieValue: null,
                    dieRollPhase: 0,
                    dieRollProgress: 1,
                    diePressed: false,
                    projectiles: _projectiles,
                    impacts: _impacts,
                    sideGunsVisible: _activeToys.contains(_ToyKind.sideGuns),
                    sideGunAnglesDegrees: List<double>.unmodifiable(
                      _sideGunAnglesDegrees,
                    ),
                    sideGunAmmo: List<int>.unmodifiable(_sideGunAmmo),
                    cornerGunsVisible:
                        _activeToys.contains(_ToyKind.cornerRicochet) ||
                        _projectiles.any((p) => p.ricochet),
                    constellation: _constellationPoints,
                    uiScale: _remoteUiScale,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        if (_activeToys.contains(_ToyKind.wireDie))
          Padding(
            padding: _remoteControllerMode ? safePadding : EdgeInsets.zero,
            child: IgnorePointer(
              ignoring: _remoteDisplayMode,
              child: DiceBubble(
                snapshot: _diceSnapshot,
                onChanged: _remoteDisplayMode ? null : _handleDiceSnapshot,
                scale: _remoteUiScale,
              ),
            ),
          ),
        if (_activeToys.contains(_ToyKind.zendoStones))
          Padding(
            padding: _remoteControllerMode ? safePadding : EdgeInsets.zero,
            child: IgnorePointer(
              ignoring: _remoteDisplayMode,
              child: ZendoStonesWidget(
                snapshot: _zendoSnapshot,
                onChanged: _remoteDisplayMode ? null : _handleZendoSnapshot,
                scale: _remoteUiScale,
              ),
            ),
          ),
        if (_activeToys.contains(_ToyKind.sideGuns) && !_remoteDisplayMode)
          Padding(padding: safePadding, child: _sideGunAimHandles()),
        if (!_remoteDisplayMode)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_remoteControllerMode &&
                        _remoteSession?.peerSeen == true) ...[
                      _remoteControllerQuickControls(),
                      const SizedBox(width: 8),
                    ],
                    _adjustableToyControls(),
                  ],
                ),
              ),
            ),
          ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_remoteDisplayMode)
                    _remoteStatusButton()
                  else ...[
                    _menu(),
                    _historyControls(),
                    if (_remoteSession != null) _remoteStatusButton(),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!_remoteDisplayMode)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _toyControls(),
              ),
            ),
          ),
        _zendoRuleCard(),
        if (_instructionsVisible) _instructionsPane(),
        if (_creditsVisible) Positioned.fill(child: _credits()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => TooltipTheme(
    data: const TooltipThemeData(preferBelow: false),
    child: Scaffold(
      backgroundColor: Colors.black,
      body: _buildBoardSurface(context),
    ),
  );
}

class _MenuCirclePainter extends CustomPainter {
  const _MenuCirclePainter({required this.snapDegrees});

  final double? snapDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1;
    final paint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    canvas.drawCircle(center, radius, paint);

    final degrees = snapDegrees;
    if (degrees == null || degrees <= 0) return;
    final tickCount = (360 / degrees).round().clamp(4, 24);
    for (var i = 0; i < tickCount; i += 1) {
      final angle = -math.pi / 2 + 2 * math.pi * i / tickCount;
      final outer = radius - 0.35;
      final inner = radius - (i % 2 == 0 ? 4.5 : 3.5);
      canvas.drawLine(
        Offset(
          center.dx + inner * math.cos(angle),
          center.dy + inner * math.sin(angle),
        ),
        Offset(
          center.dx + outer * math.cos(angle),
          center.dy + outer * math.sin(angle),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MenuCirclePainter oldDelegate) =>
      oldDelegate.snapDegrees != snapDegrees;
}

class _TimerNeedlePainter extends CustomPainter {
  const _TimerNeedlePainter({required this.durationSeconds});

  final double durationSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 7);
    final gauge = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rect = Rect.fromCircle(center: center, radius: 32);
    canvas.drawArc(rect, math.pi * 1.12, math.pi * 0.76, false, gauge);
    final logSpeed = (math.log(30 / durationSeconds) / math.ln2).clamp(
      -1.5,
      1.5,
    );
    final fraction = (logSpeed + 1.5) / 3;
    final angle = math.pi * 1.12 + math.pi * 0.76 * fraction;
    final tip = Offset(
      center.dx + math.cos(angle) * 27,
      center.dy + math.sin(angle) * 27,
    );
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 2.2, Paint()..color = Colors.white);
    final label = TextPainter(
      text: TextSpan(
        text: '${durationSeconds.round()}s',
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(center.dx - label.width / 2, 0));
  }

  @override
  bool shouldRepaint(_TimerNeedlePainter oldDelegate) =>
      oldDelegate.durationSeconds != durationSeconds;
}
