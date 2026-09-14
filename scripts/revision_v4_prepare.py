from pathlib import Path

main_path = Path('lib/main.dart')
text = main_path.read_text()
old = '''      _forceManualCalibration = false;
      _calibrationBeforeManual = null;
    });
  }

  @override
  Widget build'''
new = '''      _forceManualCalibration = false;
    });
  }

  @override
  Widget build'''
if old in text:
    text = text.replace(old, new, 1)
main_path.write_text(text)

ui_patch = Path('scripts/revision_v4_ui.py')
ui_text = ui_patch.read_text().replace('Icons.checkerboard', 'Icons.grid_on')
ui_patch.write_text(ui_text)

print('revision v4 source markers normalized')
