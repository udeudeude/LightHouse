from pathlib import Path


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 exact match, found {count}')
    return text.replace(old, new, 1)


# --- board_screen_next.dart -------------------------------------------------
p = Path('lib/ui/board_screen_next.dart')
s = p.read_text()
s = replace_once(
    s,
    "        'Rounded Triangle Tips',",
    "        'Safety Tips',",
    'safety tips label',
)

old = """      _compactMenuItem(
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
"""
new = """      const PopupMenuDivider(),
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
"""
s = replace_once(s, old, new, 'checker menu placement')

old = """  Future<String?> _showCompactMenu(List<PopupMenuEntry<String>> items) =>
      showMenu<String>(
        context: context,
        position: _compactMenuPosition(),
        color: const Color(0xFF202020),
        items: items,
      );
"""
new = """  Future<String?> _showCompactMenu(List<PopupMenuEntry<String>> items) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        useSafeArea: true,
        builder: (sheetContext) => Align(
          alignment: Alignment.bottomLeft,
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 50),
            child: Material(
              color: const Color(0xFF202020),
              elevation: 10,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicWidth(
                child: Column(mainAxisSize: MainAxisSize.min, children: items),
              ),
            ),
          ),
        ),
      );
"""
s = replace_once(s, old, new, 'pull-down menus')

s = replace_once(
    s,
    "('Dice bubble', 'Hold/release to roll; latch selects up to 3 dice'),",
    "('Dice bubble', 'Press/release to roll; two-finger drag moves; latch chooses dice'),",
    'desktop dice instructions',
)
s = replace_once(
    s,
    "              'Use the tray; drag stones; double-click to remove',",
    "              'Tap or drag from tray; drag stones; double-click to remove',",
    'desktop zendo instructions',
)
s = replace_once(
    s,
    "              'Hold/release to roll; 2 fingers move; latch selects dice',",
    "              'Tap or hold/release to roll; two-finger drag moves; latch chooses dice',",
    'touch dice instructions',
)
s = replace_once(
    s,
    "('Zendo stones', 'Use the tray; drag stones; double-tap to remove'),",
    "('Zendo stones', 'Tap or drag from tray; drag stones; double-tap to remove'),",
    'touch zendo instructions',
)
p.write_text(s)


# --- toy_overlay.dart -------------------------------------------------------
p = Path('lib/ui/toy_overlay.dart')
s = p.read_text()
old = """      final point = switch (gunIndex) {
        0 => gunCenter + Offset(15, delta),
        1 => gunCenter + Offset(-15, delta),
        2 => gunCenter + Offset(delta, 15),
        _ => gunCenter + Offset(delta, -15),
      };
"""
new = """      final point = switch (gunIndex) {
        0 => gunCenter + Offset(18, 26 + delta),
        1 => gunCenter + Offset(-18, 26 + delta),
        2 => gunCenter + Offset(26 + delta, 18),
        _ => gunCenter + Offset(26 + delta, -18),
      };
"""
s = replace_once(s, old, new, 'side gun ammo beside guns')
p.write_text(s)


# --- board_underlay.dart ----------------------------------------------------
p = Path('lib/domain/board_underlay.dart')
s = p.read_text()
s = replace_once(
    s,
    '  static const double petalRadiusMm = 46;',
    '  static const double petalRadiusMm = 40;',
    'petal radius',
)
old = """List<PhysicalPoint> _sandshipsPoints(PhysicalPoint center) => [
  center,
  PhysicalPoint(center.xMm, center.yMm - 48),
  PhysicalPoint(center.xMm + 58, center.yMm),
  PhysicalPoint(center.xMm, center.yMm + 48),
  PhysicalPoint(center.xMm - 58, center.yMm),
];
"""
new = """List<PhysicalPoint> _sandshipsPoints(PhysicalPoint center) => [
  center,
  PhysicalPoint(center.xMm - 58, center.yMm - 48),
  PhysicalPoint(center.xMm + 58, center.yMm - 48),
  PhysicalPoint(center.xMm + 58, center.yMm + 48),
  PhysicalPoint(center.xMm - 58, center.yMm + 48),
];
"""
s = replace_once(s, old, new, 'Sandships city layout')
p.write_text(s)


