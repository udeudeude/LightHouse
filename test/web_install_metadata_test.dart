import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'web install metadata supports manifest installs and iOS Home Screen',
    () {
      final manifest = jsonDecode(
        File('web/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final icons = (manifest['icons'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      expect(manifest['id'], './');
      expect(manifest['start_url'], './');
      expect(manifest['scope'], './');
      expect(
        icons,
        contains(
          predicate<Map<String, dynamic>>(
            (icon) =>
                icon['src'] == 'icons/lighthouse-icon.svg' &&
                icon['sizes'] == 'any' &&
                icon['type'] == 'image/svg+xml' &&
                (icon['purpose'] as String).contains('maskable'),
          ),
        ),
      );

      final index = File('web/index.html').readAsStringSync();
      expect(index, contains('rel="manifest" href="manifest.json?v=27"'));
      expect(
        index,
        contains(
          'rel="apple-touch-icon" sizes="192x192" href="icons/Icon-192.png"',
        ),
      );

      final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
      expect(bootstrap, contains("lighthouseBuildVersion = '27'"));
      expect(bootstrap, isNot(contains('lighthousePrepareFreshRuntime')));
    },
  );
}
