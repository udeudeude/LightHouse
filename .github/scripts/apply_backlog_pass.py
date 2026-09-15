from pathlib import Path
import re


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"{path}: expected one match, found {count}: {old[:160]!r}"
        )
    path.write_text(text.replace(old, new, 1))


def replace_once_in_segment(
    path: Path,
    start_marker: str,
    end_marker: str,
    old: str,
    new: str,
) -> None:
    text = path.read_text()
    start = text.index(start_marker)
    end = text.index(end_marker, start + len(start_marker))
    segment = text[start:end]
    count = segment.count(old)
    if count != 1:
        raise SystemExit(
            f"{path}: expected one segment match, found {count}: {old[:160]!r}"
        )
    segment = segment.replace(old, new, 1)
    path.write_text(text[:start] + segment + text[end:])


# BoardState: build immutable indexes once per immutable state instead of scanning
# element and structure lists repeatedly during interaction and painting.
path = Path("lib/domain/board_state.dart")
replace_once(
    path,
    """  }) : elements = List.unmodifiable(elements),
       structures = List.unmodifiable(structures);
""",
    """  }) : elements = List.unmodifiable(elements),
       structures = List.unmodifiable(structures) {
    _elementsById = Map<String, LightElement>.unmodifiable(
      _indexElements(this.elements),
    );
    _structureByElementId = Map<String, LightStructure>.unmodifiable(
      _indexStructures(this.structures),
    );
  }
""",
)
replace_once(
    path,
    """  final BoardUnderlay underlay;

  LightElement? elementById(String id) {
    for (final element in elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  LightStructure? structureForElement(String id) {
    for (final structure in structures) {
      if (structure.memberIds.contains(id)) return structure;
    }
    return null;
  }
""",
    """  final BoardUnderlay underlay;

  late final Map<String, LightElement> _elementsById;
  late final Map<String, LightStructure> _structureByElementId;

  static Map<String, LightElement> _indexElements(
    Iterable<LightElement> elements,
  ) {
    final result = <String, LightElement>{};
    for (final element in elements) {
      result.putIfAbsent(element.id, () => element);
    }
    return result;
  }

  static Map<String, LightStructure> _indexStructures(
    Iterable<LightStructure> structures,
  ) {
    final result = <String, LightStructure>{};
    for (final structure in structures) {
      for (final id in structure.memberIds) {
        result.putIfAbsent(id, () => structure);
      }
    }
    return result;
  }

  LightElement? elementById(String id) => _elementsById[id];

  LightStructure? structureForElement(String id) =>
      _structureByElementId[id];
""",
)
replace_once(
    path,
    """        .toList();

    if (version == 1) {
""",
    """        .toList();
    final elementIds = {for (final element in elements) element.id};

    if (version == 1) {
""",
)
replace_once(
    path,
    """            (structure) => structure.memberIds.every(
              (id) => elements.any((element) => element.id == id),
            ),
""",
    """            (structure) => structure.memberIds.every(elementIds.contains),
""",
)


# BoardStore: expose the recovery copy already maintained internally.
path = Path("lib/application/board_store.dart")
replace_once(
    path,
    "  Future<void> save(BoardState state) {\n",
    """  Future<BoardState?> loadBackup() async {
    try {
      await _saveTail;
    } on Object {
      // A failed current save does not make an older backup unusable.
    }
    final raw = await SharedPreferencesAsync().getString(_backupKey);
    if (raw == null) return null;
    try {
      return _decodeBoard(raw);
    } on Object {
      return null;
    }
  }

  Future<void> save(BoardState state) {
""",
)


# BoardController: a recovery restore is a semantic, undoable board change.
path = Path("lib/application/board_controller.dart")
replace_once(
    path,
    "  void newBoard() => replaceState(BoardState.empty());\n",
    """  void restoreState(BoardState state) {
    _execute(ReplaceBoardStateCommand(before: _state, after: state));
  }

  void newBoard() => replaceState(BoardState.empty());
""",
)