# --- board_painter.dart -----------------------------------------------------
p = Path('lib/ui/board_painter.dart')
s = p.read_text()
old = """      final isFactory = i == 4;
      final isLaunchpad = const {0, 2, 6, 8}.contains(i);
      final rect = Rect.fromCenter(
        center: centers[i],
        width: node,
        height: node,
      );
      if (isFactory) {
        final oct = Path();
        for (var p = 0; p < 8; p += 1) {
          final angle = math.pi / 8 + p * math.pi / 4;
          final point =
              centers[i] +
              Offset(math.cos(angle), math.sin(angle)) * node * 0.53;
          if (p == 0)
            oct.moveTo(point.dx, point.dy);
          else
            oct.lineTo(point.dx, point.dy);
        }
        oct.close();
        canvas.drawPath(oct, _linePaint(0.62));
        _paintTinyLabel(canvas, centers[i], 'FACTORY');
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(node * 0.07)),
          _linePaint(isLaunchpad ? 0.64 : 0.40),
        );
        if (isLaunchpad) {
          final arrow = Path()
            ..moveTo(centers[i].dx, centers[i].dy - node * 0.18)
            ..lineTo(centers[i].dx + node * 0.14, centers[i].dy + node * 0.10)
            ..lineTo(centers[i].dx - node * 0.14, centers[i].dy + node * 0.10)
            ..close();
          canvas.drawPath(arrow, _linePaint(0.52));
        }
      }
"""
new = """      final isFactory = i == 4;
      final isLaunchpad = const {0, 2, 6, 8}.contains(i);
      final rect = Rect.fromCenter(
        center: centers[i],
        width: node,
        height: node,
      );
      if (isFactory) {
        final oct = Path();
        for (var p = 0; p < 8; p += 1) {
          final angle = math.pi / 8 + p * math.pi / 4;
          final point =
              centers[i] +
              Offset(math.cos(angle), math.sin(angle)) * node * 0.53;
          if (p == 0) {
            oct.moveTo(point.dx, point.dy);
          } else {
            oct.lineTo(point.dx, point.dy);
          }
        }
        oct.close();
        canvas.drawPath(oct, _linePaint(0.62));
        _paintTinyLabel(canvas, centers[i], 'FACTORY');
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(node * 0.07)),
          _linePaint(isLaunchpad ? 0.64 : 0.40),
        );
        if (isLaunchpad) {
          const launchpadLabels = <int, String>{
            0: 'LAUNCH PAD 23-A',
            2: 'LAUNCH PAD 23-B',
            8: 'LAUNCH PAD 23-C',
            6: 'LAUNCH PAD 23-D',
          };
          final arrow = Path()
            ..moveTo(centers[i].dx, centers[i].dy - node * 0.24)
            ..lineTo(centers[i].dx + node * 0.11, centers[i].dy - node * 0.02)
            ..lineTo(centers[i].dx - node * 0.11, centers[i].dy - node * 0.02)
            ..close();
          canvas.drawPath(arrow, _linePaint(0.52));
          _paintTinyLabel(
            canvas,
            centers[i] + Offset(0, node * 0.19),
            launchpadLabels[i]!,
            fontSize: 5.5,
          );
        } else {
          _paintTinyLabel(canvas, centers[i], 'STORAGE DEPOT', fontSize: 5.5);
        }
      }
"""
s = replace_once(s, old, new, 'Launchpad labels')

s = replace_once(
    s,
    "      _paintTinyLabel(canvas, labelCenter, labels[continent]);",
    "      _paintTinyLabel(\n        canvas,\n        labelCenter,\n        labels[continent],\n        angleRadians: math.pi / 2,\n      );",
    'World War 5 label rotation',
)

