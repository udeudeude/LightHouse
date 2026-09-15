from pathlib import Path
import re


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


def regex_once(text, pattern, replacement, label):
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly one regex match, found {count}')
    return new_text


# Main board screen: remove iOS web rotation compensation, reduce idle/background
# work, debounce persistence, and coalesce touch transforms to one update/frame.
path = Path('lib/ui/board_screen_next.dart')
text = path.read_text()
text = replace_once(
    text,
    "import 'package:flutter/services.dart';\n",
    "import 'package:flutter/services.dart';\nimport 'package:flutter/scheduler.dart';\n",
    'scheduler import',
)
text = replace_once(
    text,
    "import '../platform/web_orientation.dart';\n",
    '',
    'remove web orientation import',
)
text = replace_once(
    text,
    "  Size? _webBoardSize;\n"
    "  EdgeInsets? _webBoardPadding;\n"
    "  EdgeInsets? _webBoardViewPadding;\n"
    "  double? _webReferenceOrientationAngle;\n"
    "  double? _webObservedOrientationAngle;\n"
    "  Timer? _webOrientationPollTimer;\n",
    '',
    'remove web rotation state',
)
text = replace_once(
    text,
    "  bool _transformTranslated = false;\n",
    "  bool _transformTranslated = false;\n"
    "  PhysicalPoint _pendingTransformDelta = PhysicalPoint.zero;\n"
    "  double _pendingTransformRotation = 0;\n"
    "  bool _transformFrameScheduled = false;\n",
    'transform coalescing fields',
)
text = replace_once(
    text,
    "  Timer? _historyControlsTimer;\n",
    "  Timer? _historyControlsTimer;\n"
    "  Timer? _saveDebounceTimer;\n"
    "  BoardState? _pendingSaveState;\n",
    'save debounce fields',
)
text = regex_once(
    text,
    r"  @override\n  void didChangeDependencies\(\) \{.*?\n  @override\n  void didChangeAppLifecycleState",
    "  @override\n"
    "  void didChangeDependencies() {\n"
    "    super.didChangeDependencies();\n"
    "    if (_orientationLocked || kIsWeb) return;\n"
    "    _orientationLocked = true;\n"
    "    final orientation = MediaQuery.orientationOf(context);\n"
    "    SystemChrome.setPreferredOrientations([\n"
    "      orientation == Orientation.portrait\n"
    "          ? DeviceOrientation.portraitUp\n"
    "          : DeviceOrientation.landscapeLeft,\n"
    "    ]);\n"
    "  }\n\n"
    "  @override\n"
    "  void didChangeAppLifecycleState",
    'remove Safari rotation compensation methods',
)
text = regex_once(
    text,
    r"  @override\n  void didChangeAppLifecycleState\(AppLifecycleState state\) \{.*?\n  \}\n\n  @override\n  void dispose\(\)",
    "  @override\n"
    "  void didChangeAppLifecycleState(AppLifecycleState state) {\n"
    "    if (state == AppLifecycleState.resumed) {\n"
    "      if (!kIsWeb) unawaited(_applyBrightness());\n"
    "      if (kIsWeb &&\n"
    "          defaultTargetPlatform == TargetPlatform.iOS &&\n"
    "          _motionPermissionAttempted) {\n"
    "        _startWebMotionMonitoring();\n"
    "      } else if (!kIsWeb) {\n"
    "        _startFaceDownMonitoring();\n"
    "      }\n"
    "      if (_needsToyTicker) _ensureToyTicker();\n"
    "      return;\n"
    "    }\n\n"
    "    _webMotionTimer?.cancel();\n"
    "    _webMotionTimer = null;\n"
    "    final subscription = _accelerometerSubscription;\n"
    "    _accelerometerSubscription = null;\n"
    "    if (subscription != null) unawaited(subscription.cancel());\n"
    "    _toyTicker?.cancel();\n"
    "    _toyTicker = null;\n"
    "    unawaited(_flushPendingSave());\n"
    "    if (!kIsWeb) {\n"
    "      unawaited(\n"
    "        ScreenBrightness.instance.resetApplicationScreenBrightness(),\n"
    "      );\n"
    "    }\n"
    "  }\n\n"
    "  @override\n"
    "  void dispose()",
    'lifecycle throttling',
)
text = replace_once(
    text,
    "    _webMotionTimer?.cancel();\n    _webOrientationPollTimer?.cancel();\n",
    "    _webMotionTimer?.cancel();\n"
    "    _saveDebounceTimer?.cancel();\n"
    "    unawaited(_flushPendingSave());\n",
    'dispose timers',
)
text = replace_once(
    text,
    "samplingPeriod: const Duration(milliseconds: 140)",
    "samplingPeriod: const Duration(milliseconds: 180)",
    'native accelerometer rate',
)
text = replace_once(
    text,
    "_webMotionTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {",
    "_webMotionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {",
    'web motion rate',
)
text = replace_once(
    text,
    "  ({double width, double height}) _physicalBoardSize() {\n"
    "    final size = _webBoardSize ?? MediaQuery.sizeOf(context);\n"
    "    final padding = _webBoardViewPadding ?? MediaQuery.viewPaddingOf(context);\n",
    "  ({double width, double height}) _physicalBoardSize() {\n"
    "    final size = MediaQuery.sizeOf(context);\n"
    "    final padding = MediaQuery.viewPaddingOf(context);\n",
    'physical board size',
)
text = replace_once(
    text,
    "    final mediaSize = _webBoardSize ?? MediaQuery.sizeOf(context);\n"
    "    final padding = _webBoardViewPadding ?? MediaQuery.viewPaddingOf(context);\n",
    "    final mediaSize = MediaQuery.sizeOf(context);\n"
    "    final padding = MediaQuery.viewPaddingOf(context);\n",
    'snap size',
)
text = replace_once(
    text,
    "      _controller.transformBy(delta, rotationDelta);\n      return;\n",
    "      _queueTransform(delta, rotationDelta);\n      return;\n",
    'coalesce touch transform',
)
text = replace_once(
    text,
    "  void _onScaleEnd(ScaleEndDetails details) {\n"
    "    if (_mouseTransform || _creditsVisible) return;\n"
    "    if (_transformStarted) {\n"
    "      _endTransformWithSnaps();\n",
    "  void _onScaleEnd(ScaleEndDetails details) {\n"
    "    if (_mouseTransform || _creditsVisible) return;\n"
    "    if (_transformStarted) {\n"
    "      _flushQueuedTransform();\n"
    "      _endTransformWithSnaps();\n",
    'flush transform before release',
)
queue_methods = '''  void _queueTransform(PhysicalPoint delta, double rotationDelta) {
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

'''
text = replace_once(
    text,
    "  void _onScaleEnd(ScaleEndDetails details) {\n",
    queue_methods + "  void _onScaleEnd(ScaleEndDetails details) {\n",
    'insert transform queue helpers',
)
text = replace_once(
    text,
    "    _lastRotation = 0;\n    _transformStarted = false;\n    _transformTranslated = false;\n  }\n",
    "    _lastRotation = 0;\n"
    "    _transformStarted = false;\n"
    "    _transformTranslated = false;\n"
    "    _pendingTransformDelta = PhysicalPoint.zero;\n"
    "    _pendingTransformRotation = 0;\n"
    "  }\n",
    'clear queued transform',
)
save_helpers = '''  void _scheduleSave() {
    _pendingSaveState = _controller.state;
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

'''
text = replace_once(
    text,
    "  void _refresh() {\n",
    save_helpers + "  void _refresh() {\n",
    'insert save debounce helpers',
)
text = replace_once(
    text,
    "    _store.save(_controller.state);\n",
    "    _scheduleSave();\n",
    'debounce automatic save',
)
projectile_helper = '''  double _elementBoundingRadiusMm(LightElement element) {
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

'''
text = replace_once(
    text,
    "  ({PhysicalPoint contact, PhysicalPoint normal, double distance})\n  _nearestBoundary",
    projectile_helper +
    "  ({PhysicalPoint contact, PhysicalPoint normal, double distance})\n  _nearestBoundary",
    'projectile broad phase helper',
)
text = replace_once(
    text,
    "              for (final element in _controller.state.elements) {\n"
    "                final boundary = _nearestBoundary(element, position);\n",
    "              for (final element in _controller.state.elements) {\n"
    "                if (!_couldProjectileTouch(\n"
    "                  element,\n"
    "                  position,\n"
    "                  projectile.radiusMm,\n"
    "                )) {\n"
    "                  continue;\n"
    "                }\n"
    "                final boundary = _nearestBoundary(element, position);\n",
    'ricochet broad phase',
)
text = replace_once(
    text,
    "          for (final element in _controller.state.elements) {\n"
    "            if (!_containsPoint(element, position)) continue;\n",
    "          for (final element in _controller.state.elements) {\n"
    "            if (!_couldProjectileTouch(element, position, projectile.radiusMm)) {\n"
    "              continue;\n"
    "            }\n"
    "            if (!_containsPoint(element, position)) continue;\n",
    'projectile broad phase',
)
text = regex_once(
    text,
    r"  void _dismissCreditsAndRecalibrate\(\) \{.*?\n  \}\n\n  Widget _credits\(\)",
    "  void _dismissCreditsAndRecalibrate() {\n"
    "    _faceDownTimer?.cancel();\n"
    "    _faceDownTimer = null;\n"
    "    final sign = _lastDominantZSign;\n"
    "    setState(() {\n"
    "      if (sign != null) _faceUpZSign = sign;\n"
    "      _faceUpCandidateSign = null;\n"
    "      _faceUpStableSamples = 0;\n"
    "      _faceDownLatched = false;\n"
    "      _creditsVisible = false;\n"
    "    });\n"
    "  }\n\n"
    "  Widget _credits()",
    'remove credits rotation recalibration',
)
text = replace_once(
    text,
    "                sideGunAnglesDegrees: _sideGunAnglesDegrees,\n"
    "                sideGunAmmo: _sideGunAmmo,\n",
    "                sideGunAnglesDegrees: List<double>.unmodifiable(\n"
    "                  _sideGunAnglesDegrees,\n"
    "                ),\n"
    "                sideGunAmmo: List<int>.unmodifiable(_sideGunAmmo),\n",
    'snapshot gun painter state',
)
text = regex_once(
    text,
    r"  double _webBoardRotationRadians\(\) \{.*?\n  \}\n\n  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}\n\}\n\nclass _MenuCirclePainter",
    "  @override\n"
    "  Widget build(BuildContext context) => Scaffold(\n"
    "    backgroundColor: Colors.black,\n"
    "    body: _buildBoardSurface(context),\n"
    "  );\n"
    "}\n\n"
    "class _MenuCirclePainter",
    'remove rotated/frozen Safari build',
)
path.write_text(text)

