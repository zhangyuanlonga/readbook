import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/datasources/local/app_database.dart';
import '../features/source/application/external_source_import_bridge.dart';
import 'layout/app_layout.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_provider.dart';
import 'theme/app_theme_seed_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedColor = ref.watch(appSeedColorProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    final lightScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      brightness: Brightness.light,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      title: '书享阅读',
      theme: AppTheme.build(lightScheme),
      darkTheme: AppTheme.build(darkScheme),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 180),
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: appRouter,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final textScale = AppLayout.clampedTextScaleFactor(context);

        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
          child: _SystemUiOverlayWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _SystemUiOverlayWrapper extends StatefulWidget {
  const _SystemUiOverlayWrapper({required this.child});

  final Widget child;

  @override
  State<_SystemUiOverlayWrapper> createState() =>
      _SystemUiOverlayWrapperState();
}

class _SystemUiOverlayWrapperState extends State<_SystemUiOverlayWrapper> {
  StreamSubscription<IncomingSourceImportPayload>? _incomingImportSub;
  Brightness? _lastBrightness;
  bool _hasShownStartupAnnouncement = false;
  bool _startupAnnouncementScheduled = false;
  int _startupAnnouncementRetryCount = 0;
  bool _isStartupReady = false;
  bool _skipStartupAnnouncement = false;
  Timer? _startupDelayTimer;

  static const Duration _kStartupMinDuration = Duration(milliseconds: 500);
  static const String _kStartupAnnouncementSkipKey =
      'startup_announcement_skip_v1';

  @override
  void initState() {
    super.initState();
    _incomingImportSub = ExternalSourceImportBridge.instance.payloadStream
        .listen(_onIncomingSourceImportPayload);
    unawaited(ExternalSourceImportBridge.instance.initialize());
    unawaited(_prepareStartup());
  }

  Future<void> _prepareStartup() async {
    final startedAt = DateTime.now();
    final preferencesFuture = SharedPreferences.getInstance();

    try {
      await AppDatabase.instance.countSourceListItems();
    } catch (_) {
      // Ignore warmup failures and continue startup.
    }

    try {
      final prefs = await preferencesFuture;
      _skipStartupAnnouncement =
          prefs.getBool(_kStartupAnnouncementSkipKey) ?? false;
    } catch (_) {
      _skipStartupAnnouncement = false;
    }

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _kStartupMinDuration - elapsed;
    if (remaining > Duration.zero) {
      await _waitStartupDelay(remaining);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isStartupReady = true;
    });
    _showStartupAnnouncementIfNeeded();
  }

  Future<void> _waitStartupDelay(Duration delay) {
    if (delay <= Duration.zero) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _startupDelayTimer?.cancel();
    _startupDelayTimer = Timer(delay, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    return completer.future;
  }

  @override
  void dispose() {
    _incomingImportSub?.cancel();
    _startupDelayTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness == brightness) {
      return;
    }
    _lastBrightness = brightness;

    final base =
        brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

    final style = base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    SystemChrome.setSystemUIOverlayStyle(style);
  }

  void _showStartupAnnouncementIfNeeded() {
    if (!_isStartupReady ||
        _hasShownStartupAnnouncement ||
        _skipStartupAnnouncement ||
        _startupAnnouncementScheduled) {
      return;
    }

    _startupAnnouncementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupAnnouncementScheduled = false;
      if (!mounted || _hasShownStartupAnnouncement) {
        return;
      }

      final navigatorContext = appRootNavigatorKey.currentContext;
      if (navigatorContext == null) {
        if (_startupAnnouncementRetryCount < 10) {
          _startupAnnouncementRetryCount += 1;
          _showStartupAnnouncementIfNeeded();
        }
        return;
      }

      _startupAnnouncementRetryCount = 0;
      _hasShownStartupAnnouncement = true;
      showDialog<void>(
        context: navigatorContext,
        builder: (context) {
          return AlertDialog(
            title: const Text('公告'),
            content: const Text('每天高产更新，请在我的页面点击反馈进群及时使用最新版。'),
            actions: [
              TextButton(
                onPressed:
                    () => _dismissStartupAnnouncementPermanently(context),
                child: const Text('不再显示'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('我知道了'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _dismissStartupAnnouncementPermanently(
    BuildContext dialogContext,
  ) async {
    Navigator.of(dialogContext).pop();
    _skipStartupAnnouncement = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kStartupAnnouncementSkipKey, true);
    } catch (_) {
      // Ignore preference write failures; skip stays in-memory for this run.
    }
  }

  void _onIncomingSourceImportPayload(IncomingSourceImportPayload _) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      appRouter.go('/source');
    });
  }

  @override
  Widget build(BuildContext context) {
    final style =
        _isStartupReady
            ? _adaptiveOverlayStyle(context)
            : _startupOverlayStyle(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (!_isStartupReady) const _StartupGuardPage(),
        ],
      ),
    );
  }

  SystemUiOverlayStyle _adaptiveOverlayStyle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final base =
        brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  SystemUiOverlayStyle _startupOverlayStyle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final base =
        brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;
    final navColor = Theme.of(context).colorScheme.surface;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: navColor,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}

