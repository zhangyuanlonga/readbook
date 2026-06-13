import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_desktop_input_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_annotation_controller.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_chrome_action_presenter.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_desktop_input_dispatcher.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_page_support_models.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_pointer_input_controller.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_selection_toolbar_presenter.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_touch_navigation_controller.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/widgets/chrome/reader_overlay_bars.dart';

void main() {
  group('ReaderTouchNavigationController', () {
    const controller = ReaderTouchNavigationController();
    final now = DateTime.utc(2026, 6, 13, 10);

    ReaderTouchNavigationIntent resolve({
      bool textSelectionActive = false,
      bool initialInteractionCoolingDown = false,
      bool backNavigationCoolingDown = false,
      ReaderTouchAutoReadStatus autoReadStatus = ReaderTouchAutoReadStatus.off,
      bool autoReadSessionEnabled = false,
      DateTime? autoReadTapGuardUntil,
      bool overlayVisible = false,
      bool tapEnabled = true,
      bool usesScrollLayout = false,
    }) {
      return controller.resolveTapStart(
        textSelectionActive: textSelectionActive,
        initialInteractionCoolingDown: initialInteractionCoolingDown,
        backNavigationCoolingDown: backNavigationCoolingDown,
        autoReadStatus: autoReadStatus,
        autoReadSessionEnabled: autoReadSessionEnabled,
        autoReadTapGuardUntil: autoReadTapGuardUntil,
        now: now,
        overlayVisible: overlayVisible,
        tapEnabled: tapEnabled,
        usesScrollLayout: usesScrollLayout,
      );
    }

    test('ignores selection and cooldown taps', () {
      expect(resolve(textSelectionActive: true).type, _ignore);
      expect(resolve(initialInteractionCoolingDown: true).type, _ignore);
      expect(resolve(backNavigationCoolingDown: true).type, _ignore);
    });

    test('routes auto-read taps before normal tap-zone handling', () {
      expect(
        resolve(autoReadStatus: ReaderTouchAutoReadStatus.chapterPaused).type,
        ReaderTouchNavigationIntentType.showAutoReadControl,
      );
      expect(
        resolve(
          autoReadSessionEnabled: true,
          autoReadStatus: ReaderTouchAutoReadStatus.running,
        ).type,
        ReaderTouchNavigationIntentType.openAutoReadOverlay,
      );
      expect(
        resolve(
          autoReadSessionEnabled: true,
          autoReadStatus: ReaderTouchAutoReadStatus.paused,
        ).type,
        ReaderTouchNavigationIntentType.showAutoReadControl,
      );
      expect(
        resolve(
          autoReadSessionEnabled: true,
          autoReadStatus: ReaderTouchAutoReadStatus.running,
          autoReadTapGuardUntil: now.add(const Duration(milliseconds: 50)),
        ).type,
        _ignore,
      );
    });

    test('routes overlay and tap-zone intents', () {
      expect(
        resolve(overlayVisible: true).type,
        ReaderTouchNavigationIntentType.hideOverlay,
      );
      expect(resolve(tapEnabled: false, usesScrollLayout: false).type, _ignore);
      expect(
        resolve(tapEnabled: false, usesScrollLayout: true).type,
        ReaderTouchNavigationIntentType.resolveTapZone,
      );

      final tapZoneIntent = controller.resolveTapZoneAction(
        ReaderTapZoneAction.nextPage,
      );
      expect(
        tapZoneIntent.type,
        ReaderTouchNavigationIntentType.performTapZoneAction,
      );
      expect(tapZoneIntent.tapZoneAction, ReaderTapZoneAction.nextPage);
    });
  });

  group('ReaderPointerInputController', () {
    test('marks child-handled taps so fallback reader tap can be skipped', () {
      final controller = ReaderPointerInputController(
        now: () => DateTime.utc(2026, 6, 13, 10),
      );
      final traces = <String>[];

      controller.beginPointer(
        const PointerDownEvent(
          pointer: 1,
          position: Offset(10, 10),
          kind: PointerDeviceKind.touch,
        ),
        shouldHandleLongPress: false,
        selectionActive: false,
        resolveLongPressGuard:
            () => const ReaderPointerLongPressGuard(
              mounted: true,
              selectionActive: false,
            ),
        logTrace: (step, {context = const <String, Object?>{}}) {
          traces.add(step);
        },
        onLongPress: () {},
      );
      controller.markChildHandled();
      final snapshot = controller.buildPointerUpSnapshot(
        const PointerUpEvent(
          pointer: 1,
          position: Offset(10, 10),
          kind: PointerDeviceKind.touch,
        ),
      );

      expect(snapshot?.childHandled, isTrue);
      expect(traces, contains('pointer_down'));
    });

    test('movement cancels reader-level long press priority', () {
      final controller = ReaderPointerInputController(
        now: () => DateTime.utc(2026, 6, 13, 10),
      );
      final traces = <String>[];

      controller.beginPointer(
        const PointerDownEvent(
          pointer: 1,
          position: Offset(0, 0),
          kind: PointerDeviceKind.touch,
        ),
        shouldHandleLongPress: true,
        selectionActive: false,
        resolveLongPressGuard:
            () => const ReaderPointerLongPressGuard(
              mounted: true,
              selectionActive: false,
            ),
        logTrace: (step, {context = const <String, Object?>{}}) {
          traces.add(step);
        },
        onLongPress: () {},
      );

      controller.updatePointerMove(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(80, 0),
          kind: PointerDeviceKind.touch,
        ),
        logTrace: (step, {context = const <String, Object?>{}}) {
          traces.add(step);
        },
      );
      final snapshot = controller.buildPointerUpSnapshot(
        const PointerUpEvent(
          pointer: 1,
          position: Offset(80, 0),
          kind: PointerDeviceKind.touch,
        ),
      );

      expect(snapshot?.moved, isTrue);
      expect(traces, contains('pointer_move_cancel_long_press'));
    });

    test('selection active blocks reader fallback long press', () async {
      final controller = ReaderPointerInputController();
      var longPressed = false;

      controller.beginPointer(
        const PointerDownEvent(
          pointer: 1,
          position: Offset(0, 0),
          kind: PointerDeviceKind.touch,
        ),
        shouldHandleLongPress: true,
        selectionActive: true,
        resolveLongPressGuard:
            () => const ReaderPointerLongPressGuard(
              mounted: true,
              selectionActive: true,
            ),
        logTrace: (step, {context = const <String, Object?>{}}) {},
        onLongPress: () {
          longPressed = true;
        },
      );

      await Future<void>.delayed(
        kLongPressTimeout + const Duration(milliseconds: 20),
      );

      expect(longPressed, isFalse);
      controller.dispose();
    });
  });

  group('ReaderDesktopInputDispatcher', () {
    const dispatcher = ReaderDesktopInputDispatcher();
    const snapshot = ReaderDesktopInputSnapshot(
      textSelectionActive: false,
      editingText: false,
      readerBusy: false,
      overlayVisible: false,
      autoReadSessionEnabled: false,
      isPagedViewport: true,
    );

    test('resolves key down events through desktop resolver', () {
      final intent = dispatcher.resolveKeyIntent(
        event: const KeyDownEvent(
          logicalKey: LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
          timeStamp: Duration.zero,
        ),
        snapshot: snapshot,
      );

      expect(intent.action, ReaderDesktopInputAction.nextPage);

      final ignored = dispatcher.resolveKeyIntent(
        event: const KeyUpEvent(
          logicalKey: LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
          timeStamp: Duration.zero,
        ),
        snapshot: snapshot,
      );

      expect(ignored.action, ReaderDesktopInputAction.none);
    });

    test('resolves pointer wheel intents and update marker', () {
      final intent = dispatcher.resolvePointerSignalIntent(
        event: const PointerScrollEvent(scrollDelta: Offset(0, 24)),
        snapshot: snapshot,
        now: DateTime.utc(2026, 6, 13, 10),
      );

      expect(intent.action, ReaderDesktopInputAction.nextPage);
      expect(intent.updateLastPageTurnAt, isTrue);

      final ignored = dispatcher.resolvePointerSignalIntent(
        event: const PointerScrollEvent(scrollDelta: Offset(0, 2)),
        snapshot: snapshot,
        now: DateTime.utc(2026, 6, 13, 10),
      );

      expect(ignored.action, ReaderDesktopInputAction.none);
      expect(ignored.updateLastPageTurnAt, isFalse);
    });
  });

  group('ReaderSelectionToolbarPresenter', () {
    const presenter = ReaderSelectionToolbarPresenter();

    test('maps annotation actions to inspiration action items', () {
      var pressed = false;
      final items = presenter.buildItems(
        actions: const [
          ReaderAnnotationToolbarAction(
            kind: ReaderAnnotationToolbarActionKind.saveOrRemoveBookmark,
            label: '删除灵感',
            isDestructive: true,
          ),
          ReaderAnnotationToolbarAction(
            kind: ReaderAnnotationToolbarActionKind.toggleHighlight,
            label: '取消高亮',
            isActive: true,
          ),
        ],
        onAction: (action) => () => pressed = true,
      );

      expect(items, hasLength(2));
      expect(items.first.icon, Icons.delete_outline_rounded);
      expect(items.first.label, '删除灵感');
      expect(items.last.icon, Icons.highlight_alt_rounded);
      expect(items.last.isActive, isTrue);

      items.first.onPressed();
      expect(pressed, isTrue);
    });
  });

  group('ReaderChromeActionPresenter', () {
    const presenter = ReaderChromeActionPresenter();

    test('resolves day-night and auto-read actions', () {
      final dayNight = presenter.dayNightAction(isDarkMode: true);
      expect(dayNight.label, '日间');
      expect(dayNight.tooltip, '切换日间模式');
      expect(dayNight.active, isTrue);

      final autoRead = presenter.autoReadAction(
        ReaderChromeAutoReadStatus.running,
      );
      expect(autoRead.label, '暂停');
      expect(autoRead.tooltip, '暂停自动阅读');
      expect(autoRead.active, isTrue);
    });

    test('resolves progress labels and top more actions', () {
      expect(
        presenter.chapterProgressLabel(
          bookTitle: '测试书',
          currentIndex: 2,
          chapterCount: 10,
        ),
        '测试书 · 第 3 / 10 章',
      );
      expect(
        presenter.chapterProgressLabel(
          bookTitle: '',
          currentIndex: null,
          chapterCount: 0,
        ),
        '加载章节信息中',
      );

      final actions = presenter.buildTopMoreActions(
        canCacheChapter: true,
        isCurrentChapterCached: true,
        canSwitchSource: true,
        isSwitchSourceLoading: true,
        isShelfActionLoading: false,
        isInBookshelf: false,
      );

      expect(actions, hasLength(3));
      expect(actions.first.kind, ReaderChromeTopMoreActionKind.cacheChapter);
      expect(actions.first.enabled, isFalse);
      expect(actions[1].loading, isTrue);
      expect(actions.last.title, '加入书架');
    });
  });

  group('Reader overlay chrome widgets', () {
    testWidgets('top overlay renders title and actions', (tester) async {
      var moreCount = 0;

      await tester.pumpWidget(
        _wrapOverlay(
          ReaderTopOverlayBar(
            colors: _colors,
            overlayVisible: true,
            animation: const AlwaysStoppedAnimation<double>(1),
            fadeProgress: 1,
            transitionBuilder: (child) => child,
            chapterTitle: '章节标题',
            chapterLine: '测试书 · 第 1 / 10 章',
            useDesktopChrome: true,
            autoReadAction: const ReaderChromeActionData(
              icon: Icons.play_circle_outline_rounded,
              label: '自动',
              tooltip: '自动阅读',
            ),
            dayNightAction: const ReaderChromeActionData(
              icon: Icons.dark_mode_rounded,
              label: '夜间',
              tooltip: '切换夜间模式',
            ),
            onBack: () {},
            onCatalog: () {},
            onAutoRead: () {},
            onToggleDayNight: () {},
            onInterfaceSettings: () {},
            onOpenDetail: () {},
            onMore: () => moreCount += 1,
            onActionPointerDown: () {},
          ),
        ),
      );

      expect(find.text('章节标题'), findsOneWidget);
      expect(find.text('测试书 · 第 1 / 10 章'), findsOneWidget);

      await tester.tap(find.byTooltip('更多'));
      expect(moreCount, 1);
    });

    testWidgets('mobile bottom overlay renders progress and action row', (
      tester,
    ) async {
      var catalogCount = 0;

      await tester.pumpWidget(
        _wrapOverlay(
          ReaderMobileBottomOverlayBar(
            colors: _colors,
            overlayVisible: true,
            animation: const AlwaysStoppedAnimation<double>(1),
            fadeProgress: 1,
            transitionBuilder: (child) => child,
            progressStrip: const Text('progress-strip'),
            autoReadAction: const ReaderChromeActionData(
              icon: Icons.play_circle_outline_rounded,
              label: '自动',
              tooltip: '自动阅读',
            ),
            dayNightAction: const ReaderChromeActionData(
              icon: Icons.dark_mode_rounded,
              label: '夜间',
              tooltip: '切换夜间模式',
            ),
            interfaceAction: const ReaderChromeActionData(
              icon: Icons.palette_outlined,
              label: '界面',
              tooltip: '界面设置',
            ),
            onCatalog: (_) async => catalogCount += 1,
            onAutoRead: (_) async {},
            onAutoReadLongPress: () async {},
            onToggleDayNight: (_) async {},
            onInterfaceSettings: (_) async {},
            onActionPointerDown: () {},
            onActionError: () {},
          ),
        ),
      );

      expect(find.text('progress-strip'), findsOneWidget);
      expect(find.text('目录'), findsOneWidget);
      expect(find.text('自动'), findsOneWidget);
      expect(find.text('界面'), findsOneWidget);

      await tester.tap(find.text('目录'));
      expect(catalogCount, 1);
    });
  });
}

const _ignore = ReaderTouchNavigationIntentType.ignore;

const _colors = ReaderThemeColors(
  background: Colors.white,
  text: Colors.black,
  meta: Colors.black54,
  divider: Colors.black26,
  overlay: Colors.white,
);

Widget _wrapOverlay(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox.expand(child: Stack(children: [child]))),
  );
}
