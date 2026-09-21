import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pyramid_love_lightning_paths.dart';

enum ArcadeDieKind { standard, lightning, pyramid, treehouse, color, fate }

bool arcadeDieUsesDarkBody(ArcadeDieKind kind) =>
    kind == ArcadeDieKind.lightning || kind == ArcadeDieKind.treehouse;

String lightningDieFaceSymbol(int face) => switch (face % 6) {
  0 => 'bolt',
  1 => 'atom',
  2 => 'split-circle',
  3 => 'arrow',
  4 => 'pyramids',
  _ => 'recycle',
};

String pyramidDieFaceSymbol(int face) => switch (face % 6) {
  0 => 'small',
  1 => 'medium',
  2 => 'large',
  3 => 'small-medium',
  4 => 'small-large',
  _ => 'medium-large',
};

String fateDieFaceSymbol(int face) => switch (face % 6) {
  0 || 1 => '+',
  2 || 3 => '-',
  _ => '',
};

int nextArcadeDieCount({required int current, required int otherSelected}) {
  final maximum = (3 - otherSelected).clamp(0, 3).toInt();
  if (maximum == 0 || current >= maximum) return 0;
  return current + 1;
}

const pyramidDieHeightToBaseRatio = 1.75;

Offset diceBubbleSpiderPoint(int serial) {
  if (serial <= 0) return Offset.zero;
  final angle = (serial * 2.399963229728653) % (2 * math.pi);
  final radiusStep = ((serial * 37) % 100) / 100;
  final radius = 0.17 + radiusStep * 0.30;
  return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
}

class ArcadeDieChoice {
  const ArcadeDieChoice(this.id, this.kind, this.label);

  final String id;
  final ArcadeDieKind kind;
  final String label;
}

const arcadeDiceChoices = <ArcadeDieChoice>[
  ArcadeDieChoice('standard', ArcadeDieKind.standard, 'Regular D6'),
  ArcadeDieChoice('lightning', ArcadeDieKind.lightning, 'Lightning die'),
  ArcadeDieChoice('pyramid', ArcadeDieKind.pyramid, 'Pyramid die'),
  ArcadeDieChoice('treehouse', ArcadeDieKind.treehouse, 'Treehouse die'),
  ArcadeDieChoice('color', ArcadeDieKind.color, 'Color die'),
  ArcadeDieChoice('fate', ArcadeDieKind.fate, 'Fudge / Fate die'),
];

String arcadeDieBaseId(String instanceId) {
  if (instanceId.contains('#')) return instanceId.split('#').first;
  if (instanceId.startsWith('standard-')) return 'standard';
  if (instanceId.startsWith('lightning-')) return 'lightning';
  return instanceId;
}

bool isKnownArcadeDieInstance(String instanceId) =>
    arcadeDiceChoices.any((choice) => choice.id == arcadeDieBaseId(instanceId));

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
    selectedIds: ['standard#1'],
    faces: {'standard#1': 0},
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
      final ids =
          (map['selectedIds'] as List?)
              ?.whereType<String>()
              .where(isKnownArcadeDieInstance)
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
    this.scale = 1,
  });

  final DiceBubbleSnapshot snapshot;
  final ValueChanged<DiceBubbleSnapshot>? onChanged;
  final double scale;

  @override
  State<DiceBubble> createState() => _DiceBubbleState();
}

class _Rotation3 {
  const _Rotation3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static _Rotation3 lerp(_Rotation3 a, _Rotation3 b, double t) => _Rotation3(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.z + (b.z - a.z) * t,
  );
}

class _SpinPlan {
  const _SpinPlan({
    required this.start,
    required this.end,
    required this.bounceAngle,
    required this.bouncePhase,
  });

  final _Rotation3 start;
  final _Rotation3 end;
  final double bounceAngle;
  final double bouncePhase;

  _Rotation3 rotationAt(double progress) {
    final eased = 1 - math.pow(1 - progress.clamp(0.0, 1.0), 3).toDouble();
    return _Rotation3.lerp(start, end, eased);
  }
}

