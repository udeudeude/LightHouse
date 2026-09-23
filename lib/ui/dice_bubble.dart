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
  bool _pickerOpen = false;
  bool _spiderRevealed = false;
  bool _twoFingerMove = false;
  bool _gestureMoved = false;
  double _gestureTravel = 0;

  @override
  void initState() {
    super.initState();
    _applySnapshot(widget.snapshot, animateRoll: false);
    ²È="24€ô}™…•A½¥¹Ð (€€€€€€€€€•¹Ñ•È°(€€€€€€€€€Í…±”°(€€€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€€€™…”°(€€€€€€€€€Á½¥¹Ð¹‘à°(€€€€€€€€€Á½¥¹Ð¹‘ä°(€€€€€€€€¤ì(€€€€€€€Á…Ñ ¹±¥¹•Q¼¡ÁÉ½©•Ñ•¹‘à°ÁÉ½©•Ñ•¹‘ä¤ì(€€€€€ô(€€€€€Á…Ñ ¹±½Í” ¤ì(€€€ô(€€€…¹Ù…Ì¹‘É…ÝA…Ñ ¡Á…Ñ °Á…¥¹Ð¤ì(€ô((€Ù½¥}Á…¥¹Ñ1¥¡Ñ¹¥¹5…É¬ (€€€…¹Ù…Ì…¹Ù…Ì°(€€€=™™Í•Ð•¹Ñ•È°(€€€‘½Õ‰±”Í…±”°(€€€}I½Ñ…Ñ¥½¸ÌÉ½Ñ…Ñ¥½¸°(€€€}…”™…”°(€€€A…¥¹Ð™¥±°°(€€¤ì(€€€™¥¹…°½¹Ñ½ÕÉÌ€ôÍÝ¥Ñ €¡™…”¹¥¹‘•à¤ì(€€€€€€À€ôøÁåÉ…µ¥‘1½Ù•1¥¡Ñ¹¥¹	½±Ñ½¹Ñ½ÕÉÌ°(€€€€€€Ä€ôøÁåÉ…µ¥‘1½Ù•1¥¡Ñ¹¥¹Ñ½µ½¹Ñ½ÕÉÌ°(€€€€€€È€ôøÁåÉ…µ¥‘1½Ù•1¥¡Ñ¹¥¹MÁ±¥Ñ¥É±•½¹Ñ½ÕÉÌ°(€€€€€€Ì€ôøÁåÉ…µ¥‘1½Ù•1¥¡Ñ¹¥¹ÉÉ½Ý½¹Ñ½ÕÉÌ°(€€€€€€Ð€ôøÁåÉ…µ¥‘1½Ù•1¥¡Ñ¹¥¹AåÉ…µ¥‘Í½¹Ñ½ÕÉÌ°(€€€€€|€ôøÁåÉ…µ¥‘1½Ù•1¥¡Ñ¹¥¹I•å±•½¹Ñ½ÕÉÌ°(€€€ôì(€€€}Á…¥¹ÑAåÉ…µ¥‘1½Ù•½¹Ñ½ÕÉÌ (€€€€€…¹Ù…Ì°(€€€€€•¹Ñ•È°(€€€€€Í…±”°(€€€€€É½Ñ…Ñ¥½¸°(€€€€€™…”°(€€€€€½¹Ñ½ÕÉÌ°(€€€€€™¥±°°(€€€€¤ì(€ô((€Ù½¥}ÁÉ½©•Ñ•‘QÉ¥…¹±” (€€€…¹Ù…Ì…¹Ù…Ì°(€€€=™™Í•Ð•¹Ñ•È°(€€€‘½Õ‰±”Í…±”°(€€€}I½Ñ…Ñ¥½¸ÌÉ½Ñ…Ñ¥½¸°(€€€}…”™…”°(€€€‘½Õ‰±”à°(€€€‘½Õ‰±”ä°(€€€‘½Õ‰±”É…‘¥ÕÌ°(€€€A…¥¹ÐÁ…¥¹Ð°ì(€€€‰½½°¥¹Ù•ÉÑ•€ô™…±Í”°(€€€‰½½°™¥±±•€ôÑÉÕ”°(€ô¤ì(€€€€¼¼Q¡”É•…°1½½¹•äAåÉ…µ¥Í¥‘”ÁÉ½™¥±”¥ÌÑ…±°…¹¥Í½Í•±•Ì°¹½Ð…¸(€€€€¼¼•ÅÕ¥±…Ñ•É…°ÑÉ¥…¹±”¸1¥¡Ñ!½ÕÍ”Ìµ•…ÍÕÉ•™±…Ðµ±•¹Ñ ½‰…Í”É…Ñ¥¼¥Ì(€€€€¼¼…‰½ÕÐ€Ä¸ÜÔ°Í¼Ñ¡”‘¥”µ…É¬ÕÍ•ÌÑ¡…ÐÍ…µ”Í¥±¡½Õ•ÑÑ”É…Ñ¥¼¸(€€€™¥¹…°¡…±™!•¥¡Ð€ôÉ…‘¥ÕÌ€¨€À¸ÜÈì(€€€™¥¹…°¡…±™	…Í”€ô¡…±™!•¥¡Ð€¼ÁåÉ…µ¥‘¥•!•¥¡ÑQ½	…Í•I…Ñ¥¼ì(€€€™¥¹…°‘¥É•Ñ¥½¸€ô¥¹Ù•ÉÑ•€ü€´Ä¸À€è€Ä¸Àì(€€€™¥¹…°Á½¥¹ÑÌ€ô€ñ=™™Í•Ðùl(€€€€€=™™Í•Ð¡à°ä€´¡…±™!•¥¡Ð€¨‘¥É•Ñ¥½¸¤°(€€€€€=™™Í•Ð¡à€¬¡…±™	…Í”°ä€¬¡…±™!•¥¡Ð€¨‘¥É•Ñ¥½¸¤°(€€€€€=™™Í•Ð¡à€´¡…±™	…Í”°ä€¬¡…±™!•¥¡Ð€¨‘¥É•Ñ¥½¸¤°(€€€tì(€€€™¥¹…°Á…Ñ €ôA…Ñ  ¤ì(€€€™½È€¡Ù…È¤€ô€Àì¤€ðÁ½¥¹ÑÌ¹±•¹Ñ ì¤€¬ô€Ä¤ì(€€€€€™¥¹…°À€ô}™…•A½¥¹Ð (€€€€€€€•¹Ñ•È°(€€€€€€€Í…±”°(€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€™…”°(€€€€€€€Á½¥¹ÑÍm¥t¹‘à°(€€€€€€€Á½¥¹ÑÍm¥t¹‘ä°(€€€€€€¤ì(€€€€€¥˜€¡¤€ôô€À¤ì(€€€€€€€Á…Ñ ¹µ½Ù•Q¼¡À¹‘à°À¹‘ä¤ì(€€€€€ô•±Í”ì(€€€€€€€Á…Ñ ¹±¥¹•Q¼¡À¹‘à°À¹‘ä¤ì(€€€€€ô(€€€ô(€€€Á…Ñ ¹±½Í” ¤ì(€€€¥˜€¡™¥±±•¤ì(€€€€€…¹Ù…Ì¹‘É…ÝA…Ñ ¡Á…Ñ °Á…¥¹Ð¤ì(€€€ô•±Í”ì(€€€€€…¹Ù…Ì¹‘É…ÝA…Ñ  (€€€€€€€Á…Ñ °(€€€€€€€A…¥¹Ð ¤(€€€€€€€€€€¸¹½±½È€ôÁ…¥¹Ð¹½±½È(€€€€€€€€€€¸¹ÍÑå±”€ôA…¥¹Ñ¥¹MÑå±”¹ÍÑÉ½­”(€€€€€€€€€€¸¹ÍÑÉ½­•]¥‘Ñ €ôµ…Ñ ¹µ…à Ä¸À°Í…±”€¨€À¸ÀÜÔ¤(€€€€€€€€€€¸¹ÍÑÉ½­•)½¥¸€ôMÑÉ½­•)½¥¸¹É½Õ¹°(€€€€€€¤ì(€€€ô(€ô((€Ù½¥}Á…¥¹ÑAåÉ…µ¥‘…” (€€€…¹Ù…Ì…¹Ù…Ì°(€€€=™™Í•Ð•¹Ñ•È°(€€€‘½Õ‰±”Í…±”°(€€€}I½Ñ…Ñ¥½¸ÌÉ½Ñ…Ñ¥½¸°(€€€}…”™…”°ì(€€€É•ÅÕ¥É•‘½Õ‰±”à°(€€€É•ÅÕ¥É•‘½Õ‰±”ä°(€€€É•ÅÕ¥É•‘½Õ‰±”É…‘¥ÕÌ°(€€€É•ÅÕ¥É•¥¹ÐÁ¥ÁÌ°(€€€É•ÅÕ¥É•A…¥¹ÐÁ…¥¹Ð°(€€€‰½½°¥¹Ù•ÉÑ•€ô™…±Í”°(€ô¤ì(€€€}ÁÉ½©•Ñ•‘QÉ¥…¹±” (€€€€€…¹Ù…Ì°(€€€€€•¹Ñ•È°(€€€€€Í…±”°(€€€€€É½Ñ…Ñ¥½¸°(€€€€€™…”°(€€€€€à°(€€€€€ä°(€€€€€É…‘¥ÕÌ°(€€€€€Á…¥¹Ð°(€€€€€¥¹Ù•ÉÑ•è¥¹Ù•ÉÑ•°(€€€€€™¥±±•è™…±Í”°(€€€€¤ì(€€€™¥¹…°¡…±™!•¥¡Ð€ôÉ…‘¥ÕÌ€¨€À¸ÜÈì(€€€™¥¹…°¡…±™	…Í”€ô¡…±™!•¥¡Ð€¼ÁåÉ…µ¥‘¥•!•¥¡ÑQ½	…Í•I…Ñ¥¼ì(€€€™¥¹…°Á¥Ád€ôä€¬€¡¥¹Ù•ÉÑ•€ü€µ¡…±™!•¥¡Ð€¨€À¸Øà€è¡…±™!•¥¡Ð€¨€À¸Øà¤ì(€€€™¥¹…°ÍÁ…¥¹œ€ô¡…±™	…Í”€¨€À¸ØÈì(€€€™¥¹…°ÍÑ…ÉÑ`€ôà€´ÍÁ…¥¹œ€¨€¡Á¥ÁÌ€´€Ä¤€¼€Èì(€€€™½È€¡Ù…È¤€ô€Àì¤€ðÁ¥ÁÌì¤€¬ô€Ä¤ì(€€€€€}ÁÉ½©•Ñ•‘¥ÍŒ (€€€€€€€…¹Ù…Ì°(€€€€€€€•¹Ñ•È°(€€€€€€€Í…±”°(€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€™…”°(€€€€€€€ÍÑ…ÉÑ`€¬¤€¨ÍÁ…¥¹œ°(€€€€€€€Á¥Ád°(€€€€€€€µ…Ñ ¹µ…à À¸ÀÐÔ°¡…±™	…Í”€¨€À¸Äà¤°(€€€€€€€Á…¥¹Ð°(€€€€€€¤ì(€€€ô(€ô((€Ù½¥}Á…¥¹ÑAåÉ…µ¥‘5…É¬ (€€€…¹Ù…Ì…¹Ù…Ì°(€€€=™™Í•Ð•¹Ñ•È°(€€€‘½Õ‰±”Í…±”°(€€€}I½Ñ…Ñ¥½¸ÌÉ½Ñ…Ñ¥½¸°(€€€}…”™…”°(€€€A…¥¹ÐÁ…¥¹Ð°(€€¤ì(€€€ÍÝ¥Ñ €¡™…”¹¥¹‘•à¤ì(€€€€€…Í”€Àè€¼¼Mµ…±°¸(€€€€€€€}Á…¥¹ÑAåÉ…µ¥‘…” (€€€€€€€€€…¹Ù…Ì°(€€€€€€€€€•¹Ñ•È°(€€€€€€€€€Í…±”°(€€€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€€€™…”°(€€€€€€€€€àè€À°(€€€€€€€€€äè€À¸ÀÐ°(€€€€€€€€€É…‘¥ÕÌè€À¸Ôà°(€€€€€€€€€Á¥ÁÌè€Ä°(€€€€€€€€€Á…¥¹ÐèÁ…¥¹Ð°(€€€€€€€€¤ì(€€€€€…Í”€Äè€¼¼5•‘¥Õ´¸(€€€€€€€}Á…¥¹ÑAåÉ…µ¥‘…” (€€€€€€€€€…¹Ù…Ì°(€€€€€€€€€•¹Ñ•È°(€€€€€€€€€Í…±”°(€€€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€€€™…”°(€€€€€€€€€àè€À°(€€€€€€€€€äè€À¸ÀÐ°(€€€€€€€€€É…‘¥ÕÌè€À¸ÜØ°(€€€€€€€€€Á¥ÁÌè€È°(€€€€€€€€€Á…¥¹ÐèÁ…¥¹Ð°(€€€€€€€€¤ì(€€€€€…Í”€Èè€¼¼1…É”¸(€€€€€€€}Á…¥¹ÑAåÉ…µ¥‘…” (€€€€€€€€€…¹Ù…Ì°(€€€€€€€€€•¹Ñ•È°(€€€€€€€€€Í…±”°(€€€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€€€™…”°(€€€€€€€€€àè€À°(€€€€€€€€€äè€À¸ÀÌ°(€€€€€€€€€É…‘¥ÕÌè€À¸äÀ°(€€€€€€€€€Á¥ÁÌè€Ì°(€€€€€€€€€Á…¥¹ÐèÁ…¥¹Ð°(€€€€€€€€¤ì(€€€€€…Í”€Ìè€¼¼Mµ…±°€¬5•‘¥Õ´¸(€€€€€€€}Á…¥¹ÑAåÉ…µ¥‘…” (€€€€€€€€€…¹Ù…Ì°(€€€€€€€€€•¹Ñ•È°(€€€€€€€€€Í…±”°(€€€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€€€™…”°(€€€€€€€€€àè€´À¸ÌÀ°(€€€€€€€€€äè€´À¸ÄÔ°(€€€€€€€€€É…‘¥ÕÌè€À¸Ìä°(€€€€€€€€€Á¥ÁÌè€Ä°(€€€€€€€€€Á…¥¹ÐèÁ…¥¹Ð°(€€€€€€€€€¥¹Ù•ÉÑ•èÑÉÕ”°(€€€€€€€€¤ì(€€€€€€€}Á…¥¹ÑAåÉ…µ¥‘…” (€€€€€€€€€…¹Ù…Ì°(€€€€€€€€€•¹Ñ•È°(€€€€€€€€€Í…±”°(€€€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€€€™…”°(€€€€€€€€€àè€À¸ÈÔ°(€€€€€€€€€äè€À¸ÈÀ°(€€€€€€€€€É…‘¥ÕÌè€À¸ÔØ°(€€€€€€€€€Á¥ÁÌè€È°(€€€€€€€€€Á…¥¹ÐèÁ…¥¹Ð°(€€€€€€€€¤ì(€€€€€…Í”€Ðè€¼¼Mµ…±°€¬1…É”¸(€€€€€€€}Á…¥¹ÑAåÉ…µ¥‘…” (€€€€€€€€€…¹Ù…Ì°(€€€€€€€€€•¹Ñ•È°(€€€€€€€€€Í…±”°(€€€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€€€™…”°(€€€€€€€€€àè€´À¸ÌÌ°(€€€€€€€€€äè€´À¸ÄÜ°(€€€€€€€€€É…‘¥ÕÌè€À¸Ìä°(€€€€€€€€€Á¥ÁÌè€Ä°(€€€€€€€€€Á…¥¹ÐèÁ…¥¹Ð°(€€€€€€€€€¥¹Ù•ÉÑ•èÑÉÕ”°(€€€€€€€€¤ì(€€€€€€€}Á…¥¹ÑAåÉ…µ¥‘…” (€€€€€€€€€…¹Ù…Ì°(€€€€€€€€€•¹Ñ•È°(€€€€€€€€€Í…±”°(€€€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€€€™…”°(€€€€€€€€€àè€À¸ÈÐ°(€€€€€€€€€äè€À¸ÈÄ°(€€€€€€€€€É…‘¥ÕÌè€À¸ÜÐ°(€€€€€€€€€Á¥ÁÌè€Ì°(€€€€€€€€€Á…¥¹ÐèÁ…¥¹Ð°(€€€€€€€€¤ì(€€€€€…Í”€Ôè€¼¼5•‘¥Õ´€¬1…É”è¥¹Ñ•¹Ñ¥½¹…±±ä™¥±±Ì…±µ½ÍÐÑ¡”Ý¡½±”™…”¸(€€€€€€€}Á…¥¹ÑAåÉ…µ¥‘…” (€€€€€€€€€…¹Ù…Ì°(€€€€€€€€€•¹Ñ•È°(€€€€€€€€€Í…±”°(€€€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€€€™…”°(€€€€€€€€€àè€´À¸ÌÐ°(€€€€€€€€€äè€´À¸ÈÀ°(€€€€€€€€€É…‘¥ÕÌè€À¸ØÈ°(€€€€€€€€€Á¥ÁÌè€È°(€€€€€€€€€Á…¥¹ÐèÁ…¥¹Ð°(€€€€€€€€€¥¹Ù•ÉÑ•èÑÉÕ”°(€€€€€€€€¤ì(€€€€€€€}Á…¥¹ÑAåÉ…µ¥‘…” (€€€€€€€€€…¹Ù…Ì°(€€€€€€€€€•¹Ñ•È°(€€€€€€€€€Í…±”°(€€€€€€€€€É½Ñ…Ñ¥½¸°(€€€€€€€€€™…”°(€€€€€€€€€àè€À¸ÈÜ°(€€€€€€€€€äè€À¸ÈÈ°(€€€€€€€€€É…‘¥ÕÌè€À¸àØ°(€€€€€€€€€Á¥ÁÌè€Ì°(€€€€€€€€€Á…¥¹ÐèÁ…¥¹Ð°(€€€€€€€€¤ì(€€€ô(€ô((€Ù½¥}Á…¥¹Ñ…•Q•áÐ (€€€…¹Ù…Ì…¹Ù…Ì°(€€€=™™Í•Ð•¹Ñ•È°(€€€‘½Õ‰±”Í…±”°(€€€}I½Ñ…Ñ¥½¸ÌÉ½Ñ…Ñ¥½¸°(€€€}…”™…”°(€€€MÑÉ¥¹œÑ•áÐ°(€€€½±½È½±½È°ì(€€€‰½½°‘¥…½¹…°€ô™…±Í”°(€€€‘½Õ‰±”Í¥é•…Ñ½È€ô€Ä°(€ô¤ì(€€€™¥¹…°Œ€ô}™…•A½¥¹Ð¡•¹Ñ•È°Í…±”°É½Ñ…Ñ¥½¸°™…”°€À°€À¤ì(€€€™¥¹…°Á…¥¹Ñ•È€ôQ•áÑA…¥¹Ñ•È (€€€€€Ñ•áÐèQ•áÑMÁ…¸ (€€€€€€€Ñ•áÐèÑ•áÐ°(€€€€€€€ÍÑå±”èQ•áÑMÑå±” (€€€€€€€€€½±½Èè½±½È°(€€€€€€€€€™½¹ÑM¥é”è(€€€€€€€€€€€€€µ…Ñ ¹µ…à Ô¸Ô°Í…±”€¨€¡Ñ•áÐ¹±•¹Ñ €ø€Ì€ü€À¸ÐÈ€è€À¸ÔÀ¤¤€¨(€€€€€€€€€€€€€Í¥é•…Ñ½È°(€€€€€€€€€™½¹Ñ]•¥¡Ðè½¹Ñ]•¥¡Ð¹ÜäÀÀ°(€€€€€€€€€±•ÑÑ•ÉMÁ…¥¹œèÑ•áÐ¹±•¹Ñ €ø€Ì€ü€´À¸ØÔ€è€´À¸ÌÔ°(€€€€€€€€¤°(€€€€€€¤°(€€€€€Ñ•áÑ¥É•Ñ¥½¸èQ•áÑ¥É•Ñ¥½¸¹±ÑÈ°(€€€€¤¸¹±…å½ÕÐ ¤ì((€€€…¹Ù…Ì¹Í…Ù” ¤ì(€€€…¹Ù…Ì¹ÑÉ…¹Í±…Ñ”¡Œ¹‘à°Œ¹‘ä¤ì(€€€¥˜€¡‘¥…½¹…°¤ì(€€€€€™¥¹…°Áà€ô}™…•A½¥¹Ð¡•¹Ñ•È°Í…±”°É½Ñ…Ñ¥½¸°™…”°€À¸ÐÔ°€À¤ì(€€€€€™¥¹…°Áä€ô}™…•A½¥¹Ð¡•¹Ñ•È°Í…±”°É½Ñ…Ñ¥½¸°™…”°€À°€À¸ÐÔ¤ì(€€€€€™¥¹…°‘¥…½¹…±Y•Ñ½È€ô€¡Áà€´Œ¤€¬€¡Áä€´Œ¤ì(€€€€€…¹Ù…Ì¹É½Ñ…Ñ”¡µ…Ñ ¹…Ñ…¸È¡‘¥…½¹…±Y•Ñ½È¹‘ä°‘¥…½¹…±Y•Ñ½È¹‘à¤¤ì(€€€ô(€€€Á…¥¹Ñ•È¹Á…¥¹Ð¡…¹Ù…Ì°=™™Í•Ð µÁ…¥¹Ñ•È¹Ý¥‘Ñ €¼€È°€µÁ…¥¹Ñ•È¹¡•¥¡Ð€¼€È¤¤ì(€€€…¹Ù…Ì¹É•ÍÑ½É” ¤ì(€ô((€½Ù•ÉÉ¥‘”(€‰½½°Í¡½Õ±‘I•Á…¥¹Ð¡½Ù…É¥…¹Ð}¥•	Õ‰‰±•A…¥¹Ñ•È½±‘•±•…Ñ”¤€ôø(€€€€€€…±¥ÍÑÅÕ…±Ì¡½±‘•±•…Ñ”¹¥¹ÍÑ…¹•%‘Ì°¥¹ÍÑ…¹•%‘Ì¤ñð(€€€€€€…±¥ÍÑÅÕ…±Ì¡½±‘•±•…Ñ”¹¡½¥•Ì°¡½¥•Ì¤ñð(€€€€€€…µ…ÁÅÕ…±Ì¡½±‘•±•…Ñ”¹™…•Ì°™…•Ì¤ñð(€€€€€€…µ…ÁÅÕ…±Ì¡½±‘•±•…Ñ”¹Á±…¹Ì°Á±…¹Ì¤ñð(€€€€€½±‘•±•…Ñ”¹ÁÉ½É•ÍÌ€„ôÁÉ½É•ÍÌñð(€€€€€½±‘•±•…Ñ”¹É½±±M•É¥…°€„ôÉ½±±M•É¥…°ñð(€€€€€½±‘•±•…Ñ”¹ÁÉ•ÍÍ•€„ôÁÉ•ÍÍ•ñð(€€€€€½±‘•±•…Ñ”¹Í¡½ÝMÁ¥‘•È€„ôÍ¡½ÝMÁ¥‘•Èì)ô(