from pathlib import Path
import re


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 exact match, found {count}')
    return text.replace(old, new, 1)


def sub_once(text, pattern, repl, label, flags=0):
    out, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 regex match, found {count}')
    return out


p = Path('lib/domain/board_underlay.dart')
s = p.read_text()
s = replace_once(s, '  petalBattle,\n  worldWar5;', '  petalBattle,\n  sandships,\n  martianBackgammon,\n  worldWar5;', 'underlay enum')
s = replace_once(s, '  static const double petalRadiusMm = 54;', '  static const double petalRadiusMm = 46;', 'petal radius')
s = replace_once(s, "    BoardUnderlay.petalBattle => 'Petal Battle',\n    BoardUnderlay.worldWar5 => 'World War 5',", "    BoardUnderlay.petalBattle => 'Petal Battle',\n    BoardUnderlay.sandships => 'Sandships',\n    BoardUnderlay.martianBackgammon => 'Martian Backgammon',\n    BoardUnderlay.worldWar5 => 'World War 5',", 'underlay labels')
s = replace_once(s, '      BoardUnderlay.petalBattle => _petalPoints(center),\n      BoardUnderlay.worldWar5 => _worldWarPoints(center),', '      BoardUnderlay.petalBattle => _petalPoints(center),\n      BoardUnderlay.sandships => _sandshipsPoints(center),\n      BoardUnderlay.martianBackgammon => _rectGridPoints(center, 5, 4),\n      BoardUnderlay.worldWar5 => _worldWarPoints(center),', 'underlay snap switch')
s = replace_once(s, '''List<PhysicalPoint> _worldWarPoints(PhysicalPoint center) {
  const horizontal = 52.0;
  const vertical = 38.0;
  const spread = 12.0;
  final continentCenters = <PhysicalPoint>[
    PhysicalPoint(center.xMm - horizontal, center.yMm - vertical),
    PhysicalPoint(center.xMm - horizontal * 0.72, center.yMm + vertical),
    PhysicalPoint(center.xMm - 8, center.yMm - vertical * 1.12),
    PhysicalPoint(center.xMm + 1, center.yMm + vertical * 0.60),
    PhysicalPoint(center.xMm + horizontal * 0.70, center.yMm - vertical * 0.86),
    PhysicalPoint(center.xMm + horizontal, center.yMm + vertical * 1.06),
  ];
  return [
    for (var c = 0; c < continentCenters.length; c += 1)
      for (var i = 0; i < 3; i += 1)
        PhysicalPoint(
          continentCenters[c].xMm +
              spread * math.cos((i + c * 0.2) * 2 * math.pi / 3),
          continentCenters[c].yMm +
              spread * math.sin((i + c * 0.2) * 2 * math.pi / 3),
        ),
  ];
}
''', '''List<PhysicalPoint> _sandshipsPoints(PhysicalPoint center) => [
  center,
  PhysicalPoint(center.xMm, center.yMm - 48),
  PhysicalPoint(center.xMm + 58, center.yMm),
  PhysicalPoint(center.xMm, center.yMm + 48),
  PhysicalPoint(center.xMm - 58, center.yMm),
];

List<PhysicalPoint> _worldWarPoints(PhysicalPoint center) {
  const horizontal = 52.0;
  const vertical = 38.0;
  const spread = 12.0;
  final portraitCenters = <PhysicalPoint>[
    PhysicalPoint(center.xMm - horizontal, center.yMm - vertical),
    PhysicalPoint(center.xMm - horizontal * 0.72, center.yMm + vertical),
    PhysicalPoint(center.xMm - 8, center.yMm - vertical * 1.12),
    PhysicalPoint(center.xMm + 1, center.yMm + vertical * 0.60),
    PhysicalPoint(center.xMm + horizontal * 0.70, center.yMm - vertical * 0.86),
    PhysicalPoint(center.xMm + horizontal, center.yMm + vertical * 1.06),
  ];
  final continentCenters = [
    for (final point in portraitCenters)
      PhysicalPoint(
        center.xMm - (point.yMm - center.yMm),
        center.yMm + (point.xMm - center.xMm),
      ),
  ];
  return [
    for (var c = 0; c < continentCenters.length; c += 1)
      for (var i = 0; i < 3; i += 1)
        PhysicalPoint(
          continentCenters[c].xMm +
              spread * math.cos(math.pi / 2 + (i + c * 0.2) * 2 * math.pi / 3),
          continentCenters[c].yMm +
              spread * math.sin(math.pi / 2 + (i + c * 0.2) * 2 * math.pi / 3),
        ),
  ];
}
''', 'world war rotation')
p.write_text(s)

