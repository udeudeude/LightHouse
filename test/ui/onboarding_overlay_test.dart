import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/domain/light_element.dart';
import 'package:lighthouse/domain/physical_point.dart';
import 'package:lighthouse/domain/pyramid_geometry.dart';
import 'package:lighthouse/ui/onboarding_overlay.dart';

void main() {
  testWidgets('onboarding overlay exposes the quiet first-use prompts', (
    tester,
  ) async {
    const square = LightElement(
      id: 'square',
      size: PyramidSize.medium,
      pose: PyramidPose.upright,
      position: PhysicalPoint(60, 80),
      headingDegrees: 0,
      illumination: IlluminationPattern.full,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 500,
            child: OnboardingOverlay(
              animation: AlwaysStoppedAnimation<double>(0.5),
              logicalPixelsPerMm: 2,
              geometry: PyramidGeometryProfile.prototype2025,
              showHaiku: true,
              showTapTap: true,
              tipTarget: square,
              hollowTarget: square,
              transformTarget: square,
            ),
          ),
        ),
      ),
    );

    expect(find.text(onboardingHaiku), findsOneWidget);
    expect(find.text('Tap. Tap.'), findsOneWidget);
    expect(onboardingHaikuFadeDuration, const Duration(milliseconds: 1500));
  });

  test('first-use defaults and timing remain deliberately sparse', () {
    final source = File('lib/ui/board_screen.dart').readAsStringSync();

    expect(
      source,
      contains("lightLottery('Light Lottery', Icons.auto_awesome, false)"),
    );
    expect(
      source,
      contains("entropy('Entropy Delete', Icons.hourglass_bottom, false)"),
    );
    expect(
      source,
      contains(
        'static const Duration _onboardingWait = Duration(seconds: 35);',
      ),
    );
    expect(
      source,
      contains(
        'static const Duration _onboardingHaikuHold = Duration(seconds: 7);',
      ),
    );
    expect(
      source,
      contains(
        'static const Duration _onboardingTransformWait = '
        'Duration(seconds: 60);',
      ),
    );
    expect(
      source,
      contains(
        'static const Duration _onboardingMenuWait = Duration(seconds: 90);',
      ),
    );
    expect(source, contains("tr('Show gestures again')"));
    expect(source, contains('_recordOnboardingMenuOpened();'));
  });

  test('hollow gesture is a faster diagonal ellipse with a leading arrow', () {
    final source = File('lib/ui/onboarding_overlay.dart').readAsStringSync();

    expect(source, contains('(phase / 0.42)'));
    expect(source, contains('final radiusX = base * 0.92;'));
    expect(source, contains('final radiusY = base * 0.70;'));
    expect(source, contains('const rotation = -math.pi / 9;'));
    expect(source, contains('_paintArrowHead(canvas, end, tangent'));
  });

  test('opening haiku text is exact', () {
    expect(
      onboardingHaiku,
      'No video game.\n'
      'Just bespoke lamps trapped in glass.\n'
      'Glowing pyramids.',
    );
  });
}
