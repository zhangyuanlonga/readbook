import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/widgets/switch_source_candidate_sheet.dart';
import '../../../app/widgets/disk_cached_cover_image.dart';
import '../../../app/widgets/text_cover_placeholder.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_book.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../reader/application/content_provider.dart';
import '../../reader/application/local/local_book_index_service.dart';
import '../../reader/application/local/local_reader_identity.dart';
import '../../reader/application/local/local_book_storage_service.dart';
import '../../reader/application/local_content_provider.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../reader/application/reader_system_settings_service.dart';
import '../../reader/application/reading_record_service.dart';
import '../../reader/application/source_content_provider.dart';
import '../../reader/application/source_switch_score_service.dart';
import '../../reader/application/switch_source_shared.dart';
import '../../reader/presentation/chapter_cache_sheets.dart';
import '../../reader/presentation/reader_route.dart';
import '../../search/application/search_hit_cache_service.dart';
import '../../search/application/search_service.dart';
import '../../source/application/source_runtime_facade.dart';
import '../application/book_detail_service.dart';
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
    this.heroTag,
    this.bookDetailService,
    this.bookshelfService,
    this.switchSourceSearchService,
    this.cachedChapterCountStreamBuilder,
  });

  final String bookId;
  final String? sourceId;
  final String? detailUrl;
  final String? title;
  final String? heroTag;
  final BookDetailService? bookDetailService;
  final BookshelfService? bookshelfService;
  final SearchService? switchSourceSearchService;
  final Stream<int> Function(String bookId)? cachedChapterCountStreamBuilder;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late final SourceContentProvider _sourceContentProvider;
  late final ContentProviderRegistry _contentProviderRegistry;
  late final BookshelfService _bookshelfService;
  late final SearchService _switchSourceSearchService;
  late final Stream<int> Function(String bookId)
  _cachedChapterCountStreamBuilder;
  late final BookDetailSwitchSourceHelper _switchSourceHelper;

  static const int _tocPreviewLimit = 10;
  bool _isLoading = false;
  bool _isSwitchingSource = false;
  bool _manualTocReversed = false;
  bool _isShelfActionLoading = false;
  bool _isInBookshelf = false;
  bool _showLocalAdvancedOptions = false;
  int _bookshelfStateSyncToken = 0;
  SearchCancellationToken? _activeSwitchSourceCancellationToken;
  String? _errorText;
  String? _tocWarningText;
  String? _activeSourceId;
  String? _activeDetailUrl;
  String _activeBookId = '';
  String? _displayTitle;
  BookDetailLoadResult? _result;
  LocalBook? _localBookMeta;
  StreamSubscription<LocalBookIndexEvent>? _localIndexEventSubscription;
  final SearchHitCacheService _searchHitCacheService = SearchHitCacheService();
  final SourceSwitchScoreService _switchSourceScoreService =
      SourceSwitchScoreService();
  final ReaderSystemSettingsService _readerSystemSettingsService =
      ReaderSystemSettingsService();
  final LocalBookStorageService _localBookStorageService =
      LocalBookStorageService();
  final ReaderPreferencesService _readerPreferencesService =
      ReaderPreferencesService();
  final ReadingRecordService _readingRecordService = ReadingRecordService();

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
    _cachedChapterCountStreamBuilder =
        widget.cachedChapterCountStreamBuilder ??
        AppDatabase.instance.watchCachedChapterCount;
    _activeSourceId = _normalizeRouteParam(widget.sourceId);
    _activeDetailUrl = _normalizeRouteParam(widget.detailUrl);
    _activeBookId = widget.bookId.trim();
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
    _cancelActiveSwitchSourceSearch();
    _localIndexEventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
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
        appBar: AppBar(
          leading: IconButton(
            onPressed: _handleBackNavigation,
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            _displayTitle?.isNotEmpty == true ? _displayTitle! : '书籍详情',
          ),
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colorScheme.surface, colorScheme.surfaceContainerLow],
            ),
          ),
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
                  child: RefreshIndicator(
                    onRefresh: () => _load(forceRefresh: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        16,
                        horizontal,
                        16 + bottomSafe,
                      ),
                      children: [
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_isMissingParams)
                          BookDetailStateCard(
                            child: Text(
                              '缺少 sourceId/detailUrl，无法加载详情。请从搜索结果进入。bookId=${widget.bookId}',
                            ),
                          )
                        else if (_errorText != null && _result == null)
                          BookDetailStateCard(
                            color: colorScheme.errorContainer,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '加载失败',
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorText!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
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
                                ),
                              ],
                            ),
                          )
                        else if (_result != null) ...[
                          _buildDetailCard(_result!),
                          if (_canSwitchSource) ...[
                            const SizedBox(height: 12),
                            _buildSwitchSourceEntryCard(),
                          ],
                          if (_resolveLatestChapter(_result!) != null) ...[
                            const SizedBox(height: 12),
                            _buildLatestChapterCard(
                              _resolveLatestChapter(_result!)!,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildCacheCard(_result!),
                          if (_tocWarningText != null) ...[
                            const SizedBox(height: 12),
                            _buildTocWarningCard(_tocWarningText!),
                          ],
                          const SizedBox(height: 12),
                          _buildChapterSection(_result!),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
    if (cached == null) {
      return false;
    }

    _result = cached;
    _activeBookId = cached.detail.id.trim();
    _activeSourceId = cached.detail.sourceId.trim();
    _activeDetailUrl = cached.detail.detailUrl.trim();
    _displayTitle = cached.detail.title.trim();
    _tocWarningText = null;
    return true;
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

  bool get _isLocalTxtContent =>
      _isLocalContent && _localBookMeta?.format == LocalBookFormat.txt;

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
    final intro = _resolveIntro(detail.intro);
    final heroTag =
        widget.heroTag?.trim().isNotEmpty == true
            ? widget.heroTag!.trim()
            : _buildBookCoverHeroTag(
              bookId: detail.id,
              sourceId: detail.sourceId,
              detailUrl: detail.detailUrl,
            );

    return BookDetailSummaryCard(
      title: detail.title,
      sourceName: result.sourceName,
      author: detail.author,
      cover: _buildCoverPreview(
        detail.coverUrl,
        title: detail.title,
        author: detail.author,
        heroTag: heroTag,
      ),
      intro: intro,
      primaryActions: LayoutBuilder(
        builder: (context, constraints) {
          return BookDetailPrimaryActions(
            availableWidth: constraints.maxWidth,
            isInBookshelf: _isInBookshelf,
            isShelfActionLoading: _isShelfActionLoading,
            onRead:
                _readableChapters(result.chapters).isEmpty
                    ? null
                    : () =>
                        _openChapter(_readableChapters(result.chapters).first),
            onToggleBookshelf: _toggleBookshelf,
          );
        },
      ),
    );
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
    required String title,
    String? author,
    required String heroTag,
  }) {
    final uri = Uri.tryParse(coverUrl ?? '');
    if (uri != null && uri.hasScheme) {
      return Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DiskCachedCoverImage(
            imageUrl: coverUrl,
            width: 84,
            height: 120,
            fit: BoxFit.cover,
            fallback: _buildCoverFallback(title: title, author: author),
          ),
        ),
      );
    }

    return Hero(
      tag: heroTag,
      child: _buildCoverFallback(title: title, author: author),
    );
  }

  Widget _buildCoverFallback({required String title, String? author}) {
    return TextCoverPlaceholder(
      title: title,
      author: author,
      width: 84,
      height: 120,
      borderRadius: BorderRadius.circular(14),
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

  Widget _buildLatestChapterCard(Chapter latestChapter) {
    final latestTitle = _normalizeSingleLineText(latestChapter.title);
    return BookDetailActionEntryCard(
      title: '最新章节',
      subtitle: latestTitle,
      buttonLabel: '去阅读',
      onPressed: () => _openChapter(latestChapter),
    );
  }

  Widget _buildSwitchSourceEntryCard() {
    final sourceLabel = _resolveCurrentSourceDisplayName();
    final enabled = !(_isLoading || _isSwitchingSource || _isMissingParams);
    return BookDetailActionEntryCard(
      title: '切换书源',
      subtitle: sourceLabel,
      buttonLabel: _isSwitchingSource ? '切换中' : '去换源',
      onPressed: enabled ? _handleSwitchSource : null,
      enabled: enabled,
    );
  }

  Widget _buildCacheCard(BookDetailLoadResult result) {
    final readableChapters = _readableChapters(result.chapters);
    final totalChapters = readableChapters.length;

    final sourceId = _activeSourceId;
    if (sourceId == null || sourceId.isEmpty) {
      return const SizedBox.shrink();
    }
    if (!_contentCapabilities.canCacheChapter) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<int>(
      stream: _cachedChapterCountStreamBuilder(_activeBookId),
      builder: (context, snapshot) {
        final cached = snapshot.data ?? 0;
        final cappedCached = cached.clamp(0, totalChapters);
        final isAllCached = totalChapters > 0 && cappedCached >= totalChapters;
        final progress =
            totalChapters <= 0 ? 0.0 : cappedCached / totalChapters;
        final percentLabel =
            totalChapters <= 0 ? '0%' : '${(progress * 100).round()}%';
        final statusLabel = switch ((
          totalChapters,
          cappedCached,
          isAllCached,
        )) {
          (<= 0, _, _) => '暂无章节',
          (_, 0, false) => '未缓存',
          (_, _, true) => '已缓存完成',
          _ => '缓存中',
        };

        void openCache() {
          if (totalChapters == 0) {
            return;
          }
          final startIndex = 0;
          final endIndex =
              totalChapters > 0
                  ? (startIndex + 49).clamp(0, totalChapters - 1)
                  : 0;

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
        }

        return BookDetailCacheSummaryCard(
          totalChapters: totalChapters,
          cachedChapters: cappedCached,
          statusLabel: statusLabel,
          percentLabel: percentLabel,
          progress: progress,
          isAllCached: isAllCached,
          onOpenCache: totalChapters == 0 ? null : openCache,
        );
      },
    );
  }

  String _resolveCurrentSourceDisplayName() {
    final sourceName = _result?.sourceName.trim() ?? '';
    if (sourceName.isNotEmpty) {
      return sourceName;
    }
    final sourceId = _activeSourceId?.trim() ?? '';
    if (sourceId.isNotEmpty) {
      return sourceId;
    }
    return '当前书源未知';
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

  Widget _buildChapterSection(BookDetailLoadResult result) {
    final displayedChapters = _buildDisplayedChapters(result.chapters);
    final readableChapters = _readableChapters(displayedChapters);
    final hasVolumeItems = displayedChapters.any((chapter) => chapter.isVolume);
    final previewCount =
        displayedChapters.length > _tocPreviewLimit
            ? _tocPreviewLimit
            : displayedChapters.length;
    final previewChapters = displayedChapters
        .take(previewCount)
        .toList(growable: false);
    final hasMoreChapters = displayedChapters.length > previewCount;

    final localTxtControls = _buildLocalRecoveryPanel();

    final primaryActions =
        readableChapters.isNotEmpty
            ? Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _openChapter(readableChapters.first),
                    child: const Text('阅读当前首章'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openChapter(readableChapters.last),
                    child: const Text('阅读当前末章'),
                  ),
                ),
              ],
            )
            : null;

    final emptyState =
        displayedChapters.isEmpty
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isLocalContent &&
                            (_localBookMeta?.indexStatus ==
                                    LocalBookIndexStatus.pending ||
                                _localBookMeta?.indexStatus ==
                                    LocalBookIndexStatus.indexing)
                        ? '正在建立目录，请稍候，完成后会自动刷新。'
                        : _contentCapabilities.canReindexLocal
                        ? '目录暂时为空，可点击下方重新索引重试。'
                        : '目录暂时为空，可下拉页面刷新重试。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_isLocalContent &&
                    (_localBookMeta?.indexStatus ==
                            LocalBookIndexStatus.pending ||
                        _localBookMeta?.indexStatus ==
                            LocalBookIndexStatus.indexing))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (_contentCapabilities.canReindexLocal && !_isLocalTxtContent)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isLoading ? null : () => _load(forceRefresh: true),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('重新索引'),
                      ),
                    ),
                  ),
              ],
            )
            : null;

    final previewChildren = previewChapters
        .asMap()
        .entries
        .map(
          (entry) => BookDetailChapterTile(
            displayIndex: entry.key,
            title: _normalizeSingleLineText(entry.value.title),
            onTap:
                entry.value.isVolume || entry.value.chapterUrl.trim().isEmpty
                    ? null
                    : () => _openChapter(entry.value),
            enabled:
                !entry.value.isVolume &&
                entry.value.chapterUrl.trim().isNotEmpty,
            isVolume: entry.value.isVolume,
            showDivider:
                hasMoreChapters || entry.key < previewChapters.length - 1,
          ),
        )
        .toList(growable: false);

    return BookDetailChapterSectionCard(
      totalChapters: displayedChapters.length,
      tocFromCache: result.tocFromCache,
      reversed: _manualTocReversed,
      canToggleReverse: displayedChapters.length > 1,
      onToggleReverse:
          displayedChapters.length <= 1
              ? null
              : () {
                setState(() {
                  _manualTocReversed = !_manualTocReversed;
                });
              },
      localTxtControls: localTxtControls,
      primaryActions: primaryActions,
      emptyState: emptyState,
      previewChildren: previewChildren,
      showAllChaptersLabel:
          hasMoreChapters
              ? '查看全部目录（${displayedChapters.length} ${hasVolumeItems ? '项' : '章'}）'
              : null,
      onShowAllChapters:
          hasMoreChapters
              ? () => _showAllChaptersSheet(displayedChapters)
              : null,
    );
  }

  Future<void> _showAllChaptersSheet(List<Chapter> chapters) async {
    if (chapters.isEmpty || !mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final heightFactor = AppLayout.sheetHeightFactor(
          context,
          compact: 0.92,
          regular: 0.88,
          large: 0.84,
        );
        final horizontal = AppSpacing.pageHorizontal(context);

        return FractionallySizedBox(
          heightFactor: heightFactor,
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 12),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final title = Text(
                      '全部目录（${chapters.length} ${chapters.any((chapter) => chapter.isVolume) ? '项' : '章'}）',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    );
                    final orderBadge = Text(
                      _manualTocReversed ? '倒序' : '正序',
                      style: Theme.of(context).textTheme.labelMedium,
                    );

                    if (constraints.maxWidth < AppLayout.compactContentWidth) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 4),
                          orderBadge,
                        ],
                      );
                    }

                    return Row(children: [Expanded(child: title), orderBadge]);
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemExtent: 58,
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      return ListTile(
                        dense: true,
                        leading:
                            chapter.isVolume
                                ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '卷',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                )
                                : Text('${index + 1}'),
                        title: Text(
                          _normalizeSingleLineText(chapter.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              chapter.isVolume
                                  ? Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)
                                  : null,
                        ),
                        onTap:
                            chapter.isVolume ||
                                    chapter.chapterUrl.trim().isEmpty
                                ? null
                                : () {
                                  Navigator.of(context).pop();
                                  _openChapter(chapter);
                                },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

    setState(() {
      _activeSourceId = candidate.book.sourceId.trim();
      _activeDetailUrl = candidate.book.detailUrl.trim();
      _activeBookId = candidate.book.id.trim();
      _displayTitle = candidate.book.title.trim();
    });

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
      setState(() {
        _activeSourceId = previousSourceId;
        _activeDetailUrl = previousDetailUrl;
        _activeBookId = previousBookId;
        _displayTitle = previousTitle;
        _result = previousResult;
        _errorText = previousErrorText;
        _tocWarningText = previousTocWarning;
        _isInBookshelf = previousInBookshelf;
      });
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
        setState(() {
          _isInBookshelf = true;
        });
      }
      return false;
    } catch (_) {
      _scheduleBookshelfStateRefresh(result);
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
          title: result.detail.latestChapter,
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
    final route = buildReaderRoute(
      bookId: _activeBookId,
      chapterId: chapter.id,
      chapterUrl: chapter.chapterUrl,
      chapterTitle: chapter.title,
      sourceId: sourceId,
      detailUrl: detailUrl,
      chapterIndex: chapter.index,
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

    final shouldShowLoading = !backgroundRefresh || _result == null;
    setState(() {
      if (shouldShowLoading) {
        _isLoading = true;
      }
      if (!backgroundRefresh) {
        _errorText = null;
        _tocWarningText = null;
      }
      if (clearResult) {
        _result = null;
      }
    });

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

      if (!mounted) {
        return false;
      }

      setState(() {
        _result = result;
        _tocWarningText = _toTocWarningText(result.tocError);
        _activeBookId = result.detail.id.trim();
        _activeSourceId = result.detail.sourceId.trim();
        _activeDetailUrl = result.detail.detailUrl.trim();
        _displayTitle = result.detail.title.trim();
      });

      await _syncLocalBookMeta();
      _scheduleBookshelfStateRefresh(result);
      return true;
    } on AppException catch (error) {
      if (!mounted) {
        return false;
      }
      if (_result != null) {
        if (!backgroundRefresh) {
          _showMessage(_toUserReadableError(error));
        }
        return false;
      }
      setState(() {
        _errorText = _toUserReadableError(error);
        _tocWarningText = null;
        _localBookMeta = null;
      });
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      if (_result != null) {
        if (!backgroundRefresh) {
          _showMessage('加载失败，请稍后重试。');
        }
        return false;
      }
      setState(() {
        _errorText = '加载失败，请稍后重试。';
        _tocWarningText = null;
        _localBookMeta = null;
      });
      return false;
    } finally {
      if (mounted && shouldShowLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncLocalBookMeta() async {
    if (!_isLocalContent) {
      if (!mounted) {
        _localBookMeta = null;
        return;
      }
      setState(() {
        _localBookMeta = null;
      });
      return;
    }

    final localBook = await AppDatabase.instance.getLocalBookById(
      _activeBookId,
    );
    if (!mounted) {
      _localBookMeta = localBook;
      return;
    }
    setState(() {
      _localBookMeta = localBook;
      if (localBook != null && !_hasLocalRepairIssue(localBook)) {
        _showLocalAdvancedOptions = false;
      }
    });
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

  Widget? _buildLocalRecoveryPanel() {
    if (!_isLocalTxtContent) {
      return null;
    }

    final localBook = _localBookMeta;
    if (localBook == null) {
      return null;
    }

    final hasIssue = _hasLocalRepairIssue(localBook);
    if (!hasIssue && !_showLocalAdvancedOptions) {
      return null;
    }

    return _buildLocalDiagnosticsPanel();
  }

  bool _hasLocalRepairIssue(LocalBook localBook) {
    return _tocWarningText != null ||
        localBook.indexStatus == LocalBookIndexStatus.stale ||
        localBook.indexStatus == LocalBookIndexStatus.failed ||
        localBook.chapterCount <= 0 ||
        (localBook.lastError?.trim().isNotEmpty ?? false);
  }

  Widget _buildLocalDiagnosticsPanel() {
    final localBook = _localBookMeta;
    if (!_isLocalContent || localBook == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<_LocalBookDiagnosticsSnapshot>(
      future: _loadLocalDiagnosticsSnapshot(localBook),
      builder: (context, snapshot) {
        final diagnostics = snapshot.data;
        final colorScheme = Theme.of(context).colorScheme;
        final hasIssue = _hasLocalRepairIssue(localBook);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasIssue
                        ? Icons.auto_fix_high_rounded
                        : Icons.health_and_safety_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasIssue ? '这本书识别不太理想' : '本地图书诊断',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasIssue
                    ? '当前本地图书目录或索引状态异常，建议先重新索引。'
                    : '当前本地图书看起来正常。只有遇到识别问题时，才需要使用高级选项。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showLocalAdvancedOptions = !_showLocalAdvancedOptions;
                      });
                    },
                    icon: Icon(
                      _showLocalAdvancedOptions
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(_showLocalAdvancedOptions ? '收起高级选项' : '高级选项'),
                  ),
                ],
              ),
              if (_showLocalAdvancedOptions) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    BookDetailMetaChip(
                      label: '格式',
                      value: localBook.format.name.toUpperCase(),
                    ),
                    BookDetailMetaChip(
                      label: '编码',
                      value: _normalizeSingleLineText(
                        localBook.charset?.trim().isNotEmpty ?? false
                            ? localBook.charset!.trim()
                            : '未探测',
                      ),
                    ),
                    BookDetailMetaChip(
                      label: '索引',
                      value: _localIndexStatusText(localBook.indexStatus),
                    ),
                    BookDetailMetaChip(
                      label: '章节',
                      value: '${localBook.chapterCount}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          _isLoading ? null : () => _load(forceRefresh: true),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重新索引'),
                    ),
                    TextButton.icon(
                      onPressed:
                          () => _copyLocalDiagnostics(
                            localBook,
                            diagnostics: diagnostics,
                          ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('复制诊断信息'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildLocalDiagnosticLine(
                  context,
                  label: '原文件',
                  value:
                      diagnostics == null
                          ? _localFileName(localBook.sourcePath)
                          : '${_localFileName(localBook.sourcePath)} · ${diagnostics.sourceFileExists ? '已找到' : '缺失'}',
                ),
                _buildLocalDiagnosticLine(
                  context,
                  label: '应用副本',
                  value:
                      diagnostics == null
                          ? _localFileName(localBook.storagePath)
                          : '${_localFileName(localBook.storagePath)} · ${diagnostics.storageFileExists ? '已找到' : '缺失'}',
                ),
                _buildLocalDiagnosticLine(
                  context,
                  label: '文件变化',
                  value:
                      diagnostics == null
                          ? '检查中…'
                          : diagnostics.sourcePath.isEmpty
                          ? '未记录原文件路径'
                          : diagnostics.sourceFileChanged
                          ? '检测到原文件变化，建议重新导入或重新索引'
                          : '与上次导入记录一致',
                  emphasize: diagnostics?.sourceFileChanged ?? false,
                ),
                _buildLocalDiagnosticLine(
                  context,
                  label: '长章节拆分',
                  value:
                      diagnostics == null
                          ? '读取中…'
                          : diagnostics.globalSplitLongChapterEnabled
                          ? diagnostics.splitSettingNeedsReindex
                              ? '系统默认开启（当前书需重新索引生效）'
                              : '系统默认开启'
                          : diagnostics.splitSettingNeedsReindex
                          ? '系统默认关闭（当前书需重新索引生效）'
                          : '系统默认关闭',
                  emphasize: diagnostics?.splitSettingNeedsReindex ?? false,
                ),
                if ((localBook.lastError?.trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '最近错误：${localBook.lastError!.trim()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalDiagnosticLine(
    BuildContext context, {
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor =
        emphasize ? colorScheme.error : colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label：',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextSpan(
              text: value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: textColor, height: 1.4),
            ),
          ],
        ),
      ),
    );
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
    return switch (status) {
      LocalBookIndexStatus.pending => '待建立',
      LocalBookIndexStatus.indexing => '索引中',
      LocalBookIndexStatus.ready => '已就绪',
      LocalBookIndexStatus.stale => '需重建',
      LocalBookIndexStatus.failed => '失败',
    };
  }

  String _toUserReadableError(AppException error) {
    if (_isLocalContent) {
      final message = error.briefMessage;
      if (message.contains('未找到本地书籍')) {
        return '未找到本地书籍，请确认文件是否存在或重新导入。';
      }
      if (message.contains('索引失败')) {
        return '本地书籍索引失败，请尝试重新索引。';
      }
      if (message.contains('没有可用章节') || message.contains('章节为空')) {
        return '未解析到可读章节，请重新索引。';
      }
      if (message.contains('本地书籍信息缺失') || message.contains('bookId')) {
        return '本地书籍信息缺失，请重新进入或重新导入。';
      }
      return '本地书籍加载失败，请重新索引或重新导入。';
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
      if (message.contains('未找到本地书籍')) {
        return '本地书籍不存在，目录暂不可用。';
      }
      if (message.contains('索引失败')) {
        return '目录解析失败，请重新索引。';
      }
      if (message.contains('没有可用章节') || message.contains('章节为空')) {
        return '未解析到可读章节，请重新索引。';
      }
      return '目录解析失败，请重新索引。';
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

  void _scheduleBookshelfStateRefresh(BookDetailLoadResult result) {
    final sourceId = result.detail.sourceId.trim();
    final detailUrl = result.detail.detailUrl.trim();
    if (sourceId.isEmpty || detailUrl.isEmpty) {
      return;
    }

    final syncToken = ++_bookshelfStateSyncToken;
    unawaited(() async {
      bool isInBookshelf;
      try {
        isInBookshelf = await _bookshelfService.contains(
          sourceId: sourceId,
          detailUrl: detailUrl,
        );
      } catch (_) {
        return;
      }

      if (!mounted || syncToken != _bookshelfStateSyncToken) {
        return;
      }
      final activeSourceId = (_activeSourceId ?? '').trim();
      final activeDetailUrl = (_activeDetailUrl ?? '').trim();
      if (activeSourceId != sourceId || activeDetailUrl != detailUrl) {
        return;
      }

      setState(() {
        _isInBookshelf = isInBookshelf;
      });
    }());
  }

  Future<void> _toggleBookshelf() async {
    final result = _result;
    if (result == null) {
      return;
    }

    setState(() {
      _isShelfActionLoading = true;
    });
    _bookshelfStateSyncToken++;

    try {
      final detail = result.detail;
      final wasInBookshelf = _isInBookshelf;
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
            title: detail.title,
            detailUrl: detail.detailUrl,
            author: detail.author,
            coverUrl: detail.coverUrl,
            latestChapter: latestChapter,
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
    } catch (_) {
      _showMessage('操作失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isShelfActionLoading = false;
        });
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

enum _DetailSwitchSourceApplyResult {
  switched,
  switchedWithBookshelfSyncFailed,
  failed,
}
