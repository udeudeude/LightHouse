from pathlib import Path
import re


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing anchor: {label}')
    return text.replace(old, new, 1)


def sub_once(text, pattern, repl, label, flags=re.S):
    out, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        raise SystemExit(f'pattern {label}: expected 1, got {n}')
    return out


# ---------------- board_screen_next.dart ----------------
p = Path('lib/ui/board_screen_next.dart')
s = p.read_text()
s = replace_once(
    s,
    "import 'dart:async';\nimport 'dart:math' as math;",
    "import 'dart:async';\nimport 'dart:convert';\nimport 'dart:math' as math;\nimport 'dart:typed_data';",
    'dart imports',
)
s = replace_once(
    s,
    "import 'package:flutter/foundation.dart';",
    "import 'package:file_picker/file_picker.dart';\nimport 'package:file_saver/file_saver.dart';\nimport 'package:flutter/foundation.dart';",
    'package imports',
)
s = replace_once(
    s,
    "import '../domain/light_element.dart';",
    "import '../domain/light_element.dart';\nimport '../domain/light_structure.dart';",
    'light_structure import',
)

enum_block = r'''enum _ToyKind {
  lightLottery('Light Lottery', Icons.auto_awesome, true),
  entropy('Entropy Delete', Icons.hourglass_bottom, true),
  ghostPaths('Ghost Paths', Icons.timeline, false),
  eventZone('Random Event Zone', Icons.adjust, false),
  turnTimer('Turn Timer', Icons.timer_outlined, false),
  breathing('Breathing', Icons.air, false),
  nestCycle('Nest Cycle', Icons.layers, false),
  radar('Radar', Icons.track_changes, false),
  redSweep('Red Sweep', Icons.swap_vert, false),
  wireDie('Wireframe d6', Icons.casino, false),
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

  String get preferenceKey => 'lighthouse.toy.$name.visible.v3';
}
'''
s = sub_once(s, r'enum _ToyKind \{.*?\n\}\n\nclass BoardScreenNext', enum_block + '\nclass BoardScreenNext', 'toy enum')

s = replace_once(
    s,
    "  static const double _minimumLineGestureMm = 1.5;",
    "  static const double _minimumLineGestureMm = 1.5;\n  static const MethodChannel _displayChannel = MethodChannel('lighthouse/display');",
    'display channel',
)

s = replace_once(
    s,
    "  DateTime? _turnTimerEndsAt;\n  double? _turnTimerProgress;\n  int _dieValue = 1;\n  double _dieRollPhase = 0;\n  DateTime? _dieRollEndsAt;",
    "  DateTime? _turnTimerEndsAt;\n  double? _turnTimerProgress;\n  double _turnTimerDurationSeconds = 30;\n  double _turnTimerActiveDurationSeconds = 30;\n  double _timerLongPressStartDuration = 30;\n  bool _timerNeedleVisible = false;\n  int _dieValue = 1;\n  double _dieRollPhase = 0;\n  double _dieRollProgress = 1;\n  DateTime? _dieRollEndsAt;",
    'timer die state',
)
s = replace_once(
    s,
    "  double _lastGunShotClock = -10;\n  List<PhysicalPoint> _constellation = const [];\n  double? _rouletteAngleDegrees;",
    "  double _lastGunShotClock = -10;\n  final List<double> _sideGunAnglesDegrees = [0, 180, 90, 270];\n  List<PhysicalPoint> _constellation = const [];",
    'gun state',
)
s = replace_once(
    s,
    "  bool _motionPermissionAttempted = false;",
    "  bool _motionPermissionAttempted = false;\n  bool _roundedTriangleTips = false;\n  bool _historyControlsVisible = false;\n  Timer? _historyControlsTimer;",
    'ui prefs state',
)
s = replace_once(
    s,
    "    _desktopScrollEndTimer?.cancel();\n    _entropyTimer?.cancel();",
    "    _desktopScrollEndTimer?.cancel();\n    _historyControlsTimer?.cancel();\n    _entropyTimer?.cancel();",
    'dispose history timer',
)

s = replace_once(
    s,
    "      _gridSnapEnabled =\n          preferences.getBool('lighthouse.gridSnapEnabled.v1') ?? false;",
    "      _gridSnapEnabled =\n          preferences.getBool('lighthouse.gridSnapEnabled.v1') ?? false;\n      _roundedTriangleTips =\n          preferences.getBool('lighthouse.roundedTriangleTips.v1') ?? false;\n      _turnTimerDurationSeconds =\n          (preferences.getDouble('lighthouse.turnTimerSeconds.v1') ?? 30)\n              .clamp(10, 300)\n              .toDouble();\n      _turnTimerActiveDurationSeconds = _turnTimerDurationSeconds;",
    'load prefs additions',
)

anchor = "  Future<void> _toggleToyVisibility(_ToyKind toy) async {"
insert = r'''  Future<void> _toggleRoundedTriangleTips() async {
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

'''
s = replace_once(s, anchor, insert + anchor, 'preference methods insertion')

continuous_region = r'''  static const Set<_ToyKind> _continuousLightToys = {
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
      case _ToyKind.sideGuns:
        _projectiles = _projectiles.where((p) => p.ricochet).toList();
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
        _rollWireDie();
      case _ToyKind.sideGuns:
        _toggleSideGuns();
      case _ToyKind.cornerRicochet:
        _launchCornerRicochets();
      case _ToyKind.hotPotato:
        _runHotPotato();
      case _ToyKind.constellationDraw:
        _drawConstellation();
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
      _ToyKind.wireDie => _dieRollEndsAt != null || _dieRollProgress >= 1,
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

'''
s = sub_once(
    s,
    r'  static const Set<_ToyKind> _continuousLightToys = \{.*?\n  \}\n\n  \(\{double width, double height\}\) _physicalBoardSize\(\)',
    continuous_region + '  ({double width, double height}) _physicalBoardSize()',
    'continuous toy region',
)

s = sub_once(
    s,
    r'''  void _stopContinuousLightToys\(\) \{.*?\n  void _toggleGhostPaths\(\) \{''',
    r'''  void _toggleContinuousLightToy(_ToyKind toy) {
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

  void _toggleGhostPaths() {''',
    'continuous toggle',
)

