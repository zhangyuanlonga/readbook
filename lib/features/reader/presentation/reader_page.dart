// UI-GOV-EXEMPT-FILE: platform-branch
// reason: Phase 10 reviewed Reader shell platform branches; migration is deferred to the Reader outer-shell phase.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_adaptive.dart';
import '../../../app/images/local_file_image.dart';
import '../../../app/motion/app_motion.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/adaptive_fullscreen_preview.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../app/widgets/switch_source_candidate_sheet.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/app_exception_diagnostics.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/membership/membership_access_service.dart';
import '../../../core/storage/local_file_stat.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../domain/entities/reader_visual_overrides.dart';
import '../../../domain/entities/source_health.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reader_toc_snapshot.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../book/application/book_detail_service.dart';
import '../../book/presentation/book_detail_route.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../../mine/application/reader_background_service.dart';
import '../../search/application/search_hit_cache_service.dart';
import '../../search/application/search_service.dart';
import '../../source/application/source_health_service.dart';
import '../../source/application/remote_content_task_conflict_service.dart';
import '../../source/application/remote_content_task_scheduler_service.dart';
import '../../source/routes.dart';
import '../application/content_provider.dart';
import '../application/chapter_content_service.dart';
import '../application/local/local_reader_identity.dart';
import '../application/paged_transition_controller.dart';
import '../application/reader_audio_controller.dart';
import '../application/reader_auto_read_coordinator.dart';
import '../application/reader_cache_feedback_resolver.dart';
import '../application/reader_content_session.dart';
import '../application/reader_content_mode_resolver.dart';
import '../application/reader_desktop_input_resolver.dart';
import '../application/reader_mode_capabilities.dart';
import '../application/reader_mode_model.dart';
import '../application/reader_mode_resolver.dart';
import '../application/reader_entry_route_resolver.dart';
import '../application/reader_catalog_entry_controller.dart';
import '../application/reader_catalog_search_service.dart';
import '../application/reader_chapter_cache_decoder.dart';
import '../application/reader_chapter_load_planner.dart';
import '../application/reader_chapter_window_controller.dart';
import '../application/reader_chapter_flow.dart';
import '../application/reader_chapter_navigation.dart';
import '../application/reader_content_load_controller.dart';
import '../application/reader_content_mode_surface_controller.dart';
import '../application/reader_document_render_model.dart';
import '../application/reader_font_registry_service.dart';
import '../application/reader_image_decode_budget.dart';
import '../application/reader_interaction_runtime_controller.dart';
import '../application/removed_script_source_guard.dart';
import '../application/reader_jump_facade.dart';
import '../application/reader_jump_planner.dart';
import '../application/reader_layout_anchor_readiness_policy.dart';
import '../application/reader_layout_resolver.dart';
import '../application/reader_layout_release_policy.dart';
import '../application/reader_layout_renderer_controller.dart';
import '../application/reader_layout_request.dart';
import '../application/reader_navigation_command_dispatcher.dart';
import '../application/reader_navigation_entry_resolver.dart';
import '../application/reader_overlay_controller.dart';
import '../application/reader_page_turn_gate.dart';
import '../application/reader_page_turn_coordinator.dart';
import '../application/reader_page_bootstrap_controller.dart';
import '../application/reader_pagination_controller.dart';
import '../application/reader_pagination_cache_service.dart';
import '../application/reader_pagination_engine.dart';
import '../application/reader_pagination_models.dart';
import '../application/reader_pagination_spec.dart';
import '../application/reader_platform_bridge_service.dart';
import '../application/reader_platform_facade.dart';
import '../application/reader_progress_commit_controller.dart';
import '../application/reader_surface_position.dart';
import '../application/reader_surface_position_runtime.dart';
import '../application/reader_settings_groups.dart';
import '../application/reader_settings_entry_controller.dart';
import '../application/reader_settings_resolution_service.dart';
import '../application/reader_selection_controller.dart';
import '../application/reader_selection_runtime.dart';
import '../application/reader_session_presentation_facade.dart';
import '../application/reader_surface_policy_resolver.dart';
import '../application/reader_surface_metrics.dart';
import '../application/reader_logical_position.dart';
import '../application/local/local_chapter_content_service.dart';
import '../application/reader_session_controller.dart';
import '../application/reader_preferences_service.dart';
import '../application/reader_preload_controller.dart';
import '../application/reader_resource_budget.dart';
import '../application/reader_renderer_authority_resolver.dart';
import '../application/reader_runtime_facade.dart';
import '../application/reader_runtime_lifecycle_controller.dart';
import '../application/reader_runtime_wake_policy.dart';
import '../application/reader_visual_overrides_service.dart';
import '../application/reader_session_state.dart';
import '../application/reader_session_state_resolver.dart';
import '../application/reader_streaming_pagination_controller.dart';
import '../application/reader_source_switch_coordinator.dart';
import '../application/reader_source_switch_service.dart';
import '../application/reader_reading_record_coordinator.dart';
import '../application/reading_record_service.dart';
import '../application/reader_error_center_service.dart';
import '../application/reader_feedback_service.dart';
import '../application/reader_failure_presentation_service.dart';
import '../application/reader_system_settings_service.dart';
import '../application/reader_theme_mode_service.dart';
import '../application/reader_typography_resolver.dart';
import '../application/reader_typography_metrics_resolver.dart';
import '../application/reader_viewport_state.dart';
import '../application/text_reader_renderer.dart';
import '../application/reader_volume_key_page_bridge.dart';
import '../application/source_switch_score_service.dart';
import '../application/switch_source_shared.dart';
import '../application/local/local_book_storage_service.dart';
import '../application/reader_cached_chapter_store.dart';
import '../application/reader_dependencies_provider.dart';
import 'chapter_cache_sheets.dart';
import 'reader_catalog_sheet.dart';
import 'reader_annotated_text.dart';
import 'reader_audio_view.dart';
import 'reader_annotation_controller.dart';
import 'reader_annotation_interaction.dart';
import 'reader_annotation_presenter.dart';
import 'reader_body_region.dart';
import 'reader_bookmark_range_presenter.dart';
import 'reader_chrome_action_presenter.dart';
import 'reader_content_loading_controller.dart';
import 'reader_content_loading_presenter.dart';
import 'reader_desktop_input_dispatcher.dart';
import 'reader_error_presenter.dart';
import 'reader_feedback_widgets.dart';
import 'reader_layout_context.dart';
import 'reader_layout_paged_view.dart';
import 'reader_layout_release_surface.dart';
import 'paged_animation/curl_paged_animation_renderer.dart';
import 'paged_animation/reader_paged_animation_surface.dart';
import 'reader_interaction_coordinator.dart';
import 'reader_pdf_view.dart';
import 'reader_paper_curl_paged_view.dart';
import 'reader_page_lifecycle_delegate.dart';
import 'reader_page_support_models.dart';
import 'reader_page_turn_runtime_controller.dart';
import 'reader_pointer_input_controller.dart';
import 'reader_overlay_z_order.dart';
import 'reader_selection_state.dart';
import 'reader_shell.dart';
import 'reader_source_switch_controller.dart';
import 'reader_settings_presenter.dart';
import 'reader_text_offset_mapper.dart' as text_offset_mapper;
import 'reader_text_block_presentation.dart';
import 'reader_paged_viewport_support.dart';
import 'reader_cross_chapter_snapshot_overlay.dart';
import 'reader_presentation_resolver.dart';
import 'reader_runtime_controller.dart';
import 'reader_selection_overlay_policy.dart';
import 'reader_selection_toolbar_presenter.dart';
import 'reader_tap_zone_resolver.dart';
import 'reader_text_paged_view.dart';
import 'reader_touch_navigation_controller.dart';
import 'reader_viewport_builder.dart';
import 'widgets/background/reader_background_layer.dart';
import 'widgets/chrome/reader_chrome_widgets.dart';
import 'widgets/chrome/reader_overlay_bars.dart';
import 'widgets/chrome/reader_transient_layers.dart';
import 'widgets/overlay/reader_overlay_layer_model.dart';
import 'widgets/reader_cached_network_image.dart';
import 'widgets/viewport/reader_page_scaffold_shell.dart';
import 'sheets/reader_settings/reader_audio_settings_section.dart';
import 'sheets/reader_settings/reader_auto_read_settings_section.dart';
import 'sheets/reader_settings/reader_floating_settings_sheet.dart';
import 'sheets/reader_settings/reader_font_picker_sheet.dart';
import 'sheets/reader_settings/reader_font_weight_sheet.dart';
import 'sheets/reader_settings/reader_layout_settings_section.dart';
import 'sheets/reader_settings/reader_manga_settings_section.dart';
import 'sheets/reader_settings/reader_page_turn_settings_section.dart';
import 'sheets/reader_settings/reader_settings_background_tiles_presenter.dart';
import 'sheets/reader_settings/reader_settings_components.dart';
import 'sheets/reader_settings/reader_settings_sections.dart';
import 'sheets/reader_settings/reader_settings_sheet_frame.dart';
import 'sheets/reader_settings/reader_settings_sheet_session.dart';
import 'sheets/reader_settings/reader_tap_zone_editor_sheet.dart';
import 'sheets/reader_settings/reader_theme_background_settings_section.dart';
import 'sheets/reader_settings/reader_typography_settings_section.dart';

part 'reader_page_content_loading.dart';
part 'reader_page_selection.dart';
part 'reader_page_background.dart';
part 'reader_page_bootstrap.dart';
part 'reader_page_content_rendering.dart';
part 'reader_page_lifecycle.dart';
part 'reader_page_navigation.dart';
part 'reader_page_runtime.dart';
part 'reader_chrome_surface.dart';
part 'reader_page_shell.dart';
part 'reader_page_settings_sheet.dart';
part 'reader_page_source_switch.dart';
part 'reader_page_viewport.dart';

/// 阅读器页面的路由入口 widget。
///
/// 这里只保留 route 传入的章节身份参数，真实运行态继续由
/// [_ReaderPageState] 和各个 part 承接；后续拆分 ReaderPage 时，不能在
/// 入口 widget 里新增加载、缓存、平台桥或进度保存逻辑。
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    required this.chapterId,
    this.chapterUrl,
    this.chapterTitle,
    this.sourceId,
    this.detailUrl,
    this.chapterIndex,
    this.bookmarkId,
    this.openRequestedAtMs,
    this.openRouteKind,
    this.heroTag,
  });

  final String bookId;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final String? sourceId;
  final String? detailUrl;
  final int? chapterIndex;
  final String? bookmarkId;
  final int? openRequestedAtMs;
  final String? openRouteKind;
  final String? heroTag;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

enum _ReaderSettingsTab { interface, reading }

enum _OverlayEdge { top, bottom }

enum _ReaderAutoReadControlAction { catalog, toggle, settings, exit }

enum ReaderAutoReadSessionState {
  off,
  running,
  paused,
  chapterPaused,
  finished,
}

extension _ReaderDesktopInputLayer on _ReaderPageState {
  KeyEventResult _handleReaderKeyEvent(FocusNode node, KeyEvent event) {
    final intent = _desktopInputDispatcher.resolveKeyIntent(
      event: event,
      snapshot: _desktopInputSnapshot(),
    );
    return _dispatchReaderDesktopInputAction(intent.action);
  }

  void _handleReaderPointerSignal(PointerSignalEvent event) {
    final now = DateTime.now();
    final intent = _desktopInputDispatcher.resolvePointerSignalIntent(
      event: event,
      snapshot: _desktopInputSnapshot(),
      now: now,
    );
    if (intent.action == ReaderDesktopInputAction.none) {
      return;
    }
    if (intent.updateLastPageTurnAt) {
      _lastPointerScrollPageTurnAt = now;
    }
    _dispatchReaderDesktopInputAction(intent.action);
  }

  ReaderDesktopInputSnapshot _desktopInputSnapshot() {
    return ReaderDesktopInputSnapshot(
      textSelectionActive: _isTextSelectionActive,
      editingText: _isEditingBookmarkNote,
      readerBusy: _isBootstrapping || _isLoadingContent || _errorText != null,
      overlayVisible: _overlayController.showOverlayControls,
      autoReadSessionEnabled: _isAutoReadSessionEnabled,
      isPagedViewport:
          _currentViewportKind == ReaderModeViewportKind.textPaged ||
          _currentViewportKind == ReaderModeViewportKind.imagePaged,
      lastPageTurnAt: _lastPointerScrollPageTurnAt,
    );
  }

  KeyEventResult _dispatchReaderDesktopInputAction(
    ReaderDesktopInputAction action,
  ) {
    switch (action) {
      case ReaderDesktopInputAction.none:
        return KeyEventResult.ignored;
      case ReaderDesktopInputAction.toggleOverlay:
        if (_overlayController.showOverlayControls) {
          _hideOverlayControls(resumeAutoRead: true);
        } else {
          _setOverlayControlsVisibility(true);
        }
        return KeyEventResult.handled;
      case ReaderDesktopInputAction.pauseAutoRead:
        _pauseAutoReadSession();
        return KeyEventResult.handled;
      case ReaderDesktopInputAction.previousPage:
        unawaited(
          _dispatchReaderNavigationCommand(
            const ReaderNavigationCommand.previousPage(
              source: ReaderNavigationCommandSource.keyboard,
            ),
          ),
        );
        return KeyEventResult.handled;
      case ReaderDesktopInputAction.nextPage:
        unawaited(
          _dispatchReaderNavigationCommand(
            const ReaderNavigationCommand.nextPage(
              source: ReaderNavigationCommandSource.keyboard,
            ),
          ),
        );
        return KeyEventResult.handled;
      case ReaderDesktopInputAction.chapterStart:
        _restoreScrollPosition(0);
        return KeyEventResult.handled;
      case ReaderDesktopInputAction.chapterEnd:
        _restoreScrollPosition(1);
        return KeyEventResult.handled;
    }
  }
}

extension _ReaderTouchNavigationLayer on _ReaderPageState {
  void _onReaderTap(Offset localPosition, Size size, EdgeInsets gestureInsets) {
    final startIntent = _touchNavigationController.resolveTapStart(
      textSelectionActive: _isTextSelectionActive,
      initialInteractionCoolingDown: _isInitialReaderInteractionCoolingDown,
      backNavigationCoolingDown: _isBackNavigationInteractionCoolingDown,
      autoReadStatus: _touchAutoReadStatus,
      autoReadSessionEnabled: _isAutoReadSessionEnabled,
      autoReadTapGuardUntil: _autoReadTapGuardUntil,
      now: DateTime.now(),
      overlayVisible: _overlayController.showOverlayControls,
      tapEnabled: _settings.pageTurnMode.tapEnabled,
      usesScrollLayout: _settings.pageTurnMode.usesScrollLayout,
    );
    if (startIntent.type != ReaderTouchNavigationIntentType.resolveTapZone) {
      _dispatchReaderTouchNavigationIntent(startIntent);
      return;
    }

    final hit = _resolveTapZoneHit(
      localPosition: localPosition,
      size: size,
      gestureInsets: gestureInsets,
    );
    _dispatchReaderTouchNavigationIntent(
      _touchNavigationController.resolveTapZoneAction(hit?.action),
    );
  }

  ReaderTouchAutoReadStatus get _touchAutoReadStatus {
    return switch (_autoReadSessionState) {
      ReaderAutoReadSessionState.off => ReaderTouchAutoReadStatus.off,
      ReaderAutoReadSessionState.running => ReaderTouchAutoReadStatus.running,
      ReaderAutoReadSessionState.paused => ReaderTouchAutoReadStatus.paused,
      ReaderAutoReadSessionState.chapterPaused =>
        ReaderTouchAutoReadStatus.chapterPaused,
      ReaderAutoReadSessionState.finished => ReaderTouchAutoReadStatus.finished,
    };
  }

  void _dispatchReaderTouchNavigationIntent(
    ReaderTouchNavigationIntent intent,
  ) {
    _dispatchReaderInteractionCommand(
      _interactionCoordinator.resolveTouchIntent(intent),
    );
  }

  void _dispatchReaderInteractionCommand(ReaderInteractionCommand command) {
    switch (command.type) {
      case ReaderInteractionCommandType.ignore:
        return;
      case ReaderInteractionCommandType.showAutoReadControl:
        unawaited(_showAutoReadControlSheet());
        return;
      case ReaderInteractionCommandType.openAutoReadOverlay:
        unawaited(_openAutoReadFromOverlay());
        return;
      case ReaderInteractionCommandType.hideOverlay:
        _hideOverlayControls(resumeAutoRead: true);
        return;
      case ReaderInteractionCommandType.navigation:
        final navigationCommand = command.navigationCommand;
        if (navigationCommand != null) {
          unawaited(_dispatchReaderNavigationCommand(navigationCommand));
        }
        return;
      case ReaderInteractionCommandType.toggleToolbar:
        final nextShow = !_overlayController.showOverlayControls;
        _setOverlayControlsVisibility(nextShow);
        if (!nextShow) {
          _scheduleAutoReadResume();
        } else {
          _touchOverlayControls();
        }
        return;
      case ReaderInteractionCommandType.openCatalog:
        unawaited(_openCatalogSheetFromOverlay());
        return;
      case ReaderInteractionCommandType.openAutoRead:
        if (_supportsAutoRead) {
          unawaited(_openAutoReadFromOverlay());
        } else {
          _showMessage('当前内容暂不支持自动阅读');
        }
        return;
      case ReaderInteractionCommandType.openBookmarkCatalog:
        unawaited(_showCatalogSheet());
        return;
      case ReaderInteractionCommandType.toggleNightMode:
        unawaited(_toggleDayNightMode());
        return;
    }
  }

  ReaderTapZoneHit? _resolveTapZoneHit({
    required Offset localPosition,
    required Size size,
    required EdgeInsets gestureInsets,
  }) {
    final surfaceMetrics = _resolveReaderSurfaceMetrics(
      context,
      viewportSize: size,
      viewportKind: _currentViewportKind,
    );
    final tapZoneRect = _tapZoneResolver.resolveRect(
      viewportSize: size,
      contentRect: surfaceMetrics.contentRect,
      gestureInsets: gestureInsets,
    );
    return _tapZoneResolver.resolvePrimaryHit(
      localPosition: localPosition,
      rect: tapZoneRect,
    );
  }

  bool get _supportsFloatingToolbarOnLongPress {
    if (_isTextPagedViewport || _isTextScrollViewport) {
      return false;
    }
    if (_currentContentMode == ReaderContentMode.audio) {
      return false;
    }
    if (_isMangaViewport) {
      return false;
    }
    return _resolvedContentSession().hybridSubMode != ReaderHybridSubMode.pdf;
  }

  bool get _shouldHandleReaderLongPress =>
      _isMangaViewport || _supportsFloatingToolbarOnLongPress;

  Future<void> _handleReaderLongPress() async {
    if (_isAutoReadSessionEnabled) {
      if (_autoReadSessionState == ReaderAutoReadSessionState.running) {
        _pauseAutoReadSession();
      } else if (_autoReadSessionState == ReaderAutoReadSessionState.paused) {
        await _showSettingsSheet(
          initialTab: _ReaderSettingsTab.reading,
          initialSettingsGroupKey: 'auto_read',
        );
        return;
      }
    }
    if (_isMangaViewport) {
      await _openMangaPositionSheet();
      return;
    }
    if (_supportsFloatingToolbarOnLongPress) {
      _setOverlayControlsVisibility(true);
      _touchOverlayControls();
      return;
    }
    _hideOverlayControls(resumeAutoRead: false);
  }
}

