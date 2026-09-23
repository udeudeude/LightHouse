import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/application/app_language.dart';

void main() {
  tearDown(() {
    AppLanguageController.notifier.value = AppLanguage.english;
  });

  test('toki pona has the standard language code and interface name', () {
    expect(AppLanguage.tokiPona.code, 'tok');
    expect(AppLanguage.tokiPona.selfName, 'toki pona');

    AppLanguageController.notifier.value = AppLanguage.tokiPona;
    expect(tr('Menu'), 'lipu nasin');
    expect(tr('Dice Bubble'), 'sike ilo nanpa');
    expect(
      tr('Thanks for playing with LightHouse!'),
      'pona tawa sina tan musi lon LightHouse!',
    );
  });

  test('toki pona translation coverage matches Italian coverage', () {
    final source = File('lib/application/app_language.dart').readAsStringSync();

    Set<String> keysFor(String mapName) {
      final start = source.indexOf('const ${mapName} = <String, String>{');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('\n};', start);
      expect(end, greaterThan(start));
      final block = source.substring(start, end);
      return RegExp(r"^\s*'((?:\\'|[^'])*)'\s*:", multiLine: true)
          .allMatches(block)
          .map((match) => match.group(1)!.replaceAll(r"\'", "'"))
          .toSet();
    }

    final italianKeys = keysFor('_it');
    final tokiPonaKeys = keysFor('_tok');
    expect(italianKeys, hasLength(182));
    expect(tokiPonaKeys, italianKeys);
  });
}
