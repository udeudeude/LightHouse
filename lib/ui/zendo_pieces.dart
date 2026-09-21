import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ZendoPieceSet { pyramids, boxed, both }

enum ZendoPieceKind { pyramid, wedge, block }

enum ZendoPiecePose { upright, flat, cheesecake, doorstop }

const double zendoMediumBaseMm = 19.84375;
const double zendoMediumHeightMm = 34.925;
double get zendoWedgeSlopedLengthMm => math.sqrt(
  zendoMediumBaseMm * zendoMediumBaseMm +
      zendoMediumHeightMm * zendoMediumHeightMm,
);

class ZendoPieceSnapshot {
  const ZendoPieceSnapshot({
    required this.id,
    required this.kind,
    required this.pose,
    required this.size,
    required this.xFraction,
    required this.yFraction,
    required this.headingDegrees,
  });

  final int id;
  final String kind;
  final String pose;
  final String size;
  final double xFraction;
  final double yFraction;
  final double headingDegrees;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'pose': pose,
    'size': size,
    'xFraction': xFraction,
    'yFraction': yFraction,
    'headingDegrees': headingDegrees,
  };

  static ZendoPieceSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final map = raw.cast<String, Object?>();
      final id = (map['id'] as num?)?.toInt();
      final kind = map['kind'];
      final pose = map['pose'];
      final size = map['size'];
      if (id == null || kind is! String || pose is! String || size is! String) {
        return null;
      }
      return ZendoPieceSnapshot(
        id: id,
        kind: kind,
        pose: pose,
        size: size,
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
    this.snapshot = ZendoPiecesSnapshot.initial,
    this.onChanged,
    this.scale = 1,
    this.pixelsPerMm = 1,
    this.pieceSet = ZendoPieceSet.both,
    this.showTray = true,
  });

  final ZendoPiecesSnapshot snapshot;
  final ValueChanged<ZendoPiecesSnapshot>? onChanged;
  final double scale;
  final double pixelsPerMm;
  final ZendoPieceSet pieceSet;
  final bool showTray;

  @override
  State<ZendoPiecesWidget> createState() => _ZendoPiecesWidgetState();
}

class _Piece {
  const _Piece({
    required this.id,
    required this.kind,
    required this.pose,
    required this.size,
    required this.center,
    required this.headingDegrees,
  });

  final int id;
  final ZendoPieceKind kind;
  final ZendoPiecePose pose;
  final String size;
  final Offset center;
  final double headingDegrees;

  _Piece copyWith({
    ZendoPiecePose? pose,
    Offset? center,
    double? headingDegrees,
  }) => _Piece(
    id: id,
    kind: kind,
    pose: pose ?? this.pose,
    size: size,
    center: center ?? this.center,
    headingDegrees: headingDegrees ?? this.headingDegrees,
  );
}

class _ZendoPiecesWidgetState extends State<ZendoPiecesWidget> {
  final GlobalKey _surfaceKey = GlobalKey();
  final List<_Piece> _pieces = [];
  Size _surfaceSize = Size.zero;
  ZendoPiecesSnapshot? _pendingSnapshot;
  int _nextId = 1;
  int _revision = 0;
  int _appliedRevision = -1;
  int? _gestureId;
  double _gestureStartHeading = 0;
  Offset _gestureStartCenter = Offset.zero;

  double get _uiScale => widget.scale.clamp(0.25, 4.0);
  double get _ppm => math.max(0.1, widget.pixelsPerMm);

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

  ZendoPieceKind? _kind(String value) =>
      ZendoPieceKind.values.where((item) => item.name == value).firstOrNull;

  ZendoPiecePose? _pose(String value) =>
      ZendoPiecePose.values.where((item) => item.name == value).firstOrNull;

