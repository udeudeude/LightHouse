from pathlib import Path

board = Path('lib/ui/board_screen.dart')
text = board.read_text()

old_import = "import 'dice_bubble.dart';\nimport 'toy_overlay.dart';"
new_import = "import 'dice_bubble.dart';\nimport 'remote_board_viewport.dart';\nimport 'toy_overlay.dart';"
if text.count(old_import) != 1:
    raise SystemExit('unexpected board_screen import block')
text = text.replace(old_import, new_import)

old_viewport = '''  double get _pixelsPerMm {
    final widthMm = _remoteDisplayWidthMm;
    final heightMm = _remoteDisplayHeightMm;
    if (!_remoteControllerMode || widthMm == null || heightMm == null) {
      return widget.logicalPixelsPerMm;
    }
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.viewPaddingOf(context);
    final availableWidth = math.max(1.0, size.width - safe.horizontal);
    final availableHeight = math.max(1.0, size.height - safe.vertical);
    return math.max(
      0.1,
      math.min(availableWidth / widthMm, availableHeight / heightMm),
    );
  }

  EdgeInsets _boardSurfacePadding(BuildContext surfaceContext) {
    final safe = MediaQuery.viewPaddingOf(surfaceContext);
    final widthMm = _remoteDisplayWidthMm;
    final heightMm = _remoteDisplayHeightMm;
    if (!_remoteControllerMode || widthMm == null || heightMm == null) {
      return safe;
    }
    final size = MediaQuery.sizeOf(surfaceContext);
    final availableWidth = math.max(1.0, size.width - safe.horizontal);
    final availableHeight = math.max(1.0, size.height - safe.vertical);
    final scale = math.max(
      0.1,
      math.min(availableWidth / widthMm, availableHeight / heightMm),
    );
    final extraX = math.max(0.0, (availableWidth - widthMm * scale) / 2);
    final extraY = math.max(0.0, (availableHeight - heightMm * scale) / 2);
    return EdgeInsets.fromLTRB(
      safe.left + extraX,
      safe.top + extraY,
      safe.right + extraX,
      safe.bottom + extraY,
    );
  }
'''
new_viewport = '''  Rect? _remoteBoardRect(BuildContext surfaceContext) {
    final widthMm = _remoteDisplayWidthMm;
    final heightMm = _remoteDisplayHeightMm;
    if (!_remoteControllerMode || widthMm == null || heightMm == null) {
      return null;
    }
    return fitRemoteBoardRect(
      hostSize: MediaQuery.sizeOf(surfaceContext),
      safePadding: MediaQuery.viewPaddingOf(surfaceContext),
      remoteSize: Size(widthMm, heightMm),
    );
  }

  double get _pixelsPerMm {
    final widthMm = _remoteDisplayWidthMm;
    final rect = _remoteBoardRect(context);
    if (!_remoteControllerMode || widthMm == null || rect == null) {
      return widget.logicalPixelsPerMm;
    }
    return math.max(0.1, rect.width / widthMm);
  }

  EdgeInsets _boardSurfacePadding(BuildContext surfaceContext) {
    final remoteRect = _remoteBoardRect(surfaceContext);
    if (remoteRect == null) return MediaQuery.viewPaddingOf(surfaceContext);
    final size = MediaQuery.sizeOf(surfaceContext);
    return EdgeInsets.fromLTRB(
      remoteRect.left,
      remoteRect.top,
      math.max(0.0, size.width - remoteRect.right),
      math.max(0.0, size.height - remoteRect.bottom),
    );
  }
'''
if text.count(old_viewport) != 1:
    raise SystemExit('unexpected viewport block')
text = text.replace(old_viewport, new_viewport)

