from pathlib import Path
import re


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"missing marker: {label}")
    return text.replace(old, new, 1)


def replace_regex(text, pattern, replacement, label):
    next_text, count = re.subn(
        pattern,
        lambda _: replacement,
        text,
        count=1,
        flags=re.S,
    )
    if count != 1:
        raise SystemExit(f"missing regex marker: {label} ({count})")
    return next_text


# Preserve the live table state when calibration temporarily replaces the table screen.
main = read('lib/main.dart')
main = replace_once(
    main,
    '''  void _recalibrate() {
    setState(() {
      _calibrationBeforeManual = _calibration;
      _forceManualCalibration = true;
      _calibration = null;
    });
  }
''',
    '''  void _recalibrate(BoardState currentTable) {
    setState(() {
      _board = currentTable;
      _calibrationBeforeManual = _calibration;
      _forceManualCalibration = true;
      _calibration = null;
    });
  }
''',
    'recalibration live state',
)
main = main.replace(
    '''      _calibrationBeforeManual = null;
      _forceManualCalibration = false;
      _calibrationBeforeManual = null;
''',
    '''      _calibrationBeforeManual = null;
      _forceManualCalibration = false;
''',
)
main = replace_once(
    main,
    '''      _forceManualCalibration = false;
    });
  }

  @override
  Widget build''',
    '''      _forceManualCalibration = false;
      _calibrationBeforeManual = null;
    });
  }

  @override
  Widget build''',
    'clear calibration backup after save',
)
write('lib/main.dart', main)

# Add GitHub link support.
pubspec = read('pubspec.yaml')
pubspec = replace_once(
    pubspec,
    '  shared_preferences: ^2.5.5\n  wakelock_plus: ^1.8.0\n',
    '  shared_preferences: ^2.5.5\n  url_launcher: ^6.3.2\n  wakelock_plus: ^1.8.0\n',
    'url launcher dependency',
)
write('pubspec.yaml', pubspec)

screen = read('lib/ui/board_screen_next.dart')
screen = replace_once(
    screen,
    "import 'package:shared_preferences/shared_preferences.dart';\n",
    "import 'package:shared_preferences/shared_preferences.dart';\nimport 'package:url_launcher/url_launcher.dart';\n",
    'url launcher import',
)
screen = screen.replace("wireDie('Wireframe d6', Icons.casino, false)", "wireDie('D6', Icons.casino, false)")
screen = screen.replace('  final VoidCallback onRecalibrate;\n', '  final ValueChanged<BoardState> onRecalibrate;\n')

screen = replace_once(
    screen,
    '  bool _gridSnapEnabled = false;\n  bool _transformTranslated = false;\n',
    '  bool _gridSnapEnabled = false;\n  bool _checkerUnderlays = false;\n  bool _transformTranslated = false;\n',
    'checker state',
)
screen = replace_once(
    screen,
    '  DateTime? _dieRollEndsAt;\n  List<ToyProjectile> _projectiles = const [];\n',
    '  DateTime? _dieRollEndsAt;\n  bool _diePressed = false;\n  List<ToyProjectile> _projectiles = const [];\n',
    'die pressed state',
)
screen = replace_once(
    screen,
    '  double _lastGunShotClock = -10;\n  final List<double> _sideGunAnglesDegrees = [0, 180, 90, 270];\n',
    '  final List<double> _sideGunAnglesDegrees = [0, 180, 90, 270];\n  final List<int> _sideGunAmmo = [0, 0, 0, 0];\n',
    'gun ammo state',
)

screen = replace_once(
    screen,
    "      _gridSnapEnabled =\n          preferences.getBool('lighthouse.gridSnapEnabled.v1') ?? false;\n",
    "      _gridSnapEnabled =\n          preferences.getBool('lighthouse.gridSnapEnabled.v1') ?? false;\n      _checkerUnderlays =\n          preferences.getBool('lighthouse.checkerUnderlays.v1') ?? false;\n",
    'load checker preference',
)

