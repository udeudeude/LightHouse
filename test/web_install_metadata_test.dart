import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

bool _isCompletePng(File file) {
  final bytes = file.readAsBytesSync();
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return false;
  }

  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  var offset = 8;
  var sawEnd = false;
  while (offset + 12 <= bytes.length) {
    final length = data.getUint32(offset, Endian.big);
    final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
    final next = offset + 12 + length;
    if (next > bytes.length) return false;
    offset = next;
    if (type == 'IEND') {
      sawEnd = true;
      break;
    }
  }
  return sawEnd && offset == bytes.length;
}

void main() {
  test(
    'iOS Home Screen uses one valid dedicated icon while manifest icons stay isolated',
    () {
      final manifest = jsonDecode(
        File('web/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      expect(manifest['id'], './');
      expect(manifest['start_url'], './');
      expect(manifest['scope'], './');
      expect(manifest.containsKey('icons'), isFalse);

      final index = File('web/index.html').readAsStringSync();
      expect(index, contains('rel="manifest" href="manifest.json?v=29"'));
      expect(
        index,
        contains(
          'rel="apple-touch-icon" sizes="180x180" href="icons/Icon-180.png"',
        ),
      );
      expect(_isCompletePng(File('web/icons/Icon-180.png')), isTrue);

      final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
      expect(bootstrap, contains("lighthouseBuildVersion = '29'"));
      expect(bootstrap, isNot(contains('lighthousePrepareFreshRuntime')));
    },
  );
}