# Serialize actual preference writes. Debouncing above prevents the queue from
# growing during a drag; this guarantees a slow storage write cannot race a
# newer one.
path = Path('lib/application/board_store.dart')
text = path.read_text()
text = replace_once(
    text,
    "class BoardStore {\n",
    "class BoardStore {\n  Future<void> _saveTail = Future<void>.value();\n",
    'save queue field',
)
old_save = '''  Future<void> save(BoardState state) async {
    final prefs = SharedPreferencesAsync();
    final previous = await prefs.getString(_boardKey);
    if (previous != null) {
      await prefs.setString(_backupKey, previous);
    }
    await prefs.setString(_boardKey, jsonEncode(state.toJson()));
  }
'''
new_save = '''  Future<void> save(BoardState state) {
    final encoded = jsonEncode(state.toJson());
    final previousWrite = _saveTail;
    final nextWrite = () async {
      try {
        await previousWrite;
      } on Object {
        // A failed older write must not prevent newer board state from saving.
      }
      final prefs = SharedPreferencesAsync();
      final previous = await prefs.getString(_boardKey);
      if (previous != null) {
        await prefs.setString(_backupKey, previous);
      }
      await prefs.setString(_boardKey, encoded);
    }();
    _saveTail = nextWrite;
    return nextWrite;
  }
'''
text = replace_once(text, old_save, new_save, 'serialized save method')
path.write_text(text)