p = Path('lib/ui/board_painter.dart')
s = p.read_text()
s = replace_once(s, "import 'physical_point.dart';", "import 'physical_point.dart';\nimport 'special_board_painter.dart';", 'special board painter import')
s = replace_once(s, '''      case BoardUnderlay.petalBattle:
        _paintPetalBattle(canvas, size);
        return;
      case BoardUnderlay.worldWar5:
        _paintWorldWar5(canvas, size);
        return;''', '''      case BoardUnderlay.petalBattle:
        _paintPetalBattle(canvas, size);
        return;
      case BoardUnderlay.sandships:
        SpecialBoardPainter(logicalPixelsPerMm).paintSandships(canvas, size);
        return;
      case BoardUnderlay.martianBackgammon:
        SpecialBoardPainter(logicalPixelsPerMm).paintMartianBackgammon(canvas, size);
        return;
      case BoardUnderlay.worldWar5:
        _paintWorldWar5(canvas, size);
        return;''', 'special board painter switch')
s = replace_once(s, '''    final orbit = BoardUnderlay.petalRadiusMm * logicalPixelsPerMm;
    final petalLength = orbit * 0.58;
    final petalWidth = orbit * 0.31;''', '''    final orbit = BoardUnderlay.petalRadiusMm * logicalPixelsPerMm;
    final petalLength = 31.3 * logicalPixelsPerMm;
    final petalWidth = 16.7 * logicalPixelsPerMm;''', 'petal dimensions')
s = replace_once(s, '    canvas.drawCircle(center, orbit * 0.25, _linePaint(0.24));', '    canvas.drawCircle(center, 13.5 * logicalPixelsPerMm, _linePaint(0.24));', 'petal center circle')
s = replace_once(s, '          ? _apexRoundedTriangle(points, math.min(base, flatLength) * 0.12)', '          ? _apexRoundedTriangle(points, math.min(base, flatLength) * 0.18)', 'triangle rounding')
p.write_text(s)

p = Path('lib/ui/toy_overlay.dart')
s = p.read_text()
s = replace_once(s, '      final alpha = i == 0 ? 0.68 : 0.01 + (1 - i / 12) * 0.18;', '      final alpha = i == 0 ? 0.72 : 0.025 + (1 - i / 12) * 0.23;', 'radar trail brightness')
s = sub_once(s, r'''  void _paintGun\(Canvas canvas, Offset center, double angleDegrees\) \{.*?\n  \}\n\n  void _paintRounds\(.*?\n  \}\n\n  void _paintGuns''', '''  void _paintGun(Canvas canvas, Offset center, double angleDegrees) {
    final radians = angleDegrees * math.pi / 180;
    final direction = Offset(math.cos(radians), math.sin(radians));
    final normal = Offset(-direction.dy, direction.dx);
    final body = Path()
      ..moveTo(center.dx + normal.dx * 6.4, center.dy + normal.dy * 6.4)
      ..lineTo(center.dx - normal.dx * 6.4, center.dy - normal.dy * 6.4)
      ..lineTo(center.dx + direction.dx * 14 - normal.dx * 4.2, center.dy + direction.dy * 14 - normal.dy * 4.2)
      ..lineTo(center.dx + direction.dx * 14 + normal.dx * 4.2, center.dy + direction.dy * 14 + normal.dy * 4.2)
      ..close();
    canvas.drawPath(body, Paint()..color = Colors.white.withValues(alpha: 0.34));
    canvas.drawLine(
      center + direction * 10,
      center + direction * 26,
      Paint()..color = Colors.white.withValues(alpha: 0.60)..strokeWidth = 4,
    );
  }

  void _paintRounds(Canvas canvas, Offset gunCenter, int gunIndex, int count) {
    if (count <= 0) return;
    final visible = math.min(5, count);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.68);
    for (var i = 0; i < visible; i += 1) {
      final delta = (i - (visible - 1) / 2) * 6.2;
      final point = switch (gunIndex) {
        0 => gunCenter + Offset(15, delta),
        1 => gunCenter + Offset(-15, delta),
        2 => gunCenter + Offset(delta, 15),
        _ => gunCenter + Offset(delta, -15),
      };
      canvas.drawCircle(point, 2.15, paint);
    }
  }

  void _paintGuns''', 'gun painter replacement', flags=re.S)
