from pathlib import Path


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


path = Path('lib/ui/board_screen_next.dart')
text = path.read_text()

text = replace_once(
    text,
    '  Timer? _toyTicker;\n',
    '  Timer? _toyTicker;\n  final ValueNotifier<int> _toyRevision = ValueNotifier<int>(0);\n',
    'toy repaint notifier field',
)

text = replace_once(
    text,
    '    _toyTicker?.cancel();\n    _effectGeneration += 1;\n',
    '    _toyTicker?.cancel();\n    _toyRevision.dispose();\n    _effectGeneration += 1;\n',
    'dispose toy repaint notifier',
)

old_tick = '''  void _tickToys(double dt) {
    if (!mounted) return;
    _toyClock += dt;
    final now = DateTime.now();

    final eventEnds = _eventZoneEndsAt;
'''
new_tick = '''  void _tickToys(double dt) {
    if (!mounted) return;
    final eventWasActive = _eventZoneCenter != null;
    final timerWasActive = _turnTimerProgress != null;
    final ricochetWasActive = _projectiles.any((p) => p.ricochet);
    _toyClock += dt;
    final now = DateTime.now();

    final eventEnds = _eventZoneEndsAt;
'''
text = replace_once(text, old_tick, new_tick, 'capture toy control transitions')

text = replace_once(
    text,
    '''    _tickProjectiles(dt);
    _updateContinuousLighting();
    setState(() {});
    _maybeStopToyTicker();
  }
''',
    '''    _tickProjectiles(dt);
    _updateContinuousLighting();
    _toyRevision.value += 1;
    _maybeStopToyTicker();

    final controlStateChanged =
        eventWasActive != (_eventZoneCenter != null) ||
        timerWasActive != (_turnTimerProgress != null) ||
        ricochetWasActive != _projectiles.any((p) => p.ricochet);
    if (controlStateChanged && mounted) setState(() {});
  }
''',
    'isolate animation tick from whole screen',
)

old_board = '''              child: CustomPaint(
                painter: BoardPainter(
                  state: _controller.state,
                  logicalPixelsPerMm: widget.logicalPixelsPerMm,
                  geometry: _controller.geometry,
                  selectedId: _selectedId,
                  elementOpacities: _paintElementOpacities,
                  burstCenter: _burstCenter,
                  triangleBouncePhase:
                      _activeToys.contains(_ToyKind.triangleBounce)
                      ? 0.5 - 0.5 * math.cos(_toyClock * math.pi * 0.9)
                      : null,
                  squareChasePhase: _activeToys.contains(_ToyKind.squareChase)
                      ? (_toyClock * 0.24) % 1
                      : null,
                  roundTriangleTips: _roundedTriangleTips,
                  checkerUnderlays: _checkerUnderlays,
                  burstProgress: _burstProgress,
                ),
                child: const SizedBox.expand(),
              ),
'''
new_board = '''              child: ValueListenableBuilder<int>(
                valueListenable: _toyRevision,
                builder: (context, revision, child) => RepaintBoundary(
                  child: CustomPaint(
                    painter: BoardPainter(
                      state: _controller.state,
                      logicalPixelsPerMm: widget.logicalPixelsPerMm,
                      geometry: _controller.geometry,
                      selectedId: _selectedId,
                      elementOpacities: _paintElementOpacities,
                      burstCenter: _burstCenter,
                      triangleBouncePhase:
                          _activeToys.contains(_ToyKind.triangleBounce)
                          ? 0.5 - 0.5 * math.cos(_toyClock * math.pi * 0.9)
                          : null,
                      squareChasePhase:
                          _activeToys.contains(_ToyKind.squareChase)
                          ? (_toyClock * 0.24) % 1
                          : null,
                      roundTriangleTips: _roundedTriangleTips,
                      checkerUnderlays: _checkerUnderlays,
                      burstProgress: _burstProgress,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
'''
text = replace_once(text, old_board, new_board, 'board painting isolation')

old_overlay = '''          child: IgnorePointer(
            child: CustomPaint(
              painter: ToyOverlayPainter(
                logicalPixelsPerMm: widget.logicalPixelsPerMm,
                geometry: _controller.geometry,
                elements: _controller.state.elements,
                ghostTrails: _ghostTrails,
                ghostTrailsVisible: _ghostTrailActive,
                eventZoneCenter: _eventZoneCenter,
                eventZoneRadiusMm: _eventZoneRadiusMm,
                eventZoneProgress: _eventZoneProgress,
                eventZoneDismiss: _eventZoneDismiss,
                turnTimerProgress: _turnTimerProgress,
                radarAngleDegrees: _activeToys.contains(_ToyKind.radar)
                    ? _radarAngleDegrees
                    : null,
                redSweepY: _activeToys.contains(_ToyKind.redSweep)
                    ? _redSweepY
                    : null,
                dieValue: null,
                dieRollPhase: 0,
                dieRollProgress: 1,
                diePressed: false,
                projectiles: _projectiles,
                impacts: _impacts,
                sideGunsVisible: _activeToys.contains(_ToyKind.sideGuns),
                sideGunAnglesDegrees: List<double>.unmodifiable(
                  _sideGunAnglesDegrees,
                ),
                sideGunAmmo: List<int>.unmodifiable(_sideGunAmmo),
                cornerGunsVisible:
                    _activeToys.contains(_ToyKind.cornerRicochet) ||
                    _projectiles.any((p) => p.ricochet),
                constellation: _constellationPoints,
              ),
              child: const SizedBox.expand(),
            ),
          ),
'''
new_overlay = '''          child: IgnorePointer(
            child: ValueListenableBuilder<int>(
              valueListenable: _toyRevision,
              builder: (context, revision, child) => RepaintBoundary(
                child: CustomPaint(
                  painter: ToyOverlayPainter(
                    logicalPixelsPerMm: widget.logicalPixelsPerMm,
                    geometry: _controller.geometry,
                    elements: _controller.state.elements,
                    ghostTrails: _ghostTrails,
                    ghostTrailsVisible: _ghostTrailActive,
                    eventZoneCenter: _eventZoneCenter,
                    eventZoneRadiusMm: _eventZoneRadiusMm,
                    eventZoneProgress: _eventZoneProgress,
                    eventZoneDismiss: _eventZoneDismiss,
                    turnTimerProgress: _turnTimerProgress,
                    radarAngleDegrees: _activeToys.contains(_ToyKind.radar)
                        ? _radarAngleDegrees
                        : null,
                    redSweepY: _activeToys.contains(_ToyKind.redSweep)
                        ? _redSweepY
                        : null,
                    dieValue: null,
                    dieRollPhase: 0,
                    dieRollProgress: 1,
                    diePressed: false,
                    projectiles: _projectiles,
                    impacts: _impacts,
                    sideGunsVisible: _activeToys.contains(_ToyKind.sideGuns),
                    sideGunAnglesDegrees: List<double>.unmodifiable(
                      _sideGunAnglesDegrees,
                    ),
                    sideGunAmmo: List<int>.unmodifiable(_sideGunAmmo),
                    cornerGunsVisible:
                        _activeToys.contains(_ToyKind.cornerRicochet) ||
                        _projectiles.any((p) => p.ricochet),
                    constellation: _constellationPoints,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
'''
text = replace_once(text, old_overlay, new_overlay, 'toy overlay painting isolation')

path.write_text(text)
print('Animation repaint isolation applied.')
