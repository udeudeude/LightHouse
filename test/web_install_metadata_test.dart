import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web install metadata uses the manifest as the icon source of truth', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
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
    expect(index, contains('rel="manifest" href="manifest.json?v=26"'));
    expect(index, isNot(contains('apple-touch-icon')));

    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, contains("lighthouseBuildVersion = '26'"));
    expect(bootstrap, isNot(contains('lighthousePrepareFreshRuntime')));
  });
}