s = replace_once(s, '''      final centers = <Offset>[
        Offset(8, size.height / 2),
        Offset(size.width - 8, size.height / 2),
        Offset(size.width / 2, 8),
        Offset(size.width / 2, size.height - 8),
      ];''', '''      final centers = <Offset>[
        Offset(14, size.height / 2),
        Offset(size.width - 14, size.height / 2),
        Offset(size.width / 2, 14),
        Offset(size.width / 2, size.height - 14),
      ];''', 'gun centers')
s = sub_once(s, r'''          _paintRounds\(\n            canvas,\n            centers\[i\],\n            sideGunAnglesDegrees\[i\],\n            sideGunAmmo\[i\],\n          \);''', '          _paintRounds(canvas, centers[i], i, sideGunAmmo[i]);', 'gun rounds call')
p.write_text(s)

p = Path('lib/ui/board_screen_next.dart')
s = p.read_text()
s = replace_once(s, "import 'board_painter.dart';\nimport 'toy_overlay.dart';", "import 'board_painter.dart';\nimport 'credits_overlay.dart';\nimport 'dice_bubble.dart';\nimport 'toy_overlay.dart';\nimport 'zendo_stones.dart';", 'board screen imports')
s = replace_once(s, "  wireDie('D6', Icons.casino, false),", "  wireDie('Dice Bubble', Icons.casino, false),", 'dice label')
s = replace_once(s, "  squareChase('Square Chase', Icons.crop_square, false);", "  squareChase('Square Chase', Icons.crop_square, false),\n  zendoStones('Zendo Stones', Icons.circle_outlined, false);", 'zendo toy enum')
s = sub_once(s, r'''  int _dieValue = 1;\n  double _dieRollPhase = 0;\n  double _dieRollProgress = 1;\n  DateTime\? _dieRollEndsAt;\n  bool _diePressed = false;\n''', '', 'old die state')
s = replace_once(s, '  List<PhysicalPoint> _constellation = const [];', '  List<String> _constellationElementIds = const [];', 'constellation state')
s = replace_once(s, '  int _faceUpStableSamples = 0;', '  int _faceUpStableSamples = 0;\n  double? _lastDominantZSign;', 'dominant z state')
s = replace_once(s, '    final sign = z.sign;\n    if (_faceUpZSign == null) {', '    final sign = z.sign;\n    _lastDominantZSign = sign;\n    if (_faceUpZSign == null) {', 'remember z sign')
s = sub_once(s, r'''      case _ToyKind\.wireDie:\n        _dieRollEndsAt = null;\n        _dieRollPhase = 0;\n        _dieRollProgress = 1;\n        _diePressed = false;''', '''      case _ToyKind.wireDie:
      case _ToyKind.zendoStones:''', 'deactivate overlays')
s = replace_once(s, '''      case _ToyKind.constellationDraw:
        _constellation = const [];''', '''      case _ToyKind.constellationDraw:
        _constellationElementIds = const [];''', 'deactivate constellation')
s = replace_once(s, '''      case _ToyKind.constellationDraw:
        _toggleConstellation();''', '''      case _ToyKind.constellationDraw:
        _toggleConstellation();
      case _ToyKind.zendoStones:
        _toggleOverlayToy(toy);''', 'activate zendo')
s = replace_once(s, '''      _ToyKind.constellationDraw => _constellation.isNotEmpty,
      _ToyKind.breathing ||''', '''      _ToyKind.constellationDraw => _constellationElementIds.isNotEmpty,
      _ToyKind.zendoStones => _activeToys.contains(_ToyKind.zendoStones),
      _ToyKind.breathing ||''', 'toy active zendo')
s = sub_once(s, r'''  void _toggleDie\(\) \{.*?\n  \}\n\n  void _rollWireDie\(\) \{.*?\n  \}\n\n  void _pressDie\(\) \{.*?\n  \}\n\n  void _releaseDie\(\) \{.*?\n  \}\n''', '''  void _toggleOverlayToy(_ToyKind toy) {
    setState(() {
      if (!_activeToys.add(toy)) _activeToys.remove(toy);
    });
  }

  void _toggleDie() => _toggleOverlayToy(_ToyKind.wireDie);

''', 'old die methods', flags=re.S)
s = replace_once(s, '      _sideGunAmmo[i] += 5;', '      _sideGunAmmo[i] = 5;', 'gun fixed ammo')
s = replace_once(s, '    final inset = 8 / widget.logicalPixelsPerMm;', '    final inset = 14 / widget.logicalPixelsPerMm;', 'gun projectile inset')
s = replace_once(s, '''    final center = switch (gunIndex) {
      0 => const Offset(8, box / 2),
      1 => const Offset(box - 8, box / 2),
      2 => const Offset(box / 2, 8),
      _ => const Offset(box / 2, box - 8),
    };''', '''    final center = switch (gunIndex) {
      0 => const Offset(14, box / 2),
      1 => const Offset(box - 14, box / 2),
      2 => const Offset(box / 2, 14),
      _ => const Offset(box / 2, box - 14),
    };''', 'gun aim center')