s = sub_once(
    s,
    r'''  void _startTurnTimer\(\) \{.*?\n  void _rollWireDie\(\) \{''',
    r'''  void _startTurnTimer() {
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
    final multiplier = math.pow(2, -details.offsetFromOrigin.dx / 78).toDouble();
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

  void _rollWireDie() {''',
    'timer adjustment',
)
s = replace_once(
    s,
    "    _dieRollEndsAt = DateTime.now().add(const Duration(milliseconds: 900));\n    _dieValue = 1 + _random.nextInt(6);\n    _dieRollPhase = 0;",
    "    _dieRollEndsAt = DateTime.now().add(const Duration(milliseconds: 1300));\n    _dieValue = 1 + _random.nextInt(6);\n    _dieRollPhase = 0;\n    _dieRollProgress = 0;",
    'die roll start',
)

s = sub_once(
    s,
    r'''  void _spawnSideVolley\(\) \{.*?\n  void _launchCornerRicochets\(\) \{''',
    r'''  PhysicalPoint _velocityForDegrees(double degrees, double speed) {
    final radians = degrees * math.pi / 180;
    return PhysicalPoint(math.cos(radians) * speed, math.sin(radians) * speed);
  }

  void _spawnSideVolley() {
    final table = _physicalBoardSize();
    const speed = 85.0;
    final inset = 8 / widget.logicalPixelsPerMm;
    final centerX = table.width / 2;
    final centerY = table.height / 2;
    _projectiles = [
      ..._projectiles,
      ToyProjectile(
        position: PhysicalPoint(inset, centerY),
        velocity: _velocityForDegrees(_sideGunAnglesDegrees[0], speed),
        radiusMm: 0.8,
      ),
      ToyProjectile(
        position: PhysicalPoint(table.width - inset, centerY),
        velocity: _velocityForDegrees(_sideGunAnglesDegrees[1], speed),
        radiusMm: 0.8,
      ),
      ToyProjectile(
        position: PhysicalPoint(centerX, inset),
        velocity: _velocityForDegrees(_sideGunAnglesDegrees[2], speed),
        radiusMm: 0.8,
      ),
      ToyProjectile(
        position: PhysicalPoint(centerX, table.height - inset),
        velocity: _velocityForDegrees(_sideGunAnglesDegrees[3], speed),
        radiusMm: 0.8,
      ),
    ];
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
        base + offset.clamp(-72, 72),
      );
    });
  }

  void _launchCornerRicochets() {''',
    'side gun aiming',
)

# Timer and die ticking.
s = replace_once(
    s,
    "        _turnTimerProgress = (remaining / 30000).clamp(0, 1).toDouble();",
    "        _turnTimerProgress =\n            (remaining / (_turnTimerActiveDurationSeconds * 1000))\n                .clamp(0, 1)\n                .toDouble();",
    'timer denominator',
)
s = sub_once(
    s,
    r'''    final dieEnds = _dieRollEndsAt;\n    if \(dieEnds != null\) \{.*?\n    \}\n\n    _tickProjectiles''',
    r'''    final dieEnds = _dieRollEndsAt;
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

    _tickProjectiles''',
    'die tick',
)

continuous_update = r'''  void _updateContinuousLighting() {
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
      final phase = (_toyClock * 0.30) % 2;
      _redSweepDirection = phase <= 1 ? 1 : -1;
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

'''
s = sub_once(
    s,
    r'  void _updateContinuousLighting\(\) \{.*?\n  double _breathOpacity',
    continuous_update + '  double _breathOpacity',
    'continuous lighting rewrite',
)
s = sub_once(
    s,
    r'''  double _radarOpacity\(.*?\n  double _heartbeatOpacity''',
    r'''  double _radarOpacity(
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

  double _heartbeatOpacity''',
    'radar opacity and sweep removal',
)

# Replace ricochet collision integrator with sub-stepped exact boundary response.
projectiles = r'''  ({PhysicalPoint contact, PhysicalPoint normal, double distance})
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
          : (((point.xMm - a.xMm) * ex + (point.yMm - a.yMm) * ey) /
                    length2)
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
    return (
      contact: bestContact,
      normal: bestOutward,
      distance: bestDistance,
    );
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
        position = position + PhysicalPoint(
          velocity.xMm * stepDt,
          velocity.yMm * stepDt,
        );

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
                if (!inside && boundary.distance > projectile.radiusMm) continue;
                final normal = boundary.normal;
                final dot = velocity.xMm * normal.xMm + velocity.yMm * normal.yMm;
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

'''
s = sub_once(
    s,
    r'  void _tickProjectiles\(double dt\) \{.*?\n  Future<void> _runHotPotato',
    projectiles + '  Future<void> _runHotPotato',
    'projectile integrator',
)

hot_potato = r'''  Future<void> _runHotPotato() async {
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
        final pool = fresh.isNotEmpty ? fresh.take(2).toList() : available.take(2).toList();
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

'''
s = sub_once(
    s,
    r'  Future<void> _runHotPotato\(\) async \{.*?\n  Future<void> _runComet',
    hot_potato + '  Future<void> _runComet',
    'hot potato rewrite',
)
# Remove Comet + Infection methods.
s = sub_once(
    s,
    r'  Future<void> _runComet\(\) async \{.*?\n  void _drawConstellation',
    '  void _drawConstellation',
    'remove comet infection',
)
# Remove Roulette + False Endings methods.
s = sub_once(
    s,
    r'  Future<void> _runRoulette\(\) async \{.*?\n  PhysicalPoint\? _nearestUnderlaySnapPoint',
    '  PhysicalPoint? _nearestUnderlaySnapPoint',
    'remove roulette false ending',
)

# File import/export now use actual files.
s = sub_once(
    s,
    r'''  Future<void> _exportBoard\(\) async \{.*?\n  Future<void> _renameBoard''',
    r'''  Future<void> _exportTableFile() async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Table JSON saved.')),
    );
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

  Future<void> _renameBoard''',
    'file import export',
)

