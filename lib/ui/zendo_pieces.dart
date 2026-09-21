import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/pyramid_geometry.dart';
import '../domain/zendo_geometry.dart';

class ZendoPieceSnapshot {
  const ZendoPieceSnapshot({
    required this.id,
    required this.shape,
    required this.orientation,
    required this.xFraction,
    required this.yFraction,
    required this.headingDegrees,
  });

  final int id;
  final String shape;
  final String orientation;
  final double xFraction;
  final double yFraction;
  final double headingDegrees;

  Map<String, Object?> toJson() => {
    'id': id,
    'shape': shape,
    'orientation': orientation,
    'xFraction': xFraction,
    'yFraction': yFraction,
    'headingDegrees': headingDegrees,
  };

  static ZendoPieceSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final map = raw.cast<String, Object?>();
      final id = (map['id'] as num?)?.toInt();
      final shape = map['shape'];
      final orientation = map['orientation'];
      if (id == null || shape is! String || orientation is! String) {
        return null;
      }
      return ZendoPieceSnapshot(
        id: id,
        shape: shape,
        orientation: orientation,
        xFraction: ((map['xFraction'] as num?)?.toDouble() ?? 0.5)
            .clamp(0.0, 1.0)
            .toDouble(),
        yFraction: ((map['yFraction'] as num?)?.toDouble() ?? 0.5)
            .clamp(0.0, 1.0)
            .toDouble(),
        headingDegrees:
            ((map['headingDegrees'] as num?)?.toDouble() ?? 0) % 360,
      );
    } on Object {
      return null;
    }
  }
}

class ZendoPiecesSnapshot {
  const ZendoPiecesSnapshot({required this.revision, required this.pieces});

  static const initial = ZendoPiecesSnapshot(revision: 0, pieces: []);

  final int revision;
  final List<ZendoPieceSnapshot> pieces;

  Map<String, Object?> toJson() => {
    'revision': revision,
    'pieces': [for (final piece in pieces) piece.toJson()],
  };

  static ZendoPiecesSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final map = raw.cast<String, Object?>();
      final pieces = <ZendoPieceSnapshot>[];
      final rawPieces = map['pieces'];
      if (rawPieces is List) {
        for (final item in rawPieces) {
          final piece = ZendoPieceSnapshot.fromJson(item);
          if (piece != null) pieces.add(piece);
        }
      }
      return ZendoPiecesSnapshot(
        revision: (map['revision'] as num?)?.toInt() ?? 0,
        pieces: List<ZendoPieceSnapshot>.unmodifiable(pieces),
      );
    } on Object {
      return null;
    }
  }
}

class ZendoPiecesWidget extends StatefulWidget {
  const ZendoPiecesWidget({
    super.key,
    required this.geometry,
    required this.logicalPixelsPerMm,
    this.snapshot = ZendoPiecesSnapshot.initial,
    this.onChanged,
    this.showTray = true,
  });

  final PyramidGeometryProfile geometry;
  final double logicalPixelsPerMm;
  final ZendoPiecesSnapshot snapshot;
  final ValueChanged<ZendoPiecesSnapshot>? onChanged;
  final bool showTray;

  @override
  State<ZendoPiecesWidget> createState() => _ZendoPiecesWidgetState();
}

class _ZendoPiece {
  const _ZendoPiece({
    required this.id,
    required this.shape,
    required this.orientation,
    required this.center,
    required this.headingDegrees,
  });

  final int id;
  final ZendoPieceShape shape;
  final ZendoPieceOrientation orientation;
  final Offset center;
  final double headingDegrees;

  _ZendoPiece copyWith({
    ZendoPieceOrientation? orientation,
    Offset? center,
    double? headingDegrees,
  }) => _ZendoPiece(
    id: id,
    shape: shape,
    orientation: orientation ?? this.orientation,
    center: center ?? this.center,
    headingDegrees: headingDegrees ?? this.headingDegrees,
  );
}

class _ZendoPiecesWidgetState extends State<ZendoPiecesWidget> {
  final GlobalKey _surfaceKey = GlobalKey();
  final List<_ZendoPiece> _pieces = [];
  Size _surfaceSize = Size.zero;
  ZendoPiecesSnapshot? _pendingSnapshot;
  int _revision = 0;
  int _appliedRevision = -1;
  int _nextId = 1;
  int? _trayDragId;
  double _gestureStartHeading = 0;

  double get _pixelsPerMm => widget.logicalPixelsPerMm;

  @override
  void initState() {
    super.initState();
    _pendingSnapshot = widget.snapshot;
  }

