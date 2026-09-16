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