# System settings / brightness dialogs.
s = sub_once(
    s,
    r'''  Future<void> _showOrientationLockInfo\(\) async \{.*?\n  Future<void> _showCalibrationCheck''',
    r'''  Future<void> _openAndroidDisplaySettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _displayChannel.invokeMethod<bool>('openDisplaySettings');
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Android display settings.')),
      );
    }
  }

  Future<void> _showOrientationLockInfo() async {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
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
                await ScreenBrightness.instance.resetApplicationScreenBrightness();
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

  Future<void> _showCalibrationCheck''',
    'settings dialogs',
)

# Calibration verification square stays square and is filled.
s = sub_once(
    s,
    r'''            const Text\('A Large upright pyramid should fit this square:'\),\n            const SizedBox\(height: 12\),\n            Container\(.*?\n            \),\n            const SizedBox\(height: 12\),''',
    r'''            const Text('A Large upright pyramid should fit this square:'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: largeBase * pixelsPerMm,
                height: largeBase * pixelsPerMm,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),''',
    'calibration check square',
)

# Compact menus replace the large draggable bottom sheet.
menu_block = r'''  RelativeRect _compactMenuPosition() {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final left = padding.left + 8;
    final bottom = padding.bottom + 50;
    return RelativeRect.fromLTRB(
      left,
      size.height - bottom,
      math.max(0, size.width - left - 1),
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
      _compactMenuItem('import', Icons.file_open_outlined, 'Import Table JSON…'),
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
      _compactMenuItem('undo', Icons.undo, 'Undo', enabled: _controller.canUndo),
      _compactMenuItem('redo', Icons.redo, 'Redo', enabled: _controller.canRedo),
      _compactMenuItem('left', Icons.rotate_left, 'Rotate Left 15°'),
      _compactMenuItem('right', Icons.rotate_right, 'Rotate Right 15°'),
      _compactMenuItem('orientation', Icons.explore_outlined, 'Set Orientation'),
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

  Future<void> _showOrientationMenu() async {
    const angles = <double>[0, 45, 90, 135, 180, 225, 270, 315];
    final choice = await _showCompactMenu([
      for (final angle in angles)
        _compactMenuItem(
          'a${angle.toInt()}',
          Icons.navigation_outlined,
          '${angle.toInt()}°',
        ),
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

  Future<void> _showUnderlayMenu() async {
    final choice = await _showCompactMenu([
      _compactMenuItem(
        'snap',
        Icons.grid_4x4,
        'Snap pieces to underlay',
        checked: _gridSnapEnabled,
      ),
      for (final underlay in BoardUnderlay.values)
        _compactMenuItem(
          'u${underlay.index}',
          Icons.grid_on,
          underlay.menuLabel,
          checked: _controller.state.underlay == underlay,
        ),
    ]);
    if (!mounted || choice == null) return;
    if (choice == 'snap') {
      await _toggleGridSnap();
    } else {
      _selectUnderlay(BoardUnderlay.values[int.parse(choice.substring(1))]);
    }
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
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            Future<void>.microtask(_showUnderlayMenu);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                            child: Row(
                              children: [
                                Icon(Icons.grid_on, size: 20),
                                SizedBox(width: 9),
                                Expanded(child: Text('Underlays')),
                                Icon(Icons.chevron_right, size: 19),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 8),
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
                                    if (dialogContext.mounted) setDialogState(() {});
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (_toyVisible[toy] ?? toy.defaultVisible)
                                          ? Colors.white.withValues(alpha: 0.13)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: (_toyVisible[toy] ?? toy.defaultVisible)
                                            ? Colors.white38
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Icon(
                                      _toyIcon(toy),
                                      size: 21,
                                      color: (_toyVisible[toy] ?? toy.defaultVisible)
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
      _compactMenuItem('orientation', Icons.screen_lock_rotation, 'Orientation Lock'),
      _compactMenuItem(
        'round',
        Icons.change_history,
        'Rounded Triangle Tips',
        checked: _roundedTriangleTips,
      ),
      if (kIsWeb) _compactMenuItem('fullscreen', Icons.fullscreen, 'Full-screen'),
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

'''
s = sub_once(
    s,
    r'  Future<void> _showMainMenu\(\) async \{.*?\n  Widget _instructionsPane\(\)',
    menu_block + '  Widget _instructionsPane()',
    'compact menu rewrite',
)

# User-facing table terminology in this screen.
for old, new in [
    ("'Board name'", "'Table name'"),
    ("'Board saved.'", "'Table saved.'"),
    ("'No saved boards yet.'", "'No saved tables yet.'"),
    ("'Delete saved board'", "'Delete saved table'"),
    ("'Board brightness'", "'Table brightness'"),
    ("'freezes the board", "'freezes the table"),
    ("'LightHouse locks the board", "'LightHouse locks the table"),
    ("'Menu > Board > Underlays > Snap pieces to underlay'", "'Menu > Toys > Underlays > Snap pieces to underlay'"),
]:
    s = s.replace(old, new)

# Toy controls: same icons as menu, entropy hourglass states, timer long-press needle.
toy_control = r'''  Widget _toyControl(_ToyKind toy) {
    final active = _toyIsActive(toy);
    if (toy == _ToyKind.turnTimer) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Semantics(
              button: true,
              label: 'Turn Timer. Hold and drag left or right to adjust speed.',
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

'''
s = sub_once(
    s,
    r'  Widget _toyControl\(_ToyKind toy\) \{.*?\n  Widget _toyControls\(\)',
    toy_control + '  Widget _toyControls()',
    'toy controls',
)

# Add side gun drag hit areas and on-screen history arrows before credits.
insert_before_credits = r'''  Widget _gunAimHandle(int index, Alignment alignment) => Align(
    alignment: alignment,
    child: SizedBox(
      width: 48,
      height: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanDown: (details) => _aimGunFromLocal(index, details.localPosition),
        onPanUpdate: (details) => _aimGunFromLocal(index, details.localPosition),
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

'''
s = replace_once(s, '  Widget _credits() => GestureDetector(', insert_before_credits + '  Widget _credits() => GestureDetector(', 'history gun handles')

