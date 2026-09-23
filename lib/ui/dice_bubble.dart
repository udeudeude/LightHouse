import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_language.dart';
import 'pyramid_love_lightning_paths.dart';

enum ArcadeDieKind {
  standard,
  lightning,
  pyramid,
  treehouse,
  color,
  fate,
  d4,
  d8,
  d10,
  d12,
  d20,
}

int arcadeDieSides(ArcadeDieKind kind) => switch (kind) {
  ArcadeDieKind.d4 => 4,
  ArcadeDieKind.d8 => 8,
  ArcadeDieKind.d10 => 10,
  ArcadeDieKind.d12 => 12,
  ArcadeDieKind.d20 => 20,
  _ => 6,
};

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
  ArcadeDieChoice('d4', ArcadeDieKind.d4, 'D4'),
  ArcadeDieChoice('d8', ArcadeDieKind.d8, 'D8'),
  ArcadeDieChoice('d10', ArcadeDieKind.d10, 'D10'),
  ArcadeDieChoice('d12', ArcadeDieKind.d12, 'D12'),
  ArcadeDieChoice('d20', ArcadeDieKind.d20, 'D20'),
];

String arcadeDieBaseId(String instanceId) {
  if (instanceId.contains('#')) return instanceId.split('#').first;
  if (instanceId.startsWith('standard-')) return 'standard';
  if (instanceId.startsWith('lightning-')) return 'lightning';
  return instanceId;
}

bool isKnownArcadeDieInstance(String instanceId) =>
    arcadeDiceChoices.any((choice) => choice.id == arcadeDieBaseId(instanceId));

ArcadeDieChoice? arcadeDieChoiceForInstance(String instanceId) {
  final baseId = arcadeDieBaseId(instanceId);
  return arcadeDiceChoices.where((choice) => choice.id == baseId).firstOrNull;
}

int arcadeDieSidesForInstance(String instanceId) {
  final choice = arcadeDieChoiceForInstance(instanceId);
  return choice == null ? 6 : arcadeDieSides(choice.kind);
}