old = """  void _paintTinyLabel(Canvas canvas, Offset center, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white54, fontSize: 7),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }
"""
new = """  void _paintTinyLabel(
    Canvas canvas,
    Offset center,
    String text, {
    double angleRadians = 0,
    double fontSize = 7,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.white54, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (angleRadians == 0) {
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
      return;
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angleRadians);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }
"""
s = replace_once(s, old, new, 'rotatable tiny labels')
p.write_text(s)


# --- special_board_painter.dart --------------------------------------------
p = Path('lib/ui/special_board_painter.dart')
s = p.read_text()
start = s.index('  void paintSandships(Canvas canvas, Size size) {')
end = s.index('\n  void paintMartianBackgammon', start)
new_method = r'''  void paintSandships(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final cityCentersMm = BoardUnderlay.sandships.snapPoints(
      boardWidthMm: size.width / logicalPixelsPerMm,
      boardHeightMm: size.height / logicalPixelsPerMm,
    );
    final cityCenters = [
      for (final point in cityCentersMm)
        Offset(point.xMm * logicalPixelsPerMm, point.yMm * logicalPixelsPerMm),
    ];
    final cityRadius = 15.0 * logicalPixelsPerMm;
    final boardRadius = math.min(size.width, size.height) * 0.47;

    // The published board has a central city, four corner cities and eight
    // wasteland zones. Canals radiate between the zones; ports open from each
    // city into the neighboring zones.
    final canal = _linePaint(0.30);
    for (var i = 0; i < 8; i += 1) {
      final angle = math.pi / 8 + i * math.pi / 4;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * cityRadius,
        center + direction * boardRadius,
        canal,
      );
    }

    void paintPort(Offset cityCenter, double angle) {
      final direction = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-direction.dy, direction.dx);
      final tip = cityCenter + direction * cityRadius * 1.02;
      final base = cityCenter + direction * cityRadius * 0.70;
      final half = 3.2 * logicalPixelsPerMm;
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base.dx + normal.dx * half, base.dy + normal.dy * half)
        ..lineTo(base.dx - normal.dx * half, base.dy - normal.dy * half)
        ..close();
      canvas.drawPath(path, _linePaint(0.46));
    }

    for (var city = 0; city < cityCenters.length; city += 1) {
      final cityCenter = cityCenters[city];
      canvas.drawCircle(
        cityCenter,
        cityRadius,
        _linePaint(city == 0 ? 0.66 : 0.52),
      );
      if (city == 0) {
        for (var port = 0; port < 8; port += 1) {
          paintPort(cityCenter, port * math.pi / 4);
        }
      } else {
        final inward = math.atan2(
          center.dy - cityCenter.dy,
          center.dx - cityCenter.dx,
        );
        for (final offset in const [-math.pi / 4, 0.0, math.pi / 4]) {
          paintPort(cityCenter, inward + offset);
        }
      }
    }
  }
'''
s = s[:start] + new_method + s[end:]
p.write_text(s)


