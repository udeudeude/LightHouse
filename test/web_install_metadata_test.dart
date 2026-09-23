import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'web install diagnostic deliberately exposes no custom install icons',
    () {
      final manifest = jsonDecode(
        File('web/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      expect(manifest['id'], './');
      expect(manifest['start_url'], './');
      expect(manifest['scope'], './');
      expect(manifest.containsKey('icons'), isFalse);

      final index = File('web/index.html').readAsStringSync();
      expect(index, contains('rel="manifest" href="manifest.json?v=28"'));
      expect(index, isNot(contains('apple-touch-icon')));

      final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
      expect(bootstrap, contains("lighthouseBuildVersion = '28'"));
      expect(bootstrap, isNot(contains('lighthousePrepareFreshRuntime')));
    },
  );
}
