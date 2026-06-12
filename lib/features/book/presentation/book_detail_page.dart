import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../app/composition/app_providers.dart' as app_providers;
import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/layout/app_adaptive.dart';
import '../../../app/images/local_file_image.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/adaptive_fullscreen_preview.dart';
import '../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../app/widgets/adaptive_route_top_bar.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../app/widgets/runtime_feedback_card.dart';
import '../../../app/widgets/switch_source_candidate_sheet.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/storage/local_file_stat.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../providers.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../reader/application/content_provider.dart';
import '../../reader/application/reader_catalog_search_service.dart';
import '../../reader/application/local/local_book_index_service.dart';
import '../../reader/application/local/local_reader_identity.dart';
import '../../reader/application/local/local_book_storage_service.dart';
import '../../reader/application/local/local_book_workflow_policy.dart';
import '../../reader/application/local_content_provider.dart';
import '../../reader/application/removed_script_source_guard.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../reader/application/server_gateway_content_provider.dart';
import '../../reader/application/reader_system_settings_service.dart';
import '../../reader/application/reading_record_service.dart';
import '../../reader/application/source_switch_score_service.dart';
import '../../reader/application/switch_source_shared.dart';
import '../../reader/presentation/chapter_cache_sheets.dart';
import '../../reader/presentation/reader_catalog_sheet.dart';
import '../../search/application/search_hit_cache_service.dart';
import '../../search/application/search_service.dart';
import '../../search/application/server_gateway_identity.dart';
import '../../search/presentation/online_source_error_presentation.dart';
import '../../search/providers.dart' as search_providers;
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../../source/application/remote_content_task_conflict_service.dart';
import '../../source/application/remote_content_task_scheduler_service.dart';
import '../application/book_detail_service.dart';
import '../application/book_detail_action_service.dart';
import '../application/book_detail_catalog_service.dart';
import '../application/book_detail_read_route_service.dart';
import '../application/book_local_metadata_service.dart';
import '../application/book_detail_metadata_flow_service.dart';
import '../application/book_metadata_edit_service.dart';
import '../application/book_metadata_presentation_resolver.dart';
import '../application/book_reading_status_service.dart';
import 'book_reading_status_presentation.dart';
import 'book_detail_switch_source_helper.dart';
import 'widgets/book_detail_primary_actions.dart';
import 'widgets/book_detail_sections.dart';
part 'book_detail_page_models.dart';
part 'book_detail_page_metadata.dart';
part 'book_detail_page_actions.dart';
part 'book_detail_page_catalog.dart';
part 'book_detail_page_view.dart';

class BookDetailPage extends ConsumerStatefulWidget {
  const BookDetailPage({
    super.key,
    required this.bookId,
    this.initialBook,
    this.sourceId,
    this.detailUrl,
    this.title,
    this.author,
    this.coverUrl,
    this.heroTag,
    this.titleHeroTag,
    this.metaHeroTag,
    this.initialEditMode = false,
    this.bookDetailService,
    this.bookshelfService,
    this.switchSourceSearchService,
  });

  final String bookId;
  final Book? initialBook;
  final String? sourceId;
  final String? detailUrl;
  final String? title;
  final String? author;
  final String? coverUrl;
  final String? heroTag;
  final String? titleHeroTag;
  final String? metaHeroTag;
  final bool initialEditMode;
  final BookDetailService? bookDetailService;
  final BookshelfService? bookshelfService;
  final SearchService? switchSourceSearchService;

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPresentationState {
  const _BookDetailPresentationState({
    this.isLoading = false,
    this.isCatalogLoading = false,
    this.errorText,
    this.tocWarningText,
    this.result,
  });

  final bool isLoading;
  final bool isCatalogLoading;
  final String? errorText;
  final String? tocWarningText;
  final BookDetailLoadResult? result;

  _BookDetailPresentationState copyWith({
    bool? isLoading,
    bool? isCatalogLoading,
    String? errorText,
    bool clearErrorText = false,
    String? tocWarningText,
    bool clearTocWarningText = false,
    BookDetailLoadResult? result,
    bool clearResult = false,
  }) {
    return _BookDetailPresentationState(
      isLoading: isLoading ?? this.isLoading,
      isCatalogLoading: isCatalogLoading ?? this.isCatalogLoading,
      errorText: clearErrorText ? null : (errorText ?? this.errorText),
      tocWarningText:
          clearTocWarningText ? null : (tocWarningText ?? this.tocWarningText),
      result: clearResult ? null : (result ?? this.result),
    );
  }
}

class _BookDetailAuxiliaryState {
  const _BookDetailAuxiliaryState({
    this.isInBookshelf = false,
    this.isShelfStateLoading = true,
    this.isShelfActionLoading = false,
    this.localBookMeta,
    this.readingProgress,
    this.showLocalAdvancedOptions = false,
  });

  final bool isInBookshelf;
  final bool isShelfStateLoading;
  final bool isShelfActionLoading;
  final LocalBook? localBookMeta;
  final ReadingProgress? readingProgress;
  final bool showLocalAdvancedOptions;

  _BookDetailAuxiliaryState copyWith({
    bool? isInBookshelf,
    bool? isShelfStateLoading,
    bool? isShelfActionLoading,
    LocalBook? localBookMeta,
    bool clearLocalBookMeta = false,
    ReadingProgress? readingProgress,
    bool clearReadingProgress = false,
    bool? showLocalAdvancedOptions,
  }) {
    return _BookDetailAuxiliaryState(
      isInBookshelf: isInBookshelf ?? this.isInBookshelf,
      isShelfStateLoading: isShelfStateLoading ?? this.isShelfStateLoading,
      isShelfActionLoading: isShelfActionLoading ?? this.isShelfActionLoading,
      localBookMeta:
          clearLocalBookMeta ? null : (localBookMeta ?? this.localBookMeta),
      readingProgress:
          clearReadingProgress
              ? null
              : (readingProgress ?? this.readingProgress),
      showLocalAdvancedOptions:
          showLocalAdvancedOptions ?? this.showLocalAdvancedOptions,
    );
  }
}

enum _EditableCoverAction { gallery, files, focusLink, clear }

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  static const List<_LocalCharsetOption> _kLocalCharsetOptions =
      <_LocalCharsetOption>[
        _LocalCharsetOption(label: '自动', charset: null),
        _LocalCharsetOption(label: 'UTF-8', charset: 'utf-8'),
        _LocalCharsetOption(label: 'UTF-16LE', charset: 'utf-16le'),
        _LocalCharsetOption(label: 'UTF-16BE', charset: 'utf-16be'),
        _LocalCharsetOption(label: 'GBK', charset: 'gbk'),
        _LocalCharsetOption(label: 'GB18030', charset: 'gb18030'),
        _LocalCharsetOption(label: 'Big5', charset: 'big5'),
      ];
  late final ContentProviderRegistry _contentProviderRegistry;
  late final BookshelfService _bookshelfService;
  late final SearchService _switchSourceSearchService;
  late final BookDetailSwitchSourceHelper _switchSourceHelper;
  final ValueNotifier<_BookDetailPresentationState> _presentationStateNotifier =
      ValueNotifier<_BookDetailPresentationState>(
        const _BookDetailPresentationState(),
      );
  final ValueNotifier<_BookDetailAuxiliaryState> _auxiliaryStateNotifier =
      ValueNotifier<_BookDetailAuxiliaryState>(
        const _BookDetailAuxiliaryState(),
      );
  late final Listenable _detailStateListenable = Listenable.merge(<Listenable>[
    _presentationStateNotifier,
    _auxiliaryStateNotifier,
  ]);

  bool _isSwitchingSource = false;
  bool _manualTocReversed = false;
  bool _isEditingMetadata = false;
  bool _isSavingMetadata = false;
  String? _metadataInlineNotice;
  List<BookshelfTaxonomyItem> _detailTags = const <BookshelfTaxonomyItem>[];
  BookshelfTaxonomyItem? _detailCategory;
  int _detailLoadRequestToken = 0;
  SearchCancellationToken? _activeSwitchSourceCancellationToken;
  String? _activeSourceId;
  String? _activeDetailUrl;
  String _activeBookId = '';
  String? _displayTitle;
  BookMetadataOverride? _metadataOverride;
  int _metadataMutationEpoch = 0;
  bool _pendingInitialEditMode = false;
  StreamSubscription<LocalBookIndexEvent>? _localIndexEventSubscription;
  late final SearchHitCacheService _searchHitCacheService;
  final SourceSwitchScoreService _switchSourceScoreService =
      SourceSwitchScoreService();
  late final BookmarkRepository _bookmarkRepository;
  late final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  late final BookLocalMetadataService _localMetadataService;
  late final BookMetadataEditService _bookMetadataEditService;
  late final BookDetailMetadataFlowService _metadataFlowService;
  late final BookDetailActionService _actionService;
  late final BookDetailCatalogService _catalogService;
  late final BookDetailService _bookDetailService;
  late final BookReadingStatusService _bookReadingStatusService;
  late final AppLogger _logger;
  final Stopwatch _detailOpenStopwatch = Stopwatch()..start();
  final BookDisplayStateResolver _bookMetadataPresentationResolver =
      const BookDisplayStateResolver();
  final BookReadingStatusPresentationMapper _readingStatusPresentationMapper =
      const BookReadingStatusPresentationMapper();
  final OnlineSourceErrorPresentationAdapter _onlineSourceErrorAdapter =
      const OnlineSourceErrorPresentationAdapter();
  late final ReaderSystemSettingsService _readerSystemSettingsService;
  late final LocalBookStorageService _localBookStorageService;
  late final ReaderPreferencesService _readerPreferencesService;
  late final ReadingRecordService _readingRecordService;
  late final LocalBookIndexService _localBookIndexService;
  late final BookDetailReadRouteService _readRouteService;
  late final RemoteContentTaskConflictService _taskConflictService;
  late final RemoteContentTaskSchedulerService _taskScheduler;
  final TextEditingController _editTitleController = TextEditingController();
  final TextEditingController _editAuthorController = TextEditingController();
  final TextEditingController _editCoverController = TextEditingController();
  final TextEditingController _editIntroController = TextEditingController();
  final FocusNode _editCoverFocusNode = FocusNode();
  String? _editingCoverPath;
  String? _editingCharset;
  bool _editingSplitLongChapter = true;
  bool _defaultSplitLongChapterEnabled = true;
  bool _hasLoggedDetailBodyVisible = false;
  DateTime? _lastReadActionAt;
  bool _isDetailExitAnimating = false;
  final ScrollController _detailScrollController = ScrollController();
  double _detailScrollOffset = 0;
  String? _catalogSearchCacheFingerprint;
  Map<String, List<ReaderCatalogSearchEntry>> _catalogSearchEntriesCache =
      const <String, List<ReaderCatalogSearchEntry>>{};