# --- zendo_stones.dart ------------------------------------------------------
Path('lib/ui/zendo_stones.dart').write_text(r'''import 'package:flutter/material.dart';

class ZendoStonesWidget extends StatefulWidget {
  const ZendoStonesWidget({super.key});

  @override
  State<ZendoStonesWidget> createState() => _ZendoStonesWidgetState();
}

enum _ZendoStoneKind { white, black, green }

class _ZendoStone {
  const _ZendoStone({
    required this.id,
    required this.kind,
    required this.center,
    required this.expanded,
  });

  final int id;
  final _ZendoStoneKind kind;
  final Offset center;
  final bool expanded;

  _ZendoStone copyWith({Offset? center, bool? expanded}) => _ZendoStone(
    id: id,
    kind: kind,
    center: center ?? this.center,
    expanded: expanded ?? this.expanded,
  );
}

class _ZendoStonesWidgetState extends State<ZendoStonesWidget> {
  static const double _smallRadius = 10.5;
  static const double _largeRadius = 21;
  final GlobalKey _surfaceKey = GlobalKey();
  final List<_ZendoStone> _stones = [];
  int _nextId = 1;
  int? _trayDragStoneId;

  Color _fill(_ZendoStoneKind kind) => switch (kind) {
    _ZendoStoneKind.white => Colors.white,
    _ZendoStoneKind.black => Colors.black,
    _ZendoStoneKind.green => const Color(0xFF31C95A),
  };

  String _label(_ZendoStoneKind kind) => switch (kind) {
    _ZendoStoneKind.white => 'White marking stone',
    _ZendoStoneKind.black => 'Black marking stone',
    _ZendoStoneKind.green => 'Green guessing stone',
  };

  Offset _local(Offset global) {
    final box = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  Offset _clamp(Offset center, Size size) => Offset(
    center.dx.clamp(_largeRadius, size.width - _largeRadius).toDouble(),
    center.dy.clamp(_largeRadius, size.height - _largeRadius).toDouble(),
  );

  void _add(_ZendoStoneKind kind, Size size) {
    final n = _nextId++;
    final offset = Offset(((n % 5) - 2) * 12.0, ((n % 3) - 1) * 12.0);
    setState(() {
      _stones.add(
        _ZendoStone(
          id: n,
          kind: kind,
          center: _clamp(Offset(size.width / 2, size.height / 2) + offset, size),
          expanded: true,
        ),
      );
    });
  }

  void _beginTrayDrag(
    _ZendoStoneKind kind,
    DragStartDetails details,
    Size size,
  ) {
    final id = _nextId++;
    _trayDragStoneId = id;
    setState(() {
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

  void _updateTrayDrag(DragUpdateDetails details, Size size) {
    final id = _trayDragStoneId;
    if (id == null) return;
    final index = _stones.indexWhere((stone) => stone.id == id);
    if (index < 0) return;
    setState(() {
      _stones[index] = _stones[index].copyWith(
        center: _clamp(_local(details.globalPosition), size),
        expanded: true,
      );
    });
  }

  void _endTrayDrag() {
    final id = _trayDragStoneId;
    _trayDragStoneId = null;
    if (id == null) return;
    final index = _stones.indexWhere((stone) => stone.id == id);
    if (index < 0) return;
    setState(() => _stones[index] = _stones[index].copyWith(expanded: true));
  }

  void _move(int id, Offset delta, Size size) {
    final index = _stones.indexWhere((stone) => stone.id == id);
    if (index < 0) return;
    setState(() {
      _stones[index] = _stones[index].copyWith(
        center: _clamp(_stones[index].center + delta, size),
        expanded: true,
      );
    });
  }

  void _remove(int id) => setState(() {
    _stones.removeWhere((stone) => stone.id == id);
  });

  Widget _trayButton(_ZendoStoneKind kind, Size size) => Tooltip(
    message: _label(kind),
    child: Semantics(
      button: true,
      label: 'Add ${_label(kind)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _add(kind, size),
        onPanStart: (details) => _beginTrayDrag(kind, details, size),
        onPanUpdate: (details) => _updateTrayDrag(details, size),
        onPanEnd: (_) => _endTrayDrag(),
        onPanCancel: _endTrayDrag,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _fill(kind),
              border: Border.all(color: Colors.white70),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 2, spreadRadius: 1),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return Stack(
        key: _surfaceKey,
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: const Color(0xCC171717),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _trayButton(_ZendoStoneKind.white, size),
                    _trayButton(_ZendoStoneKind.black, size),
                    _trayButton(_ZendoStoneKind.green, size),
                  ],
                ),
              ),
            ),
          ),
          for (final stone in _stones)
            Positioned(
              left: stone.center.dx - _largeRadius - 5,
              top: stone.center.dy - _largeRadius - 5,
              width: (_largeRadius + 5) * 2,
              height: (_largeRadius + 5) * 2,
              child: Tooltip(
                message: '${_label(stone.kind)} · drag · double-tap to remove',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => _move(stone.id, details.delta, size),
                  onDoubleTap: () => _remove(stone.id),
                  onLongPress: () => _remove(stone.id),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutBack,
                      width: (stone.expanded ? _largeRadius : _smallRadius) * 2,
                      height: (stone.expanded ? _largeRadius : _smallRadius) * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _fill(stone.kind),
                        border: Border.all(
                          color: stone.kind == _ZendoStoneKind.white
                              ? Colors.black54
                              : Colors.white70,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
''')


