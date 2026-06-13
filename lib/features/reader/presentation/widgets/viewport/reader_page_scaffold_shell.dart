import 'package:flutter/material.dart';

import '../../reader_page_support_models.dart';
import '../../reader_shell.dart';
import '../root/reader_root_scaffold.dart';

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
    return ReaderRootScaffold(
      model: ReaderRootScaffoldModel(
        canPopRoute: canPopRoute,
        onFallbackPop: onFallbackPop,
        focusNode: focusNode,
        onKeyEvent: onKeyEvent,
        backgroundColor: colors.background,
        body: ReaderShell(model: shellModel, child: child),
      ),
    );
  }
}