  @override
  void initState() {
    super.initState();
    _editCoverController.addListener(_handleEditCoverTextChanged);
    _pendingInitialEditMode = widget.initialEditMode;
    _logger = ref.read(app_providers.appLoggerProvider);
    final dependencies = ref.read(bookDetailDependenciesProvider);
    _bookmarkRepository = ref.read(bookBookmarkRepositoryProvider);
    _bookMetadataOverrideRepository = ref.read(
      bookMetadataOverrideRepositoryProvider,
    );
    _localMetadataService = ref.read(bookLocalMetadataServiceProvider);
    _bookMetadataEditService = dependencies.bookMetadataEditService;
    _metadataFlowService = dependencies.metadataFlowService;
    _bookReadingStatusService = dependencies.readingStatusService;
    _actionService = dependencies.actionService;
    _catalogService = dependencies.catalogService;
    _taskConflictService = ref.read(bookTaskConflictServiceProvider);
    _taskScheduler = ref.read(bookTaskSchedulerProvider);
    _searchHitCacheService = dependencies.searchHitCacheService;
    _readerSystemSettingsService = dependencies.readerSystemSettingsService;
    _localBookStorageService = dependencies.localBookStorageService;
    _readerPreferencesService = dependencies.readerPreferencesService;
    _readingRecordService = dependencies.readingRecordService;
    _localBookIndexService = dependencies.localBookIndexService;
    _readRouteService = dependencies.readRouteService;
    _bookDetailService =
        widget.bookDetailService ?? dependencies.bookDetailService;
    _contentProviderRegistry = ContentProviderRegistry(
      providers: [
        LocalContentProvider(
          detailService: ref.read(bookLocalBookDetailServiceProvider),
          chapterContentService: ref.read(
            bookDetailLocalChapterContentServiceProvider,
          ),
          previewService: ref.read(bookDetailLocalBookPreviewServiceProvider),
        ),
        ServerGatewayContentProvider(
          gatewayService: ref.read(
            search_providers.serverBookGatewayServiceProvider,
          ),
          settingsService: ref.read(
            search_providers.searchSystemSettingsServiceProvider,
          ),
        ),
      ],
    );
    _bookshelfService =
        widget.bookshelfService ?? dependencies.bookshelfService;
    _switchSourceSearchService =
        widget.switchSourceSearchService ??
        dependencies.switchSourceSearchService;
    _switchSourceHelper = BookDetailSwitchSourceHelper(
      switchSourceSearchService: _switchSourceSearchService,
      searchHitCacheService: _searchHitCacheService,
      switchSourceScoreService: _switchSourceScoreService,
      sourceHealthService: ref.read(
        app_providers.appSourceHealthServiceProvider,
      ),
    );
    final initialBook = widget.initialBook;
    _activeSourceId =
        _normalizeRouteParam(widget.sourceId) ??
        _normalizeRouteParam(initialBook?.sourceId);
    _activeDetailUrl =
        _normalizeRouteParam(widget.detailUrl) ??
        _normalizeRouteParam(initialBook?.detailUrl);
    _activeBookId =
        widget.bookId.trim().isNotEmpty
            ? widget.bookId.trim()
            : (initialBook?.id.trim() ?? '');
    _detailScrollController.addListener(_handleDetailScrollChanged);
    _cancelBackgroundRefreshConflictForCurrentBook(
      byScene: RemoteContentConflictScene.detail,
    );
    _applyLocalSchemeFallback();
    _displayTitle =
        _normalizeRouteParam(widget.title) ??
        _normalizeRouteParam(initialBook?.title);
    final hydratedFromCache = _hydrateCachedDetailIfAvailable();
    if (!hydratedFromCache && !_isLocalContent) {
      _updatePresentationState(
        _presentationState.copyWith(isLoading: true, clearErrorText: true),
      );
    }
    _localIndexEventSubscription = LocalBookIndexService.watchEvents.listen(
      _handleLocalIndexEvent,
    );
    if (hydratedFromCache) {
      unawaited(
        _load(
          forceRefresh: true,
          backgroundRefresh: true,
          includeCatalog: _result?.catalogLoaded ?? true,
        ),
      );
    } else {
      if (_isLocalContent) {
        unawaited(_loadInitialLocalDetail());
      } else {
        unawaited(_load(includeCatalog: false));
      }
    }
  }

  @override
  void dispose() {
    _detailScrollController
      ..removeListener(_handleDetailScrollChanged)
      ..dispose();
    _detailLoadRequestToken += 1;
    _cancelActiveSwitchSourceSearch();
    _localIndexEventSubscription?.cancel();
    _editTitleController.dispose();
    _editAuthorController.dispose();
    _editCoverController
      ..removeListener(_handleEditCoverTextChanged)
      ..dispose();
    _editCoverFocusNode.dispose();
    _editIntroController.dispose();
    _presentationStateNotifier.dispose();
    _auxiliaryStateNotifier.dispose();
    super.dispose();
  }

  void _handleDetailScrollChanged() {
    if (!mounted) {
      return;
    }
    final offset =
        _detailScrollController.hasClients
            ? _detailScrollController.offset
            : 0.0;
    if ((offset - _detailScrollOffset).abs() < 0.5) {
      return;
    }
    setState(() {
      _detailScrollOffset = offset;
    });
  }

  void _handleEditCoverTextChanged() {
    if (!_isEditingMetadata || !mounted) {
      return;
    }
    final nextCover = _normalizeOptionalEditText(_editCoverController.text);
    if (nextCover == _editingCoverPath) {
      return;
    }
    setState(() {
      _editingCoverPath = nextCover;
    });
  }

  _BookDetailPresentationState get _presentationState =>
      _presentationStateNotifier.value;

  _BookDetailAuxiliaryState get _auxiliaryState =>
      _auxiliaryStateNotifier.value;

  bool get _isLoading => _presentationState.isLoading;

  bool get _isCatalogLoading => _presentationState.isCatalogLoading;

  String? get _errorText => _presentationState.errorText;

  String? get _tocWarningText => _presentationState.tocWarningText;

  BookDetailLoadResult? get _result => _presentationState.result;

  bool get _isInBookshelf => _auxiliaryState.isInBookshelf;

  LocalBook? get _localBookMeta => _auxiliaryState.localBookMeta;

  void _updatePresentationState(_BookDetailPresentationState nextState) {
    _presentationStateNotifier.value = nextState;
  }

  void _updateAuxiliaryState(_BookDetailAuxiliaryState nextState) {
    _auxiliaryStateNotifier.value = nextState;
  }

  void _updateDetailPageState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  Future<void> _maybeEnterInitialEditingMode() async {
    if (!_pendingInitialEditMode || _isEditingMetadata || _result == null) {
      return;
    }
    _pendingInitialEditMode = false;
    await _handleEditAction();
  }

  BookDisplayState _resolvePresentedMetadata({BookDetailLoadResult? result}) {
    final activeResult = result ?? _result;
    final detail = activeResult?.detail;
    return _bookMetadataPresentationResolver.resolve(
      fallbackTitle: detail?.title ?? _displayTitle ?? widget.title,
      fallbackAuthor: detail?.author,
      fallbackIntro: detail?.intro,
      realCoverUrl: detail?.coverUrl ?? widget.coverUrl,
      localBook: _localBookMeta,
      metadataOverride: _metadataOverride,
    );
  }

  @override
  Widget build(BuildContext context) => _buildBookDetailPage(context);

  void _handleBackNavigation([BuildContext? sourceContext]) {
    if (_isDetailExitAnimating) {
      return;
    }
    _updateDetailPageState(() {
      _isDetailExitAnimating = true;
    });
    Future<void> closeRoute() async {
      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go('/bookshelf');
    }

    final overlay =
        sourceContext == null
            ? null
            : CircularThemeRevealOverlay.of(sourceContext);
    if (sourceContext == null || overlay == null) {
      Future<void>.delayed(const Duration(milliseconds: 120), closeRoute);
      return;
    }
    final center = CircularThemeRevealOverlay.getCenterFromContext(
      sourceContext,
    );
    unawaited(
      overlay.startTransition(
        center: center,
        reverse: false,
        onThemeChange: () {
          unawaited(closeRoute());
        },
      ),
    );
  }