checker_method = '''  Future<void> _toggleCheckerUnderlays() async {
    setState(() => _checkerUnderlays = !_checkerUnderlays);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      'lighthouse.checkerUnderlays.v1',
      _checkerUnderlays,
    );
  }

'''
screen = replace_once(
    screen,
    '  Future<void> _toggleRoundedTriangleTips() async {',
    checker_method + '  Future<void> _toggleRoundedTriangleTips() async {',
    'checker preference method',
)

screen = replace_once(
    screen,
    '''      case _ToyKind.wireDie:
        _dieRollEndsAt = null;
        _dieRollPhase = 0;
        _dieRollProgress = 1;
      case _ToyKind.sideGuns:
        _projectiles = _projectiles.where((p) => p.ricochet).toList();
''',
    '''      case _ToyKind.wireDie:
        _dieRollEndsAt = null;
        _dieRollPhase = 0;
        _dieRollProgress = 1;
        _diePressed = false;
      case _ToyKind.sideGuns:
        _projectiles = _projectiles.where((p) => p.ricochet).toList();
        for (var i = 0; i < _sideGunAmmo.length; i += 1) {
          _sideGunAmmo[i] = 0;
        }
''',
    'deactivate die guns',
)
screen = replace_once(
    screen,
    '''      case _ToyKind.wireDie:
        _rollWireDie();
      case _ToyKind.sideGuns:
        _toggleSideGuns();
''',
    '''      case _ToyKind.wireDie:
        _toggleDie();
      case _ToyKind.sideGuns:
        _loadSideGuns();
''',
    'activate die guns',
)
screen = screen.replace('        _drawConstellation();\n', '        _toggleConstellation();\n', 1)

# D6 icon now only toggles the die; the die itself is the popper.
screen = replace_regex(
    screen,
    r"  void _rollWireDie\(\) \{.*?\n  \}\n\n  void _toggleSideGuns\(\) \{.*?\n  \}\n\n  PhysicalPoint _velocityForDegrees",
    r'''  void _toggleDie() {
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

  PhysicalPoint _velocityForDegrees''',
    'die and gun activation',
)

# Replace volley firing with one aimed round per release.
screen = replace_regex(
    screen,
    r"  void _spawnSideVolley\(\) \{.*?\n  \}\n\n  void _aimGunFromLocal",
    r'''  void _fireSideGun(int index) {
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

  void _aimGunFromLocal''',
    'single gun firing',
)

# Side guns no longer keep the animation clock alive or fire on a timer.
screen = screen.replace('      _activeToys.contains(_ToyKind.sideGuns) ||\n', '')
screen = replace_regex(
    screen,
    r"\n    if \(_activeToys\.contains\(_ToyKind\.sideGuns\) &&\n        _toyClock - _lastGunShotClock >= 0\.85\) \{\n      _spawnSideVolley\(\);\n      _lastGunShotClock = _toyClock;\n    \}\n",
    '\n',
    'remove continuous gun firing',
)

# Red sweep at half speed and heartbeat waits before drifting out of phase.
screen = screen.replace('final phase = (_toyClock * 0.30) % 2;', 'final phase = (_toyClock * 0.15) % 2;')
screen = replace_once(
    screen,
    '    final drift = odd ? math.min(math.pi, elapsed * 0.23) : 0.0;\n',
    '    final separationTime = math.max(0.0, elapsed - 4.0);\n    final drift = odd ? math.min(math.pi, separationTime * 0.23) : 0.0;\n',
    'heartbeat delay',
)

# Constellations alternate draw -> clear -> new draw, with no timeout.
screen = replace_regex(
    screen,
    r"  void _drawConstellation\(\) \{.*?\n  \}\n\n  PhysicalPoint\? _nearestUnderlaySnapPoint",
    r'''  void _toggleConstellation() {
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

  PhysicalPoint? _nearestUnderlaySnapPoint''',
    'constellation toggle',
)

# Recalibration receives the live table state.
screen = screen.replace('    if (recalibrate == true) widget.onRecalibrate();', '    if (recalibrate == true) widget.onRecalibrate(_controller.state);')

