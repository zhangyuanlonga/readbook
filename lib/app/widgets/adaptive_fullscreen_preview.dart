import 'package:flutter/material.dart';

Future<T?> showAdaptiveFullscreenPreview<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? helperText,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title ?? 'preview',
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, __) {
      return _AdaptiveFullscreenPreviewSurface(
        title: title,
        helperText: helperText,
        onClose: () => Navigator.of(dialogContext).pop(),
        child: builder(dialogContext),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class _AdaptiveFullscreenPreviewSurface extends StatelessWidget {
  const _AdaptiveFullscreenPreviewSurface({
    required this.child,
    required this.onClose,
    this.title,
    this.helperText,
  });

  final Widget child;
  final VoidCallback onClose;
  final String? title;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title!.trim().isNotEmpty;
    final hasHelper = helperText != null && helperText!.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    hasTitle ? 56 : 16,
                    16,
                    hasHelper ? 44 : 16,
                  ),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onClose,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
              if (hasTitle)
                Positioned(
                  left: 16,
                  top: 10,
                  right: 58,
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: '关闭',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
              if (hasHelper)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Text(
                    helperText!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
