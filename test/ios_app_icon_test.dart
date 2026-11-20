import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

int _pngDimension(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);

void main() {
  test('native iOS Lighthouse app icon includes every declared size', () {
    const iconSizes = <String, int>{
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };
    const directory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

    for (final entry in iconSizes.entries) {
      final file = File('$directory/${entry.key}');
      expect(file.existsSync(), isTrue, reason: entry.key);
      final bytes = file.readAsBytesSync();
      expect(
        bytes.sublist(0, 8),
        <int>[137, 80, 78, 71, 13, 10, 26, 10],
        reason: entry.key,
      );
      expect(_pngDimension(bytes, 16), entry.value, reason: entry.key);
      expect(_pngDimension(bytes, 20), entry.value, reason: entry.key);
    }
  });
}
