import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/app_language.dart';

class CreditsOverlay extends StatelessWidget {
  const CreditsOverlay({
    super.key,
    required this.onCloseAndRecalibrate,
    required this.onOpenGithub,
  });

  final VoidCallback onCloseAndRecalibrate;
  final VoidCallback onOpenGithub;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: null,
    child: ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 58, 32, 104),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 150,
                      height: 128,
                      child: CustomPaint(painter: ArtDecoCreditsMarkPainter()),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'LightHouse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 3.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'An illuminated physical play surface\nfor Looney Pyramids',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://udeudeude.github.io/'),
                        mode: LaunchMode.externalApplication,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(height: 1.55),
                      ),
                      child: const Text('Project: udeudeude'),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://www.looneylabs.com/pyramids-home'),
                        mode: LaunchMode.externalApplication,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(height: 1.55),
                      ),
                      child: const Text('Looney Pyramids: Looney Labs'),
                    ),
                    const Text(
                      'Open source under the MIT License',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, height: 1.55),
                    ),
                    const SizedBox(height: 7),
                    TextButton.icon(
                      onPressed: onOpenGithub,
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('github.com/udeudeude/LightHouse'),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: IconButton(
                tooltip: tr('Close and set this side as up'),
                onPressed: onCloseAndRecalibrate,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Text(
                  'No video game\nJust bespoke lamps trapped in glass\nGlowing pyramids',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    height: 1.45,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Faithful vector translation of 01 Stepped Plinth (300 x 256 SVG).
class ArtDecoCreditsMarkPainter extends CustomPainter {
  const ArtDecoCreditsMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 256);
    final footprint = Paint()
      ..color = const Color(0xFFF8F8F8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeJoin = StrokeJoin.miter;
    final triangle = Path()
      ..moveTo(150, 55.5)
      ..lineTo(191.428, 200.5)
      ..lineTo(108.572, 200.5)
      ..close();
    for (final angle in <double>[0, 120, 240]) {
      canvas.save();
      canvas.translate(150, 128);
      canvas.rotate(angle * 3.141592653589793 / 180);
      canvas.translate(-150, -128);
      canvas.drawPath(triangle, footprint);
      canvas.restore();
    }
    for (var i = 0; i < 4; i++) {
      final inset = 70.0 + i * 10;
      final step = Path()
        ..moveTo(inset, 220)
        ..lineTo(inset, 224)
        ..lineTo(300 - inset, 224)
        ..lineTo(300 - inset, 220);
      canvas.drawPath(
        step,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22 + i * 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArtDecoCreditsMarkPainter oldDelegate) => false;
}