# Painter constructor parameters and overlay parameters.
s = replace_once(
    s,
    "                  elementOpacities: _effectOpacities,\n                  burstCenter: _burstCenter,",
    "                  elementOpacities: _paintElementOpacities,\n                  burstCenter: _burstCenter,\n                  triangleBouncePhase:\n                      _activeToys.contains(_ToyKind.triangleBounce)\n                      ? 0.5 - 0.5 * math.cos(_toyClock * math.pi * 0.9)\n                      : null,\n                  squareChasePhase:\n                      _activeToys.contains(_ToyKind.squareChase)\n                      ? (_toyClock * 0.24) % 1\n                      : null,\n                  roundTriangleTips: _roundedTriangleTips,",
    'board painter toy args',
)
s = replace_once(
    s,
    "                dieRollPhase: _dieRollPhase,\n                projectiles: _projectiles,",
    "                dieRollPhase: _dieRollPhase,\n                dieRollProgress: _dieRollProgress,\n                projectiles: _projectiles,",
    'die progress overlay arg',
)
s = replace_once(
    s,
    "                sideGunsVisible: _activeToys.contains(_ToyKind.sideGuns),\n                cornerGunsVisible:",
    "                sideGunsVisible: _activeToys.contains(_ToyKind.sideGuns),\n                sideGunAnglesDegrees: _sideGunAnglesDegrees,\n                cornerGunsVisible:",
    'gun angles overlay arg',
)
s = re.sub(r"\n\s*rouletteAngleDegrees: _rouletteAngleDegrees,", '', s)

# Put aim handles above painter and menu + transient undo/redo compactly.
s = replace_once(
    s,
    "        SafeArea(\n          child: Align(\n            alignment: Alignment.bottomLeft,\n            child: Padding(padding: const EdgeInsets.all(8), child: _menu()),\n          ),\n        ),",
    "        if (_activeToys.contains(_ToyKind.sideGuns))\n          Padding(padding: safePadding, child: _sideGunAimHandles()),\n        SafeArea(\n          child: Align(\n            alignment: Alignment.bottomLeft,\n            child: Padding(\n              padding: const EdgeInsets.all(8),\n              child: Row(\n                mainAxisSize: MainAxisSize.min,\n                children: [_menu(), _historyControls()],\n              ),\n            ),\n          ),\n        ),",
    'history controls on screen',
)

# Instructions now refer to table and compact menu paths.
s = s.replace("'Tap a footprint first.'", "'Tap a footprint first.'")
s = s.replace("'Enable in Menu > Toys, then tap the starburst button'", "'Enable in Menu > Toys, then tap the matching starburst button'")
s = s.replace("'Enable in Menu > Toys, then toggle the deletion control'", "'Enable in Menu > Toys, then tap the matching hourglass control'")

# Replace obsolete entropy painter with timer needle painter.
s = sub_once(
    s,
    r'class _EntropyControlPainter extends CustomPainter \{.*\Z',
    r'''class _TimerNeedlePainter extends CustomPainter {
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
    final logSpeed = (math.log(30 / durationSeconds) / math.ln2).clamp(-1.5, 1.5);
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
''',
    'timer needle painter',
)
p.write_text(s)

