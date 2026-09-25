import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remote quick controls occupy their own row above primary controls', () {
    final source = File('lib/ui/board_screen.dart').readAsStringSync();

    expect(
      source,
      contains(
        '_remoteControllerQuickControls(),\n'
        '                    const SizedBox(height: 6),\n'
        '                  ],\n'
        '                  Row(',
      ),
    );
  });

  test(
    'language picker uses a drawn arrow rather than an emoji-capable glyph',
    () {
      final source = File('lib/ui/board_screen.dart').readAsStringSync();
      final languageSource =
          File('lib/application/app_language.dart').readAsStringSync();

      expect(source, contains('painter: _LanguageArrowPainter()'));
      expect(source, isNot(contains('languagePickerGlyph')));
      expect(languageSource, isNot(contains('languagePickerGlyph')));
      expect(languageSource, isNot(contains(r'\uFE0F')));
    },
  );

  test('remote status composition is translated before display', () {
    final source = File('lib/ui/board_screen.dart').readAsStringSync();

    expect(source, contains('_translatedRemoteStatus(session)'));
    expect(source, contains('_translatedRemoteTransportLabel(session)'));
    expect(source, contains("tr('Encrypted relay')"));
    expect(source, contains("tr('multiple controllers')"));
    expect(source, contains("tr(error)"));
  });
}