# --- dice_bubble.dart -------------------------------------------------------
p = Path('lib/ui/dice_bubble.dart')
s = p.read_text()
s = replace_once(
    s,
    '  static const double _radius = 59;',
    '  static const double _radius = 70;',
    'bubble radius',
)
s = replace_once(
    s,
    "  Offset _center = const Offset(69, 69);\n  bool _pressed = false;\n  bool _twoFingerMove = false;",
    "  Offset _center = const Offset(80, 80);\n  bool _pressed = false;\n  bool _twoFingerMove = false;\n  bool _gestureMoved = false;\n  double _gestureTravel = 0;",
    'bubble gesture fields',
)

picker_start = s.index('  Future<void> _showPicker() async {')
picker_end = s.index('\n  @override\n  Widget build', picker_start)
new_picker = r'''  Widget _selectorImage(ArcadeDieChoice choice) {
    Widget mark;
    switch (choice.kind) {
      case ArcadeDieKind.standard:
        mark = const Stack(
          children: [
            Positioned(left: 11, top: 11, child: _SelectorPip()),
            Positioned(right: 11, top: 11, child: _SelectorPip()),
            Center(child: _SelectorPip()),
            Positioned(left: 11, bottom: 11, child: _SelectorPip()),
            Positioned(right: 11, bottom: 11, child: _SelectorPip()),
          ],
        );
      case ArcadeDieKind.lightning:
        mark = const Icon(Icons.bolt, color: Colors.black, size: 35);
      case ArcadeDieKind.pyramid:
        mark = const Icon(Icons.change_history, color: Colors.black, size: 35);
      case ArcadeDieKind.treehouse:
        mark = const Center(
          child: Text(
            'AIM',
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w900,
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
              Text('♦', style: TextStyle(color: Colors.cyan, fontSize: 17)),
              Text('♣', style: TextStyle(color: Colors.green, fontSize: 17)),
              Text('★', style: TextStyle(color: Colors.yellow, fontSize: 15)),
            ],
          ),
        );
    }
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black87),
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
          final atLimit = _selectedIds.length >= 3;
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 9,
                      crossAxisSpacing: 9,
                      childAspectRatio: 1,
                    ),
                    itemCount: arcadeDiceChoices.length,
                    itemBuilder: (context, index) {
                      final choice = arcadeDiceChoices[index];
                      final selected = _selectedIds.contains(choice.id);
                      final disabled = !selected && atLimit;
                      return Tooltip(
                        message: choice.label,
                        child: Semantics(
                          button: true,
                          selected: selected,
                          label: choice.label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: disabled
                                ? null
                                : () {
                                    setState(() {
                                      if (selected) {
                                        _selectedIds.remove(choice.id);
                                        _faces.remove(choice.id);
                                        _plans.remove(choice.id);
                                      } else {
                                        _selectedIds.add(choice.id);
                                        _faces[choice.id] = _random.nextInt(6);
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 100),
                              opacity: disabled ? 0.30 : 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected ? Colors.white : Colors.white24,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _selectorImage(choice),
                                    if (selected)
                                      const Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
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
'''
s = s[:picker_start] + new_picker + s[picker_end:]

