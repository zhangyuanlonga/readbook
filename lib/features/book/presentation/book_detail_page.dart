import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/layout/app_adaptive.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../app/widgets/runtime_feedback_card.dart';
import '../../../app/widgets/switch_source_candidate_sheet.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
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
import '../../reader/application/reader_preferences_service.dart';
import '../../reader/application/reader_system_settings_service.dart';
import '../../reader/application/reading_record_service.dart';
import '../../reader/application/source_content_provider.dart';
import '../../reader/application/source_switch_score_service.dart';
import '../../reader/application/switch_source_shared.dart';
import '../../reader/presentation/chapter_cache_sheets.dart';
import '../../reader/presentation/reader_catalog_sheet.dart';
import '../../search/application/search_hit_cache_service.dart';
import '../../search/application/search_service.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../../source/application/source_runtime_facade.dart';
import '../../source/application/source_runtime_task_conflict_service.dart';
import '../../source/application/source_runtime_scheduler_service.dart';
import '../application/book_detail_service.dart';
import '../application/book_detail_action_service.dart';
import '../application/book_detail_catalog_service.dart';
import '../application/book_detail_read_route_service.dart';
import '../application/book_local_metadata_service.dart';
import '../application/book_detail_metadata_flow_service.dart';
import '../application/book_metadata_edit_service.dart';
import '../application/book_metadata_presentation_resolver.dart';
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
    this.sourceId,
    this.detailUrl,
    this.title,
    this.author,
    this.coverUrl,
    this.heroTag,
    this.bookDetailService,
    this.bookshelfService,
    this.switchSourceSearchService,
  });

  final String bookId;
  final String? sourceId;
  final String? detailUrl;
  final String? title;
  final String? author;
  final String? coverUrl;
  final String? heroTag;
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
    this.showLocalAdvancedOptions = false,
  });

  final bool isInBookshelf;
  final bool isShelfStateLoading;
  final bool isShelfActionLoading;
  final LocalBook? localBookMeta;
  final bool showLocalAdvancedOptions;

  _BookDetailAuxiliaryState copyWith({
    bool? isInBookshelf,
    bool? isShelfStateLoading,
    bool? isShelfActionLoading,
    LocalBook? localBookMeta,
    bool clearLocalBookMeta = false,
    bool? showLocalAdvancedOptions,
  }) {
    return _BookDetailAuxiliaryState(
      isInBookshelf: isInBookshelf ?? this.isInBookshelf,
      isShelfStateLoading: isShelfStateLoading ?? this.isShelfStateLoading,
      isShelfActionLoading: isShelfActionLoading ?? this.isShelfActionLoading,
      localBookMeta:
          clearLocalBookMeta ? null : (localBookMeta ?? this.localBookMeta),
      showLocalAdvancedOptions:
          showLocalAdvancedOptions ?? this.showLocalAdvancedOptions,
    );
  }
}

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
  late final SourceContentProvider _sourceContentProvider;
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
  late final SourceRuntimeFacade _sourceRuntimeFacade;
  final AppLogger _logger = AppLogger.instance;
  final Stopwatch _detailOpenStopwatch = Stopwatch()..start();
  final BookDisplayStateResolver _bookMetadataPresentationResolver =
      const BookDisplayStateResolver();
  late final ReaderSystemSettingsService _readerSystemSettingsService;
  late final LocalBookStorageService _localBookStorageService;
  late final ReaderPreferencesService _readerPreferencesService;
  late final ReadingRecordService _readingRecordService;
  late final LocalBookIndexService _localBookIndexService;
  late final BookDetailReadRouteService _readRouteService;
  late final SourceRuntimeTaskConflictService _taskConflictService;
  late final SourceRuntimeSchedulerService _taskScheduler;
  final TextEditingController _editTitleController = TextEditingController();
  final TextEditingController _editAuthorController = TextEditingController();
  final TextEditingController _editIntroController = TextEditingController();
  String? _editingCoverPath;
  String? _editingCharset;
  bool _editingSplitLongChapter = true;
  bool _defaultSplitLongChapterEnabled = true;
  bool _hasLoggedDetailBodyVisible = false;
  String? _catalogSearchCacheFingerprint;
  Map<String, List<ReaderCatalogSearchEntry>> _catalogSearchEntriesCache =
      const <String, List<ReaderCatalogSearchEntry>>{};

  @override
  void initState() {
    super.initState();
    final dependencies = ref.read(bookDetailDependenciesProvider);
    _bookmarkRepository = ref.read(bookBookmarkRepositoryProvider);
    _bookMetadataOverrideRepository = ref.read(
      bookMetadataOverrideRepositoryProvider,
    );
    _localMetadataService = ref.read(bookLocalMetadataServiceProvider);
    _bookMetadataEditService = dependencies.bookMetadataEditService;
    _metadataFlowService = dependencies.metadataFlowService;
    _actionService = dependencies.actionService;
    _catalogService = dependencies.catalogService;
    _sourceRuntimeFacade = ref.read(bookSourceRuntimeFacadeProvider);
    _taskConflictService = ref.read(bookTaskConflictServiceProvider);
    _taskScheduler = ref.read(bookTaskSchedulerProvider);
    _searchHitCacheService = dependencies.searchHitCacheService;
    _readerSystemSettingsService = dependencies.readerSystemSettingsService;
    _localBookStorageService = dependencies.localBookStorageService;
    _readerPreferencesService = dependencies.readerPreferencesService;
    _readingRecordService = dependencies.readingRecordService;
    _localBookIndexService = dependencies.localBookIndexService;
    _readRouteService = dependencies.readRouteService;
    final detailService =
        widget.bookDetailService ?? dependencies.bookDetailService;
    _sourceContentProvider = SourceContentProvider(
      detailService: detailService,
    );
    _contentProviderRegistry = ContentProviderRegistry(
      providers: [
        LocalContentProvider(
          detailService: ref.read(bookLocalBookDetailServiceProvider),
          chapterContentService: ref.read(
            bookDetailLocalChapterContentServiceProvider,
          ),
          previewService: ref.read(bookDetailLocalBookPreviewServiceProvider),
        ),
        _sourceContentProvider,
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
      sourceRuntimeFacade: _sourceRuntimeFacade,
    );
    _activeSourceId = _normalizeRouteParam(widget.sourceId);
    _activeDetailUrl = _normalizeRouteParam(widget.detailUrl);
    _activeBookId = widget.bookId.trim();
    _cancelBackgroundRefreshConflictForCurrentBook(
      byScene: SourceRuntimeConflictScene.detail,
    );
    _applyLocalSchemeFallback();
    _displayTitle = _normalizeRouteParam(widget.title);
    final hydratedFromCache = _hydrateCachedDetailIfAvailable();
    if (!hydratedFromCache) {
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
        unawaited(_hydrateLocalBookSnapshotIfAvailable());
      }
      unawaited(_load(includeCatalog: false));
    }
  }

  @override
  void dispose() {
    _detailLoadRequestToken += 1;
    _cancelActiveSwitchSourceSearch();
    _localIndexEventSubscription?.cancel();
    _editTitleController.dispose();
    _editAuthorController.dispose();
    _editIntroController.dispose();
    final sourceId = (_activeSourceId ?? '').trim();
    if (sourceId.isNotEmpty) {
      _sourceRuntimeFacade.clearReadingFlow(
        sourceId: sourceId,
        detailUrl: (_activeDetailUrl ?? '').trim(),
        title: (_displayTitle ?? '').trim(),
      );
    }
    _presentationStateNotifier.dispose();
    _auxiliaryStateNotifier.dispose();
    super.dispose();
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

  BookDisplayState _resolvePresentedMetadata({BookDetailLoadResult? result}) {
    final activeResult = result ?? _result;
    final detail = activeResult?.detail;
    return _bookMetadataPresentationResolver.resolve(
      fallbackTitle: detail?.title ?? _displayTitle ?? widget.title,
      fallbackAuthor: detail?.author,
      fallbackIntro: detail?.intro,
      realCoverUrl: detail?.coverUrl,
      localBook: _localBookMeta,
      metadataOverride: _metadataOverride,
    );
  }

  @override
  Widget build(BuildContext context) => _buildBookDetailPage(context);

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/bookshelf');
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

    final cached = _sourceContentProvider.peekCachedDetail(
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

  Future<void> _hydrateLocalBookSnapshotIfAvailable() async {
    final sourceId = _activeSourceId?.trim();
    final detailUrl = _activeDetailUrl?.trim();
    if (sourceId == null ||
        sourceId.isEmpty ||
        detailUrl == null ||
        detailUrl.isEmpty ||
        !LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return;
    }

    final provider = _contentProviderRegistry.findForSourceId(sourceId);
    if (provider is! LocalContentProvider) {
      return;
    }

    final result = await provider.loadBookSnapshotDetail(
      sourceId: sourceId,
      bookId: _activeBookId,
      detailUrl: detailUrl,
    );
    if (!mounted || result == null || _result != null) {
      return;
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

  bool get _canSwitchSource => _contentCapabilities.canSwitchSource;

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
    if (filePath.isNotEmpty && File(filePath).existsSync()) {
      return ResizeImage(FileImage(File(filePath)), width: 720);
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
      final file = File.fromUri(uri);
      if (file.existsSync()) {
        return ResizeImage(FileImage(file), width: 720);
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
      throw AppException(
        code: ErrorCode.unknownSource,
        stage: stage,
        briefMessage: '未找到可用的内容提供者。',
      );
    }

    return provider;
  }

  Widget _buildDetailCard(BookDetailLoadResult result) {
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

    return BookDetailSummaryCard(
      title: presentation.displayTitle,
      sourceName: result.sourceName,
      author: _cleanSummaryMetaValue(presentation.displayAuthor),
      latestChapter: _resolveLatestChapter(result)?.title,
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

    if (_isEditingMetadata) {
      sections.addAll(<Widget>[
        _buildEditingDetailCard(result),
        SizedBox(height: metrics.sectionGap),
        _buildEditingActionCard(result),
        SizedBox(height: metrics.sectionGap),
        _buildEditingIntroCard(result),
        _buildEditingLocalOptionsCard(),
      ]);
    } else {
      final introCard = _buildPresentedIntroCard(result);
      final localBookMeta = auxiliaryState.localBookMeta;
      final shouldShowLocalIndexStatus =
          _isLocalContent &&
          localBookMeta != null &&
          localBookMeta.indexStatus != LocalBookIndexStatus.ready;

      final detailCard = _buildDetailCard(result);
      final organizationCard = _buildDetailOrganizationCard();
      final quickActionsCard = _buildQuickActionsCard(
        auxiliaryState: auxiliaryState,
        hasCatalog: _canOpenCatalogForResult(result),
      );
      if (metrics.isMediumWindow || metrics.isExpandedWindow) {
        sections.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: detailCard),
              SizedBox(width: metrics.sectionGap),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    quickActionsCard,
                    if (_detailCategory != null || _detailTags.isNotEmpty) ...[
                      SizedBox(height: metrics.sectionGap),
                      organizationCard,
                    ],
                    if (introCard != null) ...[
                      SizedBox(height: metrics.sectionGap),
                      introCard,
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        sections.addAll(<Widget>[
          detailCard,
          SizedBox(height: metrics.sectionGap),
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

    if (presentationState.tocWarningText != null) {
      sections.addAll(<Widget>[
        SizedBox(height: metrics.sectionGap),
        _buildTocWarningCard(presentationState.tocWarningText!),
      ]);
    }
    return [
      for (var index = 0; index < sections.length; index++)
        AppFadeSlideTransition(
          delay: Duration(milliseconds: (index * 48).clamp(0, 240).toInt()),
          child: sections[index],
        ),
    ];
  }

  Widget _buildEditingDetailCard(BookDetailLoadResult result) {
    final detail = result.detail;
    final heroTag =
        widget.heroTag?.trim().isNotEmpty == true
            ? widget.heroTag!.trim()
            : _buildBookCoverHeroTag(
              bookId: detail.id,
              sourceId: detail.sourceId,
              detailUrl: detail.detailUrl,
            );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCoverPreview(
                  _resolvePresentedMetadata(result: result).realCoverUrl,
                  customCoverPath: _editingCoverPath,
                  title:
                      _editTitleController.text.trim().isEmpty
                          ? _resolvePresentedMetadata(
                            result: result,
                          ).displayTitle
                          : _editTitleController.text.trim(),
                  author:
                      _editAuthorController.text.trim().isEmpty
                          ? null
                          : _editAuthorController.text.trim(),
                  heroTag: heroTag,
                  bookId: detail.id,
                  sourceId: detail.sourceId,
                  detailUrl: detail.detailUrl,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _editTitleController,
                        enabled: !_isSavingMetadata,
                        decoration: const InputDecoration(
                          labelText: '书名',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _editAuthorController,
                        enabled: !_isSavingMetadata,
                        decoration: const InputDecoration(
                          labelText: '作者',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildEditingIntroCard(BookDetailLoadResult result) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '简介',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _editIntroController,
                enabled: !_isSavingMetadata,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(
                  hintText: '输入书籍简介',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEditingActionCard(BookDetailLoadResult result) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '操作',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _isSavingMetadata
                            ? null
                            : () async {
                              final nextPath = await _pickEditableCoverPath(
                                result,
                              );
                              if (!mounted || nextPath == null) {
                                return;
                              }
                              setState(() {
                                _editingCoverPath = nextPath;
                              });
                            },
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: const Text('更换封面'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _isSavingMetadata
                            ? null
                            : () {
                              setState(() {
                                _editingCoverPath = null;
                              });
                            },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('移除封面'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _isLocalContent
                    ? '当前为本地图书编辑，保存后会影响书架和阅读展示。'
                    : '当前为在线书本地覆盖编辑，保存后不会修改书源。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEditingLocalOptionsCard() {
    if (!_isLocalContent || _localBookMeta == null) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
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
                decoration: const InputDecoration(
                  labelText: '编码',
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('长章节拆分'),
                subtitle: const Text('修改后可选择立即重新索引使正文生效。'),
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
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget? _buildReadFloatingActionButton(BookDetailLoadResult result) {
    final readableChapters = _readableChapters(result.chapters);
    final fallbackRoute = _buildFallbackReadRoute(result);
    if (readableChapters.isEmpty && fallbackRoute == null) {
      return null;
    }
    return FloatingActionButton.extended(
      key: const Key('book_detail_read_button'),
      onPressed:
          readableChapters.isNotEmpty
              ? () => _openChapter(readableChapters.first)
              : () => context.push(fallbackRoute!),
      icon: const Icon(Icons.chrome_reader_mode_outlined),
      label: const Text('开始阅读'),
    );
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
    final normalizedPreviousSourceId = (previousSourceId ?? '').trim();
    if (normalizedPreviousSourceId.isNotEmpty) {
      _sourceRuntimeFacade.clearReadingFlow(
        sourceId: normalizedPreviousSourceId,
        detailUrl: (previousDetailUrl ?? '').trim(),
        title: (previousTitle ?? '').trim(),
      );
    }

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

  void _openChapter(Chapter chapter) {
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
      byScene: SourceRuntimeConflictScene.reader,
    );
    final route = _readRouteService.buildChapterRoute(
      bookId: _activeBookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      chapter: chapter,
    );
    if (route == null) {
      _showMessage('当前章节暂不可阅读。');
      return;
    }

    context.push(route);
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
      byScene: SourceRuntimeConflictScene.detail,
    );
    final lease = await _taskScheduler.acquire(
      scene: SourceRuntimeSchedulerScene.detail,
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
        fallbackTitle: _displayTitle ?? widget.title,
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
    required SourceRuntimeConflictScene byScene,
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
    final bookshelfStateFuture = _loadBookshelfStateSnapshot(
      sourceId: sourceId,
      detailUrl: detailUrl,
    );

    final localBook = await localBookFuture;
    final metadataOverride = await metadataOverrideFuture;
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
    final sourceStat = await _tryStatFile(sourcePath);
    final storageStat = await _tryStatFile(resolvedStoragePath);

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

  Future<FileStat?> _tryStatFile(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final file = File(normalized);
      if (!await file.exists()) {
        return null;
      }
      return file.stat();
    } catch (_) {
      return null;
    }
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

    return switch (error.code) {
      ErrorCode.network => '网络请求失败，请检查网络或更换书源后重试。',
      ErrorCode.validation => '书源配置不完整，暂时无法加载详情。',
      ErrorCode.ruleParse => '书源脚本语法错误，无法解析详情。',
      ErrorCode.ruleMatchEmpty => '未获取到有效内容，请更换书源或稍后重试。',
      ErrorCode.decode => '响应解析失败，可能是编码或格式不兼容。',
      ErrorCode.unknownSource => '书源不存在或已被删除。',
      ErrorCode.unknown => '加载失败，请稍后重试。',
    };
  }

  String? _toTocWarningText(AppException? error) {
    if (error == null) {
      return null;
    }

    if (_isLocalContent) {
      final message = error.briefMessage;
      return LocalBookWorkflowPolicy.tocWarningText(message);
    }

    return switch (error.code) {
      ErrorCode.network => '目录加载失败（网络异常），已展示详情。可稍后刷新目录重试。',
      ErrorCode.validation => '书源配置不完整，目录暂不可用。',
      ErrorCode.ruleParse => '书源脚本语法错误，目录暂不可用。',
      ErrorCode.ruleMatchEmpty => '未获取到目录内容，目录暂为空。',
      ErrorCode.decode => '目录解析失败，目录暂不可用。',
      ErrorCode.unknownSource => '书源不存在，目录暂不可用。',
      ErrorCode.unknown => '目录加载失败，目录暂不可用。',
    };
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