  void _applySnapshot(ZendoPiecesSnapshot snapshot, Size size) {
    if (snapshot.revision == _appliedRevision) return;
    _pieces.clear();
    var maximumId = 0;
    for (final item in snapshot.pieces) {
      final kind = _kind(item.kind);
      final pose = _pose(item.pose);
      if (kind == null || pose == null) continue;
      maximumId = math.max(maximumId, item.id);
      _pieces.add(
        _Piece(
          id: item.id,
          kind: kind,
          pose: pose,
          size: item.size,
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

  void _emit(Size size) {
    final callback = widget.onChanged;
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
              kind: piece.kind.name,
              pose: piece.pose.name,
              size: piece.size,
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

  Offset _clamp(Offset center, Size size) => Offset(
    center.dx.clamp(8.0, math.max(8.0, size.width - 8)).toDouble(),
    center.dy.clamp(8.0, math.max(8.0, size.height - 8)).toDouble(),
  );

  void _add(ZendoPieceKind kind, String size, Size boardSize) {
    final id = _nextId++;
    final offset = Offset(((id % 5) - 2) * 10.0, ((id % 4) - 1.5) * 10.0);
    setState(() {
      _pieces.add(
        _Piece(
          id: id,
          kind: kind,
          pose: ZendoPiecePose.upright,
          size: size,
          center: _clamp(
            Offset(boardSize.width / 2, boardSize.height / 2) + offset,
            boardSize,
          ),
          headingDegrees: 0,
        ),
      );
    });
    _emit(boardSize);
  }

  void _cyclePose(int id) {
    final index = _pieces.indexWhere((piece) => piece.id == id);
    if (index < 0) return;
    final piece = _pieces[index];
    final next = switch (piece.kind) {
      ZendoPieceKind.pyramid =>
        piece.pose == ZendoPiecePose.upright
            ? ZendoPiecePose.flat
            : ZendoPiecePose.upright,
      ZendoPieceKind.block =>
        piece.pose == ZendoPiecePose.upright
            ? ZendoPiecePose.flat
            : ZendoPiecePose.upright,
      ZendoPieceKind.wedge => switch (piece.pose) {
        ZendoPiecePose.upright => ZendoPiecePose.cheesecake,
        ZendoPiecePose.cheesecake => ZendoPiecePose.doorstop,
        _ => ZendoPiecePose.upright,
      },
    };
    setState(() => _pieces[index] = piece.copyWith(pose: next));
    _emit(_surfaceSize);
  }

  void _remove(int id) {
    setState(() => _pieces.removeWhere((piece) => piece.id == id));
    _emit(_surfaceSize);
  }

  void _onScaleStart(int id, ScaleStartDetails details) {
    final piece = _pieces.where((item) => item.id == id).firstOrNull;
    if (piece == null) return;
    _gestureId = id;
    _gestureStartCenter = piece.center;
    _gestureStartHeading = piece.headingDegrees;
  }

  void _onScaleUpdate(int id, ScaleUpdateDetails details) {
    if (_gestureId != id) return;
    final index = _pieces.indexWhere((piece) => piece.id == id);
    if (index < 0) return;
    final nextHeading =
        (_gestureStartHeading + details.rotation * 180 / math.pi) % 360;
    final nextCenter = _clamp(
      _gestureStartCenter + details.focalPointDelta,
      _surfaceSize,
    );
    _gestureStartCenter = nextCenter;
    _gestureStartHeading = nextHeading;
    setState(() {
      _pieces[index] = _pieces[index].copyWith(
        center: nextCenter,
        headingDegrees: nextHeading,
      );
    });
  }

  void _onScaleEnd(int id) {
    if (_gestureId != id) return;
    _gestureId = null;
    _emit(_surfaceSize);
  }

  double _baseMm(_Piece piece) => switch (piece.size) {
    'small' => 14.2875,
    'large' => 25.4,
    _ => zendoMediumBaseMm,
  };

  double _heightMm(_Piece piece) => switch (piece.size) {
    'small' => 25.4,
    'large' => 44.45,
    _ => zendoMediumHeightMm,
  };

  Size _footprintSize(_Piece piece) {
    final base = _baseMm(piece) * _ppm;
    final height = _heightMm(piece) * _ppm;
    return switch ((piece.kind, piece.pose)) {
      (_, ZendoPiecePose.upright) => Size(base, base),
      (ZendoPieceKind.pyramid, _) => Size(base, height),
      (ZendoPieceKind.block, _) => Size(base, height),
      (ZendoPieceKind.wedge, ZendoPiecePose.cheesecake) => Size(base, height),
      (ZendoPieceKind.wedge, ZendoPiecePose.doorstop) => Size(
        base,
        zendoWedgeSlopedLengthMm * _ppm,
      ),
      _ => Size(base, base),
    };
  }

  Widget _pieceWidget(_Piece piece) {
    final footprint = _footprintSize(piece);
    final hitSize = math.max(44.0 * _uiScale, footprint.longestSide + 16);
    return Positioned(
      left: piece.center.dx - hitSize / 2,
      top: piece.center.dy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: Tooltip(
        message: _pieceLabel(piece),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) => _onScaleStart(piece.id, details),
          onScaleUpdate: (details) => _onScaleUpdate(piece.id, details),
          onScaleEnd: (_) => _onScaleEnd(piece.id),
          onDoubleTap: () => _cyclePose(piece.id),
          onLongPress: () => _remove(piece.id),
          child: Center(
            child: Transform.rotate(
              angle: piece.headingDegrees * math.pi / 180,
              child: CustomPaint(
                size: footprint,
                painter: _ZendoFootprintPainter(piece: piece),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _pieceLabel(_Piece piece) {
    final size = piece.size[0].toUpperCase();
    final shape = switch (piece.kind) {
      ZendoPieceKind.pyramid => 'pyramid',
      ZendoPieceKind.wedge => 'wedge',
      ZendoPieceKind.block => 'block',
    };
    return '$size $shape · ${piece.pose.name} · drag/twist · double-tap pose · hold remove';
  }

  Widget _trayButton(
    ZendoPieceKind kind,
    String size,
    String label,
    Size boardSize,
  ) => Tooltip(
    message: 'Add $label',
    child: InkWell(
      borderRadius: BorderRadius.circular(6 * _uiScale),
      onTap: () => _add(kind, size, boardSize),
      child: Container(
        width: 34 * _uiScale,
        height: 34 * _uiScale,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11 * _uiScale,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );

  List<Widget> _trayItems(Size size) {
    final items = <Widget>[];
    if (widget.pieceSet == ZendoPieceSet.pyramids ||
        widget.pieceSet == ZendoPieceSet.both) {
      items.addAll([
        _trayButton(ZendoPieceKind.pyramid, 'small', 'S△', size),
        _trayButton(ZendoPieceKind.pyramid, 'medium', 'M△', size),
        _trayButton(ZendoPieceKind.pyramid, 'large', 'L△', size),
      ]);
    }
    if (widget.pieceSet == ZendoPieceSet.boxed ||
        widget.pieceSet == ZendoPieceSet.both) {
      items.addAll([
        _trayButton(ZendoPieceKind.pyramid, 'medium', 'M△', size),
        _trayButton(ZendoPieceKind.wedge, 'medium', 'W', size),
        _trayButton(ZendoPieceKind.block, 'medium', 'B', size),
      ]);
    }
    return items;
  }

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
              top: 8 * _uiScale,
              left: 8 * _uiScale,
              child: Material(
                color: const Color(0xCC171717),
                borderRadius: BorderRadius.circular(10 * _uiScale),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3 * _uiScale),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _trayItems(size),
                  ),
                ),
              ),
            ),
          for (final piece in _pieces) _pieceWidget(piece),
        ],
      );
    },
  );
}

class _ZendoFootprintPainter extends CustomPainter {
  const _ZendoFootprintPainter({required this.piece});

  final _Piece piece;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final center = Offset(size.width / 2, size.height / 2);

    if (piece.pose == ZendoPiecePose.upright) {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, edge);
      if (piece.kind == ZendoPieceKind.pyramid) {
        canvas.drawLine(rect.topLeft, rect.bottomRight, edge);
        canvas.drawLine(rect.topRight, rect.bottomLeft, edge);
      } else if (piece.kind == ZendoPieceKind.wedge) {
        canvas.drawLine(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          edge,
        );
      }
      return;
    }

    if (piece.kind == ZendoPieceKind.pyramid ||
        piece.pose == ZendoPiecePose.cheesecake) {
      final triangle = Path()
        ..moveTo(center.dx, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(triangle, fill);
      canvas.drawPath(triangle, edge);
      if (piece.kind == ZendoPieceKind.wedge) {
        canvas.drawCircle(center, 1.7, edge);
      }
      return;
    }

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, edge);
    if (piece.kind == ZendoPieceKind.wedge) {
      canvas.drawLine(rect.topLeft, rect.bottomRight, edge);
    }
  }

  @override
  bool shouldRepaint(covariant _ZendoFootprintPainter oldDelegate) =>
      oldDelegate.piece.kind != piece.kind ||
      oldDelegate.piece.pose != piece.pose ||
      oldDelegate.piece.size != piece.size;
}