# Board screen: real elapsed toy time, cached Red Sweep geometry, recovery UI.
path = Path("lib/ui/board_screen_next.dart")
replace_once(
    path,
    """  Timer? _toyTicker;
  final ValueNotifier<int> _toyRevision = ValueNotifier<int>(0);
""",
    """  Timer? _toyTicker;
  DateTime? _lastToyTickAt;
  final ValueNotifier<int> _toyRevision = ValueNotifier<int>(0);
""",
)
replace_once(
    path,
    """  final Map<String, List<PhysicalPoint>> _ghostTrails = {};
  bool _ghostTrailActive = false;
""",
    """  final Map<String, List<PhysicalPoint>> _ghostTrails = {};
  final Map<String, ({double minY, double maxY})> _elementVerticalBounds = {};
  bool _ghostTrailActive = false;
""",
)
replace_once(
    path,
    """    _toyTicker?.cancel();
    _toyTicker = null;
    unawaited(_flushPendingSave());
""",
    """    _toyTicker?.cancel();
    _toyTicker = null;
    _lastToyTickAt = null;
    unawaited(_flushPendingSave());
""",
)
replace_once(
    path,
    """  void _ensureToyTicker() {
    _toyTicker ??= Timer.periodic(const Duration(milliseconds: 33), (_) {
      _tickToys(0.033);
    });
  }
""",
    """  void _ensureToyTicker() {
    if (_toyTicker != null) return;
    _lastToyTickAt = DateTime.now();
    _toyTicker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final now = DateTime.now();
      final previous = _lastToyTickAt;
      _lastToyTickAt = now;
      final elapsedSeconds = previous == null
          ? 0.033
          : now.difference(previous).inMicroseconds / 1000000;
      _tickToys(elapsedSeconds.clamp(0.0, 0.1).toDouble());
    });
  }
""",
)
replace_once(
    path,
    """  void _maybeStopToyTicker() {
    if (_needsToyTicker) return;
    _toyTicker?.cancel();
    _toyTicker = null;
  }
""",
    """  void _maybeStopToyTicker() {
    if (_needsToyTicker) return;
    _toyTicker?.cancel();
    _toyTicker = null;
    _lastToyTickAt = null;
  }
""",
)
replace_once(path, "    _updateContinuousLighting();\n", "    _updateContinuousLighting(dt);\n")
replace_once(
    path,
    "  void _updateContinuousLighting() {\n",
    """  ({double minY, double maxY}) _verticalBoundsFor(
    LightElement element,
  ) {
    final cached = _elementVerticalBounds[element.id];
    if (cached != null) return cached;
    final polygon = polygonForElement(element, _controller.geometry);
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final point in polygon) {
      minY = math.min(minY, point.yMm);
      maxY = math.max(maxY, point.yMm);
    }
    final bounds = (minY: minY, maxY: maxY);
    _elementVerticalBounds[element.id] = bounds;
    return bounds;
  }

  void _updateContinuousLighting(double dt) {
""",
)
replace_once_in_segment(
    path,
    "  void _updateContinuousLighting(double dt) {",
    "\n  Map<String, double> get _paintElementOpacities",
    "_radarAngleDegrees = normalizeDegrees(_radarAngleDegrees + 1.8);",
    """_radarAngleDegrees = normalizeDegrees(
        _radarAngleDegrees + (1.8 / 0.033) * dt,
      );""",
)
replace_once_in_segment(
    path,
    "  void _updateContinuousLighting(double dt) {",
    "\n  Map<String, double> get _paintElementOpacities",
    """        final polygon = polygonForElement(element, _controller.geometry);
        final minY = polygon.map((p) => p.yMm).reduce(math.min);
        final maxY = polygon.map((p) => p.yMm).reduce(math.max);
        opacity = math.min(
          opacity,
          lineY >= minY && lineY <= maxY ? 1.0 : 0.035,
        );
""",
    """        final bounds = _verticalBoundsFor(element);
        opacity = math.min(
          opacity,
          lineY >= bounds.minY && lineY <= bounds.maxY ? 1.0 : 0.035,
        );
""",
)
replace_once(
    path,
    """  void _refresh() {
    if (!mounted) return;
""",
    """  void _refresh() {
    if (!mounted) return;
    _elementVerticalBounds.clear();
""",
)
replace_once(
    path,
    "  Future<void> _saveBoard({bool asCopy = false}) async {\n",
    """  Future<void> _restoreAutosaveBackup(BoardState backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore previous autosave?'),
        content: const Text(
          'Replace the current table with the previous autosaved snapshot? '
          'You can use Undo immediately afterward to return to the current table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _controller.restoreState(backup);
    setState(() => _activeSavedId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Previous autosave restored. Undo can reverse it.'),
      ),
    );
  }

  Future<void> _saveBoard({bool asCopy = false}) async {
""",
)
replace_once(
    path,
    """  Future<void> _showFileMenu() async {
    final choice = await _showCompactMenu([
      _compactMenuItem('new', Icons.note_add_outlined, 'New'),
      _compactMenuItem('open', Icons.folder_open, 'Open…'),
      _compactMenuItem('save', Icons.save_outlined, 'Save'),
""",
    """  Future<void> _showFileMenu() async {
    await _flushPendingSave();
    final backup = await _store.loadBackup();
    if (!mounted) return;
    final choice = await _showCompactMenu([
      _compactMenuItem('new', Icons.note_add_outlined, 'New'),
      _compactMenuItem('open', Icons.folder_open, 'Open…'),
      _compactMenuItem(
        'restore',
        Icons.history,
        'Restore Previous Autosave…',
        enabled: backup != null,
      ),
      _compactMenuItem('save', Icons.save_outlined, 'Save'),
""",
)
replace_once(
    path,
    """      case 'open':
        await _manageSavedBoards();
      case 'save':
""",
    """      case 'open':
        await _manageSavedBoards();
      case 'restore':
        if (backup != null) await _restoreAutosaveBackup(backup);
      case 'save':
""",
)


