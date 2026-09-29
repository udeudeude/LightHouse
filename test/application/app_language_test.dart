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

  test('every supported language covers the same active interface keys', () {
    final source = File('lib/application/app_language.dart').readAsStringSync();

    Set<String> keysFor(String mapName) {
      final start = source.indexOf('const ${mapName} = <String, String>{');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('\n};', start);
      expect(end, greaterThan(start));
      final block = source.substring(start, end);
      return RegExp(r"'((?:\\'|[^'])*)'\s*:")
          .allMatches(block)
          .map((match) => match.group(1)!.replaceAll(r"\'", "'"))
          .toSet();
    }

    final italianKeys = keysFor('_it');
    expect(italianKeys, hasLength(201));
    for (final language in const [
      '_es',
      '_ja',
      '_de',
      '_fr',
      '_nl',
      '_pt',
      '_zh',
      '_tok',
    ]) {
      final keys = keysFor(language);
      if (language == '_es' || language == '_ja') {
        keys.addAll(keysFor('${language}Extra'));
      }
      expect(keys, italianKeys, reason: 'Missing interface keys in $language');
    }

    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              !file.path.endsWith('app_language.dart'),
        );
    final literalCalls = RegExp(r"\btr\(\s*'((?:\\'|[^'])*)'\s*\)");
    for (final file in sourceFiles) {
      final usedKeys = literalCalls
          .allMatches(file.readAsStringSync())
          .map((match) => match.group(1)!.replaceAll(r"\'", "'"))
          .toSet();
      expect(
        usedKeys.difference(italianKeys),
        isEmpty,
        reason: 'Untranslated literal in ${file.path}',
      );
    }

    for (final removed in const [
      '6-Character Code',
      'Pair with QR / Link',
      'Show Pairing QR',
      'Pairing link copied.',
      'Copy Link',
      'QR / Link',
    ]) {
      expect(italianKeys, isNot(contains(removed)));
    }
  });

  test('Remote failures use stable localized messages', () {
    for (final language in AppLanguage.values.where(
      (value) => value != AppLanguage.english,
    )) {
      AppLanguageController.notifier.value = language;
      expect(
        tr('Could not reach the pairing service.'),
        isNot('Could not reach the pairing service.'),
      );
      expect(
        tr('Both devices chose the same role. Choose opposite roles.'),
        isNot('Both devices chose the same role. Choose opposite roles.'),
      );
    }
  });

  test('Zendo stone labels and interaction hint are localized', () {
    const keys = [
      'White marking stone',
      'Black marking stone',
      'Green guessing stone',
      'Add',
      'Drag · double-tap to remove',
    ];
    for (final language in AppLanguage.values.where(
      (value) => value != AppLanguage.english,
    )) {
      AppLanguageController.notifier.value = language;
      for (final key in keys) {
        expect(tr(key), isNot(key), reason: '${language.name}: $key');
      }
    }
  });
}