old = """              onScaleStart: (details) {
                _twoFingerMove = details.pointerCount >= 2;
                setState(() => _pressed = !_twoFingerMove);
                if (_pressed) HapticFeedback.selectionClick();
              },
              onScaleUpdate: (details) {
                if (details.pointerCount < 2) return;
                _twoFingerMove = true;
                setState(() {
                  _pressed = false;
                  _center = _clampCenter(
                    _center + details.focalPointDelta,
                    size,
                  );
                });
              },
              onScaleEnd: (_) {
                final roll = _pressed && !_twoFingerMove;
                setState(() => _pressed = false);
                if (roll) _roll();
                _twoFingerMove = false;
              },
"""
new = """              onScaleStart: (details) {
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
                  if (_gestureMoved && _pressed) setState(() => _pressed = false);
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
              },
              onScaleEnd: (_) {
                final roll = _pressed && !_twoFingerMove && !_gestureMoved;
                setState(() => _pressed = false);
                if (roll) _roll();
                _twoFingerMove = false;
                _gestureMoved = false;
                _gestureTravel = 0;
              },
"""
s = replace_once(s, old, new, 'bubble movement does not roll')

old = """                      child: Container(
                        width: 25,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          border: Border.all(color: Colors.white54),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(4),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_open_outlined,
                          size: 15,
                          color: Colors.white70,
                        ),
                      ),
"""
new = """                      child: Container(
                        width: 12,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          border: Border.all(color: Colors.white70, width: 1.2),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(2),
                          ),
                        ),
                      ),
"""
s = replace_once(s, old, new, 'thin bubble latch')

s = replace_once(
    s,
    """  List<Offset> _dieOffsets(int count) => switch (count) {
    1 => const [Offset.zero],
    2 => const [Offset(-18, 0), Offset(18, 0)],
    _ => const [Offset(-18, -10), Offset(18, -10), Offset(0, 19)],
  };
""",
    """  List<Offset> _dieOffsets(int count) => switch (count) {
    1 => const [Offset.zero],
    2 => const [Offset(-24, 0), Offset(24, 0)],
    _ => const [Offset(-27, -17), Offset(27, -17), Offset(0, 29)],
  };
""",
    'dice spacing',
)

old = """    final radius = math.min(size.width, size.height) / 2 - 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white.withValues(alpha: 0.035),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 5),
      math.pi * 1.12,
      math.pi * 0.64,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final offsets = _dieOffsets(choices.length);
    final squeeze = pressed ? 0.72 : 1.0;
"""
new = """    final baseRadius = math.min(size.width, size.height) / 2 - 5;
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

    final offsets = _dieOffsets(choices.length);
    final squeeze = pressed ? 0.72 : 1.0;
"""
s = replace_once(s, old, new, 'bubble bulge and reflection')
s = replace_once(
    s,
    '      _paintDie(canvas, dieCenter, 15.2 * squeeze, choice.kind, rotation);',
    '      _paintDie(canvas, dieCenter, 13.8 * squeeze, choice.kind, rotation);',
    'dice size',
)

old = """      case ArcadeDieKind.color:
        if (face.index < 5) {
          final colors = [
            Colors.red,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.purple,
          ];
          _projectedDisc(
            canvas,
            center,
            scale,
            rotation,
            face,
            0,
            0,
            0.36,
            Paint()..color = colors[face.index],
          );
        } else {
          _paintAtom(canvas, center, scale, rotation, face, black);
        }
"""
new = """      case ArcadeDieKind.color:
        _paintColorMark(canvas, center, scale, rotation, face, black);
"""
s = replace_once(s, old, new, 'color die suits')