# ---------------- toy_overlay.dart: full replacement ----------------
toy_overlay = r'''import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/light_element.dart';
import '../domain/physical_point.dart';
import '../domain/pyramid_geometry.dart';

class ToyProjectile {
  const ToyProjectile({
    required this.position,
    required this.velocity,
    required this.radiusMm,
    this.ricochet = false,
    this.edgeHits = 0,
    this.escaping = false,
  });

  final PhysicalPoint position;
  final PhysicalPoint velocity;
  final double radiusMm;
  final bool ricochet;
  final int edgeHits;
  final bool escaping;

  ToyProjectile copyWith({
    PhysicalPoint? position,
    PhysicalPoint? velocity,
    int? edgeHits,
    bool? escaping,
  }) => ToyProjectile(
    position: position ?? this.position,
    velocity: velocity ?? this.velocity,
    radiusMm: radiusMm,
    ricochet: ricochet,
    edgeHits: edgeHits ?? this.edgeHits,
    escaping: escaping ?? this.escaping,
  );
}

class ToyImpact {
  const ToyImpact({required this.position, required this.lifeSeconds});
  final PhysicalPoint position;
  final double lifeSeconds;

  ToyImpact copyWith({double? lifeSeconds}) => ToyImpact(
    position: position,
    lifeSeconds: lifeSeconds ?? this.lifeSeconds,
  );
}

class _V3 {
  const _V3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  _V3 operator +(_V3 other) => _V3(x + other.x, y + other.y, z + other.z);
  _V3 scale(double amount) => _V3(x * amount, y * amount, z * amount);
}

class ToyOverlayPainter extends CustomPainter {
  const ToyOverlayPainter({
    required this.logicalPixelsPerMm,
    required this.geometry,
    required this.elements,
    required this.ghostTrails,
    required this.ghostTrailsVisible,
    required this.eventZoneCenter,
    required this.eventZoneRadiusMm,
    required this.eventZoneProgress,
    required this.eventZoneDismiss,
    required this.turnTimerProgress,
    required this.radarAngleDegrees,
    required this.redSweepY,
    required this.dieValue,
    required this.dieRollPhase,
    required this.dieRollProgress,
    required this.projectiles,
    required this.impacts,
    required this.sideGunsVisible,
    required this.sideGunAnglesDegrees,
    required this.cornerGunsVisible,
    required this.constellation,
  });

  final double logicalPixelsPerMm;
  final PyramidGeometryProfile geometry;
  final List<LightElement> elements;
  final Map<String, List<PhysicalPoint>> ghostTrails;
  final bool ghostTrailsVisible;
  final PhysicalPoint? eventZoneCenter;
  final double? eventZoneRadiusMm;
  final double? eventZoneProgress;
  final double eventZoneDismiss;
  final double? turnTimerProgress;
  final double? radarAngleDegrees;
  final double? redSweepY;
  final int? dieValue;
  final double dieRollPhase;
  final double dieRollProgress;
  final List<ToyProjectile> projectiles;
  final List<ToyImpact> impacts;
  final bool sideGunsVisible;
  final List<double> sideGunAnglesDegrees;
  final bool cornerGunsVisible;
  final List<PhysicalPoint> constellation;

  Offset _px(PhysicalPoint point) =>
      Offset(point.xMm * logicalPixelsPerMm, point.yMm * logicalPixelsPerMm);

  @override
  void paint(Canvas canvas, Size size) {
    _paintGhostTrails(canvas);
    _paintEventZone(canvas);
    _paintTurnTimer(canvas, size);
    _paintRadar(canvas, size);
    _paintRedSweep(canvas, size);
    _paintWireDie(canvas, size);
    _paintGuns(canvas, size);
    _paintProjectiles(canvas);
    _paintImpacts(canvas);
    _paintConstellation(canvas);
  }

  void _paintGhostTrails(Canvas canvas) {
    if (!ghostTrailsVisible) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.26)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final points in ghostTrails.values) {
      if (points.length < 2) continue;
      final first = _px(points.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in points.skip(1)) {
        final o = _px(point);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
      for (var i = 0; i < points.length; i += 5) {
        canvas.drawCircle(_px(points[i]), 1.6, paint);
      }
    }
  }

  void _paintEventZone(Canvas canvas) {
    final center = eventZoneCenter;
    final radiusMm = eventZoneRadiusMm;
    final progress = eventZoneProgress;
    if (center == null || radiusMm == null || progress == null) return;
    final c = _px(center);
    final dismiss = eventZoneDismiss.clamp(0, 1).toDouble();
    final radius = radiusMm * logicalPixelsPerMm * (1 - dismiss * 0.18);
    final alpha = 1 - dismiss;
    canvas.drawCircle(
      c,
      radius,
      Paint()..color = Colors.white.withValues(alpha: 0.08 * alpha),
    );
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.70 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, radius, ring);

    // A fixed black gap travels counter-clockwise around the otherwise intact
    // ring. The amount of black never grows with elapsed time.
    final elapsed = 1 - progress.clamp(0, 1).toDouble();
    const gap = math.pi / 8;
    final centerAngle = -math.pi / 2 - math.pi * 2 * elapsed;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      centerAngle - gap / 2,
      gap,
      false,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.butt,
    );

    if (dismiss > 0) {
      final shard = Paint()
        ..color = Colors.white.withValues(alpha: (1 - dismiss) * 0.65)
        ..strokeWidth = 1.5;
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + dismiss * 0.45;
        final inner = radius * (0.65 + dismiss * 0.15);
        final outer = radius * (0.90 + dismiss * 0.35);
        canvas.drawLine(
          Offset(c.dx + math.cos(a) * inner, c.dy + math.sin(a) * inner),
          Offset(c.dx + math.cos(a) * outer, c.dy + math.sin(a) * outer),
          shard,
        );
      }
    }
  }

  void _paintTurnTimer(Canvas canvas, Size size) {
    final progress = turnTimerProgress;
    if (progress == null) return;
    final inset = math.max(19.0, logicalPixelsPerMm * 4.5);
    final rect = Rect.fromLTWH(
      inset,
      inset,
      math.max(1, size.width - inset * 2),
      math.max(1, size.height - inset * 2),
    );
    final path = Path()..addRect(rect);
    final metric = path.computeMetrics().first;
    final length = metric.length * progress.clamp(0, 1).toDouble();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      metric.extractPath(0, length),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.square,
    );
  }

  void _paintRadar(Canvas canvas, Size size) {
    final degrees = radarAngleDegrees;
    if (degrees == null) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.sqrt(size.width * size.width + size.height * size.height);
    // A stack of fading rays gives a phosphor-like radar persistence trail.
    for (var i = 12; i >= 0; i -= 1) {
      final radians = (degrees - i * 2.4) * math.pi / 180;
      final alpha = 0.03 + (1 - i / 12) * 0.72;
      final end = Offset(
        center.dx + math.cos(radians) * radius,
        center.dy + math.sin(radians) * radius,
      );
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = const Color(0xFF35FF67).withValues(alpha: alpha)
          ..strokeWidth = i == 0 ? 1.5 : 1.1,
      );
    }
  }

  void _paintRedSweep(Canvas canvas, Size size) {
    final y = redSweepY;
    if (y == null) return;
    canvas.drawLine(
      Offset(0, size.height * y),
      Offset(size.width, size.height * y),
      Paint()
        ..color = const Color(0xFFFF3030).withValues(alpha: 0.82)
        ..strokeWidth = 1.5,
    );
  }

  _V3 _rotate(_V3 p, double rx, double ry, double rz) {
    final cx = math.cos(rx);
    final sx = math.sin(rx);
    final cy = math.cos(ry);
    final sy = math.sin(ry);
    final cz = math.cos(rz);
    final sz = math.sin(rz);
    var x = p.x;
    var y = p.y * cx - p.z * sx;
    var z = p.y * sx + p.z * cx;
    final x2 = x * cy + z * sy;
    final z2 = -x * sy + z * cy;
    x = x2;
    z = z2;
    return _V3(x * cz - y * sz, x * sz + y * cz, z);
  }

  Offset _project3(_V3 p, Offset center, double scale) {
    const camera = 4.6;
    final perspective = camera / (camera - p.z);
    return Offset(
      center.dx + p.x * scale * perspective,
      center.dy + p.y * scale * perspective,
    );
  }

  ({double rx, double ry}) _dieTargetRotation(int value) => switch (value) {
    1 => (rx: 0, ry: 0),
    2 => (rx: -math.pi / 2, ry: 0),
    3 => (rx: 0, ry: -math.pi / 2),
    4 => (rx: 0, ry: math.pi / 2),
    5 => (rx: math.pi / 2, ry: 0),
    _ => (rx: 0, ry: math.pi),
  };

  List<Offset> _pipPattern(int value) {
    const a = 0.46;
    const b = 0.0;
    return switch (value) {
      1 => const [Offset(b, b)],
      2 => const [Offset(-a, -a), Offset(a, a)],
      3 => const [Offset(-a, -a), Offset(b, b), Offset(a, a)],
      4 => const [Offset(-a, -a), Offset(a, -a), Offset(-a, a), Offset(a, a)],
      5 => const [
        Offset(-a, -a), Offset(a, -a), Offset(b, b), Offset(-a, a), Offset(a, a)
      ],
      _ => const [
        Offset(-a, -a), Offset(-a, b), Offset(-a, a),
        Offset(a, -a), Offset(a, b), Offset(a, a)
      ],
    };
  }

  void _paintWireDie(Canvas canvas, Size size) {
    final value = dieValue;
    if (value == null) return;
    final center = Offset(size.width / 2, size.height / 2);
    final scale = math.min(size.width, size.height) * 0.055;
    final target = _dieTargetRotation(value);
    final eased = 1 - math.pow(1 - dieRollProgress.clamp(0, 1), 3).toDouble();
    final residual = 1 - eased;
    final rx = target.rx + dieRollPhase * 1.10 * residual;
    final ry = target.ry + dieRollPhase * 0.87 * residual;
    final rz = dieRollPhase * 0.61 * residual;

    const vertices = <_V3>[
      _V3(-1, -1, -1), _V3(1, -1, -1), _V3(1, 1, -1), _V3(-1, 1, -1),
      _V3(-1, -1, 1), _V3(1, -1, 1), _V3(1, 1, 1), _V3(-1, 1, 1),
    ];
    const edges = <(int, int)>[
      (0, 1), (1, 2), (2, 3), (3, 0),
      (4, 5), (5, 6), (6, 7), (7, 4),
      (0, 4), (1, 5), (2, 6), (3, 7),
    ];
    final projected = [
      for (final v in vertices) _project3(_rotate(v, rx, ry, rz), center, scale),
    ];
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.76)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45;
    for (final edge in edges) {
      canvas.drawLine(projected[edge.$1], projected[edge.$2], line);
    }

    const faces = <(int, _V3, _V3, _V3)>[
      (1, _V3(0, 0, 1), _V3(1, 0, 0), _V3(0, 1, 0)),
      (6, _V3(0, 0, -1), _V3(-1, 0, 0), _V3(0, 1, 0)),
      (2, _V3(0, -1, 0), _V3(1, 0, 0), _V3(0, 0, 1)),
      (5, _V3(0, 1, 0), _V3(1, 0, 0), _V3(0, 0, -1)),
      (3, _V3(1, 0, 0), _V3(0, 0, -1), _V3(0, 1, 0)),
      (4, _V3(-1, 0, 0), _V3(0, 0, 1), _V3(0, 1, 0)),
    ];
    for (final face in faces) {
      final normal = _rotate(face.$2, rx, ry, rz);
      if (normal.z <= 0.08) continue;
      final opacity = (0.25 + normal.z.abs() * 0.7).clamp(0.25, 0.95).toDouble();
      for (final pip in _pipPattern(face.$1)) {
        final local = face.$2.scale(1.015) + face.$3.scale(pip.dx) + face.$4.scale(pip.dy);
        final point = _project3(_rotate(local, rx, ry, rz), center, scale);
        canvas.drawCircle(
          point,
          math.max(1.1, scale * 0.075),
          Paint()
            ..color = Colors.white.withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  void _paintGun(Canvas canvas, Offset center, double angleDegrees) {
    final radians = angleDegrees * math.pi / 180;
    final direction = Offset(math.cos(radians), math.sin(radians));
    final normal = Offset(-direction.dy, direction.dx);
    final body = Path()
      ..moveTo(center.dx + normal.dx * 3.2, center.dy + normal.dy * 3.2)
      ..lineTo(center.dx - normal.dx * 3.2, center.dy - normal.dy * 3.2)
      ..lineTo(
        center.dx + direction.dx * 7 - normal.dx * 2.1,
        center.dy + direction.dy * 7 - normal.dy * 2.1,
      )
      ..lineTo(
        center.dx + direction.dx * 7 + normal.dx * 2.1,
        center.dy + direction.dy * 7 + normal.dy * 2.1,
      )
      ..close();
    canvas.drawPath(body, Paint()..color = Colors.white.withValues(alpha: 0.34));
    canvas.drawLine(
      center + direction * 5,
      center + direction * 13,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.60)
        ..strokeWidth = 2,
    );
  }

  void _paintGuns(Canvas canvas, Size size) {
    if (sideGunsVisible && sideGunAnglesDegrees.length >= 4) {
      _paintGun(canvas, Offset(8, size.height / 2), sideGunAnglesDegrees[0]);
      _paintGun(canvas, Offset(size.width - 8, size.height / 2), sideGunAnglesDegrees[1]);
      _paintGun(canvas, Offset(size.width / 2, 8), sideGunAnglesDegrees[2]);
      _paintGun(canvas, Offset(size.width / 2, size.height - 8), sideGunAnglesDegrees[3]);
    }
    if (cornerGunsVisible) {
      const d = 7.0;
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.22);
      for (final p in [
        const Offset(d, d),
        Offset(size.width - d, d),
        Offset(d, size.height - d),
        Offset(size.width - d, size.height - d),
      ]) {
        canvas.drawCircle(p, 3.2, paint);
      }
    }
  }

  void _paintProjectiles(Canvas canvas) {
    for (final p in projectiles) {
      canvas.drawCircle(
        _px(p.position),
        math.max(1.4, p.radiusMm * logicalPixelsPerMm),
        Paint()
          ..color = p.ricochet
              ? Colors.white.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.88),
      );
    }
  }

  void _paintImpacts(Canvas canvas) {
    for (final impact in impacts) {
      final t = (impact.lifeSeconds / 0.8).clamp(0, 1).toDouble();
      final c = _px(impact.position);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: t * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawCircle(c, 3 + (1 - t) * 9, paint);
      canvas.drawLine(c + const Offset(-4, -4), c + const Offset(4, 4), paint);
      canvas.drawLine(c + const Offset(-4, 4), c + const Offset(4, -4), paint);
    }
  }

  void _paintConstellation(Canvas canvas) {
    if (constellation.length < 2) return;
    final path = Path();
    final first = _px(constellation.first);
    path.moveTo(first.dx, first.dy);
    for (final point in constellation.skip(1)) {
      final o = _px(point);
      path.lineTo(o.dx, o.dy);
    }
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, paint);
    for (final point in constellation) {
      canvas.drawCircle(_px(point), 3.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ToyOverlayPainter oldDelegate) => true;
}
'''
Path('lib/ui/toy_overlay.dart').write_text(toy_overlay)

