import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/application/app_language.dart';

void main() {
  tearDown(() {
    AppLanguageController.notifier.value = AppLanguage.english;
  });

  test('Chinese covers remote runtime status and gesture replay text', () {
    AppLanguageController.notifier.value = AppLanguage.chinese;
    expect(tr('Encrypted relay'), '加密中继');
    expect(tr('Controller'), '控制器');
    expect(tr('Remote device disconnected.'), '远程设备已断开连接。');
    expect(tr('Show gestures again'), '再次显示手势');
    expect(tr('Percentile D10'), '百分位 D10');
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
    expect(italianKeys, hasLength(193));
    expect(tokiPonaKeys, italianKeys);
  });
}