# Visual angle menu items.
angle_helper = '''  PopupMenuItem<String> _angleMenuItem(double angle) => PopupMenuItem<String>(
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

'''
screen = replace_once(
    screen,
    '  Future<void> _showOrientationMenu() async {',
    angle_helper + '  Future<void> _showOrientationMenu() async {',
    'angle menu helper',
)
screen = replace_regex(
    screen,
    r"    final choice = await _showCompactMenu\(\[\n      for \(final angle in angles\)\n        _compactMenuItem\(\n          'a\$\{angle\.toInt\(\)\}',\n          Icons\.navigation_outlined,\n          '\$\{angle\.toInt\(\)\}°',\n        \),\n    \]\);",
    "    final choice = await _showCompactMenu([\n      for (final angle in angles) _angleMenuItem(angle),\n    ]);",
    'visual orientation menu',
)

# Boards get their own compact top-level menu.
screen = replace_once(
    screen,
    "      _compactMenuItem('edit', Icons.edit_outlined, 'Edit'),\n      _compactMenuItem('toys', Icons.toys_outlined, 'Toys'),\n",
    "      _compactMenuItem('edit', Icons.edit_outlined, 'Edit'),\n      _compactMenuItem('boards', Icons.grid_on, 'Boards'),\n      _compactMenuItem('toys', Icons.toys_outlined, 'Toys'),\n",
    'boards top level item',
)
screen = replace_once(
    screen,
    "      case 'edit':\n        await _showEditMenu();\n      case 'toys':\n",
    "      case 'edit':\n        await _showEditMenu();\n      case 'boards':\n        await _showBoardsMenu();\n      case 'toys':\n",
    'boards top level action',
)

# Replace the long underlay list with compact categories. Snap and None remain at the bottom.
screen = replace_regex(
    screen,
    r"  Future<void> _showUnderlayMenu\(\) async \{.*?\n  \}\n\n  IconData _toyIcon",
    r'''  void _toggleUnderlaySelection(BoardUnderlay underlay) {
    _selectUnderlay(
      _controller.state.underlay == underlay ? BoardUnderlay.none : underlay,
    );
  }

  Future<void> _showBoardsMenu() async {
    final choice = await _showCompactMenu([
      _compactMenuItem('games', Icons.dashboard_customize_outlined, 'Game Boards'),
      _compactMenuItem('grids', Icons.grid_4x4, 'Grids'),
      _compactMenuItem('chess', Icons.grid_view, 'Martian Chess'),
      _compactMenuItem(
        'checker',
        Icons.checkerboard,
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

  IconData _toyIcon''',
    'boards menu redesign',
)

# Remove Underlays from the Toys panel.
screen = replace_regex(
    screen,
    r"                        InkWell\(\n                          borderRadius: BorderRadius\.circular\(6\),\n                          onTap: \(\) \{\n                            Navigator\.pop\(dialogContext\);\n                            Future<void>\.microtask\(_showUnderlayMenu\);\n                          \},.*?                        const Divider\(height: 8\),\n",
    '',
    'remove underlays from toys',
)

# Instructions reflect the new menu and explain long-press toy names.
screen = screen.replace("Menu > Toys > Underlays > Snap pieces to underlay", "Menu > Boards > Snap pieces to board")
screen = screen.replace(
    "('More toys', 'Menu > Toys controls which toy icons appear'),",
    "('Toy names', 'Press and hold a toy icon to pop up its name'),\n            ('More toys', 'Menu > Toys controls which toy icons appear'),",
)

# Wrap the instruction list so added help remains usable on smaller phones.
screen = replace_once(
    screen,
    '''                    for (final item in instructions)
                      Padding(
''',
    '''                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final item in instructions)
                              Padding(
''',
    'instructions scroll start',
)
screen = replace_once(
    screen,
    '''                          ),
                        ),
                      ),
                  ],
                ),
''',
    '''                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
''',
    'instructions scroll end',
)