# ---------------- board_painter.dart ----------------
p = Path('lib/ui/board_painter.dart')
s = p.read_text()
s = replace_once(
    s,
    "    this.burstCenter,\n    this.burstProgress,",
    "    this.burstCenter,\n    this.burstProgress,\n    this.triangleBouncePhase,\n    this.squareChasePhase,\n    this.roundTriangleTips = false,",
    'board painter ctor',
)
s = replace_once(
    s,
    "  final double? burstProgress;",
    "  final double? burstProgress;\n  final double? triangleBouncePhase;\n  final double? squareChasePhase;\n  final bool roundTriangleTips;",
    'board painter fields',
)
paint_element = r'''  Offset _toward(Offset from, Offset to, double distance) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length <= 0.001) return from;
    final t = math.min(0.45, distance / length);
    return Offset(from.dx + dx * t, from.dy + dy * t);
  }

  Path _roundedPolygon(List<Offset> points, double radius) {
    final path = Path();
    for (var i = 0; i < points.length; i += 1) {
      final current = points[i];
      final previous = points[(i - 1 + points.length) % points.length];
      final next = points[(i + 1) % points.length];
      final incoming = _toward(current, previous, radius);
      final outgoing = _toward(current, next, radius);
      if (i == 0) {
        path.moveTo(incoming.dx, incoming.dy);
      } else {
        path.lineTo(incoming.dx, incoming.dy);
      }
      path.quadraticBezierTo(current.dx, current.dy, outgoing.dx, outgoing.dy);
    }
    path.close();
    return path;
  }

  void _paintElement(Canvas canvas, LightElement element, double opacity) {
    if (opacity <= 0) return;
    final alpha = opacity.clamp(0.0, 1.0).toDouble();
    final white = Color.fromRGBO(255, 255, 255, alpha);
    final center = Offset(
      element.position.xMm * logicalPixelsPerMm,
      element.position.yMm * logicalPixelsPerMm,
    );
    final base = geometry.baseMm(element.size) * logicalPixelsPerMm;
    final flatLength = geometry.flatLengthMm(element.size) * logicalPixelsPerMm;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(element.headingDegrees * math.pi / 180);

    if (element.pose == PyramidPose.upright) {
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: base,
        height: base,
      );
      if (element.illumination == IlluminationPattern.full) {
        canvas.drawRect(rect, Paint()..color = white);
      } else {
        final band = geometry.wallBandMm * logicalPixelsPerMm;
        final inner = rect.deflate(band.clamp(0, base / 2).toDouble());
        final ring = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect)
          ..addRect(inner);
        final chase = squareChasePhase;
        if (chase == null) {
          canvas.drawPath(ring, Paint()..color = white);
        } else {
          canvas.drawPath(
            ring,
            Paint()..color = Color.fromRGBO(255, 255, 255, 0.055 * alpha),
          );
          final chasePath = Path()..addRect(rect.deflate(band / 2));
          final metric = chasePath.computeMetrics().first;
          final start = metric.length * chase.clamp(0, 1);
          final span = metric.length * 0.19;
          final chasePaint = Paint()
            ..color = white
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, band)
            ..strokeCap = StrokeCap.round;
          if (start + span <= metric.length) {
            canvas.drawPath(metric.extractPath(start, start + span), chasePaint);
          } else {
            canvas.drawPath(metric.extractPath(start, metric.length), chasePaint);
            canvas.drawPath(
              metric.extractPath(0, start + span - metric.length),
              chasePaint,
            );
          }
        }
      }
      if (element.id == selectedId && alpha > 0.15) {
        canvas.drawRect(
          rect.inflate(3),
          Paint()
            ..color = Color.fromRGBO(255, 255, 255, 0.34 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    } else {
      final points = <Offset>[
        Offset(0, -flatLength / 2),
        Offset(base / 2, flatLength / 2),
        Offset(-base / 2, flatLength / 2),
      ];
      final triangle = roundTriangleTips
          ? _roundedPolygon(points, math.min(base, flatLength) * 0.075)
          : (Path()
              ..moveTo(points[0].dx, points[0].dy)
              ..lineTo(points[1].dx, points[1].dy)
              ..lineTo(points[2].dx, points[2].dy)
              ..close());
      final bounce = triangleBouncePhase;
      if (bounce == null) {
        canvas.drawPath(triangle, Paint()..color = white);
      } else {
        canvas.drawPath(
          triangle,
          Paint()..color = Color.fromRGBO(255, 255, 255, 0.045 * alpha),
        );
        final y = -flatLength / 2 + flatLength * bounce.clamp(0, 1);
        final band = math.max(3.0, flatLength * 0.16);
        canvas.save();
        canvas.clipPath(triangle);
        canvas.drawRect(
          Rect.fromLTWH(-base, y - band / 2, base * 2, band),
          Paint()..color = white,
        );
        canvas.restore();
      }
      if (element.id == selectedId && alpha > 0.15) {
        canvas.drawPath(
          triangle,
          Paint()
            ..color = Color.fromRGBO(255, 255, 255, 0.34 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    canvas.restore();
  }

'''
s = sub_once(
    s,
    r'  void _paintElement\(Canvas canvas, LightElement element, double opacity\) \{.*?\n  void _paintBurst',
    paint_element + '  void _paintBurst',
    'board element painter',
)
p.write_text(s)