old_hello = '''  Future<void> _sendRemoteHello() async {
    final session = _remoteSession;
    if (session == null) return;
    final board = _physicalBoardSize();
    await session.sendApp('hello', {
      'role': session.role.name,
      'creator': session.isCreator,
      if (session.role == RemoteRole.display) 'widthMm': board.width,
      if (session.role == RemoteRole.display) 'heightMm': board.height,
    });
  }
'''
new_hello = '''  void _captureRemoteDisplayMetrics(
    Map<String, Object?> payload, {
    RemoteRole? senderRole,
  }) {
    if (!_remoteControllerMode) return;
    final payloadRoleName = payload['role'];
    final payloadRole = RemoteRole.values
        .where((value) => value.name == payloadRoleName)
        .firstOrNull;
    final effectiveRole = payloadRole ?? senderRole;
    if (effectiveRole != RemoteRole.display) return;
    final width = (payload['widthMm'] as num?)?.toDouble();
    final height = (payload['heightMm'] as num?)?.toDouble();
    if (width == null || height == null || width <= 0 || height <= 0) {
      return;
    }
    if (_remoteDisplayWidthMm == width && _remoteDisplayHeightMm == height) {
      return;
    }
    setState(() {
      _remoteDisplayWidthMm = width;
      _remoteDisplayHeightMm = height;
    });
  }

  Future<void> _sendRemoteHello() async {
    final session = _remoteSession;
    if (session == null) return;
    final board = _physicalBoardSize();
    await session.sendApp('hello', {
      'role': session.role.name,
      'creator': session.isCreator,
      if (session.role == RemoteRole.display) 'widthMm': board.width,
      if (session.role == RemoteRole.display) 'heightMm': board.height,
    });
  }
'''
if text.count(old_hello) != 1:
    raise SystemExit('unexpected hello block')
text = text.replace(old_hello, new_hello)

old_hello_metrics = '''        if (peerRole == RemoteRole.display) {
          final width = (message.payload['widthMm'] as num?)?.toDouble();
          final height = (message.payload['heightMm'] as num?)?.toDouble();
          if (width != null && height != null && width > 0 && height > 0) {
            setState(() {
              _remoteDisplayWidthMm = width;
              _remoteDisplayHeightMm = height;
            });
          }
        }
'''
new_hello_metrics = '''        _captureRemoteDisplayMetrics(message.payload, senderRole: peerRole);
'''
if text.count(old_hello_metrics) != 1:
    raise SystemExit('unexpected hello metrics block')
text = text.replace(old_hello_metrics, new_hello_metrics)

old_cases = '''      case 'seed':
        await _applyRemoteState(message.payload, force: true);
        _remoteSeedReceived = true;
        if (session.role == RemoteRole.controller) {
          _startRemoteRuntimePublisher();
          await _sendRemoteState('state');
          await _sendRemoteRuntimeIfChanged(force: true);
        }
      case 'state':
        if (session.role == RemoteRole.display) {
          await _applyRemoteState(message.payload);
        }
'''
new_cases = '''      case 'seed':
        _captureRemoteDisplayMetrics(
          message.payload,
          senderRole: session.role.other,
        );
        await _applyRemoteState(message.payload, force: true);
        _remoteSeedReceived = true;
        if (session.role == RemoteRole.controller) {
          _startRemoteRuntimePublisher();
          await _sendRemoteState('state');
          await _sendRemoteRuntimeIfChanged(force: true);
        }
      case 'state':
        _captureRemoteDisplayMetrics(
          message.payload,
          senderRole: session.role.other,
        );
        if (session.role == RemoteRole.display) {
          await _applyRemoteState(message.payload);
        }
'''
if text.count(old_cases) != 1:
    raise SystemExit('unexpected seed/state cases')
text = text.replace(old_cases, new_cases)

old_state_payload = '''    await session.sendApp(kind, {
      'state': (state ?? _controller.state).toJson(),
      'selectedId': _selectedId,
      'widthMm': board.width,
      'heightMm': board.height,
    });
'''
new_state_payload = '''    await session.sendApp(kind, {
      'role': session.role.name,
      'state': (state ?? _controller.state).toJson(),
      'selectedId': _selectedId,
      'widthMm': board.width,
      'heightMm': board.height,
    });
'''
if text.count(old_state_payload) != 1:
    raise SystemExit('unexpected remote state payload')
text = text.replace(old_state_payload, new_state_payload)

old_stack = '''    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
'''
new_stack = '''    return Stack(
      fit: StackFit.expand,
      children: [
        if (_remoteControllerMode &&
            _remoteDisplayWidthMm != null &&
            _remoteDisplayHeightMm != null)
          Padding(
            padding: safePadding,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white38, width: 1),
                ),
              ),
            ),
          ),
        Padding(
'''
if text.count(old_stack) != 1:
    raise SystemExit('unexpected board stack header')
text = text.replace(old_stack, new_stack)

