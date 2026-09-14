from pathlib import Path

p = Path('lib/ui/board_screen_next.dart')
s = p.read_text()
s = s.replace("String get preferenceKey => 'lighthouse.toy.$name.visible.v3';", "String get preferenceKey => 'lighthouse.toy.$name.visible.v2';")
s = s.replace('  double _redSweepDirection = 1;\n', '')
s = s.replace('      _redSweepDirection = phase <= 1 ? 1 : -1;\n', '')
s = s.replace('    _stopContinuousLightToys();\n', '')
s = s.replace('base + offset.clamp(-72, 72),', 'base + offset.clamp(-72, 72).toDouble(),')
s = s.replace('math.max(0, size.width - left - 1),', 'math.max(0.0, size.width - left - 1),')
s = s.replace('_ToyKind.wireDie => _dieRollEndsAt != null || _dieRollProgress >= 1,', '_ToyKind.wireDie => _activeToys.contains(_ToyKind.wireDie),')
s = s.replace('position: const PhysicalPoint(1, 1),', 'position: const PhysicalPoint(2.25, 2.25),')
s = s.replace('position: PhysicalPoint(board.width - 1, 1),', 'position: PhysicalPoint(board.width - 2.25, 2.25),')
s = s.replace('position: PhysicalPoint(1, board.height - 1),', 'position: PhysicalPoint(2.25, board.height - 2.25),')
s = s.replace('position: PhysicalPoint(board.width - 1, board.height - 1),', 'position: PhysicalPoint(board.width - 2.25, board.height - 2.25),')
p.write_text(s)

p = Path('lib/ui/board_painter.dart')
s = p.read_text().replace('math.max(1, band)', 'math.max(1.0, band)')
p.write_text(s)

p = Path('lib/ui/toy_overlay.dart')
s = p.read_text()
s = s.replace('math.max(1, size.width - inset * 2)', 'math.max(1.0, size.width - inset * 2)')
s = s.replace('math.max(1, size.height - inset * 2)', 'math.max(1.0, size.height - inset * 2)')
p.write_text(s)

p = Path('lib/ui/calibration_screen.dart')
s = p.read_text().replace(
    '_logicalPixelsPerMm = widget.initialLogicalPixelsPerMm.clamp(2, 8);',
    '_logicalPixelsPerMm = widget.initialLogicalPixelsPerMm.clamp(2, 8).toDouble();',
)
p.write_text(s)

print('interaction revision v3 hardened')