# Generic toy controls keep their native long-press tooltip; turn timer also gets a visible tooltip wrapper.
screen = replace_once(
    screen,
    '''      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
''',
    '''      return Tooltip(
        message: toy.label,
        triggerMode: TooltipTriggerMode.longPress,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
''',
    'timer tooltip start',
)
screen = replace_once(
    screen,
    '''          ],
        ),
      );
    }
    return IconButton(
''',
    '''            ],
          ),
        ),
      );
    }
    return IconButton(
''',
    'timer tooltip end',
)

# Guns aim continuously but fire only when the finger is released.
screen = replace_once(
    screen,
    '''        onPanUpdate: (details) =>
            _aimGunFromLocal(index, details.localPosition),
      ),
''',
    '''        onPanUpdate: (details) =>
            _aimGunFromLocal(index, details.localPosition),
        onPanEnd: (_) => _fireSideGun(index),
        onTapUp: (_) => _fireSideGun(index),
      ),
''',
    'gun fire on release',
)

# Credits get a compact Art Deco mark, the requested line break, and a live GitHub link.
open_github = '''  Future<void> _openGithub() async {
    final uri = Uri.parse('https://github.com/udeudeude/LightHouse-StashBoard');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

'''
screen = replace_once(screen, '  Widget _credits() => GestureDetector(', open_github + '  Widget _credits() => GestureDetector(', 'github method')
screen = replace_regex(
    screen,
    r"  Widget _credits\(\) => GestureDetector\(.*?\n  \);\n\n  Widget _buildBoardSurface",
    r'''  Widget _credits() => GestureDetector(
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
                  label: const Text('github.com/udeudeude/LightHouse-StashBoard'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildBoardSurface''',
    'credits redesign',
)

# Feed checker state, D6 press state, and gun ammunition to painters.
screen = replace_once(
    screen,
    '                  roundTriangleTips: _roundedTriangleTips,\n                  burstProgress: _burstProgress,\n',
    '                  roundTriangleTips: _roundedTriangleTips,\n                  checkerUnderlays: _checkerUnderlays,\n                  burstProgress: _burstProgress,\n',
    'checker painter arg',
)
screen = replace_once(
    screen,
    '                dieRollProgress: _dieRollProgress,\n                projectiles: _projectiles,\n',
    '                dieRollProgress: _dieRollProgress,\n                diePressed: _diePressed,\n                projectiles: _projectiles,\n',
    'die pressed painter arg',
)
screen = replace_once(
    screen,
    '                sideGunAnglesDegrees: _sideGunAnglesDegrees,\n                cornerGunsVisible:',
    '                sideGunAnglesDegrees: _sideGunAnglesDegrees,\n                sideGunAmmo: _sideGunAmmo,\n                cornerGunsVisible:',
    'gun ammo painter arg',
)

# The D6 itself is an interactive popper target at the top-left of the usable table.
die_interaction = '''        if (_activeToys.contains(_ToyKind.wireDie))
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
'''
screen = replace_once(
    screen,
    '        if (_activeToys.contains(_ToyKind.sideGuns))\n          Padding(padding: safePadding, child: _sideGunAimHandles()),\n',
    die_interaction + '        if (_activeToys.contains(_ToyKind.sideGuns))\n          Padding(padding: safePadding, child: _sideGunAimHandles()),\n',
    'die interaction target',
)

# Add the Art Deco credit mark painter before the menu-ring painter.
credits_painter = r'''class _CreditsMarkPainter extends CustomPainter {
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
    canvas.drawLine(Offset(c.dx - 14, beamY), Offset(size.width * 0.14, beamY - 18), faint);
    canvas.drawLine(Offset(c.dx - 14, beamY), Offset(size.width * 0.10, beamY + 5), faint);
    canvas.drawLine(Offset(c.dx + 14, beamY), Offset(size.width * 0.86, beamY - 18), faint);
    canvas.drawLine(Offset(c.dx + 14, beamY), Offset(size.width * 0.90, beamY + 5), faint);

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

'''
screen = replace_once(screen, 'class _MenuCirclePainter extends CustomPainter {', credits_painter + 'class _MenuCirclePainter extends CustomPainter {', 'credits painter')

write('lib/ui/board_screen_next.dart', screen)
print('revision v4 UI applied')