class _DiceBubbleState extends State<DiceBubble>
    with SingleTickerProviderStateMixin {
  double get _radius => 70 * widget.scale.clamp(0.25, 4.0);
  final math.Random _random = math.Random();
  final List<String> _selectedIds = [];
  final Map<String, int> _faces = {};
  final Map<String, _SpinPlan> _plans = {};
  late final AnimationController _rollController;

  Offset _center = const Offset(80, 80);
  Size _surfaceSize = Size.zero;
  Offset _pendingCenterFraction = const Offset(0.20, 0.14);
  int _revision = 0;
  int _rollSerial = 0;
  int _appliedRevision = -1;
  int _nextInstanceSerial = 2;
  bool _pressed = false;
  bool _twoFingerMove = false;
  bool _gestureMoved = false;
  double _gestureTravel = 0;

  @override
  void initState() {
    super.initState();
    _applySnapshot(widget.snapshot, animateRoll: false);
    _rollController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1180),
          value: 1,
        )..addListener(() {
          if (mounted) setState(() {});
        });
  }

  @override
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
    for (final id in _selectedIds) {
      final marker = id.lastIndexOf('#');
      if (marker < 0) continue;
      final serial = int.tryParse(id.substring(marker + 1));
      if (serial != null && serial >= _nextInstanceSerial) {
        _nextInstanceSerial = serial + 1;
      }
    }
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

  ArcadeDieChoice _choice(String id) {
    final baseId = arcadeDieBaseId(id);
    return arcadeDiceChoices.firstWhere((choice) => choice.id == baseId);
  }

  int _choiceCount(String baseId) =>
      _selectedIds.where((id) => arcadeDieBaseId(id) == baseId).length;

  int _maximumChoiceCount(ArcadeDieChoice choice) {
    final current = _choiceCount(choice.id);
    final otherSelected = _selectedIds.length - current;
    return (3 - otherSelected).clamp(0, 3).toInt();
  }

  void _setChoiceCount(ArcadeDieChoice choice, int target) {
    final maximum = _maximumChoiceCount(choice);
    final desired = target.clamp(0, maximum).toInt();
    final current = _choiceCount(choice.id);
    if (current == desired) return;
    setState(() {
      while (_choiceCount(choice.id) > desired) {
        final index = _selectedIds.lastIndexWhere(
          (id) => arcadeDieBaseId(id) == choice.id,
        );
        if (index < 0) break;
        final id = _selectedIds.removeAt(index);
        _faces.remove(id);
        _plans.remove(id);
      }
      while (_choiceCount(choice.id) < desired && _selectedIds.length < 3) {
        final id = '${choice.id}#${_nextInstanceSerial++}';
        _selectedIds.add(id);
        _faces[id] = _random.nextInt(6);
      }
    });
    _emitSnapshot();
  }

  void _addChoice(ArcadeDieChoice choice) =>
      _setChoiceCount(choice, _choiceCount(choice.id) + 1);

  void _removeChoice(ArcadeDieChoice choice) =>
      _setChoiceCount(choice, _choiceCount(choice.id) - 1);

  void _cycleChoice(ArcadeDieChoice choice) {
    final current = _choiceCount(choice.id);
    final otherSelected = _selectedIds.length - current;
    _setChoiceCount(
      choice,
      nextArcadeDieCount(current: current, otherSelected: otherSelected),
    );
  }

  double _normalize(double radians) =>
      ((radians + math.pi) % (2 * math.pi)) - math.pi;

  _Rotation3 _targetForFace(int face) => switch (face) {
    0 => const _Rotation3(0, 0, 0),
    1 => const _Rotation3(-math.pi / 2, 0, 0),
    2 => const _Rotation3(0, -math.pi / 2, 0),
    3 => const _Rotation3(0, math.pi / 2, 0),
    4 => const _Rotation3(math.pi / 2, 0, 0),
    _ => const _Rotation3(0, math.pi, 0),
  };

  double _spunEnd(double target) {
    final turns = 2 + _random.nextInt(3);
    final sign = _random.nextBool() ? 1.0 : -1.0;
    return target + sign * turns * 2 * math.pi;
  }

  void _roll() {
    if (_selectedIds.isEmpty) {
      _rollSerial += 1;
      HapticFeedback.lightImpact();
      _rollController.forward(from: 0);
      _emitSnapshot();
      return;
    }
    for (final id in _selectedIds) {
      final old = _plans[id]?.rotationAt(1) ?? _targetForFace(_faces[id] ?? 0);
      final start = _Rotation3(
        _normalize(old.x),
        _normalize(old.y),
        _normalize(old.z),
      );
      final face = _random.nextInt(6);
      final target = _targetForFace(face);
      _faces[id] = face;
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
    _rollSerial += 1;
    HapticFeedback.mediumImpact();
    _rollController.forward(from: 0);
    _emitSnapshot();
  }

  Offset _clampCenter(Offset center, Size size) => Offset(
    center.dx
        .clamp(_radius + 2, math.max(_radius + 2, size.width - _radius - 2))
        .toDouble(),
    center.dy
        .clamp(_radius + 2, math.max(_radius + 2, size.height - _radius - 2))
        .toDouble(),
  );

  Widget _selectorImage(ArcadeDieChoice choice) {
    final darkBody = arcadeDieUsesDarkBody(choice.kind);
    final foreground = darkBody ? Colors.white : Colors.black;
    Widget mark;
    switch (choice.kind) {
      case ArcadeDieKind.standard:
        mark = Stack(
          children: [
            Positioned(left: 11, top: 11, child: _SelectorPip(foreground)),
            Positioned(right: 11, top: 11, child: _SelectorPip(foreground)),
            Center(child: _SelectorPip(foreground)),
            Positioned(left: 11, bottom: 11, child: _SelectorPip(foreground)),
            Positioned(right: 11, bottom: 11, child: _SelectorPip(foreground)),
          ],
        );
      case ArcadeDieKind.lightning:
        mark = Icon(Icons.bolt, color: foreground, size: 35);
      case ArcadeDieKind.pyramid:
        mark = Icon(Icons.change_history, color: foreground, size: 35);
      case ArcadeDieKind.treehouse:
        mark = Center(
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Text(
              'AIM',
              style: TextStyle(
                color: foreground,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ),
        );
      case ArcadeDieKind.color:
        mark = Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 1,
            runSpacing: -4,
            children: const [
              Text('♠', style: TextStyle(color: Colors.purple, fontSize: 17)),
              Text('♥', style: TextStyle(color: Colors.red, fontSize: 17)),
              Text('♦', style: TextStyle(color: Colors.blue, fontSize: 17)),
              Text('♣', style: TextStyle(color: Colors.green, fontSize: 17)),
              Text('★', style: TextStyle(color: Colors.yellow, fontSize: 15)),
            ],
          ),
        );
      case ArcadeDieKind.fate:
        mark = Center(
          child: Text(
            '±',
            style: TextStyle(
              color: foreground,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
    }
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: darkBody ? Colors.black : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: darkBody ? Colors.white70 : Colors.black87),
      ),
      child: mark,
    );
  }

  Future<void> _showPicker() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF202020),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                    child: Text(
                      'Dice · ${_selectedIds.length}/3 selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 9,
                          crossAxisSpacing: 9,
                          childAspectRatio: 1,
                        ),
                    itemCount: arcadeDiceChoices.length,
                    itemBuilder: (context, index) {
                      final choice = arcadeDiceChoices[index];
                      final count = _choiceCount(choice.id);
                      final canAdd = count < _maximumChoiceCount(choice);
                      return Tooltip(
                        message: choice.label,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            _cycleChoice(choice);
                            setSheetState(() {});
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: count > 0
                                    ? Colors.white
                                    : Colors.white24,
                                width: count > 0 ? 2 : 1,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _selectorImage(choice),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 2,
                                  bottom: 2,
                                  child: IconButton(
                                    tooltip: 'Remove one ${choice.label}',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 30,
                                      minHeight: 30,
                                    ),
                                    onPressed: count == 0
                                        ? null
                                        : () {
                                            _removeChoice(choice);
                                            setSheetState(() {});
                                          },
                                    icon: const Icon(Icons.remove, size: 18),
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: IconButton(
                                    tooltip: 'Add one ${choice.label}',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 30,
                                      minHeight: 30,
                                    ),
                                    onPressed: canAdd
                                        ? () {
                                            _addChoice(choice);
                                            setSheetState(() {});
                                          }
                                        : null,
                                    icon: const Icon(Icons.add, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
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
      final selected = [for (final id in _selectedIds) _choice(id)];
      return Stack(
        children: [
          Positioned(
            left: _center.dx - _radius,
            top: _center.dy - _radius,
            width: _radius * 2,
            height: _radius * 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _twoFingerMove = details.pointerCount >= 2;
                _gestureMoved = false;
                _gestureTravel = 0;
                setState(() => _pressed = !_twoFingerMove);
                if (_pressed) HapticFeedback.selectionClick();
              },
              onScaleUpdate: (details) {
                _gestureTravel += details.focalPointDelta.distance;
                if (_gestureTravel > 4) _gestureMoved = true;
                if (details.pointerCount < 2) {
                  if (_gestureMoved && _pressed)
                    setState(() => _pressed = false);
                  return;
                }
                _twoFingerMove = true;
                if (details.focalPointDelta.distance > 0) _gestureMoved = true;
                setState(() {
                  _pressed = false;
                  _center = _clampCenter(
                    _center + details.focalPointDelta,
                    size,
                  );
                });
                _emitSnapshot();
              },
              onScaleEnd: (_) {
                final roll = _pressed && !_twoFingerMove && !_gestureMoved;
                setState(() => _pressed = false);
                if (roll) _roll();
                _twoFingerMove = false;
                _gestureMoved = false;
                _gestureTravel = 0;
                _emitSnapshot();
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _DiceBubblePainter(
                      instanceIds: List<String>.unmodifiable(_selectedIds),
                      choices: List<ArcadeDieChoice>.unmodifiable(selected),
                      faces: Map<String, int>.unmodifiable(_faces),
                      plans: Map<String, _SpinPlan>.unmodifiable(_plans),
                      progress: _rollController.value,
                      rollSerial: _rollSerial,
                      pressed: _pressed,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showPicker,
                      child: Container(
                        width: 12 * widget.scale.clamp(0.25, 4.0),
                        height: 38 * widget.scale.clamp(0.25, 4.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBDBDBD),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _SelectorPip extends StatelessWidget {
  const _SelectorPip(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

class _Face {
  const _Face({
    required this.index,
    required this.vertices,
    required this.normal,
    required this.xAxis,
    required this.yAxis,
  });

  final int index;
  final List<int> vertices;
  final _V3 normal;
  final _V3 xAxis;
  final _V3 yAxis;
}

class _DiceBubblePainter extends CustomPainter {
  const _DiceBubblePainter({
    required this.instanceIds,
    required this.choices,
    required this.faces,
    required this.plans,
    required this.progress,
    required this.rollSerial,
    required this.pressed,
  });

  final List<String> instanceIds;
  final List<ArcadeDieChoice> choices;
  final Map<String, int> faces;
  final Map<String, _SpinPlan> plans;
  final double progress;
  final int rollSerial;
  final bool pressed;

  static const _vertices = <_V3>[
    _V3(-1, -1, -1),
    _V3(1, -1, -1),
    _V3(1, 1, -1),
    _V3(-1, 1, -1),
    _V3(-1, -1, 1),
    _V3(1, -1, 1),
    _V3(1, 1, 1),
    _V3(-1, 1, 1),
  ];

  static const _cubeFaces = <_Face>[
    _Face(
      index: 0,
      vertices: [4, 5, 6, 7],
      normal: _V3(0, 0, 1),
      xAxis: _V3(1, 0, 0),
      yAxis: _V3(0, 1, 0),
    ),
    _Face(
      index: 5,
      vertices: [1, 0, 3, 2],
      normal: _V3(0, 0, -1),
      xAxis: _V3(-1, 0, 0),
      yAxis: _V3(0, 1, 0),
    ),
    _Face(
      index: 1,
      vertices: [0, 1, 5, 4],
      normal: _V3(0, -1, 0),
      xAxis: _V3(1, 0, 0),
      yAxis: _V3(0, 0, 1),
    ),
    _Face(
      index: 4,
      vertices: [3, 7, 6, 2],
      normal: _V3(0, 1, 0),
      xAxis: _V3(1, 0, 0),
      yAxis: _V3(0, 0, -1),
    ),
    _Face(
      index: 2,
      vertices: [1, 2, 6, 5],
      normal: _V3(1, 0, 0),
      xAxis: _V3(0, 0, -1),
      yAxis: _V3(0, 1, 0),
    ),
    _Face(
      index: 3,
      vertices: [0, 4, 7, 3],
      normal: _V3(-1, 0, 0),
      xAxis: _V3(0, 0, 1),
      yAxis: _V3(0, 1, 0),
    ),
  ];

  _V3 _rotate(_V3 p, _Rotation3 rotation) {
    final cx = math.cos(rotation.x);
    final sx = math.sin(rotation.x);
    final cy = math.cos(rotation.y);
    final sy = math.sin(rotation.y);
    final cz = math.cos(rotation.z);
    final sz = math.sin(rotation.z);
    var x = p.x;
    var y = p.y * cx - p.z * sx;
    var z = p.y * sx + p.z * cx;
    final x2 = x * cy + z * sy;
    final z2 = -x * sy + z * cy;
    x = x2;
    z = z2;
    return _V3(x * cz - y * sz, x * sz + y * cz, z);
  }

  Offset _project(_V3 p, Offset center, double scale) {
    const camera = 4.6;
    final perspective = camera / (camera - p.z);
    return Offset(
      center.dx + p.x * scale * perspective,
      center.dy + p.y * scale * perspective,
    );
  }

  _Rotation3 _targetForFace(int face) => switch (face) {
    0 => const _Rotation3(0, 0, 0),
    1 => const _Rotation3(-math.pi / 2, 0, 0),
    2 => const _Rotation3(0, -math.pi / 2, 0),
    3 => const _Rotation3(0, math.pi / 2, 0),
    4 => const _Rotation3(math.pi / 2, 0, 0),
    _ => const _Rotation3(0, math.pi, 0),
  };

  List<Offset> _dieOffsets(int count) => switch (count) {
    1 => const [Offset.zero],
    2 => const [Offset(-24, 0), Offset(24, 0)],
    _ => const [Offset(-27, -17), Offset(27, -17), Offset(0, 29)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2 - 5;
    final radius = baseRadius + (pressed ? 3.5 : 0);
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white.withValues(alpha: pressed ? 0.055 : 0.035),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: pressed ? 0.82 : 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pressed ? 1.55 : 1.35,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - (pressed ? 8 : 5)),
      math.pi * (pressed ? 1.07 : 1.12),
      math.pi * (pressed ? 0.73 : 0.64),
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: pressed ? 0.30 : 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pressed ? 2.55 : 2.2,
    );

    final visualScale = math.min(size.width, size.height) / 140;
    if (choices.isEmpty) {
      _paintSpider(canvas, center, baseRadius, visualScale);
      return;
    }
    final offsets = _dieOffsets(choices.length)
        .map((offset) => offset * visualScale)
        .toList(growable: false);
    final squeeze = pressed ? 0.72 : 1.0;
    for (var i = 0; i < choices.length; i += 1) {
      final choice = choices[i];
      final instanceId = instanceIds[i];
      final face = faces[instanceId] ?? 0;
      final plan = plans[instanceId];
      final rotation = plan?.rotationAt(progress) ?? _targetForFace(face);
      var dieCenter = center + offsets[i] * squeeze;
      if (plan != null && progress < 1) {
        final decay = math.pow(1 - progress, 2).toDouble();
        final wobble =
            math.sin(progress * math.pi * 8 + plan.bouncePhase) * 5.5 * decay;
        dieCenter += Offset(
          math.cos(plan.bounceAngle) * wobble,
          math.sin(plan.bounceAngle) * wobble,
        );
      }
      _paintDie(
        canvas,
        dieCenter,
        13.8 * visualScale * squeeze,
        choice.kind,
        rotation,
      );
    }
  }

  void _paintSpider(
    Canvas canvas,
    Offset center,
    double bubbleRadius,
    double visualScale,
  ) {
    final from = diceBubbleSpiderPoint(math.max(0, rollSerial - 1));
    final to = diceBubbleSpiderPoint(rollSerial);
    final eased = 1 - math.pow(1 - progress.clamp(0.0, 1.0), 3).toDouble();
    final base = Offset.lerp(from, to, eased)! * (bubbleRadius * 0.82);
    final skitterEnvelope = math.sin(math.pi * progress.clamp(0.0, 1.0));
    final skitterAngle = rollSerial * 1.7 + progress * math.pi * 14;
    final jitter =
        Offset(math.cos(skitterAngle), math.sin(skitterAngle * 1.13)) *
        (bubbleRadius * 0.065 * skitterEnvelope);
    final position = center + base + jitter;
    final motion = to - from;
    final heading = motion.distance < 0.001
        ? -math.pi / 2
        : math.atan2(motion.dy, motion.dx);
    final bodyScale = visualScale * (pressed ? 0.82 : 1.0);
    final white = Paint()
      ..color = Colors.white.withValues(alpha: 0.94)
      ..style = PaintingStyle.fill;
    final leg = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.25 * visualScale)
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(heading);
    final legSwing =
        math.sin(progress * math.pi * 18 + rollSerial) *
        2.3 *
        visualScale *
        skitterEnvelope;
    for (var side = -1; side <= 1; side += 2) {
      for (var i = 0; i < 4; i += 1) {
        final y = (-7.2 + i * 4.8) * bodyScale;
        final root = Offset(side * 2.5 * bodyScale, y * 0.68);
        final knee = Offset(
          side * (7.0 + i * 0.55) * bodyScale,
          y + (i.isEven ? legSwing : -legSwing),
        );
        final foot = Offset(
          side * (11.5 + i * 0.7) * bodyScale,
          y + (i.isEven ? -2.2 : 2.2) * bodyScale,
        );
        final path = Path()
          ..moveTo(root.dx, root.dy)
          ..lineTo(knee.dx, knee.dy)
          ..lineTo(foot.dx, foot.dy);
        canvas.drawPath(path, leg);
      }
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 1.5 * bodyScale),
        width: 8.0 * bodyScale,
        height: 12.5 * bodyScale,
      ),
      white,
    );
    canvas.drawCircle(Offset(0, -6.0 * bodyScale), 3.4 * bodyScale, white);
    canvas.restore();
  }

  void _paintDie(
    Canvas canvas,
    Offset center,
    double scale,
    ArcadeDieKind kind,
    _Rotation3 rotation,
  ) {
    final rotated = [for (final vertex in _vertices) _rotate(vertex, rotation)];
    final projected = [
      for (final vertex in rotated) _project(vertex, center, scale),
    ];
    final visible = <({_Face face, double depth, _V3 normal})>[];
    for (final face in _cubeFaces) {
      final normal = _rotate(face.normal, rotation);
      if (normal.z <= 0.02) continue;
      final depth =
          face.vertices
              .map((index) => rotated[index].z)
              .reduce((a, b) => a + b) /
          4;
      visible.add((face: face, depth: depth, normal: normal));
    }
    visible.sort((a, b) => a.depth.compareTo(b.depth));

    final darkBody = arcadeDieUsesDarkBody(kind);
    final facePaint = Paint()
      ..color = darkBody
          ? Colors.black.withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.90);
    final edgePaint = Paint()
      ..color = darkBody
          ? Colors.white.withValues(alpha: 0.88)
          : Colors.black.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final item in visible) {
      final face = item.face;
      final path = Path();
      for (var i = 0; i < face.vertices.length; i += 1) {
        final p = projected[face.vertices[i]];
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, facePaint);
      canvas.drawPath(path, edgePaint);
      _paintFaceMark(canvas, center, scale, rotation, face, kind);
    }
  }

  Offset _facePoint(
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    double x,
    double y,
  ) {
    final local =
        face.normal.scale(1.012) + face.xAxis.scale(x) + face.yAxis.scale(y);
    return _project(_rotate(local, rotation), center, scale);
  }

  void _projectedDisc(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    double x,
    double y,
    double radius,
    Paint paint,
  ) {
    final path = Path();
    for (var i = 0; i <= 18; i += 1) {
      final angle = i * 2 * math.pi / 18;
      final p = _facePoint(
        center,
        scale,
        rotation,
        face,
        x + math.cos(angle) * radius,
        y + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  List<Offset> _pipPattern(int value) {
    const a = 0.45;
    return switch (value) {
      1 => const [Offset.zero],
      2 => const [Offset(-a, -a), Offset(a, a)],
      3 => const [Offset(-a, -a), Offset.zero, Offset(a, a)],
      4 => const [Offset(-a, -a), Offset(a, -a), Offset(-a, a), Offset(a, a)],
      5 => const [
        Offset(-a, -a),
        Offset(a, -a),
        Offset.zero,
        Offset(-a, a),
        Offset(a, a),
      ],
      _ => const [
        Offset(-a, -a),
        Offset(-a, 0),
        Offset(-a, a),
        Offset(a, -a),
        Offset(a, 0),
        Offset(a, a),
      ],
    };
  }

  void _paintFaceMark(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    ArcadeDieKind kind,
  ) {
    final darkBody = arcadeDieUsesDarkBody(kind);
    final mark = Paint()
      ..color = (darkBody ? Colors.white : Colors.black).withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    switch (kind) {
      case ArcadeDieKind.standard:
        for (final pip in _pipPattern(face.index + 1)) {
          _projectedDisc(
            canvas,
            center,
            scale,
            rotation,
            face,
            pip.dx,
            pip.dy,
            0.145,
            mark,
          );
        }
      case ArcadeDieKind.lightning:
        _paintLightningMark(canvas, center, scale, rotation, face, mark);
      case ArcadeDieKind.pyramid:
        _paintPyramidMark(canvas, center, scale, rotation, face, mark);
      case ArcadeDieKind.treehouse:
        const labels = ['AIM', 'DIG', 'HOP', 'SWAP', 'TIP', 'WILD'];
        _paintFaceText(
          canvas,
          center,
          scale,
          rotation,
          face,
          labels[face.index],
          mark.color,
          diagonal: true,
          sizeFactor: 1.28,
        );
      case ArcadeDieKind.color:
        _paintColorMark(canvas, center, scale, rotation, face, mark);
      case ArcadeDieKind.fate:
        final symbol = fateDieFaceSymbol(face.index);
        if (symbol.isNotEmpty) {
          _paintFaceText(
            canvas,
            center,
            scale,
            rotation,
            face,
            symbol,
            mark.color,
            sizeFactor: 1.55,
          );
        }
    }
  }

  void _projectedPolygon(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    List<Offset> points,
    Paint paint,
  ) {
    final path = Path();
    for (var i = 0; i < points.length; i += 1) {
      final p = _facePoint(
        center,
        scale,
        rotation,
        face,
        points[i].dx,
        points[i].dy,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _paintColorMark(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    Paint black,
  ) {
    switch (face.index) {
      case 0: // Pyramid Love: purple spade.
        _projectedPolygon(canvas, center, scale, rotation, face, const [
          Offset(0, -0.60),
          Offset(-0.48, -0.02),
          Offset(-0.46, 0.22),
          Offset(-0.28, 0.36),
          Offset(-0.10, 0.29),
          Offset(-0.16, 0.60),
          Offset(0.16, 0.60),
          Offset(0.10, 0.29),
          Offset(0.28, 0.36),
          Offset(0.46, 0.22),
          Offset(0.48, -0.02),
        ], Paint()..color = Colors.purple);
      case 1: // Pyramid Love: red heart.
        _projectedPolygon(canvas, center, scale, rotation, face, const [
          Offset(0, 0.60),
          Offset(-0.48, 0.08),
          Offset(-0.46, -0.26),
          Offset(-0.25, -0.46),
          Offset(0, -0.26),
          Offset(0.25, -0.46),
          Offset(0.46, -0.26),
          Offset(0.48, 0.08),
        ], Paint()..color = Colors.red);
      case 2: // Pyramid Love: blue diamond.
        _projectedPolygon(canvas, center, scale, rotation, face, const [
          Offset(0, -0.62),
          Offset(0.43, 0),
          Offset(0, 0.62),
          Offset(-0.43, 0),
        ], Paint()..color = Colors.blue);
      case 3: // Pyramid Love: green club.
        final green = Paint()..color = Colors.green;
        _projectedDisc(
          canvas,
          center,
          scale,
          rotation,
          face,
          0,
          -0.30,
          0.25,
          green,
        );
        _projectedDisc(
          canvas,
          center,
          scale,
          rotation,
          face,
          -0.25,
          0.02,
          0.25,
          green,
        );
        _projectedDisc(
          canvas,
          center,
          scale,
          rotation,
          face,
          0.25,
          0.02,
          0.25,
          green,
        );
        _projectedPolygon(canvas, center, scale, rotation, face, const [
          Offset(-0.11, 0.08),
          Offset(0.11, 0.08),
          Offset(0.18, 0.60),
          Offset(-0.18, 0.60),
        ], green);
      case 4: // Pyramid Love: yellow star.
        final star = <Offset>[];
        for (var i = 0; i < 10; i += 1) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? 0.60 : 0.26;
          star.add(Offset(math.cos(angle) * radius, math.sin(angle) * radius));
        }
        _projectedPolygon(
          canvas,
          center,
          scale,
          rotation,
          face,
          star,
          Paint()..color = Colors.yellow,
        );
      case 5: // Pyramid Love: wild atom.
        _paintPyramidLoveContours(
          canvas,
          center,
          scale,
          rotation,
          face,
          pyramidLoveLightningAtomContours,
          black,
        );
    }
  }

  void _paintPyramidLoveContours(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    List<List<Offset>> contours,
    Paint paint,
  ) {
    final path = Path()..fillType = PathFillType.nonZero;
    for (final contour in contours) {
      if (contour.isEmpty) continue;
      final first = _facePoint(
        center,
        scale,
        rotation,
        face,
        contour.first.dx,
        contour.first.dy,
      );
      path.moveTo(first.dx, first.dy);
      for (final point in contour.skip(1)) {
        final projected = _facePoint(
          center,
          scale,
          rotation,
          face,
          point.dx,
          point.dy,
        );
        path.lineTo(projected.dx, projected.dy);
      }
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  void _paintLightningMark(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    Paint fill,
  ) {
    final contours = switch (face.index) {
      0 => pyramidLoveLightningBoltContours,
      1 => pyramidLoveLightningAtomContours,
      2 => pyramidLoveLightningSplitCircleContours,
      3 => pyramidLoveLightningArrowContours,
      4 => pyramidLoveLightningPyramidsContours,
      _ => pyramidLoveLightningRecycleContours,
    };
    _paintPyramidLoveContours(
      canvas,
      center,
      scale,
      rotation,
      face,
      contours,
      fill,
    );
  }

  void _projectedTriangle(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    double x,
    double y,
    double radius,
    Paint paint, {
    bool inverted = false,
    bool filled = true,
  }) {
    // The real Looney Pyramid side profile is tall and isosceles, not an
    // equilateral triangle. LightHouse's measured flat-length/base ratio is
    // about 1.75, so the die mark uses that same silhouette ratio.
    final halfHeight = radius * 0.72;
    final halfBase = halfHeight / pyramidDieHeightToBaseRatio;
    final direction = inverted ? -1.0 : 1.0;
    final points = <Offset>[
      Offset(x, y - halfHeight * direction),
      Offset(x + halfBase, y + halfHeight * direction),
      Offset(x - halfBase, y + halfHeight * direction),
    ];
    final path = Path();
    for (var i = 0; i < points.length; i += 1) {
      final p = _facePoint(
        center,
        scale,
        rotation,
        face,
        points[i].dx,
        points[i].dy,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    if (filled) {
      canvas.drawPath(path, paint);
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, scale * 0.075)
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _paintPyramidFace(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face, {
    required double x,
    required double y,
    required double radius,
    required int pips,
    required Paint paint,
    bool inverted = false,
  }) {
    _projectedTriangle(
      canvas,
      center,
      scale,
      rotation,
      face,
      x,
      y,
      radius,
      paint,
      inverted: inverted,
      filled: false,
    );
    final halfHeight = radius * 0.72;
    final halfBase = halfHeight / pyramidDieHeightToBaseRatio;
    final pipY = y + (inverted ? -halfHeight * 0.16 : halfHeight * 0.16);
    final spacing = halfBase * 0.62;
    final startX = x - spacing * (pips - 1) / 2;
    for (var i = 0; i < pips; i += 1) {
      _projectedDisc(
        canvas,
        center,
        scale,
        rotation,
        face,
        startX + i * spacing,
        pipY,
        math.max(0.045, halfBase * 0.18),
        paint,
      );
    }
  }

  void _paintPyramidMark(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    Paint paint,
  ) {
    switch (face.index) {
      case 0: // Small.
        _paintPyramidFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          x: 0,
          y: 0.04,
          radius: 0.42,
          pips: 1,
          paint: paint,
        );
      case 1: // Medium.
        _paintPyramidFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          x: 0,
          y: 0.04,
          radius: 0.50,
          pips: 2,
          paint: paint,
        );
      case 2: // Large.
        _paintPyramidFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          x: 0,
          y: 0.03,
          radius: 0.58,
          pips: 3,
          paint: paint,
        );
      case 3: // Small + Medium.
        _paintPyramidFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          x: -0.28,
          y: -0.12,
          radius: 0.31,
          pips: 1,
          paint: paint,
          inverted: true,
        );
        _paintPyramidFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          x: 0.26,
          y: 0.18,
          radius: 0.39,
          pips: 2,
          paint: paint,
        );
      case 4: // Small + Large.
        _paintPyramidFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          x: -0.31,
          y: -0.14,
          radius: 0.30,
          pips: 1,
          paint: paint,
          inverted: true,
        );
        _paintPyramidFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          x: 0.23,
          y: 0.18,
          radius: 0.47,
          pips: 3,
          paint: paint,
        );
      case 5: // Medium + Large.
        _paintPyramidFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          x: -0.31,
          y: -0.14,
          radius: 0.34,
          pips: 2,
          paint: paint,
          inverted: true,
        );
        _paintPyramidFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          x: 0.24,
          y: 0.18,
          radius: 0.47,
          pips: 3,
          paint: paint,
        );
    }
  }

  void _paintFaceText(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    String text,
    Color color, {
    bool diagonal = false,
    double sizeFactor = 1,
  }) {
    final c = _facePoint(center, scale, rotation, face, 0, 0);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize:
              math.max(5.5, scale * (text.length > 3 ? 0.42 : 0.50)) *
              sizeFactor,
          fontWeight: FontWeight.w900,
          letterSpacing: text.length > 3 ? -0.65 : -0.35,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (diagonal) {
      final px = _facePoint(center, scale, rotation, face, 0.45, 0);
      final py = _facePoint(center, scale, rotation, face, 0, 0.45);
      final diagonalVector = (px - c) + (py - c);
      canvas.rotate(math.atan2(diagonalVector.dy, diagonalVector.dx));
    }
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiceBubblePainter oldDelegate) =>
      !listEquals(oldDelegate.instanceIds, instanceIds) ||
      !listEquals(oldDelegate.choices, choices) ||
      !mapEquals(oldDelegate.faces, faces) ||
      !mapEquals(oldDelegate.plans, plans) ||
      oldDelegate.progress != progress ||
      oldDelegate.rollSerial != rollSerial ||
      oldDelegate.pressed != pressed;
}
