import 'reader_surface_position.dart';

enum ReaderLayoutEngineMode { experimental }

class ReaderLayoutDiagnostics {
  const ReaderLayoutDiagnostics({
    required this.requestedMode,
    required this.effectiveMode,
    required this.layoutPageCount,
    required this.elapsedMicros,
    this.surfaceKind,
    this.failureReason,
    this.errorMessage,
  });

  final ReaderLayoutEngineMode requestedMode;
  final ReaderLayoutEngineMode effectiveMode;
  final int layoutPageCount;
  final int elapsedMicros;
  final ReaderSurfaceKind? surfaceKind;
  final String? failureReason;
  final String? errorMessage;

  bool get hasFailure => failureReason != null;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'requestedMode': requestedMode.name,
      'effectiveMode': effectiveMode.name,
      'layoutPageCount': layoutPageCount,
      'elapsedMicros': elapsedMicros,
      if (surfaceKind != null) 'surfaceKind': surfaceKind!.name,
      if (failureReason != null) 'failureReason': failureReason,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}
