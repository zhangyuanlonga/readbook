import 'package:flutter/material.dart';

class ReaderRootScaffoldModel {
  const ReaderRootScaffoldModel({
    required this.canPopRoute,
    required this.onFallbackPop,
    required this.focusNode,
    required this.onKeyEvent,
    required this.backgroundColor,
    required this.body,
  });

  final bool canPopRoute;
  final VoidCallback onFallbackPop;
  final FocusNode focusNode;
  final FocusOnKeyEventCallback onKeyEvent;
  final Color backgroundColor;
  final Widget body;
}

/// Reader route shell.
///
/// This boundary owns only route/back/focus/scaffold concerns. Chapter loading,
/// pagination, overlay state, and page-turn side effects must stay outside.
class ReaderRootScaffold extends StatelessWidget {
  const ReaderRootScaffold({super.key, required this.model});

  final ReaderRootScaffoldModel model;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: model.canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          model.onFallbackPop();
        }
      },
      child: Focus(
        focusNode: model.focusNode,
        autofocus: true,
        onKeyEvent: model.onKeyEvent,
        child: Scaffold(
          backgroundColor: model.backgroundColor,
          body: SafeArea(
            top: false,
            bottom: false,
            child: ClipRect(child: model.body),
          ),
        ),
      ),
    );
  }
}