// 阅读器拆分索引：
// 1. 路由入口保留在 reader_page.dart，初始参数归一化由 ReaderPageBootstrapController 承接。
// 2. 启动加载流程继续放在 reader_page_bootstrap.dart，后续只搬独立业务决策。
// 3. 应用生命周期、运行时暂停恢复放在 reader_page_lifecycle.dart 与 ReaderRuntimeLifecycleController。
// 4. 内容加载延迟 UI 决策放在 reader_page_content_loading.dart / runtime part 与 ReaderContentLoadController。
// 5. 阅读进度、分页签名和分页触发由 ReaderProgressCommitController / ReaderPaginationController 承接。
// 6. 壳层、设置、换源、选区、视口渲染继续由现有 part 文件隔离，避免再次塞回主文件。
class _ReaderPageState extends ConsumerState<ReaderPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _kBookmarkNoHighlightToken =
      ReaderBookmarkRangePresenter.defaultNoHighlightToken;
  static const String _kBookmarkDefaultHighlightToken = '__highlight__';

  late final ContentProviderRegistry _contentProviderRegistry;
  late final ReaderPreferencesService _preferencesService;
  late final ReaderVisualOverridesService _visualOverridesService;
  late final ReaderPlatformBridgeService _platformBridgeService;
  late final ReaderFontRegistryService _fontRegistryService;
  final ReaderTypographyResolver _typographyResolver =
      const ReaderTypographyResolver();
  final ReaderTypographyMetricsResolver _typographyMetricsResolver =
      const ReaderTypographyMetricsResolver();
  final ReaderAutoReadCoordinator _autoReadCoordinator =
      const ReaderAutoReadCoordinator();
  final ReaderCacheFeedbackResolver _readerCacheFeedbackResolver =
      const ReaderCacheFeedbackResolver();
  final ReaderContentLoadingController _contentLoadingController =
      const ReaderContentLoadingController();
  final ReaderContentLoadingPresenter _contentLoadingPresenter =
      const ReaderContentLoadingPresenter();
  final ReaderContentModeResolver _contentModeResolver =
      const ReaderContentModeResolver();
  final ReaderContentModeSurfaceController _contentModeSurfaceController =
      const ReaderContentModeSurfaceController();
  final ReaderPresentationResolver _presentationResolver =
      const ReaderPresentationResolver();
  final ReaderViewportBuilder _viewportBuilder = const ReaderViewportBuilder();
  final ReaderModeResolver _readerModeResolver = const ReaderModeResolver();
  final ReaderChapterCacheDecoder _chapterCacheDecoder =
      const ReaderChapterCacheDecoder();
  final ReaderChapterLoadPlanner _chapterLoadPlanner =
      const ReaderChapterLoadPlanner();
  final ReaderErrorPresenter _readerErrorPresenter =
      const ReaderErrorPresenter();
  final ReaderBookmarkRangePresenter _bookmarkRangePresenter =
      const ReaderBookmarkRangePresenter();
  final ReaderChromeActionPresenter _chromeActionPresenter =
      const ReaderChromeActionPresenter();
  final ReaderChapterFlow _chapterFlow = const ReaderChapterFlow();
  final ReaderChapterNavigation _chapterNavigation =
      const ReaderChapterNavigation();
  final ReaderNavigationCommandDispatcher _navigationCommandDispatcher =
      const ReaderNavigationCommandDispatcher();
  final ReaderChapterWindowController _chapterWindowController =
      const ReaderChapterWindowController();
  final ReaderPageBootstrapController _pageBootstrapController =
      const ReaderPageBootstrapController();
  final ReaderContentLoadController _contentLoadController =
      const ReaderContentLoadController();
  final ReaderJumpFacade _jumpFacade = const ReaderJumpFacade();
  final ReaderJumpPlanner _jumpPlanner = const ReaderJumpPlanner();
  final ReaderNavigationEntryResolver _navigationEntryResolver =
      const ReaderNavigationEntryResolver();
  final ReaderLayoutResolver _layoutResolver = const ReaderLayoutResolver();
  final ReaderPaginationEngine _paginationEngine =
      const ReaderPaginationEngine();
  final ReaderPaginationController _paginationController =
      const ReaderPaginationController();
  final ReaderStreamingPaginationController _streamingPaginationController =
      const ReaderStreamingPaginationController();
  final ReaderImageDecodeBudgetResolver _imageDecodeBudgetResolver =
      const ReaderImageDecodeBudgetResolver();
  final ReaderDeviceTierResolver _deviceTierResolver =
      const ReaderDeviceTierResolver();
  late final ReaderPaginationCacheService _paginationCacheService;
  final ReaderPaginationSpecResolver _paginationSpecResolver =
      const ReaderPaginationSpecResolver();
  final ReaderSurfacePolicyResolver _surfacePolicyResolver =
      const ReaderSurfacePolicyResolver();
  final PagedTransitionController _pagedTransitionLogic =
      const PagedTransitionController();
  final ReaderPagedViewportTransitionResolver _pagedViewportTransitionResolver =
      const ReaderPagedViewportTransitionResolver();
  final ReaderCatalogSearchService _catalogSearchService =
      const ReaderCatalogSearchService();
  final ReaderCatalogEntryController _catalogEntryController =
      const ReaderCatalogEntryController();
  final ReaderReadingRecordCoordinator _readingRecordCoordinator =
      const ReaderReadingRecordCoordinator();
  final ReaderRuntimeWakePolicy _runtimeWakePolicy =
      const ReaderRuntimeWakePolicy();
  final ReaderRuntimeLifecycleController _runtimeLifecycleController =
      const ReaderRuntimeLifecycleController();
  final ReaderFeedbackService _readerFeedbackService =
      const ReaderFeedbackService();
  final ReaderThemeModeService _readerThemeModeService =
      const ReaderThemeModeService();
  final ReaderRuntimeController _readerRuntimeController =
      const ReaderRuntimeController();
  final ReaderRuntimeFacade _readerRuntimeFacade = const ReaderRuntimeFacade();
  final ReaderPlatformFacade _readerPlatformFacade =
      const ReaderPlatformFacade();
  final ReaderSessionPresentationFacade _sessionPresentationFacade =
      const ReaderSessionPresentationFacade();
  final ReaderPageLifecycleDelegate _lifecycleDelegate =
      const ReaderPageLifecycleDelegate();
  final ReaderSettingsPresenter _readerSettingsPresenter =
      const ReaderSettingsPresenter();
  final ReaderSettingsResolutionService _readerSettingsResolutionService =
      const ReaderSettingsResolutionService();
  final ReaderSettingsEntryController _settingsEntryController =
      const ReaderSettingsEntryController();
  final ReaderSelectionController _selectionController =
      const ReaderSelectionController();
  final ReaderAnnotationPresenter _annotationPresenter =
      const ReaderAnnotationPresenter();
  final ReaderSelectionToolbarPresenter _selectionToolbarPresenter =
      const ReaderSelectionToolbarPresenter();
  final ReaderSelectionOverlayPolicy _selectionOverlayPolicy =
      const ReaderSelectionOverlayPolicy();
  final ReaderSessionStateResolver _sessionStateResolver =
      const ReaderSessionStateResolver();
  final ReaderDesktopInputDispatcher _desktopInputDispatcher =
      const ReaderDesktopInputDispatcher();
  final ReaderTouchNavigationController _touchNavigationController =
      const ReaderTouchNavigationController();
  final ReaderInteractionCoordinator _interactionCoordinator =
      const ReaderInteractionCoordinator();
  final ReaderPageTurnGate _pageTurnGate = const ReaderPageTurnGate();
  final ReaderPageTurnCoordinator _pageTurnCoordinator =
      const ReaderPageTurnCoordinator();
  final ReaderInteractionRuntimeController _interactionRuntimeController =
      ReaderInteractionRuntimeController();
  final ReaderOverlayController _overlayController = ReaderOverlayController();
  final ReaderPageTurnRuntimeController _pageTurnRuntimeController =
      ReaderPageTurnRuntimeController();
  late final ReaderSystemSettingsService _systemSettingsService;
  late final ReaderBackgroundService _readerBackgroundService;
  late final LocalBookStorageService _localBookStorageService;
  late final ReaderErrorCenterService _readerErrorCenterService;
  late final ReadingRecordService _readingRecordService;
  late final ImageSelectionService _imageSelectionService;
  late final BookshelfService _bookshelfService;
  late final MembershipAccessService _membershipAccessService;
  late final SearchService _switchSourceSearchService;
  late final SearchHitCacheService _searchHitCacheService;
  final SourceSwitchScoreService _switchSourceScoreService =
      SourceSwitchScoreService();
  final ReaderSourceSwitchController _sourceSwitchController =
      const ReaderSourceSwitchController();
  late final SourceHealthService _sourceHealthService;
  late final RemoteContentTaskConflictService _taskConflictService;
  late final RemoteContentTaskSchedulerService _taskScheduler;
  late final String _readerSessionScopeKey;
  late final ProviderContainer _readerSessionProviderContainer;
  final ReaderSourceSwitchCoordinator _sourceSwitchCoordinator =
      const ReaderSourceSwitchCoordinator();
  final ReaderSourceSwitchService _sourceSwitchService =
      const ReaderSourceSwitchService();
  final ReaderProgressCommitController _progressCommitController =
      const ReaderProgressCommitController();
  final ReaderSurfacePositionRuntime _surfacePositionRuntime =
      const ReaderSurfacePositionRuntime();
  final ScrollTextReaderRenderer _scrollTextRenderer =
      const ScrollTextReaderRenderer();
  final PagedTextReaderRenderer _pagedTextRenderer =
      const PagedTextReaderRenderer();
  late final ReaderSessionControllerNotifier _readerSessionController;
  final ReaderPreloadController _preloadController =
      const ReaderPreloadController();
  final ReaderPreloadFailureMemory _preloadFailureMemory =
      ReaderPreloadFailureMemory();
  late final ReaderResourceBudgetResolver _resourceBudgetResolver;
  late final AppLogger _logger;
  final ScrollController _scrollController = ScrollController();
  final PageController _mangaPageController = PageController();
  PageController? _staticPagedTextPageControllerInstance;
  final FocusNode _readerFocusNode = FocusNode(debugLabel: 'ReaderPage');
  final Set<String> _precachedInlineImageUrls = <String>{};
  final GlobalKey _readerBodyKey = GlobalKey();
  final GlobalKey _readerContentSnapshotKey = GlobalKey();
  final GlobalKey<ReaderPaperCurlPagedViewState> _paperCurlViewKey =
      GlobalKey<ReaderPaperCurlPagedViewState>();
  final GlobalKey<SelectionAreaState> _selectionAreaKey =
      GlobalKey<SelectionAreaState>();
  final SelectionListenerNotifier _selectionNotifier =
      SelectionListenerNotifier();
  final ReaderTapZoneResolver _tapZoneResolver = const ReaderTapZoneResolver();
  final ReaderPointerInputController _pointerInputController =
      ReaderPointerInputController();
  late final ReaderAudioController _readerAudioController;
  late final BookmarkRepository _bookmarkRepository;
  late final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  late final LocalBookRepository _localBookRepository;
  late final ReaderCachedChapterStore _cachedChapterStore;
  final BookDisplayStateResolver _bookMetadataPresentationResolver =
      const BookDisplayStateResolver();
  final Uuid _uuid = const Uuid();

  late String _chapterId;
  String? _chapterUrl;
  String? _chapterTitle;
  String? _sourceId;
  String? _detailUrl;
  String? _pendingBookmarkId;
  late String _activeBookId;

  String _bookTitle = '';
  String? _bookAuthor;
  String? _bookCoverUrl;
  String? _bookCustomCoverPath;

  ReaderSettings _settings = const ReaderSettings();
  ReaderSettings _persistedReaderSettings = const ReaderSettings();
  ReaderVisualOverrides _visualOverrides = ReaderVisualOverrides.empty;
  ThemeMode _appThemeMode = ThemeMode.system;
  AppAdvancedTheme? _activeAdvancedTheme;
  List<CoverGallery> _coverGalleries = const <CoverGallery>[];
  List<Chapter> _chapters = const [];
  bool _catalogComplete = false;
  int? _currentIndex;

  bool _isBootstrapping = true;
  bool _isLoadingContent = false;
  bool _isInBookshelf = false;
  bool _isCurrentChapterCached = false;
  bool _isShelfActionLoading = false;
  bool _isSwitchSourceLoading = false;
  bool _isAutoSwitchingSource = false;
  bool _autoSwitchSourceOnFailureEnabled = false;
  bool _readingRecordEnabled = true;
  bool _isScrollEdgeAdvancingChapter = false;
  SearchCancellationToken? _activeSwitchSourceCancellationToken;
  String? _errorText;
  AppExceptionDiagnostics? _contentFailureDiagnostics;
  ReaderFailurePresentation? _readerFailurePresentation;
  String? _readerGatewayFailureStage;
  ReaderDocument _document = ReaderDocument(blocks: const <ReaderBlock>[]);
  String _content = '';
  List<String> _paragraphs = const [];
  List<ReaderRenderBlockItem> _renderItems = const [];
  Map<int, ReaderRenderTextItem> _renderTextItemsByParagraph =
      const <int, ReaderRenderTextItem>{};
  String? _resolvedContentType;
  List<String> _chapterImageUrls = const [];
  Map<String, String> _chapterImageHeaders = const {};
  String? _chapterAudioUrl;
  String? _chapterAudioManifestUrl;
  Map<String, String> _chapterAudioHeaders = const {};
  String? _chapterExecutionContext;
  Duration _audioPlaybackPosition = Duration.zero;
  Duration _audioPlaybackDuration = Duration.zero;
  double _audioPlaybackSpeed = 1.0;
  String? _chapterSourceFilePath;
  int? _chapterTotalPageCount;
  int _imagePageIndex = 0;
  int _documentPageIndex = 0;
  int? _documentPageCount;
  double? _documentZoomScale;
  double? _documentPanDx;
  double? _documentPanDy;
  PdfViewerController? _pdfViewerController;
  bool _isEditingBookmarkNote = false;
  ReaderSelectionState _selectionState = const ReaderSelectionState();
  List<Bookmark> _chapterBookmarks = const [];
  Map<int, List<ReaderBookmarkRange>> _bookmarkRangesByParagraph =
      const <int, List<ReaderBookmarkRange>>{};
  List<ReaderCustomFontEntry> _customFonts = const [];
  final Map<String, int> _mangaImageRetryNonce = <String, int>{};
  ReadingProgress? _bootstrapProgress;
  Timer? _progressDebounceTimer;
  Timer? _autoReadResumeTimer;
  Timer? _autoReadPagedTimer;
  Timer? _overlayAutoHideTimer;
  Timer? _systemUiHideTimer;
  Timer? _readerInfoClockTimer;
  Timer? _chapterLoadingIndicatorTimer;
  Timer? _blockingLoadingCardTimer;
  Timer? _hiddenLoadingPlaceholderTimer;
  Timer? _readingRecordAutoCommitTimer;
  DateTime? _lastReaderSnackAt;
  String? _lastReaderSnackKey;
  StreamSubscription<ReaderVolumeKeyEvent>? _volumeKeyEventSubscription;
  ProviderSubscription<ThemeMode>? _appThemeModeSubscription;
  ProviderSubscription<AsyncValue<AppAdvancedTheme?>>?
  _activeAdvancedThemeSubscription;
  ProviderSubscription<AsyncValue<List<CoverGallery>>>?
  _coverGalleriesSubscription;
  late final Battery _battery;
  late final DeviceInfoPlugin _deviceInfo;
  DateTime _readerInfoNow = DateTime.now();
  DateTime? _lastReaderBatteryRefreshAt;
  DateTime? _lastProgressSavedAt;
  int? _readerBatteryLevel;
  bool _readerBatteryReadFailed = false;
  bool _isSystemBrightnessOverrideActive = false;
  Future<bool>? _iosSimulatorCheck;
  int _autoReadTaskToken = 0;
  int get _chapterContentRequestToken =>
      _readerSessionController.chapterContentGeneration;

  int get _preloadTaskToken => _readerSessionController.preloadGeneration;

  bool _isAutoReadRunning = false;
  bool _isAutoReadSessionEnabled = false;
  bool _isAutoReadPausedByRuntime = false;
  bool _isRestoringContinuousTextAnchor = false;
  int? _lastAutoReadContinuousSyncSkipLogToken;
  int? _lastAutoReadVisibleChapterIndex;
  DateTime? _lastAutoReadProgressUiRefreshAt;
  double? _autoReadDisplayProgressRatio;
  double? _autoReadRunStartOffset;
  double? _autoReadRunTargetOffset;
  double? _autoReadRunStartProgressRatio;
  DateTime? _autoReadTapGuardUntil;
  ReaderAutoReadSessionState _autoReadSessionState =
      ReaderAutoReadSessionState.off;
  bool _isReaderRuntimeVisible = true;
  bool _isAutoReadAdvancingChapter = false;
  bool _isAutoReadHandlingBoundary = false;
  bool _isScrollStepAnimating = false;
  ReaderScrollEdgeAdvanceState _scrollEdgeAdvanceState =
      const ReaderScrollEdgeAdvanceState();
  DateTime? _lastPointerScrollPageTurnAt;
  OverlayEntry? _bookmarkToolbarEntry;
  ReaderPageTurnMode _pageTurnModeBeforeAutoRead =
      ReaderPageTurnMode.tapAndSwipe;
  List<String> _customBackgroundImages = const [];
  List<int> _recentBodyTextColors = const [];
  String? _lightModeBackgroundImageBackup;
  final _ReaderBackgroundAssetStore _backgroundAssets =
      _ReaderBackgroundAssetStore();
  final ReaderLayoutReleasePolicy _layoutReleasePolicy =
      const ReaderLayoutReleasePolicy();
  final ReaderLayoutAnchorReadinessPolicy _layoutAnchorReadinessPolicy =
      const ReaderLayoutAnchorReadinessPolicy();
  final ReaderRendererAuthorityResolver _rendererAuthorityResolver =
      const ReaderRendererAuthorityResolver();
  final ReaderLayoutRendererController _layoutReleaseRendererController =
      ReaderLayoutRendererController();
  List<List<ReaderPagedSlice>> _pagedPages = const [];
  List<List<ReaderPagedBlock>> _pagedBlockPages = const [];
  String? _textPaginationFallbackDiagnostic;
  int? _layoutReleasePageCount;
  String? _layoutReleaseRequestSignature;
  String? _layoutReleaseDiagnostic;
  double _layoutReleaseTargetRatio = 0;
  int _layoutReleaseInitialPageIndex = 0;
  bool _layoutReleaseRendererActive = false;
  int get _paginationTaskId => _readerSessionController.paginationGeneration;
  ReaderPaginationSpec? _lastPaginationSpec;
  double? _measuredPinnedChapterHeaderWidth;
  bool _isSystemUiVisible = false;
  bool _isVolumeKeyPageInterceptionEnabled = false;
  late final AnimationController _overlayControlsController;
  late final AnimationController _pagedTransitionController;
  late final AnimationController _curlAutoTurnController;
  late final AnimationController _crossChapterSnapshotController;
  ReaderReadingRecordSession? _activeReadingRecordSession;
  String? _catalogSearchCacheFingerprint;
  Map<String, List<ReaderCatalogSearchEntry>> _catalogSearchEntriesCache =
      const <String, List<ReaderCatalogSearchEntry>>{};
  final Map<String, GlobalKey> _continuousTextChapterKeys =
      <String, GlobalKey>{};
  List<ReaderPageContinuousTextChapter> _continuousTextChapters =
      const <ReaderPageContinuousTextChapter>[];
  DateTime? _lastInlineImagePrecacheAt;
  bool _deferredBootstrapWarmupStarted = false;

  static const List<String> _kFallbackBackgroundPresetPaths = [
    'assets/reader/backgrounds/20260224-212555-700782.jpeg',
    'assets/reader/backgrounds/20260224-212555-b91cd8.jpeg',
    'assets/reader/backgrounds/20260224-212555-01b93d.jpeg',
    'assets/reader/backgrounds/Image_1768236174407.jpg',
  ];

  static const double _kPinnedHeaderTopPadding = 6;
  static const int _kCustomBackgroundPreviewMaxDimension = 480;
  static const int _kCustomBackgroundStoreMaxDimension = 1800;
  static const int _kCustomBackgroundStoreQuality = 82;
  static const double _kPinnedHeaderHeight = 40;
  static const double _kBottomProgressReserve = 12;
  static const double _kBottomOverlayReserve = 96;
  static const double _kMarginControlStep = 0.5;
  static const double _kSwipeTurnDistanceThreshold = 42;
  static const double _kSwipeTurnVelocityThreshold = 120;
  static const double _kPagedPullRefreshDistanceThreshold = 48;
  static const double _kSystemBackGestureGuardMin = 44;
  static const double _kSystemBackGestureGuardRatio = 0.06;
  static const Duration _kBackNavigationInteractionCooldown = Duration(
    milliseconds: 520,
  );
  static const double _kCurlPreviewStartThreshold = 8;
  static const double _kOverlayScrimMaxAlpha = 0.14;
  static const Duration _kOverlayControlsShowDuration = Duration(
    milliseconds: 220,
  );
  static const Duration _kOverlayControlsHideDuration = Duration(
    milliseconds: 180,
  );
  static const Duration _kOverlayControlsAutoHideDelay = Duration(seconds: 5);
  static const double _kShellOverlayTranslateDistance = 12;
  static const Duration _kCurlAutoTurnDuration = Duration(milliseconds: 760);
  static const Duration _kPagedScrollTurnDuration = Duration(milliseconds: 300);
  static const Duration _kMangaPagedTurnDuration = Duration(milliseconds: 320);
  static const Duration _kAutoReadMinimumScrollDuration = Duration(
    milliseconds: 260,
  );
  static const Duration _kAutoReadResumeDelay = Duration(milliseconds: 420);
  static const Duration _kAutoReadBoundaryResumeDelay = Duration(
    milliseconds: 360,
  );
  static const Duration _kInitialReaderInteractionCooldown = Duration(
    milliseconds: 320,
  );
  static const Duration _kChapterLoadingIndicatorDelay = Duration(
    milliseconds: 260,
  );
  static const Duration _kBlockingLoadingCardDelay = Duration(
    milliseconds: 320,
  );
  static const Duration _kHiddenLoadingPlaceholderDelay = Duration(
    milliseconds: 40,
  );
  static const Duration _kReaderSnackDuration = Duration(milliseconds: 1800);
  static const Duration _kReaderBoundarySnackDuration = Duration(
    milliseconds: 1200,
  );
  static const Duration _kReaderSnackActionDuration = Duration(
    milliseconds: 2600,
  );
  static const Duration _kReaderSnackDedupWindow = Duration(milliseconds: 900);
  static const int _kSwitchSourceCandidateLimit = 24;
  static const int _kSwitchSourceLagTolerance = 20;
  static const int _kSwitchSourceScoreStep = 6;
  static const int _kSwitchSourceHitCountCap = 12;
  static const int _kSwitchSourceHitCountWeight = 3;
  static const int _kAutoSwitchSourceTryLimit = 3;
  static const int _kForwardPreloadChapterCount = 2;
  static const int _kBackwardPreloadChapterCount = 1;
  static const int _kBookshelfForwardCacheChapterCount = 10;
  static const double _kScrollAdvanceOverscrollTrigger = 56;
  static const double _kScrollAdvanceEdgeTolerance = 2;
  static const double _kScrollAdvanceNearEdgeThreshold = 24;
  static const int _kScrollRefreshCurrentChapterAction = -2;

  bool get _isCurlAutoTurning =>
      _pageTurnRuntimeController.curlTransition.isAnimating;
  bool get _isCurlPreviewActive =>
      _pageTurnRuntimeController.curlTransition.isPreview;
  int get _curlAutoDirection =>
      _pageTurnRuntimeController.curlTransition.direction;
  int get _curlAnimationFromIndex =>
      _pageTurnRuntimeController.curlTransition.fromIndex;
  int get _curlAnimationToIndex =>
      _pageTurnRuntimeController.curlTransition.toIndex;
  double get _curlPreviewProgress =>
      _pageTurnRuntimeController.curlTransition.previewProgress;
  bool get _curlCommitOnAnimationEnd =>
      _pageTurnRuntimeController.curlTransition.commitOnAnimationEnd;
  bool get _isCurlCrossChapterTurn =>
      _pageTurnRuntimeController.curlTransition.isCrossChapter;
  bool get _isPagedTransitionAnimating =>
      _pageTurnRuntimeController.pagedTransition.isAnimating;
  bool get _shouldUseContinuousTextFlow => _isTextScrollViewport;
  int get _currentPagedPageCount => _currentRendererAuthority.pageCount;
  ReaderRendererAuthoritySnapshot get _currentRendererAuthority {
    return _rendererAuthorityResolver.resolve(
      releaseActive: _layoutReleaseRendererActive,
      releasePageCount: _layoutReleasePageCount,
      legacyTextPageCount: _pagedPages.length,
      legacyBlockPageCount: _pagedBlockPages.length,
      currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
      fallbackReason: _layoutReleaseDiagnostic,
    );
  }

  void _resetLayoutReleaseRuntime() {
    _layoutReleaseRendererActive = false;
    _layoutReleasePageCount = null;
    _layoutReleaseRequestSignature = null;
    _layoutReleaseDiagnostic = null;
    _layoutReleaseTargetRatio = 0;
    _layoutReleaseInitialPageIndex = 0;
    _layoutReleaseRendererController.cancelActive();
  }

  void _syncLayoutReleaseRequest(
    ReaderLayoutRequest request, {
    required double targetRatio,
    required int initialPageIndex,
  }) {
    if (_layoutReleaseRequestSignature == request.layoutSignature) {
      return;
    }
    _layoutReleaseRequestSignature = request.layoutSignature;
    _layoutReleaseRendererActive = true;
    _layoutReleasePageCount = null;
    _layoutReleaseDiagnostic = null;
    _layoutReleaseTargetRatio = targetRatio.clamp(0.0, 1.0).toDouble();
    _layoutReleaseInitialPageIndex = max(0, initialPageIndex);
  }

  PageController? _resolveStaticPagedTextPageController(int pageCount) {
    if (pageCount <= 0) {
      return null;
    }
    final safePage = _pageTurnRuntimeController.currentPageIndex.clamp(
      0,
      _safePageUpperBound(pageCount),
    );
    final controller = _staticPagedTextPageControllerInstance;
    if (controller == null) {
      _staticPagedTextPageControllerInstance = PageController(
        initialPage: safePage,
      );
      return _staticPagedTextPageControllerInstance;
    }
    if (!controller.hasClients && controller.initialPage != safePage) {
      controller.dispose();
      _staticPagedTextPageControllerInstance = PageController(
        initialPage: safePage,
      );
      return _staticPagedTextPageControllerInstance;
    }
    if (controller.hasClients) {
      final current = _readSingleAttachedPage(controller);
      if (current != safePage &&
          !_pageTurnRuntimeController.pagedTransition.isAnimating &&
          !_isCurlAutoTurning) {
        final syncGeneration =
            ++_pageTurnRuntimeController.pagedTextControllerSyncGeneration;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              syncGeneration !=
                  _pageTurnRuntimeController
                      .pagedTextControllerSyncGeneration ||
              _staticPagedTextPageControllerInstance != controller ||
              !controller.hasClients ||
              _pageTurnRuntimeController.pagedTransition.isAnimating ||
              _isCurlAutoTurning) {
            return;
          }
          final target = _pageTurnRuntimeController.currentPageIndex.clamp(
            0,
            _safePageUpperBound(_currentPagedPageCount),
          );
          final currentPage = _readSingleAttachedPage(controller);
          if (currentPage != target) {
            controller.jumpToPage(target);
          }
        });
      }
    }
    return controller;
  }

  int _readSingleAttachedPage(PageController controller) {
    if (!controller.hasClients || controller.positions.length != 1) {
      return controller.initialPage;
    }
    return controller.page?.round() ?? controller.initialPage;
  }

  TextAlign _paragraphTextAlign(ReaderSettings settings) {
    return settings.textFullJustifyEnabled
        ? TextAlign.justify
        : TextAlign.start;
  }

  ReaderModeModel _resolveReaderModeFor(
    ReaderSettings settings, {
    ReaderContentMode? contentMode,
    bool? canUsePagedText,
  }) {
    final effectiveContentMode = contentMode ?? _currentContentMode;
    final effectiveCanUsePagedText =
        canUsePagedText ??
        _sessionPresentationFacade
            .resolveModeCapabilities(
              contentMode: effectiveContentMode,
              contentCapabilities: _contentCapabilities,
              hasInlineImageParagraphs:
                  _currentChapterHasInlineImageParagraphs(),
            )
            .canUsePagedText;
    return _readerModeResolver.resolve(
      contentMode: effectiveContentMode,
      settings: settings,
      canUsePagedText: effectiveCanUsePagedText,
    );
  }

  ReaderModeModel get _currentReaderMode => _resolveReaderModeFor(_settings);

  List<int> _neighborPreloadContentIndexes({
    required String normalizedSourceId,
    required int currentIndex,
    required int chapterCount,
    required ReaderResourceBudget budget,
  }) {
    final preloadPlan = _preloadController.buildChapterPlan(
      currentChapterIndex: currentIndex,
      chapterCount: chapterCount,
      budget: budget,
      isLocalSource: LocalReaderIdentity.isLocalSourceId(normalizedSourceId),
      isInBookshelf: _isInBookshelf,
      maxForwardChapterCount: _kForwardPreloadChapterCount,
      maxBackwardChapterCount: _kBackwardPreloadChapterCount,
      bookshelfForwardChapterCount: _kBookshelfForwardCacheChapterCount,
      failureMemory: _preloadFailureMemory,
    );
    return preloadPlan
        .chapterIndexesFor(ReaderPreloadTaskType.content)
        .toList(growable: false);
  }

  ReaderResourceBudget _currentResourceBudget({
    ReaderWorkScene scene = ReaderWorkScene.foregroundReading,
  }) {
    final batteryTier =
        (_readerBatteryLevel != null && _readerBatteryLevel! <= 20)
            ? ReaderBatteryTier.lowBattery
            : ReaderBatteryTier.normal;
    return _resourceBudgetResolver.resolve(
      ReaderResourceBudgetInput(
        deviceTier: _deviceTierResolver.resolve(
          ReaderDeviceTierInput(
            platform: _currentReaderDevicePlatform(),
            batteryLevel: _readerBatteryLevel,
            scene: scene,
          ),
        ),
        batteryTier: batteryTier,
        networkTier: ReaderNetworkTier.unmetered,
        scene: scene,
      ),
    );
  }

  ReaderDevicePlatform _currentReaderDevicePlatform() {
    if (kIsWeb) {
      return ReaderDevicePlatform.web;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => ReaderDevicePlatform.android,
      TargetPlatform.iOS => ReaderDevicePlatform.ios,
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => ReaderDevicePlatform.desktop,
      _ => ReaderDevicePlatform.unknown,
    };
  }

  ReaderImageDecodeBudget _readerImageDecodeBudget({
    required ReaderImageDecodeRole role,
    required double logicalWidth,
    double? logicalHeight,
  }) {
    return _imageDecodeBudgetResolver.resolve(
      role: role,
      resourceBudget: _currentResourceBudget(),
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  void _scheduleInlineImagePrecache({int startIndex = 0, int limit = 4}) {
    if (!mounted || _renderItems.isEmpty) {
      return;
    }
    final safeStartIndex = max(0, startIndex);
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final decodeBudget = _readerImageDecodeBudget(
      role: ReaderImageDecodeRole.epubInline,
      logicalWidth: mediaWidth,
    );
    final imageUrls = _renderItems
        .whereType<ReaderRenderImageItem>()
        .skip(safeStartIndex)
        .map((item) => item.imageUrl)
        .where((url) => url.trim().isNotEmpty)
        .take(limit)
        .toList(growable: false);
    if (imageUrls.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      for (final imageUrl in imageUrls) {
        if (!_precachedInlineImageUrls.add(imageUrl)) {
          continue;
        }
        final provider = _readerImageProviderForPrecache(
          imageUrl,
          decodeBudget,
        );
        if (provider == null) {
          continue;
        }
        precacheImage(provider, context).ignore();
      }
    });
  }

  ImageProvider? _readerImageProviderForPrecache(
    String imageUrl,
    ReaderImageDecodeBudget decodeBudget,
  ) {
    if (imageUrl.startsWith('data:image/svg+xml') || _isSvgImageUrl(imageUrl)) {
      return null;
    }
    if (imageUrl.startsWith('data:image/')) {
      final decoded = _decodeDataUriImage(
        dataUri: imageUrl,
        maxBytes: decodeBudget.maxDataUriBytes,
      );
      if (decoded == null) {
        return null;
      }
      return ResizeImage.resizeIfNeeded(
        decodeBudget.cacheWidth,
        decodeBudget.cacheHeight,
        MemoryImage(decoded.bytes),
      );
    }
    final uri = Uri.tryParse(imageUrl);
    if (uri != null && uri.scheme == 'file') {
      final fileProvider = resolveLocalFileImageProvider(
        localFilePathFromUri(uri),
      );
      if (fileProvider == null) {
        return null;
      }
      return ResizeImage.resizeIfNeeded(
        decodeBudget.cacheWidth,
        decodeBudget.cacheHeight,
        fileProvider,
      );
    }
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return ResizeImage.resizeIfNeeded(
      decodeBudget.cacheWidth,
      decodeBudget.cacheHeight,
      NetworkImage(
        imageUrl,
        headers: _chapterImageHeaders.isEmpty ? null : _chapterImageHeaders,
      ),
    );
  }

  void _scheduleInlineImagePrecacheNearProgress({int limit = 6}) {
    final imageCount = _renderItems.whereType<ReaderRenderImageItem>().length;
    if (imageCount <= 0) {
      return;
    }
    final now = DateTime.now();
    final lastPrecacheAt = _lastInlineImagePrecacheAt;
    if (lastPrecacheAt != null &&
        now.difference(lastPrecacheAt) < const Duration(milliseconds: 650)) {
      return;
    }
    _lastInlineImagePrecacheAt = now;
    final progressIndex = (_currentScrollRatio() * imageCount).floor();
    _scheduleInlineImagePrecache(
      startIndex: max(0, progressIndex - 1),
      limit: limit,
    );
  }

  bool _isPagedTextReaderEnabledFor(ReaderSettings settings) {
    final mode = _resolveReaderModeFor(settings);
    return mode.isText && mode.isPaged;
  }

  bool _isPagedTextReaderEnabled() {
    return _isPagedTextReaderEnabledFor(_settings);
  }

  TextReaderRenderer get _activeTextRenderer =>
      _isPagedTextReaderEnabled() ? _pagedTextRenderer : _scrollTextRenderer;

  bool get _hasSingleAttachedScrollPosition =>
      _scrollController.hasClients && _scrollController.positions.length == 1;

  ReaderRenderMetrics _currentTextRenderMetrics() {
    if (_isPagedTextReaderEnabled()) {
      return ReaderRenderMetrics(
        pageCount: _currentPagedPageCount,
        currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
      );
    }
    return ReaderRenderMetrics(
      hasScrollClients: _hasSingleAttachedScrollPosition,
      maxScrollExtent:
          _hasSingleAttachedScrollPosition
              ? _scrollController.position.maxScrollExtent
              : 0,
      scrollOffset:
          _hasSingleAttachedScrollPosition
              ? _scrollController.position.pixels
              : 0,
    );
  }

  ReaderLogicalPosition? _currentLogicalPosition() {
    final chapterIndex = _currentIndex;
    if (chapterIndex == null) {
      return null;
    }
    final continuousChapter =
        _shouldUseContinuousTextFlow
            ? _findCurrentContinuousTextChapter()
            : null;
    return ReaderLogicalPosition.fromDocument(
      document: continuousChapter?.document ?? _document,
      chapterIndex: chapterIndex,
      chapterPositionRatio: _currentLogicalPositionRatio(),
      pageIndex:
          _isPagedTextReaderEnabled()
              ? _pageTurnRuntimeController.currentPageIndex
              : null,
    );
  }

  ReaderSessionState? _currentTextSessionState() {
    final viewportState = _currentViewportState();
    final logicalPosition = _currentLogicalPosition();
    return _sessionStateResolver.resolve(
      chapterIndex: _currentIndex,
      chapterId: _chapterId,
      chapterUrl: _chapterUrl,
      chapterTitle: _chapterTitle,
      logicalPosition: logicalPosition?.copyWith(
        pageIndex: viewportState.pageIndex,
        totalPageCount: viewportState.pageCount,
        viewportMode: viewportState.kind.name,
      ),
      rendererKind: _activeTextRenderer.kind,
      metrics: _currentTextRenderMetrics(),
      isAutoReading: _isAutoReadSessionEnabled,
      isChapterTransitioning: _isLoadingContent,
    );
  }

  ReaderContentSession? _currentContentSession() {
    final contentMode = _currentContentMode;
    final result = ChapterContentResult(
      content: _content,
      fromCache: _isCurrentChapterCached,
      imageUrls: _chapterImageUrls,
      imageHeaders: _chapterImageHeaders,
      contentType: _resolvedContentType,
      audioUrl: _chapterAudioUrl,
      audioManifestUrl: _chapterAudioManifestUrl,
      audioHeaders: _chapterAudioHeaders,
      executionContext: _chapterExecutionContext,
      document: _document,
    );
    return _sessionPresentationFacade.resolveContentSession(
      contentMode: contentMode,
      bookId: _activeBookId,
      sourceId: _sourceId,
      detailUrl: _detailUrl,
      bookTitle: _bookTitle,
      bookAuthor: _bookAuthor,
      bookCoverUrl: _bookCoverUrl,
      chapterId: _chapterId,
      chapterUrl: _chapterUrl,
      chapterTitle: _chapterTitle,
      chapterIndex: _currentIndex,
      resolvedContentType: _resolvedContentType,
      hybridSubMode: _contentModeResolver.resolveHybridSubMode(result),
      sourceFilePath: _resolveCurrentSourceFilePath(),
      totalPageCount: _resolveCurrentTotalPageCount(contentMode),
      audioUrl: _chapterAudioUrl,
      audioManifestUrl: _chapterAudioManifestUrl,
      audioHeaders: _chapterAudioHeaders,
      executionContext: _chapterExecutionContext,
      chapters: _chapters,
      sessionState:
          contentMode == ReaderContentMode.text
              ? _currentTextSessionState()
              : null,
      bootstrapProgress: _bootstrapProgressForCurrentChapter(),
      readingRecordSession: _activeReadingRecordSession,
    );
  }

  ReaderHybridSubMode? _currentHybridSubMode() {
    if (_currentContentMode != ReaderContentMode.hybrid) {
      return null;
    }
    return _contentModeResolver.resolveHybridSubMode(
      ChapterContentResult(
        content: _content,
        fromCache: _isCurrentChapterCached,
        imageUrls: _chapterImageUrls,
        imageHeaders: _chapterImageHeaders,
        contentType: _resolvedContentType,
        audioUrl: _chapterAudioUrl,
        audioManifestUrl: _chapterAudioManifestUrl,
        audioHeaders: _chapterAudioHeaders,
        executionContext: _chapterExecutionContext,
        document: _document,
      ),
    );
  }

  bool get _isCurrentHybridDocumentSurface {
    final subMode = _currentHybridSubMode();
    return subMode != ReaderHybridSubMode.pictureBook;
  }

  ReaderContentSession _resolvedContentSession() {
    final current = _currentContentSession();
    if (current != null) {
      return current;
    }
    final result = ChapterContentResult(
      content: _content,
      fromCache: _isCurrentChapterCached,
      imageUrls: _chapterImageUrls,
      imageHeaders: _chapterImageHeaders,
      contentType: _resolvedContentType,
      audioUrl: _chapterAudioUrl,
      audioManifestUrl: _chapterAudioManifestUrl,
      audioHeaders: _chapterAudioHeaders,
      executionContext: _chapterExecutionContext,
      document: _document,
    );
    return _presentationResolver.resolveContentSession(
      seed: ReaderSessionSeed(
        contentMode: _currentContentMode,
        bookId: _activeBookId,
        sourceId: _sourceId ?? '',
        detailUrl: _detailUrl ?? '',
        bookTitle: _bookTitle,
        bookAuthor: _bookAuthor,
        bookCoverUrl: _bookCoverUrl,
        chapterId: _chapterId,
        chapterUrl: _chapterUrl,
        chapterTitle: _chapterTitle,
        chapterIndex: _currentIndex,
        resolvedContentType: _resolvedContentType,
        hybridSubMode: _contentModeResolver.resolveHybridSubMode(result),
        sourceFilePath: _resolveCurrentSourceFilePath(),
        totalPageCount: _resolveCurrentTotalPageCount(_currentContentMode),
        audioUrl: _chapterAudioUrl,
        audioManifestUrl: _chapterAudioManifestUrl,
        audioHeaders: _chapterAudioHeaders,
        executionContext: _chapterExecutionContext,
        chapters: _chapters,
      ),
    );
  }

  ReaderPresentationPalette _presentationPalette(BuildContext context) {
    return ReaderPresentationPalette.fromColorScheme(
      Theme.of(context).colorScheme,
    );
  }

  String? _resolveCurrentSourceFilePath() {
    final chapterSourceFilePath = _chapterSourceFilePath?.trim();
    if (chapterSourceFilePath != null && chapterSourceFilePath.isNotEmpty) {
      return chapterSourceFilePath;
    }
    return null;
  }

  int? _resolveCurrentTotalPageCount(ReaderContentMode contentMode) {
    if (_chapterTotalPageCount != null && _chapterTotalPageCount! > 0) {
      return _chapterTotalPageCount;
    }
    switch (contentMode) {
      case ReaderContentMode.hybrid:
      case ReaderContentMode.comic:
        return _chapterImageUrls.isEmpty ? null : _chapterImageUrls.length;
      case ReaderContentMode.text:
      case ReaderContentMode.audio:
        return null;
    }
  }

  ReaderViewportState _currentViewportState() {
    final ratio = _currentScrollRatio();
    switch (_currentViewportKind) {
      case ReaderModeViewportKind.textPaged:
        return _sessionPresentationFacade.resolveViewportState(
          contentMode: _currentContentMode,
          mode: _currentReaderMode,
          chapterPositionRatio: ratio,
          pageIndex: _pageTurnRuntimeController.currentPageIndex,
          pageCount: _currentPagedPageCount,
        );
      case ReaderModeViewportKind.imagePaged:
        return _sessionPresentationFacade.resolveViewportState(
          contentMode: _currentContentMode,
          mode: _currentReaderMode,
          chapterPositionRatio: ratio,
          pageIndex: _imagePageIndex,
          pageCount: _chapterImageUrls.length,
        );
      case ReaderModeViewportKind.hybridPaged:
        return _sessionPresentationFacade.resolveViewportState(
          contentMode: _currentContentMode,
          mode: _currentReaderMode,
          chapterPositionRatio: ratio,
          pageIndex:
              _isCurrentHybridDocumentSurface
                  ? _documentPageIndex
                  : _imagePageIndex,
          pageCount:
              _isCurrentHybridDocumentSurface
                  ? (_documentPageCount ?? _chapterTotalPageCount)
                  : _chapterImageUrls.length,
          zoomScale:
              _isCurrentHybridDocumentSurface ? _documentZoomScale : null,
          panDx: _isCurrentHybridDocumentSurface ? _documentPanDx : null,
          panDy: _isCurrentHybridDocumentSurface ? _documentPanDy : null,
        );
      case ReaderModeViewportKind.textScroll:
      case ReaderModeViewportKind.imageScroll:
        return _sessionPresentationFacade.resolveViewportState(
          contentMode: _currentContentMode,
          mode: _currentReaderMode,
          chapterPositionRatio: ratio,
          scrollOffset:
              _scrollController.hasClients ? _scrollController.offset : 0,
          maxScrollExtent:
              _scrollController.hasClients
                  ? _scrollController.position.maxScrollExtent
                  : 0,
        );
      case ReaderModeViewportKind.audio:
        return _sessionPresentationFacade.resolveViewportState(
          contentMode: _currentContentMode,
          mode: _currentReaderMode,
          chapterPositionRatio: ratio,
          audioPositionMs: _audioPlaybackPosition.inMilliseconds,
          audioDurationMs: _audioPlaybackDuration.inMilliseconds,
          audioSpeed: _audioPlaybackSpeed,
        );
    }
  }

  ReaderPresentationViewportKind get _presentationViewportKind {
    return switch (_currentViewportKind) {
      ReaderModeViewportKind.textPaged =>
        ReaderPresentationViewportKind.textPaged,
      ReaderModeViewportKind.textScroll =>
        ReaderPresentationViewportKind.textScroll,
      ReaderModeViewportKind.imagePaged =>
        ReaderPresentationViewportKind.mangaPaged,
      ReaderModeViewportKind.imageScroll =>
        ReaderPresentationViewportKind.mangaContinuous,
      ReaderModeViewportKind.hybridPaged =>
        ReaderPresentationViewportKind.mangaPaged,
      ReaderModeViewportKind.audio => ReaderPresentationViewportKind.textScroll,
    };
  }

  ReadingProgress? _bootstrapProgressForCurrentChapter({bool consume = false}) {
    final progress = _bootstrapProgress;
    if (progress == null) {
      return null;
    }

    final currentChapterId = _chapterId.trim();
    final currentChapterUrl = (_chapterUrl ?? '').trim();
    final matchesChapter =
        progress.chapterId == currentChapterId ||
        progress.chapterUrl == currentChapterUrl;
    if (!matchesChapter) {
      return null;
    }

    if (consume) {
      _bootstrapProgress = null;
    }
    return progress;
  }

  double _resolveDocumentRestoreRatio({
    ReaderDocument? document,
    ReaderLogicalPosition? logicalPosition,
    ReadingProgress? progress,
    double fallback = 0,
  }) {
    final effectiveDocument = document ?? _document;
    final effectivePosition = logicalPosition ?? progress?.logicalPosition;
    if (effectivePosition != null && !effectiveDocument.isEmpty) {
      return effectivePosition.approximateRatio(effectiveDocument);
    }

    final ratio = progress?.chapterPositionRatio ?? fallback;
    return ratio.clamp(0.0, 1.0);
  }

  void _restoreTextPositionFromLogicalAnchor({
    required bool previousPagedTextEnabled,
    required ReaderLogicalPosition? logicalAnchor,
    required double fallbackRatio,
  }) {
    final nextPagedTextEnabled = _isPagedTextReaderEnabled();
    if (previousPagedTextEnabled == nextPagedTextEnabled) {
      return;
    }

    final anchorRatio = _resolveDocumentRestoreRatio(
      logicalPosition: logicalAnchor,
      fallback: fallbackRatio,
    );
    if (nextPagedTextEnabled) {
      _pageTurnRuntimeController
          .pagedPaginationState = _pageTurnRuntimeController
          .pagedPaginationState
          .copyWith(pendingRestoreRatio: anchorRatio);
    } else if (_restoreContinuousTextAnchorPosition(anchorRatio)) {
      _scheduleProgressSave();
      return;
    }
    _restoreScrollPosition(anchorRatio);
    _scheduleProgressSave();
  }

  bool _restoreContinuousTextAnchorPosition(double chapterRatio) {
    if (!_shouldUseContinuousTextFlow || _continuousTextChapters.isEmpty) {
      return false;
    }
    final currentIndex = _currentIndex;
    if (currentIndex == null) {
      return false;
    }
    final chapter =
        _continuousTextChapters
            .where((item) => item.chapterIndex == currentIndex)
            .firstOrNull;
    if (chapter == null) {
      return false;
    }

    final normalized = chapterRatio.clamp(0.0, 1.0);
    _isRestoringContinuousTextAnchor = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreContinuousTextAnchorPositionAfterLayout(
        chapter: chapter,
        ratio: normalized,
        attempt: 0,
      );
    });
    return true;
  }

  void _restoreContinuousTextAnchorPositionAfterLayout({
    required ReaderPageContinuousTextChapter chapter,
    required double ratio,
    required int attempt,
  }) {
    if (!mounted || !_scrollController.hasClients) {
      _isRestoringContinuousTextAnchor = false;
      return;
    }

    final layout = _measureContinuousTextChapterLayoutFlow(chapter);
    if (layout == null) {
      if (attempt < 3) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreContinuousTextAnchorPositionAfterLayout(
            chapter: chapter,
            ratio: ratio,
            attempt: attempt + 1,
          );
        });
        return;
      }
      _isRestoringContinuousTextAnchor = false;
      _logger.info(
        'Reader continuous anchor restore fallback',
        context: <String, Object?>{
          'chain': 'reader_auto_read',
          'step': 'continuous_anchor_restore_fallback',
          'chapterId': chapter.chapterId,
          'activeChapterId': _chapterId,
          'ratio': ratio.toStringAsFixed(3),
          'attempt': attempt,
        },
      );
      _restoreScrollPosition(ratio);
      return;
    }

    final position = _scrollController.position;
    final viewportExtent = position.viewportDimension;
    final available = (layout.endOffset - layout.startOffset - viewportExtent)
        .clamp(0.0, double.infinity);
    final target = (layout.startOffset + available * ratio).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - target).abs() > 0.5) {
      position.jumpTo(target);
    }
    _isRestoringContinuousTextAnchor = false;
    _logger.info(
      'Reader continuous anchor restored',
      context: <String, Object?>{
        'chain': 'reader_auto_read',
        'step': 'continuous_anchor_restored',
        'chapterId': chapter.chapterId,
        'activeChapterId': _chapterId,
        'ratio': ratio.toStringAsFixed(3),
        'startOffset': layout.startOffset.toStringAsFixed(1),
        'endOffset': layout.endOffset.toStringAsFixed(1),
        'targetOffset': target.toStringAsFixed(1),
      },
    );
    if (_isAutoReadSessionEnabled &&
        _autoReadSessionState == ReaderAutoReadSessionState.running) {
      _reconcileAutoRead(restart: true);
    }
  }

  bool _isSwipePaginationEnabled() {
    return _currentReaderMode.viewportKind ==
            ReaderModeViewportKind.textPaged &&
        _currentReaderMode.swipeTurnEnabled &&
        !_usesPaperCurlAnimation;
  }

  bool get _isMixedMediaTextDocument =>
      _document.hasImageBlocks && !_document.isPureImageDocument;

  bool _shouldUseCurlGesturePreview() {
    return _isSwipePaginationEnabled() &&
        _currentPagedAnimationStyle() == ReaderPageAnimationStyle.curl &&
        !_isMixedMediaTextDocument;
  }

  ReaderContentMode get _currentContentMode {
    return _contentModeResolver.resolveFromChapterResult(
      ChapterContentResult(
        content: _content,
        fromCache: _isCurrentChapterCached,
        imageUrls: _chapterImageUrls,
        imageHeaders: _chapterImageHeaders,
        contentType: _resolvedContentType,
        audioUrl: _chapterAudioUrl,
        audioManifestUrl: _chapterAudioManifestUrl,
        audioHeaders: _chapterAudioHeaders,
        document: _document,
      ),
    );
  }

  bool get _isMangaChapter => _currentContentMode == ReaderContentMode.comic;

  bool get _isMangaPagedMode {
    if (!_isMangaChapter) {
      return false;
    }
    return _settings.mangaReadMode != ReaderMangaReadMode.continuous;
  }

  ReaderModeViewportKind get _currentViewportKind {
    final resolved = _currentReaderMode.viewportKind;
    if (resolved == ReaderModeViewportKind.textPaged &&
        _textPaginationFallbackDiagnostic != null) {
      return ReaderModeViewportKind.textScroll;
    }
    return resolved;
  }

  bool get _isTextPagedViewport =>
      _currentViewportKind == ReaderModeViewportKind.textPaged;

  bool get _isTextScrollViewport =>
      _currentViewportKind == ReaderModeViewportKind.textScroll;

  bool get _isMangaViewport =>
      _currentViewportKind == ReaderModeViewportKind.imagePaged ||
      _currentViewportKind == ReaderModeViewportKind.imageScroll;

  ReaderContentModeSurfaceModel get _currentContentModeSurfaceModel {
    return _contentModeSurfaceController.buildModel(
      mode: _currentContentMode,
      isTextPagedViewport: _isTextPagedViewport,
      isTextScrollViewport: _isTextScrollViewport,
    );
  }

  ReaderModeCapabilities get _readerModeCapabilities =>
      _sessionPresentationFacade.resolveModeCapabilities(
        contentMode: _currentContentMode,
        contentCapabilities: _contentCapabilities,
        hasInlineImageParagraphs: _currentChapterHasInlineImageParagraphs(),
      );

  bool get _supportsAutoRead => _readerModeCapabilities.canAutoRead;

  bool get _isTextSelectionActive => _selectionState.isActive;
  set _isTextSelectionActive(bool value) {
    _selectionState = _selectionState.copyWith(isActive: value);
  }

  SelectedContentRange? get _selectionRange => _selectionState.range;
  set _selectionRange(SelectedContentRange? value) {
    _selectionState = _selectionState.copyWith(range: value);
  }

  SelectionStatus get _selectionStatus => _selectionState.status;
  set _selectionStatus(SelectionStatus value) {
    _selectionState = _selectionState.copyWith(status: value);
  }

  int get _selectionStartOffset => _selectionState.startOffset;
  set _selectionStartOffset(int value) {
    _selectionState = _selectionState.copyWith(startOffset: value);
  }

  int get _selectionEndOffset => _selectionState.endOffset;
  set _selectionEndOffset(int value) {
    _selectionState = _selectionState.copyWith(endOffset: value);
  }

  String get _selectedSnippet => _selectionState.snippet;
  set _selectedSnippet(String value) {
    _selectionState = _selectionState.copyWith(snippet: value);
  }

  bool get _selectionHighlight => _selectionState.highlight;
  set _selectionHighlight(bool value) {
    _selectionState = _selectionState.copyWith(highlight: value);
  }

  bool get _selectionBold => _selectionState.bold;
  set _selectionBold(bool value) {
    _selectionState = _selectionState.copyWith(bold: value);
  }

  bool get _selectionUnderline => _selectionState.underline;
  set _selectionUnderline(bool value) {
    _selectionState = _selectionState.copyWith(underline: value);
  }

  bool get _selectionWavy => _selectionState.wavy;
  set _selectionWavy(bool value) {
    _selectionState = _selectionState.copyWith(wavy: value);
  }

  bool _showsOuterPinnedChapterHeaderFor(ReaderModeViewportKind viewportKind) {
    return viewportKind != ReaderModeViewportKind.textPaged &&
        _layoutResolver.showsPinnedChapterHeader(_settings);
  }

  bool _showsPagedPinnedChapterHeaderFor(ReaderModeViewportKind viewportKind) {
    return viewportKind == ReaderModeViewportKind.textPaged &&
        _layoutResolver.showsPinnedChapterHeader(_settings);
  }

  bool _showsOuterInfoBarsFor(ReaderModeViewportKind viewportKind) {
    return viewportKind == ReaderModeViewportKind.textScroll;
  }

  bool _showsPagedHeaderInfoBarFor(ReaderModeViewportKind viewportKind) {
    return false;
  }

  bool get _hasReaderInfoItems =>
      _settings.infoShowProgress ||
      _settings.infoShowTime ||
      _settings.infoShowBattery ||
      _settings.infoShowChapter;

  bool _showsOuterFooterInfoBarFor(ReaderModeViewportKind viewportKind) {
    return _showsOuterInfoBarsFor(viewportKind) && _settings.infoFooterEnabled;
  }

  bool _reservesPinnedHeaderSpaceFor(ReaderModeViewportKind viewportKind) {
    return _showsOuterPinnedChapterHeaderFor(viewportKind) ||
        _showsPagedPinnedChapterHeaderFor(viewportKind);
  }

  bool get _showsPinnedChapterHeader =>
      _showsOuterPinnedChapterHeaderFor(_currentViewportKind);

  bool get _showsReaderFooterInfoBar =>
      _showsOuterFooterInfoBarFor(_currentViewportKind);

  bool get _hasVisibleReaderContent =>
      _content.trim().isNotEmpty ||
      !_document.isEmpty ||
      (_chapterAudioUrl?.trim().isNotEmpty ?? false) ||
      (_chapterAudioManifestUrl?.trim().isNotEmpty ?? false);

  bool get _needsBlockingLoadingUi {
    if (_isBootstrapping && !_hasVisibleReaderContent) {
      return true;
    }
    if (_isSwitchSourceLoading) {
      return true;
    }
    if (_isLoadingContent && !_hasVisibleReaderContent) {
      return true;
    }
    return false;
  }

  bool get _shouldShowBlockingReaderLoading {
    return _overlayController.showBlockingLoadingCard &&
        _needsBlockingLoadingUi;
  }

  bool get _supportsChapterPullToRefresh {
    return _errorText != null || !_hasVisibleReaderContent;
  }

  Future<void> _reloadCurrentChapterFromPullToRefresh() async {
    if (_isBootstrapping || _isLoadingContent || _isSwitchSourceLoading) {
      return;
    }
    final initialScrollRatio =
        _hasVisibleReaderContent ? _currentScrollRatio() : null;
    await _loadCurrentChapter(initialScrollRatio: initialScrollRatio);
  }

  void _resetScrollEdgeAdvanceState() {
    _scrollEdgeAdvanceState = const ReaderScrollEdgeAdvanceState();
  }

  void _updateScrollEdgeAdvanceState({
    double? overscrollDistance,
    bool? isArmed,
    int? actionDirection,
  }) {
    _scrollEdgeAdvanceState = _scrollEdgeAdvanceState.copyWith(
      overscrollDistance: overscrollDistance,
      isArmed: isArmed,
      actionDirection: actionDirection,
    );
  }

  double get _overlayControlsShiftProgress =>
      Curves.easeOutCubic.transform(_overlayControlsController.value);

  double get _overlayControlsFadeProgress =>
      Curves.easeOut.transform(_overlayControlsController.value);

  double _topSafeInset(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context).top;
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context).top;
    return max(viewPadding, gestureInsets);
  }

  double _bottomSafeInset(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context).bottom;
    return max(viewPadding, gestureInsets);
  }

  double _effectiveBottomSafeInset(BuildContext context) {
    final rawInset = _bottomSafeInset(context);
    final platform = Theme.of(context).platform;
    final minInset = platform == TargetPlatform.iOS ? 14.0 : 0.0;
    return max(rawInset, minInset);
  }

  EdgeInsets _readerSafeInsets(BuildContext context) {
    return EdgeInsets.only(
      top: _topSafeInset(context),
      bottom: _effectiveBottomSafeInset(context),
    );
  }

  int _safePageUpperBound(int pageCount) {
    return max(0, pageCount - 1);
  }

  double _pinnedHeaderTotalHeight(BuildContext context) {
    return _topSafeInset(context) +
        _kPinnedHeaderTopPadding +
        _layoutResolver.resolveChapterHeaderTopSpacing(_settings) +
        _kPinnedHeaderHeight +
        _layoutResolver.resolveChapterHeaderBottomSpacing(_settings);
  }

  ReaderSurfaceReserves _resolveReaderSurfaceReserves(
    BuildContext context, {
    ReaderModeViewportKind? viewportKind,
  }) {
    final effectiveViewportKind = viewportKind ?? _currentViewportKind;
    final footerPadding = _layoutResolver.resolveInfoBarPadding(
      _settings,
      isHeader: false,
    );
    final headerPadding = _layoutResolver.resolveInfoBarPadding(
      _settings,
      isHeader: true,
    );
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final fontSize = max(11.5, textStyle?.fontSize ?? 11.5);
    final lineHeightFactor = textStyle?.height ?? 1.2;
    final policy = _surfacePolicyResolver.resolve(
      showsReaderFooterInfoBar: _showsOuterFooterInfoBarFor(
        effectiveViewportKind,
      ),
      showsPagedHeaderInfoBar: _showsPagedHeaderInfoBarFor(
        effectiveViewportKind,
      ),
      hasPagedInfoOverlay: _hasPagedInfoOverlay(),
      effectiveBottomSafeInset: _effectiveBottomSafeInset(context),
      bottomProgressReserve: _kBottomProgressReserve,
      bottomOverlayReserve: _kBottomOverlayReserve,
      headerMarginTop: headerPadding.top,
      headerMarginBottom: headerPadding.bottom,
      footerMarginTop: footerPadding.top,
      footerMarginBottom: footerPadding.bottom,
      infoHeaderPadding:
          _settings.infoHeaderPadding
              .clamp(
                ReaderSettings.minInfoBarPadding,
                ReaderSettings.maxInfoBarPadding,
              )
              .toDouble(),
      infoFooterPadding:
          _settings.infoFooterPadding
              .clamp(
                ReaderSettings.minInfoBarPadding,
                ReaderSettings.maxInfoBarPadding,
              )
              .toDouble(),
      headerFontSize: fontSize,
      headerLineHeightFactor: lineHeightFactor,
      footerFontSize: fontSize,
      footerLineHeightFactor: lineHeightFactor,
    );
    return ReaderSurfaceReserves(
      scrollBottomReserve: policy.scrollBottomReserve,
      pagedHeaderReserve: policy.pagedHeaderReserve,
      pagedBottomReserve: policy.pagedBottomReserve,
    );
  }

  ReaderSurfaceMetrics _resolveReaderSurfaceMetrics(
    BuildContext context, {
    ReaderModeViewportKind? viewportKind,
    Size? viewportSize,
    double? scrollBottomReserve,
    double? pagedBottomReserve,
  }) {
    final effectiveViewportKind = viewportKind ?? _currentViewportKind;
    final reserves = _resolveReaderSurfaceReserves(
      context,
      viewportKind: effectiveViewportKind,
    );
    return _layoutResolver.resolveSurfaceMetrics(
      settings: _settings,
      viewportSize: viewportSize ?? AppLayout.viewportSize(context),
      safeInsets: _readerSafeInsets(context),
      pinnedHeaderHeight:
          _reservesPinnedHeaderSpaceFor(effectiveViewportKind)
              ? _pinnedHeaderTotalHeight(context)
              : 0,
      pagedHeaderReserve: reserves.pagedHeaderReserve,
      scrollBottomReserve: scrollBottomReserve ?? reserves.scrollBottomReserve,
      pagedBottomReserve: pagedBottomReserve ?? reserves.pagedBottomReserve,
      maxContentWidth:
          ReaderLayoutContext.resolve(
            context,
            viewportKind: effectiveViewportKind,
          ).contentMaxWidth,
    );
  }

  Widget _buildFloatingReaderSettingsSheet({
    required BuildContext context,
    required ThemeData readerModalTheme,
    required double keyboardInset,
    required double safeBottom,
    required double sheetHorizontal,
    required double maxWidth,
    required double heightFactor,
    Color? backgroundColor,
    required Widget child,
  }) => buildReaderFloatingSettingsSheet(
    context: context,
    readerModalTheme: readerModalTheme,
    viewportKind: _currentViewportKind,
    keyboardInset: keyboardInset,
    safeBottom: safeBottom,
    sheetHorizontal: sheetHorizontal,
    maxWidth: maxWidth,
    heightFactor: heightFactor,
    backgroundColor: backgroundColor,
    child: child,
  );

  ReaderSurfaceMetrics _resolvePagedLayoutMetrics(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    return _resolveReaderSurfaceMetrics(
      context,
      viewportSize: constraints.biggest,
    );
  }

  ReaderPaginationSpec _resolvePaginationSpec({
    required ReaderSurfaceMetrics surfaceMetrics,
  }) {
    return _paginationSpecResolver.resolve(
      settings: _settings,
      surfaceMetrics: surfaceMetrics,
    );
  }

  bool _hasPagedInfoOverlay() {
    return _settings.infoFooterEnabled && _hasReaderInfoItems;
  }

  String _formatLayoutMarginValue(double value) =>
      _readerSettingsPresenter.layoutMarginValueLabel(value);

  void _bindDependencies() => _bindReaderDependencies();

  @override
  void initState() {
    super.initState();
    _readerSessionScopeKey =
        '${widget.bookId}|${widget.chapterId}|${widget.sourceId ?? ''}|'
        '${widget.openRouteKind ?? ''}|${widget.openRequestedAtMs ?? 0}';
    _readerSessionProviderContainer = ProviderScope.containerOf(
      context,
      listen: false,
    );
    _readerSessionController = ref.read(
      readerSessionControllerProvider(_readerSessionScopeKey).notifier,
    );
    _initializeReaderPage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyReaderImageCacheBudget();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _handlePlatformBrightnessChange();
  }

  @override
  void dispose() {
    _disposeReaderPage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildReaderPageScaffold(context);

  double _readerBrightnessOverlayAlpha() {
    if (_settings.followSystemBrightness || _isSystemBrightnessOverrideActive) {
      return 0;
    }
    final alpha = (1 - _settings.brightness) * 0.6;
    final hasBackgroundImage =
        _settings.backgroundImageBase64?.trim().isNotEmpty ?? false;
    if (!hasBackgroundImage) {
      return alpha;
    }
    // Keep dimming available, but don't let it flatten background images.
    return alpha * 0.18;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _handleReaderAppLifecycleState(state);

  Future<void> _applySystemReaderBrightness([double? brightness]) =>
      _applySystemReaderBrightnessImpl(brightness);

  Future<void> _restoreSystemReaderBrightness() =>
      _restoreSystemReaderBrightnessImpl();

  void _updateReaderState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  Decoration _buildReaderBackgroundDecoration(ReaderThemeColors colors) =>
      _buildReaderBackgroundDecorationImpl(colors);

  bool _isPresetBackgroundValue(String? value) =>
      _isPresetBackgroundValueImpl(value);

  Future<void> _preloadCustomBackgroundPreviews(List<String> sources) =>
      _preloadCustomBackgroundPreviewsImpl(sources);

  Future<String?> _storeCustomBackgroundImage(Uint8List bytes) =>
      _storeCustomBackgroundImageImpl(bytes);

  Future<void> _deleteManagedBackgroundFileIfNeeded(String source) =>
      _deleteManagedBackgroundFileIfNeededImpl(source);

  Future<List<String>> _loadUnifiedCustomBackgrounds() =>
      _loadUnifiedCustomBackgroundsImpl();

  Future<void> _refreshSharedReaderAssets({
    void Function(VoidCallback fn)? updateModalState,
  }) => _refreshSharedReaderAssetsImpl(updateModalState: updateModalState);

  Widget _buildReaderContent(ReaderThemeColors colors) {
    final hasRenderableContent =
        _content.trim().isNotEmpty ||
        _chapterImageUrls.isNotEmpty ||
        (_chapterAudioUrl?.trim().isNotEmpty ?? false) ||
        (_chapterAudioManifestUrl?.trim().isNotEmpty ?? false);
    final content = AppAnimatedSwitcher(
      duration: AppMotion.fast,
      layoutBuilder: (currentChild, previousChildren) {
        return currentChild ?? const SizedBox.shrink();
      },
      child: KeyedSubtree(
        key: ValueKey<String>(
          'reader_content_${_chapterId}_$hasRenderableContent',
        ),
        child: _composeReaderContent(colors),
      ),
    );
    final transition =
        _pageTurnRuntimeController.crossChapterSnapshotTransition;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _readerContentSnapshotKey, child: content),
        if (transition.isActive)
          ReaderFullScreenHitTestLayer(
            strategy: ReaderFullScreenHitTestStrategy.passThrough,
            child: ReaderCrossChapterSnapshotOverlay(
              key: ValueKey<int>(transition.generation),
              fromImage: transition.fromImage!,
              toImage: transition.toImage,
              style: transition.style,
              direction: transition.direction,
              animation: _crossChapterSnapshotController,
              generation: transition.generation,
              curlColors: CurlRendererColors(
                backgroundColor: colors.background,
                dividerColor: colors.divider,
                overlayColor: colors.overlay,
              ),
              onPaperCurlCompleted: _completeCrossChapterSnapshotAnimation,
            ),
          ),
      ],
    );
  }

  ReaderChromePalette _chromePalette(ReaderThemeColors colors) {
    return ReaderChromePalette(
      background: colors.background,
      text: colors.text,
      meta: colors.meta,
      divider: colors.divider,
      overlay: colors.overlay,
    );
  }

  Widget _buildPinnedChapterHeader(ReaderThemeColors colors) {
    final chapterTitle =
        _chapterTitle?.isNotEmpty == true ? _chapterTitle! : '未命名章节';
    return ReaderPinnedChapterHeader(
      model: ReaderPinnedChapterHeaderModel(
        title: chapterTitle,
        mode:
            _settings.showChapterHeader
                ? ReaderChapterHeaderMode.start
                : ReaderChapterHeaderMode.hidden,
        horizontalProgress: _settings.chapterHeaderHorizontalOffset,
        topSafeInset: _topSafeInset(context),
        topPadding:
            _kPinnedHeaderTopPadding +
            _layoutResolver.resolveChapterHeaderTopSpacing(_settings),
        bottomSpacing: _layoutResolver.resolveChapterHeaderBottomSpacing(
          _settings,
        ),
        height: _kPinnedHeaderHeight,
        measuredWidth: _measuredPinnedChapterHeaderWidth,
      ),
      palette: _chromePalette(colors),
      onBackPressed: _handleBackNavigation,
      onMeasuredWidthChanged: (nextWidth) {
        final currentWidth = _measuredPinnedChapterHeaderWidth;
        if (currentWidth != null && (currentWidth - nextWidth).abs() < 0.5) {
          return;
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _measuredPinnedChapterHeaderWidth = nextWidth;
        });
      },
    );
  }

  Widget _buildReaderInfoBar(
    ReaderThemeColors colors, {
    required bool isHeader,
  }) {
    final leadingItems = <ReaderInfoBarItemData>[
      if (_settings.infoShowProgress)
        ReaderInfoBarItemData.text(
          '进度 ${(_safeCurrentScrollRatio() * 100).round()}%',
        ),
    ];
    final centerItems = <ReaderInfoBarItemData>[
      if (_settings.infoShowChapter &&
          (_chapterTitle?.trim().isNotEmpty ?? false))
        ReaderInfoBarItemData.text(_chapterTitle!.trim(), expand: true),
    ];
    final trailingItems = <ReaderInfoBarItemData>[
      if (_settings.infoShowTime)
        ReaderInfoBarItemData.text(_formatReaderInfoTime(_readerInfoNow)),
      if (_settings.infoShowBattery)
        ReaderInfoBarItemData.battery(
          batteryLevel: _readerBatteryLevel,
          batteryReadFailed: _readerBatteryReadFailed,
        ),
    ];
    return ReaderInfoBar(
      model: ReaderInfoBarModel.fromSettings(
        settings: _settings,
        layoutResolver: _layoutResolver,
        placement:
            isHeader
                ? ReaderInfoBarPlacement.header
                : ReaderInfoBarPlacement.footer,
        role: switch ((_currentViewportKind, isHeader)) {
          (ReaderModeViewportKind.textScroll, true) =>
            ReaderChromeRole.scrollHeader,
          (ReaderModeViewportKind.textScroll, false) =>
            ReaderChromeRole.scrollFooter,
          (_, true) => ReaderChromeRole.pagedHeader,
          (_, false) => ReaderChromeRole.pagedFooter,
        },
        leadingItems: isHeader ? const <ReaderInfoBarItemData>[] : leadingItems,
        centerItems: isHeader ? const <ReaderInfoBarItemData>[] : centerItems,
        trailingItems:
            isHeader ? const <ReaderInfoBarItemData>[] : trailingItems,
      ),
      palette: _chromePalette(colors),
    );
  }

  String _formatReaderInfoTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _readerBatteryLabel() {
    final level = _readerBatteryLevel;
    if (level != null) {
      return '电量 ${level.clamp(0, 100)}%';
    }
    if (_readerBatteryReadFailed) {
      return '电量 N/A';
    }
    return '电量 --';
  }

  Widget _buildBody(ReaderThemeColors colors) => _composeReaderBody(colors);

  Widget _buildReaderList(ReaderThemeColors colors) =>
      _buildReaderViewportContent(colors);

  Widget _buildStandardReaderList(ReaderThemeColors colors) {
    final surfaceMetrics = _resolveReaderSurfaceMetrics(context);
    final scrollModel = _presentationResolver.buildTextScrollModel(
      contentSession: _resolvedContentSession(),
      settings: _settings,
      document: _document,
      surfaceMetrics: surfaceMetrics,
      palette: _presentationPalette(context),
      renderItems: _renderItems,
      contentPadding: surfaceMetrics.scrollBodyPadding,
      imageDecodeBudget: _readerImageDecodeBudget(
        role: ReaderImageDecodeRole.epubInline,
        logicalWidth: MediaQuery.sizeOf(context).width,
      ),
    );
    return _viewportBuilder.buildStandardTextViewport(
      model: scrollModel,
      scrollController: _scrollController,
      bodyKey: _readerBodyKey,
      selectionWrapper: ({required child}) => _wrapSelectionArea(child: child),
      onScrollNotification: _onReaderScrollNotification,
      imageBuilder:
          (_, item) => _buildInlineReaderImageCard(
            imageUrl: item.imageUrl,
            colors: colors,
          ),
      blockWrapper: (context, item, isLast, child) {
        if (item is ReaderRenderTextItem) {
          return _buildSelectableReaderBlockItem(
            item: item,
            isLast: isLast,
            colors: colors,
          );
        }
        if (item is ReaderRenderImageItem) {
          return _buildInlineImageParagraphItem(
            imageUrl: item.imageUrl,
            isLast: isLast,
            colors: colors,
          );
        }
        return child;
      },
      overlay: null,
    );
  }

  Widget _buildContinuousTextReader(ReaderThemeColors colors) {
    final surfaceMetrics = _resolveReaderSurfaceMetrics(context);
    final bodyPadding = surfaceMetrics.scrollBodyPadding;
    final contentSession = _resolvedContentSession();

    final listView = NotificationListener<ScrollNotification>(
      onNotification: _onReaderScrollNotification,
      child: ListView.separated(
        controller: _scrollController,
        scrollCacheExtent: ScrollCacheExtent.pixels(
          _document.hasImageBlocks ? 640 : 1800,
        ),
        padding: bodyPadding,
        itemCount: _continuousTextChapters.length,
        separatorBuilder:
            (_, __) => SizedBox(
              height: max(
                18.0,
                _typographyMetricsResolver.resolveParagraphSpacingPixels(
                      settings: _settings,
                    ) *
                    1.2,
              ),
            ),
        itemBuilder: (context, index) {
          final chapter = _continuousTextChapters[index];
          return _buildContinuousTextChapterSection(
            chapter: chapter,
            isActive: _isContinuousTextChapterActive(chapter),
            colors: colors,
          );
        },
      ),
    );

    return _viewportBuilder.buildContinuousTextViewport(
      listView: listView,
      bodyKey: _readerBodyKey,
      shellModel: _viewportBuilder.buildContinuousShellModel(
        contentSession: contentSession,
        settings: _settings,
        document: _document,
        surfaceMetrics: surfaceMetrics,
        palette: _presentationPalette(context),
      ),
      overlay: null,
    );
  }

  Widget _buildContinuousTextChapterSection({
    required ReaderPageContinuousTextChapter chapter,
    required bool isActive,
    required ReaderThemeColors colors,
  }) => _ReaderPageContentRenderingExtension(
    this,
  )._buildContinuousTextChapterSection(
    chapter: chapter,
    isActive: isActive,
    colors: colors,
  );

  ReaderRenderTextItem? _readerRenderTextItemForParagraphIndex(
    int paragraphIndex,
  ) => _ReaderPageContentRenderingExtension(
    this,
  )._readerRenderTextItemForParagraphIndex(paragraphIndex);

  Widget _buildSelectableReaderBlockItem({
    required ReaderRenderBlockItem item,
    required bool isLast,
    required ReaderThemeColors colors,
  }) => _ReaderPageContentRenderingExtension(
    this,
  )._buildSelectableReaderBlockItem(item: item, isLast: isLast, colors: colors);

  Widget _buildInlineImageParagraphItem({
    required String imageUrl,
    required bool isLast,
    required ReaderThemeColors colors,
  }) =>
      _ReaderPageContentRenderingExtension(this)._buildInlineImageParagraphItem(
        imageUrl: imageUrl,
        isLast: isLast,
        colors: colors,
      );

  Widget _buildInlineReaderImageCard({
    required String imageUrl,
    required ReaderThemeColors colors,
  }) => _ReaderPageContentRenderingExtension(
    this,
  )._buildInlineReaderImageCard(imageUrl: imageUrl, colors: colors);

  bool _isInlineImageParagraph(String paragraph) =>
      _ReaderPageContentRenderingExtension(
        this,
      )._isInlineImageParagraph(paragraph);

  int _clampInt(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  int _paragraphIndentLength() {
    final indentCount = _typographyMetricsResolver.resolveParagraphIndentCount(
      _settings,
    );
    return indentCount <= 0 ? 0 : indentCount;
  }

  int _chapterTextLength() {
    final continuousChapter =
        _shouldUseContinuousTextFlow
            ? _findCurrentContinuousTextChapter()
            : null;
    final paragraphs =
        continuousChapter?.paragraphs ??
        (_paragraphs.isEmpty
            ? <String>[_content.trim()]
            : _paragraphs.toList(growable: false));
    if (paragraphs.isEmpty) {
      return 0;
    }
    final rawLength = paragraphs.fold<int>(0, (sum, item) => sum + item.length);
    return rawLength + max(0, paragraphs.length - 1) * 2;
  }

  int _resolveChapterOffsetFromDisplayOffset(int displayOffset) {
    final paragraphs =
        _paragraphs.isEmpty
            ? <String>[_content.trim()]
            : _paragraphs.toList(growable: false);
    return text_offset_mapper.resolveChapterOffsetFromDisplayOffset(
      paragraphs: paragraphs,
      pagedPages: _pagedPages,
      currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
      paragraphIndentLength: _paragraphIndentLength(),
      displayOffset: displayOffset,
    );
  }

  int _resolveChapterOffsetFromParagraph({
    required int paragraphIndex,
    required int paragraphOffset,
  }) {
    final paragraphs =
        _paragraphs.isEmpty
            ? <String>[_content.trim()]
            : _paragraphs.toList(growable: false);
    return text_offset_mapper.resolveChapterOffsetFromParagraph(
      paragraphs: paragraphs,
      paragraphIndex: paragraphIndex,
      paragraphOffset: paragraphOffset,
    );
  }

  ({int startOffset, int endOffset, String snippet})?
  _resolveParagraphSelectionTargetForOffset(int chapterOffset) {
    final paragraphs =
        _paragraphs.isEmpty
            ? <String>[_content.trim()]
            : _paragraphs.toList(growable: false);
    if (paragraphs.isEmpty) {
      return null;
    }
    final safeOffset = chapterOffset.clamp(0, _chapterTextLength());
    var cursor = 0;
    for (var index = 0; index < paragraphs.length; index += 1) {
      final paragraph = paragraphs[index];
      final start = cursor;
      final end = start + paragraph.length;
      if (safeOffset <= end || index == paragraphs.length - 1) {
        final snippet = paragraph.trim();
        if (snippet.isEmpty) {
          return null;
        }
        return (startOffset: start, endOffset: end, snippet: snippet);
      }
      cursor = end + 2;
    }
    return null;
  }

  bool _onReaderScrollNotification(ScrollNotification notification) {
    if (!_isTextScrollViewport) {
      return false;
    }

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        _isAutoReadSessionEnabled) {
      _pauseAutoReadSession();
    }

    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      if (notification is ScrollStartNotification ||
          notification is ScrollEndNotification ||
          (notification is UserScrollNotification &&
              notification.direction == ScrollDirection.idle)) {
        _resetScrollEdgeAdvanceState();
      }
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _resetScrollEdgeAdvanceState();
      return false;
    }

    final atTop =
        metrics.pixels <=
        metrics.minScrollExtent + _kScrollAdvanceEdgeTolerance;
    final atBottom =
        metrics.pixels >=
        metrics.maxScrollExtent - _kScrollAdvanceEdgeTolerance;
    final nearTop =
        metrics.pixels <=
        metrics.minScrollExtent + _kScrollAdvanceNearEdgeThreshold;
    final nearBottom =
        metrics.pixels >=
        metrics.maxScrollExtent - _kScrollAdvanceNearEdgeThreshold;
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse && nearBottom) {
        _updateScrollEdgeAdvanceState(isArmed: true, actionDirection: 1);
      } else if (notification.direction == ScrollDirection.forward && nearTop) {
        _updateScrollEdgeAdvanceState(
          isArmed: true,
          actionDirection: _kScrollRefreshCurrentChapterAction,
        );
      } else if (notification.direction == ScrollDirection.forward) {
        _updateScrollEdgeAdvanceState(isArmed: false, actionDirection: 0);
      } else if (notification.direction == ScrollDirection.idle) {
        _updateScrollEdgeAdvanceState(isArmed: false, actionDirection: 0);
      }
    }

    if (!atBottom && !atTop) {
      _updateScrollEdgeAdvanceState(overscrollDistance: 0);
      if (notification is ScrollEndNotification ||
          (notification is UserScrollNotification &&
              notification.direction == ScrollDirection.idle)) {
        _updateScrollEdgeAdvanceState(isArmed: false, actionDirection: 0);
      }
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.scrollDelta != null) {
      final delta = notification.scrollDelta!;
      if (nearBottom && delta >= 0) {
        _updateScrollEdgeAdvanceState(isArmed: true, actionDirection: 1);
      } else if (nearTop && delta <= 0) {
        _updateScrollEdgeAdvanceState(
          isArmed: true,
          actionDirection: _kScrollRefreshCurrentChapterAction,
        );
      }
    }

    if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      final direction =
          notification.overscroll > 0 && atBottom
              ? 1
              : notification.overscroll < 0 && atTop
              ? _kScrollRefreshCurrentChapterAction
              : 0;
      if (direction != 0) {
        _updateScrollEdgeAdvanceState(
          isArmed: true,
          actionDirection: direction,
          overscrollDistance:
              _scrollEdgeAdvanceState.overscrollDistance +
              notification.overscroll.abs(),
        );
      }
      if (_scrollEdgeAdvanceState.overscrollDistance >=
              _kScrollAdvanceOverscrollTrigger &&
          _scrollEdgeAdvanceState.actionDirection != 0) {
        final actionDirection = _scrollEdgeAdvanceState.actionDirection;
        _resetScrollEdgeAdvanceState();
        unawaited(_handleScrollEdgeChapterAction(actionDirection));
      }
      return false;
    }

    if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      final isDragEnd =
          notification is ScrollEndNotification &&
          notification.dragDetails != null;
      final double endVelocityDy =
          notification is ScrollEndNotification
              ? (notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0)
              : 0;
      final action = _readerRuntimeController.resolveScrollEdgeDragEndAction(
        isArmed: _scrollEdgeAdvanceState.isArmed,
        armedActionDirection: _scrollEdgeAdvanceState.actionDirection,
        atTop: atTop,
        atBottom: atBottom,
        isDragEnd: isDragEnd,
        velocityDy: endVelocityDy,
      );
      _resetScrollEdgeAdvanceState();
      if (action == ReaderScrollEdgeAction.nextChapter) {
        unawaited(_handleScrollEdgeChapterAction(1));
      } else if (action == ReaderScrollEdgeAction.refreshCurrent) {
        unawaited(
          _handleScrollEdgeChapterAction(_kScrollRefreshCurrentChapterAction),
        );
      }
    }

    return false;
  }

  Future<void> _handleScrollEdgeChapterAction(int direction) async {
    if (direction == 0) {
      return;
    }
    if (direction == _kScrollRefreshCurrentChapterAction) {
      await _reloadCurrentChapterFromPullToRefresh();
      return;
    }
    if (_shouldUseContinuousTextFlow) {
      _showMessage(
        direction > 0 ? '正在加载下一章...' : '正在加载上一章...',
        duration: const Duration(milliseconds: 900),
        dedupeKey:
            direction > 0 ? 'loading_next_chapter' : 'loading_prev_chapter',
      );
      final chapter = await _loadAdjacentContinuousTextChapter(
        forward: direction > 0,
      );
      if (chapter != null && mounted) {
        _activateContinuousTextChapterFlow(chapter);
      } else if (mounted) {
        final current = _currentIndex;
        final hasAdjacent =
            current != null &&
            _chapterNavigation.findReadableChapterIndex(
                  _chapters,
                  current + (direction > 0 ? 1 : -1),
                  forward: direction > 0,
                ) !=
                null;
        _showMessage(
          hasAdjacent
              ? (direction > 0 ? '下一章仍在加载，请稍后再试。' : '上一章仍在加载，请稍后再试。')
              : (direction > 0 ? '已经是最后一章。' : '已经是第一章。'),
          dedupeKey:
              hasAdjacent
                  ? (direction > 0
                      ? 'next_chapter_loading_pending'
                      : 'prev_chapter_loading_pending')
                  : (direction > 0
                      ? 'boundary_last_chapter'
                      : 'boundary_first_chapter'),
        );
      }
      return;
    }
    await _jumpChapterFromScrollEdge(forward: direction > 0);
  }

  Future<void> _jumpChapterFromScrollEdge({required bool forward}) async {
    if (_isScrollEdgeAdvancingChapter || _isAutoReadAdvancingChapter) {
      return;
    }

    _isScrollEdgeAdvancingChapter = true;
    try {
      await _dispatchReaderNavigationCommand(
        forward
            ? const ReaderNavigationCommand.nextChapter(
              source: ReaderNavigationCommandSource.scrollEdge,
            )
            : const ReaderNavigationCommand.previousChapter(
              source: ReaderNavigationCommandSource.scrollEdge,
            ),
      );
    } finally {
      _isScrollEdgeAdvancingChapter = false;
    }
  }

  String _buildMangaImageUrl(String imageUrl, int retryNonce) {
    if (retryNonce <= 0 || imageUrl.startsWith('data:image/')) {
      return imageUrl;
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null || uri.scheme == 'file') {
      return imageUrl;
    }

    final updatedParameters = Map<String, String>.from(uri.queryParameters)
      ..['retry'] = '$retryNonce';
    return uri.replace(queryParameters: updatedParameters).toString();
  }

  Widget _buildMangaReader(ReaderThemeColors colors) =>
      _buildMangaViewport(colors);

  Widget _buildReaderImageWidget({
    required String requestUrl,
    required String sourceUrl,
    required ReaderThemeColors colors,
    required int retryNonce,
  }) => _ReaderPageContentRenderingExtension(this)._buildReaderImageWidget(
    requestUrl: requestUrl,
    sourceUrl: sourceUrl,
    colors: colors,
    retryNonce: retryNonce,
  );

  double _resolveMangaCacheExtent() =>
      _ReaderPageContentRenderingExtension(this)._resolveMangaCacheExtent();

  ReaderThemeMode _effectiveReaderThemeMode() {
    return _settings.themeMode;
  }

  Brightness _currentPlatformBrightness() {
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  ThemeMode _currentAppThemeMode() {
    return _appThemeMode;
  }

  AppAdvancedTheme? _currentActiveAdvancedTheme() {
    return _activeAdvancedTheme;
  }

  Future<void> _syncAppThemeModeWithReaderTheme(ReaderThemeMode mode) async {
    if (!mounted) {
      return;
    }
    final nextAppThemeMode = switch (mode) {
      ReaderThemeMode.dark => ThemeMode.dark,
      ReaderThemeMode.light => ThemeMode.light,
      ReaderThemeMode.sepia => null,
    };
    if (nextAppThemeMode == null) {
      return;
    }
    final currentAppThemeMode = _currentAppThemeMode();
    if (currentAppThemeMode == nextAppThemeMode) {
      return;
    }
    await ref
        .read(appThemeModeProvider.notifier)
        .setThemeMode(nextAppThemeMode);
  }

  void _handleAppThemeModeChanged(ThemeMode nextMode) {
    if (!mounted) {
      return;
    }
    _appThemeMode = nextMode;
    _syncReaderThemeDependencies(appThemeMode: nextMode);
  }

  void _handleActiveAdvancedThemeChanged(
    AsyncValue<AppAdvancedTheme?> nextTheme,
  ) {
    if (!mounted || nextTheme.isLoading) {
      return;
    }
    _activeAdvancedTheme = nextTheme.valueOrNull;
    _syncReaderThemeDependencies(activeTheme: nextTheme.valueOrNull);
  }

  void _syncReaderThemeDependencies({
    ThemeMode? appThemeMode,
    AppAdvancedTheme? activeTheme,
  }) {
    final nextResolved = _resolveReaderSettingsLayers(
      appThemeMode: appThemeMode,
      activeTheme: activeTheme,
    );
    final nextSettings = nextResolved.copyWith(
      pageTurnMode: _settings.pageTurnMode,
      autoReadEnabled: _settings.autoReadEnabled,
    );
    if (jsonEncode(nextSettings.toJson()) == jsonEncode(_settings.toJson())) {
      return;
    }
    _applyReaderSettingsWithModeRestore(nextSettings: nextSettings);
  }

  ReaderSettings _resolveReaderSettingsLayers({
    ReaderSettings? persistedSettings,
    ReaderVisualOverrides? visualOverrides,
    AppAdvancedTheme? activeTheme,
    ThemeMode? appThemeMode,
    Brightness? platformBrightness,
  }) {
    return _readerSettingsResolutionService.resolve(
      persistedSettings: persistedSettings ?? _persistedReaderSettings,
      visualOverrides: visualOverrides ?? _visualOverrides,
      activeTheme: activeTheme ?? _currentActiveAdvancedTheme(),
      appThemeMode: appThemeMode ?? _currentAppThemeMode(),
      platformBrightness: platformBrightness ?? _currentPlatformBrightness(),
    );
  }

  String? _normalizeOptionalVisualValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool _matchesThemeReaderFontBinding(
    ReaderSettings settings,
    String themeFontFamilyKey,
  ) {
    return settings.fontSource == ReaderFontSource.custom &&
        _normalizeOptionalVisualValue(settings.fontFamilyKey) ==
            themeFontFamilyKey &&
        _normalizeOptionalVisualValue(settings.customFontPath) == null;
  }

  Future<void> _persistResolvedReaderSettingsLayers(
    ReaderSettings resolvedSettings,
  ) async {
    final activeTheme = _currentActiveAdvancedTheme();
    final appThemeMode = _currentAppThemeMode();
    final platformBrightness = _currentPlatformBrightness();
    final themeReaderBackgroundPath = _readerSettingsResolutionService
        .resolveThemeReaderBackgroundPath(
          activeTheme: activeTheme,
          appThemeMode: appThemeMode,
          platformBrightness: platformBrightness,
        );
    final themeReaderFontFamilyKey = _readerSettingsResolutionService
        .resolveThemeReaderFontFamilyKey(activeTheme);

    var nextPersisted = resolvedSettings;
    var nextVisualOverrides = _visualOverrides;

    if (themeReaderBackgroundPath != null) {
      final persistedBackground = _normalizeOptionalVisualValue(
        _persistedReaderSettings.backgroundImageBase64,
      );
      nextPersisted = nextPersisted.copyWith(
        backgroundImageBase64: persistedBackground,
        clearBackgroundImage: persistedBackground == null,
      );

      final selectedBackground = _normalizeOptionalVisualValue(
        resolvedSettings.backgroundImageBase64,
      );
      if (selectedBackground == themeReaderBackgroundPath) {
        nextVisualOverrides = nextVisualOverrides.copyWith(
          clearBackgroundImageOverride: true,
        );
      } else {
        nextVisualOverrides = nextVisualOverrides.copyWith(
          hasBackgroundImageOverride: true,
          backgroundImageBase64: selectedBackground,
        );
      }
    } else {
      nextVisualOverrides = nextVisualOverrides.copyWith(
        clearBackgroundImageOverride: true,
      );
    }

    if (themeReaderFontFamilyKey != null) {
      final persistedFontFamilyKey = _normalizeOptionalVisualValue(
        _persistedReaderSettings.fontFamilyKey,
      );
      final persistedCustomFontPath = _normalizeOptionalVisualValue(
        _persistedReaderSettings.customFontPath,
      );
      nextPersisted = nextPersisted.copyWith(
        fontSource: _persistedReaderSettings.fontSource,
        systemFontPreset: _persistedReaderSettings.systemFontPreset,
        fontFamilyKey: persistedFontFamilyKey,
        clearFontFamilyKey: persistedFontFamilyKey == null,
        customFontPath: persistedCustomFontPath,
        clearCustomFontPath: persistedCustomFontPath == null,
      );

      if (_matchesThemeReaderFontBinding(
        resolvedSettings,
        themeReaderFontFamilyKey,
      )) {
        nextVisualOverrides = nextVisualOverrides.copyWith(
          clearFontSource: true,
          clearSystemFontPreset: true,
          clearFontFamilyKeyOverride: true,
          clearCustomFontPathOverride: true,
        );
      } else {
        nextVisualOverrides = nextVisualOverrides.copyWith(
          fontSource: resolvedSettings.fontSource,
          systemFontPreset: resolvedSettings.systemFontPreset,
          hasFontFamilyKeyOverride: true,
          fontFamilyKey: _normalizeOptionalVisualValue(
            resolvedSettings.fontFamilyKey,
          ),
          hasCustomFontPathOverride: true,
          customFontPath: _normalizeOptionalVisualValue(
            resolvedSettings.customFontPath,
          ),
        );
      }
    } else {
      nextVisualOverrides = nextVisualOverrides.copyWith(
        clearFontSource: true,
        clearSystemFontPreset: true,
        clearFontFamilyKeyOverride: true,
        clearCustomFontPathOverride: true,
      );
    }

    await _preferencesService.saveSettings(nextPersisted);
    await _visualOverridesService.saveOverrides(nextVisualOverrides);

    _persistedReaderSettings = nextPersisted;
    _visualOverrides = nextVisualOverrides;
    _settings = _resolveReaderSettingsLayers(
      persistedSettings: nextPersisted,
      visualOverrides: nextVisualOverrides,
      activeTheme: activeTheme,
      appThemeMode: appThemeMode,
      platformBrightness: platformBrightness,
    );
  }

  ReaderPageAnimationStyle _currentPagedAnimationStyle() {
    if (_layoutReleaseRendererActive) {
      return ReaderPageAnimationStyle.none;
    }
    return _currentReaderMode.pageAnimationStyle ??
        ReaderPageAnimationStyle.none;
  }

  bool get _usesPaperCurlAnimation =>
      _currentViewportKind == ReaderModeViewportKind.textPaged &&
      _currentPagedAnimationStyle() == ReaderPageAnimationStyle.paperCurl;

  bool _currentChapterHasInlineImageParagraphs() {
    return _paragraphs.any(_isInlineImageParagraph);
  }

  Widget _buildPagedReader(ReaderThemeColors colors) =>
      _buildPagedTextViewport(colors);

  Widget _buildPagedPageContainer({
    required ReaderThemeColors colors,
    required int pageIndex,
    required int total,
    required Size pageSize,
    required ReaderTextPagedViewModel pagedViewModel,
    bool includeBackgroundDecoration = false,
  }) => _ReaderPageContentRenderingExtension(this)._buildPagedPageContainer(
    colors: colors,
    pageIndex: pageIndex,
    total: total,
    pageSize: pageSize,
    pagedViewModel: pagedViewModel,
    includeBackgroundDecoration: includeBackgroundDecoration,
  );

  Widget _buildPagedHeaderSection(
    ReaderThemeColors colors,
    ReaderSurfaceMetrics layoutMetrics,
  ) => _ReaderPageContentRenderingExtension(
    this,
  )._buildPagedHeaderSection(colors, layoutMetrics);

  Widget _buildPagedFooterSection({
    required ReaderThemeColors colors,
    required int index,
    required int total,
    required ReaderSurfaceMetrics layoutMetrics,
  }) => _ReaderPageContentRenderingExtension(this)._buildPagedFooterSection(
    colors: colors,
    index: index,
    total: total,
    layoutMetrics: layoutMetrics,
  );

  Widget _buildPageIndexOverlay({
    required ReaderThemeColors colors,
    required int index,
    required int total,
    required double bottomInset,
    double? safeBottomInset,
  }) => _ReaderPageContentRenderingExtension(this)._buildPageIndexOverlay(
    colors: colors,
    index: index,
    total: total,
    bottomInset: bottomInset,
    safeBottomInset: safeBottomInset,
  );

  void _updateCurlPreviewProgress(Size viewportSize) {
    if (_isCurlAutoTurning) {
      return;
    }

    final swipe = _pointerInputController.swipeSnapshot;
    if (swipe == null) {
      return;
    }

    final delta = swipe.dx;
    if (delta.abs() < _kCurlPreviewStartThreshold) {
      if (_isCurlPreviewActive) {
        setState(() {
          _pageTurnRuntimeController.cancelCurlPreview(
            currentIndex: _pageTurnRuntimeController.currentPageIndex,
          );
        });
      }
      return;
    }

    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      return;
    }

    final direction = delta < 0 ? 1 : -1;
    final currentIndex = _pageTurnRuntimeController.currentPageIndex.clamp(
      0,
      pageCount - 1,
    );
    final targetIndex = currentIndex + direction;
    if (targetIndex < 0 || targetIndex >= pageCount) {
      if (_isCurlPreviewActive) {
        setState(() {
          _pageTurnRuntimeController.cancelCurlPreview(
            currentIndex: currentIndex,
          );
        });
      }
      return;
    }

    final progress = (delta.abs() / max(viewportSize.width * 0.9, 1.0)).clamp(
      0.0,
      0.98,
    );
    if (_isCurlPreviewActive &&
        _curlAutoDirection == direction &&
        _curlAnimationFromIndex == currentIndex &&
        _curlAnimationToIndex == targetIndex &&
        (progress - _curlPreviewProgress).abs() < 0.01) {
      return;
    }

    setState(() {
      _pageTurnRuntimeController.beginCurlPreview(
        direction: direction,
        fromIndex: currentIndex,
        toIndex: targetIndex,
        progress: progress,
      );
    });
  }

  void _finishCurlPreview({required bool commit}) {
    if (!_isCurlPreviewActive) {
      return;
    }

    final progress = _curlPreviewProgress.clamp(0.0, 1.0);
    if (progress <= 0) {
      setState(() {
        _pageTurnRuntimeController.cancelCurlPreview(
          currentIndex: _pageTurnRuntimeController.currentPageIndex,
        );
      });
      return;
    }

    setState(() {
      _pageTurnRuntimeController.finishCurlPreview(commit: commit);
    });

    _curlAutoTurnController.value = progress;
    if (commit) {
      _curlAutoTurnController.forward();
    } else {
      _curlAutoTurnController.reverse();
    }
  }

  void _onCurlAutoTurnStatus(AnimationStatus status) {
    if (!_isCurlAutoTurning) {
      return;
    }

    if (status == AnimationStatus.dismissed && !_curlCommitOnAnimationEnd) {
      final pageCount = _currentPagedPageCount;
      final currentIndex =
          pageCount <= 0
              ? 0
              : _pageTurnRuntimeController.currentPageIndex.clamp(
                0,
                _safePageUpperBound(pageCount),
              );
      setState(() {
        _pageTurnRuntimeController.cancelCurlPreview(
          currentIndex: currentIndex,
        );
      });
      _scheduleReaderInteractionSettle();
      return;
    }

    if (status != AnimationStatus.completed || !_curlCommitOnAnimationEnd) {
      return;
    }

    if (_isCurlCrossChapterTurn) {
      final direction = _curlAutoDirection;
      setState(() {
        _pageTurnRuntimeController.resetCurlTransition(
          pageIndex: _pageTurnRuntimeController.currentPageIndex,
        );
      });
      _recordFirstPageTurnCompleted(mode: 'curl_cross_chapter');
      _scheduleReaderInteractionSettle();
      _logReaderPageTurnResult(
        ReaderPageTurnResult(
          type: ReaderPageTurnResultType.committed,
          request: ReaderPageTurnRequest(direction: direction),
          executionType: ReaderPageTurnExecutionType.crossChapter,
        ),
      );
      return;
    }

    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      if (!mounted) {
        _pageTurnRuntimeController.resetCurlTransition();
        return;
      }
      setState(() {
        _pageTurnRuntimeController.resetCurlTransition();
      });
      _scheduleReaderInteractionSettle();
      return;
    }
    final nextIndex = _curlAnimationToIndex.clamp(
      0,
      _safePageUpperBound(pageCount),
    );

    setState(() {
      _pageTurnRuntimeController.commitCurlTurn(pageIndex: nextIndex);
    });
    _scheduleProgressSave();
    _recordFirstPageTurnCompleted(mode: 'curl');
    _scheduleReaderInteractionSettle();
    _logReaderPageTurnResult(
      ReaderPageTurnResult(
        type: ReaderPageTurnResultType.committed,
        request: ReaderPageTurnRequest(direction: _curlAutoDirection),
        executionType: ReaderPageTurnExecutionType.curl,
        targetPageIndex: nextIndex,
      ),
    );
  }

  Future<ReaderPageTurnResult?> _autoTurnCurlPage(
    int direction, {
    ReaderPageTurnRequest? request,
  }) async {
    final turnRequest = request ?? ReaderPageTurnRequest(direction: direction);
    if (_isCurlAutoTurning) {
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: turnRequest,
        executionType: ReaderPageTurnExecutionType.curl,
        rejectReason: ReaderPageTurnRejectReason.pageTurnBusy,
      );
    }

    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: turnRequest,
        executionType: ReaderPageTurnExecutionType.curl,
        rejectReason: ReaderPageTurnRejectReason.noPages,
      );
    }

    final currentIndex = _pageTurnRuntimeController.currentPageIndex.clamp(
      0,
      pageCount - 1,
    );
    if (direction < 0 && currentIndex <= 0) {
      return _turnCrossChapterWithSnapshot(
        ReaderPageTurnPlan.execute(
          request: turnRequest,
          executionType: ReaderPageTurnExecutionType.crossChapter,
        ),
        style: ReaderPageAnimationStyle.curl,
        completionMode: 'curl_cross_chapter',
      );
    }

    if (direction > 0 && currentIndex >= pageCount - 1) {
      return _turnCrossChapterWithSnapshot(
        ReaderPageTurnPlan.execute(
          request: turnRequest,
          executionType: ReaderPageTurnExecutionType.crossChapter,
        ),
        style: ReaderPageAnimationStyle.curl,
        completionMode: 'curl_cross_chapter',
      );
    }

    _markReaderInteractionBusy(ReaderInteractionRuntimeState.animating);
    setState(() {
      _pageTurnRuntimeController.beginCurlAutoTurn(
        direction: direction,
        fromIndex: currentIndex,
        toIndex: currentIndex + direction,
      );
    });

    _curlAutoTurnController.value = 0;
    _curlAutoTurnController.forward();
    return null;
  }

  void _snapToPagedTextPage(int pageIndex) {
    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      return;
    }
    final safeIndex = pageIndex.clamp(0, _safePageUpperBound(pageCount));
    _resetPagedTransitionState();
    _resetCurlAnimationState();
    _pageTurnRuntimeController.pagedTextControllerSyncGeneration += 1;
    final pageController = _staticPagedTextPageControllerInstance;
    if (pageController != null && pageController.hasClients) {
      pageController.jumpToPage(safeIndex);
    }
    setState(() {
      _pageTurnRuntimeController.currentPageIndex = safeIndex;
      _pageTurnRuntimeController
          .pagedPaginationState = _pageTurnRuntimeController
          .pagedPaginationState
          .copyWith(pendingRestoreRatio: safeIndex / max(1, pageCount - 1));
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  void _ensurePagination({required ReaderPaginationSpec spec}) {
    if (!mounted || !_isTextPagedViewport) {
      return;
    }
    final plan = _paginationController.buildEnsurePlan(
      spec: spec,
      chapterId: _chapterId,
      currentState: _pageTurnRuntimeController.pagedPaginationState,
      hasExistingPages: _pagedPages.isNotEmpty || _pagedBlockPages.isNotEmpty,
      currentProgressRatio: _currentScrollRatio(),
    );
    if (!plan.shouldPaginate) {
      return;
    }

    final taskId =
        _readerSessionController
            .beginIntent(const ReaderSessionIntent.changeSettings())
            .paginationTaskToken!;
    unawaited(
      _restoreOrPaginateCurrentChapter(taskId: taskId, spec: spec, plan: plan),
    );
  }

  Future<void> _restoreOrPaginateCurrentChapter({
    required int taskId,
    required ReaderPaginationSpec spec,
    required ReaderPaginationEnsurePlan plan,
  }) async {
    final sourceId = (_sourceId ?? '').trim();
    final chapterUrl = (_chapterUrl ?? '').trim();

    if (sourceId.isNotEmpty && chapterUrl.isNotEmpty) {
      final cachedLayout = await _loadPrecomputedChapterLayout(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: plan.signature,
      );
      if (!mounted || taskId != _paginationTaskId) {
        return;
      }
      if (cachedLayout != null && cachedLayout.pagedBlockPages.isNotEmpty) {
        final targetIndex = _chapterLoadPlanner.resolvePageIndexByRatio(
          targetRatio: plan.preservedRatio,
          pageCount: cachedLayout.pagedBlockPages.length,
        );
        setState(() {
          _pagedPages = const <List<ReaderPagedSlice>>[];
          _pagedBlockPages = cachedLayout.pagedBlockPages;
          _pageTurnRuntimeController.currentPageIndex = targetIndex;
          _pageTurnRuntimeController
              .pagedPaginationState = ReaderPaginationSessionState(
            signature: cachedLayout.paginationSignature,
          );
          if (_paragraphs.isEmpty && cachedLayout.paragraphs.isNotEmpty) {
            _paragraphs = List<String>.unmodifiable(cachedLayout.paragraphs);
          }
          _resetPagedTransitionState();
          _resetCurlAnimationState();
        });
        _traceReaderFirstPageReady(
          source: 'block_cache',
          pageCount: cachedLayout.pagedBlockPages.length,
        );
        return;
      }
      if (cachedLayout != null && cachedLayout.pagedPages.isNotEmpty) {
        final targetIndex = _chapterLoadPlanner.resolvePageIndexByRatio(
          targetRatio: plan.preservedRatio,
          pageCount: cachedLayout.pagedPages.length,
        );
        setState(() {
          _pagedPages = cachedLayout.pagedPages;
          _pagedBlockPages = const <List<ReaderPagedBlock>>[];
          _pageTurnRuntimeController.currentPageIndex = targetIndex;
          _pageTurnRuntimeController
              .pagedPaginationState = ReaderPaginationSessionState(
            signature: cachedLayout.paginationSignature,
          );
          if (_paragraphs.isEmpty && cachedLayout.paragraphs.isNotEmpty) {
            _paragraphs = List<String>.unmodifiable(cachedLayout.paragraphs);
          }
          _resetPagedTransitionState();
          _resetCurlAnimationState();
        });
        _traceReaderFirstPageReady(
          source: 'text_cache',
          pageCount: cachedLayout.pagedPages.length,
        );
        return;
      }
    }

    _resetPagedTransitionState();
    _resetCurlAnimationState();

    setState(() {
      _textPaginationFallbackDiagnostic = null;
      _pageTurnRuntimeController.pagedPaginationState =
          plan.buildLoadingState();
      _pagedPages = const [];
      _pagedBlockPages = const <List<ReaderPagedBlock>>[];
      _pageTurnRuntimeController.currentPageIndex = 0;
    });

    await _paginateCurrentChapter(
      taskId: taskId,
      spec: spec,
      signature: plan.signature,
    );
  }

  void _resetCurlAnimationState() {
    _curlAutoTurnController.stop();
    _pageTurnRuntimeController.resetCurlTransition(
      pageIndex: _pageTurnRuntimeController.currentPageIndex,
    );
  }

  void _resetPagedTransitionState() {
    _pagedTransitionController.stop();
    _pageTurnRuntimeController.resetPagedTransition();
  }

  String _buildPaginationSignature({
    required ReaderPaginationSpec spec,
    String? chapterIdOverride,
  }) {
    return _paginationController.buildSignature(
      chapterId: chapterIdOverride ?? _chapterId,
      spec: spec,
    );
  }

  bool _canWarmNeighborPaginationCache() {
    final paginationSpec = _lastPaginationSpec;
    return _isTextPagedViewport &&
        !_pageTurnRuntimeController.pagedPaginationState.isPaginating &&
        _pagedPages.isNotEmpty &&
        paginationSpec != null &&
        paginationSpec.contentWidth >= 20 &&
        paginationSpec.contentHeight >= 40;
  }

  List<ReaderPaginationParagraph> _buildPaginationParagraphModels(
    ReaderThemeColors colors,
    List<String> paragraphs,
  ) {
    return List<ReaderPaginationParagraph>.generate(paragraphs.length, (index) {
      final renderItem = _readerRenderTextItemForParagraphIndex(index);
      final resolved = resolveReaderTextBlockPresentation(
        settings: _settings,
        primaryTextColor: colors.text,
        secondaryTextColor: colors.meta,
        item: renderItem,
        isLast: false,
      );
      final style = resolved.textStyle.copyWith(color: Colors.black);
      final firstLinePrefix =
          renderItem == null ||
                  renderItem.kind == ReaderRenderTextKind.paragraph
              ? readerParagraphIndentPrefix(_settings)
              : '';
      return ReaderPaginationParagraph(
        text: paragraphs[index],
        paragraphStyle: style,
        textAlign: resolved.textAlign,
        firstLinePrefix: firstLinePrefix,
        spacingAfter: resolved.spacingAfter,
      );
    }, growable: false);
  }

  Future<void> _paginateCurrentChapter({
    required int taskId,
    required ReaderPaginationSpec spec,
    required String signature,
  }) async {
    final paragraphs =
        _paragraphs.isEmpty ? <String>[_content.trim()] : _paragraphs;
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    final request = ReaderPaginationRequest(
      paragraphs: paragraphs,
      spec: spec,
      paragraphStyle: _paragraphTextStyle(colors).copyWith(color: Colors.black),
      paragraphModels: _buildPaginationParagraphModels(colors, paragraphs),
      textScaler: MediaQuery.textScalerOf(context),
      shouldAbort: () => !mounted || taskId != _paginationTaskId,
    );
    if (_document.hasImageBlocks) {
      await for (final event in _streamingPaginationController.paginateBlocks(
        ReaderBlockPaginationRequest(
          renderItems: _renderItems,
          paragraphs: paragraphs,
          spec: spec,
          paragraphStyle: _paragraphTextStyle(
            colors,
          ).copyWith(color: Colors.black),
          paragraphModels: _buildPaginationParagraphModels(colors, paragraphs),
          textScaler: MediaQuery.textScalerOf(context),
          shouldAbort: () => !mounted || taskId != _paginationTaskId,
          imagePlaceholderAspectRatio: spec.imagePlaceholderAspectRatio,
        ),
        targetRatio:
            _pageTurnRuntimeController
                .pagedPaginationState
                .pendingRestoreRatio ??
            0,
      )) {
        if (!mounted || taskId != _paginationTaskId) {
          return;
        }
        if (event.type == ReaderStreamingPaginationEventType.cancelled) {
          return;
        }
        final pages = event.pages;
        if (pages.isEmpty) {
          if (event.completed) {
            _fallbackTextPaginationToScroll(
              'block pagination completed with no pages',
            );
          }
          continue;
        }
        final pendingRatio =
            _pageTurnRuntimeController.pagedPaginationState.pendingRestoreRatio;
        final targetIndex =
            pendingRatio == null
                ? _pageTurnRuntimeController.currentPageIndex.clamp(
                  0,
                  pages.length - 1,
                )
                : (pendingRatio.clamp(0.0, 1.0) * (pages.length - 1))
                    .round()
                    .clamp(0, pages.length - 1);
        setState(() {
          _textPaginationFallbackDiagnostic = null;
          _pageTurnRuntimeController
              .pagedPaginationState = ReaderPaginationSessionState(
            signature: signature,
            isPaginating: !event.completed,
          );
          _pagedPages = const <List<ReaderPagedSlice>>[];
          _pagedBlockPages = pages;
          _pageTurnRuntimeController.currentPageIndex = targetIndex;
          _resetCurlAnimationState();
        });
        _traceReaderFirstPageReady(
          source: event.completed ? 'block_complete' : 'block_stream',
          pageCount: pages.length,
        );
        if (event.completed &&
            _paginationCacheService.shouldPersistChapterLayout(
              sourceId: _sourceId ?? '',
              chapterUrl: _chapterUrl ?? '',
            )) {
          _storePrecomputedChapterLayout(
            sourceId: _sourceId ?? '',
            chapterUrl: _chapterUrl ?? '',
            layout: ReaderPrecomputedChapterLayout(
              paragraphs: paragraphs,
              pagedPages: const <List<ReaderPagedSlice>>[],
              pagedBlockPages: pages,
              paginationSignature: signature,
            ),
          );
        }
      }
      return;
    }

    await for (final event in _streamingPaginationController.paginateText(
      request,
      targetRatio:
          _pageTurnRuntimeController.pagedPaginationState.pendingRestoreRatio ??
          0,
    )) {
      if (!mounted || taskId != _paginationTaskId) {
        return;
      }
      if (event.type == ReaderStreamingPaginationEventType.cancelled) {
        return;
      }
      final pages = event.pages;
      if (pages.isEmpty) {
        setState(() {
          _pageTurnRuntimeController
              .pagedPaginationState = _pageTurnRuntimeController
              .pagedPaginationState
              .copyWith(isPaginating: false, pendingRestoreRatio: null);
          _pagedPages = const [];
          _pagedBlockPages = const <List<ReaderPagedBlock>>[];
          _resetCurlAnimationState();
        });
        continue;
      }
      var targetIndex = 0;
      final pendingRatio =
          _pageTurnRuntimeController.pagedPaginationState.pendingRestoreRatio;
      if (pendingRatio != null && pages.isNotEmpty) {
        targetIndex = (pendingRatio.clamp(0.0, 1.0) * (pages.length - 1))
            .round()
            .clamp(0, pages.length - 1);
      }
      setState(() {
        _pageTurnRuntimeController
            .pagedPaginationState = ReaderPaginationSessionState(
          signature: signature,
          isPaginating: !event.completed,
        );
        _pagedPages = pages;
        _pagedBlockPages = const <List<ReaderPagedBlock>>[];
        _pageTurnRuntimeController.currentPageIndex = targetIndex;
        _resetCurlAnimationState();
      });
      _traceReaderFirstPageReady(
        source: event.completed ? 'text_complete' : 'text_stream',
        pageCount: pages.length,
      );
      if (event.completed) {
        if (_paginationCacheService.shouldPersistChapterLayout(
          sourceId: _sourceId ?? '',
          chapterUrl: _chapterUrl ?? '',
        )) {
          _storePrecomputedChapterLayout(
            sourceId: _sourceId ?? '',
            chapterUrl: _chapterUrl ?? '',
            layout: ReaderPrecomputedChapterLayout(
              paragraphs: paragraphs,
              pagedPages: pages,
              paginationSignature: signature,
            ),
          );
        }
      }
    }
    return;
  }

  void _traceReaderFirstPageReady({
    required String source,
    required int pageCount,
  }) {
    developer.Timeline.instantSync(
      'reader.first_page_ready',
      arguments: <String, Object?>{
        'source': source,
        'pageCount': pageCount,
        'chapterId': _chapterId,
      },
    );
  }

  void _logLongPressTrace(
    String step, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    _logger.info(
      'Reader long press trace',
      context: <String, Object?>{
        'chain': 'reader_long_press',
        'step': step,
        'chapterId': _chapterId,
        'viewportKind': _currentViewportKind.name,
        'contentMode': _currentContentMode.name,
        ...context,
      },
    );
  }

  void _fallbackTextPaginationToScroll(String diagnostic) {
    if (!mounted) {
      return;
    }
    _resetPagedTransitionState();
    _resetCurlAnimationState();
    setState(() {
      _textPaginationFallbackDiagnostic = diagnostic;
      _pageTurnRuntimeController.pagedPaginationState =
          const ReaderPaginationSessionState();
      _pagedPages = const <List<ReaderPagedSlice>>[];
      _pagedBlockPages = const <List<ReaderPagedBlock>>[];
      _pageTurnRuntimeController.currentPageIndex = 0;
    });
  }

  Widget _buildTapAwareBody({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gestureInsets = MediaQuery.systemGestureInsetsOf(context);
        final enableSwipeTurn = _isSwipePaginationEnabled();
        final enableCurlPreview = _shouldUseCurlGesturePreview();
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: _handleReaderPointerSignal,
          onPointerDown: (event) {
            final started = _pointerInputController.beginPointer(
              event,
              shouldHandleLongPress: _shouldHandleReaderLongPress,
              selectionActive: _isTextSelectionActive,
              resolveLongPressGuard:
                  () => ReaderPointerLongPressGuard(
                    mounted: mounted,
                    selectionActive: _isTextSelectionActive,
                  ),
              logTrace: _logLongPressTrace,
              onLongPress: () => unawaited(_handleReaderLongPress()),
            );
            if (!started) {
              return;
            }
            if (enableSwipeTurn) {
              _pointerInputController.startSwipe(event.localPosition);
            }
          },
          onPointerMove: (event) {
            if (!_pointerInputController.updatePointerMove(
              event,
              logTrace: _logLongPressTrace,
            )) {
              return;
            }
            if (enableSwipeTurn) {
              if (enableCurlPreview) {
                _updateCurlPreviewProgress(constraints.biggest);
              }
            }
          },
          onPointerCancel: (event) {
            if (!_pointerInputController.isTrackedPointer(event.pointer)) {
              return;
            }
            if (enableCurlPreview && _isCurlPreviewActive) {
              _finishCurlPreview(commit: false);
            }
            _resetPointerTracking();
          },
          onPointerUp: (event) {
            final pointerSnapshot = _pointerInputController
                .buildPointerUpSnapshot(event);
            if (pointerSnapshot == null) {
              return;
            }
            if (_isInitialReaderInteractionCoolingDown) {
              _resetPointerTracking();
              return;
            }
            final size = constraints.biggest;
            final elapsedMs = pointerSnapshot.elapsedMs;
            final dx = pointerSnapshot.dx;
            final dy = pointerSnapshot.dy;
            final velocity = pointerSnapshot.velocity;

            if (enableSwipeTurn && pointerSnapshot.hasSwipeTracking) {
              final isSwipe =
                  dx.abs() >= _kSwipeTurnDistanceThreshold ||
                  velocity.abs() >= _kSwipeTurnVelocityThreshold;
              if (enableCurlPreview && _isCurlPreviewActive) {
                _finishCurlPreview(commit: isSwipe);
                _resetPointerTracking();
                return;
              }
              if (isSwipe) {
                final dragDetails = DragEndDetails(
                  velocity: Velocity(pixelsPerSecond: Offset(velocity, 0)),
                  primaryVelocity: velocity,
                );
                _onSwipePaginationDragEnd(
                  dragDetails,
                  size,
                  pointerSnapshot.swipe!,
                );
                _resetPointerTracking();
                return;
              }
              final isPagedPullRefresh =
                  (_currentViewportKind == ReaderModeViewportKind.textPaged ||
                      _currentViewportKind ==
                          ReaderModeViewportKind.imagePaged) &&
                  dy >= _kPagedPullRefreshDistanceThreshold &&
                  dy.abs() > dx.abs() * 1.2;
              if (isPagedPullRefresh) {
                unawaited(_reloadCurrentChapterFromPullToRefresh());
                _resetPointerTracking();
                return;
              }
            }

            if (pointerSnapshot.childHandled) {
              _logLongPressTrace(
                'pointer_up_child_handled',
                context: <String, Object?>{
                  'pointer': pointerSnapshot.pointer,
                  'elapsedMs': elapsedMs,
                  'selectionActive': _isTextSelectionActive,
                  'longPressTriggered': pointerSnapshot.longPressTriggered,
                },
              );
              _resetPointerTracking();
              return;
            }

            _logLongPressTrace(
              'pointer_up',
              context: <String, Object?>{
                'pointer': pointerSnapshot.pointer,
                'elapsedMs': elapsedMs,
                'tapPointerMoved': pointerSnapshot.moved,
                'selectionActive': _isTextSelectionActive,
                'longPressTriggered': pointerSnapshot.longPressTriggered,
              },
            );
            if (!pointerSnapshot.moved &&
                !pointerSnapshot.longPressTriggered &&
                elapsedMs <= kLongPressTimeout.inMilliseconds &&
                !_isTextSelectionActive) {
              _logLongPressTrace(
                'pointer_up_fallback_tap',
                context: <String, Object?>{
                  'pointer': pointerSnapshot.pointer,
                  'elapsedMs': elapsedMs,
                },
              );
              _onReaderTap(event.localPosition, size, gestureInsets);
            }
            _resetPointerTracking();
          },
          child: child,
        );
      },
    );
  }

  void _onSwipePaginationDragEnd(
    DragEndDetails details,
    Size viewportSize,
    ReaderPointerSwipeSnapshot swipe,
  ) {
    if (!_isSwipePaginationEnabled()) {
      return;
    }
    if (_isInitialReaderInteractionCoolingDown) {
      return;
    }
    if (_isBackNavigationInteractionCoolingDown) {
      return;
    }

    // Reserve system edge-swipe area for route back gestures, so returning to
    // bookshelf does not accidentally trigger chapter/page turning.
    if (context.canPop()) {
      final gestureInsets = MediaQuery.systemGestureInsetsOf(context);
      final leftGuard = max(
        _kSystemBackGestureGuardMin,
        gestureInsets.left + viewportSize.width * _kSystemBackGestureGuardRatio,
      );
      final rightGuard = max(
        _kSystemBackGestureGuardMin,
        gestureInsets.right +
            viewportSize.width * _kSystemBackGestureGuardRatio,
      );
      if (swipe.startDx <= leftGuard ||
          swipe.startDx >= viewportSize.width - rightGuard) {
        return;
      }
    }

    if (_isAutoReadSessionEnabled) {
      _pauseAutoReadSession();
      return;
    }

    if (_overlayController.showOverlayControls) {
      _hideOverlayControls(resumeAutoRead: true);
    }

    final delta = swipe.dx;
    final velocity = details.primaryVelocity ?? 0;
    final isLeftTurn =
        delta <= -_kSwipeTurnDistanceThreshold ||
        velocity <= -_kSwipeTurnVelocityThreshold;
    final isRightTurn =
        delta >= _kSwipeTurnDistanceThreshold ||
        velocity >= _kSwipeTurnVelocityThreshold;

    if (isLeftTurn && !isRightTurn) {
      unawaited(
        _dispatchReaderNavigationCommand(
          const ReaderNavigationCommand.nextPage(
            source: ReaderNavigationCommandSource.swipe,
          ),
        ),
      );
      return;
    }

    if (isRightTurn && !isLeftTurn) {
      unawaited(
        _dispatchReaderNavigationCommand(
          const ReaderNavigationCommand.previousPage(
            source: ReaderNavigationCommandSource.swipe,
          ),
        ),
      );
    }
  }

  void _resetPointerTracking() {
    _pointerInputController.reset();
  }

  TextStyle _paragraphTextStyle(ReaderThemeColors colors) =>
      _ReaderPageContentRenderingExtension(this)._paragraphTextStyle(colors);

  Future<int?> _showBodyTextColorPickerDialog(
    BuildContext context, {
    int? initialColorValue,
  }) async {
    return _showReaderColorPickerSurface(
      context,
      title: '自定义正文字色',
      initialColorValue:
          initialColorValue ??
          _resolveThemeColors(_settings.themeMode, _settings).text.toARGB32(),
      previewBuilder:
          (context, preview) => Text(
            '正文预览：山高月小，水落石出。',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: preview, height: 1.6),
          ),
      recentColors: _recentBodyTextColors,
    );
  }

  Future<int?> _showBodyTextShadowColorPickerDialog(
    BuildContext context, {
    int? initialColorValue,
  }) async {
    return _showReaderColorPickerSurface(
      context,
      title: '正文阴影颜色',
      initialColorValue:
          initialColorValue ??
          _resolveThemeColors(_settings.themeMode, _settings).text.toARGB32(),
      previewBuilder:
          (context, preview) => Text(
            '阴影预览：山高月小，水落石出。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.black,
              shadows: [
                Shadow(
                  color: preview,
                  blurRadius: 8,
                  offset: const Offset(1, 1),
                ),
              ],
              height: 1.6,
            ),
          ),
    );
  }

  Future<int?> _showBodyTextDecorationColorPickerDialog(
    BuildContext context, {
    int? initialColorValue,
  }) async {
    return _showReaderColorPickerSurface(
      context,
      title: '正文下划线颜色',
      initialColorValue:
          initialColorValue ??
          _resolveThemeColors(_settings.themeMode, _settings).text.toARGB32(),
      previewBuilder:
          (context, preview) => Text(
            '下划线预览：山高月小，水落石出。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.black,
              decoration: TextDecoration.underline,
              decorationColor: preview,
              decorationThickness: 3,
              height: 1.6,
            ),
          ),
    );
  }

  Future<int?> _showReaderColorPickerSurface(
    BuildContext context, {
    required String title,
    required int initialColorValue,
    required Widget Function(BuildContext context, Color preview)
    previewBuilder,
    List<int> recentColors = const <int>[],
  }) async {
    Color draftColor = Color(initialColorValue);
    final hexController = TextEditingController(
      text: _formatReaderHex(draftColor.toARGB32()),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final desktopLike = AppLayout.isDesktopLike(
      context,
      platform: theme.platform,
    );
    final panelRadius = BorderRadius.vertical(
      top: const Radius.circular(28),
      bottom: desktopLike ? const Radius.circular(28) : Radius.zero,
    );

    final result = await showAdaptiveRawSurface<int>(
      context: context,
      showDragHandle: false,
      mobileBackgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final preview = draftColor;
            return Material(
              color: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(borderRadius: panelRadius),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!desktopLike) ...[
                      const AdaptiveSheetDragHandle(),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        AppButton(
                          variant: AppButtonVariant.tonal,
                          onPressed:
                              () => Navigator.of(
                                dialogContext,
                              ).pop(draftColor.toARGB32()),
                          label: '保存',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: previewBuilder(context, preview),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: hexController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[#0-9a-fA-F]'),
                        ),
                      ],
                      onChanged: (value) {
                        final parsed = _parseReaderHexColor(value);
                        if (parsed == null) {
                          return;
                        }
                        setDialogState(() {
                          draftColor = Color(parsed);
                        });
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                        hintText: '#RRGGBB / #AARRGGBB',
                        filled: true,
                        fillColor: colorScheme.surface.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ColorPicker(
                      pickerColor: draftColor,
                      onColorChanged: (color) {
                        setDialogState(() {
                          draftColor = color;
                        });
                      },
                      enableAlpha: true,
                      displayThumbColor: true,
                      portraitOnly: true,
                      paletteType: PaletteType.hsvWithHue,
                      colorPickerWidth: 360,
                      pickerAreaHeightPercent: 0.62,
                      pickerAreaBorderRadius: const BorderRadius.all(
                        Radius.circular(12),
                      ),
                      labelTypes: const [],
                      hexInputController: hexController,
                    ),
                    if (recentColors.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '最近使用',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: recentColors
                            .map((value) {
                              final color = Color(value);
                              final selected = draftColor.toARGB32() == value;
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    draftColor = color;
                                    hexController.text = _formatReaderHex(
                                      color.toARGB32(),
                                    );
                                  });
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          selected
                                              ? colorScheme.primary
                                              : colorScheme.outlineVariant,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: draftColor,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: colorScheme.outline.withValues(
                                alpha: 0.38,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _formatReaderHex(draftColor.toARGB32()),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        AppButton(
                          variant: AppButtonVariant.text,
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          label: '取消',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    hexController.dispose();
    return result;
  }

  int? _parseReaderHexColor(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final normalized = value.startsWith('#') ? value.substring(1) : value;
    if (normalized.length == 6) {
      final parsed = int.tryParse(normalized, radix: 16);
      return parsed == null ? null : 0xFF000000 | parsed;
    }
    if (normalized.length == 8) {
      return int.tryParse(normalized, radix: 16);
    }
    return null;
  }

  String _formatReaderHex(int? value) {
    if (value == null) {
      return '#000000';
    }
    final hex = value.toRadixString(16).toUpperCase().padLeft(8, '0');
    if (hex.startsWith('FF')) {
      return '#${hex.substring(2)}';
    }
    return '#$hex';
  }

  String _applyParagraphIndent(String paragraph) {
    final indentCount = _paragraphIndentLength();
    if (indentCount <= 0) {
      return paragraph;
    }

    return '${'　' * indentCount}$paragraph';
  }

  Future<void> _openChapterCache() async {
    final sourceId = _sourceId;
    if (sourceId == null || sourceId.isEmpty) {
      if (!mounted) {
        return;
      }
      _showMessage('缺少目录信息，无法缓存。');
      return;
    }
    if (_chapters.isEmpty) {
      await _hydrateCatalogAfterVisible();
      if (!mounted || _chapters.isEmpty) {
        _showMessage('缺少目录信息，无法缓存。');
        return;
      }
    }

    if (!_canCacheChapter) {
      _showMessage(
        _readerCacheFeedbackResolver.unsupportedMessage(
          isLocalContent: _isLocalContent,
        ),
      );
      return;
    }

    final readableChapters = _chapterNavigation.readableChapters(_chapters);
    if (readableChapters.isEmpty) {
      _showMessage(_readerCacheFeedbackResolver.missingCatalogMessage());
      return;
    }

    final total = readableChapters.length;
    final currentChapterId = _chapterId;
    final currentChapterUrl = (_chapterUrl ?? '').trim();
    final currentReadableIndex = readableChapters.indexWhere(
      (chapter) =>
          chapter.id == currentChapterId ||
          chapter.chapterUrl.trim() == currentChapterUrl,
    );
    final startIndex =
        (currentReadableIndex >= 0 ? currentReadableIndex : 0)
            .clamp(0, max(0, total - 1))
            .toInt();
    final endIndex = min(total - 1, startIndex + 49);

    await showChapterCacheFlow(
      context: context,
      bookId: _currentBookId,
      sourceId: sourceId,
      chapters: readableChapters,
      initialStartIndex: startIndex,
      initialEndIndex: endIndex,
      entryPoint: ChapterCacheEntryPoint.reader,
      bookTitle: _bookTitle,
    );
  }

  Widget _buildTopOverlay(ReaderThemeColors colors) {
    final chapterTitle =
        _chapterTitle?.isNotEmpty == true ? _chapterTitle! : '阅读';
    final sourceName = _currentSourceNameForTopOverlay();
    final chapterLine =
        sourceName.isEmpty
            ? _chapterProgressLabel()
            : '${_chapterProgressLabel()} · $sourceName';
    final layoutContext = ReaderLayoutContext.resolve(
      context,
      viewportKind: _currentViewportKind,
    );
    final useDesktopChrome =
        layoutContext.overlayActionPlacement ==
        ReaderOverlayActionPlacement.topToolbar;
    final isDarkMode = _effectiveReaderThemeMode() == ReaderThemeMode.dark;
    final dayNightAction = _chromeActionPresenter.dayNightAction(
      isDarkMode: isDarkMode,
    );
    final autoReadAction = _chromeActionPresenter.autoReadAction(
      _chromeAutoReadStatus,
    );

    return ReaderTopOverlayBar(
      colors: colors,
      overlayVisible: _overlayController.showOverlayControls,
      animation: _overlayControlsController,
      fadeProgress: _overlayControlsFadeProgress,
      transitionBuilder:
          (child) => _buildShellOverlayTransition(
            edge: _OverlayEdge.top,
            child: child,
          ),
      chapterTitle: chapterTitle,
      chapterLine: chapterLine,
      useDesktopChrome: useDesktopChrome,
      autoReadAction: autoReadAction,
      dayNightAction: dayNightAction,
      onBack: _handleBackNavigation,
      onCatalog: () => unawaited(_openCatalogSheetFromOverlay()),
      onAutoRead: () => unawaited(_openAutoReadFromOverlay()),
      onToggleDayNight: () => unawaited(_toggleDayNightMode()),
      onInterfaceSettings:
          () => unawaited(
            _showSettingsSheet(initialTab: _ReaderSettingsTab.interface),
          ),
      onOpenDetail: _openDetailPage,
      onMore: () => unawaited(_showTopMoreActions(colors)),
      onActionPointerDown: _markReaderTapHandledByChild,
    );
  }

  String _currentSourceNameForTopOverlay() {
    return '';
  }

  Future<void> _showTopMoreActions(ReaderThemeColors colors) async {
    final actions = _chromeActionPresenter.buildTopMoreActions(
      canCacheChapter: _canCacheChapter,
      isCurrentChapterCached: _isCurrentChapterCached,
      canSwitchSource: _canSwitchSource,
      isSwitchSourceLoading: _isSwitchSourceLoading,
      isShelfActionLoading: _isShelfActionLoading,
      isInBookshelf: _isInBookshelf,
    );
    final action =
        await showAdaptiveActionSurface<ReaderChromeTopMoreActionKind>(
          context: context,
          maxWidth: 420,
          padding: EdgeInsets.zero,
          builder: (_) => ReaderTopMoreActionSheet(actions: actions),
        );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case ReaderChromeTopMoreActionKind.cacheChapter:
        await _openChapterCache();
        return;
      case ReaderChromeTopMoreActionKind.switchSource:
        await _showSwitchSourceSheet();
        return;
      case ReaderChromeTopMoreActionKind.toggleBookshelf:
        await _toggleBookshelf();
        return;
    }
  }

  Widget _buildBottomOverlay(ReaderThemeColors colors) {
    final layoutContext = ReaderLayoutContext.resolve(
      context,
      viewportKind: _currentViewportKind,
    );
    if (!layoutContext.showsBottomActionBar) {
      return _buildDesktopBottomProgressOverlay(colors, layoutContext);
    }

    final isDarkMode = _effectiveReaderThemeMode() == ReaderThemeMode.dark;
    final dayNightAction = _chromeActionPresenter.dayNightAction(
      isDarkMode: isDarkMode,
    );
    final autoReadAction = _chromeActionPresenter.autoReadAction(
      _chromeAutoReadStatus,
    );
    const interfaceAction = ReaderChromeActionData(
      icon: Icons.palette_outlined,
      label: '界面',
      tooltip: '界面设置',
    );

    return ReaderMobileBottomOverlayBar(
      colors: colors,
      overlayVisible: _overlayController.showOverlayControls,
      animation: _overlayControlsController,
      fadeProgress: _overlayControlsFadeProgress,
      transitionBuilder:
          (child) => _buildShellOverlayTransition(
            edge: _OverlayEdge.bottom,
            child: child,
          ),
      progressStrip: _buildBottomProgressStrip(colors),
      autoReadAction: autoReadAction,
      dayNightAction: dayNightAction,
      interfaceAction: interfaceAction,
      onCatalog: (_) async {
        _touchOverlayControls();
        await _openCatalogSheetFromOverlay();
      },
      onAutoRead: (_) async {
        _touchOverlayControls();
        await _openAutoReadFromOverlay();
      },
      onAutoReadLongPress:
          () => _showSettingsSheet(
            initialTab: _ReaderSettingsTab.reading,
            initialSettingsGroupKey: 'auto_read',
          ),
      onToggleDayNight: (buttonContext) async {
        _touchOverlayControls();
        await _toggleDayNightModeWithReveal(buttonContext);
      },
      onInterfaceSettings: (_) async {
        _touchOverlayControls();
        await _showSettingsSheet(initialTab: _ReaderSettingsTab.interface);
      },
      onActionPointerDown: _markReaderTapHandledByChild,
      onActionError: () => _showMessage('操作失败，请稍后重试。'),
    );
  }

  Widget _buildDesktopBottomProgressOverlay(
    ReaderThemeColors colors,
    ReaderLayoutContext layoutContext,
  ) {
    return ReaderDesktopBottomProgressOverlay(
      colors: colors,
      overlayVisible: _overlayController.showOverlayControls,
      animation: _overlayControlsController,
      fadeProgress: _overlayControlsFadeProgress,
      transitionBuilder:
          (child) => _buildShellOverlayTransition(
            edge: _OverlayEdge.bottom,
            child: child,
          ),
      progressStrip: _buildBottomProgressStrip(colors),
      maxWidth: layoutContext.desktopProgressMaxWidth,
      bottomPadding: max(10.0, layoutContext.metrics.pagePadding * 0.5),
    );
  }

  Widget _buildAutoReadStatusOverlay(ReaderThemeColors colors) {
    final isPaused =
        _autoReadSessionState == ReaderAutoReadSessionState.paused ||
        _autoReadSessionState == ReaderAutoReadSessionState.chapterPaused;
    final isChapterPaused =
        _autoReadSessionState == ReaderAutoReadSessionState.chapterPaused;
    return ReaderAutoReadStatusOverlay(
      colors: colors,
      visible: _autoReadSessionState != ReaderAutoReadSessionState.off,
      isPaused: isPaused,
      isChapterPaused: isChapterPaused,
      progress: _safeCurrentScrollRatio(),
      topPadding: MediaQuery.viewPaddingOf(context).top,
      onResume: _resumeAutoReadSession,
      onOpenSettings:
          () => _showSettingsSheet(
            initialTab: _ReaderSettingsTab.reading,
            initialSettingsGroupKey: 'auto_read',
          ),
      onContinueChapter: () => unawaited(_continueAutoReadAfterChapterPause()),
    );
  }

  Widget _buildBottomProgressStrip(ReaderThemeColors colors) {
    final progressValue = (_overlayController.bottomDraftProgressRatio ??
            _safeCurrentScrollRatio())
        .clamp(0.0, 1.0);
    final canNavigateChapters = _chapters.isNotEmpty;

    return ReaderBottomProgressStrip(
      colors: colors,
      progressValue: progressValue,
      canNavigateChapters: canNavigateChapters,
      hasVisibleReaderContent: _hasVisibleReaderContent,
      onPreviousChapter:
          () => unawaited(
            _dispatchReaderNavigationCommand(
              const ReaderNavigationCommand.previousChapter(
                source: ReaderNavigationCommandSource.chrome,
              ),
            ),
          ),
      onNextChapter:
          () => unawaited(
            _dispatchReaderNavigationCommand(
              const ReaderNavigationCommand.nextChapter(
                source: ReaderNavigationCommandSource.chrome,
              ),
            ),
          ),
      onPointerDown: _markReaderTapHandledByChild,
      onChangeStart: (_) => _suspendOverlayAutoHide(),
      onChanged: (value) {
        _touchOverlayControls();
        setState(() {
          _overlayController.bottomDraftProgressRatio = value;
        });
      },
      onChangeEnd: (value) {
        setState(() {
          _overlayController.resetBottomDraftProgress();
        });
        final request = _navigationEntryResolver.resolveProgressSelection(
          scrollRatio: value,
        );
        _restoreScrollPosition(request.initialScrollRatio ?? value);
        _syncActiveReadingRecordSessionProgress(ratio: value);
        _scheduleProgressSave();
        _resumeOverlayAutoHide();
      },
    );
  }

  double _safeCurrentScrollRatio({double fallback = 0}) {
    try {
      if (_settings.autoReadMode == ReaderAutoReadMode.scroll &&
          _autoReadSessionState == ReaderAutoReadSessionState.running) {
        final autoReadProgress = _autoReadDisplayProgressRatio;
        if (autoReadProgress != null) {
          return autoReadProgress.clamp(0.0, 1.0);
        }
      }
      return _currentScrollRatio();
    } on FlutterError {
      return fallback;
    }
  }

  Widget _buildShellOverlayTransition({
    required _OverlayEdge edge,
    required Widget child,
  }) {
    final slideProgress = _overlayControlsShiftProgress;
    final fadeProgress = _overlayControlsFadeProgress;
    final translateY =
        (edge == _OverlayEdge.top ? -1 : 1) *
        (1 - slideProgress) *
        _kShellOverlayTranslateDistance;

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(opacity: fadeProgress, child: child),
    );
  }

  String _chapterProgressLabel() {
    return _chromeActionPresenter.chapterProgressLabel(
      bookTitle: _bookTitle,
      currentIndex: _currentIndex,
      chapterCount: _chapters.length,
    );
  }

  ReaderChromeAutoReadStatus get _chromeAutoReadStatus {
    return switch (_autoReadSessionState) {
      ReaderAutoReadSessionState.off => ReaderChromeAutoReadStatus.off,
      ReaderAutoReadSessionState.running => ReaderChromeAutoReadStatus.running,
      ReaderAutoReadSessionState.paused => ReaderChromeAutoReadStatus.paused,
      ReaderAutoReadSessionState.chapterPaused =>
        ReaderChromeAutoReadStatus.chapterPaused,
      ReaderAutoReadSessionState.finished =>
        ReaderChromeAutoReadStatus.finished,
    };
  }

  ReaderFailurePresentation? _readerFailurePresentationFor(AppException error) {
    return _readerErrorPresenter.gatewayPresentationFor(error);
  }

  String _readerGatewayFailureStageFor(AppException error) =>
      _readerErrorPresenter.gatewayFailureStageFor(error);

  String _toUserReadableError(AppException error) => _readerErrorPresenter
      .userReadableError(error, isLocalContent: _isLocalContent);

  bool get _hasReaderGatewayRecoveryAction {
    final presentation = _readerFailurePresentation;
    return presentation?.allowWebLogin == true ||
        presentation?.allowWebViewTask == true;
  }

  String? get _readerGatewayRecoveryActionLabel {
    if (!_hasReaderGatewayRecoveryAction) {
      return null;
    }
    return _readerFailurePresentation?.primaryActionLabel;
  }

  Future<void> _openReaderGatewayRecovery() async {
    final presentation = _readerFailurePresentation;
    if (presentation == null) {
      await _loadCurrentChapter(initialScrollRatio: null);
      return;
    }
    final sourceId = (_sourceId ?? '').trim();
    if (sourceId.isEmpty) {
      _showMessage('缺少书源标识，无法打开恢复入口。');
      return;
    }

    final route =
        presentation.allowWebLogin
            ? sourceWebViewLoginLocation(
              sourceId: sourceId,
              sourceName: _bookTitle.isEmpty ? null : _bookTitle,
            )
            : sourceWebViewTaskLocation(
              sourceId: sourceId,
              stage: _readerGatewayFailureStage ?? 'content',
              sourceName: _bookTitle.isEmpty ? null : _bookTitle,
              bookId: _activeBookId,
              detailUrl: _detailUrl,
              chapterUrl: _chapterUrl,
              chapterIndex: _currentIndex,
              chapterTitle: _chapterTitle,
              executionContext: _chapterExecutionContext,
            );

    final result = await context.push<Object?>(route);
    if (!mounted || result == null) {
      return;
    }
    _showMessage('已收到客户端协作结果，正在重试当前章节。');
    setState(() {
      _isBootstrapping = true;
      _errorText = null;
      _readerFailurePresentation = null;
      _readerGatewayFailureStage = null;
    });
    await _bootstrap();
  }

  bool _isBookmarkInCurrentChapter(Bookmark bookmark) {
    return _bookmarkRangePresenter.isBookmarkInChapter(
      bookmark,
      chapterId: _chapterId,
      chapterIndex: _currentIndex,
    );
  }

  Map<int, List<ReaderBookmarkRange>> _buildBookmarkRangesByParagraph(
    List<Bookmark> bookmarks,
  ) => _bookmarkRangePresenter.buildRangesByParagraph(
    bookmarks: bookmarks,
    paragraphs: _paragraphs,
    fallbackContent: _content,
  );

  bool _bookmarkHasHighlight(Bookmark bookmark) =>
      _bookmarkRangePresenter.bookmarkHasHighlight(bookmark);

  Bookmark? _currentSelectionBookmark() {
    if (!_isTextSelectionActive || _selectedSnippet.isEmpty) {
      return null;
    }
    return _bookmarkRangePresenter.findBookmarkByOffsets(
      bookmarks: _chapterBookmarks,
      chapterId: _chapterId,
      chapterIndex: _currentIndex,
      startOffset: _selectionStartOffset,
      endOffset: _selectionEndOffset,
    );
  }

  double _adaptiveReaderSheetHeightFactor(
    BuildContext context, {
    required double compact,
    required double regular,
    required double large,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    if (metrics.isLandscape && metrics.height < 420) {
      return max(compact, 0.92);
    }
    return switch (metrics.windowClass) {
      AppWindowClass.compact => metrics.isCompactDensity ? compact : regular,
      AppWindowClass.medium => regular,
      AppWindowClass.expanded => large,
    };
  }

  Future<void> _refreshBookshelfState() async {
    final sourceId = _sourceId;
    final detailUrl = _detailUrl;
    if (sourceId == null ||
        detailUrl == null ||
        sourceId.isEmpty ||
        detailUrl.isEmpty) {
      return;
    }

    final value = await _bookshelfService.contains(
      sourceId: sourceId,
      detailUrl: detailUrl,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isInBookshelf = value;
    });
  }

  void _cancelBackgroundRefreshConflictForCurrentBook() {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    final bookId = _currentBookId.trim();
    final conflictKey = _taskConflictService.conflictKeyForBook(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
    );
    if (conflictKey.isEmpty) {
      return;
    }
    _taskConflictService.cancelBackgroundWorkFor(
      conflictKey: conflictKey,
      byScene: RemoteContentConflictScene.reader,
    );
  }

  List<String> _currentConflictKeys() {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    final bookId = _currentBookId.trim();
    return <String>[
      _taskConflictService.conflictKeyForSource(sourceId),
      _taskConflictService.conflictKeyForBook(
        sourceId: sourceId,
        detailUrl: detailUrl,
        bookId: bookId,
      ),
    ].where((item) => item.trim().isNotEmpty).toList(growable: false);
  }

  Future<void> _toggleBookshelf() async {
    final sourceId = _sourceId;
    final detailUrl = _detailUrl;
    if (sourceId == null ||
        detailUrl == null ||
        sourceId.isEmpty ||
        detailUrl.isEmpty) {
      _showMessage('缺少书源参数，无法操作书架。');
      return;
    }

    setState(() {
      _isShelfActionLoading = true;
    });

    final wasInBookshelf = _isInBookshelf;
    try {
      if (wasInBookshelf) {
        await _bookshelfService.remove(
          sourceId: sourceId,
          detailUrl: detailUrl,
        );
      } else {
        await _bookshelfService.upsert(
          BookshelfBook(
            bookId: _currentBookId,
            sourceId: sourceId,
            title:
                _bookTitle.isNotEmpty
                    ? _bookTitle
                    : (widget.chapterTitle ?? '未命名书籍'),
            detailUrl: detailUrl,
            author: _bookAuthor,
            coverUrl: _bookCoverUrl,
            latestChapter: _latestReadableChapterTitle(_chapters),
            addedAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isInBookshelf = !wasInBookshelf;
      });
      _showMessage(wasInBookshelf ? '已从书架移除。' : '已加入书架。');
    } catch (error, stackTrace) {
      _logger.warn(
        'Reader bookshelf operation failed',
        context: <String, Object?>{
          'bookId': _activeBookId,
          'sourceId': _sourceId,
          'detailUrl': _detailUrl,
          'chapterId': _chapterId,
          'chapterUrl': _chapterUrl,
          'chapterIndex': _currentIndex,
          'wasInBookshelf': wasInBookshelf,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      _showMessage('书架操作失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isShelfActionLoading = false;
        });
      }
    }
  }

  void _openDetailPage() {
    final sourceId = _sourceId;
    final detailUrl = _detailUrl;
    if (sourceId == null ||
        detailUrl == null ||
        sourceId.isEmpty ||
        detailUrl.isEmpty) {
      _showMessage('缺少详情参数，无法打开详情页。');
      return;
    }

    final route = buildBookDetailRoute(
      bookId: _currentBookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      title:
          _bookTitle.isNotEmpty ? _bookTitle : (widget.chapterTitle ?? '书籍详情'),
      author: _bookAuthor,
      coverUrl: _bookCustomCoverPath ?? _bookCoverUrl,
    );

    context.push(route);
  }

  List<ReaderCatalogSearchEntry>? _peekCatalogSearchEntries(
    String normalizedKeyword,
  ) {
    final fingerprint = _catalogSearchService.buildCacheFingerprint(
      chapterId: _chapterId,
      chapterUrl: _chapterUrl,
      currentChapterIndex: _currentIndex,
      chapters: _chapters,
      supportsContentSearch:
          _readerModeCapabilities.supportsCatalogContentSearch,
      chapterContent: _content,
      chapterParagraphCount: _paragraphs.length,
    );
    if (_catalogSearchCacheFingerprint != fingerprint) {
      _resetCatalogSearchCache();
      _catalogSearchCacheFingerprint = fingerprint;
    }
    return _catalogSearchEntriesCache[normalizedKeyword];
  }

  int? _resolveCatalogSearchEntryTargetIndex(ReaderCatalogSearchEntry entry) {
    final request = _navigationEntryResolver.resolveCatalogSearchEntry(
      entry: ReaderCatalogSearchEntryAdapter(
        chapterIndex: entry.chapterIndex,
        targetChapterIndex: entry.targetChapterIndex,
        isVolume: entry.isVolume,
        isContent: entry.isContent,
      ),
      chapters: _chapters,
    );
    return request?.targetChapterIndex;
  }

  int? _resolveCurrentIndex(List<Chapter> chapters) {
    if (chapters.isEmpty) {
      return null;
    }

    final byId = chapters.indexWhere((chapter) => chapter.id == _chapterId);
    if (byId >= 0) {
      return _chapterNavigation.resolveNearestReadableChapterIndex(
        chapters,
        byId,
        preferForward: true,
      );
    }

    final chapterUrl = _chapterUrl;
    if (chapterUrl != null && chapterUrl.isNotEmpty) {
      final byUrl = chapters.indexWhere(
        (chapter) => chapter.chapterUrl == chapterUrl,
      );
      if (byUrl >= 0) {
        return _chapterNavigation.resolveNearestReadableChapterIndex(
          chapters,
          byUrl,
          preferForward: true,
        );
      }
    }

    final fromRoute = widget.chapterIndex;
    if (fromRoute != null && fromRoute >= 0 && fromRoute < chapters.length) {
      return _chapterNavigation.resolveNearestReadableChapterIndex(
        chapters,
        fromRoute,
        preferForward: true,
      );
    }

    return _chapterNavigation.findReadableChapterIndex(
      chapters,
      0,
      forward: true,
    );
  }

  String? _latestReadableChapterTitle(List<Chapter> chapters) {
    for (var index = chapters.length - 1; index >= 0; index--) {
      final chapter = chapters[index];
      if (_chapterNavigation.isReadableChapter(chapter)) {
        return chapter.title;
      }
    }
    return null;
  }

  void _applyReaderSettingsWithModeRestore({
    required ReaderSettings nextSettings,
    VoidCallback? beforeStateUpdate,
    bool syncVolumeKeyPageInterception = true,
  }) {
    final previousSettings = _settings;
    final shouldSyncAppThemeMode =
        nextSettings.themeMode != previousSettings.themeMode;
    final previousPagedTextEnabled = _isPagedTextReaderEnabledFor(
      previousSettings,
    );
    final nextPagedTextEnabled = _isPagedTextReaderEnabledFor(nextSettings);
    final didSwitchTextRenderMode =
        !_isMangaChapter && previousPagedTextEnabled != nextPagedTextEnabled;
    final logicalAnchor =
        didSwitchTextRenderMode ? _currentLogicalPosition() : null;
    final anchorFallbackRatio =
        didSwitchTextRenderMode ? _currentScrollRatio() : 0.0;

    setState(() {
      beforeStateUpdate?.call();
      _settings = nextSettings;
      _textPaginationFallbackDiagnostic = null;
    });
    _syncContinuousTextFlowAfterSettingsApplied();
    if (didSwitchTextRenderMode) {
      _restoreTextPositionFromLogicalAnchor(
        previousPagedTextEnabled: previousPagedTextEnabled,
        logicalAnchor: logicalAnchor,
        fallbackRatio: anchorFallbackRatio,
      );
    }
    if (syncVolumeKeyPageInterception) {
      unawaited(_syncVolumeKeyPageInterception());
    }
    unawaited(_applySystemReaderBrightness(nextSettings.brightness));
    if (shouldSyncAppThemeMode) {
      unawaited(_syncAppThemeModeWithReaderTheme(nextSettings.themeMode));
    }
  }

  void _applyProgressFallback(ReadingProgress progress) {
    if ((_sourceId ?? '').trim().isEmpty) {
      _sourceId = progress.sourceId;
    }
    if ((_detailUrl ?? '').trim().isEmpty) {
      _detailUrl = progress.detailUrl;
    }
    if (_isPlaceholderChapterId(_chapterId)) {
      _chapterId = progress.chapterId;
    }
    if ((_chapterUrl ?? '').trim().isEmpty) {
      _chapterUrl = progress.chapterUrl;
    }
    if ((_chapterTitle ?? '').trim().isEmpty) {
      _chapterTitle = progress.chapterTitle;
    }
    if (_currentIndex == null || _currentIndex! < 0) {
      _currentIndex = progress.chapterIndex;
    }
  }

  void _applyLocalSchemeFallback() {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    final chapterUrl = (_chapterUrl ?? '').trim();

    if (sourceId.isEmpty &&
        (LocalReaderIdentity.isLocalSchemeUrl(detailUrl) ||
            LocalReaderIdentity.isLocalSchemeUrl(chapterUrl))) {
      _sourceId = LocalReaderIdentity.localSourceId;
    }

    if (!LocalReaderIdentity.isLocalSourceId(_sourceId)) {
      return;
    }

    if (detailUrl.isEmpty || !LocalReaderIdentity.isLocalSchemeUrl(detailUrl)) {
      _detailUrl = LocalReaderIdentity.buildBookDetailUrl(_currentBookId);
    }

    final normalizedChapterId = _chapterId.trim();
    if ((chapterUrl.isEmpty ||
            !LocalReaderIdentity.isLocalSchemeUrl(chapterUrl)) &&
        normalizedChapterId.isNotEmpty &&
        !_isPlaceholderChapterId(normalizedChapterId)) {
      _chapterUrl = LocalReaderIdentity.buildChapterUrl(normalizedChapterId);
    }
  }

  String _normalizeLocalDetailUrlForProgress(String detailUrl) {
    return _progressCommitController.normalizeLocalDetailUrlForProgress(
      sourceId: _sourceId ?? '',
      bookId: _currentBookId,
      detailUrl: detailUrl,
    );
  }

  String _normalizeLocalChapterUrlForProgress(String chapterUrl) {
    return _progressCommitController.normalizeLocalChapterUrlForProgress(
      sourceId: _sourceId ?? '',
      chapterId: _chapterId,
      chapterUrl: chapterUrl,
    );
  }

  bool _isPlaceholderChapterId(String chapterId) {
    final normalized = chapterId.trim();
    return normalized.isEmpty ||
        normalized == 'bootstrap' ||
        normalized == 'unknown-chapter' ||
        normalized == 'unknown-local-chapter';
  }

  ContentCapabilities get _contentCapabilities {
    final sourceId = _sourceId?.trim();
    if (sourceId == null || sourceId.isEmpty) {
      return const ContentCapabilities();
    }
    final provider = _contentProviderRegistry.findForSourceId(sourceId);
    return provider?.capabilities ?? const ContentCapabilities();
  }

  bool get _canSwitchSource => false;
  bool get _canCacheChapter => _readerModeCapabilities.canCacheChapter;

  String get _currentBookId {
    final normalized = _activeBookId.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return widget.bookId.trim();
  }

  bool get _isLocalSource => LocalReaderIdentity.isLocalSourceId(_sourceId);
  bool get _isLocalContent =>
      _isLocalSource || _contentCapabilities.canReindexLocal;

  ContentProvider _requireContentProvider({
    required String? sourceId,
    ErrorStage stage = ErrorStage.unknown,
  }) {
    final normalized = (sourceId ?? '').trim();
    if (normalized.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: stage,
        briefMessage: '缺少 sourceId，无法加载内容。',
      );
    }

    final provider = _contentProviderRegistry.findForSourceId(normalized);
    if (provider == null) {
      if (isRemovedScriptSourceId(normalized)) {
        throwRemovedScriptSource(stage: stage, sourceId: normalized);
      }
      throw AppException(
        code: ErrorCode.unknownSource,
        stage: stage,
        briefMessage: '未找到可用的内容提供者。',
      );
    }

    return provider;
  }

  bool get _isMissingCriticalParams {
    return _sourceId == null ||
        _sourceId!.isEmpty ||
        _detailUrl == null ||
        _detailUrl!.isEmpty;
  }

  Future<void> _showSettingsSheet({
    _ReaderSettingsTab initialTab = _ReaderSettingsTab.reading,
    String? initialSettingsGroupKey,
    bool startAutoReadAfterApplyInitially = false,
  }) => _ReaderPageSettingsSheetExtension(this)._showSettingsSheet(
    initialTab: initialTab,
    initialSettingsGroupKey: initialSettingsGroupKey,
    startAutoReadAfterApplyInitially: startAutoReadAfterApplyInitially,
  );
  double _letterSpacingSliderValue(ReaderSettings settings) {
    return ((settings.letterSpacing * 100) + 50).clamp(0, 100).toDouble();
  }

  double _letterSpacingFromSliderValue(double sliderValue) {
    return ((((sliderValue.clamp(0, 100).toDouble()) - 50) / 100).clamp(
      ReaderSettings.minLetterSpacing,
      ReaderSettings.maxLetterSpacing,
    )).toDouble();
  }

  String _letterSpacingValueLabel(ReaderSettings settings) =>
      _readerSettingsPresenter.letterSpacingValueLabel(settings);

  double _lineHeightSliderValue(ReaderSettings settings) {
    return _typographyMetricsResolver.resolveLineSpacingExtra(settings);
  }

  double _lineHeightFromSliderValue({
    required double sliderValue,
    required ReaderSettings settings,
  }) {
    final safeFontSize = settings.fontSize <= 0 ? 18.0 : settings.fontSize;
    return ((safeFontSize + sliderValue) / safeFontSize).toDouble();
  }

  String _lineHeightValueLabel(ReaderSettings settings) {
    final md3Extra = _typographyMetricsResolver.resolveLineSpacingExtra(
      settings,
    );
    return md3Extra.round().toString();
  }

  String _paragraphSpacingValueLabel(ReaderSettings settings) {
    final md3Spacing = _typographyMetricsResolver.resolveParagraphSpacingUnits(
      settings,
    );
    return md3Spacing.toStringAsFixed(1);
  }

  String _paragraphIndentValueLabel(ReaderSettings settings) {
    return switch (_typographyMetricsResolver.resolveParagraphIndentCount(
      settings,
    )) {
      0 => '无缩进',
      1 => '一字符',
      2 => '二字符',
      3 => '三字符',
      _ => '四字符',
    };
  }

  String _pageAnimationLabel(ReaderPageAnimationStyle style) =>
      _readerSettingsPresenter.pageAnimationLabel(style);

  ThemeData _readerModalTheme() {
    final mode = _effectiveReaderThemeMode();
    final baseScheme = _colorSchemeForReaderMode(mode);
    final colors = _resolveThemeColors(mode, _settings);

    Color blendOverlay(double alpha) {
      return Color.alphaBlend(
        colors.overlay.withValues(alpha: alpha),
        colors.background,
      );
    }

    final tunedScheme = baseScheme.copyWith(
      surface: blendOverlay(0.18),
      surfaceContainerLowest: blendOverlay(0.08),
      surfaceContainerLow: blendOverlay(0.14),
      surfaceContainer: blendOverlay(0.22),
      surfaceContainerHigh: blendOverlay(0.32),
      surfaceContainerHighest: blendOverlay(0.40),
      onSurface: colors.text,
      onSurfaceVariant: colors.meta,
    );
    final theme = AppTheme.build(tunedScheme);
    final bottomSheetColor = tunedScheme.surfaceContainerHigh;

    return theme.copyWith(
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        backgroundColor: bottomSheetColor,
        modalBackgroundColor: bottomSheetColor,
        dragHandleColor: colors.divider,
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        backgroundColor: tunedScheme.surface,
      ),
    );
  }

  ReaderThemeColors _resolveThemeColors(
    ReaderThemeMode mode,
    ReaderSettings settings,
  ) {
    if (_isClassicLightReaderBackground(mode, settings)) {
      return const ReaderThemeColors(
        background: Color(0xFFFDFDFD),
        text: Color(0xFF111827),
        meta: Color(0xFF6B7280),
        divider: Color(0xFFE5E7EB),
        overlay: Color(0xFFF7F7F7),
      );
    }

    final scheme = _colorSchemeForReaderMode(mode);

    final baseBackground = _backgroundForTone(scheme, settings.backgroundTone);
    final baseOverlay = _overlayForTone(scheme, settings.backgroundTone);

    var background = baseBackground;
    var overlay = baseOverlay;
    var textColor = scheme.onSurface;
    var metaColor = scheme.onSurfaceVariant;
    final dividerColor = scheme.outlineVariant.withValues(alpha: 0.6);

    if (mode == ReaderThemeMode.sepia) {
      const targetBackground = Color(0xFFF7EEDC);
      const targetOverlay = Color(0xFFF0E3C7);
      background =
          Color.lerp(baseBackground, targetBackground, 0.72) ??
          targetBackground;
      overlay = Color.lerp(baseOverlay, targetOverlay, 0.72) ?? targetOverlay;
      textColor = const Color(0xFF3F2E1F);
      metaColor = const Color(0xFF6E563D);
    }

    return ReaderThemeColors(
      background: background,
      text: textColor,
      meta: metaColor,
      divider: dividerColor,
      overlay: overlay,
    );
  }

  bool _isClassicLightReaderBackground(
    ReaderThemeMode mode,
    ReaderSettings settings,
  ) {
    return mode == ReaderThemeMode.light &&
        settings.backgroundStyle == ReaderBackgroundStyle.plain &&
        settings.backgroundTone == ReaderBackgroundTone.surface;
  }

  ColorScheme _colorSchemeForReaderMode(ReaderThemeMode mode) {
    final currentScheme = Theme.of(context).colorScheme;
    final targetBrightness =
        mode == ReaderThemeMode.dark ? Brightness.dark : Brightness.light;

    if (currentScheme.brightness == targetBrightness) {
      return currentScheme;
    }

    return ColorScheme.fromSeed(
      seedColor: currentScheme.primary,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      brightness: targetBrightness,
    );
  }

  Color _backgroundForTone(ColorScheme scheme, ReaderBackgroundTone tone) {
    final paletteSeedColor = readerPaletteSeedColorForTone(tone);
    if (paletteSeedColor != null) {
      return _blendReaderToneColor(
        base: scheme.surface,
        tint: paletteSeedColor,
        alpha: 0.12,
      );
    }

    return switch (tone) {
      ReaderBackgroundTone.surface => scheme.surface,
      ReaderBackgroundTone.containerLow => scheme.surfaceContainerLow,
      ReaderBackgroundTone.container => scheme.surfaceContainer,
      ReaderBackgroundTone.containerHigh => scheme.surfaceContainerHigh,
      ReaderBackgroundTone.containerHighest => scheme.surfaceContainerHighest,
      ReaderBackgroundTone.pureBlack => const Color(0xFF000000),
      ReaderBackgroundTone.primaryTint => scheme.surface,
      ReaderBackgroundTone.secondaryTint => scheme.surface,
      ReaderBackgroundTone.tertiaryTint => scheme.surface,
      ReaderBackgroundTone.flameOrangeTint => scheme.surface,
      ReaderBackgroundTone.pineGreenTint => scheme.surface,
      ReaderBackgroundTone.seaBlueTint => scheme.surface,
      ReaderBackgroundTone.nightPurpleTint => scheme.surface,
      ReaderBackgroundTone.mistTealTint => scheme.surface,
      ReaderBackgroundTone.berryRoseTint => scheme.surface,
      ReaderBackgroundTone.amberGoldTint => scheme.surface,
    };
  }

  Color _overlayForTone(ColorScheme scheme, ReaderBackgroundTone tone) {
    final paletteSeedColor = readerPaletteSeedColorForTone(tone);
    if (paletteSeedColor != null) {
      return _blendReaderToneColor(
        base: scheme.surfaceContainerLow,
        tint: paletteSeedColor,
        alpha: 0.18,
      );
    }

    return switch (tone) {
      ReaderBackgroundTone.surface => scheme.surfaceContainerLow,
      ReaderBackgroundTone.containerLow => scheme.surfaceContainer,
      ReaderBackgroundTone.container => scheme.surfaceContainerHigh,
      ReaderBackgroundTone.containerHigh => scheme.surfaceContainerHighest,
      ReaderBackgroundTone.containerHighest => scheme.surfaceContainerHighest,
      ReaderBackgroundTone.pureBlack => const Color(0xFF0A0A0A),
      ReaderBackgroundTone.primaryTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.secondaryTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.tertiaryTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.flameOrangeTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.pineGreenTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.seaBlueTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.nightPurpleTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.mistTealTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.berryRoseTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.amberGoldTint => scheme.surfaceContainerLow,
    };
  }

  Color _blendReaderToneColor({
    required Color base,
    required Color tint,
    required double alpha,
  }) {
    return Color.alphaBlend(tint.withValues(alpha: alpha), base);
  }

  Color _shiftLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final shifted = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(shifted).toColor();
  }
}

class _ReaderSourceSnapshot {
  const _ReaderSourceSnapshot({
    required this.contentSession,
    required this.errorText,
    required this.isInBookshelf,
    required this.isCurrentChapterCached,
    required this.content,
    required this.chapterImageUrls,
    required this.chapterImageHeaders,
    required this.scrollRatio,
    required this.catalogComplete,
  });

  final ReaderContentSession? contentSession;
  final String? errorText;
  final bool isInBookshelf;
  final bool isCurrentChapterCached;
  final String content;
  final List<String> chapterImageUrls;
  final Map<String, String> chapterImageHeaders;
  final double scrollRatio;
  final bool catalogComplete;

  String get bookId => contentSession?.bookId ?? '';
  String? get sourceId => contentSession?.sourceId;
  String? get detailUrl => contentSession?.detailUrl;
  String get bookTitle => contentSession?.bookTitle ?? '';
  String? get bookAuthor => contentSession?.bookAuthor;
  String? get bookCoverUrl => contentSession?.bookCoverUrl;
  List<Chapter> get chapters => contentSession?.chapters ?? const <Chapter>[];
  int? get currentIndex => contentSession?.chapterIndex;
  String get chapterId => contentSession?.chapterId ?? '';
  String? get chapterUrl => contentSession?.chapterUrl;
  String? get chapterTitle => contentSession?.chapterTitle;
}