# Cheap broad-phase rejection before polygon collision work during drags.
path = Path('lib/application/board_controller.dart')
text = path.read_text()
broad_phase = '''  double _boundingRadiusMm(LightElement element) {
    final halfBase = geometry.baseMm(element.size) / 2;
    if (element.pose == PyramidPose.upright) {
      return math.sqrt(halfBase * halfBase * 2);
    }
    final halfLength = geometry.flatLengthMm(element.size) / 2;
    return math.sqrt(halfBase * halfBase + halfLength * halfLength);
  }

  bool _boundingCirclesOverlap(LightElement a, LightElement b) =>
      a.position.distanceTo(b.position) <=
      _boundingRadiusMm(a) + _boundingRadiusMm(b);

'''
text = replace_once(
    text,
    "  BoardState _resolvePushes(BoardState initial, Set<String> movingIds) {\n",
    broad_phase + "  BoardState _resolvePushes(BoardState initial, Set<String> movingIds) {\n",
    'collision broad phase helper',
)
text = replace_once(
    text,
    "          final separation = minimumSeparationVector(\n",
    "          if (!_boundingCirclesOverlap(moving, stationary)) continue;\n"
    "          final separation = minimumSeparationVector(\n",
    'drag broad phase',
)
text = replace_once(
    text,
    "          final overlap = minimumSeparationVector(\n",
    "          if (!_boundingCirclesOverlap(moving, candidate)) continue;\n"
    "          final overlap = minimumSeparationVector(\n",
    'snap broad phase',
)
path.write_text(text)

