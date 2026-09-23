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
            ),
          ),
        ),
      ),
    );

    expect(find.text(onboardingHaiku), findsOneWidget);
    expect(find.text('Tap. Tap.'), findsOneWidget);
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
        'static const Duration _onboardingWait = Duration(seconds: 50);',
      ),
    );
    expect(
      source,
      contains(
        'static const Duration _onboardingHaikuHold = Duration(seconds: 14);',
      ),
    );
    expect(
      source,
      contains(
        'static const Duration _onboardingHintDuration = Duration(seconds: 8);',
      ),
    );
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
