from pathlib import Path

p = Path('lib/ui/board_screen_next.dart')
s = p.read_text()
s = s.replace("import 'dart:typed_data';\n", '')
s = s.replace('  int _redSweepDirection = 1;\n', '')
p.write_text(s)

print('interaction revision v3 analyzer cleanup applied')