# Avoid repainting the toy overlay when unrelated parent UI state changes.
path = Path('lib/ui/toy_overlay.dart')
text = path.read_text()
text = replace_once(
    text,
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart';\n",
    'toy foundation import',
)
text = replace_once(
    text,
    "  @override\n  bool shouldRepaint(covariant ToyOverlayPainter oldDelegate) => true;\n",
    '''  @override
  bool shouldRepaint(covariant ToyOverlayPainter oldDelegate) =>
      oldDelegate.logicalPixelsPerMm != logicalPixelsPerMm ||
      oldDelegate.geometry != geometry ||
      !listEquals(oldDelegate.elements, elements) ||
      oldDelegate.ghostTrailsVisible != ghostTrailsVisible ||
      (ghostTrailsVisible && oldDelegate.ghostTrails != ghostTrails) ||
      oldDelegate.eventZoneCenter != eventZoneCenter ||
      oldDelegate.eventZoneRadiusMm != eventZoneRadiusMm ||
      oldDelegate.eventZoneProgress != eventZoneProgress ||
      oldDelegate.eventZoneDismiss != eventZoneDismiss ||
      oldDelegate.turnTimerProgress != turnTimerProgress ||
      oldDelegate.radarAngleDegrees != radarAngleDegrees ||
      oldDelegate.redSweepY != redSweepY ||
      oldDelegate.dieValue != dieValue ||
      oldDelegate.dieRollPhase != dieRollPhase ||
      oldDelegate.dieRollProgress != dieRollProgress ||
      oldDelegate.diePressed != diePressed ||
      !listEquals(oldDelegate.projectiles, projectiles) ||
      !listEquals(oldDelegate.impacts, impacts) ||
      oldDelegate.sideGunsVisible != sideGunsVisible ||
      !listEquals(oldDelegate.sideGunAnglesDegrees, sideGunAnglesDegrees) ||
      !listEquals(oldDelegate.sideGunAmmo, sideGunAmmo) ||
      oldDelegate.cornerGunsVisible != cornerGunsVisible ||
      !listEquals(oldDelegate.constellation, constellation);
''',
    'toy shouldRepaint',
)
path.write_text(text)

# The dice painter should repaint while its animation actually changes, not on
# every parent rebuild or position-only change.
path = Path('lib/ui/dice_bubble.dart')
text = path.read_text()
text = replace_once(
    text,
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart';\n",
    'dice foundation import',
)
text = replace_once(
    text,
    "                      choices: selected,\n"
    "                      faces: _faces,\n"
    "                      plans: _plans,\n",
    "                      choices: List<ArcadeDieChoice>.unmodifiable(selected),\n"
    "                      faces: Map<String, int>.unmodifiable(_faces),\n"
    "                      plans: Map<String, _SpinPlan>.unmodifiable(_plans),\n",
    'dice painter snapshots',
)
text = replace_once(
    text,
    "  @override\n  bool shouldRepaint(covariant _DiceBubblePainter oldDelegate) => true;\n",
    '''  @override
  bool shouldRepaint(covariant _DiceBubblePainter oldDelegate) =>
      !listEquals(oldDelegate.choices, choices) ||
      !mapEquals(oldDelegate.faces, faces) ||
      !mapEquals(oldDelegate.plans, plans) ||
      oldDelegate.progress != progress ||
      oldDelegate.pressed != pressed;
''',
    'dice shouldRepaint',
)
path.write_text(text)

# Remove the discarded iOS web rotation workaround at its JavaScript source.
path = Path('web/index.html')
text = path.read_text()
text = regex_once(
    text,
    r"    const lighthouseOrientationState = \{ angle: 0 \};\n",
    '',
    'orientation state',
)
text = regex_once(
    text,
    r"\n    function lighthouseNormalizeQuarterTurn\(angle\) \{.*?\n    function lighthouseInstallMotionListener\(\)",
    "\n    function lighthouseInstallMotionListener()",
    'orientation helper functions',
)
text = regex_once(
    text,
    r"\n    lighthouseUpdateOrientation\(\);.*?\n    window\.lighthouseRequestMotionPermission",
    "\n    window.lighthouseRequestMotionPermission",
    'orientation listeners and getter',
)
path.write_text(text)

# These files only existed for the removed Safari rotation workaround.
for obsolete in [
    'lib/platform/web_orientation.dart',
    'lib/platform/web_orientation_stub.dart',
    'lib/platform/web_orientation_web.dart',
]:
    Path(obsolete).unlink()

print('Performance revision applied successfully.')
