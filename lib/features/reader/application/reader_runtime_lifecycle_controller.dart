import 'package:flutter/widgets.dart';

class ReaderRuntimeLifecycleDecision {
  const ReaderRuntimeLifecycleDecision({
    required this.pauseRuntime,
    required this.resumeRuntime,
  });

  final bool pauseRuntime;
  final bool resumeRuntime;
}

class ReaderRuntimeLifecycleController {
  const ReaderRuntimeLifecycleController();

  ReaderRuntimeLifecycleDecision resolve(AppLifecycleState state) {
    return ReaderRuntimeLifecycleDecision(
      pauseRuntime:
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.detached,
      resumeRuntime: state == AppLifecycleState.resumed,
    );
  }
}
