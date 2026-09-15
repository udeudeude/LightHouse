import 'package:flutter/material.dart';

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
          center: _clamp(
            Offset(size.width / 2, size.height / 2) + offset,
            size,
          ),
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
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 2,
                  spreadRadius: 1,
                ),
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
                  onPanUpdate: (details) =>
                      _move(stone.id, details.delta, size),
                  onDoubleTap: () => _remove(stone.id),
                  onLongPress: () => _remove(stone.id),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutBack,
                      width: (stone.expanded ? _largeRadius : _smallRadius) * 2,
                      height:
                          (stone.expanded ? _largeRadius : _smallRadius) * 2,
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
