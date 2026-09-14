from pathlib import Path
import re

path = Path('lib/ui/board_painter.dart')
text = path.read_text()
pattern = r'''\n  Path _roundedPolygon\(List<Offset> points, double radius\) \{.*?\n    return path;\n  \}\n'''
text, count = re.subn(pattern, '\n', text, count=1, flags=re.S)
if count != 1:
    raise SystemExit(f'missing obsolete rounded polygon helper: {count}')
path.write_text(text)
print('revision v4 analyzer cleanup applied')