  @override
  void didUpdateWidget(covariant ZendoPiecesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapshot.revision == _appliedRevision) return;
    _pendingSnapshot = widget.snapshot;
    if (_surfaceSize != Size.zero) {
      _applySnapshot(widget.snapshot, _surfaceSize);
      if (mounted) setState(() {});
    }
  }

  ZendoPieceShape? _shape(String name) =>
      ZendoPieceShape.values.where((value) => value.name == name).firstOrNull;

  ZendoPieceOrientation? _orientation(String name) => ZendoPieceOrientation
      .values
      .where((value) => value.name == name)
      .firstOrNull;

  void _applySnapshot(ZendoPiecesSnapshot snapshot, Size size) {
    if (snapshot.revision == _appliedRevision) return;
    _pieces.clear();
    var maximumId = 0;
    for (final item in snapshot.pieces) {
      final shape = _shape(item.shape);
      final orientation = _orientation(item.orientation);
      if (shape == null || orientation == null) continue;
      if (item.id > maximumId) maximumId = item.id;
      _pieces.add(
        _ZendoPiece(
          id: item.id,
          shape: shape,
          orientation: orientation,
          center: _clamp(
            Offset(item.xFraction * size.width, item.yFraction * size.height),
            size,
          ),
          headingDegrees: item.headingDegrees,
        ),
      );
    }
    _nextId = maximumId + 1;
    _revision = snapshot.revision;
    _appliedRevision = snapshot.revision;
    _pendingSnapshot = null;
  }

  void _emitSnapshot() {
    final callback = widget.onChanged;
    final size = _surfaceSize;
    if (callback == null || size == Size.zero) return;
    _revision += 1;
    _appliedRevision = _revision;
    callback(
      ZendoPiecesSnapshot(
        revision: _revision,
        pieces: List<ZendoPieceSnapshot>.unmodifiable([
          for (final piece in _pieces)
            ZendoPieceSnapshot(
              id: piece.id,
              shape: piece.shape.name,
              orientation: piece.orientation.name,
              xFraction: (piece.center.dx / size.width)
                  .clamp(0.0, 1.0)
                  .toDouble(),
              yFraction: (piece.center.dy / size.height)
                  .clamp(0.0, 1.0)
                  .toDouble(),
              headingDegrees: piece.headingDegrees,
            ),
        ]),
      ),
    );
  }

  Offset _local(Offset global) {
    final box = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  double get _interactionRadius {
    final maximumMm = math.max(
      widget.geometry.mediumFlatLengthMm,
      zendoPieceHeightMm(widget.geometry),
    );
    return maximumMm * _pixelsPerMm * 0.72 + 12;
  }

  Offset _clamp(Offset center, Size size) {
    final radius = _interactionRadius;
    return Offset(
      center.dx.clamp(radius, math.max(radius, size.width - radius)).toDouble(),
      center.dy.clamp(radius, math.max(radius, size.height - radius)).toDouble(),
    );
  }

  String _shapeLabel(ZendoPieceShape shape) => switch (shape) {
    ZendoPieceShape.pyramid => 'Medium pyramid',
    ZendoPieceShape.wedge => 'Wedge',
    ZendoPieceShape.block => 'Block',
  };

  void _add(ZendoPieceShape shape, Offset center) {
    final id = _nextId++;
    setState(() {
      _pieces.add(
        _ZendoPiece(
          id: id,
          shape: shape,
          orientation: defaultZendoOrientation(shape),
          center: _clamp(center, _surfaceSize),
          headingDegrees: 0,
        ),
      );
    });
    _emitSnapshot();
  }

  void _beginTrayDrag(ZendoPieceShape shape, DragStartDetails details) {
    final id = _nextId++;
    _trayDragId = id;
    setState(() {
      _pieces.add(
        _ZendoPiece(
          id: id,
          shape: shape,
          orientation: defaultZendoOrientation(shape),
          center: _clamp(_local(details.globalPosition), _surfaceSize),
          headingDegrees: 0,
        ),
      );
    });
    _emitSnapshot();
  }

  void _updateTrayDrag(DragUpdateDetails details) {
    final id = _trayDragId;
    if (id == null) return;
    final index = _pieces.indexWhere((piece) => piece.id == id);
    if (index < 0) return;
    setState(() {
      _pieces[index] = _pieces[index].copyWith(
        center: _clamp(_local(details.globalPosition), _surfaceSize),
      );
    });
    _emitSnapshot();
  }

  void _endTrayDrag() {
    _trayDragId = null;
    _emitSnapshot();
  }

  void _cycleOrientation(int id) {
    final index = _pieces.indexWhere((piece) => piece.id == id);
    if (index < 0) return;
    final piece = _pieces[index];
    setState(() {
      _pieces[index] = piece.copyWith(
        orientation: nextZendoOrientation(piece.shape, piece.orientation),
      );
    });
    _emitSnapshot();
  }

  void _remove(int id) {
    setState(() => _pieces.removeWhere((piece) => piece.id == id));
    _emitSnapshot();
  }

  void _gestureStart(_ZendoPiece piece) {
    _gestureStartHeading = piece.headingDegrees;
  }

  void _gestureUpdate(int id, ScaleUpdateDetails details) {
    final index = _pieces.indexWhere((piece) => piece.id == id);
    if (index < 0) return;
    final piece = _pieces[index];
    setState(() {
      _pieces[index] = piece.copyWith(
        center: _clamp(piece.center + details.focalPointDelta, _surfaceSize),
        headingDegrees:
            (_gestureStartHeading + details.rotation * 180 / math.pi) % 360,
      );
    });
    _emitSnapshot();
  }

  Widget _trayButton(ZendoPieceShape shape) => Tooltip(
    message: 'Add ' + _shapeLabel(shape),
    child: GestureDetector(
      onTap: () => _add(
        shape,
        Offset(_surfaceSize.width / 2, _surfaceSize.height / 2),
      ),
      onPanStart: (details) => _beginTrayDrag(shape, details),
      onPanUpdate: _updateTrayDrag,
      onPanEnd: (_) => _endTrayDrag(),
      onPanCancel: _endTrayDrag,
      child: SizedBox.square(
        dimension: 38,
        child: CustomPaint(
          painter: _ZendoTrayPiecePainter(shape: shape),
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
          if (widget.showTray)
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: const Color(0xCC171717),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _trayButton(ZendoPieceShape.pyramid),
                      _trayButton(ZendoPieceShape.wedge),
                      _trayButton(ZendoPieceShape.block),
                    ],
                  ),
                ),
              ),
            ),
          for (final piece in _pieces)
            Positioned(
              left: piece.center.dx - _interactionRadius,
              top: piece.center.dy - _interactionRadius,
              width: _interactionRadius * 2,
              height: _interactionRadius * 2,
              child: Tooltip(
                message:
                    '${_shapeLabel(piece.shape)} · '
                    '${zendoOrientationLabel(piece.orientation)} · '
                    'tap to change orientation · drag/twist to move/rotate · '
                    'double-tap to remove',
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _cycleOrientation(piece.id),
                  onDoubleTap: () => _remove(piece.id),
                  onScaleStart: (_) => _gestureStart(piece),
                  onScaleUpdate: (details) =>
                      _gestureUpdate(piece.id, details),
                  child: CustomPaint(
                    painter: _ZendoFootprintPainter(
                      piece: piece,
                      geometry: widget.geometry,
                      logicalPixelsPerMm: _pixelsPerMm,
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

class _ZendoFootprintPainter extends CustomPainter {
  const _ZendoFootprintPainter({
    required this.piece,
    required this.geometry,
    required this.logicalPixelsPerMm,
  });

  final _ZendoPiece piece;
  final PyramidGeometryProfile geometry;
  final double logicalPixelsPerMm;

  @override
  void paint(Canvas canvas, Size size) {
    final local = zendoLocalFootprint(
      piece.shape,
      piece.orientation,
      geometry,
    );
    if (local.isEmpty) return;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(piece.headingDegrees * math.pi / 180);

    final path = Path();
    for (var i = 0; i < local.length; i += 1) {
      final point = local[i];
      final p = Offset(
        point.xMm * logicalPixelsPerMm,
        point.yMm * logicalPixelsPerMm,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ZendoFootprintPainter oldDelegate) =>
      oldDelegate.piece != piece ||
      oldDelegate.geometry != geometry ||
      oldDelegate.logicalPixelsPerMm != logicalPixelsPerMm;
}

class _ZendoTrayPiecePainter extends CustomPainter {
  const _ZendoTrayPiecePainter({required this.shape});

  final ZendoPieceShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round;
    final center = Offset(size.width / 2, size.height / 2);
    switch (shape) {
      case ZendoPieceShape.pyramid:
        final path = Path()
          ..moveTo(center.dx, 7)
          ..lineTo(size.width - 8, size.height - 8)
          ..lineTo(8, size.height - 8)
          ..close();
        canvas.drawPath(path, paint);
      case ZendoPieceShape.wedge:
        final path = Path()
          ..moveTo(7, size.height - 8)
          ..lineTo(size.width - 7, size.height - 8)
          ..lineTo(size.width - 7, 9)
          ..close();
        canvas.drawPath(path, paint);
      case ZendoPieceShape.block:
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 23, height: 27),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _ZendoTrayPiecePainter oldDelegate) =>
      oldDelegate.shape != shape;
}
