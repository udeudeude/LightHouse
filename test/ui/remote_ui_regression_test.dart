import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/ripple_overlay.dart';

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
      final languageSource = File('lib/application/app_language.dart')
          .readAsStringSync();

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

  test('remote pairing UI is code-only', () {
    final source = File('lib/ui/board_screen.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(source, isNot(contains('QrImageView')));
    expect(source, isNot(contains('Icons.qr_code_2')));
    expect(source, isNot(contains('Pair with QR / Link')));
    expect(source, isNot(contains('Show Pairing QR')));
    expect(source, isNot(contains('Copy Link')));
    expect(source, isNot(contains('createShareable')));
    expect(pubspec, isNot(contains('qr_flutter')));
  });

  test('remote ripples travel farther, slower, and brighter', () {
    expect(remoteRipplePeriodSeconds, greaterThanOrEqualTo(2.0));
    expect(remoteRippleNormalTravelMm, greaterThanOrEqualTo(16.0));
    expect(remoteRippleDimTravelMm, greaterThanOrEqualTo(10.0));
    expect(remoteRippleNormalAlpha, greaterThanOrEqualTo(0.75));
    expect(remoteRippleDimAlpha, greaterThanOrEqualTo(0.4));
    expect(remoteRippleFadePower, lessThan(2.0));
  });
}