  String _buildReaderCoverHeroTag({
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) {
    return 'reader_cover_${sourceId.trim()}_${bookId.trim()}_${detailUrl.hashCode}';
  }

  void _setDetailExitAnimating(bool value) {
    if (!mounted || _isDetailExitAnimating == value) {
      return;
    }
    if (context.canPop()) {
      _updateDetailPageState(() {
        _isDetailExitAnimating = value;
      });
    } else {
      _isDetailExitAnimating = value;
    }
  }

  bool _hydrateCachedDetailIfAvailable() {
    final sourceId = _activeSourceId?.trim();
    final detailUrl = _activeDetailUrl?.trim();
    if (sourceId == null ||
        sourceId.isEmpty ||
        detailUrl == null ||
        detailUrl.isEmpty ||
        LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return false;
    }

    final cached = _bookDetailService.peekCached(
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
    if (cached == null || _shouldSkipCachedHydration(cached)) {
      return false;
    }

    _activeBookId = cached.detail.id.trim();
    _activeSourceId = cached.detail.sourceId.trim();
    _activeDetailUrl = cached.detail.detailUrl.trim();
    _displayTitle = cached.detail.title.trim();
    _updatePresentationState(
      _presentationState.copyWith(
        result: cached,
        clearErrorText: true,
        clearTocWarningText: true,
      ),
    );
    _recordDetailBodyVisible(result: cached, source: 'detail_cache');
    unawaited(
      _loadSupplementaryState(
        result: cached,
        loadRequestToken: _detailLoadRequestToken,
      ),
    );
    return true;
  }

  Future<void> _loadInitialLocalDetail() async {
    final hydrated = await _hydrateLocalBookSnapshotIfAvailable();
    if (!mounted || hydrated) {
      return;
    }
    _updatePresentationState(
      _presentationState.copyWith(isLoading: true, clearErrorText: true),
    );
    unawaited(_load(includeCatalog: false));
  }

  Future<bool> _hydrateLocalBookSnapshotIfAvailable() async {
    final sourceId = _activeSourceId?.trim();
    final detailUrl = _activeDetailUrl?.trim();
    if (sourceId == null ||
        sourceId.isEmpty ||
        detailUrl == null ||
        detailUrl.isEmpty ||
        !LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return false;
    }

    final provider = _contentProviderRegistry.findForSourceId(sourceId);
    if (provider is! LocalContentProvider) {
      return false;
    }

    final BookDetailLoadResult? result;
    try {
      result = await provider.loadBookSnapshotDetail(
        sourceId: sourceId,
        bookId: _activeBookId,
        detailUrl: detailUrl,
      );
    } catch (_) {
      return false;
    }
    if (!mounted || result == null || _result != null) {
      return false;
    }

    _activeBookId = result.detail.id.trim();
    _activeSourceId = result.detail.sourceId.trim();
    _activeDetailUrl = result.detail.detailUrl.trim();
    _displayTitle = result.detail.title.trim();
    _updatePresentationState(
      _presentationState.copyWith(
        result: result,
        clearErrorText: true,
        clearTocWarningText: true,
      ),
    );
    _recordDetailBodyVisible(result: result, source: 'local_book_snapshot');
    unawaited(_loadSupplementaryState(result: result));
    return true;
  }

  bool _shouldSkipCachedHydration(BookDetailLoadResult cached) {
    bool hasMeaningfulMismatch(String? routeValue, String? cachedValue) {
      final routeText = (routeValue ?? '').trim();
      if (routeText.isEmpty) {
        return false;
      }
      return routeText != (cachedValue ?? '').trim();
    }

    return hasMeaningfulMismatch(widget.title, cached.detail.title) ||
        hasMeaningfulMismatch(widget.author, cached.detail.author) ||
        hasMeaningfulMismatch(widget.coverUrl, cached.detail.coverUrl);
  }

  bool get _isMissingParams {
    return _activeSourceId == null ||
        _activeSourceId!.isEmpty ||
        _activeDetailUrl == null ||
        _activeDetailUrl!.isEmpty;
  }

  ContentCapabilities get _contentCapabilities {
    final sourceId = _activeSourceId?.trim();
    if (sourceId == null || sourceId.isEmpty) {
      return const ContentCapabilities();
    }
    final provider = _contentProviderRegistry.findForSourceId(sourceId);
    return provider?.capabilities ?? const ContentCapabilities();
  }

  bool get _isLocalContent => _contentCapabilities.canReindexLocal;

  bool get _canSwitchSource {
    final sourceId = (_activeSourceId ?? '').trim();
    final detailUrl = (_activeDetailUrl ?? '').trim();
    return !_isLocalContent &&
        _contentCapabilities.canSwitchSource &&
        sourceId.isNotEmpty &&
        detailUrl.isNotEmpty &&
        !_isSwitchingSource;
  }

  ImageProvider? _resolveDetailCoverBackdropProvider({
    required AppAdvancedTheme? activeAdvancedTheme,
  }) {
    if ((activeAdvancedTheme
            ?.configFor(
              Theme.of(context).brightness == Brightness.dark
                  ? AppAdvancedThemeMode.dark
                  : AppAdvancedThemeMode.light,
            )
            .wallpaperPath
            ?.trim()
            .isNotEmpty ??
        false)) {
      return null;
    }

    final presentation = _resolvePresentedMetadata();
    final resolvedCover = resolveBookCover(
      realCoverUrl: presentation.realCoverUrl,
      customCoverPath:
          presentation.customCoverPath ?? _localBookMeta?.coverPath,
      activeTheme: activeAdvancedTheme,
      galleries: ref.read(coverGalleriesProvider).valueOrNull ?? const [],
      brightness: Theme.of(context).brightness,
      bookId: _result?.detail.id ?? _activeBookId,
      sourceId: _result?.detail.sourceId ?? _activeSourceId,
      detailUrl: _result?.detail.detailUrl ?? _activeDetailUrl,
    );

    final filePath = resolvedCover.filePath?.trim() ?? '';
    final fileProvider = resolveLocalFileImageProvider(filePath);
    if (fileProvider != null) {
      return ResizeImage(fileProvider, width: 720);
    }

    final coverUrl = resolvedCover.imageUrl?.trim() ?? '';
    if (coverUrl.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(coverUrl);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    if (uri.scheme == 'file') {
      final uriFileProvider = resolveLocalFileImageProvider(
        localFilePathFromUri(uri),
      );
      if (uriFileProvider != null) {
        return ResizeImage(uriFileProvider, width: 720);
      }
      return null;
    }
    return ResizeImage(NetworkImage(coverUrl), width: 720);
  }

  ContentProvider _requireContentProvider({
    required String? sourceId,
    ErrorStage stage = ErrorStage.detail,
  }) {
    final normalized = (sourceId ?? '').trim();
    if (normalized.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: stage,
        briefMessage: '缺少 sourceId，无法加载详情。',
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

  Widget _buildDetailCard(
    BookDetailLoadResult result, {
    _BookDetailAuxiliaryState? auxiliaryState,
  }) {
    final detail = result.detail;
    final presentation = _resolvePresentedMetadata(result: result);
    final metrics = AppAdaptiveMetrics.of(context);
    final heroTag =
        widget.heroTag?.trim().isNotEmpty == true
            ? widget.heroTag!.trim()
            : _buildBookCoverHeroTag(
              bookId: detail.id,
              sourceId: detail.sourceId,
              detailUrl: detail.detailUrl,
            );
    final titleHeroTag =
        widget.titleHeroTag?.trim().isNotEmpty == true
            ? widget.titleHeroTag!.trim()
            : 'book_title_${detail.sourceId.trim()}_${detail.id.trim()}_${detail.detailUrl.hashCode}';
    final metaHeroTag =
        widget.metaHeroTag?.trim().isNotEmpty == true
            ? widget.metaHeroTag!.trim()
            : 'book_meta_${detail.sourceId.trim()}_${detail.id.trim()}_${detail.detailUrl.hashCode}';

    return BookDetailSummaryCard(
      title: presentation.displayTitle,
      sourceName: result.sourceName,
      author: _cleanSummaryMetaValue(presentation.displayAuthor),
      readingStatusText:
          !metrics.isMediumUpWindow && auxiliaryState != null
              ? _detailReadingStatusSummaryText(
                result: result,
                auxiliaryState: auxiliaryState,
              )
              : null,
      titleHeroTag: titleHeroTag,
      metaHeroTag: metaHeroTag,
      cover: _buildCoverPreview(
        presentation.realCoverUrl,
        customCoverPath: presentation.customCoverPath,
        title: presentation.displayTitle,
        author: presentation.displayAuthor,
        heroTag: heroTag,
        bookId: detail.id,
        sourceId: detail.sourceId,
        detailUrl: detail.detailUrl,
      ),
    );
  }

  Widget _buildDesktopCoverPane(BookDetailLoadResult result) {
    final detail = result.detail;
    final presentation = _resolvePresentedMetadata(result: result);
    final heroTag =
        widget.heroTag?.trim().isNotEmpty == true
            ? widget.heroTag!.trim()
            : _buildBookCoverHeroTag(
              bookId: detail.id,
              sourceId: detail.sourceId,
              detailUrl: detail.detailUrl,
            );
    return Center(
      child: _buildCoverPreview(
        presentation.realCoverUrl,
        customCoverPath: presentation.customCoverPath,
        title: presentation.displayTitle,
        author: presentation.displayAuthor,
        heroTag: heroTag,
        bookId: detail.id,
        sourceId: detail.sourceId,
        detailUrl: detail.detailUrl,
        coverWidth: AppAdaptiveMetrics.of(context).isMediumWindow ? 168 : 208,
      ),
    );
  }

  Widget _buildDesktopSummaryText({
    required BookDetailLoadResult result,
    required _BookDetailAuxiliaryState auxiliaryState,
  }) {
    final presentation = _resolvePresentedMetadata(result: result);
    final titleHeroTag =
        widget.titleHeroTag?.trim().isNotEmpty == true
            ? widget.titleHeroTag!.trim()
            : 'book_title_${result.detail.sourceId.trim()}_${result.detail.id.trim()}_${result.detail.detailUrl.hashCode}';
    final metaHeroTag =
        widget.metaHeroTag?.trim().isNotEmpty == true
            ? widget.metaHeroTag!.trim()
            : 'book_meta_${result.detail.sourceId.trim()}_${result.detail.id.trim()}_${result.detail.detailUrl.hashCode}';
    final authorText = _cleanSummaryMetaValue(presentation.displayAuthor);
    return BookDetailSummaryTextBlock(
      title: presentation.displayTitle,
      sourceName: result.sourceName,
      author: authorText,
      readingStatusText: _detailReadingStatusSummaryText(
        result: result,
        auxiliaryState: auxiliaryState,
      ),
      titleHeroTag: titleHeroTag,
      metaHeroTag: metaHeroTag,
      titleStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.14,
      ),
      metaAxis: Axis.horizontal,
    );
  }

  String? _cleanSummaryMetaValue(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized =
        _normalizeSingleLineText(
          raw,
        ).replaceFirst(RegExp(r'^(作者|来源|最新章节|最新)\s*[:：]\s*'), '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _resolveDisplayLatestChapterTitle(BookDetailLoadResult result) {
    final fromDetail = _normalizeLatestChapterCandidate(
      result.detail.latestChapterTitle,
    );
    if (fromDetail != null) {
      return fromDetail;
    }
    return _normalizeLatestChapterCandidate(
      _resolveLatestChapter(result)?.title,
    );
  }

  String? _normalizeLatestChapterCandidate(String? raw) {
    final normalized = _cleanSummaryMetaValue(raw);
    if (normalized == null || _looksLikeUpdateTime(normalized)) {
      return null;
    }
    final withoutLeadingUpdate =
        normalized
            .replaceFirst(
              RegExp(r'^\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}日?\s*(更新|更)?\s*'),
              '',
            )
            .trim();
    return withoutLeadingUpdate.isEmpty ? null : withoutLeadingUpdate;
  }

  bool _looksLikeUpdateTime(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return true;
    }
    return RegExp(r'^\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}日?$').hasMatch(normalized);
  }

  Widget _buildQuickActionsCard({
    required _BookDetailAuxiliaryState auxiliaryState,
    required bool hasCatalog,
  }) {
    return BookDetailQuickActionsCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return BookDetailPrimaryActions(
            availableWidth: constraints.maxWidth,
            isInBookshelf: auxiliaryState.isInBookshelf,
            isShelfStateLoading: auxiliaryState.isShelfStateLoading,
            isShelfActionLoading: auxiliaryState.isShelfActionLoading,
            onToggleBookshelf: _toggleBookshelf,
            onOpenCatalog:
                hasCatalog && _result != null ? _handleOpenCatalogAction : null,
            isCatalogEnabled: hasCatalog && !_isCatalogLoading,
            onSwitchSource: _canSwitchSource ? _handleSwitchSource : null,
            isSwitchSourceEnabled: _canSwitchSource,
            onOpenOrganize: _openOrganizeSheet,
            isOrganizeEnabled: auxiliaryState.isInBookshelf,
          );
        },
      ),
    );
  }

  String _detailReadingStatusSummaryText({
    required BookDetailLoadResult result,
    required _BookDetailAuxiliaryState auxiliaryState,
  }) {
    final status = _readingStatusOfDetail(
      result: result,
      auxiliaryState: auxiliaryState,
    );
    final label = _readingStatusLabel(status);
    return label;
  }

  BookReadingStatus _readingStatusOfDetail({
    required BookDetailLoadResult result,
    required _BookDetailAuxiliaryState auxiliaryState,
  }) {
    final progress = auxiliaryState.readingProgress;
    return _bookReadingStatusService.resolveStatus(
      progress: progress,
      progressValue: _detailReadingProgressValue(
        result: result,
        progress: progress,
      ),
      hasProgressDisplay: progress != null,
    );
  }

  double? _detailReadingProgressValue({
    required BookDetailLoadResult result,
    required ReadingProgress? progress,
  }) {
    if (progress == null) {
      return null;
    }
    final readableChapterCount =
        result.detail.totalChapterNum ??
        result.chapters.where((chapter) => !chapter.isVolume).length;
    if (readableChapterCount > 0) {
      final position =
          progress.chapterIndex + progress.chapterPositionRatio.clamp(0.0, 1.0);
      return (position / readableChapterCount).clamp(0.0, 1.0);
    }
    return progress.chapterPositionRatio.clamp(0.0, 1.0);
  }

  Future<void> _markDetailReadingStatus(
    BookDetailLoadResult result,
    BookReadingStatus status,
  ) async {
    if (_readingStatusOfDetail(
          result: result,
          auxiliaryState: _auxiliaryState,
        ) ==
        status) {
      _showMessage('当前已是${_readingStatusLabel(status)}。');
      return;
    }

    final localBook =
        _isLocalContent ? await _ensureEditableLocalBookMeta() : _localBookMeta;
    BookReadingStatusMarkResult? markResult;
    try {
      markResult = await _bookReadingStatusService.markBookDetailStatus(
        detail: result.detail,
        chapters: result.chapters,
        chaptersComplete: result.catalogComplete,
        status: status,
        existingProgress: _auxiliaryState.readingProgress,
        localBook: localBook,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('阅读状态保存失败，请重试。');
      return;
    }

    if (markResult == null) {
      if (mounted) {
        _showMessage('暂无可用章节，暂不能标记为${_readingStatusLabel(status)}。');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(
        clearReadingProgress: markResult.progress == null,
        readingProgress: markResult.progress,
      ),
    );
    _showMessage(
      markResult.progress == null
          ? '已标记为未读。'
          : '已标记为${_readingStatusLabel(status)}。',
    );
  }

  String _readingStatusLabel(BookReadingStatus status) {
    return _readingStatusPresentationMapper.resolve(status).label;
  }

  IconData _readingStatusIcon(BookReadingStatus status) {
    return _readingStatusPresentationMapper.resolve(status).icon;
  }

  Widget _buildDetailServerMetaLine(
    BookDetailLoadResult result, {
    bool includeUpdateTime = true,
    Set<String> excludedValues = const <String>{},
  }) {
    final detail = result.detail;
    return BookDetailServerMetaLine(
      wordCount: detail.wordCount,
      category: detail.category,
      tags: detail.tags,
      updateTime: detail.updateTime,
      includeUpdateTime: includeUpdateTime,
      excludedValues: excludedValues,
    );
  }

  Widget _buildMobileLatestMetaLine(
    BookDetailLoadResult result, {
    required Set<String> excludedValues,
  }) {
    final detail = result.detail;
    return BookDetailMobileLatestMetaLine(
      latestChapter: _resolveDisplayLatestChapterTitle(result),
      wordCount: detail.wordCount,
      category: detail.category,
      tags: detail.tags,
      excludedValues: excludedValues,
    );
  }

  Widget _buildDetailChapterStatusLine(BookDetailLoadResult result) {
    final detail = result.detail;
    return BookDetailChapterStatusLine(
      totalChapterNum:
          detail.totalChapterNum ??
          (result.chapters.isNotEmpty ? result.chapters.length : null),
      latestChapter: _resolveDisplayLatestChapterTitle(result),
    );
  }

  bool _hasDetailServerMeta(
    BookDetailLoadResult result, {
    bool includeUpdateTime = true,
    Set<String> excludedValues = const <String>{},
  }) {
    final detail = result.detail;
    final wordCount = _normalizeServerMetaDisplayValue(
      detail.wordCount,
      label: '字数',
    );
    final category = _normalizeServerMetaDisplayValue(
      detail.category,
      label: '分类',
    );
    final hasVisibleTag = detail.tags.any((item) {
      final normalized = _normalizeServerMetaDisplayValue(item, label: '标签');
      return normalized != null && !excludedValues.contains(normalized);
    });
    return (wordCount != null && !excludedValues.contains(wordCount)) ||
        (category != null && !excludedValues.contains(category)) ||
        hasVisibleTag ||
        (includeUpdateTime && (detail.updateTime?.trim().isNotEmpty ?? false));
  }

  bool _hasDetailChapterStatus(BookDetailLoadResult result) {
    final total =
        result.detail.totalChapterNum ??
        (result.chapters.isNotEmpty ? result.chapters.length : 0);
    return total > 0 ||
        (_resolveDisplayLatestChapterTitle(result)?.trim().isNotEmpty ?? false);
  }

  bool _hasMobileLatestMetaStatus(
    BookDetailLoadResult result, {
    required Set<String> excludedValues,
  }) {
    return (_resolveDisplayLatestChapterTitle(result)?.trim().isNotEmpty ??
            false) ||
        _hasDetailServerMeta(
          result,
          includeUpdateTime: false,
          excludedValues: excludedValues,
        );
  }

  String? _resolveDetailUpdateTimeText(BookDetailLoadResult result) {
    final detail = result.detail;
    final direct = _normalizeDetailUpdateTimeCandidate(detail.updateTime);
    if (direct != null) {
      return direct;
    }
    for (final candidate in <String?>[
      detail.wordCount,
      detail.category,
      ...detail.tags,
    ]) {
      final normalized = _normalizeDetailUpdateTimeCandidate(candidate);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  Set<String> _detailServerMetaExcludedValues(BookDetailLoadResult result) {
    final update = _resolveDetailUpdateTimeText(result);
    if (update == null || update.isEmpty) {
      return const <String>{};
    }
    final detail = result.detail;
    final excluded = <String>{update};

    void collect(String? raw, {required String label}) {
      final candidate = _normalizeDetailUpdateTimeCandidate(raw);
      if (candidate != update) {
        return;
      }
      final display = _normalizeServerMetaDisplayValue(raw, label: label);
      if (display != null) {
        excluded.add(display);
      }
    }

    collect(detail.wordCount, label: '字数');
    collect(detail.category, label: '分类');
    for (final tag in detail.tags) {
      collect(tag, label: '标签');
    }
    return excluded;
  }

  String? _normalizeServerMetaDisplayValue(
    String? raw, {
    required String label,
  }) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    var normalized = _normalizeSingleLineText(trimmed);
    final pattern = RegExp('^$label[：:]\\s*');
    while (pattern.hasMatch(normalized)) {
      normalized = normalized.replaceFirst(pattern, '').trim();
    }
    return normalized.isEmpty ? null : normalized;
  }

  String? _normalizeDetailUpdateTimeCandidate(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    var normalized = _normalizeSingleLineText(trimmed);
    for (final label in const ['更新时间', '更新日期', '更新', '时间', '日期']) {
      final pattern = RegExp('^$label[：:]\\s*');
      while (pattern.hasMatch(normalized)) {
        normalized = normalized.replaceFirst(pattern, '').trim();
      }
    }
    if (normalized.isEmpty) {
      return null;
    }
    final dateLikePattern = RegExp(
      r'^\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}日?'
      r'(?:[ T]\d{1,2}:\d{2}(?::\d{2})?)?$',
    );
    return dateLikePattern.hasMatch(normalized) ? normalized : null;
  }

  Widget _buildDetailOrganizationCard() {
    if (_detailCategory == null && _detailTags.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_detailCategory != null)
            _buildDetailTaxonomyChip(
              item: _detailCategory!,
              icon: Icons.folder_rounded,
            ),
          for (final tag in _detailTags)
            _buildDetailTaxonomyChip(item: tag, icon: Icons.sell_rounded),
        ],
      ),
    );
  }

  Widget _buildDetailTaxonomyChip({
    required BookshelfTaxonomyItem item,
    required IconData icon,
  }) {
    final color = Color(item.colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            item.name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildPresentedIntroCard(BookDetailLoadResult result) {
    final presentedIntro = _resolveIntro(
      _resolvePresentedMetadata(result: result).displayIntro,
    );
    if (presentedIntro == null) {
      return null;
    }
    return BookDetailIntroCard(intro: presentedIntro);
  }

  List<Widget> _buildLoadedContentSections({
    required _BookDetailPresentationState presentationState,
    required _BookDetailAuxiliaryState auxiliaryState,
    required BookDetailLoadResult result,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    final sections = <Widget>[
      if (presentationState.isLoading) ...[
        _buildInlineRefreshNotice(),
        SizedBox(height: metrics.sectionGap),
      ],
    ];

    if (_isEditingMetadata && !metrics.isMediumUpWindow) {
      sections.add(
        _buildMobileMetadataEditor(
          result: result,
          auxiliaryState: auxiliaryState,
        ),
      );
    } else {
      final introCard = _buildPresentedIntroCard(result);
      final localBookMeta = auxiliaryState.localBookMeta;
      final shouldShowLocalIndexStatus =
          _isLocalContent &&
          localBookMeta != null &&
          localBookMeta.indexStatus != LocalBookIndexStatus.ready;

      final detailCard = Transform.translate(
        offset: Offset(
          0,
          (-_detailScrollOffset.clamp(0.0, 80.0) * 0.1).clamp(-8.0, 0.0),
        ),
        child: _buildDetailCard(result, auxiliaryState: auxiliaryState),
      );
      final organizationCard = _buildDetailOrganizationCard();
      final quickActionsCard = _buildQuickActionsCard(
        auxiliaryState: auxiliaryState,
        hasCatalog: _canOpenCatalogForResult(result),
      );
      final serverMetaLine = _buildDetailServerMetaLine(result);
      final mobileMetaExcludedValues = _detailServerMetaExcludedValues(result);
      final mobileLatestMetaLine = _buildMobileLatestMetaLine(
        result,
        excludedValues: mobileMetaExcludedValues,
      );
      final chapterStatusLine = _buildDetailChapterStatusLine(result);
      final hasServerMeta = _hasDetailServerMeta(result);
      final hasMobileLatestMeta = _hasMobileLatestMetaStatus(
        result,
        excludedValues: mobileMetaExcludedValues,
      );
      final hasChapterStatus = _hasDetailChapterStatus(result);
      if (metrics.isMediumUpWindow) {
        final compactDesktop = metrics.isMediumWindow;
        final coverWidth = compactDesktop ? 188.0 : 240.0;
        final desktopMetaExcludedValues = _detailServerMetaExcludedValues(
          result,
        );
        final desktopLatestMetaLine = _buildMobileLatestMetaLine(
          result,
          excludedValues: desktopMetaExcludedValues,
        );
        final hasDesktopLatestMeta = _hasMobileLatestMetaStatus(
          result,
          excludedValues: desktopMetaExcludedValues,
        );
        sections.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: coverWidth,
                child: _buildDesktopCoverPane(result),
              ),
              SizedBox(width: metrics.sectionGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDesktopSummaryText(
                      result: result,
                      auxiliaryState: auxiliaryState,
                    ),
                    if (hasDesktopLatestMeta) ...[
                      SizedBox(height: metrics.sectionGap),
                      desktopLatestMetaLine,
                    ] else if (hasChapterStatus) ...[
                      SizedBox(height: metrics.sectionGap),
                      chapterStatusLine,
                    ],
                    SizedBox(height: metrics.sectionGap),
                    quickActionsCard,
                    if (introCard != null) ...[
                      SizedBox(height: metrics.sectionGap),
                      introCard,
                    ],
                    if (presentationState.tocWarningText != null) ...[
                      SizedBox(height: metrics.sectionGap),
                      _buildTocWarningCard(presentationState.tocWarningText!),
                    ],
                    if (hasServerMeta && !hasDesktopLatestMeta) ...[
                      SizedBox(height: metrics.sectionGap),
                      serverMetaLine,
                    ],
                    if (_detailCategory != null || _detailTags.isNotEmpty) ...[
                      SizedBox(height: metrics.sectionGap),
                      organizationCard,
                    ],
                    if (shouldShowLocalIndexStatus) ...[
                      SizedBox(height: metrics.sectionGap),
                      _buildLocalIndexStatusCard(localBookMeta),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        final mobileHeaderInset = metrics.isCompactDensity ? 4.0 : 6.0;
        sections.addAll(<Widget>[
          Padding(
            padding: EdgeInsets.only(left: mobileHeaderInset),
            child: detailCard,
          ),
          SizedBox(height: metrics.sectionGap),
          if (hasMobileLatestMeta) ...[
            Padding(
              padding: EdgeInsets.only(left: mobileHeaderInset),
              child: mobileLatestMetaLine,
            ),
            SizedBox(height: metrics.sectionGap),
          ],
          quickActionsCard,
          if (_detailCategory != null || _detailTags.isNotEmpty) ...[
            SizedBox(height: metrics.sectionGap),
            organizationCard,
          ],
          if (introCard != null) ...[
            SizedBox(height: metrics.sectionGap),
            introCard,
          ],
        ]);
      }

      sections.addAll(<Widget>[
        if (shouldShowLocalIndexStatus) ...[
          SizedBox(height: metrics.sectionGap),
          _buildLocalIndexStatusCard(localBookMeta),
        ],
      ]);
    }

    if (!metrics.isMediumUpWindow && presentationState.tocWarningText != null) {
      sections.addAll(<Widget>[
        SizedBox(height: metrics.sectionGap),
        _buildTocWarningCard(presentationState.tocWarningText!),
      ]);
    }
    return [
      for (var index = 0; index < sections.length; index++)
        // Stage the reveal so focus lands on shared summary first,
        // then actions, then supporting content.
        AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          opacity: _isDetailExitAnimating ? 0 : 1,
          child: AppFadeSlideTransition(
            delay: Duration(
              milliseconds: switch (index) {
                0 => 0,
                1 => 36,
                2 => 72,
                _ => (96 + (index - 3) * 20).clamp(96, 260).toInt(),
              },
            ),
            child: sections[index],
          ),
        ),
    ];
  }

  Widget _buildMobileMetadataEditor({
    required BookDetailLoadResult result,
    required _BookDetailAuxiliaryState auxiliaryState,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMobileEditableCover(result),
        const SizedBox(height: 18),
        _buildMobileEditTextField(
          controller: _editTitleController,
          label: '书名',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _buildMobileEditTextField(
          controller: _editAuthorController,
          label: '作者',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _buildMobileEditTextField(
          controller: _editCoverController,
          focusNode: _editCoverFocusNode,
          label: '封面链接',
          hintText: '可粘贴图片链接，或点击封面选择本地图片',
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          suffixIcon: IconButton(
            tooltip: '清空封面',
            onPressed: _isSavingMetadata ? null : _clearEditingCover,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        const SizedBox(height: 16),
        _buildMobileReadingStatusSegment(
          result: result,
          auxiliaryState: auxiliaryState,
        ),
        const SizedBox(height: 16),
        _buildMobileEditTextField(
          controller: _editIntroController,
          label: '简介',
          hintText: '输入书籍简介',
          minLines: 4,
          maxLines: 8,
          textInputAction: TextInputAction.newline,
        ),
        if (_isLocalContent && _localBookMeta != null) ...[
          const SizedBox(height: 18),
          _buildMobileEditingLocalOptions(),
        ],
      ],
    );
  }

  Widget _buildMobileEditableCover(BookDetailLoadResult result) {
    final detail = result.detail;
    final presentation = _resolvePresentedMetadata(result: result);
    final title =
        _editTitleController.text.trim().isEmpty
            ? presentation.displayTitle
            : _editTitleController.text.trim();
    final author =
        _editAuthorController.text.trim().isEmpty
            ? presentation.displayAuthor
            : _editAuthorController.text.trim();
    final heroTag =
        widget.heroTag?.trim().isNotEmpty == true
            ? widget.heroTag!.trim()
            : _buildBookCoverHeroTag(
              bookId: detail.id,
              sourceId: detail.sourceId,
              detailUrl: detail.detailUrl,
            );

    return Column(
      children: [
        _buildCoverPreview(
          presentation.realCoverUrl,
          customCoverPath: _editingCoverPath,
          title: title,
          author: author,
          heroTag: heroTag,
          bookId: detail.id,
          sourceId: detail.sourceId,
          detailUrl: detail.detailUrl,
          coverWidth: 128,
          onTap:
              _isSavingMetadata
                  ? null
                  : () => unawaited(_showEditableCoverActionSheet(result)),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed:
              _isSavingMetadata
                  ? null
                  : () => unawaited(_showEditableCoverActionSheet(result)),
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: const Text('点击封面更换'),
        ),
      ],
    );
  }

  Widget _buildMobileEditTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !_isSavingMetadata,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildMobileReadingStatusSegment({
    required BookDetailLoadResult result,
    required _BookDetailAuxiliaryState auxiliaryState,
  }) {
    final theme = Theme.of(context);
    final currentStatus = _readingStatusOfDetail(
      result: result,
      auxiliaryState: auxiliaryState,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '阅读状态',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<BookReadingStatus>(
            showSelectedIcon: false,
            selected: <BookReadingStatus>{currentStatus},
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
            segments: [
              for (final status in BookReadingStatus.values)
                ButtonSegment<BookReadingStatus>(
                  value: status,
                  label: Text(_readingStatusLabel(status)),
                  icon: Icon(_readingStatusIcon(status), size: 18),
                ),
            ],
            onSelectionChanged:
                _isSavingMetadata
                    ? null
                    : (values) {
                      if (values.isEmpty) {
                        return;
                      }
                      final next = values.first;
                      unawaited(_markDetailReadingStatus(result, next));
                    },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileEditingLocalOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本地图书高级项',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _editingCharset,
          decoration: InputDecoration(
            labelText: '编码',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: _kLocalCharsetOptions
              .map(
                (option) => DropdownMenuItem<String?>(
                  value: option.charset,
                  child: Text(option.label),
                ),
              )
              .toList(growable: false),
          onChanged:
              _isSavingMetadata
                  ? null
                  : (value) {
                    setState(() {
                      _editingCharset = value;
                    });
                  },
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('长章节拆分'),
          subtitle: const Text('保存后可选择重新索引使正文生效。'),
          value: _editingSplitLongChapter,
          onChanged:
              _isSavingMetadata
                  ? null
                  : (value) {
                    setState(() {
                      _editingSplitLongChapter = value;
                    });
                  },
        ),
      ],
    );
  }

  Widget _buildDesktopMetadataEditorDialog({
    required BuildContext surfaceContext,
    required BookDetailLoadResult result,
    required _BookDetailAuxiliaryState auxiliaryState,
    required VoidCallback refreshSurface,
    required VoidCallback onCancel,
    required Future<void> Function() onReset,
    required Future<void> Function() onSave,
  }) {
    final theme = Theme.of(surfaceContext);
    final colorScheme = theme.colorScheme;
    final presentation = _resolvePresentedMetadata(result: result);
    final title = presentation.displayTitle.trim();
    final author = (presentation.displayAuthor ?? '').trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '编辑书籍',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (title.isNotEmpty || author.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (title.isNotEmpty) title,
                          if (author.isNotEmpty) author,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: _isSavingMetadata ? null : onCancel,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                child: _buildDesktopEditableCover(
                  result,
                  refreshSurface: refreshSurface,
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDesktopEditTextField(
                      controller: _editTitleController,
                      label: '书名',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _buildDesktopEditTextField(
                      controller: _editAuthorController,
                      label: '作者',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _buildDesktopEditTextField(
                      controller: _editCoverController,
                      focusNode: _editCoverFocusNode,
                      label: '封面链接',
                      hintText: '可粘贴图片链接，或点击左侧封面选择本地图片',
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      suffixIcon: IconButton(
                        tooltip: '清空封面',
                        onPressed:
                            _isSavingMetadata
                                ? null
                                : () {
                                  _clearEditingCover();
                                  refreshSurface();
                                },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildDesktopReadingStatusSegment(
                      result: result,
                      auxiliaryState: auxiliaryState,
                      refreshSurface: refreshSurface,
                    ),
                    const SizedBox(height: 14),
                    _buildDesktopEditTextField(
                      controller: _editIntroController,
                      label: '简介',
                      hintText: '输入书籍简介',
                      minLines: 4,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                    ),
                    if (_isLocalContent && _localBookMeta != null) ...[
                      const SizedBox(height: 18),
                      _buildDesktopEditingLocalOptions(
                        refreshSurface: refreshSurface,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isLocalContent
                      ? '本地图书信息保存后会影响书架和阅读展示。'
                      : '在线书仅保存本地覆盖信息，不会修改书源数据。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: _isSavingMetadata ? null : onCancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed:
                    _isSavingMetadata ? null : () => unawaited(onReset()),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('恢复默认'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _isSavingMetadata ? null : () => unawaited(onSave()),
                icon:
                    _isSavingMetadata
                        ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_outlined, size: 18),
                label: Text(_isSavingMetadata ? '保存中' : '保存'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopEditableCover(
    BookDetailLoadResult result, {
    required VoidCallback refreshSurface,
  }) {
    final detail = result.detail;
    final heroTag =
        widget.heroTag?.trim().isNotEmpty == true
            ? widget.heroTag!.trim()
            : _buildBookCoverHeroTag(
              bookId: detail.id,
              sourceId: detail.sourceId,
              detailUrl: detail.detailUrl,
            );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _editTitleController,
        _editAuthorController,
        _editCoverController,
      ]),
      builder: (context, _) {
        final presentation = _resolvePresentedMetadata(result: result);
        final title =
            _editTitleController.text.trim().isEmpty
                ? presentation.displayTitle
                : _editTitleController.text.trim();
        final author =
            _editAuthorController.text.trim().isEmpty
                ? presentation.displayAuthor
                : _editAuthorController.text.trim();
        return Column(
          children: [
            _buildCoverPreview(
              presentation.realCoverUrl,
              customCoverPath: _editingCoverPath,
              title: title,
              author: author,
              heroTag: '${heroTag}_desktop_editor',
              bookId: detail.id,
              sourceId: detail.sourceId,
              detailUrl: detail.detailUrl,
              coverWidth: 176,
              onTap:
                  _isSavingMetadata
                      ? null
                      : () async {
                        await _showEditableCoverActionSheet(result);
                        refreshSurface();
                      },
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed:
                  _isSavingMetadata
                      ? null
                      : () async {
                        await _showEditableCoverActionSheet(result);
                        refreshSurface();
                      },
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('点击封面更换'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopEditTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    int minLines = 1,
    int maxLines = 1,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !_isSavingMetadata,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        isDense: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildDesktopReadingStatusSegment({
    required BookDetailLoadResult result,
    required _BookDetailAuxiliaryState auxiliaryState,
    required VoidCallback refreshSurface,
  }) {
    final theme = Theme.of(context);
    final currentStatus = _readingStatusOfDetail(
      result: result,
      auxiliaryState: auxiliaryState,
    );
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            '阅读状态',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SegmentedButton<BookReadingStatus>(
            showSelectedIcon: false,
            selected: <BookReadingStatus>{currentStatus},
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            segments: [
              for (final status in BookReadingStatus.values)
                ButtonSegment<BookReadingStatus>(
                  value: status,
                  label: Text(_readingStatusLabel(status)),
                  icon: Icon(_readingStatusIcon(status), size: 18),
                ),
            ],
            onSelectionChanged:
                _isSavingMetadata
                    ? null
                    : (values) {
                      if (values.isEmpty) {
                        return;
                      }
                      unawaited(
                        _markDetailReadingStatus(
                          result,
                          values.first,
                        ).then((_) => refreshSurface()),
                      );
                    },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopEditingLocalOptions({
    required VoidCallback refreshSurface,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本地图书高级项',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _editingCharset,
                decoration: InputDecoration(
                  labelText: '编码',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: _kLocalCharsetOptions
                    .map(
                      (option) => DropdownMenuItem<String?>(
                        value: option.charset,
                        child: Text(option.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    _isSavingMetadata
                        ? null
                        : (value) {
                          setState(() {
                            _editingCharset = value;
                          });
                          refreshSurface();
                        },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('长章节拆分'),
                subtitle: const Text('保存后可选择重新索引。'),
                value: _editingSplitLongChapter,
                onChanged:
                    _isSavingMetadata
                        ? null
                        : (value) {
                          setState(() {
                            _editingSplitLongChapter = value;
                          });
                          refreshSurface();
                        },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _buildReadFloatingActionButton(BookDetailLoadResult result) {
    final readableChapters = _readableChapters(result.chapters);
    final fallbackRoute = _buildFallbackReadRoute(result);
    if (readableChapters.isEmpty &&
        fallbackRoute == null &&
        !result.catalogAvailable) {
      return null;
    }
    final button = FloatingActionButton.extended(
      key: const Key('book_detail_read_button'),
      onPressed:
          readableChapters.isNotEmpty
              ? () => _handleStartReading(chapter: readableChapters.first)
              : () => _handleStartReading(fallbackRoute: fallbackRoute),
      icon: const Icon(Icons.chrome_reader_mode_outlined),
      label: const Text('开始阅读'),
    );
    return AnimatedSlide(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      offset: _isDetailExitAnimating ? const Offset(0, 0.06) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        opacity: _isDetailExitAnimating ? 0 : 1,
        child: button,
      ),
    );
  }

  Future<void> _handleStartReading({
    Chapter? chapter,
    String? fallbackRoute,
  }) async {
    final now = DateTime.now();
    final previous = _lastReadActionAt;
    if (previous != null &&
        now.difference(previous) < const Duration(milliseconds: 300)) {
      return;
    }
    _lastReadActionAt = now;
    unawaited(HapticFeedback.lightImpact());

    if (chapter != null) {
      _openChapter(chapter);
      return;
    }

    final currentResult = _result;
    if (currentResult != null && _canOpenCatalogForResult(currentResult)) {
      final loadedResult = await _ensureFirstReadableCatalogBatch(
        currentResult,
      );
      if (!mounted || loadedResult == null) {
        return;
      }
      final readableChapters = _readableChapters(loadedResult.chapters);
      if (readableChapters.isNotEmpty) {
        _openChapter(readableChapters.first, warmCompleteCatalog: true);
        return;
      }
      _showMessage('当前目录没有可阅读的正文章节。');
      return;
    }

    final normalizedFallback = (fallbackRoute ?? '').trim();
    if (normalizedFallback.isEmpty) {
      return;
    }
    _setDetailExitAnimating(true);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      context.push(normalizedFallback);
      _setDetailExitAnimating(false);
    });
  }

  Widget _buildDetailLoadingSkeleton({
    String? title,
    String? author,
    String? coverUrl,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedTitle = (title ?? '').trim();
    final normalizedAuthor = (author ?? '').trim();
    final normalizedCover = (coverUrl ?? '').trim();

    Widget block({
      required double height,
      double? width,
      BorderRadius? borderRadius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: borderRadius ?? BorderRadius.circular(10),
        ),
      );
    }

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (normalizedTitle.isNotEmpty || normalizedCover.isNotEmpty)
                  _buildCoverPreview(
                    normalizedCover.isEmpty ? null : normalizedCover,
                    title:
                        normalizedTitle.isEmpty ? '加载书籍详情中' : normalizedTitle,
                    author: normalizedAuthor.isEmpty ? null : normalizedAuthor,
                    heroTag: 'book_loading_${widget.bookId}',
                    bookId: widget.bookId,
                    sourceId: widget.sourceId,
                    detailUrl: widget.detailUrl,
                  )
                else
                  block(
                    width: 104,
                    height: 148,
                    borderRadius: BorderRadius.circular(16),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (normalizedTitle.isNotEmpty)
                        Text(
                          normalizedTitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        )
                      else
                        block(height: 22, width: double.infinity),
                      const SizedBox(height: 12),
                      if (normalizedAuthor.isNotEmpty)
                        Text(
                          normalizedAuthor,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        )
                      else
                        block(height: 16, width: 160),
                      const SizedBox(height: 8),
                      block(height: 16, width: 130),
                      const SizedBox(height: 8),
                      block(height: 16, width: 200),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              block(height: 18, width: 48),
              const SizedBox(height: 10),
              block(height: 14, width: double.infinity),
              const SizedBox(height: 8),
              block(height: 14, width: double.infinity),
              const SizedBox(height: 8),
              block(height: 14, width: 220),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInitialLoadingContent({
    required _BookDetailAuxiliaryState auxiliaryState,
  }) {
    final routePreviewTitle = (widget.title ?? '').trim();
    final bootstrapTitle =
        (_displayTitle ?? widget.title ?? '').trim().isNotEmpty
            ? (_displayTitle ?? widget.title ?? '').trim()
            : '加载书籍详情中';
    final bootstrapAuthor = (widget.author ?? '').trim();
    final bootstrapCover = (widget.coverUrl ?? '').trim();
    final hasRoutePreview =
        routePreviewTitle.isNotEmpty ||
        bootstrapAuthor.isNotEmpty ||
        bootstrapCover.isNotEmpty;

    final detailSkeleton =
        hasRoutePreview
            ? _buildDetailLoadingSkeleton(
              title: bootstrapTitle,
              author: bootstrapAuthor.isEmpty ? null : bootstrapAuthor,
              coverUrl: bootstrapCover.isEmpty ? null : bootstrapCover,
            )
            : _buildDetailLoadingSkeleton();

    return Column(
      children: [
        detailSkeleton,
        const SizedBox(height: 12),
        _buildQuickActionsCard(
          auxiliaryState: auxiliaryState,
          hasCatalog: false,
        ),
      ],
    );
  }

  Widget _buildInlineRefreshNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '正在刷新最新详情…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataInlineNoticeCard(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              if (!mounted) {
                return;
              }
              setState(() {
                _metadataInlineNotice = null;
              });
            },
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeText(String text) {
    var normalized = text
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'\{\{[^{}]*\}\}'), '')
        .replaceAll(RegExp(r'\{\{[^\n\r]*'), '');

    if (RegExp(r'<[^>]+>').hasMatch(normalized)) {
      normalized = html_parser.parseFragment(normalized).text ?? '';
    }

    normalized =
        normalized
            .replaceAll(RegExp(r'[ \t\u00A0]+'), ' ')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();

    return normalized;
  }

  List<Chapter> _buildDisplayedChapters(List<Chapter> chapters) {
    return _catalogService.buildDisplayedChapters(
      chapters,
      reversed: _manualTocReversed,
    );
  }

  String? _normalizeRouteParam(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _normalizeOptionalEditText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  void _applyLocalSchemeFallback() {
    final sourceId = (_activeSourceId ?? '').trim();
    final detailUrl = (_activeDetailUrl ?? '').trim();

    if (sourceId.isEmpty && LocalReaderIdentity.isLocalSchemeUrl(detailUrl)) {
      _activeSourceId = LocalReaderIdentity.localSourceId;
    }

    if (!LocalReaderIdentity.isLocalSourceId(_activeSourceId)) {
      return;
    }

    if (detailUrl.isEmpty || !LocalReaderIdentity.isLocalSchemeUrl(detailUrl)) {
      final normalizedBookId = _activeBookId.trim();
      if (normalizedBookId.isNotEmpty) {
        _activeDetailUrl = LocalReaderIdentity.buildBookDetailUrl(
          normalizedBookId,
        );
      }
    }
  }

  Future<void> _handleSwitchSource() async {
    if (_isSwitchingSource) {
      return;
    }

    final currentSourceId = _activeSourceId?.trim();
    final currentDetailUrl = _activeDetailUrl?.trim();
    if (currentSourceId == null ||
        currentSourceId.isEmpty ||
        currentDetailUrl == null ||
        currentDetailUrl.isEmpty) {
      _showMessage('缺少当前书源信息，暂时无法换源。');
      return;
    }

    final keyword = await _switchSourceHelper.resolveSearchKeyword(
      currentTitle: (_result?.detail.title ?? _displayTitle ?? '').trim(),
      reloadTitle: (currentTitle) async {
        final detailProvider = _requireContentProvider(
          sourceId: currentSourceId,
          stage: ErrorStage.detail,
        );
        final detailResult = await detailProvider.loadDetail(
          sourceId: currentSourceId,
          bookId: _activeBookId,
          detailUrl: currentDetailUrl,
          fallbackTitle: currentTitle.isEmpty ? null : currentTitle,
          includeCatalog: false,
        );
        return detailResult.detail.title;
      },
      onResolvedTitle: (refreshedTitle) {
        if (mounted && refreshedTitle != _displayTitle) {
          setState(() {
            _displayTitle = refreshedTitle;
          });
        } else {
          _displayTitle = refreshedTitle;
        }
      },
    );
    if (!mounted) {
      return;
    }
    if (keyword == null) {
      _showMessage('当前书名为空或仍在加载，暂时无法换源。');
      return;
    }
    final author = _result?.detail.author?.trim();

    BookDetailSwitchSourceScope scope;
    try {
      scope = await _switchSourceHelper.buildScope(
        currentSourceId: currentSourceId,
      );
      if (scope.sourceIds.isEmpty && !scope.allowUnscopedSearch) {
        _showMessage('暂无可切换的同类型书源。');
        return;
      }
    } on AppException catch (error) {
      _showMessage('查找可切换书源失败：${error.briefMessage}');
      return;
    } catch (_) {
      _showMessage('查找可切换书源失败，请稍后重试。');
      return;
    }

    final scoreStore = await _switchSourceHelper.loadScoreStoreSafely();
    const scoreRankingEnabled = true;
    if (!mounted) {
      return;
    }

    final lookupStateNotifier = ValueNotifier<SwitchSourceLookupState>(
      SwitchSourceLookupState.loading(
        sourceCount: scope.sourceIds.length,
        scoreRankingEnabled: scoreRankingEnabled,
      ),
    );
    final cancellationToken = SearchCancellationToken();
    _cancelActiveSwitchSourceSearch();
    _activeSwitchSourceCancellationToken = cancellationToken;

    setState(() {
      _isSwitchingSource = true;
    });

    final searchFuture = _switchSourceHelper.loadCandidatesProgressively(
      keyword: keyword,
      author: author,
      scope: scope,
      currentSourceId: currentSourceId,
      currentChapterCount: _result?.chapters.length ?? 0,
      lookupStateNotifier: lookupStateNotifier,
      cancellationToken: cancellationToken,
      scoreStore: scoreStore,
      scoreRankingEnabled: scoreRankingEnabled,
    );

    SwitchSourceCandidate? selected;
    try {
      if (mounted) {
        selected = await _showSwitchSourceCandidateSheet(
          lookupStateNotifier,
          scoreStore: scoreStore,
          scoreRankingEnabled: scoreRankingEnabled,
        );
      }
    } finally {
      cancellationToken.cancel();
      if (identical(_activeSwitchSourceCancellationToken, cancellationToken)) {
        _activeSwitchSourceCancellationToken = null;
      }
      unawaited(searchFuture.whenComplete(lookupStateNotifier.dispose));
      if (mounted) {
        setState(() {
          _isSwitchingSource = false;
        });
      }
    }

    if (selected == null || !mounted) {
      return;
    }

    try {
      final switchResult = await _switchToCandidateSource(selected);
      switch (switchResult) {
        case _DetailSwitchSourceApplyResult.switched:
          _showMessage('已切换到 ${selected.sourceName}。');
          break;
        case _DetailSwitchSourceApplyResult.switchedWithBookshelfSyncFailed:
          _showMessage('已换源，但书架同步失败，请稍后重试。');
          break;
        case _DetailSwitchSourceApplyResult.failed:
          _showMessage('切换书源失败，已保留当前书源。');
          break;
      }
    } on AppException catch (error) {
      if (mounted) {
        _showMessage('查找可切换书源失败：${error.briefMessage}');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('切换书源失败，请稍后重试。');
      }
    }
  }

  Future<SwitchSourceCandidate?> _showSwitchSourceCandidateSheet(
    ValueNotifier<SwitchSourceLookupState> lookupStateNotifier, {
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    return showSwitchSourceCandidateSheet(
      context: context,
      lookupStateNotifier: lookupStateNotifier,
      currentTitle: (_result?.detail.title ?? _displayTitle ?? '').trim(),
      currentChapterCount: _result?.chapters.length ?? 0,
      onScoreAction: (candidate, action) {
        return _switchSourceHelper.applyScoreAction(
          candidate: candidate,
          action: action,
          lookupStateNotifier: lookupStateNotifier,
          scoreStore: scoreStore,
          scoreRankingEnabled: scoreRankingEnabled,
          onMessage: _showMessage,
        );
      },
    );
  }

  Future<_DetailSwitchSourceApplyResult> _switchToCandidateSource(
    SwitchSourceCandidate candidate,
  ) async {
    final previousSourceId = _activeSourceId;
    final previousDetailUrl = _activeDetailUrl;
    final previousBookId = _activeBookId;
    final previousTitle = _displayTitle;
    final previousResult = _result;
    final previousErrorText = _errorText;
    final previousTocWarning = _tocWarningText;
    final previousInBookshelf = _isInBookshelf;
    final previousReadableChapter = _firstReadableChapter(
      previousResult?.chapters,
    );

    _activeSourceId = candidate.book.sourceId.trim();
    _activeDetailUrl = candidate.book.detailUrl.trim();
    _activeBookId = candidate.book.id.trim();
    _displayTitle = candidate.book.title.trim();

    final switched = await _load(
      forceRefresh: true,
      clearResult: true,
      includeCatalog: false,
    );
    if (switched) {
      final bookshelfSyncFailed = await _migrateBookshelfAfterSwitch(
        previousSourceId: previousSourceId,
        previousDetailUrl: previousDetailUrl,
        previousInBookshelf: previousInBookshelf,
      );
      await _syncReadingStateAfterSwitch(
        previousBookId: previousBookId,
        previousReadableChapter: previousReadableChapter,
      );
      if (mounted) {
        setState(() {
          _manualTocReversed = false;
        });
      }
      if (bookshelfSyncFailed) {
        return _DetailSwitchSourceApplyResult.switchedWithBookshelfSyncFailed;
      }
      return _DetailSwitchSourceApplyResult.switched;
    }

    if (mounted) {
      _activeSourceId = previousSourceId;
      _activeDetailUrl = previousDetailUrl;
      _activeBookId = previousBookId;
      _displayTitle = previousTitle;
      _updatePresentationState(
        _presentationState.copyWith(
          result: previousResult,
          errorText: previousErrorText,
          tocWarningText: previousTocWarning,
        ),
      );
      _updateAuxiliaryState(
        _auxiliaryState.copyWith(isInBookshelf: previousInBookshelf),
      );
    }
    return _DetailSwitchSourceApplyResult.failed;
  }

  Future<bool> _migrateBookshelfAfterSwitch({
    required String? previousSourceId,
    required String? previousDetailUrl,
    required bool previousInBookshelf,
  }) async {
    final result = _result;
    final normalizedPreviousSourceId = previousSourceId?.trim() ?? '';
    final normalizedPreviousDetailUrl = previousDetailUrl?.trim() ?? '';
    if (result == null ||
        normalizedPreviousSourceId.isEmpty ||
        normalizedPreviousDetailUrl.isEmpty) {
      return false;
    }

    var shouldReplace = previousInBookshelf;
    if (!shouldReplace) {
      try {
        shouldReplace = await _bookshelfService.contains(
          sourceId: normalizedPreviousSourceId,
          detailUrl: normalizedPreviousDetailUrl,
        );
      } catch (_) {
        shouldReplace = false;
      }
    }
    if (!shouldReplace) {
      return false;
    }

    try {
      final detail = result.detail;
      await _bookshelfService.replace(
        previousSourceId: normalizedPreviousSourceId,
        previousDetailUrl: normalizedPreviousDetailUrl,
        preserveTags: true,
        nextBook: BookshelfBook(
          bookId: detail.id,
          sourceId: detail.sourceId,
          title: detail.title,
          detailUrl: detail.detailUrl,
          author: detail.author,
          coverUrl: detail.coverUrl,
          addedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        _updateAuxiliaryState(_auxiliaryState.copyWith(isInBookshelf: true));
      }
      return false;
    } catch (_) {
      unawaited(_loadSupplementaryState(result: result));
      return true;
    }
  }

  Future<void> _syncReadingStateAfterSwitch({
    required String previousBookId,
    required Chapter? previousReadableChapter,
  }) async {
    final result = _result;
    final sourceId = (_activeSourceId ?? '').trim();
    final detailUrl = (_activeDetailUrl ?? '').trim();
    final nextBookId = _activeBookId.trim();
    if (result == null ||
        previousBookId.trim().isEmpty ||
        nextBookId.isEmpty ||
        previousBookId.trim() == nextBookId ||
        sourceId.isEmpty ||
        detailUrl.isEmpty) {
      return;
    }

    final fallbackChapter =
        _firstReadableChapter(result.chapters) ??
        Chapter(
          id: '',
          bookId: nextBookId,
          title: result.detail.title,
          chapterUrl: '',
          index: 0,
        );

    final chapter = previousReadableChapter ?? fallbackChapter;
    final normalizedChapterUrl = chapter.chapterUrl.trim();
    final normalizedChapterId = chapter.id.trim();
    final chapterTitle =
        chapter.title.trim().isEmpty
            ? result.detail.title
            : chapter.title.trim();
    final chapterIndex = chapter.index;

    if (normalizedChapterUrl.isNotEmpty && normalizedChapterId.isNotEmpty) {
      try {
        await _readerPreferencesService.migrateProgress(
          previousBookId: previousBookId,
          nextProgress: ReadingProgress(
            bookId: nextBookId,
            sourceId: sourceId,
            detailUrl: detailUrl,
            chapterId: normalizedChapterId,
            chapterUrl: normalizedChapterUrl,
            chapterTitle: chapterTitle,
            chapterIndex: chapterIndex,
            updatedAt: DateTime.now(),
            chapterPositionRatio: 0,
          ),
        );
      } catch (_) {
        // Keep source switch success even if progress migration fails.
      }
    }

    try {
      await _readingRecordService.reassignBookIdentity(
        previousBookId: previousBookId,
        nextBookId: nextBookId,
        nextSourceId: sourceId,
        nextDetailUrl: detailUrl,
        nextBookTitle: result.detail.title,
        nextBookAuthor: result.detail.author,
        nextCoverUrl: result.detail.coverUrl,
      );
    } catch (_) {
      // Keep source switch success even if reading record migration fails.
    }
  }

  Chapter? _firstReadableChapter(List<Chapter>? chapters) {
    if (chapters == null) {
      return null;
    }
    for (final chapter in chapters) {
      if (!chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty) {
        return chapter;
      }
    }
    return null;
  }

  void _openChapter(Chapter chapter, {bool warmCompleteCatalog = false}) {
    if (chapter.isVolume || chapter.chapterUrl.trim().isEmpty) {
      _showMessage('当前节点是分卷标题，不能直接阅读。');
      return;
    }

    final sourceId = _activeSourceId;
    final detailUrl = _activeDetailUrl;
    if (sourceId == null ||
        sourceId.isEmpty ||
        detailUrl == null ||
        detailUrl.isEmpty) {
      _showMessage('来源信息缺失，暂时无法开始阅读。');
      return;
    }
    _cancelBackgroundRefreshConflictForCurrentBook(
      byScene: RemoteContentConflictScene.reader,
    );
    final route = _readRouteService.buildChapterRoute(
      bookId: _activeBookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      chapter: chapter,
      heroTag: _buildReaderCoverHeroTag(
        bookId: _activeBookId,
        sourceId: sourceId,
        detailUrl: detailUrl,
      ),
    );
    if (route == null) {
      _showMessage('当前章节暂不可阅读。');
      return;
    }

    _setDetailExitAnimating(true);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      context.push(route);
      _setDetailExitAnimating(false);
      if (warmCompleteCatalog) {
        _scheduleCompleteCatalogWarmupAfterReaderOpen();
      }
    });
  }

  Future<bool> _load({
    bool forceRefresh = false,
    bool clearResult = false,
    bool backgroundRefresh = false,
    bool? includeCatalog,
  }) async {
    if (!mounted || _isMissingParams) {
      return false;
    }
    _cancelBackgroundRefreshConflictForCurrentBook(
      byScene: RemoteContentConflictScene.detail,
    );
    final lease = await _taskScheduler.acquire(
      scene: RemoteContentTaskScene.detail,
      conflictKeys: _currentConflictKeys(),
    );
    if (lease == null) {
      return false;
    }
    final requestToken = ++_detailLoadRequestToken;
    final shouldIncludeCatalog =
        includeCatalog ?? (_result?.catalogLoaded ?? false);

    final shouldShowLoading = !backgroundRefresh || _result == null;
    final nextPresentationBeforeLoad = _presentationState.copyWith(
      isLoading: shouldShowLoading ? true : _presentationState.isLoading,
      clearErrorText: !backgroundRefresh,
      clearTocWarningText: !backgroundRefresh,
      clearResult: clearResult,
    );
    _updatePresentationState(nextPresentationBeforeLoad);
    if (!backgroundRefresh || _result == null || clearResult) {
      _updateAuxiliaryState(
        _auxiliaryState.copyWith(isShelfStateLoading: true),
      );
    }

    try {
      final detailProvider = _requireContentProvider(
        sourceId: _activeSourceId,
        stage: ErrorStage.detail,
      );
      final result = await detailProvider.loadDetail(
        sourceId: _activeSourceId!,
        bookId: _activeBookId,
        detailUrl: _activeDetailUrl!,
        initialBook: widget.initialBook,
        fallbackTitle: _displayTitle ?? widget.title,
        fallbackAuthor: _result?.detail.author ?? widget.author,
        forceRefresh: forceRefresh,
        includeCatalog: shouldIncludeCatalog,
      );

      if (!_isActiveDetailLoadRequest(requestToken)) {
        return false;
      }

      _activeBookId = result.detail.id.trim();
      _activeSourceId = result.detail.sourceId.trim();
      _activeDetailUrl = result.detail.detailUrl.trim();
      _displayTitle = result.detail.title.trim();

      _updatePresentationState(
        _presentationState.copyWith(
          isLoading: false,
          clearErrorText: true,
          result: result,
          tocWarningText: _toTocWarningText(result.tocError),
        ),
      );
      _recordDetailBodyVisible(
        result: result,
        source: shouldIncludeCatalog ? 'detail_and_catalog' : 'detail_only',
      );
      unawaited(
        _loadSupplementaryState(result: result, loadRequestToken: requestToken),
      );
      _scheduleCatalogWarmupIfNeeded(
        result: result,
        backgroundRefresh: backgroundRefresh,
        shouldIncludeCatalog: shouldIncludeCatalog,
      );
      return true;
    } on AppException catch (error) {
      if (!_isActiveDetailLoadRequest(requestToken)) {
        return false;
      }
      if (_result != null) {
        if (!backgroundRefresh) {
          _showMessage(_toUserReadableError(error));
        }
        return false;
      }
      _updatePresentationState(
        _presentationState.copyWith(
          errorText: _toUserReadableError(error),
          clearTocWarningText: true,
        ),
      );
      _updateAuxiliaryState(
        _auxiliaryState.copyWith(
          clearLocalBookMeta: true,
          isShelfStateLoading: false,
        ),
      );
      return false;
    } catch (_) {
      if (!_isActiveDetailLoadRequest(requestToken)) {
        return false;
      }
      if (_result != null) {
        if (!backgroundRefresh) {
          _showMessage('加载失败，请稍后重试。');
        }
        return false;
      }
      _updatePresentationState(
        _presentationState.copyWith(
          errorText: '加载失败，请稍后重试。',
          clearTocWarningText: true,
        ),
      );
      _updateAuxiliaryState(
        _auxiliaryState.copyWith(
          clearLocalBookMeta: true,
          isShelfStateLoading: false,
        ),
      );
      return false;
    } finally {
      if (_isActiveDetailLoadRequest(requestToken) && shouldShowLoading) {
        _updatePresentationState(_presentationState.copyWith(isLoading: false));
      }
      lease.release();
    }
  }

  void _scheduleCatalogWarmupIfNeeded({
    required BookDetailLoadResult result,
    required bool backgroundRefresh,
    required bool shouldIncludeCatalog,
  }) {
    if (backgroundRefresh ||
        shouldIncludeCatalog ||
        result.catalogLoaded ||
        !result.catalogAvailable ||
        result.detail.totalChapterNum != null ||
        !_isLocalContent) {
      return;
    }
    unawaited(_load(includeCatalog: true, backgroundRefresh: true));
  }

  void _scheduleCompleteCatalogWarmupAfterReaderOpen() {
    final result = _result;
    if (result == null || result.catalogComplete || !result.catalogLoaded) {
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) {
        return;
      }
      unawaited(_load(includeCatalog: true, backgroundRefresh: true));
    });
  }

  List<String> _currentConflictKeys() {
    final sourceId = (_activeSourceId ?? '').trim();
    final detailUrl = (_activeDetailUrl ?? '').trim();
    final bookId = _activeBookId.trim();
    return <String>[
      _taskConflictService.conflictKeyForSource(sourceId),
      _taskConflictService.conflictKeyForBook(
        sourceId: sourceId,
        detailUrl: detailUrl,
        bookId: bookId,
      ),
    ].where((item) => item.trim().isNotEmpty).toList(growable: false);
  }

  void _cancelBackgroundRefreshConflictForCurrentBook({
    required RemoteContentConflictScene byScene,
  }) {
    final sourceId = (_activeSourceId ?? '').trim();
    final detailUrl = (_activeDetailUrl ?? '').trim();
    final bookId = _activeBookId.trim();
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
      byScene: byScene,
    );
  }

  Future<void> _loadSupplementaryState({
    required BookDetailLoadResult result,
    int? loadRequestToken,
  }) async {
    final mutationEpoch = _metadataMutationEpoch;
    if (loadRequestToken != null &&
        !_isActiveDetailLoadRequest(loadRequestToken)) {
      return;
    }

    final sourceId = result.detail.sourceId.trim();
    final detailUrl = result.detail.detailUrl.trim();
    final bookId = result.detail.id.trim();
    final initialShowLocalAdvancedOptions =
        _auxiliaryState.showLocalAdvancedOptions;

    final localBookFuture = _loadLocalBookMetaSnapshot(
      sourceId: sourceId,
      bookId: bookId,
    );
    final metadataOverrideFuture = _loadBookMetadataOverrideSnapshot(
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
    final readingProgressFuture = _loadReadingProgressSnapshot(
      detail: result.detail,
    );
    final bookshelfStateFuture = _loadBookshelfStateSnapshot(
      sourceId: sourceId,
      detailUrl: detailUrl,
    );

    final localBook = await localBookFuture;
    final metadataOverride = await metadataOverrideFuture;
    final readingProgress = await readingProgressFuture;
    final isActive =
        loadRequestToken != null
            ? _isActiveDetailLoadRequest(loadRequestToken)
            : mounted;
    if (!isActive || mutationEpoch != _metadataMutationEpoch) {
      return;
    }

    _metadataOverride = metadataOverride;
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(
        clearLocalBookMeta: localBook == null,
        localBookMeta: localBook,
        clearReadingProgress: readingProgress == null,
        readingProgress: readingProgress,
        showLocalAdvancedOptions: _resolveShowLocalAdvancedOptions(
          localBook,
          currentValue: initialShowLocalAdvancedOptions,
        ),
      ),
    );

    final isInBookshelf = await bookshelfStateFuture;
    final isStillActive =
        loadRequestToken != null
            ? _isActiveDetailLoadRequest(loadRequestToken)
            : mounted;
    if (!isStillActive || mutationEpoch != _metadataMutationEpoch) {
      return;
    }
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(
        isInBookshelf: isInBookshelf,
        isShelfStateLoading: false,
      ),
    );
    if (isInBookshelf) {
      unawaited(
        _loadDetailOrganizationSnapshot(
          sourceId: sourceId,
          detailUrl: detailUrl,
        ),
      );
    } else if (mounted) {
      setState(() {
        _detailTags = const <BookshelfTaxonomyItem>[];
        _detailCategory = null;
      });
    }
    unawaited(_maybeEnterInitialEditingMode());
  }

  Future<void> _loadDetailOrganizationSnapshot({
    required String sourceId,
    required String detailUrl,
  }) async {
    final key = '$sourceId::$detailUrl';
    try {
      final tagMapFuture = _bookshelfService.getTagMap();
      final categoryMapFuture = _bookshelfService.getCategoryMap();
      final tagItemsFuture = _bookshelfService.getTagItems();
      final categoryItemsFuture = _bookshelfService.getCategoryItems();
      final tagMap = await tagMapFuture;
      final categoryMap = await categoryMapFuture;
      final tagItems = await tagItemsFuture;
      final categoryItems = await categoryItemsFuture;
      if (!mounted) {
        return;
      }
      final tagByName = <String, BookshelfTaxonomyItem>{
        for (final item in tagItems)
          if (item.name.trim().isNotEmpty) item.name.trim(): item,
      };
      final categoryByName = <String, BookshelfTaxonomyItem>{
        for (final item in categoryItems)
          if (item.name.trim().isNotEmpty) item.name.trim(): item,
      };
      BookshelfTaxonomyItem itemFor(String name) {
        final normalized = name.trim();
        return BookshelfTaxonomyItem(
          name: normalized,
          colorValue: BookshelfTaxonomyItem.defaultColorForName(normalized),
        );
      }

      final tags = (tagMap[key] ?? const <String>[])
          .map((tag) => tagByName[tag.trim()] ?? itemFor(tag))
          .where((item) => item.name.isNotEmpty)
          .toList(growable: false);
      final categoryName = categoryMap[key]?.trim();
      setState(() {
        _detailTags = tags;
        _detailCategory =
            categoryName == null || categoryName.isEmpty
                ? null
                : (categoryByName[categoryName] ?? itemFor(categoryName));
      });
    } catch (_) {
      // Organization badges are supplemental; detail loading should stay quiet.
    }
  }

  Future<LocalBook?> _loadLocalBookMetaSnapshot({
    required String sourceId,
    required String bookId,
  }) async {
    return _localMetadataService.loadLocalBook(
      sourceId: sourceId,
      bookId: bookId,
    );
  }

  Future<LocalBook?> _ensureEditableLocalBookMeta() async {
    if (!_isLocalContent) {
      return null;
    }

    final current = _localBookMeta;
    if (current != null) {
      return current;
    }

    final localBook = await _loadLocalBookMetaSnapshot(
      sourceId: (_activeSourceId ?? '').trim(),
      bookId: _activeBookId,
    );
    if (!mounted) {
      return localBook;
    }

    _updateAuxiliaryState(
      _auxiliaryState.copyWith(
        clearLocalBookMeta: localBook == null,
        localBookMeta: localBook,
        showLocalAdvancedOptions: _resolveShowLocalAdvancedOptions(
          localBook,
          currentValue: _auxiliaryState.showLocalAdvancedOptions,
        ),
      ),
    );
    return localBook;
  }

  Future<BookMetadataOverride?> _loadBookMetadataOverrideSnapshot({
    required String sourceId,
    required String detailUrl,
  }) async {
    if (LocalReaderIdentity.isLocalSourceId(sourceId) ||
        sourceId.isEmpty ||
        detailUrl.isEmpty) {
      return null;
    }
    return _bookMetadataOverrideRepository.getByRemoteBook(
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
  }

  Future<ReadingProgress?> _loadReadingProgressSnapshot({
    required BookDetail detail,
  }) async {
    final bookId = detail.id.trim();
    if (bookId.isEmpty) {
      return null;
    }
    final progress = await _readerPreferencesService.loadProgress(bookId);
    if (!_isProgressMatchingDetail(progress, detail)) {
      return null;
    }
    return progress;
  }

  bool _isProgressMatchingDetail(ReadingProgress? progress, BookDetail detail) {
    if (progress == null) {
      return false;
    }
    return progress.sourceId.trim() == detail.sourceId.trim() &&
        progress.detailUrl.trim() == detail.detailUrl.trim();
  }

  Future<bool> _loadBookshelfStateSnapshot({
    required String sourceId,
    required String detailUrl,
  }) async {
    if (sourceId.isEmpty || detailUrl.isEmpty) {
      return false;
    }
    try {
      return await _bookshelfService.contains(
        sourceId: sourceId,
        detailUrl: detailUrl,
      );
    } catch (_) {
      return false;
    }
  }

  bool _resolveShowLocalAdvancedOptions(
    LocalBook? localBook, {
    required bool currentValue,
  }) {
    if (localBook == null) {
      return false;
    }
    if (localBook.format == LocalBookFormat.txt) {
      return true;
    }
    if (!_hasLocalRepairIssue(localBook)) {
      return false;
    }
    return currentValue;
  }

  Future<void> _syncLocalBookMeta({int? loadRequestToken}) async {
    if (loadRequestToken != null &&
        !_isActiveDetailLoadRequest(loadRequestToken)) {
      return;
    }
    final localBook = await _loadLocalBookMetaSnapshot(
      sourceId: (_activeSourceId ?? '').trim(),
      bookId: _activeBookId,
    );
    if (!mounted ||
        (loadRequestToken != null &&
            !_isActiveDetailLoadRequest(loadRequestToken))) {
      return;
    }
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(
        clearLocalBookMeta: localBook == null,
        localBookMeta: localBook,
        showLocalAdvancedOptions: _resolveShowLocalAdvancedOptions(
          localBook,
          currentValue: _auxiliaryState.showLocalAdvancedOptions,
        ),
      ),
    );
  }

  bool _isActiveDetailLoadRequest(int requestToken) {
    return mounted && requestToken == _detailLoadRequestToken;
  }

  Future<void> _handleLocalIndexEvent(LocalBookIndexEvent event) async {
    if (!mounted || !_isLocalContent || event.bookId != _activeBookId) {
      return;
    }
    if (event.status == LocalBookIndexStatus.ready && event.chapterCount > 0) {
      if (_isLoading) {
        return;
      }
      await _load(
        backgroundRefresh: true,
        includeCatalog: _result?.catalogLoaded ?? false,
      );
      return;
    }
    await _syncLocalBookMeta();
  }

  Widget _buildLocalIndexStatusCard(LocalBook localBook) {
    final colorScheme = Theme.of(context).colorScheme;
    final (title, message, background, foreground, icon) = switch (localBook
        .indexStatus) {
      LocalBookIndexStatus.pending => (
        LocalBookWorkflowPolicy.statusHeadline(localBook),
        LocalBookWorkflowPolicy.statusDescription(localBook),
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.schedule_rounded,
      ),
      LocalBookIndexStatus.indexing => (
        LocalBookWorkflowPolicy.statusHeadline(localBook),
        LocalBookWorkflowPolicy.statusDescription(localBook),
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        Icons.autorenew_rounded,
      ),
      LocalBookIndexStatus.stale => (
        LocalBookWorkflowPolicy.statusHeadline(localBook),
        LocalBookWorkflowPolicy.statusDescription(localBook),
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.refresh_rounded,
      ),
      LocalBookIndexStatus.failed => (
        LocalBookWorkflowPolicy.statusHeadline(localBook),
        LocalBookWorkflowPolicy.statusDescription(localBook),
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      _ => (
        LocalBookWorkflowPolicy.statusHeadline(localBook),
        LocalBookWorkflowPolicy.statusDescription(localBook),
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.check_circle_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (localBook.indexStatus == LocalBookIndexStatus.failed ||
              localBook.indexStatus == LocalBookIndexStatus.stale)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton.icon(
                onPressed:
                    _isLoading
                        ? null
                        : () => _load(
                          forceRefresh: true,
                          includeCatalog: _result?.catalogLoaded ?? false,
                        ),
                icon: Icon(Icons.refresh_rounded, color: foreground, size: 16),
                label: Text('重建', style: TextStyle(color: foreground)),
              ),
            ),
        ],
      ),
    );
  }

  bool _hasLocalRepairIssue(LocalBook localBook) {
    return _tocWarningText != null ||
        localBook.indexStatus == LocalBookIndexStatus.stale ||
        localBook.indexStatus == LocalBookIndexStatus.failed ||
        localBook.chapterCount <= 0 ||
        (localBook.lastError?.trim().isNotEmpty ?? false);
  }

  Future<_LocalBookDiagnosticsSnapshot> _loadLocalDiagnosticsSnapshot(
    LocalBook book,
  ) async {
    final sourcePath = book.sourcePath?.trim() ?? '';
    final storagePath = book.storagePath.trim();
    final resolvedStoragePath = await _localBookStorageService
        .resolveStoragePath(book.storagePath);
    final sourceStat = await statLocalFile(sourcePath);
    final storageStat = await statLocalFile(resolvedStoragePath);

    final sourceFileExists = sourceStat != null;
    final storageFileExists = storageStat != null;
    final sourceFileChanged =
        sourceFileExists &&
        (book.sourceFileSize != sourceStat.size ||
            book.sourceFileLastModifiedMs !=
                sourceStat.modified.millisecondsSinceEpoch);
    final globalSplitLongChapterEnabled =
        await _readerSystemSettingsService
            .loadLocalTxtSplitLongChapterEnabled();

    return _LocalBookDiagnosticsSnapshot(
      sourcePath: sourcePath,
      storagePath: storagePath,
      resolvedStoragePath: resolvedStoragePath,
      sourceFileExists: sourceFileExists,
      storageFileExists: storageFileExists,
      sourceFileChanged: sourceFileChanged,
      globalSplitLongChapterEnabled: globalSplitLongChapterEnabled,
      splitSettingNeedsReindex:
          book.splitLongChapter != globalSplitLongChapterEnabled,
    );
  }

  Future<void> _copyLocalDiagnostics(
    LocalBook book, {
    _LocalBookDiagnosticsSnapshot? diagnostics,
  }) async {
    final snapshot = diagnostics ?? await _loadLocalDiagnosticsSnapshot(book);
    final content = _buildLocalDiagnosticsText(book, snapshot);
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) {
      return;
    }
    _showMessage('已复制本地图书诊断信息。');
  }

  Future<void> _copyLocalDiagnosticsFromError() async {
    final book =
        _localBookMeta ??
        await _localMetadataService.loadLocalBook(
          sourceId: (_activeSourceId ?? '').trim(),
          bookId: _activeBookId,
        );
    if (book == null) {
      final content = [
        '本地图书诊断',
        'bookId: $_activeBookId',
        'sourceId: ${_activeSourceId ?? ''}',
        'detailUrl: ${_activeDetailUrl ?? ''}',
        'title: ${_displayTitle ?? ''}',
        'error: ${_errorText ?? ''}',
      ].join('\n');
      await Clipboard.setData(ClipboardData(text: content));
      if (!mounted) {
        return;
      }
      _showMessage('已复制基础诊断信息。');
      return;
    }
    await _copyLocalDiagnostics(book);
  }

  Future<void> _pickAndApplyCustomCover(
    BookDetailLoadResult detailResult,
  ) async {
    try {
      final coverPath = await _bookMetadataEditService
          .pickAndPersistCustomCover(detail: detailResult.detail);
      if (!mounted || coverPath == null) {
        return;
      }
      final localBook =
          _isLocalContent
              ? await _ensureEditableLocalBookMeta()
              : _localBookMeta;
      final presentation = _resolvePresentedMetadata(result: detailResult);
      final draft = BookDetailMetadataEditDraft(
        title: presentation.displayTitle,
        author: presentation.displayAuthor ?? '',
        intro: presentation.displayIntro ?? '',
        customCoverPath: coverPath,
        charset: localBook?.charset,
        splitLongChapter: localBook?.splitLongChapter ?? true,
      );
      if (_isLocalContent && localBook != null) {
        final defaultSplitLongChapterEnabled =
            await _readerSystemSettingsService
                .loadLocalTxtSplitLongChapterEnabled();
        await _saveLocalBookMetadata(
          result: detailResult,
          localBook: localBook,
          draft: draft,
          defaultSplitLongChapterEnabled: defaultSplitLongChapterEnabled,
        );
      } else {
        if (_isLocalContent) {
          _showMessage('本地图书信息尚未同步完成，请稍后重试。');
          return;
        }
        await _saveRemoteBookMetadata(result: detailResult, draft: draft);
      }
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('设置自定义封面失败，请重试。');
    }
  }

  String _buildLocalDiagnosticsText(
    LocalBook book,
    _LocalBookDiagnosticsSnapshot diagnostics,
  ) {
    return [
      '本地图书诊断',
      '书名: ${_displayTitle?.trim().isNotEmpty ?? false ? _displayTitle!.trim() : book.title}',
      '格式: ${book.format.name.toUpperCase()}',
      '编码: ${book.charset?.trim().isNotEmpty ?? false ? book.charset!.trim() : '未探测'}',
      '索引状态: ${_localIndexStatusText(book.indexStatus)}',
      '章节数: ${book.chapterCount}',
      '长章节拆分(系统): ${diagnostics.globalSplitLongChapterEnabled ? '默认开启' : '默认关闭'}${diagnostics.splitSettingNeedsReindex ? '，当前书需重新索引生效' : ''}',
      '原文件: ${_localFileName(book.sourcePath)} / ${diagnostics.sourceFileExists ? '已找到' : '缺失'}',
      '应用副本: ${_localFileName(book.storagePath)} / ${diagnostics.storageFileExists ? '已找到' : '缺失'}',
      if (diagnostics.resolvedStoragePath.trim().isNotEmpty &&
          diagnostics.resolvedStoragePath.trim() !=
              diagnostics.storagePath.trim())
        '应用副本解析路径: ${diagnostics.resolvedStoragePath}',
      '文件变化: ${diagnostics.sourcePath.isEmpty
          ? '未记录原文件路径'
          : diagnostics.sourceFileChanged
          ? '检测到原文件变化'
          : '与上次导入记录一致'}',
      if ((book.lastError?.trim().isNotEmpty ?? false))
        '最近错误: ${book.lastError!.trim()}',
    ].join('\n');
  }

  String _localFileName(String? path) {
    final normalized = path?.trim() ?? '';
    if (normalized.isEmpty) {
      return '未记录';
    }
    return p.basename(normalized);
  }

  String _localIndexStatusText(LocalBookIndexStatus status) {
    return LocalBookWorkflowPolicy.statusLabel(status);
  }

  String _toUserReadableError(AppException error) {
    if (_isLocalContent) {
      final message = error.briefMessage;
      return LocalBookWorkflowPolicy.userReadableLoadError(message);
    }

    return _onlineSourceErrorAdapter.forException(error);
  }

  String? _toTocWarningText(AppException? error) {
    if (error == null) {
      return null;
    }

    if (_isLocalContent) {
      final message = error.briefMessage;
      return LocalBookWorkflowPolicy.tocWarningText(message);
    }

    return _onlineSourceErrorAdapter.tocWarningFor(error);
  }

  Widget _buildTocWarningCard(String message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _cancelActiveSwitchSourceSearch() {
    _activeSwitchSourceCancellationToken?.cancel();
    _activeSwitchSourceCancellationToken = null;
  }
}

enum _DetailSwitchSourceApplyResult {
  switched,
  switchedWithBookshelfSyncFailed,
  failed,
}
