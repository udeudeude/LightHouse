import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../application/board_controller.dart';
import '../application/board_store.dart';
import '../domain/board_state.dart';
import '../domain/board_underlay.dart';
import '../domain/convex_geometry.dart';
import '../domain/geometry.dart';
import '../domain/light_element.dart';
import '../domain/light_structure.dart';
import '../domain/physical_point.dart';
import '../platform/motion_permission.dart';
import '../platform/web_orientation.dart';
import 'board_painter.dart';
import 'toy_overlay.dart';

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
  wireDie('D6', Icons.casino, false),
  sideGuns('Side Guns', Icons.gps_fixed, false),
  cornerRicochet('Corner Ricochet', Icons.radio_button_checked, false),
  hotPotato('Hot Potato', Icons.local_fire_department, false),
  constellationDraw('Constellation Draw', Icons.share, false),
  heartbeat('Heartbeat', Icons.favorite_border, false),
  triangleBounce('Triangle Bounce', Icons.change_history, false),
  squareChase('Square Chase', Icons.crop_square, false);

  const _ToyKind(this.label, this.icon, this.defaultVisible);

  final String label;
  final IconData icon;
  final bool defaultVisible;

  String get preferenceKey => 'lighthouse.toy.$name.visible.v2';
}

class BoardScreenNext extends StatefulWidget {
  const BoardScreenNext({
    super.key,
    required this.logicalPixelsPerMm,
    required this.initialState,
    required this.calibrationLabel,
    required this.onRecalibrate,
  });

  final double logicalPixelsPerMm;
  final BoardState initialState;
  final String calibrationLabel;
  final ValueChanged<BoardState> onRecalibrate;

  @override
  State<BoardScreenNext> createState() => _BoardScreenNextState();
}

