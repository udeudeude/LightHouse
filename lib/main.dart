import 'package:flutter/material.dart';

import 'application/board_store.dart';
import 'application/display_calibration.dart';
import 'application/remote_session.dart';
import 'domain/board_state.dart';
import 'ui/board_screen.dart';
import 'ui/calibration_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LightHouseApp());
}

class LightHouseApp extends StatefulWidget {
  const LightHouseApp({super.key});

  @override
  State<LightHouseApp> createState() => _LightHouseAppState();
}

class _LightHouseAppState extends State<LightHouseApp> {
  final BoardStore _store = BoardStore();
  late final RemoteLaunch? _remoteLaunch = RemoteLaunch.fromUri(Uri.base);
  BoardState? _board;
  CalibrationResult? _calibration;
  bool _resolvingCalibration = false;
  bool _forceManualCalibration = false;
  CalibrationResult? _calibrationBeforeManual;

  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  Future<void> _loadBoard() async {
    final board = await _store.load();
    if (!mounted) return;
    setState(() => _board = board);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_calibration == null &&
        !_resolvingCalibration &&
        !_forceManualCalibration) {
      _resolveCalibration();
    }
  }

  Future<void> _resolveCalibration() async {
    _resolvingCalibration = true;
    var result = await DisplayCalibrationService.resolve(context);
    if (result == null && _remoteLaunch?.role == RemoteRole.controller) {
      result = const CalibrationResult(
        logicalPixelsPerMm: 4.8,
        source: 'Remote controller',
      );
    }
    if (!mounted) return;
    setState(() {
      _calibration = result;
      _resolvingCalibration = false;
      if (result == null) _forceManualCalibration = true;
    });
  }

  void _recalibrate(BoardState currentTable) {
    setState(() {
      _board = currentTable;
      _calibrationBeforeManual = _calibration;
      _forceManualCalibration = true;
      _calibration = null;
    });
  }

  void _cancelManualCalibration() {
    final previous = _calibrationBeforeManual;
    if (previous == null) return;
    setState(() {
      _calibration = previous;
      _calibrationBeforeManual = null;
      _forceManualCalibration = false;
    });
  }

  Future<void> _completeManualCalibration(double value) async {
    await DisplayCalibrationService.saveManual(value);
    if (!mounted) return;
    setState(() {
      _calibration = CalibrationResult(
        logicalPixelsPerMm: value,
        source: 'Manual calibration',
      );
      _forceManualCalibration = false;
      _calibrationBeforeManual = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LightHouse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_board == null || _resolvingCalibration) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_forceManualCalibration || _calibration == null) {
      final previous = _calibrationBeforeManual;
      return CalibrationScreen(
        onComplete: _completeManualCalibration,
        initialLogicalPixelsPerMm: previous?.logicalPixelsPerMm ?? 4.8,
        onCancel: previous == null ? null : _cancelManualCalibration,
      );
    }

    final calibration = _calibration!;
    return BoardScreen(
      logicalPixelsPerMm: calibration.logicalPixelsPerMm,
      initialState: _board!,
      calibrationLabel: calibration.source,
      onRecalibrate: _recalibrate,
      remoteLaunch: _remoteLaunch,
    );
  }
}
