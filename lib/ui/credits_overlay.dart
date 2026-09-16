import 'package:flutter/material.dart';

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
                    const Text(
                      'Project: udeudeude\nSoftware: Flutter + ChatGPT\nLooney Pyramids: Looney Labs\nOpen source under the MIT License',
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
                tooltip: 'Close and set this side as up',
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

class ArtDecoCreditsMarkPainter extends CustomPainter {
  const ArtDecoCreditsMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strong = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.miter;
    final fine = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.78);
    final centerX = size.width / 2;

    final frame = Path()
      ..moveTo(size.width * 0.12, size.height * 0.88)
      ..lineTo(size.width * 0.12, size.height * 0.66)
      ..lineTo(size.width * 0.19, size.height * 0.66)
      ..lineTo(size.width * 0.19, size.height * 0.38)
      ..lineTo(size.width * 0.29, size.height * 0.38)
      ..lineTo(size.width * 0.37, size.height * 0.12)
      ..lineTo(size.width * 0.63, size.height * 0.12)
      ..lineTo(size.width * 0.71, size.height * 0.38)
      ..lineTo(size.width * 0.81, size.height * 0.38)
      ..lineTo(size.width * 0.81, size.height * 0.66)
      ..lineTo(size.width * 0.88, size.height * 0.66)
      ..lineTo(size.width * 0.88, size.height * 0.88);
    canvas.drawPath(frame, fine);

    final lanternY = size.height * 0.31;
    final tower = Path()
      ..moveTo(centerX - 16, size.height * 0.82)
      ..lineTo(centerX - 8, size.height * 0.43)
      ..lineTo(centerX + 8, size.height * 0.43)
      ..lineTo(centerX + 16, size.height * 0.82)
      ..close();
    canvas.drawPath(tower, strong);
    canvas.drawLine(
      Offset(centerX - 8, size.height * 0.53),
      Offset(centerX + 8, size.height * 0.53),
      fine,
    );
    canvas.drawLine(
      Offset(centerX - 10, size.height * 0.64),
      Offset(centerX + 10, size.height * 0.64),
      fine,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(centerX, lanternY), width: 31, height: 14),
      strong,
    );
    final roof = Path()
      ..moveTo(centerX - 20, lanternY - 8)
      ..lineTo(centerX, lanternY - 19)
      ..lineTo(centerX + 20, lanternY - 8);
    canvas.drawPath(roof, strong);
    canvas.drawLine(
      Offset(centerX, lanternY - 19),
      Offset(centerX, size.height * 0.12),
      strong,
    );

    for (var i = -3; i <= 3; i += 1) {
      if (i == 0) continue;
      final start = Offset(centerX + i.sign * 17, lanternY);
      final end = Offset(
        centerX + i * size.width * 0.12,
        size.height * (0.22 + i.abs() * 0.055),
      );
      canvas.drawLine(start, end, fine);
    }

    void pyramid(double x, double y, double scale) {
      final path = Path()
        ..moveTo(x, y - 11 * scale)
        ..lineTo(x + 9 * scale, y + 8 * scale)
        ..lineTo(x - 9 * scale, y + 8 * scale)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, strong);
    }

    pyramid(centerX - 28, size.height * 0.87, 0.72);
    pyramid(centerX, size.height * 0.87, 1.0);
    pyramid(centerX + 28, size.height * 0.87, 0.84);
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.96),
      Offset(size.width * 0.84, size.height * 0.96),
      strong,
    );
    canvas.drawLine(
      Offset(size.width * 0.24, size.height * 0.92),
      Offset(size.width * 0.76, size.height * 0.92),
      fine,
    );
  }

  @override
  bool shouldRepaint(covariant ArtDecoCreditsMarkPainter oldDelegate) => false;
}