class _BoardScreenNextState extends State<BoardScreenNext>
    with WidgetsBindingObserver {
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
  Size? _webBoardSize;
  EdgeInsets? _webBoardPadding;
  EdgeInsets? _webBoardViewPadding;
  double? _webReferenceOrientationAngle;
  double? _webObservedOrientationAngle;
  Timer? _webOrientationPollTimer;
  double? _rotationSnapDegrees;
  bool _gridSnapEnabled = false;
  bool _checkerUnderlays = false;
  bool _transformTranslated = false;

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
  int _effectGeneration = 0;
  int _entropyGeneration = 0;
  double _toyClock = 0;
  double _radarAngleDegrees = 0;
  double _redSweepY = 0;
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
  int _dieValue = 1;
  double _dieRollPhase = 0;
  double _dieRollProgress = 1;
  DateTime? _dieRollEndsAt;
  bool _diePressed = false;
  List<ToyProjectile> _projectiles = const [];
  List<ToyImpact> _impacts = const [];
  final List<double> _sideGunAnglesDegrees = [0, 180, 90, 270];
  final List<int> _sideGunAmmo = [0, 0, 0, 0];
  List<PhysicalPoint> _constellation = const [];
  String? _heartbeatOddId;
  double _heartbeatStartedAt = 0;
  final Map<String, List<PhysicalPoint>> _ghostTrails = {};
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
  double? _faceUpZSign;
  double? _faceUpCandidateSign;
  int _faceUpStableSamples = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = BoardController(initialState: widget.initialState)
      ..addListener(_refresh);
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyBrightness();
      _loadInteractionPreferences();
      if (!kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
        _startFaceDownMonitoring();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final media = MediaQuery.of(context);
      _webBoardSize ??= media.size;
      _webBoardPadding ??= media.padding;
      _webBoardViewPadding ??= media.viewPadding;
      final angle = currentWebOrientationAngle();
      _webReferenceOrientationAngle ??= angle;
      _webObservedOrientationAngle ??= angle;
      _webOrientationPollTimer ??= Timer.periodic(
        const Duration(milliseconds: 120),
        (_) => _pollWebOrientation(),
      );
    }
    if (_orientationLocked || kIsWeb) return;
    _orientationLocked = true;
    final orientation = MediaQuery.orientationOf(context);
    SystemChrome.setPreferredOrientations([
      orientation == Orientation.portrait
          ? DeviceOrientation.portraitUp
          : DeviceOrientation.landscapeLeft,
    ]);
  }

  void _pollWebOrientation() {
    if (!mounted || !kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final angle = currentWebOrientationAngle();
    if (angle == _webObservedOrientationAngle) return;
    setState(() => _webObservedOrientationAngle = angle);
  }

  @override
  void didChangeMetrics() {
    if (!kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _webObservedOrientationAngle = currentWebOrientationAngle();
        setState(() {});
      }
    });
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _pollWebOrientation();
    });
    Future<void>.delayed(const Duration(milliseconds: 340), () {
      if (mounted) _pollWebOrientation();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (state == AppLifecycleState.resumed) {
      _applyBrightness();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceDownTimer?.cancel();
    _webMotionTimer?.cancel();
    _webOrientationPollTimer?.cancel();
    _desktopScrollEndTimer?.cancel();
    _historyControlsTimer?.cancel();
    _entropyTimer?.cancel();
    _toyTicker?.cancel();
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
      samplingPeriod: const Duration(milliseconds: 140),
    ).listen(_handleAccelerometer, onError: (_) {});
  }

  void _startWebMotionMonitoring() {
    if (!kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _webMotionTimer?.cancel();
    _webMotionTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
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
      for (final toy in _ToyKind.values) {
        _toyVisible[toy] =
            preferences.getBool(toy.preferenceKey) ?? toy.defaultVisible;
      }
    });
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
  }

  Future<void> _toggleRoundedTriangleTips() async {
    setState(() => _roundedTriangleTips = !_roundedTriangleTips);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      'lighthouse.roundedTriangleTips.v1',
      _roundedTriangleTips,
    );
  }

  Future<void> _saveTurnTimerDuration() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(
      'lighthouse.turnTimerSeconds.v1',
      _turnTimerDurationSeconds,
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
        _dieRollEndsAt = null;
        _dieRollPhase = 0;
        _dieRollProgress = 1;
        _diePressed = false;
      case _ToyKind.sideGuns:
        _projectiles = _projectiles.where((p) => p.ricochet).toList();
        for (var i = 0; i < _sideGunAmmo.length; i += 1) {
          _sideGunAmmo[i] = 0;
        }
      case _ToyKind.cornerRicochet:
        _projectiles = _projectiles.where((p) => !p.ricochet).toList();
      case _ToyKind.constellationDraw:
        _constellation = const [];
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
    }
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
      _ToyKind.constellationDraw => _constellation.isNotEmpty,
      _ToyKind.breathing ||
      _ToyKind.nestCycle ||
      _ToyKind.radar ||
      _ToyKind.redSweep ||
      _ToyKind.heartbeat ||
      _ToyKind.triangleBounce ||
      _ToyKind.squareChase => _activeToys.contains(toy),
    };
  }

  ({double width, double height}) _physicalBoardSize() {
    final size = _webBoardSize ?? MediaQuery.sizeOf(context);
    final padding = _webBoardViewPadding ?? MediaQuery.viewPaddingOf(context);
    return (
      width: math.max(
        1.0,
        (size.width - padding.horizontal) / widget.logicalPixelsPerMm,
      ),
      height: math.max(
        1.0,
        (size.height - padding.vertical) / widget.logicalPixelsPerMm,
      ),
    );
  }

  void _toggleContinuousLightToy(_ToyKind toy) {
    if (_activeToys.contains(toy)) {
      _activeToys.remove(toy);
      if (!_randomizerRunning) _effectOpacities = const {};
      _maybeStopToyTicker();
      setState(() {});
      return;
    }
    _activeToys.add(toy);
    if (toy == _ToyKind.heartbeat) {
      final elements = _controller.state.elements;
      _heartbeatOddId = elements.isEmpty
          ? null
          : elements[_random.nextInt(elements.length)].id;
      _heartbeatStartedAt = _toyClock;
    }
    _ensureToyTicker();
    setState(() {});
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
  }

  void _toggleDie() {
    setState(() {
      if (!_activeToys.add(_ToyKind.wireDie)) {
        _activeToys.remove(_ToyKind.wireDie);
        _diePressed = false;
        _dieRollEndsAt = null;
        _dieRollProgress = 1;
      }
    });
    _maybeStopToyTicker();
  }

  void _rollWireDie() {
    if (!_activeToys.contains(_ToyKind.wireDie)) return;
    _dieRollEndsAt = DateTime.now().add(const Duration(milliseconds: 1300));
    _dieValue = 1 + _random.nextInt(6);
    _dieRollPhase = 0;
    _dieRollProgress = 0;
    _ensureToyTicker();
    setState(() {});
  }

  void _pressDie() {
    if (!_activeToys.contains(_ToyKind.wireDie)) return;
    HapticFeedback.selectionClick();
    setState(() => _diePressed = true);
  }

  void _releaseDie() {
    if (!_diePressed) return;
    setState(() => _diePressed = false);
    HapticFeedback.mediumImpact();
    _rollWireDie();
  }

  void _loadSideGuns() {
    _activeToys.add(_ToyKind.sideGuns);
    for (var i = 0; i < _sideGunAmmo.length; i += 1) {
      _sideGunAmmo[i] += 5;
    }
    HapticFeedback.selectionClick();
    setState(() {});
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
    final inset = 8 / widget.logicalPixelsPerMm;
    final centerX = table.width / 2;
    final centerY = table.height / 2;
    final position = switch (index) {
      0 => PhysicalPoint(inset, centerY),
      1 => PhysicalPoint(table.width - inset, centerY),
      2 => PhysicalPoint(centerX, inset),
      _ => PhysicalPoint(centerX, table.height - inset),
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
  }

  void _aimGunFromLocal(int gunIndex, Offset localPosition) {
    const box = 48.0;
    final center = switch (gunIndex) {
      0 => const Offset(8, box / 2),
      1 => const Offset(box - 8, box / 2),
      2 => const Offset(box / 2, 8),
      _ => const Offset(box / 2, box - 8),
    };
    final base = <double>[0, 180, 90, 270][gunIndex];
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
  }

  void _ensureToyTicker() {
    _toyTicker ??= Timer.periodic(const Duration(milliseconds: 33), (_) {
      _tickToys(0.033);
    });
  }

  bool get _needsToyTicker =>
      _activeToys.any(_continuousLightToys.contains) ||
      _eventZoneCenter != null ||
      _turnTimerProgress != null ||
      _dieRollEndsAt != null ||
      _projectiles.isNotEmpty ||
      _impacts.isNotEmpty;

  void _maybeStopToyTicker() {
    if (_needsToyTicker) return;
    _toyTicker?.cancel();
    _toyTicker = null;
  }

  void _tickToys(double dt) {
    if (!mounted) return;
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

    final dieEnds = _dieRollEndsAt;
    if (dieEnds != null) {
      final remaining = dieEnds.difference(now).inMilliseconds;
      if (remaining <= 0) {
        _dieRollEndsAt = null;
        _dieRollPhase = 0;
        _dieRollProgress = 1;
      } else {
        _dieRollProgress = (1 - remaining / 1300).clamp(0, 1).toDouble();
        _dieRollPhase += dt * 13;
      }
    }

    _tickProjectiles(dt);
    _updateContinuousLighting();
    setState(() {});
    _maybeStopToyTicker();
  }

  void _updateContinuousLighting() {
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
      _radarAngleDegrees = normalizeDegrees(_radarAngleDegrees + 1.8);
    }
    if (sweepOn) {
      final phase = (_toyClock * 0.15) % 2;
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
        final polygon = polygonForElement(element, _controller.geometry);
        final minY = polygon.map((p) => p.yMm).reduce(math.min);
        final maxY = polygon.map((p) => p.yMm).reduce(math.max);
        opacity = math.min(
          opacity,
          lineY >= minY && lineY <= maxY ? 1.0 : 0.035,
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
    if (!_activeToys.contains(_ToyKind.nestCycle)) return _effectOpacities;
    final result = Map<String, double>.from(_effectOpacities);
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
        if (element != null) result[id] = element.size == wanted ? 1.0 : 0.025;
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
    if (_constellation.isNotEmpty) {
      setState(() => _constellation = const []);
      return;
    }
    final elements = [..._controller.state.elements]..shuffle(_random);
    if (elements.length < 2) return;
    final count = math.min(elements.length, 2 + _random.nextInt(4));
    setState(() {
      _constellation = [for (final e in elements.take(count)) e.position];
    });
  }

  PhysicalPoint? _nearestUnderlaySnapPoint() {
    if (!_gridSnapEnabled || !_transformTranslated) return null;
    final targetId = _transformTarget?.id ?? _desktopScrollTarget?.id;
    if (targetId == null) return null;
    final target = _controller.state.elementById(targetId);
    if (target == null || !_controller.state.underlay.isVisible) return null;
    final mediaSize = _webBoardSize ?? MediaQuery.sizeOf(context);
    final padding = _webBoardViewPadding ?? MediaQuery.viewPaddingOf(context);
    final widthPx = mediaSize.width - padding.horizontal;
    final heightPx = mediaSize.height - padding.vertical;
    return _controller.state.underlay.nearestSnapPoint(
      target.position,
      boardWidthMm: widthPx / widget.logicalPixelsPerMm,
      boardHeightMm: heightPx / widget.logicalPixelsPerMm,
    );
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

  void _refresh() {
    if (!mounted) return;
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
    setState(() {
      if (_selectedId != null &&
          _controller.state.elementById(_selectedId!) == null) {
        _selectedId = null;
      }
    });
    _store.save(_controller.state);
  }

  PhysicalPoint _toPhysical(Offset point) => PhysicalPoint(
    point.dx / widget.logicalPixelsPerMm,
    point.dy / widget.logicalPixelsPerMm,
  );

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
    final point = _toPhysical(details.localPosition);
    final target = _controller.hitTest(point, haloMm: _interactionHaloMm);
    if (target == null) {
      _controller.createAt(point);
    } else {
      _controller.cycleSizeOrDelete(target);
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
    if (_transformTarget != null) {
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
        details.focalPointDelta.dx / widget.logicalPixelsPerMm,
        details.focalPointDelta.dy / widget.logicalPixelsPerMm,
      );
      final rotationDelta = details.rotation - _lastRotation;
      _lastRotation = details.rotation;
      if (delta.distanceTo(PhysicalPoint.zero) > 0.35) {
        _transformTranslated = true;
      }
      _controller.transformBy(delta, rotationDelta);
      return;
    }

    if (_transformStarted) return;
    _oneFingerLast = current;
    if (_oneFingerPath.isEmpty ||
        _oneFingerPath.last.distanceTo(current) >= 0.7) {
      _oneFingerPath.add(current);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_mouseTransform || _creditsVisible) return;
    if (_transformStarted) {
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
      setState(() => _selectedId = tapped?.id);
    }
    _clearGesture();
  }

  bool _crossesFlatBaseEdge(
    LightElement triangle,
    PhysicalPoint start,
    PhysicalPoint end,
  ) {
    if (!_containsPoint(triangle, start) || _containsPoint(triangle, end)) {
      return false;
    }
    final localStart = rotateVector(
      start - triangle.position,
      -triangle.headingDegrees,
    );
    final localEnd = rotateVector(
      end - triangle.position,
      -triangle.headingDegrees,
    );
    final halfLength = _controller.geometry.flatLengthMm(triangle.size) / 2;
    final halfBase = _controller.geometry.baseMm(triangle.size) / 2;
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
          setState(() => _selectedId = tapped?.id);
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
      event.panDelta.dx / widget.logicalPixelsPerMm,
      event.panDelta.dy / widget.logicalPixelsPerMm,
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
        -event.scrollDelta.dx / widget.logicalPixelsPerMm,
        -event.scrollDelta.dy / widget.logicalPixelsPerMm,
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

  Future<void> _saveBoard({bool asCopy = false}) async {
    final title = await _askForTitle(_controller.state.title);
    if (title == null || title.trim().isEmpty) return;
    _controller.renameBoard(title);
    final id = await _store.saveNamed(
      _controller.state,
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
                          setState(() => _activeSavedId = item.id);
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
    final raw = _store.exportJson(_controller.state);
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
      setState(() => _activeSavedId = null);
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
    final pixelsPerMm = widget.logicalPixelsPerMm;
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

  RelativeRect _compactMenuPosition() {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final left = padding.left + 8;
    final bottom = padding.bottom + 50;
    return RelativeRect.fromLTRB(
      left,
      size.height - bottom,
      math.max(0.0, size.width - left - 1),
      bottom,
    );
  }

  PopupMenuItem<String> _compactMenuItem(
    String value,
    IconData icon,
    String label, {
    bool enabled = true,
    bool checked = false,
  }) => PopupMenuItem<String>(
    value: value,
    enabled: enabled,
    height: 40,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(checked ? Icons.check : icon, size: 19),
        const SizedBox(width: 10),
        Text(label),
      ],
    ),
  );

  Future<String?> _showCompactMenu(List<PopupMenuEntry<String>> items) =>
      showMenu<String>(
        context: context,
        position: _compactMenuPosition(),
        color: const Color(0xFF202020),
        items: items,
      );

  Future<void> _showMainMenu() async {
    await _ensureMotionPermission();
    if (!mounted) return;
    final choice = await _showCompactMenu([
      _compactMenuItem('file', Icons.folder_outlined, 'File'),
      _compactMenuItem('edit', Icons.edit_outlined, 'Edit'),
      _compactMenuItem('boards', Icons.grid_on, 'Boards'),
      _compactMenuItem('toys', Icons.toys_outlined, 'Toys'),
      _compactMenuItem('display', Icons.display_settings, 'Display'),
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
      case 'display':
        await _showDisplayMenu();
      case 'instructions':
        setState(() => _instructionsVisible = true);
    }
  }

  Future<void> _showFileMenu() async {
    final choice = await _showCompactMenu([
      _compactMenuItem('new', Icons.note_add_outlined, 'New'),
      _compactMenuItem('open', Icons.folder_open, 'Open…'),
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
      _compactMenuItem(
        'checker',
        Icons.grid_on,
        'Checker shading',
        checked: _checkerUnderlays,
      ),
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
        ),
    ]);
    if (!mounted || choice == null) return;
    final underlay = BoardUnderlay.values[int.parse(choice.substring(1))];
    _toggleUnderlaySelection(underlay);
  }

  IconData _toyIcon(_ToyKind toy) {
    if (toy == _ToyKind.entropy) {
      return _entropyEnabled ? Icons.hourglass_top : Icons.hourglass_bottom;
    }
    return toy.icon;
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
                                    child: Icon(
                                      _toyIcon(toy),
                                      size: 21,
                                      color:
                                          (_toyVisible[toy] ??
                                              toy.defaultVisible)
                                          ? Colors.white
                                          : Colors.white38,
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
        'Rounded Triangle Tips',
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
    final size = _webBoardSize ?? MediaQuery.sizeOf(context);
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
            ('Select', 'Click'),
            ('Tip / stand', 'Click-drag across the actual footprint edge'),
            ('Light full / walls', 'Draw a loop around an upright footprint'),
            ('Move', 'Two-finger scroll over a footprint'),
            ('Rotate', 'Hold Shift while two-finger scrolling'),
            ('Exact rotation', 'Menu > Edit > Rotation'),
            ('Grid snap', 'Menu > Boards > Snap pieces to board'),
            (
              'Light lottery',
              'Enable in Menu > Toys, then tap the matching starburst button',
            ),
            (
              'Entropy',
              'Enable in Menu > Toys, then tap the matching hourglass control',
            ),
            ('Toy names', 'Press and hold a toy icon to pop up its name'),
            ('More toys', 'Menu > Toys controls which toy icons appear'),
          ]
        : <(String, String)>[
            ('Create / resize / delete', 'Double-tap'),
            ('Select', 'Tap'),
            (
              'Tip / stand',
              'Drag from inside across the actual footprint edge',
            ),
            ('Light full / walls', 'Draw a loop around an upright footprint'),
            ('Move + rotate', 'Two fingers: drag and twist'),
            ('Exact rotation', 'Menu > Edit > Rotation'),
            ('Grid snap', 'Menu > Boards > Snap pieces to board'),
            (
              'Light lottery',
              'Enable in Menu > Toys, then tap the matching starburst button',
            ),
            (
              'Entropy',
              'Enable in Menu > Toys, then tap the matching hourglass control',
            ),
            ('Toy names', 'Press and hold a toy icon to pop up its name'),
            ('More toys', 'Menu > Toys controls which toy icons appear'),
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
    return IconButton(
      tooltip: toy.label,
      visualDensity: VisualDensity.compact,
      onPressed:
          _randomizerRunning &&
              {_ToyKind.lightLottery, _ToyKind.hotPotato}.contains(toy)
          ? null
          : () => _activateToy(toy),
      icon: Icon(
        _toyIcon(toy),
        size: 21,
        color: active ? Colors.white : Colors.white70,
      ),
    );
  }

  Widget _toyControls() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 260),
    child: Wrap(
      alignment: WrapAlignment.end,
      runAlignment: WrapAlignment.end,
      spacing: 0,
      runSpacing: 0,
      children: [
        for (final toy in _ToyKind.values)
          if (_toyVisible[toy] ?? toy.defaultVisible) _toyControl(toy),
      ],
    ),
  );
  Widget _gunAimHandle(int index, Alignment alignment) => Align(
    alignment: alignment,
    child: SizedBox(
      width: 48,
      height: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanDown: (details) => _aimGunFromLocal(index, details.localPosition),
        onPanUpdate: (details) =>
            _aimGunFromLocal(index, details.localPosition),
        onPanEnd: (_) => _fireSideGun(index),
        onTapUp: (_) => _fireSideGun(index),
      ),
    ),
  );

  Widget _sideGunAimHandles() => Stack(
    children: [
      _gunAimHandle(0, Alignment.centerLeft),
      _gunAimHandle(1, Alignment.centerRight),
      _gunAimHandle(2, Alignment.topCenter),
      _gunAimHandle(3, Alignment.bottomCenter),
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
    final uri = Uri.parse('https://github.com/udeudeude/LightHouse-StashBoard');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _credits() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: null,
    child: ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 126,
                  height: 112,
                  child: CustomPaint(painter: _CreditsMarkPainter()),
                ),
                const SizedBox(height: 10),
                const Text(
                  'LightHouse',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'An illuminated physical play surface\nfor Looney Pyramids',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Project: udeudeude\nSoftware: Flutter + ChatGPT\nLooney Pyramids: Looney Labs\nOpen source under the MIT License',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, height: 1.6),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openGithub,
                  icon: const Icon(Icons.code, size: 18),
                  label: const Text(
                    'github.com/udeudeude/LightHouse-StashBoard',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildBoardSurface(BuildContext surfaceContext) {
    final safePadding = MediaQuery.viewPaddingOf(surfaceContext);

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: safePadding,
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
              child: CustomPaint(
                painter: BoardPainter(
                  state: _controller.state,
                  logicalPixelsPerMm: widget.logicalPixelsPerMm,
                  geometry: _controller.geometry,
                  selectedId: _selectedId,
                  elementOpacities: _paintElementOpacities,
                  burstCenter: _burstCenter,
                  triangleBouncePhase:
                      _activeToys.contains(_ToyKind.triangleBounce)
                      ? 0.5 - 0.5 * math.cos(_toyClock * math.pi * 0.9)
                      : null,
                  squareChasePhase: _activeToys.contains(_ToyKind.squareChase)
                      ? (_toyClock * 0.24) % 1
                      : null,
                  roundTriangleTips: _roundedTriangleTips,
                  checkerUnderlays: _checkerUnderlays,
                  burstProgress: _burstProgress,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Padding(
          padding: safePadding,
          child: IgnorePointer(
            child: CustomPaint(
              painter: ToyOverlayPainter(
                logicalPixelsPerMm: widget.logicalPixelsPerMm,
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
                dieValue: _activeToys.contains(_ToyKind.wireDie)
                    ? _dieValue
                    : null,
                dieRollPhase: _dieRollPhase,
                dieRollProgress: _dieRollProgress,
                diePressed: _diePressed,
                projectiles: _projectiles,
                impacts: _impacts,
                sideGunsVisible: _activeToys.contains(_ToyKind.sideGuns),
                sideGunAnglesDegrees: _sideGunAnglesDegrees,
                sideGunAmmo: _sideGunAmmo,
                cornerGunsVisible:
                    _activeToys.contains(_ToyKind.cornerRicochet) ||
                    _projectiles.any((p) => p.ricochet),
                constellation: _constellation,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        if (_activeToys.contains(_ToyKind.wireDie))
          Positioned(
            left: safePadding.left + 4,
            top: safePadding.top + 4,
            width: 86,
            height: 86,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _pressDie(),
              onPointerUp: (_) => _releaseDie(),
              onPointerCancel: (_) {
                if (mounted) setState(() => _diePressed = false);
              },
              child: const SizedBox.expand(),
            ),
          ),
        if (_activeToys.contains(_ToyKind.sideGuns))
          Padding(padding: safePadding, child: _sideGunAimHandles()),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [_menu(), _historyControls()],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _toyControls(),
            ),
          ),
        ),
        if (_instructionsVisible) _instructionsPane(),
        if (_creditsVisible) Positioned.fill(child: _credits()),
      ],
    );
  }

  double _webBoardRotationRadians() {
    final reference = _webReferenceOrientationAngle;
    final current = _webObservedOrientationAngle;
    if (reference == null || current == null) return 0;
    final raw = current - reference;
    final signed = ((raw + 540) % 360) - 180;
    final quarterTurns = (signed / 90).round();
    return -quarterTurns * math.pi / 2;
  }

  @override
  Widget build(BuildContext context) {
    final compensateForSafari =
        kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        _webBoardSize != null;

    if (!compensateForSafari) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildBoardSurface(context),
      );
    }

    final frozenSize = _webBoardSize!;
    final currentMedia = MediaQuery.of(context);
    final frozenMedia = currentMedia.copyWith(
      size: frozenSize,
      padding: _webBoardPadding ?? currentMedia.padding,
      viewPadding: _webBoardViewPadding ?? currentMedia.viewPadding,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.rotate(
            angle: _webBoardRotationRadians(),
            transformHitTests: true,
            child: SizedBox(
              width: frozenSize.width,
              height: frozenSize.height,
              child: MediaQuery(
                data: frozenMedia,
                child: Builder(builder: _buildBoardSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditsMarkPainter extends CustomPainter {
  const _CreditsMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final faint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final c = Offset(size.width / 2, size.height * 0.48);

    final frame = Path()
      ..moveTo(size.width * 0.18, size.height * 0.84)
      ..lineTo(size.width * 0.08, size.height * 0.48)
      ..lineTo(size.width * 0.23, size.height * 0.12)
      ..lineTo(size.width * 0.77, size.height * 0.12)
      ..lineTo(size.width * 0.92, size.height * 0.48)
      ..lineTo(size.width * 0.82, size.height * 0.84);
    canvas.drawPath(frame, faint);

    final tower = Path()
      ..moveTo(c.dx - 13, size.height * 0.80)
      ..lineTo(c.dx - 7, size.height * 0.35)
      ..lineTo(c.dx + 7, size.height * 0.35)
      ..lineTo(c.dx + 13, size.height * 0.80)
      ..close();
    canvas.drawPath(tower, line);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(c.dx, size.height * 0.30),
        width: 25,
        height: 10,
      ),
      line,
    );
    canvas.drawLine(
      Offset(c.dx, size.height * 0.17),
      Offset(c.dx, size.height * 0.25),
      line,
    );
    canvas.drawCircle(Offset(c.dx, size.height * 0.17), 2.2, line);

    final beamY = size.height * 0.30;
    canvas.drawLine(
      Offset(c.dx - 14, beamY),
      Offset(size.width * 0.14, beamY - 18),
      faint,
    );
    canvas.drawLine(
      Offset(c.dx - 14, beamY),
      Offset(size.width * 0.10, beamY + 5),
      faint,
    );
    canvas.drawLine(
      Offset(c.dx + 14, beamY),
      Offset(size.width * 0.86, beamY - 18),
      faint,
    );
    canvas.drawLine(
      Offset(c.dx + 14, beamY),
      Offset(size.width * 0.90, beamY + 5),
      faint,
    );

    void pyramid(Offset center, double scale) {
      final p = Path()
        ..moveTo(center.dx, center.dy - 12 * scale)
        ..lineTo(center.dx + 10 * scale, center.dy + 8 * scale)
        ..lineTo(center.dx - 10 * scale, center.dy + 8 * scale)
        ..close();
      canvas.drawPath(p, line);
    }

    pyramid(Offset(c.dx - 24, size.height * 0.87), 0.82);
    pyramid(Offset(c.dx, size.height * 0.88), 1.0);
    pyramid(Offset(c.dx + 24, size.height * 0.87), 0.66);
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.96),
      Offset(size.width * 0.82, size.height * 0.96),
      faint,
    );
  }

  @override
  bool shouldRepaint(covariant _CreditsMarkPainter oldDelegate) => false;
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