s = replace_once(s, '      _turnTimerProgress != null ||\n      _dieRollEndsAt != null ||\n      _projectiles.isNotEmpty ||', '      _turnTimerProgress != null ||\n      _projectiles.isNotEmpty ||', 'ticker removes die')
s = sub_once(s, r'''\n    final dieEnds = _dieRollEndsAt;\n    if \(dieEnds != null\) \{.*?\n    \}\n\n    _tickProjectiles''', '\n    _tickProjectiles', 'old die tick', flags=re.S)
s = sub_once(s, r'''  void _toggleConstellation\(\) \{.*?\n  \}\n\n  PhysicalPoint\? _nearestUnderlaySnapPoint''', '''  void _toggleConstellation() {
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
      if (_controller.state.elementById(id) case final element?) element.position,
  ];

  PhysicalPoint? _nearestUnderlaySnapPoint''', 'live constellation', flags=re.S)
s = replace_once(s, '''    return _controller.state.underlay.nearestSnapPoint(
      target.position,
      boardWidthMm: widthPx / widget.logicalPixelsPerMm,
      boardHeightMm: heightPx / widget.logicalPixelsPerMm,
    );''', '''    final snap = _controller.state.underlay.nearestSnapPoint(
      target.position,
      boardWidthMm: widthPx / widget.logicalPixelsPerMm,
      boardHeightMm: heightPx / widget.logicalPixelsPerMm,
    );
    if (snap == null || _controller.state.underlay != BoardUnderlay.wheel || target.pose != PyramidPose.flat) return snap;
    final centroidOffset = rotateVector(
      PhysicalPoint(0, _controller.geometry.flatLengthMm(target.size) / 6),
      target.headingDegrees,
    );
    return snap - centroidOffset;''', 'wheel snap correction')
s = replace_once(s, '''    setState(() {
      if (_selectedId != null &&
          _controller.state.elementById(_selectedId!) == null) {
        _selectedId = null;
      }
    });''', '''    final liveIds = _controller.state.elements.map((e) => e.id).toSet();
    _constellationElementIds = [for (final id in _constellationElementIds) if (liveIds.contains(id)) id];
    setState(() {
      if (_selectedId != null && _controller.state.elementById(_selectedId!) == null) _selectedId = null;
    });''', 'refresh constellation pruning')
s = sub_once(s, r'''    final instructions = isDesktop\n        \? <\(String, String\)>\[.*?\n          \];\n\n    return SafeArea\(''', '''    final instructions = isDesktop
        ? <(String, String)>[
            ('Create / resize / delete', 'Double-click'),
            ('Tip / stand', 'Drag through the footprint edge'),
            ('Full / wall light', 'Draw a loop around an upright footprint'),
            ('Move', 'Two-finger scroll over a footprint'),
            ('Rotate', 'Shift + two-finger scroll'),
            ('Board snap', 'Boards > Snap pieces to board'),
            ('Dice bubble', 'Hold/release to roll; latch selects up to 3 dice'),
            ('Zendo stones', 'Use the tray; drag stones; double-click to remove'),
            ('Toys', 'Toys chooses controls; hold an icon for its name'),
          ]
        : <(String, String)>[
            ('Create / resize / delete', 'Double-tap'),
            ('Tip / stand', 'Drag through the footprint edge'),
            ('Full / wall light', 'Draw a loop around an upright footprint'),
            ('Move + rotate', 'Two-finger drag and twist'),
            ('Board snap', 'Boards > Snap pieces to board'),
            ('Dice bubble', 'Hold/release to roll; 2 fingers move; latch selects dice'),
            ('Zendo stones', 'Use the tray; drag stones; double-tap to remove'),
            ('Toys', 'Toys chooses controls; hold an icon for its name'),
          ];

    return SafeArea(''', 'instructions content', flags=re.S)
