from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, found {count}: {old[:160]!r}")
    path.write_text(text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# Dice Bubble: expose a small serializable snapshot so a remote display can
# render the same dice selection, results, and position as the controller.
# ---------------------------------------------------------------------------
dice = Path('lib/ui/dice_bubble.dart')
replace_once(
    dice,
    """const arcadeDiceChoices = <ArcadeDieChoice>[
  ArcadeDieChoice('standard-1', ArcadeDieKind.standard, 'Regular D6 1'),
  ArcadeDieChoice('standard-2', ArcadeDieKind.standard, 'Regular D6 2'),
  ArcadeDieChoice('standard-3', ArcadeDieKind.standard, 'Regular D6 3'),
  ArcadeDieChoice('lightning-1', ArcadeDieKind.lightning, 'Lightning 1'),
  ArcadeDieChoice('lightning-2', ArcadeDieKind.lightning, 'Lightning 2'),
  ArcadeDieChoice('lightning-3', ArcadeDieKind.lightning, 'Lightning 3'),
  ArcadeDieChoice('pyramid', ArcadeDieKind.pyramid, 'Pyramid die'),
  ArcadeDieChoice('treehouse', ArcadeDieKind.treehouse, 'Treehouse die'),
  ArcadeDieChoice('color', ArcadeDieKind.color, 'Color die'),
];

class DiceBubble extends StatefulWidget {
  const DiceBubble({super.key});

  @override
  State<DiceBubble> createState() => _DiceBubbleState();
}
""",
    """const arcadeDiceChoices = <ArcadeDieChoice>[
  ArcadeDieChoice('standard-1', ArcadeDieKind.standard, 'Regular D6 1'),
  ArcadeDieChoice('standard-2', ArcadeDieKind.standard, 'Regular D6 2'),
  ArcadeDieChoice('standard-3', ArcadeDieKind.standard, 'Regular D6 3'),
  ArcadeDieChoice('lightning-1', ArcadeDieKind.lightning, 'Lightning 1'),
  ArcadeDieChoice('lightning-2', ArcadeDieKind.lightning, 'Lightning 2'),
  ArcadeDieChoice('lightning-3', ArcadeDieKind.lightning, 'Lightning 3'),
  ArcadeDieChoice('pyramid', ArcadeDieKind.pyramid, 'Pyramid die'),
  ArcadeDieChoice('treehouse', ArcadeDieKind.treehouse, 'Treehouse die'),
  ArcadeDieChoice('color', ArcadeDieKind.color, 'Color die'),
];

class DiceBubbleSnapshot {
  const DiceBubbleSnapshot({
    required this.revision,
    required this.rollSerial,
    required this.selectedIds,
    required this.faces,
    required this.xFraction,
    required this.yFraction,
  });

  static const initial = DiceBubbleSnapshot(
    revision: 0,
    rollSerial: 0,
    selectedIds: ['standard-1'],
    faces: {'standard-1': 0},
    xFraction: 0.20,
    yFraction: 0.14,
  );

  final int revision;
  final int rollSerial;
  final List<String> selectedIds;
  final Map<String, int> faces;
  final double xFraction;
  final double yFraction;

  Map<String, Object?> toJson() => {
    'revision': revision,
    'rollSerial': rollSerial,
    'selectedIds': selectedIds,
    'faces': faces,
    'xFraction': xFraction,
    'yFraction': yFraction,
  };

  static DiceBubbleSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final map = raw.cast<String, Object?>();
      final ids = (map['selectedIds'] as List?)
              ?.whereType<String>()
              .where((id) => arcadeDiceChoices.any((choice) => choice.id == id))
              .take(3)
              .toList() ??
          const <String>[];
      final rawFaces = map['faces'];
      final faces = <String, int>{};
      if (rawFaces is Map) {
        for (final entry in rawFaces.entries) {
          if (entry.key is! String || entry.value is! num) continue;
          final value = (entry.value as num).toInt();
          if (value >= 0 && value < 6) faces[entry.key as String] = value;
        }
      }
      return DiceBubbleSnapshot(
        revision: (map['revision'] as num?)?.toInt() ?? 0,
        rollSerial: (map['rollSerial'] as num?)?.toInt() ?? 0,
        selectedIds: List<String>.unmodifiable(ids),
        faces: Map<String, int>.unmodifiable(faces),
        xFraction: ((map['xFraction'] as num?)?.toDouble() ?? 0.20)
            .clamp(0.0, 1.0)
            .toDouble(),
        yFraction: ((map['yFraction'] as num?)?.toDouble() ?? 0.14)
            .clamp(0.0, 1.0)
            .toDouble(),
      );
    } on Object {
      return null;
    }
  }
}

class DiceBubble extends StatefulWidget {
  const DiceBubble({
    super.key,
    this.snapshot = DiceBubbleSnapshot.initial,
    this.onChanged,
  });

  final DiceBubbleSnapshot snapshot;
  final ValueChanged<DiceBubbleSnapshot>? onChanged;

  @override
  State<DiceBubble> createState() => _DiceBubbleState();
}
""",
)
replace_once(
    dice,
    """  final List<String> _selectedIds = ['standard-1'];
  final Map<String, int> _faces = {'standard-1': 0};
  final Map<String, _SpinPlan> _plans = {};
  late final AnimationController _rollController;

  Offset _center = const Offset(80, 80);
""",
    """  final List<String> _selectedIds = [];
  final Map<String, int> _faces = {};
  final Map<String, _SpinPlan> _plans = {};
  late final AnimationController _rollController;

  Offset _center = const Offset(80, 80);
  Size _surfaceSize = Size.zero;
  Offset _pendingCenterFraction = const Offset(0.20, 0.14);
  int _revision = 0;
  int _rollSerial = 0;
  int _appliedRevision = -1;
""",
)
replace_once(
    dice,
    """  @override
  void initState() {
    super.initState();
    _rollController =
""",
    """  @override
  void initState() {
    super.initState();
    _applySnapshot(widget.snapshot, animateRoll: false);
    _rollController =
""",
)
replace_once(
    dice,
    """  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  ArcadeDieChoice _choice(String id) =>
""",
    """  @override
  void didUpdateWidget(covariant DiceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applySnapshot(widget.snapshot, animateRoll: true);
  }

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  void _applySnapshot(
    DiceBubbleSnapshot snapshot, {
    required bool animateRoll,
  }) {
    if (snapshot.revision == _appliedRevision) return;
    final previousFaces = Map<String, int>.from(_faces);
    final previousRollSerial = _rollSerial;
    _selectedIds
      ..clear()
      ..addAll(snapshot.selectedIds);
    _faces
      ..clear()
      ..addAll(snapshot.faces);
    for (final id in _selectedIds) {
      _faces.putIfAbsent(id, () => 0);
    }
    _revision = snapshot.revision;
    _rollSerial = snapshot.rollSerial;
    _appliedRevision = snapshot.revision;
    _pendingCenterFraction = Offset(snapshot.xFraction, snapshot.yFraction);
    if (_surfaceSize != Size.zero) {
      _center = _clampCenter(
        Offset(
          snapshot.xFraction * _surfaceSize.width,
          snapshot.yFraction * _surfaceSize.height,
        ),
        _surfaceSize,
      );
    }
    if (animateRoll && snapshot.rollSerial != previousRollSerial) {
      _planRemoteRoll(previousFaces);
    } else if (!animateRoll) {
      _plans.clear();
    }
  }

  void _planRemoteRoll(Map<String, int> previousFaces) {
    _plans.clear();
    for (final id in _selectedIds) {
      final oldFace = previousFaces[id] ?? _faces[id] ?? 0;
      final face = _faces[id] ?? 0;
      final start = _targetForFace(oldFace);
      final target = _targetForFace(face);
      _plans[id] = _SpinPlan(
        start: start,
        end: _Rotation3(
          _spunEnd(target.x),
          _spunEnd(target.y),
          _spunEnd(target.z),
        ),
        bounceAngle: _random.nextDouble() * 2 * math.pi,
        bouncePhase: _random.nextDouble() * 2 * math.pi,
      );
    }
    if (_rollController.isAnimating) _rollController.stop();
    _rollController.forward(from: 0);
  }

  void _emitSnapshot() {
    final callback = widget.onChanged;
    final size = _surfaceSize;
    if (callback == null || size == Size.zero) return;
    _revision += 1;
    _appliedRevision = _revision;
    final x = (_center.dx / size.width).clamp(0.0, 1.0).toDouble();
    final y = (_center.dy / size.height).clamp(0.0, 1.0).toDouble();
    _pendingCenterFraction = Offset(x, y);
    callback(
      DiceBubbleSnapshot(
        revision: _revision,
        rollSerial: _rollSerial,
        selectedIds: List<String>.unmodifiable(_selectedIds),
        faces: Map<String, int>.unmodifiable(_faces),
        xFraction: x,
        yFraction: y,
      ),
    );
  }

  ArcadeDieChoice _choice(String id) =>
""",
)
replace_once(
    dice,
    """    HapticFeedback.mediumImpact();
    _rollController.forward(from: 0);
  }
""",
    """    _rollSerial += 1;
    HapticFeedback.mediumImpact();
    _rollController.forward(from: 0);
    _emitSnapshot();
  }
""",
)
replace_once(
    dice,
    """                                    setSheetState(() {});
                                  },
""",
    """                                    setSheetState(() {});
                                    _emitSnapshot();
                                  },
""",
)
replace_once(
    dice,
    """    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      _center = _clampCenter(_center, size);
""",
    """    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final firstLayout = _surfaceSize == Size.zero;
      _surfaceSize = size;
      if (firstLayout) {
        _center = _clampCenter(
          Offset(
            _pendingCenterFraction.dx * size.width,
            _pendingCenterFraction.dy * size.height,
          ),
          size,
        );
      } else {
        _center = _clampCenter(_center, size);
      }
""",
)
replace_once(
    dice,
    """                setState(() {
                  _pressed = false;
                  _center = _clampCenter(
                    _center + details.focalPointDelta,
                    size,
                  );
                });
""",
    """                setState(() {
                  _pressed = false;
                  _center = _clampCenter(
                    _center + details.focalPointDelta,
                    size,
                  );
                });
                _emitSnapshot();
""",
)
replace_once(
    dice,
    """                _twoFingerMove = false;
                _gestureMoved = false;
                _gestureTravel = 0;
              },
""",
    """                _twoFingerMove = false;
                _gestureMoved = false;
                _gestureTravel = 0;
                _emitSnapshot();
              },
""",
)


# ---------------------------------------------------------------------------
# Zendo stones: same normalized, serializable state contract.
# ---------------------------------------------------------------------------
zendo = Path('lib/ui/zendo_stones.dart')
replace_once(
    zendo,
    """import 'package:flutter/material.dart';

class ZendoStonesWidget extends StatefulWidget {
  const ZendoStonesWidget({super.key});

  @override
  State<ZendoStonesWidget> createState() => _ZendoStonesWidgetState();
}
""",
    """import 'package:flutter/material.dart';

class ZendoStoneSnapshot {
  const ZendoStoneSnapshot({
    required this.id,
    required this.kind,
    required this.xFraction,
    required this.yFraction,
  });

  final int id;
  final String kind;
  final double xFraction;
  final double yFraction;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'xFraction': xFraction,
    'yFraction': yFraction,
  };

  static ZendoStoneSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final map = raw.cast<String, Object?>();
      final id = (map['id'] as num?)?.toInt();
      final kind = map['kind'];
      if (id == null || kind is! String) return null;
      return ZendoStoneSnapshot(
        id: id,
        kind: kind,
        xFraction: ((map['xFraction'] as num?)?.toDouble() ?? 0.5)
            .clamp(0.0, 1.0)
            .toDouble(),
        yFraction: ((map['yFraction'] as num?)?.toDouble() ?? 0.5)
            .clamp(0.0, 1.0)
            .toDouble(),
      );
    } on Object {
      return null;
    }
  }
}

class ZendoStonesSnapshot {
  const ZendoStonesSnapshot({required this.revision, required this.stones});

  static const initial = ZendoStonesSnapshot(revision: 0, stones: []);

  final int revision;
  final List<ZendoStoneSnapshot> stones;

  Map<String, Object?> toJson() => {
    'revision': revision,
    'stones': [for (final stone in stones) stone.toJson()],
  };

  static ZendoStonesSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final map = raw.cast<String, Object?>();
      final stones = <ZendoStoneSnapshot>[];
      final rawStones = map['stones'];
      if (rawStones is List) {
        for (final item in rawStones) {
          final stone = ZendoStoneSnapshot.fromJson(item);
          if (stone != null) stones.add(stone);
        }
      }
      return ZendoStonesSnapshot(
        revision: (map['revision'] as num?)?.toInt() ?? 0,
        stones: List<ZendoStoneSnapshot>.unmodifiable(stones),
      );
    } on Object {
      return null;
    }
  }
}

class ZendoStonesWidget extends StatefulWidget {
  const ZendoStonesWidget({
    super.key,
    this.snapshot = ZendoStonesSnapshot.initial,
    this.onChanged,
  });

  final ZendoStonesSnapshot snapshot;
  final ValueChanged<ZendoStonesSnapshot>? onChanged;

  @override
  State<ZendoStonesWidget> createState() => _ZendoStonesWidgetState();
}
""",
)
replace_once(
    zendo,
    """  final List<_ZendoStone> _stones = [];
  int _nextId = 1;
  int? _trayDragStoneId;
""",
    """  final List<_ZendoStone> _stones = [];
  int _nextId = 1;
  int? _trayDragStoneId;
  int _revision = 0;
  int _appliedRevision = -1;
  Size _surfaceSize = Size.zero;
  ZendoStonesSnapshot? _pendingSnapshot;

  @override
  void initState() {
    super.initState();
    _pendingSnapshot = widget.snapshot;
  }

  @override
  void didUpdateWidget(covariant ZendoStonesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapshot.revision == _appliedRevision) return;
    _pendingSnapshot = widget.snapshot;
    if (_surfaceSize != Size.zero) {
      _applySnapshot(widget.snapshot, _surfaceSize);
      if (mounted) setState(() {});
    }
  }

  _ZendoStoneKind? _kindFromName(String name) =>
      _ZendoStoneKind.values.where((kind) => kind.name == name).firstOrNull;

  void _applySnapshot(ZendoStonesSnapshot snapshot, Size size) {
    if (snapshot.revision == _appliedRevision) return;
    _stones.clear();
    var maximumId = 0;
    for (final item in snapshot.stones) {
      final kind = _kindFromName(item.kind);
      if (kind == null) continue;
      maximumId = item.id > maximumId ? item.id : maximumId;
      _stones.add(
        _ZendoStone(
          id: item.id,
          kind: kind,
          center: _clamp(
            Offset(item.xFraction * size.width, item.yFraction * size.height),
            size,
          ),
          expanded: true,
        ),
      );
    }
    _nextId = maximumId + 1;
    _revision = snapshot.revision;
    _appliedRevision = snapshot.revision;
    _pendingSnapshot = null;
  }

  void _emitSnapshot(Size size) {
    final callback = widget.onChanged;
    if (callback == null || size == Size.zero) return;
    _revision += 1;
    _appliedRevision = _revision;
    callback(
      ZendoStonesSnapshot(
        revision: _revision,
        stones: List<ZendoStoneSnapshot>.unmodifiable([
          for (final stone in _stones)
            ZendoStoneSnapshot(
              id: stone.id,
              kind: stone.kind.name,
              xFraction: (stone.center.dx / size.width)
                  .clamp(0.0, 1.0)
                  .toDouble(),
              yFraction: (stone.center.dy / size.height)
                  .clamp(0.0, 1.0)
                  .toDouble(),
            ),
        ]),
      ),
    );
  }
""",
)
replace_once(
    zendo,
    """    setState(() {
      _stones.add(
        _ZendoStone(
          id: n,
          kind: kind,
          center: _clamp(
            Offset(size.width / 2, size.height / 2) + offset,
            size,
          ),
          expanded: true,
        ),
      );
    });
  }
""",
    """    setState(() {
      _stones.add(
        _ZendoStone(
          id: n,
          kind: kind,
          center: _clamp(
            Offset(size.width / 2, size.height / 2) + offset,
            size,
          ),
          expanded: true,
        ),
      );
    });
    _emitSnapshot(size);
  }
""",
)
replace_once(
    zendo,
    """    setState(() {
      _stones.add(
        _ZendoStone(
          id: id,
          kind: kind,
          center: _clamp(_local(details.globalPosition), size),
          expanded: false,
        ),
      );
    });
  }
""",
    """    setState(() {
      _stones.add(
        _ZendoStone(
          id: id,
          kind: kind,
          center: _clamp(_local(details.globalPosition), size),
          expanded: false,
        ),
      );
    });
    _emitSnapshot(size);
  }
""",
)
replace_once(
    zendo,
    """    setState(() {
      _stones[index] = _stones[index].copyWith(
        center: _clamp(_local(details.globalPosition), size),
        expanded: true,
      );
    });
  }
""",
    """    setState(() {
      _stones[index] = _stones[index].copyWith(
        center: _clamp(_local(details.globalPosition), size),
        expanded: true,
      );
    });
    _emitSnapshot(size);
  }
""",
)
replace_once(
    zendo,
    """    setState(() => _stones[index] = _stones[index].copyWith(expanded: true));
  }
""",
    """    setState(() => _stones[index] = _stones[index].copyWith(expanded: true));
    _emitSnapshot(_surfaceSize);
  }
""",
)
replace_once(
    zendo,
    """    setState(() {
      _stones[index] = _stones[index].copyWith(
        center: _clamp(_stones[index].center + delta, size),
        expanded: true,
      );
    });
  }

  void _remove(int id) => setState(() {
    _stones.removeWhere((stone) => stone.id == id);
  });
""",
    """    setState(() {
      _stones[index] = _stones[index].copyWith(
        center: _clamp(_stones[index].center + delta, size),
        expanded: true,
      );
    });
    _emitSnapshot(size);
  }

  void _remove(int id) {
    setState(() {
      _stones.removeWhere((stone) => stone.id == id);
    });
    _emitSnapshot(_surfaceSize);
  }
""",
)
replace_once(
    zendo,
    """    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return Stack(
""",
    """    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      _surfaceSize = size;
      final pending = _pendingSnapshot;
      if (pending != null) _applySnapshot(pending, size);
      return Stack(
""",
)


# ---------------------------------------------------------------------------
# Board screen: periodically publish a compact runtime snapshot only while this
# device is the controller, and only when that runtime actually changed.
# ---------------------------------------------------------------------------
board = Path('lib/ui/board_screen.dart')
replace_once(
    board,
    """  Timer? _remotePublishTimer;
  BoardState? _remotePendingState;
  bool _applyingRemoteState = false;
""",
    """  Timer? _remotePublishTimer;
  BoardState? _remotePendingState;
  Timer? _remoteRuntimeTimer;
  String? _lastRemoteRuntimeJson;
  DiceBubbleSnapshot _diceSnapshot = DiceBubbleSnapshot.initial;
  ZendoStonesSnapshot _zendoSnapshot = ZendoStonesSnapshot.initial;
  bool _applyingRemoteState = false;
""",
)
replace_once(
    board,
    """    _remotePublishTimer?.cancel();
    _remoteMessageSubscription?.cancel();
""",
    """    _remotePublishTimer?.cancel();
    _remoteRuntimeTimer?.cancel();
    _remoteMessageSubscription?.cancel();
""",
)
replace_once(
    board,
    """      if (_needsToyTicker) _ensureToyTicker();
""",
    """      if (_needsToyTicker && !_remoteDisplayMode) _ensureToyTicker();
""",
)
replace_once(
    board,
    """  void _ensureToyTicker() {
    if (_toyTicker != null) return;
""",
    """  void _ensureToyTicker() {
    if (_remoteDisplayMode || _toyTicker != null) return;
""",
)

# Add runtime send/apply helpers just before remote session start.
replace_once(
    board,
    """  Future<void> _startRemoteSession(RemoteSession session) async {
""",
    r'''  Map<String, Object?> _remotePoint(PhysicalPoint point) => {
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

  Map<String, Object?> _remoteRuntimePayload() => {
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
    'eventZoneCenter':
        _eventZoneCenter == null ? null : _remotePoint(_eventZoneCenter!),
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
    await session.sendApp('runtime', payload);
  }

  void _handleDiceSnapshot(DiceBubbleSnapshot snapshot) {
    _diceSnapshot = snapshot;
    unawaited(_sendRemoteRuntimeIfChanged());
  }

  void _handleZendoSnapshot(ZendoStonesSnapshot snapshot) {
    _zendoSnapshot = snapshot;
    unawaited(_sendRemoteRuntimeIfChanged());
  }

  Future<void> _applyRemoteRuntime(Map<String, Object?> payload) async {
    if (_remoteSession?.role != RemoteRole.display || !mounted) return;
    final activeNames = (payload['activeToys'] as List?)?.whereType<String>() ??
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
        impacts.add(ToyImpact(position: position, lifeSeconds: life.toDouble()));
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
    final constellation = (payload['constellationElementIds'] as List?)
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

  Future<void> _startRemoteSession(RemoteSession session) async {
''',
)

# Runtime lifecycle: start after connect, include runtime in handshake, apply it,
# and restart/stop publisher when roles change.
replace_once(
    board,
    """    await session.connect();
    if (!mounted) return;
    await _sendRemoteHello();
""",
    """    await session.connect();
    if (!mounted) return;
    _startRemoteRuntimePublisher();
    await _sendRemoteHello();
""",
)
replace_once(
    board,
    """        if (session.isCreator) {
          await _sendRemoteHello();
          await _sendRemoteState('seed');
        }
""",
    """        if (session.isCreator) {
          await _sendRemoteHello();
          await _sendRemoteState('seed');
          await _sendRemoteRuntimeIfChanged(force: true);
        }
""",
)
replace_once(
    board,
    """        if (session.role == RemoteRole.controller) {
          await _sendRemoteState('state');
        }
      case 'state':
""",
    """        if (session.role == RemoteRole.controller) {
          _startRemoteRuntimePublisher();
          await _sendRemoteState('state');
          await _sendRemoteRuntimeIfChanged(force: true);
        }
      case 'state':
""",
)
replace_once(
    board,
    """      case 'state':
        if (session.role == RemoteRole.display) {
          await _applyRemoteState(message.payload);
        }
      case 'role':
""",
    """      case 'state':
        if (session.role == RemoteRole.display) {
          await _applyRemoteState(message.payload);
        }
      case 'runtime':
        await _applyRemoteRuntime(message.payload);
      case 'role':
""",
)
replace_once(
    board,
    """        await session.setRole(peerRole.other, announce: false);
        setState(() {
          _remoteDisplayWidthMm = null;
          _remoteDisplayHeightMm = null;
        });
        await _sendRemoteHello();
        if (session.role == RemoteRole.controller) {
          await _sendRemoteState('state');
        }
""",
    """        await session.setRole(peerRole.other, announce: false);
        setState(() {
          _remoteDisplayWidthMm = null;
          _remoteDisplayHeightMm = null;
        });
        _startRemoteRuntimePublisher();
        await _sendRemoteHello();
        if (session.role == RemoteRole.controller) {
          await _sendRemoteState('state');
          await _sendRemoteRuntimeIfChanged(force: true);
        }
""",
)
replace_once(
    board,
    """    _remotePublishTimer?.cancel();
    _remotePublishTimer = null;
    _remotePendingState = null;
""",
    """    _remotePublishTimer?.cancel();
    _remotePublishTimer = null;
    _remoteRuntimeTimer?.cancel();
    _remoteRuntimeTimer = null;
    _lastRemoteRuntimeJson = null;
    _remotePendingState = null;
""",
)
replace_once(
    board,
    """    await session.setRole(session.role.other);
    setState(() {
      _remoteDisplayWidthMm = null;
      _remoteDisplayHeightMm = null;
    });
    await _sendRemoteHello();
    if (session.role == RemoteRole.controller) {
      await _sendRemoteState('state');
    }
""",
    """    await session.setRole(session.role.other);
    setState(() {
      _remoteDisplayWidthMm = null;
      _remoteDisplayHeightMm = null;
    });
    _startRemoteRuntimePublisher();
    await _sendRemoteHello();
    if (session.role == RemoteRole.controller) {
      await _sendRemoteState('state');
      await _sendRemoteRuntimeIfChanged(force: true);
    }
""",
)

# Feed synchronized overlay snapshots to both controller and display widgets.
replace_once(
    board,
    """        if (_activeToys.contains(_ToyKind.wireDie))
          IgnorePointer(
            ignoring: _remoteDisplayMode,
            child: const DiceBubble(),
          ),
        if (_activeToys.contains(_ToyKind.zendoStones))
          IgnorePointer(
            ignoring: _remoteDisplayMode,
            child: const ZendoStonesWidget(),
          ),
""",
    """        if (_activeToys.contains(_ToyKind.wireDie))
          IgnorePointer(
            ignoring: _remoteDisplayMode,
            child: DiceBubble(
              snapshot: _diceSnapshot,
              onChanged: _remoteDisplayMode ? null : _handleDiceSnapshot,
            ),
          ),
        if (_activeToys.contains(_ToyKind.zendoStones))
          IgnorePointer(
            ignoring: _remoteDisplayMode,
            child: ZendoStonesWidget(
              snapshot: _zendoSnapshot,
              onChanged: _remoteDisplayMode ? null : _handleZendoSnapshot,
            ),
          ),
""",
)

# Snapshot unit tests.
Path('test/ui/remote_overlay_snapshot_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/dice_bubble.dart';
import 'package:lighthouse/ui/zendo_stones.dart';

void main() {
  test('dice bubble snapshot round trips', () {
    const source = DiceBubbleSnapshot(
      revision: 7,
      rollSerial: 3,
      selectedIds: ['standard-1', 'pyramid'],
      faces: {'standard-1': 5, 'pyramid': 2},
      xFraction: 0.37,
      yFraction: 0.61,
    );
    final decoded = DiceBubbleSnapshot.fromJson(source.toJson());
    expect(decoded, isNotNull);
    expect(decoded!.revision, 7);
    expect(decoded.rollSerial, 3);
    expect(decoded.selectedIds, ['standard-1', 'pyramid']);
    expect(decoded.faces['standard-1'], 5);
    expect(decoded.xFraction, closeTo(0.37, 0.0001));
  });

  test('zendo stones snapshot round trips', () {
    const source = ZendoStonesSnapshot(
      revision: 4,
      stones: [
        ZendoStoneSnapshot(
          id: 9,
          kind: 'green',
          xFraction: 0.2,
          yFraction: 0.8,
        ),
      ],
    );
    final decoded = ZendoStonesSnapshot.fromJson(source.toJson());
    expect(decoded, isNotNull);
    expect(decoded!.revision, 4);
    expect(decoded.stones.single.kind, 'green');
    expect(decoded.stones.single.id, 9);
  });
}
''')

# Note complete control-surface synchronization in docs/changelog.
changelog = Path('CHANGELOG.md')
replace_once(
    changelog,
    "- Added two-device Remote sessions: either device can be the Board Display or Controller, pairing uses a QR/link, controller coordinates scale to the display board, WebRTC is preferred for direct transport, and encrypted relay messaging provides pairing/fallback.\n",
    "- Added two-device Remote sessions: either device can be the Board Display or Controller, pairing uses a QR/link, controller coordinates scale to the display board, transient toy effects plus Dice Bubble and Zendo Stone state are mirrored to the display, WebRTC is preferred for direct transport, and encrypted relay messaging provides pairing/fallback.\n",
)

# One-shot staging files do not belong in the feature commit.
Path('.github/scripts/apply_remote_runtime_sync.py').unlink()
Path('.github/workflows/remote-runtime-sync.yml').unlink()