insert_at = s.index('  void _lineOnFace(')
helpers = r'''  void _projectedPolygon(
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
      case 0: // purple spade
        final purple = Paint()..color = Colors.purple;
        _projectedPolygon(
          canvas,
          center,
          scale,
          rotation,
          face,
          const [
            Offset(0, -0.58),
            Offset(-0.50, 0.08),
            Offset(-0.34, 0.36),
            Offset(-0.10, 0.29),
            Offset(-0.16, 0.58),
            Offset(0.16, 0.58),
            Offset(0.10, 0.29),
            Offset(0.34, 0.36),
            Offset(0.50, 0.08),
          ],
          purple,
        );
      case 1: // red heart
        _projectedPolygon(
          canvas,
          center,
          scale,
          rotation,
          face,
          const [
            Offset(0, 0.58),
            Offset(-0.47, 0.05),
            Offset(-0.46, -0.25),
            Offset(-0.25, -0.45),
            Offset(0, -0.25),
            Offset(0.25, -0.45),
            Offset(0.46, -0.25),
            Offset(0.47, 0.05),
          ],
          Paint()..color = Colors.red,
        );
      case 2: // cyan diamond
        _projectedPolygon(
          canvas,
          center,
          scale,
          rotation,
          face,
          const [
            Offset(0, -0.58),
            Offset(0.42, 0),
            Offset(0, 0.58),
            Offset(-0.42, 0),
          ],
          Paint()..color = Colors.cyan,
        );
      case 3: // green club
        final green = Paint()..color = Colors.green;
        _projectedDisc(canvas, center, scale, rotation, face, 0, -0.29, 0.25, green);
        _projectedDisc(canvas, center, scale, rotation, face, -0.24, 0.02, 0.25, green);
        _projectedDisc(canvas, center, scale, rotation, face, 0.24, 0.02, 0.25, green);
        _projectedPolygon(
          canvas,
          center,
          scale,
          rotation,
          face,
          const [
            Offset(-0.11, 0.08),
            Offset(0.11, 0.08),
            Offset(0.18, 0.58),
            Offset(-0.18, 0.58),
          ],
          green,
        );
      case 4: // yellow star
        final star = <Offset>[];
        for (var i = 0; i < 10; i += 1) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? 0.58 : 0.25;
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
      case 5:
        _paintAtom(canvas, center, scale, rotation, face, black);
    }
  }

'''
s = s[:insert_at] + helpers + s[insert_at:]
p.write_text(s)

# Selector pip helper lives outside the painter/state classes.
s = p.read_text()
marker = 'class _V3 {'
selector_helper = r'''class _SelectorPip extends StatelessWidget {
  const _SelectorPip();

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
  );
}

'''
s = replace_once(s, marker, selector_helper + marker, 'selector pip widget')
p.write_text(s)


# --- tests -----------------------------------------------------------------
p = Path('test/domain/board_underlay_test.dart')
s = p.read_text()
s = replace_once(
    s,
    '    expect(points.first.yMm, closeTo(104, 0.001));',
    '    expect(points.first.yMm, closeTo(110, 0.001));',
    'Petal Battle test radius',
)
needle = """  test('World War 5 is oriented sideways', () {
"""
insert = """  test('Sandships uses a central city and four corner cities', () {
    final points = BoardUnderlay.sandships.snapPoints(
      boardWidthMm: 300,
      boardHeightMm: 300,
    );
    expect(points.first, const PhysicalPoint(150, 150));
    expect(points[1].xMm, lessThan(150));
    expect(points[1].yMm, lessThan(150));
    expect(points[3].xMm, greaterThan(150));
    expect(points[3].yMm, greaterThan(150));
  });

"""
s = replace_once(s, needle, insert + needle, 'Sandships layout test')
p.write_text(s)


# --- changelog -------------------------------------------------------------
p = Path('CHANGELOG.md')
s = p.read_text()
anchor = '## Unreleased\n'
if anchor in s:
    s = s.replace(
        anchor,
        anchor + '- Refined Safety Tips, dice bubble, Zendo stones, menus, Launchpad 23, Sandships, Petal Battle, and World War 5 labels.\n',
        1,
    )
else:
    s = '- Refined Safety Tips, dice bubble, Zendo stones, menus, Launchpad 23, Sandships, Petal Battle, and World War 5 labels.\n' + s
p.write_text(s)
