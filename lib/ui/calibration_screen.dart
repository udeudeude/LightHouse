import 'package:flutter/material.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({
    super.key,
    required this.onComplete,
    this.initialLogicalPixelsPerMm = 4.8,
    this.onCancel,
  });

  final ValueChanged<double> onComplete;
  final double initialLogicalPixelsPerMm;
  final VoidCallback? onCancel;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const double _referenceMm = 50;
  static const double _largeBaseMm = 25.4;
  late double _logicalPixelsPerMm;
  bool _usePyramid = true;

  @override
  void initState() {
    super.initState();
    _logicalPixelsPerMm = widget.initialLogicalPixelsPerMm
        .clamp(2, 8)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final referenceWidth = _referenceMm * _logicalPixelsPerMm;
    final pyramidWidth = _largeBaseMm * _logicalPixelsPerMm;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Calibrate physical size',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Ruler')),
                      ButtonSegment(value: true, label: Text('Large pyramid')),
                    ],
                    selected: {_usePyramid},
                    onSelectionChanged: (selection) {
                      setState(() => _usePyramid = selection.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _usePyramid
                        ? 'Place a Large pyramid upright over the filled square. Adjust the slider until its base matches the square exactly.'
                        : 'Hold a ruler to the screen with 0 aligned to the fixed left end. Adjust the slider until the right end reaches exactly 50 mm.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    height: _largeBaseMm * 8 + 32,
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: false,
                      child: SizedBox(
                        height: _largeBaseMm * 8,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: _usePyramid
                              ? SizedBox.square(
                                  dimension: pyramidWidth,
                                  child: const ColoredBox(color: Colors.white),
                                )
                              : SizedBox(
                                  width: referenceWidth,
                                  height: 8,
                                  child: const ColoredBox(color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Slider(
                    min: 2.0,
                    max: 8.0,
                    divisions: 600,
                    value: _logicalPixelsPerMm,
                    onChanged: (value) {
                      setState(() => _logicalPixelsPerMm = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.onCancel != null) ...[
                        OutlinedButton(
                          onPressed: widget.onCancel,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      FilledButton(
                        onPressed: () => widget.onComplete(_logicalPixelsPerMm),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Text('Use calibration'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