s = sub_once(s, r'''  Widget _credits\(\) => GestureDetector\(.*?\n  \);\n\n  Widget _buildBoardSurface''', '''  void _dismissCreditsAndRecalibrate() {
    _faceDownTimer?.cancel();
    _faceDownTimer = null;
    final sign = _lastDominantZSign;
    final angle = kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? currentWebOrientationAngle() : null;
    setState(() {
      if (sign != null) _faceUpZSign = sign;
      _faceUpCandidateSign = null;
      _faceUpStableSamples = 0;
      _faceDownLatched = false;
      _creditsVisible = false;
      if (angle != null) {
        _webReferenceOrientationAngle = angle;
        _webObservedOrientationAngle = angle;
      }
    });
  }

  Widget _credits() => CreditsOverlay(
    onCloseAndRecalibrate: _dismissCreditsAndRecalibrate,
    onOpenGithub: () => unawaited(_openGithub()),
  );

  Widget _buildBoardSurface''', 'credits widget', flags=re.S)
s = sub_once(s, r'''                dieValue: _activeToys\.contains\(_ToyKind\.wireDie\)\n                    \? _dieValue\n                    : null,\n                dieRollPhase: _dieRollPhase,\n                dieRollProgress: _dieRollProgress,\n                diePressed: _diePressed,''', '''                dieValue: null,
                dieRollPhase: 0,
                dieRollProgress: 1,
                diePressed: false,''', 'disable legacy die painter')
s = replace_once(s, '                constellation: _constellation,', '                constellation: _constellationPoints,', 'live constellation overlay')
s = sub_once(s, r'''        if \(_activeToys\.contains\(_ToyKind\.wireDie\)\)\n          Positioned\(.*?\n          \),\n        if \(_activeToys\.contains\(_ToyKind\.sideGuns\)\)''', '''        if (_activeToys.contains(_ToyKind.wireDie)) const DiceBubble(),
        if (_activeToys.contains(_ToyKind.zendoStones)) const ZendoStonesWidget(),
        if (_activeToys.contains(_ToyKind.sideGuns))''', 'dice bubble and zendo overlays', flags=re.S)
s = sub_once(s, r'''\nclass _CreditsMarkPainter extends CustomPainter \{.*?\n\}\n\nclass _MenuCirclePainter''', '\nclass _MenuCirclePainter', 'remove legacy credits painter', flags=re.S)
p.write_text(s)

p = Path('test/domain/board_underlay_test.dart')
s = p.read_text()
s = replace_once(s, "import 'package:flutter_test/flutter_test.dart';", "import 'dart:math' as math;\n\nimport 'package:flutter_test/flutter_test.dart';", 'math test import')
s = replace_once(s, '''    expect(
      BoardUnderlay.worldWar5.snapPoints(boardWidthMm: 300, boardHeightMm: 300),
      hasLength(18),
    );''', '''    expect(BoardUnderlay.sandships.snapPoints(boardWidthMm: 300, boardHeightMm: 300), hasLength(5));
    expect(BoardUnderlay.martianBackgammon.snapPoints(boardWidthMm: 300, boardHeightMm: 300), hasLength(20));
    expect(BoardUnderlay.worldWar5.snapPoints(boardWidthMm: 300, boardHeightMm: 300), hasLength(18));''', 'special board tests')
s = replace_once(s, '''  test('Looney Ludo four-board start exposes four 3 by 3 grids', () {''', '''  test('Petal Battle moves its petal centers inward', () {
    final points = BoardUnderlay.petalBattle.snapPoints(boardWidthMm: 300, boardHeightMm: 300);
    expect(points.first.yMm, closeTo(104, 0.001));
  });

  test('World War 5 is oriented sideways', () {
    final points = BoardUnderlay.worldWar5.snapPoints(boardWidthMm: 300, boardHeightMm: 300);
    final xs = points.map((p) => p.xMm);
    final ys = points.map((p) => p.yMm);
    final xSpan = xs.reduce(math.max) - xs.reduce(math.min);
    final ySpan = ys.reduce(math.max) - ys.reduce(math.min);
    expect(ySpan, greaterThan(xSpan));
  });

  test('Looney Ludo four-board start exposes four 3 by 3 grids', () {''', 'new geometry tests')
p.write_text(s)

p = Path('CHANGELOG.md')
s = p.read_text()
s = replace_once(s, '## Unreleased\n\n', '''## Unreleased

- Refined flat-pyramid rendering, live constellation anchors, radar trails, side guns, and concise device instructions.
- Rebuilt the dice toy as a movable Pop-O-Matic-style bubble with up to three selectable Pyramid Arcade dice and research-informed damped rolling.
- Added independent movable Zendo marking/guessing stones.
- Redesigned credits with an Art Deco lighthouse mark, explicit orientation recalibration control, and the LightHouse haiku.
- Added Sandships and Martian Backgammon boards, turned World War 5 sideways, tightened Petal Battle, and corrected Wheel snapping for flat pyramids.
''', 'changelog revision')
p.write_text(s)
