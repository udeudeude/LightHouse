import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    this.scale = 1,
  });

  final ZendoStonesSnapshot snapshot;
  final ValueChanged<ZendoStonesSnapshot>? onChanged;
  final double scale;

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
  double get _scale => widget.scale.clamp(0.25, 4.0);
  double get _smallRadius => 10.5 * _scale;
  double get _largeRadius => 21 * _scale;
  final GlobalKey _surfaceKey = GlobalKey();
  final List<_ZendoStone> _stones = [];
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
    _emitSnapshot(size);
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
    _emitSnapshot(size);
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
    _emitSnapshot(size);
  }

  void _endTrayDrag() {
    final id = _trayDragStoneId;
    _trayDragStoneId = null;
    if (id == null) return;
    final index = _stones.indexWhere((stone) => stone.id == id);
    if (index < 0) return;
    setState(() => _stones[index] = _stones[index].copyWith(expanded: true));
    _emitSnapshot(_surfaceSize);
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
    _emitSnapshot(size);
  }

  void _remove(int id) {
    setState(() {
      _stones.removeWhere((stone) => stone.id == id);
    });
    _emitSnapshot(_surfaceSize);
  }

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
          padding: EdgeInsets.all(5 * _scale),
          child: Container(
            width: 18 * _scale,
            height: 18 * _scale,
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
      _surfaceSize = size;
      final pending = _pendingSnapshot;
      if (pending != null) _applySnapshot(pending, size);
      return Stack(
        key: _surfaceKey,
        children: [
          Positioned(
            top: 8 * _scale,
            right: 8 * _scale,
            child: Material(
              color: const Color(0xCC171717),
              borderRadius: BorderRadius.circular(18 * _scale),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 3 * _scale),
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
              left: stone.center.dx - _largeRadius - 5 * _scale,
              top: stone.center.dy - _largeRadius - 5 * _scale,
              width: (_largeRadius + 5 * _scale) * 2,
              height: (_largeRadius + 5 * _scale) * 2,
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: _ZendoStonePainter(
                          fill: _fill(stone.kind),
                          lightBorder: stone.kind != _ZendoStoneKind.white,
                        ),
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


class _ZendoStonePainter extends CustomPainter {
  const _ZendoStonePainter({
    required this.fill,
    required this.lightBorder,
  });

  final Color fill;
  final bool lightBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius - 0.6,
      Paint()
        ..color = lightBorder ? Colors.white70 : Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15,
    );

    final sheen = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.55),
        radius: 0.82,
        colors: [
          Colors.white.withValues(alpha: 0.52),
          Colors.white.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0, 0.32, 0.82],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 1.2, sheen);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      math.pi * 1.05,
      math.pi * 0.56,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, radius * 0.085)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ZendoStonePainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.lightBorder != lightBorder;
}
