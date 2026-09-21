import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

enum PyramidLoveToyIconKind { nest, zendoMarkers, eastQueen }

class PyramidLoveToyIcon extends StatelessWidget {
  const PyramidLoveToyIcon(
    this.kind, {
    super.key,
    this.size = 21,
    required this.color,
  });

  final PyramidLoveToyIconKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _PyramidLoveToyIconPainter(kind, color)),
  );
}

class _Glyph {
  const _Glyph(this.width, this.height, this.contours);

  final double width;
  final double height;
  final List<List<Offset>> contours;
}

class _PyramidLoveToyIconPainter extends CustomPainter {
  const _PyramidLoveToyIconPainter(this.kind, this.color);

  final PyramidLoveToyIconKind kind;
  final Color color;

  static final _nest = _Glyph(
    252,
    512,
    _flattenSvg('$_nestMain $_nestDropOne $_nestDropTwo $_nestDropThree'),
  );
  static final _zendoMarkers = _Glyph(522, 512, _flattenSvg(_zendoMarkersPath));
  static final _eastQueen = _Glyph(
    512,
    512,
    _flattenSvg(
      '$_eastQueenMain $_eastQueenPipOne $_eastQueenPipTwo $_eastQueenPipThree',
    ),
  );

  _Glyph get _glyph => switch (kind) {
    PyramidLoveToyIconKind.nest => _nest,
    PyramidLoveToyIconKind.zendoMarkers => _zendoMarkers,
    PyramidLoveToyIconKind.eastQueen => _eastQueen,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final glyph = _glyph;
    final scale =
        math.min(size.width / glyph.width, size.height / glyph.height) * 0.92;
    final offset = Offset(
      (size.width - glyph.width * scale) / 2,
      (size.height - glyph.height * scale) / 2,
    );
    final path = Path()..fillType = PathFillType.nonZero;
    for (final contour in glyph.contours) {
      if (contour.isEmpty) continue;
      path.moveTo(
        offset.dx + contour.first.dx * scale,
        offset.dy + contour.first.dy * scale,
      );
      for (final point in contour.skip(1)) {
        path.lineTo(offset.dx + point.dx * scale, offset.dy + point.dy * scale);
      }
      path.close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PyramidLoveToyIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

List<List<Offset>> _flattenSvg(String data) {
  final tokens = RegExp(r'[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')
      .allMatches(data)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final contours = <List<Offset>>[];
  var contour = <Offset>[];
  var index = 0;
  String? command;
  String? previousCommand;
  var current = Offset.zero;
  var start = Offset.zero;
  Offset? previousControl;

  bool isCommand(String token) =>
      token.length == 1 && RegExp(r'[A-Za-z]').hasMatch(token);
  bool hasNumber() => index < tokens.length && !isCommand(tokens[index]);
  double number() => double.parse(tokens[index++]);

  void finishContour() {
    if (contour.isEmpty) return;
    contours.add(contour);
    contour = <Offset>[];
  }

  void add(Offset point) {
    current = point;
    contour.add(point);
  }

  void cubic(Offset p0, Offset p1, Offset p2, Offset p3) {
    const segments = 7;
    for (var segment = 1; segment <= segments; segment += 1) {
      final t = segment / segments;
      final u = 1 - t;
      contour.add(
        Offset(
          u * u * u * p0.dx +
              3 * u * u * t * p1.dx +
              3 * u * t * t * p2.dx +
              t * t * t * p3.dx,
          u * u * u * p0.dy +
              3 * u * u * t * p1.dy +
              3 * u * t * t * p2.dy +
              t * t * t * p3.dy,
        ),
      );
    }
    current = p3;
    previousControl = p2;
  }

  while (index < tokens.length) {
    if (isCommand(tokens[index])) command = tokens[index++];
    final active = command;
    if (active == null) continue;
    switch (active) {
      case 'M':
        if (!hasNumber()) continue;
        finishContour();
        current = Offset(number(), number());
        start = current;
        contour = <Offset>[current];
        previousControl = null;
        previousCommand = 'M';
        command = 'l';
      case 'l':
        if (!hasNumber()) continue;
        add(current + Offset(number(), number()));
        previousControl = null;
        previousCommand = 'l';
      case 'h':
        if (!hasNumber()) continue;
        add(Offset(current.dx + number(), current.dy));
        previousControl = null;
        previousCommand = 'h';
      case 'v':
        if (!hasNumber()) continue;
        add(Offset(current.dx, current.dy + number()));
        previousControl = null;
        previousCommand = 'v';
      case 'c':
        if (!hasNumber()) continue;
        final p0 = current;
        final p1 = current + Offset(number(), number());
        final p2 = current + Offset(number(), number());
        final p3 = current + Offset(number(), number());
        cubic(p0, p1, p2, p3);
        previousCommand = 'c';
      case 's':
        if (!hasNumber()) continue;
        final p0 = current;
        final p1 =
            (previousCommand == 'c' || previousCommand == 's') &&
                previousControl != null
            ? current * 2 - previousControl!
            : current;
        final p2 = current + Offset(number(), number());
        final p3 = current + Offset(number(), number());
        cubic(p0, p1, p2, p3);
        previousCommand = 's';
      case 'z':
      case 'Z':
        if (contour.isNotEmpty && contour.last != start) contour.add(start);
        current = start;
        previousControl = null;
        previousCommand = active;
        finishContour();
        command = null;
      default:
        throw FormatException('Unsupported Pyramid Love SVG command: $active');
    }
  }
  finishContour();
  return contours;
}

// Exact path data from Pyramid Love 3.1/SVG/Nest.svg.
const _nestMain =
    'M241.016 503.003l-109.368-259.566c-1.008-2.395-3.364-3.961-5.972-3.961-2.601 0-4.956 1.559-5.965 3.961l-109.361 259.566c-0.842 1.997-0.63 4.286 0.57 6.098 1.201 1.805 3.224 2.899 5.394 2.899h218.729c2.176 0 4.207-1.088 5.4-2.899 1.208-1.805 1.42-4.101 0.571-6.098zM212.672 499.049l-81.024-190.458c-1.015-2.389-3.364-3.941-5.965-3.941-2.594 0-4.943 1.546-5.958 3.941l-54.173 127.328h14.079l46.046-108.233 72.903 171.363h-13.72l-52.826-123.938c-1.022-2.395-3.37-3.941-5.958-3.941-2.594 0-4.943 1.539-5.958 3.941l-25.922 60.808h14.085l17.801-41.746 44.692 104.863-144.698 0.014 99.608-236.404 99.608 236.404h-12.619z';
const _nestDropOne =
    'M62.3 450.237c-2.535 4.963-9.123 18.358-9.819 25.644-0.007 0.053-0.007 0.087-0.014 0.139-0.033 0.372-0.053 0.723-0.053 1.048 0 4.113 2.309 7.644 5.672 9.495 1.553 0.856 3.311 1.387 5.209 1.387 6.011 0 10.881-4.863 10.881-10.881 0-0.318-0.020-0.657-0.046-1.009-0.007-0.079-0.013-0.139-0.020-0.212-0.412-4.021-2.627-9.959-4.956-15.3-1.838-4.226-3.742-8.108-4.864-10.297-0.418-0.822-1.572-0.822-1.99-0.014z';
const _nestDropTwo =
    'M86.903 486.065c1.745 1.195 3.848 1.885 6.118 1.885 6.005 0 10.881-4.863 10.881-10.881 0-0.318-0.020-0.657-0.053-1.009-0.007-0.079-0.013-0.139-0.020-0.212-0.438-4.339-2.993-10.921-5.507-16.56-1.659-3.736-3.304-7.053-4.313-9.030-0.418-0.822-1.566-0.822-1.99-0.014-2.534 4.963-9.116 18.358-9.813 25.644-0.007 0.053-0.013 0.087-0.013 0.139-0.033 0.372-0.053 0.723-0.053 1.048-0.007 3.742 1.891 7.033 4.764 8.99z';
const _nestDropThree =
    'M122.737 487.949c6.011 0 10.887-4.863 10.887-10.881 0-0.318-0.020-0.657-0.060-1.009-0.006-0.079-0.013-0.139-0.020-0.212-0.723-7.212-7.285-20.634-9.813-25.591-0.418-0.822-1.573-0.822-1.99-0.014-2.541 4.963-9.123 18.358-9.82 25.644 0 0.053 0 0.087-0.007 0.139-0.033 0.372-0.053 0.723-0.053 1.048-0.007 6.011 4.864 10.875 10.874 10.875z';

// Exact path data from Pyramid Love 3.1/SVG/ComponentZendoMarkers.svg.
const _zendoMarkersPath =
    'M389.959 121.493c-35.286-60.803-100.936-101.785-176.299-101.785-112.573 0-203.815 91.243-203.815 203.815 0 83.548 50.298 155.252 122.229 186.728 35.286 60.784 100.918 101.767 176.262 101.767 112.573 0 203.834-91.243 203.834-203.815 0-83.529-50.298-155.233-122.21-186.71zM308.354 486.766c-54.787 0-103.841-24.819-136.619-63.802 13.541 2.829 27.554 4.356 41.925 4.356 112.591 0 203.853-91.243 203.853-203.815 0-22.368-3.734-43.811-10.392-63.953 48.073 32.042 79.795 86.679 79.795 148.632 0 98.485-80.096 178.582-178.563 178.582z';

// Exact path data from Pyramid Love 3.1/SVG/EastQueen.svg.
const _eastQueenMain =
    'M12.203 461.306v-390.957c0-3.957 1.991-7.654 5.296-9.857s7.476-2.594 11.148-1.066l463.936 195.478c4.384 1.848 7.25 6.161 7.25 10.923s-2.867 9.075-7.25 10.923l-463.936 195.478c-3.684 1.552-7.843 1.161-11.148-1.043s-5.296-5.9-5.296-9.88zM35.897 88.214v355.262l421.57-177.649-421.57-177.613z';
const _eastQueenPipOne =
    'M76.758 134.975c0.071 0 0.189 0 0.249 0.024 13.032 1.244 36.975 13.008 45.837 17.534 1.433 0.746 1.433 2.82 0 3.542-8.886 4.537-32.876 16.266-45.766 17.558-0.118 0.024-0.249 0.024-0.391 0.048-0.628 0.048-1.232 0.095-1.777 0.095-10.757 0-19.465-8.696-19.465-19.465 0-10.733 8.696-19.441 19.465-19.441 0.581 0.012 1.197 0.036 1.848 0.107z';
const _eastQueenPipTwo =
    'M76.758 188.098c0.071 0 0.189 0 0.249 0.024 13.032 1.244 36.975 13.008 45.837 17.534 1.433 0.758 1.433 2.82 0 3.542-8.886 4.537-32.876 16.266-45.766 17.558-0.118 0.024-0.249 0.024-0.391 0.048-0.628 0.048-1.232 0.095-1.777 0.095-10.757 0-19.465-8.72-19.465-19.453s8.696-19.465 19.465-19.465c0.581 0.012 1.197 0.059 1.848 0.119z';
const _eastQueenPipThree =
    'M76.758 241.197c0.071 0.024 0.189 0.024 0.249 0.024 13.032 1.268 36.975 13.032 45.837 17.558 1.433 0.747 1.433 2.82 0 3.543-8.886 4.538-32.876 16.266-45.766 17.558-0.118 0.024-0.249 0.024-0.391 0.048-0.628 0.048-1.232 0.095-1.777 0.095-10.757 0-19.465-8.719-19.465-19.465s8.696-19.465 19.465-19.465c0.581 0.024 1.197 0.059 1.848 0.107z';
