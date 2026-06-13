import 'package:flutter/material.dart';

import '../../reader_page_support_models.dart';
import '../../reader_shell.dart';

class ReaderPageScaffoldShell extends StatelessWidget {
  const ReaderPageScaffoldShell({
    super.key,
    required this.colors,
    required this.canPopRoute,
    required this.onFallbackPop,
    required this.focusNode,
    required this.onKeyEvent,
    required this.shellModel,
    required this.child,
  });

  final ReaderThemeColors colors;
  final bool canPopRoute;
  final VoidCallback onFallbackPop;
  final FocusNode focusNode;
  final FocusOnKeyEventCallback onKeyEvent;
  final ReaderShellModel shellModel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          onFallbackPop();
        }
      },
      child: Focus(
        focusNode: focusNode,
        autofocus: true,
        onKeyEvent: onKeyEvent,
        child: Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            top: false,
            bottom: false,
            child: ClipRect(
              child: ReaderShell(model: shellModel, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
