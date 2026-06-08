import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowFrame extends StatelessWidget {
  const DesktopWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (kIsWeb ||
        (platform != TargetPlatform.windows &&
            platform != TargetPlatform.linux)) {
      return child;
    }
    return VirtualWindowFrame(child: child);
  }
}

class DesktopWindowDragArea extends StatelessWidget {
  const DesktopWindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_isNativeDesktopPlatform(Theme.of(context).platform)) {
      return child;
    }
    return DragToMoveArea(child: child);
  }
}

class DesktopWindowCaptionControls extends StatefulWidget {
  const DesktopWindowCaptionControls({super.key});

  static bool isVisible(BuildContext context) {
    final platform = Theme.of(context).platform;
    return !kIsWeb &&
        (platform == TargetPlatform.windows ||
            platform == TargetPlatform.linux);
  }

  @override
  State<DesktopWindowCaptionControls> createState() =>
      _DesktopWindowCaptionControlsState();
}

class _DesktopWindowCaptionControlsState
    extends State<DesktopWindowCaptionControls>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopWindowCaptionControls.isVisible(context)) {
      return const SizedBox.shrink();
    }

    final brightness = Theme.of(context).brightness;
    return SizedBox(
      key: const ValueKey<String>('desktop_window_caption_controls'),
      height: kWindowCaptionHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WindowCaptionButton.minimize(
            brightness: brightness,
            onPressed: () async {
              final minimized = await windowManager.isMinimized();
              if (minimized) {
                await windowManager.restore();
              } else {
                await windowManager.minimize();
              }
            },
          ),
          FutureBuilder<bool>(
            future: windowManager.isMaximized(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return WindowCaptionButton.unmaximize(
                  brightness: brightness,
                  onPressed: () async {
                    await windowManager.unmaximize();
                  },
                );
              }
              return WindowCaptionButton.maximize(
                brightness: brightness,
                onPressed: () async {
                  await windowManager.maximize();
                },
              );
            },
          ),
          WindowCaptionButton.close(
            brightness: brightness,
            onPressed: () async {
              await windowManager.close();
            },
          ),
        ],
      ),
    );
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() {});
    }
  }
}

class DesktopWindowChromeMetrics {
  const DesktopWindowChromeMetrics._();

  static double sidebarTopPadding(BuildContext context) {
    return Theme.of(context).platform == TargetPlatform.macOS ? 58 : 24;
  }
}

bool _isNativeDesktopPlatform(TargetPlatform platform) {
  return platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}
