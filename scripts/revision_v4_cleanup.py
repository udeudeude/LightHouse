from pathlib import Path
import re

path = Path('lib/ui/board_painter.dart')
text = path.read_text()
pattern = r'''\n  Path _roundedPolygon\(List<Offset> points, double radius\) \{.*?\n    return path;\n  \}\n'''
text, count = re.subn(pattern, '\n', text, count=1, flags=re.S)
if count != 1:
    raise SystemExit(f'missing obsolete rounded polygon helper: {count}')

old = '''    for (final edge in const [(1, 4), (3, 4), (5, 4), (7, 4)]) {
      final a = centers[edge.$1];
      final b = centers[edge.$2];
      canvas.drawLine(a, b, _linePaint(0.42));
      _paintArrowBetween(canvas, a, b, 0.58);
    }
'''
new = '''    for (final edge in const [(1, 4), (3, 4), (5, 4), (7, 4)]) {
      final a = centers[edge.$1];
      final b = centers[edge.$2];
      canvas.drawLine(a, b, _linePaint(0.42));
      _paintArrowBetween(canvas, a, b, 0.62);
      _paintArrowBetween(canvas, b, a, 0.62);
    }
'''
if old not in text:
    raise SystemExit('missing Twin Win center spoke marker')
text = text.replace(old, new, 1)

path.write_text(text)
print('revision v4 analyzer and Twin Win cleanup applied')
