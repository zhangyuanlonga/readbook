import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../app/widgets/runtime_feedback_card.dart';
import '../../../app/widgets/switch_source_candidate_sheet.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/bookmark_repository_impl.dart';
import '../../../data/repositories/book_metadata_override_repository_impl.dart';
import '../../../data/repositories/local_book_repository_impl.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reader_toc_snapshot.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../reader/application/content_provider.dart';
import '../../reader/application/reader_entry_route_resolver.dart';
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
import '../application/custom_cover_storage_service.dart';
import '../application/book_detail_service.dart';
import '../application/book_metadata_presentation_resolver.dart';
import 'book_detail_switch_source_helper.dart';
import 'widgets/book_detail_primary_actions.dart';
import 'widgets/book_detail_sections.dart';

class BookDetailPage extends StatefulWidget {
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
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPresentationState {
  const _BookDetailPresentationState({
    this.isLoading = false,
    this.errorText,
    this.tocWarningText,
    this.result,
  });

  final bool isLoading;
  final String? errorText;
  final String? tocWarningText;
  final BookDetailLoadResult? result;

  _BookDetailPresentationState copyWith({
    bool? isLoading,
    String? errorText,
    bool clearErrorText = false,
    String? tocWarningText,
    bool clearTocWarningText = false,
    BookDetailLoadResult? result,
    bool clearResult = false,
  }) {
    return _BookDetailPresentationState(
      isLoading: isLoading ?? this.isLoading,
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

class _BookDetailPageState extends State<BookDetailPage> {
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
  int _detailLoadRequestToken = 0;
  SearchCancellationToken? _activeSwitchSourceCancellationToken;
  String? _activeSourceId;
  String? _activeDetailUrl;
  String _activeBookId = '';
  String? _displayTitle;
  BookMetadataOverride? _metadataOverride;
  StreamSubscription<LocalBookIndexEvent>? _localIndexEventSubscription;
  final SearchHitCacheService _searchHitCacheService = SearchHitCacheService();
  final SourceSwitchScoreService _switchSourceScoreService =
      SourceSwitchScoreService();
  final BookmarkRepository _bookmarkRepository = BookmarkRepositoryImpl(
    AppDatabase.instance,
  );
  final BookMetadataOverrideRepository _bookMetadataOverrideRepository =
      BookMetadataOverrideRepositoryImpl(AppDatabase.instance);
  final LocalBookRepository _localBookRepository = LocalBookRepositoryImpl(
    AppDatabase.instance,
  );
  final BookMetadataPresentationResolver _bookMetadataPresentationResolver =
      const BookMetadataPresentationResolver();
  final ReaderCatalogSearchService _catalogSearchService =
      const ReaderCatalogSearchService();
  final ReaderSystemSettingsService _readerSystemSettingsService =
      ReaderSystemSettingsService();
  final LocalBookStorageService _localBookStorageService =
      LocalBookStorageService();
  final ReaderPreferencesService _readerPreferencesService =
      ReaderPreferencesService();
  final ReadingRecordService _readingRecordService = ReadingRecordService();
  final LocalBookIndexService _localBookIndexService = LocalBookIndexService();
  final ImageSelectionService _imageSelectionService = ImageSelectionService();
  final CustomCoverStorageService _customCoverStorageService =
      const CustomCoverStorageService();
  final ReaderEntryRouteResolver _readerEntryRouteResolver =
      const ReaderEntryRouteResolver();
  final SourceRuntimeTaskConflictService _taskConflictService =
      SourceRuntimeTaskConflictService.instance;
  final SourceRuntimeSchedulerService _taskScheduler =
      SourceRuntimeSchedulerService.instance;
  final TextEditingController _editTitleController = TextEditingController();
  final TextEditingController _editAuthorController = TextEditingController();
  final TextEditingController _editIntroController = TextEditingController();
  String? _editingCoverPath;
  String? _editingCharset;
  bool _editingSplitLongChapter = true;
  bool _defaultSplitLongChapterEnabled = true;
  String? _catalogSearchCacheFingerprint;
  Map<String, List<ReaderCatalogSearchEntry>> _catalogSearchEntriesCache =
      const <String, List<ReaderCatalogSearchEntry>>{};

  @override
  void initState() {
    super.initState();
    final detailService = widget.bookDetailService ?? BookDetailService();
    _sourceContentProvider = SourceContentProvider(
      detailService: detailService,
    );
    _contentProviderRegistry = ContentProviderRegistry(
      providers: [LocalContentProvider(), _sourceContentProvider],
    );
    _bookshelfService = widget.bookshelfService ?? BookshelfService();
    _switchSourceSearchService =
        widget.switchSourceSearchService ?? SearchService();
    _switchSourceHelper = BookDetailSwitchSourceHelper(
      switchSourceSearchService: _switchSourceSearchService,
      searchHitCacheService: _searchHitCacheService,
      switchSourceScoreService: _switchSourceScoreService,
      sourceRuntimeFacade: SourceRuntimeFacade.instance,
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
    _localIndexEventSubscription = LocalBookIndexService.watchEvents.listen(
      _handleLocalIndexEvent,
    );
    if (hydratedFromCache) {
      unawaited(_load(forceRefresh: true, backgroundRefresh: true));
    } else {
      unawaited(_load());
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
      SourceRuntimeFacade.instance.clearReadingFlow(
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

  BookMetadataPresentation _resolvePresentedMetadata({
    BookDetailLoadResult? result,
  }) {
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

  Future<void> _enterEditingMode() async {
    final result = _result;
    if (result == null) {
      _showMessage('当前书籍暂无可编辑项。');
      return;
    }
    final ensuredLocalBook =
        _isLocalContent ? await _ensureEditableLocalBookMeta() : _localBookMeta;
    final presentation = _resolvePresentedMetadata(result: result);
    _defaultSplitLongChapterEnabled =
        _isLocalContent
            ? await _readerSystemSettingsService
                .loadLocalTxtSplitLongChapterEnabled()
            : true;
    if (!mounted) {
      return;
    }
    _editTitleController.text = presentation.displayTitle;
    _editAuthorController.text = presentation.displayAuthor ?? '';
    _editIntroController.text = presentation.displayIntro ?? '';
    _editingCoverPath = presentation.customCoverPath;
    _editingCharset = ensuredLocalBook?.charset?.trim();
    if (_editingCharset != null && _editingCharset!.isEmpty) {
      _editingCharset = null;
    }
    _editingSplitLongChapter =
        ensuredLocalBook?.splitLongChapter ?? _defaultSplitLongChapterEnabled;
    setState(() {
      _isEditingMetadata = true;
    });
  }

  void _cancelEditingMode() {
    if (!_isEditingMetadata) {
      return;
    }
    setState(() {
      _isEditingMetadata = false;
      _isSavingMetadata = false;
    });
  }

  void _showMetadataInlineNotice(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _metadataInlineNotice = message;
    });
  }

  Future<void> _handleSaveMetadataEditing() async {
    final result = _result;
    final localBook =
        _isLocalContent ? await _ensureEditableLocalBookMeta() : _localBookMeta;
    if (result == null) {
      _showMessage('当前书籍暂无可编辑项。');
      return;
    }
    if (_editTitleController.text.trim().isEmpty) {
      _showMessage('书名不能为空。');
      return;
    }

    setState(() {
      _isSavingMetadata = true;
    });
    try {
      final draft = _BookMetadataEditDraft(
        title: _editTitleController.text.trim(),
        author: _editAuthorController.text.trim(),
        intro: _editIntroController.text.trim(),
        customCoverPath: _editingCoverPath,
        charset: _editingCharset,
        splitLongChapter: _editingSplitLongChapter,
      );
      if (_isLocalContent && localBook != null) {
        await _saveLocalBookMetadata(
          result: result,
          localBook: localBook,
          draft: draft,
          defaultSplitLongChapterEnabled: _defaultSplitLongChapterEnabled,
        );
      } else {
        if (_isLocalContent) {
          _showMessage('本地图书信息尚未同步完成，请稍后重试。');
          return;
        }
        await _saveRemoteBookMetadata(result: result, draft: draft);
      }
      if (mounted) {
        setState(() {
          _isEditingMetadata = false;
        });
      }
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('保存失败，请稍后重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingMetadata = false;
        });
      }
    }
  }

  Future<void> _handleResetMetadataEditing() async {
    final result = _result;
    final localBook =
        _isLocalContent ? await _ensureEditableLocalBookMeta() : _localBookMeta;
    if (result == null) {
      return;
    }
    setState(() {
      _isSavingMetadata = true;
    });
    try {
      if (_isLocalContent && localBook != null) {
        await _resetLocalBookMetadata(
          result: result,
          localBook: localBook,
          defaultSplitLongChapterEnabled: _defaultSplitLongChapterEnabled,
        );
      } else {
        if (_isLocalContent) {
          _showMessage('本地图书信息尚未同步完成，请稍后重试。');
          return;
        }
        await _resetRemoteBookMetadata(result: result);
      }
      if (mounted) {
        setState(() {
          _isEditingMetadata = false;
        });
      }
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('恢复默认失败，请稍后重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingMetadata = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final activeAdvancedTheme =
            ref.watch(activeAdvancedThemeProvider).valueOrNull;
        final colorScheme = Theme.of(context).colorScheme;
        final backdrop = resolveAdvancedThemeBackdrop(
          colorScheme,
          activeAdvancedTheme,
        );
        final horizontal = AppSpacing.pageHorizontal(context);
        final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
        final canPopRoute = context.canPop();

        return PopScope<void>(
          canPop: canPopRoute,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !mounted) {
              return;
            }
            context.go('/bookshelf');
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              leading: IconButton(
                onPressed: _handleBackNavigation,
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back),
              ),
              actions: [
                if (_isEditingMetadata) ...[
                  TextButton(
                    onPressed: _isSavingMetadata ? null : _cancelEditingMode,
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed:
                        _isSavingMetadata ? null : _handleResetMetadataEditing,
                    child: const Text('恢复默认'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton(
                      onPressed:
                          _isSavingMetadata ? null : _handleSaveMetadataEditing,
                      child: Text(_isSavingMetadata ? '保存中' : '保存'),
                    ),
                  ),
                ] else ...[
                  IconButton(
                    onPressed: _handleEditAction,
                    tooltip: '编辑',
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: _handleShareAction,
                    tooltip: '分享',
                    icon: const Icon(Icons.share_outlined),
                  ),
                  IconButton(
                    onPressed: _showMoreActionsSheet,
                    tooltip: '更多',
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ],
            ),
            floatingActionButton:
                ValueListenableBuilder<_BookDetailPresentationState>(
                  valueListenable: _presentationStateNotifier,
                  builder: (context, presentationState, _) {
                    final result = presentationState.result;
                    return result == null || _isEditingMetadata
                        ? const SizedBox.shrink()
                        : (_buildReadFloatingActionButton(result) ??
                            const SizedBox.shrink());
                  },
                ),
            body: DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: LayoutBuilder(
                builder: (context, _) {
                  final maxWidth = AppLayout.pageContentMaxWidth(
                    context,
                    maxWidth: AppLayout.bookDetailContentMaxWidth,
                  );

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: AnimatedBuilder(
                        animation: _detailStateListenable,
                        builder: (context, _) {
                          final presentationState = _presentationState;
                          final auxiliaryState = _auxiliaryState;
                          final result = presentationState.result;
                          final errorText = presentationState.errorText;
                          return RefreshIndicator(
                            onRefresh: () => _load(forceRefresh: true),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                horizontal,
                                topInset + 16,
                                horizontal,
                                16 +
                                    bottomSafe +
                                    (_isEditingMetadata ? keyboardInset : 0),
                              ),
                              children: [
                                if (_metadataInlineNotice != null) ...[
                                  _buildMetadataInlineNoticeCard(
                                    _metadataInlineNotice!,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (_isMissingParams)
                                  RuntimeFeedbackCard(
                                    title: '参数不完整',
                                    message:
                                        '缺少 sourceId/detailUrl，无法加载详情。请从搜索结果进入。bookId=${widget.bookId}',
                                    tone: RuntimeFeedbackTone.warning,
                                  )
                                else if (errorText != null && result == null)
                                  RuntimeFeedbackCard(
                                    title: '加载失败',
                                    message: errorText,
                                    tone: RuntimeFeedbackTone.error,
                                    actions: [
                                      FilledButton.tonal(
                                        onPressed:
                                            () => _load(forceRefresh: true),
                                        child: const Text('重试'),
                                      ),
                                      if (_isLocalContent)
                                        OutlinedButton.icon(
                                          onPressed:
                                              _copyLocalDiagnosticsFromError,
                                          icon: const Icon(
                                            Icons.copy_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('复制诊断信息'),
                                        ),
                                    ],
                                  )
                                else if (result != null) ...[
                                  ..._buildLoadedContentSections(
                                    presentationState: presentationState,
                                    auxiliaryState: auxiliaryState,
                                    result: result,
                                  ),
                                ] else if (presentationState.isLoading) ...[
                                  _buildInitialLoadingContent(),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

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
    unawaited(
      _loadSupplementaryState(
        result: cached,
        loadRequestToken: _detailLoadRequestToken,
      ),
    );
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

  bool get _canSwitchSource => _contentCapabilities.canSwitchSource;

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

  Widget _buildQuickActionsCard(
    BookDetailLoadResult result, {
    required _BookDetailAuxiliaryState auxiliaryState,
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
                result.chapters.isEmpty
                    ? null
                    : () => _openCatalogSheet(result),
            isCatalogEnabled: result.chapters.isNotEmpty,
            onSwitchSource: _canSwitchSource ? _handleSwitchSource : null,
            isSwitchSourceEnabled: _canSwitchSource,
            onOpenOrganize: _openOrganizeSheet,
            isOrganizeEnabled: auxiliaryState.isInBookshelf,
          );
        },
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
    final sections = <Widget>[
      if (presentationState.isLoading) ...[
        _buildInlineRefreshNotice(),
        const SizedBox(height: 12),
      ],
    ];

    if (_isEditingMetadata) {
      sections.addAll(<Widget>[
        _buildEditingDetailCard(result),
        const SizedBox(height: 12),
        _buildEditingActionCard(result),
        const SizedBox(height: 12),
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

      sections.addAll(<Widget>[
        _buildDetailCard(result),
        const SizedBox(height: 12),
        _buildQuickActionsCard(result, auxiliaryState: auxiliaryState),
        if (introCard != null) ...[const SizedBox(height: 12), introCard],
        if (shouldShowLocalIndexStatus) ...[
          const SizedBox(height: 12),
          _buildLocalIndexStatusCard(localBookMeta),
        ],
      ]);
    }

    if (presentationState.tocWarningText != null) {
      sections.addAll(<Widget>[
        const SizedBox(height: 12),
        _buildTocWarningCard(presentationState.tocWarningText!),
      ]);
    }
    return sections;
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
    if (readableChapters.isEmpty) {
      return null;
    }
    return FloatingActionButton.extended(
      key: const Key('book_detail_read_button'),
      onPressed: () => _openChapter(readableChapters.first),
      icon: const Icon(Icons.chrome_reader_mode_outlined),
      label: const Text('开始阅读'),
    );
  }

  Widget _buildDetailLoadingSkeleton() {
    final colorScheme = Theme.of(context).colorScheme;

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
                      block(height: 22, width: double.infinity),
                      const SizedBox(height: 12),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 3 ? 0 : 4),
                    child: block(height: 62),
                  ),
                ),
              ),
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

  Widget _buildInitialLoadingContent() {
    final bootstrapTitle =
        (_displayTitle ?? widget.title ?? '').trim().isNotEmpty
            ? (_displayTitle ?? widget.title ?? '').trim()
            : '加载书籍详情中';
    final bootstrapAuthor = (widget.author ?? '').trim();
    final bootstrapCover = (widget.coverUrl ?? '').trim();

    if (bootstrapAuthor.isEmpty && bootstrapCover.isEmpty) {
      return _buildDetailLoadingSkeleton();
    }

    return Column(
      children: [
        _buildBootstrapPreviewCard(
          title: bootstrapTitle,
          author: bootstrapAuthor.isEmpty ? null : bootstrapAuthor,
          coverUrl: bootstrapCover.isEmpty ? null : bootstrapCover,
        ),
        const SizedBox(height: 12),
        _buildDetailLoadingSkeleton(),
      ],
    );
  }

  Widget _buildBootstrapPreviewCard({
    required String title,
    String? author,
    String? coverUrl,
  }) {
    final heroTag =
        widget.heroTag?.trim().isNotEmpty == true
            ? widget.heroTag!.trim()
            : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoverPreview(
              coverUrl,
              title: title,
              author: author,
              heroTag: heroTag ?? 'book_bootstrap_${widget.bookId}',
              bookId: widget.bookId,
              sourceId: widget.sourceId,
              detailUrl: widget.detailUrl,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    author?.isNotEmpty == true ? author! : '作者信息加载中',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Future<void> _handleEditAction() async {
    await _enterEditingMode();
  }

  Future<String?> _pickEditableCoverPath(BookDetailLoadResult result) async {
    final picked = await _imageSelectionService.pickImage(
      confirmButtonText: '选择封面',
      allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp', 'gif'},
    );
    if (!mounted || picked == null) {
      return null;
    }
    final storedCoverUri = await _customCoverStorageService.persistForBook(
      sourceId: result.detail.sourceId,
      detailUrl: result.detail.detailUrl,
      picked: picked,
    );
    if (storedCoverUri == null) {
      return null;
    }
    return storedCoverUri.toFilePath();
  }

  Future<void> _saveRemoteBookMetadata({
    required BookDetailLoadResult result,
    required _BookMetadataEditDraft draft,
  }) async {
    final detail = result.detail;
    final normalizedTitle = draft.title.trim();
    final normalizedAuthor = _normalizeOptionalText(draft.author);
    final normalizedIntro = _normalizeOptionalText(draft.intro);
    final normalizedCoverPath = _normalizeOptionalText(draft.customCoverPath);

    final rawTitle = detail.title.trim();
    final rawAuthor = _normalizeOptionalText(detail.author);
    final rawIntro = _normalizeOptionalText(detail.intro);

    final noDiff =
        normalizedTitle == rawTitle &&
        normalizedAuthor == rawAuthor &&
        normalizedIntro == rawIntro &&
        normalizedCoverPath == null;

    if (noDiff) {
      await _bookMetadataOverrideRepository.deleteByRemoteBook(
        sourceId: detail.sourceId,
        detailUrl: detail.detailUrl,
      );
      _metadataOverride = null;
    } else {
      final nextOverride = BookMetadataOverride.forRemote(
        sourceId: detail.sourceId,
        detailUrl: detail.detailUrl,
        title: normalizedTitle,
        author: normalizedAuthor,
        intro: normalizedIntro,
        coverPath: normalizedCoverPath,
      );
      await _bookMetadataOverrideRepository.upsert(nextOverride);
      _metadataOverride = nextOverride;
    }

    await _refreshPresentedMetadata(result: result, message: '已保存书籍信息。');
  }

  Future<void> _saveLocalBookMetadata({
    required BookDetailLoadResult result,
    required LocalBook localBook,
    required _BookMetadataEditDraft draft,
    required bool defaultSplitLongChapterEnabled,
  }) async {
    final normalizedTitle = draft.title.trim();
    final normalizedAuthor = _normalizeOptionalText(draft.author);
    final normalizedIntro = _normalizeOptionalText(draft.intro);
    final normalizedCoverPath = _normalizeOptionalText(draft.customCoverPath);
    final normalizedCharset = _normalizeOptionalText(draft.charset);

    final nextLocalBook = localBook.copyWith(
      title: normalizedTitle,
      author: normalizedAuthor,
      clearAuthor: normalizedAuthor == null,
      description: normalizedIntro,
      clearDescription: normalizedIntro == null,
      coverPath: normalizedCoverPath,
      clearCoverPath: normalizedCoverPath == null,
      charset: normalizedCharset,
      clearCharset: normalizedCharset == null,
      splitLongChapter: draft.splitLongChapter,
      updatedAt: DateTime.now(),
    );

    await _localBookRepository.upsertBook(nextLocalBook);
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(localBookMeta: nextLocalBook),
    );

    final needsReindex =
        (localBook.charset?.trim() ?? '') !=
            (nextLocalBook.charset?.trim() ?? '') ||
        localBook.splitLongChapter != nextLocalBook.splitLongChapter;

    await _refreshPresentedMetadata(result: result, message: '已保存本地图书信息。');

    if (needsReindex && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('需要重新索引'),
            content: const Text('编码或长章节拆分已修改，是否立即重新索引以使正文生效？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('立即重建'),
              ),
            ],
          );
        },
      );
      if (confirmed == true) {
        await _localBookIndexService.ensureIndexed(
          bookId: localBook.id,
          force: true,
        );
        if (mounted) {
          _showMessage('已开始重新索引。');
        }
      } else if (mounted && !defaultSplitLongChapterEnabled) {
        _showMessage('设置已保存，稍后重新索引后正文才会完全生效。');
      }
    }
  }

  Future<void> _resetRemoteBookMetadata({
    required BookDetailLoadResult result,
  }) async {
    final detail = result.detail;
    await _bookMetadataOverrideRepository.deleteByRemoteBook(
      sourceId: detail.sourceId,
      detailUrl: detail.detailUrl,
    );
    _metadataOverride = null;
    await _refreshPresentedMetadata(result: result, message: '已恢复默认展示。');
  }

  Future<void> _resetLocalBookMetadata({
    required BookDetailLoadResult result,
    required LocalBook localBook,
    required bool defaultSplitLongChapterEnabled,
  }) async {
    final detail = result.detail;
    final fallbackTitle =
        detail.title.trim().isNotEmpty ? detail.title.trim() : localBook.title;
    final fallbackAuthor = _normalizeOptionalText(detail.author);
    final fallbackIntro = _normalizeOptionalText(detail.intro);
    final nextLocalBook = localBook.copyWith(
      title: fallbackTitle,
      author: fallbackAuthor,
      clearAuthor: fallbackAuthor == null,
      description: fallbackIntro,
      clearDescription: fallbackIntro == null,
      clearCoverPath: true,
      clearCharset: true,
      splitLongChapter: defaultSplitLongChapterEnabled,
      updatedAt: DateTime.now(),
    );
    await _localBookRepository.upsertBook(nextLocalBook);
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(localBookMeta: nextLocalBook),
    );
    await _refreshPresentedMetadata(result: result, message: '已恢复默认展示。');
  }

  Future<void> _refreshPresentedMetadata({
    required BookDetailLoadResult result,
    required String message,
  }) async {
    final presentation = _resolvePresentedMetadata(result: result);
    _displayTitle = presentation.displayTitle;
    _updatePresentationState(_presentationState.copyWith(result: result));
    try {
      await _readerPreferencesService.saveTocSnapshot(
        ReaderTocSnapshot(
          bookId: result.detail.id,
          sourceId: result.detail.sourceId,
          detailUrl: result.detail.detailUrl,
          title: presentation.displayTitle,
          author: presentation.displayAuthor,
          coverUrl: presentation.displayCover,
          chapters: result.chapters,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Ignore toc snapshot persistence failures when refreshing presentation.
    }
    await _readingRecordService.syncBookPresentation(
      bookId: result.detail.id,
      bookTitle: presentation.displayTitle,
      bookAuthor: presentation.displayAuthor,
      coverUrl: presentation.displayCover,
    );
    if (_auxiliaryState.isInBookshelf) {
      await _bookshelfService.upsert(
        BookshelfBook(
          bookId: result.detail.id,
          sourceId: result.detail.sourceId,
          title: presentation.displayTitle,
          detailUrl: result.detail.detailUrl,
          author: presentation.displayAuthor,
          coverUrl: presentation.displayCover,
          latestChapter: _resolveLatestChapter(result)?.title,
          addedAt: DateTime.now(),
        ),
      );
    }
    _showMetadataInlineNotice(message);
    if (mounted) {
      _showMessage(message);
    }
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _handleShareAction() async {
    final detail = _result?.detail;
    final presentation = _resolvePresentedMetadata();
    final title =
        (presentation.displayTitle.isNotEmpty
                ? presentation.displayTitle
                : (detail?.title ?? _displayTitle ?? '书籍详情'))
            .trim();
    final author = (presentation.displayAuthor ?? detail?.author ?? '').trim();
    final detailUrl = (detail?.detailUrl ?? _activeDetailUrl ?? '').trim();
    final lines = <String>[
      if (title.isNotEmpty) title,
      if (author.isNotEmpty) '作者：$author',
      if (detailUrl.isNotEmpty &&
          !LocalReaderIdentity.isLocalSchemeUrl(detailUrl))
        detailUrl,
    ];
    final text = lines.join('\n');
    try {
      await Share.share(
        text,
        subject: title.isEmpty ? '书籍详情' : title,
        sharePositionOrigin: _resolveSharePositionOrigin(),
      );
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) {
        return;
      }
      _showMessage('当前环境暂不支持系统分享，已复制内容。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('分享失败：$error');
    }
  }

  Rect? _resolveSharePositionOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final size = renderObject.size;
    if (size.isEmpty) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & size;
  }

  Future<void> _showMoreActionsSheet() async {
    final detailResult = _result;
    final latestChapter =
        detailResult == null ? null : _resolveLatestChapter(detailResult);
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (detailResult != null && detailResult.chapters.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: const Text('查看目录'),
                  onTap: () => Navigator.of(context).pop('catalog'),
                ),
              if (detailResult != null &&
                  _buildOpenCacheAction(detailResult) != null)
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('缓存章节'),
                  onTap: () => Navigator.of(context).pop('cache'),
                ),
              if (detailResult != null && _auxiliaryState.isInBookshelf)
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('自定义封面'),
                  onTap: () => Navigator.of(context).pop('custom_cover'),
                ),
              if (latestChapter != null)
                ListTile(
                  leading: const Icon(Icons.new_releases_outlined),
                  title: const Text('最新章节'),
                  onTap: () => Navigator.of(context).pop('latest'),
                ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('刷新详情'),
                onTap: () => Navigator.of(context).pop('refresh'),
              ),
              if (detailResult != null)
                ListTile(
                  leading: Icon(
                    _manualTocReversed
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                  title: Text(_manualTocReversed ? '目录正序' : '目录倒序'),
                  onTap: () => Navigator.of(context).pop('reverse'),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case 'catalog':
        if (detailResult != null) {
          await _openCatalogSheet(detailResult);
        }
        return;
      case 'cache':
        final cacheAction =
            detailResult == null ? null : _buildOpenCacheAction(detailResult);
        cacheAction?.call();
        return;
      case 'custom_cover':
        if (detailResult != null) {
          await _pickAndApplyCustomCover(detailResult);
        }
        return;
      case 'latest':
        if (latestChapter != null) {
          _openChapter(latestChapter);
        }
        return;
      case 'refresh':
        await _load(forceRefresh: true);
        return;
      case 'reverse':
        setState(() {
          _manualTocReversed = !_manualTocReversed;
        });
        return;
    }
  }

  String _buildBookCoverHeroTag({
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) {
    return 'book_cover_${sourceId.trim()}_${bookId.trim()}_${detailUrl.hashCode}';
  }

  Widget _buildCoverPreview(
    String? coverUrl, {
    String? customCoverPath,
    required String title,
    String? author,
    required String heroTag,
    String? bookId,
    String? sourceId,
    String? detailUrl,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        ref.watch(activeAdvancedThemeProvider);
        ref.watch(coverGalleriesProvider);
        final resolvedCover = resolveBookCover(
          realCoverUrl: coverUrl,
          customCoverPath: customCoverPath ?? _localBookMeta?.coverPath,
          activeTheme: ref.read(activeAdvancedThemeProvider).valueOrNull,
          galleries: ref.read(coverGalleriesProvider).valueOrNull ?? const [],
          bookId: bookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
        );
        return Hero(
          tag: heroTag,
          child: ResolvedBookCoverView(
            cover: resolvedCover,
            title: title,
            author: author,
            width: 104,
            height: 148,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  Chapter? _resolveLatestChapter(BookDetailLoadResult result) {
    final readableChapters = _readableChapters(result.chapters);
    if (readableChapters.isEmpty) {
      return null;
    }

    final chapter = readableChapters.last;
    return _normalizeText(chapter.title).isEmpty ? null : chapter;
  }

  List<Chapter> _readableChapters(List<Chapter> chapters) {
    return chapters
        .where(
          (chapter) =>
              !chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  String? _resolveIntro(String? rawIntro) {
    if (rawIntro == null) {
      return null;
    }

    final intro = _normalizeText(rawIntro);
    return intro.isEmpty ? null : intro;
  }

  String _normalizeSingleLineText(String text) {
    return _normalizeText(
      text,
    ).replaceAll('\n', ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  VoidCallback? _buildOpenCacheAction(BookDetailLoadResult result) {
    final readableChapters = _readableChapters(result.chapters);
    final totalChapters = readableChapters.length;

    final sourceId = _activeSourceId;
    if (sourceId == null ||
        sourceId.isEmpty ||
        !_contentCapabilities.canCacheChapter ||
        totalChapters == 0) {
      return null;
    }

    return () {
      final startIndex = 0;
      final endIndex =
          totalChapters > 0 ? (startIndex + 49).clamp(0, totalChapters - 1) : 0;

      showChapterCacheFlow(
        context: context,
        bookId: _activeBookId,
        sourceId: sourceId,
        chapters: readableChapters,
        initialStartIndex: startIndex,
        initialEndIndex: endIndex,
        entryPoint: ChapterCacheEntryPoint.detail,
        bookTitle: result.detail.title,
      );
    };
  }

  Future<void> _openOrganizeSheet() async {
    if (!_isInBookshelf || _result == null) {
      _showMessage('请先加入书架后再归类。');
      return;
    }

    final detail = _result!.detail;
    final initialTagMap = await _bookshelfService.getTagMap();
    final initialTagOrder = await _bookshelfService.getTagOrder();
    final initialCategoryMap = await _bookshelfService.getCategoryMap();
    final initialCategoryOrder = await _bookshelfService.getCategoryOrder();
    final bookKey = '${detail.sourceId}::${detail.detailUrl}';

    var selectedTags = List<String>.from(
      initialTagMap[bookKey] ?? const <String>[],
    );
    var availableTags = <String>[
        ...initialTagOrder,
        ...initialTagMap.values.expand((items) => items),
        ...selectedTags,
      ].where((item) => item.trim().isNotEmpty).toSet().toList(growable: false)
      ..sort();

    var selectedCategory = initialCategoryMap[bookKey];
    var availableCategories = <String>[
        ...initialCategoryOrder,
        ...initialCategoryMap.values,
        if (selectedCategory?.trim().isNotEmpty ?? false) selectedCategory!,
      ].where((item) => item.trim().isNotEmpty).toSet().toList(growable: false)
      ..sort();

    var createTagDraft = '';
    var createCategoryDraft = '';
    String? tagErrorText;
    String? categoryErrorText;

    if (!mounted) {
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);

            void addTagInline() {
              final value = createTagDraft.trim();
              if (value.isEmpty) {
                setSheetState(() {
                  tagErrorText = '请输入标签名称';
                });
                return;
              }
              if (availableTags.contains(value)) {
                if (!selectedTags.contains(value)) {
                  setSheetState(() {
                    selectedTags = <String>[...selectedTags, value];
                    createTagDraft = '';
                    tagErrorText = null;
                  });
                }
                return;
              }
              setSheetState(() {
                availableTags = <String>[...availableTags, value]..sort();
                selectedTags = <String>[...selectedTags, value];
                createTagDraft = '';
                tagErrorText = null;
              });
            }

            void addCategoryInline() {
              final value = createCategoryDraft.trim();
              if (value.isEmpty) {
                setSheetState(() {
                  categoryErrorText = '请输入分类名称';
                });
                return;
              }
              if (!availableCategories.contains(value)) {
                setSheetState(() {
                  availableCategories = <String>[...availableCategories, value]
                    ..sort();
                });
              }
              setSheetState(() {
                selectedCategory = value;
                createCategoryDraft = '';
                categoryErrorText = null;
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '归类',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '分类',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('未分类'),
                          selected: selectedCategory == null,
                          onSelected: (_) {
                            setSheetState(() {
                              selectedCategory = null;
                            });
                          },
                        ),
                        ...availableCategories.map(
                          (category) => ChoiceChip(
                            label: Text(category),
                            selected: selectedCategory == category,
                            onSelected: (_) {
                              setSheetState(() {
                                selectedCategory = category;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        labelText: '新增分类',
                        errorText: categoryErrorText,
                        suffixIcon: IconButton(
                          onPressed: addCategoryInline,
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ),
                      onChanged: (value) {
                        createCategoryDraft = value;
                        if (categoryErrorText != null) {
                          setSheetState(() {
                            categoryErrorText = null;
                          });
                        }
                      },
                      onSubmitted: (_) => addCategoryInline(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '标签',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableTags
                          .map(
                            (tag) => FilterChip(
                              label: Text(tag),
                              selected: selectedTags.contains(tag),
                              onSelected: (selected) {
                                setSheetState(() {
                                  if (selected) {
                                    selectedTags = <String>[
                                      ...selectedTags,
                                      tag,
                                    ];
                                  } else {
                                    selectedTags = selectedTags
                                        .where((item) => item != tag)
                                        .toList(growable: false);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        labelText: '新增标签',
                        errorText: tagErrorText,
                        suffixIcon: IconButton(
                          onPressed: addTagInline,
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ),
                      onChanged: (value) {
                        createTagDraft = value;
                        if (tagErrorText != null) {
                          setSheetState(() {
                            tagErrorText = null;
                          });
                        }
                      },
                      onSubmitted: (_) => addTagInline(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('保存'),
                          ),
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

    if (result != true || !mounted) {
      return;
    }

    try {
      await _bookshelfService.setBookCategory(
        sourceId: detail.sourceId,
        detailUrl: detail.detailUrl,
        category: selectedCategory,
      );
      await _bookshelfService.setBookTags(
        sourceId: detail.sourceId,
        detailUrl: detail.detailUrl,
        tags: selectedTags,
      );
      _showMessage('归类已保存。');
    } catch (_) {
      _showMessage('归类保存失败，请重试。');
    }
  }

  void _resetCatalogSearchCache() {
    _catalogSearchCacheFingerprint = null;
    _catalogSearchEntriesCache =
        const <String, List<ReaderCatalogSearchEntry>>{};
  }

  List<ReaderCatalogSearchEntry> _lookupCatalogSearchEntriesForDetail(
    String keyword,
    List<Chapter> chapters,
  ) {
    final result = _catalogSearchService.lookup(
      keyword: keyword,
      state: ReaderCatalogSearchCacheState(
        fingerprint: _catalogSearchCacheFingerprint,
        entriesCache: _catalogSearchEntriesCache,
      ),
      supportsContentSearch: false,
      chapterId: '',
      chapterUrl: null,
      currentChapterIndex: null,
      chapters: chapters,
      chapterContent: '',
      chapterParagraphs: const <String>[],
      chapterDocument: ReaderDocument(blocks: const <ReaderBlock>[]),
      isPagedTextReaderEnabled: false,
      currentPageIndex: 0,
    );
    _catalogSearchCacheFingerprint = result.state.fingerprint;
    _catalogSearchEntriesCache = result.state.entriesCache;
    return result.entries;
  }

  List<ReaderCatalogSearchEntry>? _peekCatalogSearchEntriesForDetail(
    String normalizedKeyword,
    List<Chapter> chapters,
  ) {
    final fingerprint = _catalogSearchService.buildCacheFingerprint(
      chapterId: '',
      chapterUrl: null,
      currentChapterIndex: null,
      chapters: chapters,
      supportsContentSearch: false,
      chapterContent: '',
      chapterParagraphCount: 0,
    );
    if (_catalogSearchCacheFingerprint != fingerprint) {
      _resetCatalogSearchCache();
      _catalogSearchCacheFingerprint = fingerprint;
    }
    return _catalogSearchEntriesCache[normalizedKeyword];
  }

  int? _resolveCatalogSearchEntryTargetIndexForDetail(
    ReaderCatalogSearchEntry entry,
    List<Chapter> chapters,
  ) {
    final candidateIndex =
        entry.isContent
            ? entry.chapterIndex
            : (entry.targetChapterIndex ??
                (entry.isVolume ? null : entry.chapterIndex));
    if (candidateIndex == null ||
        candidateIndex < 0 ||
        candidateIndex >= chapters.length) {
      return null;
    }
    final chapter = chapters[candidateIndex];
    if (chapter.isVolume || chapter.chapterUrl.trim().isEmpty) {
      return null;
    }
    return candidateIndex;
  }

  Future<void> _openCatalogSheet(BookDetailLoadResult result) async {
    final chapters = _buildDisplayedChapters(result.chapters);
    if (chapters.isEmpty) {
      _showMessage('当前书籍暂无目录。');
      return;
    }

    final presentation = _resolvePresentedMetadata(result: result);
    final selected = await showReaderCatalogSheet(
      context: context,
      readerModalTheme: Theme.of(context),
      chapters: chapters,
      currentChapterIndex: null,
      bookTitle: presentation.displayTitle,
      bookAuthor: presentation.displayAuthor,
      bookCoverUrl: presentation.realCoverUrl,
      customCoverPath: presentation.customCoverPath,
      supportsContentSearch: false,
      bookmarkRepository: _bookmarkRepository,
      currentBookId: _activeBookId,
      peekCatalogSearchEntries:
          (normalizedKeyword) =>
              _peekCatalogSearchEntriesForDetail(normalizedKeyword, chapters),
      lookupCatalogSearchEntries:
          (keyword) => _lookupCatalogSearchEntriesForDetail(keyword, chapters),
      resolveCatalogSearchEntryTargetIndex:
          (entry) =>
              _resolveCatalogSearchEntryTargetIndexForDetail(entry, chapters),
      refreshChapterBookmarks: () async {},
      showMessage: _showMessage,
    );

    if (!mounted || selected == null) {
      return;
    }

    if (selected.selection != null) {
      final chapterIndex = selected.selection!.chapterIndex;
      if (chapterIndex >= 0 && chapterIndex < chapters.length) {
        _openChapter(chapters[chapterIndex]);
      }
      return;
    }

    final bookmark = selected.bookmark;
    if (bookmark == null) {
      return;
    }
    final chapter = _resolveChapterFromBookmark(chapters, bookmark);
    if (chapter != null) {
      _openChapter(chapter);
    }
  }

  Chapter? _resolveChapterFromBookmark(
    List<Chapter> chapters,
    Bookmark bookmark,
  ) {
    final chapterId = bookmark.chapterId.trim();
    if (chapterId.isNotEmpty) {
      for (final chapter in chapters) {
        if (chapter.id == chapterId &&
            !chapter.isVolume &&
            chapter.chapterUrl.trim().isNotEmpty) {
          return chapter;
        }
      }
    }

    final chapterIndex = bookmark.chapterIndex;
    if (chapterIndex >= 0 && chapterIndex < chapters.length) {
      final chapter = chapters[chapterIndex];
      if (!chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty) {
        return chapter;
      }
    }
    return null;
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
    if (!_manualTocReversed) {
      return chapters;
    }
    return chapters.reversed.toList(growable: false);
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
      SourceRuntimeFacade.instance.clearReadingFlow(
        sourceId: normalizedPreviousSourceId,
        detailUrl: (previousDetailUrl ?? '').trim(),
        title: (previousTitle ?? '').trim(),
      );
    }

    _activeSourceId = candidate.book.sourceId.trim();
    _activeDetailUrl = candidate.book.detailUrl.trim();
    _activeBookId = candidate.book.id.trim();
    _displayTitle = candidate.book.title.trim();

    final switched = await _load(forceRefresh: true, clearResult: true);
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
    final route = _readerEntryRouteResolver.buildRouteFromChapter(
      bookId: _activeBookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      chapter: chapter,
    );

    context.push(route);
  }

  Future<bool> _load({
    bool forceRefresh = false,
    bool clearResult = false,
    bool backgroundRefresh = false,
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
      await _loadSupplementaryState(
        result: result,
        loadRequestToken: requestToken,
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
    if (!isActive) {
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
    if (!isStillActive) {
      return;
    }
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(
        isInBookshelf: isInBookshelf,
        isShelfStateLoading: false,
      ),
    );
  }

  Future<LocalBook?> _loadLocalBookMetaSnapshot({
    required String sourceId,
    required String bookId,
  }) async {
    if (!LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return null;
    }
    return AppDatabase.instance.getLocalBookById(bookId);
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
      await _load(backgroundRefresh: true);
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
                onPressed: _isLoading ? null : () => _load(forceRefresh: true),
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
        await AppDatabase.instance.getLocalBookById(_activeBookId);
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
      final picked = await _imageSelectionService.pickImage(
        confirmButtonText: '选择封面',
        allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp', 'gif'},
      );
      if (!mounted || picked == null) {
        return;
      }

      final storedCoverUri = await _customCoverStorageService.persistForBook(
        sourceId: detailResult.detail.sourceId,
        detailUrl: detailResult.detail.detailUrl,
        picked: picked,
      );
      if (storedCoverUri == null) {
        _showMessage('封面保存失败，请重试。');
        return;
      }
      final coverPath = storedCoverUri.toFilePath();
      final localBook =
          _isLocalContent
              ? await _ensureEditableLocalBookMeta()
              : _localBookMeta;
      final presentation = _resolvePresentedMetadata(result: detailResult);
      final draft = _BookMetadataEditDraft(
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

  Future<void> _toggleBookshelf() async {
    final result = _result;
    if (result == null) {
      return;
    }

    final wasInBookshelf = _auxiliaryState.isInBookshelf;
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(
        isShelfActionLoading: true,
        isInBookshelf: !wasInBookshelf,
      ),
    );

    try {
      final detail = result.detail;
      final presentation = _resolvePresentedMetadata(result: result);
      if (wasInBookshelf) {
        await _bookshelfService.remove(
          sourceId: detail.sourceId,
          detailUrl: detail.detailUrl,
        );
      } else {
        final latestChapter = _resolveLatestChapter(result)?.title;
        await _bookshelfService.upsert(
          BookshelfBook(
            bookId: detail.id,
            sourceId: detail.sourceId,
            title: presentation.displayTitle,
            detailUrl: detail.detailUrl,
            author: presentation.displayAuthor,
            coverUrl: presentation.displayCover,
            latestChapter: latestChapter,
            addedAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(wasInBookshelf ? '已从书架移除。' : '已加入书架。');
    } catch (_) {
      if (mounted) {
        _updateAuxiliaryState(
          _auxiliaryState.copyWith(isInBookshelf: wasInBookshelf),
        );
      }
      _showMessage('操作失败，请重试。');
    } finally {
      if (mounted) {
        _updateAuxiliaryState(
          _auxiliaryState.copyWith(isShelfActionLoading: false),
        );
      }
    }
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

class _LocalBookDiagnosticsSnapshot {
  const _LocalBookDiagnosticsSnapshot({
    required this.sourcePath,
    required this.storagePath,
    required this.resolvedStoragePath,
    required this.sourceFileExists,
    required this.storageFileExists,
    required this.sourceFileChanged,
    required this.globalSplitLongChapterEnabled,
    required this.splitSettingNeedsReindex,
  });

  final String sourcePath;
  final String storagePath;
  final String resolvedStoragePath;
  final bool sourceFileExists;
  final bool storageFileExists;
  final bool sourceFileChanged;
  final bool globalSplitLongChapterEnabled;
  final bool splitSettingNeedsReindex;
}

class _LocalCharsetOption {
  const _LocalCharsetOption({required this.label, required this.charset});

  final String label;
  final String? charset;
}

class _BookMetadataEditDraft {
  const _BookMetadataEditDraft({
    required this.title,
    required this.author,
    required this.intro,
    required this.customCoverPath,
    required this.charset,
    required this.splitLongChapter,
  });

  final String title;
  final String author;
  final String intro;
  final String? customCoverPath;
  final String? charset;
  final bool splitLongChapter;
}

enum _DetailSwitchSourceApplyResult {
  switched,
  switchedWithBookshelfSyncFailed,
  failed,
}
