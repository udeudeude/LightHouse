import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isCompletePng(File file) {
  final bytes = file.readAsBytesSync();
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return false;
  }

  int readUint32(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  var offset = 8;
  while (offset + 12 <= bytes.length) {
    final length = readUint32(offset);
    final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
    offset += length + 12;
    if (offset > bytes.length) return false;
    if (type == 'IEND') return offset == bytes.length;
  }
  return false;
}

void main() {
  test('iOS Home Screen uses one valid dedicated icon', () {
    final manifestText = File('web/manifest.json').readAsStringSync();
    final manifest = jsonDecode(manifestText) as Map<String, dynamic>;

    expect(manifest['id'], './');
    expect(manifest['start_url'], './');
    expect(manifest['scope'], './');
    expect(manifest.containsKey('icons'), isFalse);

    final index = File('web/index.html').readAsStringSync();
    const manifestLink = 'rel="manifest" href="manifest.json?v=30"';
    const touchIcon =
        'rel="apple-touch-icon" sizes="180x180" '
        'href="icons/Icon-180.png"';
    expect(index, contains(manifestLink));
    expect(index, contains(touchIcon));

    final icon = File('web/icons/Icon-180.png');
    expect(_isCompletePng(icon), isTrue);

    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, contains("lighthouseBuildVersion = '30'"));
    expect(bootstrap, isNot(contains('lighthousePrepareFreshRuntime')));
  });
}
