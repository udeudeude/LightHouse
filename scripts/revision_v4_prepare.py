from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text()
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
path.write_text(text)
print('revision v4 source markers normalized')