# ---------------- board_controller.dart: physical tip snapping ----------------
p = Path('lib/application/board_controller.dart')
s = p.read_text()
old = r'''    if (current.pose == PyramidPose.upright) {
      final ux = drag.xMm / distance;
      final uy = drag.yMm / distance;
      final dragAngle = math.atan2(uy, ux) * 180 / math.pi;
      _commitPoseChange(
        current,
        current.copyWith(
          pose: PyramidPose.flat,
          position: PhysicalPoint(
            current.position.xMm + ux * hingeTravel,
            current.position.yMm + uy * hingeTravel,
          ),
          headingDegrees: normalizeDegrees(dragAngle + 90),
        ),
      );
      return;
    }'''
new = r'''    if (current.pose == PyramidPose.upright) {
      final dragAngle = math.atan2(drag.yMm, drag.xMm) * 180 / math.pi;
      final relative = ((dragAngle - current.headingDegrees + 540) % 360) - 180;
      final quarterTurn = (relative / 90).round();
      final tipDirection = normalizeDegrees(
        current.headingDegrees + quarterTurn * 90,
      );
      final radians = tipDirection * math.pi / 180;
      final ux = math.cos(radians);
      final uy = math.sin(radians);
      _commitPoseChange(
        current,
        current.copyWith(
          pose: PyramidPose.flat,
          position: PhysicalPoint(
            current.position.xMm + ux * hingeTravel,
            current.position.yMm + uy * hingeTravel,
          ),
          headingDegrees: normalizeDegrees(tipDirection + 90),
        ),
      );
      return;
    }'''
