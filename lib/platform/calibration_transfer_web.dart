import 'dart:js_interop';

@JS('lighthouseReadCalibrationCookie')
external JSNumber _readCalibrationCookie();

@JS('lighthouseWriteCalibrationCookie')
external void _writeCalibrationCookie(JSNumber value);

@JS('lighthouseClearCalibrationCookie')
external void _clearCalibrationCookie();

double? readTransferredCalibration() {
  try {
    final value = _readCalibrationCookie().toDartDouble;
    if (!value.isFinite || value <= 0) return null;
    return value;
  } on Object {
    return null;
  }
}

void writeTransferredCalibration(double value) {
  if (!value.isFinite || value <= 0) return;
  try {
    _writeCalibrationCookie(value.toJS);
  } on Object {
    // Cookie transfer is best-effort only.
  }
}

void clearTransferredCalibration() {
  try {
    _clearCalibrationCookie();
  } on Object {
    // Cookie transfer is best-effort only.
  }
}