class DiceBubbleSnapshot {
  const DiceBubbleSnapshot({
    required this.revision,
    required this.rollSerial,
    required this.selectedIds,
    required this.faces,
    required this.xFraction,
    required this.yFraction,
    this.sizeScale = 1.0,
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
  final double sizeScale;

  Map<String, Object?> toJson() => {
    'revision': revision,
    'rollSerial': rollSerial,
    'selectedIds': selectedIds,
    'faces': faces,
    'xFraction': xFraction,
    'yFraction': yFraction,
    'sizeScale': sizeScale,
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
          final id = entry.key as String;
          final value = (entry.value as num).toInt();
          final sides = arcadeDieSidesForInstance(id);
          if (value >= 0 && value < sides) faces[id] = value;
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
        sizeScale: ((map['sizeScale'] as num?)?.toDouble() ?? 1.0)
            .clamp(0.65, 2.4)
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
  double get _baseScale => widget.scale.clamp(0.25, 4.0);
  double get _radius => 70 * _baseScale * _bubbleScale;
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
  bool _pickerOpen = false;
  bool _spiderRevealed = false;
  bool _twoFingerMove = false;
  bool _gestureMoved = false;
  double _gestureTravel = 0;
  double _bubbleScale = 1.0;
  double _gestureStartBubbleScale = 1.0;

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
    _bubbleScale = snapshot.sizeScale.clamp(0.65, 2.4).toDouble();
    if (_surfaceSize != Size.zero) {
      _bubbleScale = math
          .min(_bubbleScale, _maximumBubbleScaleFor(_surfaceSize))
          .toDouble();
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
      final kind = _choice(id).kind;
      final start = _targetForFace(oldFace, kind: kind);
      final target = _targetForFace(face, kind: kind);
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
        sizeScale: _bubbleScale,
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
        _faces[id] = _random.nextInt(arcadeDieSides(choice.kind));
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

  _Rotation3 _targetForFace(
    int face, {
    ArcadeDieKind kind = ArcadeDieKind.standard,
  }) {
    if (_isPolyhedralKind(kind)) return _polyTargetForFace(kind, face);
    return switch (face) {
      0 => const _Rotation3(0, 0, 0),
      1 => const _Rotation3(-math.pi / 2, 0, 0),
      2 => const _Rotation3(0, -math.pi / 2, 0),
      3 => const _Rotation3(0, math.pi / 2, 0),
      4 => const _Rotation3(math.pi / 2, 0, 0),
      _ => const _Rotation3(0, math.pi, 0),
    };
  }

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
      final choice = _choice(id);
      final sides = arcadeDieSides(choice.kind);
      final old =
          _plans[id]?.rotationAt(1) ??
          _targetForFace(_faces[id] ?? 0, kind: choice.kind);
      final start = _Rotation3(
        _normalize(old.x),
        _normalize(old.y),
        _normalize(old.z),
      );
      final face = _random.nextInt(sides);
      final target = _targetForFace(face, kind: choice.kind);
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

  double _maximumBubbleScaleFor(Size size) {
    if (size == Size.zero) return 2.4;
    final availableRadius =
        (math.min(size.width, size.height) - 8)
            .clamp(42.0, double.infinity)
            .toDouble() /
        2;
    return math
        .max(0.65, math.min(2.4, availableRadius / (70 * _baseScale)))
        .toDouble();
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
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: darkBody ? Colors.black : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: darkBody ? Colors.white70 : Colors.black87),
      ),
      child: CustomPaint(
        painter: _DieSelectorMarkPainter(
          kind: choice.kind,
          foreground: foreground,
        ),
      ),
    );
  }

  Future<void> _showPicker() async {
    HapticFeedback.selectionClick();
    if (mounted) {
      setState(() {
        _pickerOpen = true;
        _spiderRevealed = false;
      });
    }
    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF202020),
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                        child: Text(
                          '${tr('Dice')} · ${_selectedIds.length}/3 ${tr('selected')}',
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
                              mainAxisExtent: 112,
                            ),
                        itemCount: arcadeDiceChoices.length,
                        itemBuilder: (context, index) {
                          final choice = arcadeDiceChoices[index];
                          final count = _choiceCount(choice.id);
                          final canAdd = count < _maximumChoiceCount(choice);
                          return Tooltip(
                            message: tr(choice.label),
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
                                        tooltip:
                                            '${tr('Remove one')} ${tr(choice.label)}',
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
                                        icon: const Icon(
                                          Icons.remove,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      bottom: 2,
                                      child: IconButton(
                                        tooltip:
                                            '${tr('Add one')} ${tr(choice.label)}',
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
              ),
            );
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pickerOpen = false;
          _spiderRevealed = _selectedIds.isEmpty;
        });
      }
    }
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
      _bubbleScale = math
          .min(_bubbleScale, _maximumBubbleScaleFor(size))
          .toDouble();
      final selected = [for (final id in _selectedIds) _choice(id)];
      return Stack(
        children: [
          Positioned(
            left: _center.dx - _radius,
            top: _center.dy - _radius,
            width: _radius * 2,
            height: _radius * 2,
            child: GestureDetector(
              key: const Key('dice-bubble-gesture'),
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _twoFingerMove = details.pointerCount >= 2;
                _gestureMoved = false;
                _gestureTravel = 0;
                _gestureStartBubbleScale = _bubbleScale;
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
                final maximumScale = _maximumBubbleScaleFor(size);
                final nextBubbleScale =
                    (_gestureStartBubbleScale * details.scale)
                        .clamp(0.65, maximumScale)
                        .toDouble();
                if (details.focalPointDelta.distance > 0 ||
                    (nextBubbleScale - _bubbleScale).abs() > 0.002) {
                  _gestureMoved = true;
                }
                setState(() {
                  _pressed = false;
                  _bubbleScale = nextBubbleScale;
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
                      showSpider: !_pickerOpen && _spiderRevealed,
                      spiderVisualScale: _baseScale,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      key: const Key('dice-selector-latch'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _showPicker,
                      child: Container(
                        width: 12 * _baseScale,
                        height: 38 * _baseScale,
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

class _DieSelectorMarkPainter extends CustomPainter {
  const _DieSelectorMarkPainter({required this.kind, required this.foreground});

  final ArcadeDieKind kind;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    switch (kind) {
      case ArcadeDieKind.standard:
        _paintStandard(canvas, size);
      case ArcadeDieKind.lightning:
        _paintLightning(canvas, center, size);
      case ArcadeDieKind.pyramid:
        _paintPyramid(canvas, center, size);
      case ArcadeDieKind.treehouse:
        _paintTreehouse(canvas, center, size);
      case ArcadeDieKind.color:
        _paintColor(canvas, center, size);
      case ArcadeDieKind.fate:
        _paintFate(canvas, center, size);
      case ArcadeDieKind.d4:
        _paintPolySelector(canvas, center, size, 4);
      case ArcadeDieKind.d8:
        _paintPolySelector(canvas, center, size, 8);
      case ArcadeDieKind.d10:
        _paintPolySelector(canvas, center, size, 10);
      case ArcadeDieKind.d12:
        _paintPolySelector(canvas, center, size, 12);
      case ArcadeDieKind.d20:
        _paintPolySelector(canvas, center, size, 20);
    }
  }

  void _paintStandard(Canvas canvas, Size size) {
    final paint = Paint()..color = foreground;
    final radius = size.shortestSide * 0.083;
    final left = size.width * 0.29;
    final right = size.width * 0.71;
    final top = size.height * 0.29;
    final bottom = size.height * 0.71;
    for (final point in [
      Offset(left, top),
      Offset(right, top),
      Offset(size.width / 2, size.height / 2),
      Offset(left, bottom),
      Offset(right, bottom),
    ]) {
      canvas.drawCircle(point, radius, paint);
    }
  }

  void _paintLightning(Canvas canvas, Offset center, Size size) {
    final path = Path()..fillType = PathFillType.nonZero;
    final scale = size.shortestSide * 0.62;
    for (final contour in pyramidLoveLightningBoltContours) {
      if (contour.isEmpty) continue;
      path.moveTo(
        center.dx + contour.first.dx * scale,
        center.dy + contour.first.dy * scale,
      );
      for (final point in contour.skip(1)) {
        path.lineTo(center.dx + point.dx * scale, center.dy + point.dy * scale);
      }
      path.close();
    }
    canvas.drawPath(path, Paint()..color = foreground);
  }

  void _paintPyramid(Canvas canvas, Offset center, Size size) {
    final height = size.height * 0.58;
    final halfHeight = height / 2;
    final halfBase = halfHeight / pyramidDieHeightToBaseRatio;
    final path = Path()
      ..moveTo(center.dx, center.dy - halfHeight)
      ..lineTo(center.dx + halfBase, center.dy + halfHeight)
      ..lineTo(center.dx - halfBase, center.dy + halfHeight)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, size.shortestSide * 0.045)
        ..strokeJoin = StrokeJoin.round,
    );
    final pipRadius = size.shortestSide * 0.045;
    final spacing = halfBase * 0.54;
    for (var i = -1; i <= 1; i += 1) {
      canvas.drawCircle(
        Offset(center.dx + spacing * i, center.dy + halfHeight * 0.68),
        pipRadius,
        Paint()..color = foreground,
      );
    }
  }

  void _paintTreehouse(Canvas canvas, Offset center, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'AIM',
        style: TextStyle(
          color: foreground,
          fontSize: size.shortestSide * 0.38,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  void _paintColor(Canvas canvas, Offset center, Size size) {
    final unit = size.shortestSide;
    final diamond = Path()
      ..moveTo(center.dx, center.dy - unit * 0.22)
      ..lineTo(center.dx + unit * 0.15, center.dy)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..lineTo(center.dx - unit * 0.15, center.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = Colors.blue);

    final heartCenter = center + Offset(-unit * 0.22, -unit * 0.18);
    final heart = Path()
      ..moveTo(heartCenter.dx, heartCenter.dy + unit * 0.13)
      ..cubicTo(
        heartCenter.dx - unit * 0.20,
        heartCenter.dy,
        heartCenter.dx - unit * 0.10,
        heartCenter.dy - unit * 0.16,
        heartCenter.dx,
        heartCenter.dy - unit * 0.06,
      )
      ..cubicTo(
        heartCenter.dx + unit * 0.10,
        heartCenter.dy - unit * 0.16,
        heartCenter.dx + unit * 0.20,
        heartCenter.dy,
        heartCenter.dx,
        heartCenter.dy + unit * 0.13,
      )
      ..close();
    canvas.drawPath(heart, Paint()..color = Colors.red);

    final clubCenter = center + Offset(unit * 0.23, -unit * 0.17);
    final green = Paint()..color = Colors.green;
    final clubRadius = unit * 0.075;
    canvas.drawCircle(clubCenter + Offset(0, -clubRadius), clubRadius, green);
    canvas.drawCircle(
      clubCenter + Offset(-clubRadius * 0.85, clubRadius * 0.25),
      clubRadius,
      green,
    );
    canvas.drawCircle(
      clubCenter + Offset(clubRadius * 0.85, clubRadius * 0.25),
      clubRadius,
      green,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: clubCenter + Offset(0, clubRadius * 1.25),
        width: clubRadius * 0.72,
        height: clubRadius * 1.7,
      ),
      green,
    );

    final starCenter = center + Offset(-unit * 0.22, unit * 0.19);
    final star = Path();
    for (var i = 0; i < 10; i += 1) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final radius = unit * (i.isEven ? 0.105 : 0.045);
      final point =
          starCenter + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = Colors.yellow);

    final spadeCenter = center + Offset(unit * 0.22, unit * 0.20);
    final purple = Paint()..color = Colors.purple;
    final spade = Path()
      ..moveTo(spadeCenter.dx, spadeCenter.dy - unit * 0.12)
      ..lineTo(spadeCenter.dx - unit * 0.10, spadeCenter.dy + unit * 0.01)
      ..quadraticBezierTo(
        spadeCenter.dx - unit * 0.09,
        spadeCenter.dy + unit * 0.10,
        spadeCenter.dx,
        spadeCenter.dy + unit * 0.05,
      )
      ..quadraticBezierTo(
        spadeCenter.dx + unit * 0.09,
        spadeCenter.dy + unit * 0.10,
        spadeCenter.dx + unit * 0.10,
        spadeCenter.dy + unit * 0.01,
      )
      ..close();
    canvas.drawPath(spade, purple);
    canvas.drawRect(
      Rect.fromCenter(
        center: spadeCenter + Offset(0, unit * 0.08),
        width: unit * 0.035,
        height: unit * 0.11,
      ),
      purple,
    );
  }

  void _paintFate(Canvas canvas, Offset center, Size size) {
    final unit = size.shortestSide;
    final paint = Paint()..color = foreground;
    _paintVectorPlus(
      canvas,
      center + Offset(-unit * 0.15, 0),
      unit * 0.16,
      unit * 0.045,
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + Offset(unit * 0.20, 0),
          width: unit * 0.27,
          height: unit * 0.085,
        ),
        Radius.circular(unit * 0.025),
      ),
      paint,
    );
  }

  void _paintPolySelector(Canvas canvas, Offset center, Size size, int sides) {
    final unit = size.shortestSide;
    final outline = Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, unit * 0.04)
      ..strokeJoin = StrokeJoin.round;
    final radius = unit * 0.31;
    final vertices = switch (sides) {
      4 => 3,
      8 => 4,
      10 => 10,
      12 => 5,
      _ => 6,
    };
    final path = Path();
    for (var i = 0; i < vertices; i += 1) {
      final angle = -math.pi / 2 + i * 2 * math.pi / vertices;
      final r = sides == 10 && i.isOdd ? radius * 0.78 : radius;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, outline);

    if (sides == 8) {
      canvas.drawLine(
        center + Offset(-radius, 0),
        center + Offset(radius, 0),
        outline,
      );
    } else if (sides == 12) {
      canvas.drawCircle(center, radius * 0.46, outline);
    } else if (sides == 20) {
      for (var i = 0; i < 3; i += 1) {
        final angle = -math.pi / 2 + i * 2 * math.pi / 3;
        canvas.drawLine(
          center,
          center + Offset(math.cos(angle), math.sin(angle)) * radius,
          outline,
        );
      }
    }

    final painter = TextPainter(
      text: TextSpan(
        text: 'D$sides',
        style: TextStyle(
          color: foreground,
          fontSize: unit * 0.22,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintVectorPlus(
    Canvas canvas,
    Offset center,
    double halfExtent,
    double halfThickness,
    Paint paint,
  ) {
    final path = Path()
      ..moveTo(center.dx - halfThickness, center.dy - halfExtent)
      ..lineTo(center.dx + halfThickness, center.dy - halfExtent)
      ..lineTo(center.dx + halfThickness, center.dy - halfThickness)
      ..lineTo(center.dx + halfExtent, center.dy - halfThickness)
      ..lineTo(center.dx + halfExtent, center.dy + halfThickness)
      ..lineTo(center.dx + halfThickness, center.dy + halfThickness)
      ..lineTo(center.dx + halfThickness, center.dy + halfExtent)
      ..lineTo(center.dx - halfThickness, center.dy + halfExtent)
      ..lineTo(center.dx - halfThickness, center.dy + halfThickness)
      ..lineTo(center.dx - halfExtent, center.dy + halfThickness)
      ..lineTo(center.dx - halfExtent, center.dy - halfThickness)
      ..lineTo(center.dx - halfThickness, center.dy - halfThickness)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DieSelectorMarkPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.foreground != foreground;
}

class _V3 {
  const _V3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  _V3 operator +(_V3 other) => _V3(x + other.x, y + other.y, z + other.z);
  _V3 operator -(_V3 other) => _V3(x - other.x, y - other.y, z - other.z);
  _V3 scale(double amount) => _V3(x * amount, y * amount, z * amount);

  double dot(_V3 other) => x * other.x + y * other.y + z * other.z;

  _V3 cross(_V3 other) => _V3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );

  double get length => math.sqrt(x * x + y * y + z * z);

  _V3 get normalized {
    final magnitude = length;
    if (magnitude <= 1e-9) return const _V3(0, 0, 0);
    return scale(1 / magnitude);
  }
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

class _PolyMesh {
  const _PolyMesh(this.vertices, this.faces);

  final List<_V3> vertices;
  final List<_Face> faces;
}

bool _isPolyhedralKind(ArcadeDieKind kind) => switch (kind) {
  ArcadeDieKind.d4 ||
  ArcadeDieKind.d8 ||
  ArcadeDieKind.d10 ||
  ArcadeDieKind.d12 ||
  ArcadeDieKind.d20 => true,
  _ => false,
};

_V3 _averageVertices(List<_V3> vertices, List<int> indices) {
  var sum = const _V3(0, 0, 0);
  for (final index in indices) {
    sum = sum + vertices[index];
  }
  return sum.scale(1 / indices.length);
}

_PolyMesh _buildPolyMesh(List<_V3> rawVertices, List<List<int>> rawFaces) {
  final maxRadius = rawVertices.map((vertex) => vertex.length).reduce(math.max);
  final vertices = [
    for (final vertex in rawVertices) vertex.scale(1 / maxRadius),
  ];

  final faces = <_Face>[];
  for (var faceIndex = 0; faceIndex < rawFaces.length; faceIndex += 1) {
    var indices = List<int>.from(rawFaces[faceIndex]);
    var center = _averageVertices(vertices, indices);
    var normal = (vertices[indices[1]] - vertices[indices[0]])
        .cross(vertices[indices[2]] - vertices[indices[0]])
        .normalized;
    if (normal.dot(center) < 0) {
      indices = indices.reversed.toList(growable: false);
      center = _averageVertices(vertices, indices);
      normal = (vertices[indices[1]] - vertices[indices[0]])
          .cross(vertices[indices[2]] - vertices[indices[0]])
          .normalized;
    }
    final xAxis = (vertices[indices[1]] - vertices[indices[0]]).normalized;
    final yAxis = normal.cross(xAxis).normalized;
    faces.add(
      _Face(
        index: faceIndex,
        vertices: List<int>.unmodifiable(indices),
        normal: normal,
        xAxis: xAxis,
        yAxis: yAxis,
      ),
    );
  }
  return _PolyMesh(
    List<_V3>.unmodifiable(vertices),
    List<_Face>.unmodifiable(faces),
  );
}

final _tetrahedronMesh = _buildPolyMesh(
  const [_V3(1, 1, 1), _V3(1, -1, -1), _V3(-1, 1, -1), _V3(-1, -1, 1)],
  const [
    [0, 1, 2],
    [0, 3, 1],
    [0, 2, 3],
    [1, 3, 2],
  ],
);

final _octahedronMesh = _buildPolyMesh(
  const [
    _V3(1, 0, 0),
    _V3(0, 1, 0),
    _V3(-1, 0, 0),
    _V3(0, -1, 0),
    _V3(0, 0, 1),
    _V3(0, 0, -1),
  ],
  const [
    [4, 0, 1],
    [4, 1, 2],
    [4, 2, 3],
    [4, 3, 0],
    [5, 1, 0],
    [5, 2, 1],
    [5, 3, 2],
    [5, 0, 3],
  ],
);

final _d10Mesh = _buildPolyMesh(
  const [
    _V3(0, 0.3090169944, 0.8090169944),
    _V3(0, 0.3090169944, -0.8090169944),
    _V3(0, -0.3090169944, 0.8090169944),
    _V3(0, -0.3090169944, -0.8090169944),
    _V3(0.5, 0.5, 0.5),
    _V3(0.5, 0.5, -0.5),
    _V3(-0.5, -0.5, 0.5),
    _V3(-0.5, -0.5, -0.5),
    _V3(1.3090169944, -0.8090169944, 0),
    _V3(-1.3090169944, 0.8090169944, 0),
    _V3(0.3090169944, 0.8090169944, 0),
    _V3(-0.3090169944, -0.8090169944, 0),
  ],
  const [
    [8, 2, 6, 11],
    [8, 11, 7, 3],
    [8, 3, 1, 5],
    [8, 5, 10, 4],
    [8, 4, 0, 2],
    [9, 0, 4, 10],
    [9, 10, 5, 1],
    [9, 1, 3, 7],
    [9, 7, 11, 6],
    [9, 6, 2, 0],
  ],
);

final _icosahedronMesh = _buildPolyMesh(
  const [
    _V3(-1, 1.61803398875, 0),
    _V3(1, 1.61803398875, 0),
    _V3(-1, -1.61803398875, 0),
    _V3(1, -1.61803398875, 0),
    _V3(0, -1, 1.61803398875),
    _V3(0, 1, 1.61803398875),
    _V3(0, -1, -1.61803398875),
    _V3(0, 1, -1.61803398875),
    _V3(1.61803398875, 0, -1),
    _V3(1.61803398875, 0, 1),
    _V3(-1.61803398875, 0, -1),
    _V3(-1.61803398875, 0, 1),
  ],
  const [
    [0, 11, 5],
    [0, 5, 1],
    [0, 1, 7],
    [0, 7, 10],
    [0, 10, 11],
    [1, 5, 9],
    [5, 11, 4],
    [11, 10, 2],
    [10, 7, 6],
    [7, 1, 8],
    [3, 9, 4],
    [3, 4, 2],
    [3, 2, 6],
    [3, 6, 8],
    [3, 8, 9],
    [4, 9, 5],
    [2, 4, 11],
    [6, 2, 10],
    [8, 6, 7],
    [9, 8, 1],
  ],
);

_PolyMesh _buildDodecahedronMesh() {
  final source = _icosahedronMesh;
  final dualVertices = [for (final face in source.faces) face.normal];
  final dualFaces = <List<int>>[];
  for (
    var vertexIndex = 0;
    vertexIndex < source.vertices.length;
    vertexIndex += 1
  ) {
    final normal = source.vertices[vertexIndex].normalized;
    final reference = normal.z.abs() < 0.9
        ? const _V3(0, 0, 1)
        : const _V3(1, 0, 0);
    final axisA = normal.cross(reference).normalized;
    final axisB = normal.cross(axisA).normalized;
    final adjacent = <int>[
      for (var faceIndex = 0; faceIndex < source.faces.length; faceIndex += 1)
        if (source.faces[faceIndex].vertices.contains(vertexIndex)) faceIndex,
    ];
    adjacent.sort((a, b) {
      final va = dualVertices[a];
      final vb = dualVertices[b];
      final aa = math.atan2(va.dot(axisB), va.dot(axisA));
      final ab = math.atan2(vb.dot(axisB), vb.dot(axisA));
      return aa.compareTo(ab);
    });
    dualFaces.add(adjacent);
  }
  return _buildPolyMesh(dualVertices, dualFaces);
}

final _dodecahedronMesh = _buildDodecahedronMesh();

_PolyMesh _polyMeshForKind(ArcadeDieKind kind) => switch (kind) {
  ArcadeDieKind.d4 => _tetrahedronMesh,
  ArcadeDieKind.d8 => _octahedronMesh,
  ArcadeDieKind.d10 => _d10Mesh,
  ArcadeDieKind.d12 => _dodecahedronMesh,
  ArcadeDieKind.d20 => _icosahedronMesh,
  _ => throw ArgumentError('Not a polyhedral die: $kind'),
};

_V3 _rotatePolyVector(_V3 p, _Rotation3 rotation) {
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

_Rotation3 _polyTargetForFace(ArcadeDieKind kind, int faceIndex) {
  final mesh = _polyMeshForKind(kind);
  final face = mesh.faces[faceIndex % mesh.faces.length];
  final normal = face.normal;
  final xRotation = math.atan2(normal.y, normal.z);
  final yzLength = math.sqrt(normal.y * normal.y + normal.z * normal.z);
  final yRotation = math.atan2(-normal.x, yzLength);
  final base = _Rotation3(xRotation, yRotation, 0);
  final alignedXAxis = _rotatePolyVector(face.xAxis, base);
  final zRotation = -math.atan2(alignedXAxis.y, alignedXAxis.x);
  return _Rotation3(xRotation, yRotation, zRotation);
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
    required this.showSpider,
    required this.spiderVisualScale,
  });

  final List<String> instanceIds;
  final List<ArcadeDieChoice> choices;
  final Map<String, int> faces;
  final Map<String, _SpinPlan> plans;
  final double progress;
  final int rollSerial;
  final bool pressed;
  final bool showSpider;
  final double spiderVisualScale;

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

  _Rotation3 _targetForFace(
    int face, {
    ArcadeDieKind kind = ArcadeDieKind.standard,
  }) {
    if (_isPolyhedralKind(kind)) return _polyTargetForFace(kind, face);
    return switch (face) {
      0 => const _Rotation3(0, 0, 0),
      1 => const _Rotation3(-math.pi / 2, 0, 0),
      2 => const _Rotation3(0, -math.pi / 2, 0),
      3 => const _Rotation3(0, math.pi / 2, 0),
      4 => const _Rotation3(math.pi / 2, 0, 0),
      _ => const _Rotation3(0, math.pi, 0),
    };
  }

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
      if (showSpider) {
        _paintSpider(canvas, center, baseRadius, spiderVisualScale);
      }
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
      final rotation =
          plan?.rotationAt(progress) ?? _targetForFace(face, kind: choice.kind);
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
        face,
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
    final t = progress.clamp(0.0, 1.0);
    final eased = 1 - math.pow(1 - t, 3).toDouble();
    final travel = Offset.lerp(from, to, eased)! * (bubbleRadius * 0.82);
    final motion = to - from;
    final moving = motion.distance > 0.001 && t < 1;
    final gaitEnvelope = moving ? math.sin(math.pi * t) : 0.0;
    final gaitPhase = t * math.pi * 12 + rollSerial * 0.73;
    final heading = motion.distance < 0.001
        ? -math.pi / 2
        : math.atan2(motion.dy, motion.dx);
    final sideJitter =
        Offset(-math.sin(heading), math.cos(heading)) *
        (math.sin(gaitPhase * 0.53) * bubbleRadius * 0.025 * gaitEnvelope);
    final position = center + travel + sideJitter;
    final scale = visualScale * (pressed ? 0.82 : 1.0);

    final white = Paint()
      ..color = Colors.white.withValues(alpha: 0.96)
      ..style = PaintingStyle.fill;
    final legPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.18 * visualScale)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final eyePaint = Paint()..color = Colors.black.withValues(alpha: 0.84);

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(heading + math.sin(gaitPhase * 0.5) * 0.055 * gaitEnvelope);

    // Local +X is forward. Four articulated legs on each side alternate
    // their stride, producing an eight-legged skitter instead of a body wobble.
    const rootX = <double>[3.2, 1.2, -0.9, -2.8];
    const kneeForward = <double>[3.6, 1.7, -1.3, -3.4];
    const footForward = <double>[8.6, 5.4, -4.8, -8.4];
    const kneeOut = <double>[6.3, 7.8, 7.9, 6.7];
    const footOut = <double>[11.2, 12.8, 12.9, 11.5];

    for (var side = -1; side <= 1; side += 2) {
      for (var pair = 0; pair < 4; pair += 1) {
        final alternating = pair.isEven ? 0.0 : math.pi;
        final sidePhase = side < 0 ? math.pi : 0.0;
        final stride =
            math.sin(gaitPhase + alternating + sidePhase) * gaitEnvelope;
        final lift =
            math.cos(gaitPhase + alternating + sidePhase) * gaitEnvelope;
        final root = Offset(
          rootX[pair] * scale,
          side * (2.0 + pair * 0.28) * scale,
        );
        final knee = Offset(
          (kneeForward[pair] + stride * 1.2) * scale,
          side * (kneeOut[pair] + lift * 0.75) * scale,
        );
        final foot = Offset(
          (footForward[pair] + stride * 2.6) * scale,
          side * (footOut[pair] - lift * 0.9) * scale,
        );
        final path = Path()
          ..moveTo(root.dx, root.dy)
          ..lineTo(knee.dx, knee.dy)
          ..lineTo(foot.dx, foot.dy);
        canvas.drawPath(path, legPaint);
      }
    }

    // Abdomen, narrow waist, and cephalothorax.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-3.9 * scale, 0),
        width: 11.7 * scale,
        height: 9.7 * scale,
      ),
      white,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(2.8 * scale, 0),
        width: 7.5 * scale,
        height: 7.0 * scale,
      ),
      white,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(-0.2 * scale, 0),
        width: 3.1 * scale,
        height: 3.2 * scale,
      ),
      white,
    );

    // Pedipalps make the front read as a spider head rather than an insect.
    for (final side in const [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(5.2 * scale, side * 1.9 * scale)
        ..lineTo(7.2 * scale, side * 3.2 * scale)
        ..lineTo(8.8 * scale, side * 2.5 * scale);
      canvas.drawPath(path, legPaint);
    }

    // Four tiny eyes remain visible even at small scale.
    for (final eye in const [
      Offset(5.0, -1.45),
      Offset(5.0, 1.45),
      Offset(4.25, -0.48),
      Offset(4.25, 0.48),
    ]) {
      canvas.drawCircle(
        eye * scale,
        math.max(0.55, 0.55 * visualScale),
        eyePaint,
      );
    }

    canvas.restore();
  }

  void _paintDie(
    Canvas canvas,
    Offset center,
    double scale,
    ArcadeDieKind kind,
    _Rotation3 rotation,
    int faceIndex,
  ) {
    if ({
      ArcadeDieKind.d4,
      ArcadeDieKind.d8,
      ArcadeDieKind.d10,
      ArcadeDieKind.d12,
      ArcadeDieKind.d20,
    }.contains(kind)) {
      _paintPolyhedralDie(canvas, center, scale, kind, rotation);
      return;
    }

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

  void _paintPolyhedralDie(
    Canvas canvas,
    Offset center,
    double scale,
    ArcadeDieKind kind,
    _Rotation3 rotation,
  ) {
    final mesh = _polyMeshForKind(kind);
    final meshScale =
        scale *
        switch (kind) {
          ArcadeDieKind.d4 => 1.58,
          ArcadeDieKind.d8 => 1.54,
          ArcadeDieKind.d10 => 1.56,
          ArcadeDieKind.d12 => 1.58,
          ArcadeDieKind.d20 => 1.60,
          _ => 1.0,
        };
    final rotated = [
      for (final vertex in mesh.vertices) _rotate(vertex, rotation),
    ];
    final projected = [
      for (final vertex in rotated) _project(vertex, center, meshScale),
    ];

    final visible = <({_Face face, double depth, _V3 normal})>[];
    for (final face in mesh.faces) {
      final normal = _rotate(face.normal, rotation);
      if (normal.z <= 0.015) continue;
      final depth =
          face.vertices
              .map((index) => rotated[index].z)
              .reduce((a, b) => a + b) /
          face.vertices.length;
      visible.add((face: face, depth: depth, normal: normal));
    }
    visible.sort((a, b) => a.depth.compareTo(b.depth));

    final fill = Paint()..color = Colors.white.withValues(alpha: 0.93);
    final edge = Paint()
      ..color = Colors.black.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.9, scale * 0.072)
      ..strokeJoin = StrokeJoin.round;

    for (final item in visible) {
      final face = item.face;
      final polygon = <Offset>[
        for (final index in face.vertices) projected[index],
      ];
      final path = Path();
      for (var i = 0; i < polygon.length; i += 1) {
        final point = polygon[i];
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);

      final worldCenter = _averageVertices(mesh.vertices, face.vertices);
      final rotatedCenter = _rotate(worldCenter, rotation);
      final labelCenter = _project(rotatedCenter, center, meshScale);
      final axisPoint = _project(
        _rotate(worldCenter + face.xAxis.scale(0.24), rotation),
        center,
        meshScale,
      );
      var labelAngle = math.atan2(
        axisPoint.dy - labelCenter.dy,
        axisPoint.dx - labelCenter.dx,
      );
      if (math.cos(labelAngle) < 0) labelAngle += math.pi;

      final cosAngle = math.cos(labelAngle);
      final sinAngle = math.sin(labelAngle);
      final localPolygon = <Offset>[
        for (final point in polygon)
          Offset(
            (point.dx - labelCenter.dx) * cosAngle +
                (point.dy - labelCenter.dy) * sinAngle,
            -(point.dx - labelCenter.dx) * sinAngle +
                (point.dy - labelCenter.dy) * cosAngle,
          ),
      ];
      var left = double.infinity;
      var right = double.infinity;
      var up = double.infinity;
      var down = double.infinity;
      for (final point in localPolygon) {
        if (point.dx < 0) left = math.min(left, -point.dx);
        if (point.dx > 0) right = math.min(right, point.dx);
        if (point.dy < 0) up = math.min(up, -point.dy);
        if (point.dy > 0) down = math.min(down, point.dy);
      }
      final symmetricWidth = 2 * math.min(left, right);
      final symmetricHeight = 2 * math.min(up, down);
      final faceFill = switch (face.vertices.length) {
        3 => 0.76,
        4 => 0.86,
        _ => 0.82,
      };
      final value = face.index + 1;
      const sampleFontSize = 100.0;
      final samplePainter = TextPainter(
        text: TextSpan(
          text: '$value',
          style: const TextStyle(
            fontSize: sampleFontSize,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final widthScale =
          (symmetricWidth * faceFill) / math.max(1, samplePainter.width);
      final heightScale =
          (symmetricHeight * faceFill) / math.max(1, samplePainter.height);
      final fontSize =
          sampleFontSize * math.max(0.01, math.min(widthScale, heightScale));
      final painter = TextPainter(
        text: TextSpan(
          text: '$value',
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(labelCenter.dx, labelCenter.dy);
      canvas.rotate(labelAngle);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
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
            0.195,
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
          sizeFactor: 1.68,
        );
      case ArcadeDieKind.color:
        _paintColorMark(canvas, center, scale, rotation, face, mark);
      case ArcadeDieKind.fate:
        _paintFateMark(canvas, center, scale, rotation, face, mark);
      case ArcadeDieKind.d4:
      case ArcadeDieKind.d8:
      case ArcadeDieKind.d10:
      case ArcadeDieKind.d12:
      case ArcadeDieKind.d20:
        break;
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

  void _paintFateMark(
    Canvas canvas,
    Offset center,
    double scale,
    _Rotation3 rotation,
    _Face face,
    Paint paint,
  ) {
    final symbol = fateDieFaceSymbol(face.index);
    if (symbol.isEmpty) return;
    if (symbol == '-') {
      _projectedPolygon(canvas, center, scale, rotation, face, const [
        Offset(-0.72, -0.13),
        Offset(0.72, -0.13),
        Offset(0.72, 0.13),
        Offset(-0.72, 0.13),
      ], paint);
      return;
    }
    _projectedPolygon(canvas, center, scale, rotation, face, const [
      Offset(-0.13, -0.72),
      Offset(0.13, -0.72),
      Offset(0.13, -0.13),
      Offset(0.72, -0.13),
      Offset(0.72, 0.13),
      Offset(0.13, 0.13),
      Offset(0.13, 0.72),
      Offset(-0.13, 0.72),
      Offset(-0.13, 0.13),
      Offset(-0.72, 0.13),
      Offset(-0.72, -0.13),
      Offset(-0.13, -0.13),
    ], paint);
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
        _projectedPolygon(
          canvas,
          center,
          scale,
          rotation,
          face,
          star,
          Paint()
            ..color = Colors.black87
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.8, scale * 0.045),
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
    final pipY = y + (inverted ? -halfHeight * 0.68 : halfHeight * 0.68);
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
          radius: 0.39,
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
          radius: 0.78,
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
          radius: 1.17,
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
          x: -0.29,
          y: -0.17,
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
          x: 0.22,
          y: 0.18,
          radius: 0.60,
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
          x: -0.32,
          y: -0.21,
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
          x: 0.24,
          y: 0.18,
          radius: 0.90,
          pips: 3,
          paint: paint,
        );
      case 5: // Medium + Large: true 2:3 scale, filling almost the whole face.
        _paintPyramidFace(
          canvas,
          center,
          scale,
          rotation,
          face,
          x: -0.34,
          y: -0.23,
          radius: 0.60,
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
          x: 0.28,
          y: 0.20,
          radius: 0.90,
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
      oldDelegate.pressed != pressed ||
      oldDelegate.showSpider != showSpider;
}
