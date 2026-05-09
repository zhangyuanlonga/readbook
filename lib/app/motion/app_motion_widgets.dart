import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/app_status_state_card.dart';
import 'app_motion.dart';

enum AppLoadingState { loading, empty, error, content }

class AppAnimatedSwitcher extends StatelessWidget {
  const AppAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.medium,
    this.reverseDuration,
    this.switchInCurve = AppMotion.standard,
    this.switchOutCurve = AppMotion.accelerate,
    this.enabled = true,
    this.transitionBuilder,
    this.layoutBuilder,
  });

  final Widget child;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve switchInCurve;
  final Curve switchOutCurve;
  final bool enabled;
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;
  final AnimatedSwitcherLayoutBuilder? layoutBuilder;

  @override
  Widget build(BuildContext context) {
    final motionEnabled = AppMotion.enabledOf(context, enabled: enabled);
    return AnimatedSwitcher(
      duration: AppMotion.durationOf(context, duration, enabled: enabled),
      reverseDuration:
          motionEnabled ? (reverseDuration ?? duration) : AppMotion.instant,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      layoutBuilder: layoutBuilder ?? AnimatedSwitcher.defaultLayoutBuilder,
      transitionBuilder:
          transitionBuilder ??
          (child, animation) {
            if (!motionEnabled) {
              return child;
            }
            return FadeTransition(opacity: animation, child: child);
          },
      child: child,
    );
  }
}

class AppFadeSlideTransition extends StatefulWidget {
  const AppFadeSlideTransition({
    super.key,
    required this.child,
    this.duration = AppMotion.medium,
    this.delay = Duration.zero,
    this.curve = AppMotion.standard,
    this.beginOffset = AppMotion.sectionEnterOffset,
    this.beginOpacity = 0,
    this.enabled = true,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Offset beginOffset;
  final double beginOpacity;
  final bool enabled;

  @override
  State<AppFadeSlideTransition> createState() => _AppFadeSlideTransitionState();
}

class _AppFadeSlideTransitionState extends State<AppFadeSlideTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  Timer? _delayTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 0,
    );
    _configureAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionState();
  }

  @override
  void didUpdateWidget(AppFadeSlideTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve ||
        widget.beginOffset != oldWidget.beginOffset ||
        widget.beginOpacity != oldWidget.beginOpacity) {
      _configureAnimations();
    }
    if (widget.enabled != oldWidget.enabled ||
        widget.delay != oldWidget.delay) {
      _started = false;
      _delayTimer?.cancel();
      _syncMotionState();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _configureAnimations() {
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(
      begin: widget.beginOpacity,
      end: 1,
    ).animate(curved);
    _offset = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(curved);
  }

  void _syncMotionState() {
    if (!AppMotion.enabledOf(context, enabled: widget.enabled)) {
      _controller.value = 1;
      return;
    }
    if (_started) {
      return;
    }
    _started = true;
    if (widget.delay == Duration.zero) {
      unawaited(_controller.forward());
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (!mounted) {
        return;
      }
      unawaited(_controller.forward());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppMotion.enabledOf(context, enabled: widget.enabled)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

class AppStaggeredEntrance extends StatelessWidget {
  const AppStaggeredEntrance({
    super.key,
    required this.children,
    this.direction = Axis.vertical,
    this.spacing = 0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.duration = AppMotion.medium,
    this.staggerDelay = AppMotion.fast,
    this.beginOffset = AppMotion.sectionEnterOffset,
    this.enabled = true,
  });

  final List<Widget> children;
  final Axis direction;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final Duration duration;
  final Duration staggerDelay;
  final Offset beginOffset;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final wrapped = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0 && spacing > 0) {
        wrapped.add(
          direction == Axis.vertical
              ? SizedBox(height: spacing)
              : SizedBox(width: spacing),
        );
      }
      wrapped.add(
        AppFadeSlideTransition(
          delay: staggerDelay * index,
          duration: duration,
          beginOffset: beginOffset,
          enabled: enabled,
          child: children[index],
        ),
      );
    }

    return Flex(
      direction: direction,
      crossAxisAlignment: crossAxisAlignment,
      children: wrapped,
    );
  }
}

class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.semanticLabel,
    this.enabled = true,
    this.scale = 0.985,
    this.duration = AppMotion.fast,
    this.mouseCursor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final bool enabled;
  final double scale;
  final Duration duration;
  final MouseCursor? mouseCursor;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  bool get _enabled =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  @override
  Widget build(BuildContext context) {
    final motionEnabled = AppMotion.enabledOf(context, enabled: widget.enabled);
    final radius = widget.borderRadius ?? BorderRadius.circular(12);
    final content = AnimatedScale(
      scale: motionEnabled && _pressed ? widget.scale : 1,
      duration: AppMotion.durationOf(
        context,
        widget.duration,
        enabled: widget.enabled,
      ),
      curve: AppMotion.standard,
      child: widget.child,
    );

    return Semantics(
      button: _enabled,
      label: widget.semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: _enabled ? widget.onTap : null,
          onLongPress: _enabled ? widget.onLongPress : null,
          borderRadius: radius,
          mouseCursor:
              widget.mouseCursor ??
              (_enabled ? SystemMouseCursors.click : SystemMouseCursors.basic),
          onHighlightChanged: (value) {
            if (_pressed == value) {
              return;
            }
            setState(() {
              _pressed = value;
            });
          },
          child: content,
        ),
      ),
    );
  }
}

class AppLoadingStateSwitcher extends StatelessWidget {
  const AppLoadingStateSwitcher({
    super.key,
    required this.state,
    required this.loading,
    required this.empty,
    required this.error,
    required this.content,
    this.duration = AppMotion.medium,
    this.enabled = true,
  });

  final AppLoadingState state;
  final Widget loading;
  final Widget empty;
  final Widget error;
  final Widget content;
  final Duration duration;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final child = switch (state) {
      AppLoadingState.loading => loading,
      AppLoadingState.empty => empty,
      AppLoadingState.error => error,
      AppLoadingState.content => content,
    };
    return AppAnimatedSwitcher(
      duration: duration,
      enabled: enabled,
      child: KeyedSubtree(key: ValueKey<AppLoadingState>(state), child: child),
    );
  }
}

class AppAnimatedStatusCard extends StatelessWidget {
  const AppAnimatedStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = AppStatusStateTone.neutral,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.footer,
    this.visible = true,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final AppStatusStateTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  final Widget? footer;
  final bool visible;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppAnimatedSwitcher(
      enabled: enabled,
      child:
          visible
              ? AppStatusStateCard(
                key: ValueKey<String>('$title|$message|$tone'),
                icon: icon,
                title: title,
                message: message,
                tone: tone,
                actionLabel: actionLabel,
                onAction: onAction,
                compact: compact,
                footer: footer,
              )
              : const SizedBox.shrink(key: ValueKey<String>('hidden')),
    );
  }
}
