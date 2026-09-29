import 'dart:math' as math;

import 'package:flutter/widgets.dart';

Rect fitRemoteBoardRect({
  required Size hostSize,
  required EdgeInsets safePadding,
  required Size remoteSize,
}) {
  if (remoteSize.width <= 0 || remoteSize.height <= 0) {
    return Rect.fromLTWH(
      safePadding.left,
      safePadding.top,
      math.max(0.0, hostSize.width - safePadding.horizontal),
      math.max(0.0, hostSize.height - safePadding.vertical),
    );
  }
  final availableWidth = math.max(1.0, hostSize.width - safePadding.horizontal);
  final availableHeight = math.max(1.0, hostSize.height - safePadding.vertical);
  final scale = math.min(
    availableWidth / remoteSize.width,
    availableHeight / remoteSize.height,
  );
  final width = remoteSize.width * scale;
  final height = remoteSize.height * scale;
  return Rect.fromLTWH(
    safePadding.left + (availableWidth - width) / 2,
    safePadding.top + (availableHeight - height) / 2,
    width,
    height,
  );
}

/// Controller-only camera over the fitted Table Display. Board geometry stays
/// in physical millimeters; Flutter's render transform maps pointer positions
/// back to the same unzoomed board coordinates.
class RemoteViewTransform {
  const RemoteViewTransform({this.zoom = 1, this.pan = Offset.zero});

  static const minZoom = 1.0;
  static const maxZoom = 4.0;

  final double zoom;
  final Offset pan;

  RemoteViewTransform clamped(Size size) {
    final factor = zoom.clamp(minZoom, maxZoom).toDouble();
    final maxX = size.width * (factor - 1) / 2;
    final maxY = size.height * (factor - 1) / 2;
    return RemoteViewTransform(
      zoom: factor,
      pan: Offset(
        pan.dx.clamp(-maxX, maxX).toDouble(),
        pan.dy.clamp(-maxY, maxY).toDouble(),
      ),
    );
  }

  RemoteViewTransform panBy(Size size, Offset delta) =>
      RemoteViewTransform(zoom: zoom, pan: pan + delta).clamped(size);

  RemoteViewTransform zoomAt(Size size, double nextZoom, Offset focalPoint) {
    final factor = nextZoom.clamp(minZoom, maxZoom).toDouble();
    final center = size.center(Offset.zero);
    final nextPan =
        focalPoint - center - (focalPoint - center - pan) * (factor / zoom);
    return RemoteViewTransform(zoom: factor, pan: nextPan).clamped(size);
  }

  Offset boardPointAt(Size size, Offset viewPoint) {
    final center = size.center(Offset.zero);
    return center + (viewPoint - center - pan) / zoom;
  }
}