s = replace_once(s, old, new, 'tip snap physics')
p.write_text(s)

# ---------------- calibration_screen.dart: full replacement ----------------
calibration = r'''import 'package:flutter/material.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({
    super.key,
    required this.onComplete,
    this.initialLogicalPixelsPerMm = 4.8,
    this.onCancel,
  });

  final ValueChanged<double> onComplete;
  final double initialLogicalPixelsPerMm;
  final VoidCallback? onCancel;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const double _referenceMm = 50;
  static const double _largeBaseMm = 25.4;
  late double _logicalPixelsPerMm;
  bool _usePyramid = false;

  @override
  void initState() {
    super.initState();
    _logicalPixelsPerMm = widget.initialLogicalPixelsPerMm.clamp(2, 8);
  }

  @override
  Widget build(BuildContext context) {
    final referenceWidth = _referenceMm * _logicalPixelsPerMm;
    final pyramidWidth = _largeBaseMm * _logicalPixelsPerMm;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Calibrate physical size',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Ruler')),
                      ButtonSegment(value: true, label: Text('Large pyramid')),
                    ],
                    selected: {_usePyramid},
                    onSelectionChanged: (selection) {
                      setState(() => _usePyramid = selection.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _usePyramid
                        ? 'Place a Large pyramid upright over the filled square. Adjust the slider until its base matches the square exactly.'
                        : 'Hold a ruler to the screen with 0 aligned to the fixed left end. Adjust the slider until the right end reaches exactly 50 mm.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _usePyramid
                          ? SizedBox.square(
                              dimension: pyramidWidth,
                              child: const ColoredBox(color: Colors.white),
                            )
                          : SizedBox(
                              width: referenceWidth,
                              height: 8,
                              child: const ColoredBox(color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Slider(
                    min: 2.0,
                    max: 8.0,
                    divisions: 600,
                    value: _logicalPixelsPerMm,
                    onChanged: (value) {
                      setState(() => _logicalPixelsPerMm = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.onCancel != null) ...[
                        OutlinedButton(
                          onPressed: widget.onCancel,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      FilledButton(
                        onPressed: () => widget.onComplete(_logicalPixelsPerMm),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Text('Use calibration'),
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
    );
  }
}
'''
Path('lib/ui/calibration_screen.dart').write_text(calibration)

# ---------------- main.dart: reversible recalibration ----------------
p = Path('lib/main.dart')
s = p.read_text()
s = replace_once(
    s,
    "  bool _forceManualCalibration = false;",
    "  bool _forceManualCalibration = false;\n  CalibrationResult? _calibrationBeforeManual;",
    'calibration backup field',
)
s = replace_once(
    s,
    "  void _recalibrate() {\n    setState(() {\n      _forceManualCalibration = true;\n      _calibration = null;\n    });\n  }",
    "  void _recalibrate() {\n    setState(() {\n      _calibrationBeforeManual = _calibration;\n      _forceManualCalibration = true;\n      _calibration = null;\n    });\n  }\n\n  void _cancelManualCalibration() {\n    final previous = _calibrationBeforeManual;\n    if (previous == null) return;\n    setState(() {\n      _calibration = previous;\n      _calibrationBeforeManual = null;\n      _forceManualCalibration = false;\n    });\n  }",
    'recalibration cancel',
)
s = replace_once(
    s,
    "      _forceManualCalibration = false;\n    });\n  }",
    "      _forceManualCalibration = false;\n      _calibrationBeforeManual = null;\n    });\n  }",
    'complete clears backup',
)
s = replace_once(
    s,
    "    if (_forceManualCalibration || _calibration == null) {\n      return CalibrationScreen(onComplete: _completeManualCalibration);\n    }",
    "    if (_forceManualCalibration || _calibration == null) {\n      final previous = _calibrationBeforeManual;\n      return CalibrationScreen(\n        onComplete: _completeManualCalibration,\n        initialLogicalPixelsPerMm: previous?.logicalPixelsPerMm ?? 4.8,\n        onCancel: previous == null ? null : _cancelManualCalibration,\n      );\n    }",
    'calibration screen props',
)
p.write_text(s)

# ---------------- Android settings link ----------------
main_activity = r'''package com.udeudeude.lighthouse

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lighthouse/display",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "physicalDpi" -> {
                    val metrics = resources.displayMetrics
                    result.success(
                        mapOf(
                            "xdpi" to metrics.xdpi.toDouble(),
                            "ydpi" to metrics.ydpi.toDouble(),
                        ),
                    )
                }
                "openDisplaySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_DISPLAY_SETTINGS))
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
'''
Path('android/app/src/main/kotlin/com/udeudeude/lighthouse/MainActivity.kt').write_text(main_activity)

# ---------------- dependencies ----------------
p = Path('pubspec.yaml')
s = p.read_text()
s = replace_once(
    s,
    "dependencies:\n  flutter:\n    sdk: flutter\n",
    "dependencies:\n  flutter:\n    sdk: flutter\n  file_picker: ^12.3.0\n  file_saver: ^0.4.0\n",
    'file deps',
)
p.write_text(s)

# ---------------- tests ----------------
p = Path('test/application/board_controller_test.dart')
s = p.read_text()
insert_test = r'''
  test('diagonal tipping snaps perpendicular to a square edge', () {
    final controller = BoardController();
    controller.createAt(const PhysicalPoint(50, 50));
    final upright = controller.state.elements.single;

    controller.tipOrStand(upright, const PhysicalPoint(8, 4));
    final flat = controller.state.elements.single;

    expect(flat.pose, PyramidPose.flat);
    expect(flat.headingDegrees, closeTo(90, 0.001));
    expect(flat.position.yMm, closeTo(50, 0.001));
    expect(flat.position.xMm, greaterThan(50));
  });
'''
s = replace_once(s, "\n  test('different sizes snap into a co-located structure'", insert_test + "\n  test('different sizes snap into a co-located structure'", 'tip physics test')
p.write_text(s)

print('interaction revision v3 applied')