class _StartupGuardPage extends StatelessWidget {
  const _StartupGuardPage();

  static const List<String> _brandTextChars = ['书', '享', '阅', '读'];
  static const List<String> _sloganTextChars = [
    '享',
    '受',
    '阅',
    '读',
    '生',
    '活',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    const brandGap = 2.0;
    const brandLineHeight = 1.02;
    final brandFontSize =
        (shortestSide * 0.165).clamp(48.0, 66.0).toDouble();
    final sloganFontSize =
        (shortestSide * 0.08).clamp(23.0, 33.0).toDouble();
    final sloganTopOffset = (brandFontSize * brandLineHeight + brandGap) * 2;
    final fontFamilyFallback = const [
      'STKaiti',
      'Kaiti SC',
      'KaiTi',
      'Songti SC',
      'Noto Serif CJK SC',
      'serif',
    ];
    final backgroundTop = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.05),
      colorScheme.surface,
    );
    final backgroundBottom = Color.alphaBlend(
      colorScheme.secondary.withValues(alpha: isDark ? 0.14 : 0.04),
      colorScheme.surface,
    );
    final brandColor =
        isDark
            ? const Color(0xFFF2EFE8)
            : colorScheme.onSurface.withValues(alpha: 0.9);
    final sloganColor = brandColor.withValues(alpha: isDark ? 0.88 : 0.72);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [backgroundTop, backgroundBottom],
        ),
      ),
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VerticalTextColumn(
                    characters: _brandTextChars,
                    gap: brandGap,
                    style: TextStyle(
                      color: brandColor,
                      fontSize: brandFontSize,
                      height: brandLineHeight,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                      fontFamilyFallback: fontFamilyFallback,
                    ),
                  ),
                  SizedBox(width: shortestSide * 0.048),
                  Padding(
                    padding: EdgeInsets.only(top: sloganTopOffset),
                    child: _VerticalTextColumn(
                      characters: _sloganTextChars,
                      gap: 1,
                      style: TextStyle(
                        color: sloganColor,
                        fontSize: sloganFontSize,
                        height: 1.02,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                        fontFamilyFallback: fontFamilyFallback,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalTextColumn extends StatelessWidget {
  const _VerticalTextColumn({
    required this.characters,
    required this.style,
    this.gap = 0,
  });

  final List<String> characters;
  final TextStyle style;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final character in characters)
          Padding(
            padding: EdgeInsets.symmetric(vertical: gap / 2),
            child: Text(
              character,
              style: style.copyWith(
                decoration: TextDecoration.none,
                decorationColor: Colors.transparent,
              ),
            ),
          ),
      ],
    );
  }
}