old_overlays = '''        if (_activeToys.contains(_ToyKind.wireDie))
          IgnorePointer(
            ignoring: _remoteDisplayMode,
            child: DiceBubble(
              snapshot: _diceSnapshot,
              onChanged: _remoteDisplayMode ? null : _handleDiceSnapshot,
            ),
          ),
        if (_activeToys.contains(_ToyKind.zendoStones))
          IgnorePointer(
            ignoring: _remoteDisplayMode,
            child: ZendoStonesWidget(
              snapshot: _zendoSnapshot,
              onChanged: _remoteDisplayMode ? null : _handleZendoSnapshot,
            ),
          ),
'''
new_overlays = '''        if (_activeToys.contains(_ToyKind.wireDie))
          Padding(
            padding: _remoteControllerMode ? safePadding : EdgeInsets.zero,
            child: IgnorePointer(
              ignoring: _remoteDisplayMode,
              child: DiceBubble(
                snapshot: _diceSnapshot,
                onChanged: _remoteDisplayMode ? null : _handleDiceSnapshot,
              ),
            ),
          ),
        if (_activeToys.contains(_ToyKind.zendoStones))
          Padding(
            padding: _remoteControllerMode ? safePadding : EdgeInsets.zero,
            child: IgnorePointer(
              ignoring: _remoteDisplayMode,
              child: ZendoStonesWidget(
                snapshot: _zendoSnapshot,
                onChanged: _remoteDisplayMode ? null : _handleZendoSnapshot,
              ),
            ),
          ),
'''
if text.count(old_overlays) != 1:
    raise SystemExit('unexpected remote overlay block')
text = text.replace(old_overlays, new_overlays)

board.write_text(text)

Path('lib/ui/remote_board_viewport.dart').write_text('''import 'dart:math' as math;

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
''')

Path('test/ui/remote_board_viewport_test.dart').write_text('''import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/remote_board_viewport.dart';

void main() {
  test('fits a landscape remote display inside a portrait controller', () {
    final rect = fitRemoteBoardRect(
      hostSize: const Size(390, 844),
      safePadding: const EdgeInsets.fromLTRB(0, 47, 0, 34),
      remoteSize: const Size(160, 100),
    );

    expect(rect.width / rect.height, closeTo(1.6, 0.0001));
    expect(rect.width, closeTo(390, 0.0001));
    expect(rect.height, closeTo(243.75, 0.0001));
    expect(rect.left, closeTo(0, 0.0001));
    expect(rect.center.dy, closeTo((47 + (844 - 34)) / 2, 0.0001));
  });

  test('preserves controller safe padding while centering the remote display', () {
    final rect = fitRemoteBoardRect(
      hostSize: const Size(1000, 700),
      safePadding: const EdgeInsets.fromLTRB(20, 10, 30, 40),
      remoteSize: const Size(4, 3),
    );

    expect(rect.top, closeTo(10, 0.0001));
    expect(rect.height, closeTo(650, 0.0001));
    expect(rect.width, closeTo(650 * 4 / 3, 0.0001));
    expect(rect.center.dx, closeTo((20 + (1000 - 30)) / 2, 0.0001));
  });
}
''')

changelog = Path('CHANGELOG.md')
changelog_text = changelog.read_text()
marker = '## Unreleased\n'
bullet = '- Fixed Remote controller geometry so display dimensions are recovered from hello/state traffic, the controlled screen appears as a visible letterboxed rectangle, and Dice Bubble/Zendo overlays stay inside that same remote frame.\n'
if bullet not in changelog_text:
    changelog_text = changelog_text.replace(marker, marker + bullet, 1)
changelog.write_text(changelog_text)

bootstrap = Path('web/flutter_bootstrap.js')
bootstrap_text = bootstrap.read_text()
if "const lighthouseBuildVersion = '4';" not in bootstrap_text:
    raise SystemExit('unexpected bootstrap cache version')
bootstrap.write_text(bootstrap_text.replace("const lighthouseBuildVersion = '4';", "const lighthouseBuildVersion = '5';"))

index = Path('web/index.html')
index_text = index.read_text()
if 'flutter_bootstrap.js?v=4' not in index_text:
    raise SystemExit('unexpected index cache version')
index.write_text(index_text.replace('flutter_bootstrap.js?v=4', 'flutter_bootstrap.js?v=5'))