# Retire the obsolete alternate screen implementation and normalize naming.
replace_once(
    path,
    "class BoardScreenNext extends StatefulWidget {",
    "class BoardScreen extends StatefulWidget {",
)
replace_once(path, "  const BoardScreenNext({", "  const BoardScreen({")
replace_once(
    path,
    "  State<BoardScreenNext> createState() => _BoardScreenNextState();",
    "  State<BoardScreen> createState() => _BoardScreenState();",
)
replace_once(
    path,
    "class _BoardScreenNextState extends State<BoardScreenNext>",
    "class _BoardScreenState extends State<BoardScreen>",
)
legacy = Path("lib/ui/board_screen.dart")
legacy.unlink()
path.rename(legacy)
main = Path("lib/main.dart")
replace_once(main, "import 'ui/board_screen_next.dart';", "import 'ui/board_screen.dart';")
replace_once(main, "    return BoardScreenNext(", "    return BoardScreen(")


# Regression tests.
additions = {
    "test/application/board_controller_test.dart": r'''

  test('restoring a snapshot is undoable', () {
    final controller = BoardController();
    controller.createAt(const PhysicalPoint(25, 40));
    final before = controller.state;
    final backup = BoardState(title: 'Recovered snapshot');

    controller.restoreState(backup);
    expect(controller.state.title, 'Recovered snapshot');
    expect(controller.state.elements, isEmpty);

    controller.undo();
    expect(controller.state.title, before.title);
    expect(controller.state.elements, orderedEquals(before.elements));
  });
''',
    "test/domain/board_state_test.dart": r'''

  test('element and structure lookups use indexed membership', () {
    const a = LightElement(
      id: 'a',
      size: PyramidSize.large,
      pose: PyramidPose.upright,
      position: PhysicalPoint.zero,
      headingDegrees: 0,
      illumination: IlluminationPattern.full,
    );
    const b = LightElement(
      id: 'b',
      size: PyramidSize.small,
      pose: PyramidPose.upright,
      position: PhysicalPoint.zero,
      headingDegrees: 0,
      illumination: IlluminationPattern.wall,
    );
    const structure = LightStructure(
      id: 's',
      kind: StructureKind.nest,
      memberIds: ['a', 'b'],
    );
    final state = BoardState(
      elements: const [a, b],
      structures: const [structure],
    );

    expect(state.elementById('b'), b);
    expect(state.elementById('missing'), isNull);
    expect(state.structureForElement('a'), structure);
    expect(state.structureForElement('missing'), isNull);
  });
''',
}
for filename, addition in additions.items():
    test_path = Path(filename)
    text = test_path.read_text()
    marker = "\n}\n"
    index = text.rfind(marker)
    if index < 0:
        raise SystemExit(f"{filename}: final brace not found")
    test_path.write_text(text[:index] + addition + text[index:])


# Documentation corrections for behavior that is already shipping.
readme = Path("README.md")
text = readme.read_text()
text = text.replace(
    "- local autosave with recovery backup, named saved boards, and JSON clipboard import/export",
    "- debounced local autosave with a user-restorable previous snapshot, named saved boards, and JSON file import/export",
)
text = text.replace(
    "- lower-left hierarchical Board > File / Underlays menu with Mac-like File ordering",
    "- lower-left hierarchical menu for File, Edit, Boards, Toys, Display, and Instructions",
)
text = text.replace(
    "- native mobile orientation lock; iPhone/iPad web freezes the opening board frame and compensates for Safari viewport rotation so the physical play surface stays fixed to the glass\n- web orientation compensation is rendering-only; saved millimeter coordinates and calibration do not change when the device turns",
    "- native mobile orientation lock; web uses ordinary browser viewport/orientation behavior without a counter-rotation workaround",
)
text = text.replace(
    "- Board > File: New, Open, Save, Save a Copy, Rename, JSON import/export\n- Board > Underlays: choose an underlay and optionally enable position snapping\n- Edit > Rotation: rotate in 15-degree steps, choose an exact orientation, or enable persistent rotation snapping",
    "- File: New, Open, Restore Previous Autosave, Save, Save a Copy, Rename, JSON import/export\n- Boards: choose an underlay, checker shading, and optional position snapping\n- Edit: undo/redo, 15-degree rotation steps, exact orientation, and persistent rotation snapping",
)
readme.write_text(text)

architecture = Path("docs/architecture.md")
text = architecture.read_text()
text = text.replace(
    "Board document format version 2 contains title, elements, and structures. Version 1 documents migrate on read.",
    "Board document format version 3 contains title, underlay, elements, and structures. Versions 1 and 2 migrate on read.",
)
text = text.replace(
    "The current board autosaves after semantic changes. Before overwriting the current snapshot, the previous snapshot is retained as a recovery backup. Named boards are stored separately. Public interchange is indented JSON and deliberately contains no Flutter implementation details.",
    "The current board autosaves shortly after changes settle, with writes serialized so rapid interactions cannot race persistence. Before overwriting the current snapshot, the previous snapshot is retained as a recovery backup and can be restored explicitly from the File menu. Named boards are stored separately. Public interchange is indented JSON and deliberately contains no Flutter implementation details.",
)
architecture.write_text(text)
