import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/widgets/switch_source_candidate_sheet.dart';
import '../../../app/widgets/disk_cached_cover_image.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/local_book_repository_impl.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../bookshelf/application/local_book_import_service.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../reader/application/content_provider.dart';
import '../../reader/application/local_content_provider.dart';
import '../../reader/application/local/txt_toc_rule_settings_service.dart';
import '../../reader/application/source_content_provider.dart';
import '../../reader/application/source_switch_score_service.dart';
import '../../reader/application/switch_source_shared.dart';
import '../../reader/presentation/chapter_cache_sheets.dart';
import '../../search/application/search_hit_cache_service.dart';
import '../../search/application/search_service.dart';
import '../application/book_detail_service.dart';
import 'widgets/book_detail_primary_actions.dart';

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
  final TxtTocRuleSettingsService _txtTocRuleSettingsService =
      TxtTocRuleSettingsService();
  final LocalBookRepository _localBookRepository = LocalBookRepositoryImpl(
    AppDatabase.instance,
  );

  static const int _tocPreviewLimit = 80;
  static const int _kSwitchSourceCandidateLimit = 24;
  static const int _kSwitchSourceLagTolerance = 20;
  static const int _kSwitchSourceScoreStep = 6;
  static const int _kSwitchSourceHitCountCap = 12;
  static const int _kSwitchSourceHitCountWeight = 3;
  static const Duration _kSwitchSourceScopeLoadTimeout = Duration(
    milliseconds: 1600,
  );
  static const Duration _kSwitchSourceHitCountLoadTimeout = Duration(
    milliseconds: 1200,
  );
  static final RegExp _kSwitchSourceChapterPattern = RegExp(
    r'第?\s*(\d{1,5})\s*章',
  );
  static final RegExp _kSwitchSourceChapterEnglishPattern = RegExp(
    r'^(chapter|chap)\s*\d{1,5}\b',
  );

  bool _isLoading = false;
  bool _isSwitchingSource = false;
  bool _manualTocReversed = false;
  bool _isShelfActionLoading = false;
  bool _isInBookshelf = false;
  SearchCancellationToken? _activeSwitchSourceCancellationToken;
  String? _errorText;
  String? _tocWarningText;
  String? _activeSourceId;
  String? _activeDetailUrl;
  String _activeBookId = '';
  String? _displayTitle;
  BookDetailLoadResult? _result;
  LocalBook? _localBookMeta;
  TxtBookTocRuleSelection? _selectedTxtTocRule;
  final SearchHitCacheService _searchHitCacheService = SearchHitCacheService();
  final SourceSwitchScoreService _switchSourceScoreService =
      SourceSwitchScoreService();

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
    _cachedChapterCountStreamBuilder =
        widget.cachedChapterCountStreamBuilder ??
        AppDatabase.instance.watchCachedChapterCount;
    _activeSourceId = _normalizeRouteParam(widget.sourceId);
    _activeDetailUrl = _normalizeRouteParam(widget.detailUrl);
    _activeBookId = widget.bookId.trim();
    _applyLocalSchemeFallback();
    _displayTitle = _normalizeRouteParam(widget.title);
    _load();
  }

  @override
  void dispose() {
    _cancelActiveSwitchSourceSearch();
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
                if (_isMissingParams)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '缺少 sourceId/detailUrl，无法加载详情。请从搜索结果进入。bookId=${widget.bookId}',
                      ),
                    ),
                  )
                else if (_isLoading)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Text('正在加载详情和目录...')),
                        ],
                      ),
                    ),
                  )
                else if (_errorText != null)
                  Card(
                    color: colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                          FilledButton.tonal(
                            onPressed: _load,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
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
                    _buildLatestChapterCard(_resolveLatestChapter(_result!)!),
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
    final colorScheme = Theme.of(context).colorScheme;
    final heroTag =
        widget.heroTag?.trim().isNotEmpty == true
            ? widget.heroTag!.trim()
            : _buildBookCoverHeroTag(
              bookId: detail.id,
              sourceId: detail.sourceId,
              detailUrl: detail.detailUrl,
            );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.surface, colorScheme.surfaceContainerLowest],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCoverPreview(detail.coverUrl, heroTag: heroTag),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '点击目录章节即可开始阅读',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        if (detail.author != null && detail.author!.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetaChip('来源', result.sourceName),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMetaChip('作者', detail.author!),
                              ),
                            ],
                          )
                        else
                          _buildMetaChip('来源', result.sourceName),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return BookDetailPrimaryActions(
                              availableWidth: constraints.maxWidth,
                              isInBookshelf: _isInBookshelf,
                              isShelfActionLoading: _isShelfActionLoading,
                              onRead:
                                  result.chapters.isEmpty
                                      ? null
                                      : () =>
                                          _openChapter(result.chapters.first),
                              onToggleBookshelf: _toggleBookshelf,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (intro != null) ...[
                const SizedBox(height: 14),
                _buildIntroCard(intro),
              ],
            ],
          ),
        ),
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

  Widget _buildCoverPreview(String? coverUrl, {required String heroTag}) {
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
            fallback: _buildCoverFallback('封面加载失败'),
          ),
        ),
      );
    }

    return Hero(tag: heroTag, child: _buildCoverFallback('暂无封面'));
  }

  Widget _buildCoverFallback(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 84,
      height: 120,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildMetaChip(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Chapter? _resolveLatestChapter(BookDetailLoadResult result) {
    if (result.chapters.isEmpty) {
      return null;
    }

    final chapter = result.chapters.last;
    return _normalizeText(chapter.title).isEmpty ? null : chapter;
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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openChapter(latestChapter),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最新章节',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latestTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                onPressed: () => _openChapter(latestChapter),
                child: const Text('去阅读'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchSourceEntryCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final sourceLabel = _resolveCurrentSourceDisplayName();

    return Card(
      color: colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap:
            (_isLoading || _isSwitchingSource || _isMissingParams)
                ? null
                : _handleSwitchSource,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '切换书源',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                onPressed:
                    (_isLoading || _isSwitchingSource || _isMissingParams)
                        ? null
                        : _handleSwitchSource,
                child: Text(_isSwitchingSource ? '切换中' : '去换源'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCacheCard(BookDetailLoadResult result) {
    final totalChapters = result.chapters.length;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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

        final icon =
            isAllCached
                ? Icons.cloud_done_rounded
                : Icons.cloud_download_outlined;

        return Card(
          color: colorScheme.surfaceContainerHigh,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap:
                totalChapters == 0
                    ? null
                    : () {
                      final startIndex = 0;
                      final endIndex =
                          totalChapters > 0
                              ? (startIndex + 49).clamp(0, totalChapters - 1)
                              : 0;

                      showChapterCacheFlow(
                        context: context,
                        bookId: _activeBookId,
                        sourceId: sourceId,
                        chapters: result.chapters,
                        initialStartIndex: startIndex,
                        initialEndIndex: endIndex,
                        entryPoint: ChapterCacheEntryPoint.detail,
                        bookTitle: result.detail.title,
                      );
                    },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '缓存章节',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '已缓存 $cappedCached / $totalChapters 章',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonal(
                        onPressed:
                            totalChapters == 0
                                ? null
                                : () {
                                  final startIndex = 0;
                                  final endIndex =
                                      totalChapters > 0
                                          ? (startIndex + 49).clamp(
                                            0,
                                            totalChapters - 1,
                                          )
                                          : 0;

                                  showChapterCacheFlow(
                                    context: context,
                                    bookId: _activeBookId,
                                    sourceId: sourceId,
                                    chapters: result.chapters,
                                    initialStartIndex: startIndex,
                                    initialEndIndex: endIndex,
                                    entryPoint: ChapterCacheEntryPoint.detail,
                                    bookTitle: result.detail.title,
                                  );
                                },
                        child: const Text('去缓存'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        percentLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: totalChapters <= 0 ? 0 : progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAllCached ? '当前目录已全部缓存，离线阅读会更稳定。' : '可按章节范围批量缓存，减少翻页等待。',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  Widget _buildIntroCard(String intro) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
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
          const SizedBox(height: 8),
          Text(
            intro,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
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

  Widget _buildChapterSection(BookDetailLoadResult result) {
    final displayedChapters = _buildDisplayedChapters(result.chapters);
    final colorScheme = Theme.of(context).colorScheme;
    final previewCount =
        displayedChapters.length > _tocPreviewLimit
            ? _tocPreviewLimit
            : displayedChapters.length;
    final previewChapters = displayedChapters
        .take(previewCount)
        .toList(growable: false);
    final hasMoreChapters = displayedChapters.length > previewCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '目录（${displayedChapters.length} 章）',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (result.tocFromCache)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '缓存',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed:
                      displayedChapters.length <= 1
                          ? null
                          : () {
                            setState(() {
                              _manualTocReversed = !_manualTocReversed;
                            });
                          },
                  tooltip: _manualTocReversed ? '切换为正序' : '切换为倒序',
                  icon: Icon(
                    _manualTocReversed
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _manualTocReversed ? '当前展示：倒序' : '当前展示：正序',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (_isLocalTxtContent) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _showTxtTocRuleSheet,
                    icon: const Icon(Icons.rule_folder_outlined, size: 18),
                    label: Text(
                      '目录规则：${_selectedTxtTocRule?.ruleName ?? '自动探测'}',
                    ),
                  ),
                  FilterChip(
                    label: const Text('长章节拆分'),
                    selected: _localBookMeta?.splitLongChapter ?? false,
                    onSelected:
                        _isLoading ? null : (_) => _toggleSplitLongChapter(),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _isLoading ? null : () => _load(forceRefresh: true),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重新索引'),
                  ),
                ],
              ),
            ],
            if (displayedChapters.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _openChapter(displayedChapters.first),
                      child: const Text('阅读当前首章'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openChapter(displayedChapters.last),
                      child: const Text('阅读当前末章'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _contentCapabilities.canReindexLocal
                      ? '目录暂时为空，可点击下方重新索引重试。'
                      : '目录暂时为空，可下拉页面刷新重试。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_contentCapabilities.canReindexLocal) ...[
                const SizedBox(height: 8),
                if (!_isLocalTxtContent)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed:
                          _isLoading ? null : () => _load(forceRefresh: true),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重新索引'),
                    ),
                  ),
              ],
            ],
            if (previewChapters.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...previewChapters.asMap().entries.map(
                (entry) => _buildChapterTile(
                  displayIndex: entry.key,
                  chapter: entry.value,
                  showDivider:
                      hasMoreChapters || entry.key < previewChapters.length - 1,
                ),
              ),
              if (hasMoreChapters) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showAllChaptersSheet(displayedChapters),
                  icon: const Icon(Icons.unfold_more_rounded),
                  label: Text('查看全部目录（${displayedChapters.length} 章）'),
                ),
              ],
            ],
          ],
        ),
      ),
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
                      '全部目录（${chapters.length} 章）',
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
                        leading: Text('${index + 1}'),
                        title: Text(
                          _normalizeSingleLineText(chapter.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
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

  Widget _buildChapterTile({
    required int displayIndex,
    required Chapter chapter,
    bool showDivider = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openChapter(chapter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border:
              showDivider
                  ? Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  )
                  : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${displayIndex + 1}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _normalizeSingleLineText(chapter.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
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

    if (sourceId.isEmpty && _isLocalScheme(detailUrl)) {
      _activeSourceId = LocalBookImportService.localBookSourceId;
    }

    if ((_activeSourceId ?? '').trim() !=
        LocalBookImportService.localBookSourceId) {
      return;
    }

    if (detailUrl.isEmpty || !_isLocalScheme(detailUrl)) {
      final normalizedBookId = _activeBookId.trim();
      if (normalizedBookId.isNotEmpty) {
        _activeDetailUrl = _buildLocalDetailUrl(normalizedBookId);
      }
    }
  }

  String _buildLocalDetailUrl(String bookId) {
    final normalized = bookId.trim();
    return 'local://book/$normalized';
  }

  bool _isLocalScheme(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(normalized);
    return uri != null && uri.scheme == 'local';
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

    final keyword = await _resolveSwitchSourceSearchKeyword(
      currentSourceId: currentSourceId,
      currentDetailUrl: currentDetailUrl,
    );
    if (!mounted) {
      return;
    }
    if (keyword == null) {
      _showMessage('当前书名为空或仍在加载，暂时无法换源。');
      return;
    }
    final author = _result?.detail.author?.trim();

    _DetailSwitchSourceScope scope;
    try {
      scope = await _buildSwitchSourceScope(currentSourceId: currentSourceId);
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

    final scoreStore = await _loadSwitchSourceScoreStoreSafely();
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

    final searchFuture = _loadSwitchSourceCandidatesProgressively(
      keyword: keyword,
      author: author,
      scope: scope,
      currentSourceId: currentSourceId,
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

  Future<_DetailSwitchSourceScope> _buildSwitchSourceScope({
    required String currentSourceId,
  }) async {
    List<SourceDefinition> sources;
    try {
      sources = await AppDatabase.instance.getAllSources().timeout(
        _kSwitchSourceScopeLoadTimeout,
      );
    } catch (_) {
      return const _DetailSwitchSourceScope(
        sourceIds: <String>[],
        contentMode: SearchContentMode.novel,
        allowUnscopedSearch: true,
      );
    }
    if (sources.isEmpty) {
      return const _DetailSwitchSourceScope(
        sourceIds: <String>[],
        contentMode: SearchContentMode.novel,
        allowUnscopedSearch: true,
      );
    }

    SourceDefinition? currentSource;
    for (final source in sources) {
      if (source.id == currentSourceId) {
        currentSource = source;
        break;
      }
    }

    if (currentSource == null) {
      final fallbackSourceIds = sources
          .where((source) => source.enabled && source.id != currentSourceId)
          .map((source) => source.id)
          .toList(growable: false);
      if (fallbackSourceIds.isEmpty) {
        return const _DetailSwitchSourceScope(
          sourceIds: <String>[],
          contentMode: SearchContentMode.novel,
          allowUnscopedSearch: true,
        );
      }
      return _DetailSwitchSourceScope(
        sourceIds: fallbackSourceIds,
        contentMode: SearchContentMode.novel,
      );
    }

    final isMangaType = currentSource.isMangaSource;
    final sourceIds = sources
        .where(
          (source) =>
              source.enabled &&
              source.id != currentSourceId &&
              source.isMangaSource == isMangaType,
        )
        .map((source) => source.id)
        .toList(growable: false);
    if (sourceIds.isEmpty) {
      return _DetailSwitchSourceScope(
        sourceIds: const <String>[],
        contentMode:
            isMangaType ? SearchContentMode.manga : SearchContentMode.novel,
        allowUnscopedSearch: true,
      );
    }
    return _DetailSwitchSourceScope(
      sourceIds: sourceIds,
      contentMode:
          isMangaType ? SearchContentMode.manga : SearchContentMode.novel,
    );
  }

  Future<void> _loadSwitchSourceCandidatesProgressively({
    required String keyword,
    required String? author,
    required _DetailSwitchSourceScope scope,
    required String currentSourceId,
    required ValueNotifier<SwitchSourceLookupState> lookupStateNotifier,
    required SearchCancellationToken cancellationToken,
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    final requestScopedSourceIds =
        scope.allowUnscopedSearch && scope.sourceIds.isEmpty
            ? null
            : scope.sourceIds;
    try {
      final hitCountBySource = await _loadSwitchSourceHitCountsSafely(
        title: keyword,
        author: author,
      );
      final report = await _switchSourceSearchService.search(
        keyword: keyword,
        pageSize: 16,
        contentMode: scope.contentMode,
        sourceIds: requestScopedSourceIds,
        cancellationToken: cancellationToken,
        onProgress: (progress) {
          if (cancellationToken.isCancelled) {
            return;
          }

          final candidates = _buildSwitchSourceCandidates(
            books: progress.books,
            sourceNames: progress.sourceNames,
            currentSourceId: currentSourceId,
            currentChapterCount: _result?.chapters.length ?? 0,
            targetTitle: keyword,
            targetAuthor: author,
            hitCountBySource: hitCountBySource,
            scoreStore: scoreStore,
            scoreRankingEnabled: scoreRankingEnabled,
          );
          lookupStateNotifier.value = SwitchSourceLookupState(
            isLoading: true,
            sourceCount: progress.sourceCount,
            processedSourceCount: progress.processedSourceCount,
            candidates: candidates,
            errorText: null,
            scoreRankingEnabled: scoreRankingEnabled,
          );
        },
      );

      if (cancellationToken.isCancelled) {
        return;
      }

      final candidates = _buildSwitchSourceCandidates(
        books: report.books,
        sourceNames: report.sourceNames,
        currentSourceId: currentSourceId,
        currentChapterCount: _result?.chapters.length ?? 0,
        targetTitle: keyword,
        targetAuthor: author,
        hitCountBySource: hitCountBySource,
        scoreStore: scoreStore,
        scoreRankingEnabled: scoreRankingEnabled,
      );
      lookupStateNotifier.value = SwitchSourceLookupState(
        isLoading: false,
        sourceCount: report.sourceCount,
        processedSourceCount: report.processedSourceCount,
        candidates: candidates,
        errorText: candidates.isEmpty ? '没有检索到可切换书源，请稍后重试。' : null,
        scoreRankingEnabled: scoreRankingEnabled,
      );
    } on AppException catch (error) {
      if (cancellationToken.isCancelled) {
        return;
      }
      lookupStateNotifier.value = SwitchSourceLookupState(
        isLoading: false,
        sourceCount:
            requestScopedSourceIds == null ? 0 : requestScopedSourceIds.length,
        processedSourceCount: 0,
        candidates: const <SwitchSourceCandidate>[],
        errorText: '查找可切换书源失败：${error.briefMessage}',
        scoreRankingEnabled: scoreRankingEnabled,
      );
    } catch (_) {
      if (cancellationToken.isCancelled) {
        return;
      }
      lookupStateNotifier.value = SwitchSourceLookupState(
        isLoading: false,
        sourceCount:
            requestScopedSourceIds == null ? 0 : requestScopedSourceIds.length,
        processedSourceCount: 0,
        candidates: const <SwitchSourceCandidate>[],
        errorText: '查找可切换书源失败，请稍后重试。',
        scoreRankingEnabled: scoreRankingEnabled,
      );
    }
  }

  Future<SourceSwitchScoreStore> _loadSwitchSourceScoreStoreSafely() async {
    try {
      return await _switchSourceScoreService.loadStore();
    } catch (_) {
      return SourceSwitchScoreStore(
        sourceScores: <String, int>{},
        bookScores: <String, int>{},
      );
    }
  }

  Future<Map<String, int>> _loadSwitchSourceHitCountsSafely({
    required String title,
    required String? author,
  }) async {
    try {
      return await _searchHitCacheService
          .loadSourceHitCounts(title: title, author: author)
          .timeout(_kSwitchSourceHitCountLoadTimeout);
    } catch (_) {
      return <String, int>{};
    }
  }

  List<SwitchSourceCandidate> _buildSwitchSourceCandidates({
    required List<Book> books,
    required Map<String, String> sourceNames,
    required String currentSourceId,
    required int currentChapterCount,
    required String targetTitle,
    required String? targetAuthor,
    required Map<String, int> hitCountBySource,
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) {
    return buildSwitchSourceCandidates(
      books: books,
      sourceNames: sourceNames,
      currentSourceId: currentSourceId,
      currentChapterCount: currentChapterCount,
      targetTitle: targetTitle,
      targetAuthor: targetAuthor,
      hitCountBySource: hitCountBySource,
      scoreStore: scoreStore,
      scoreRankingEnabled: scoreRankingEnabled,
      buildBookScoreKey: _switchSourceScoreService.buildBookScoreKey,
      lagTolerance: _kSwitchSourceLagTolerance,
      hitCountCap: _kSwitchSourceHitCountCap,
      hitCountWeight: _kSwitchSourceHitCountWeight,
      candidateLimit: _kSwitchSourceCandidateLimit,
    );
  }

  Future<String?> _resolveSwitchSourceSearchKeyword({
    required String currentSourceId,
    required String currentDetailUrl,
  }) async {
    final currentTitle = (_result?.detail.title ?? _displayTitle ?? '').trim();
    if (_isSwitchSourceBookTitleUsable(currentTitle)) {
      return currentTitle;
    }

    try {
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
      final refreshedTitle = detailResult.detail.title.trim();
      if (_isSwitchSourceBookTitleUsable(refreshedTitle)) {
        if (mounted && refreshedTitle != _displayTitle) {
          setState(() {
            _displayTitle = refreshedTitle;
          });
        } else {
          _displayTitle = refreshedTitle;
        }
        return refreshedTitle;
      }
    } catch (_) {
      // Fall through to null and let caller show user-facing message.
    }

    return null;
  }

  bool _isSwitchSourceBookTitleUsable(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return !_looksLikeSwitchSourceChapterTitle(trimmed);
  }

  bool _looksLikeSwitchSourceChapterTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_kSwitchSourceChapterPattern.hasMatch(trimmed)) {
      return true;
    }
    final lower = trimmed.toLowerCase();
    return _kSwitchSourceChapterEnglishPattern.hasMatch(lower);
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
        return _applySwitchSourceScoreAction(
          candidate: candidate,
          action: action,
          lookupStateNotifier: lookupStateNotifier,
          scoreStore: scoreStore,
          scoreRankingEnabled: scoreRankingEnabled,
        );
      },
    );
  }

  Future<void> _applySwitchSourceScoreAction({
    required SwitchSourceCandidate candidate,
    required SwitchSourceScoreAction action,
    required ValueNotifier<SwitchSourceLookupState> lookupStateNotifier,
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    try {
      final update = switch (action) {
        SwitchSourceScoreAction.upvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: _kSwitchSourceScoreStep,
            ),
        SwitchSourceScoreAction.downvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: -_kSwitchSourceScoreStep,
            ),
        SwitchSourceScoreAction.reset => _switchSourceScoreService
            .resetBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
            ),
      };
      final resolved = await update;

      if (resolved.sourceScore == 0) {
        scoreStore.sourceScores.remove(candidate.book.sourceId);
      } else {
        scoreStore.sourceScores[candidate.book.sourceId] = resolved.sourceScore;
      }
      if (resolved.bookScore == 0) {
        scoreStore.bookScores.remove(resolved.bookScoreKey);
      } else {
        scoreStore.bookScores[resolved.bookScoreKey] = resolved.bookScore;
      }

      final current = lookupStateNotifier.value;
      final nextCandidates = current.candidates
          .map(
            (item) => _rebuildSwitchSourceCandidateScore(
              item,
              scoreStore: scoreStore,
              scoreRankingEnabled: scoreRankingEnabled,
            ),
          )
          .toList(growable: false);
      lookupStateNotifier.value = current.copyWith(
        candidates: sortSwitchSourceCandidates(nextCandidates),
      );

      if (!mounted) {
        return;
      }

      final actionLabel = switch (action) {
        SwitchSourceScoreAction.upvote => '已推荐',
        SwitchSourceScoreAction.downvote => '已降权',
        SwitchSourceScoreAction.reset => '已重置',
      };
      _showMessage(
        '$actionLabel ${candidate.sourceName}（源评 ${_formatSignedScore(resolved.sourceScore)}，书评 ${_formatSignedScore(resolved.bookScore)}）',
      );
    } catch (_) {
      _showMessage('更新评分失败，请稍后重试。');
    }
  }

  SwitchSourceCandidate _rebuildSwitchSourceCandidateScore(
    SwitchSourceCandidate candidate, {
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) {
    return rebuildSwitchSourceCandidateScore(
      candidate,
      scoreStore: scoreStore,
      scoreRankingEnabled: scoreRankingEnabled,
      buildBookScoreKey: _switchSourceScoreService.buildBookScoreKey,
      hitCountCap: _kSwitchSourceHitCountCap,
      hitCountWeight: _kSwitchSourceHitCountWeight,
    );
  }

  String _formatSignedScore(int score) {
    if (score > 0) {
      return '+$score';
    }
    return '$score';
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

    setState(() {
      _activeSourceId = candidate.book.sourceId.trim();
      _activeDetailUrl = candidate.book.detailUrl.trim();
      _activeBookId = candidate.book.id.trim();
      _displayTitle = candidate.book.title.trim();
    });

    final switched = await _load(forceRefresh: true);
    if (switched) {
      final bookshelfSyncFailed = await _migrateBookshelfAfterSwitch(
        previousSourceId: previousSourceId,
        previousDetailUrl: previousDetailUrl,
        previousInBookshelf: previousInBookshelf,
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
      await _refreshBookshelfState(result);
      return true;
    }
  }

  void _openChapter(Chapter chapter) {
    final sourceId = _activeSourceId;
    final detailUrl = _activeDetailUrl;
    if (sourceId == null ||
        sourceId.isEmpty ||
        detailUrl == null ||
        detailUrl.isEmpty) {
      _showMessage('来源信息缺失，暂时无法开始阅读。');
      return;
    }
    final route =
        Uri(
          path: '/reader/$_activeBookId/${chapter.id}',
          queryParameters: {
            'chapterUrl': chapter.chapterUrl,
            'chapterTitle': chapter.title,
            'sourceId': sourceId,
            'detailUrl': detailUrl,
            'chapterIndex': chapter.index.toString(),
          },
        ).toString();

    context.push(route);
  }

  Future<bool> _load({bool forceRefresh = false}) async {
    if (!mounted || _isMissingParams) {
      return false;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
      _tocWarningText = null;
      if (forceRefresh) {
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

      await _syncLocalTxtContext();
      await _refreshBookshelfState(result);
      return true;
    } on AppException catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _errorText = _toUserReadableError(error);
        _tocWarningText = null;
        _localBookMeta = null;
        _selectedTxtTocRule = null;
      });
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _errorText = '加载失败，请稍后重试。';
        _tocWarningText = null;
        _localBookMeta = null;
        _selectedTxtTocRule = null;
      });
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncLocalTxtContext() async {
    if (!_isLocalContent) {
      if (!mounted) {
        _localBookMeta = null;
        _selectedTxtTocRule = null;
        return;
      }
      setState(() {
        _localBookMeta = null;
        _selectedTxtTocRule = null;
      });
      return;
    }

    final localBook = await _localBookRepository.getBookById(_activeBookId);
    final selection =
        localBook == null ||
                (localBook.txtTocRuleName?.trim().isEmpty ?? true) ||
                (localBook.txtTocRulePattern?.trim().isEmpty ?? true)
            ? null
            : TxtBookTocRuleSelection(
              ruleName: localBook.txtTocRuleName!.trim(),
              pattern: localBook.txtTocRulePattern!.trim(),
            );
    if (!mounted) {
      _localBookMeta = localBook;
      _selectedTxtTocRule = selection;
      return;
    }

    setState(() {
      _localBookMeta = localBook;
      _selectedTxtTocRule = selection;
    });
  }

  Future<void> _showTxtTocRuleSheet() async {
    if (!_isLocalTxtContent || !mounted) {
      return;
    }

    final rules = await _txtTocRuleSettingsService.loadRules();
    final localBook = await _localBookRepository.getBookById(_activeBookId);
    final currentSelection =
        localBook == null ||
                (localBook.txtTocRuleName?.trim().isEmpty ?? true) ||
                (localBook.txtTocRulePattern?.trim().isEmpty ?? true)
            ? null
            : TxtBookTocRuleSelection(
              ruleName: localBook.txtTocRuleName!.trim(),
              pattern: localBook.txtTocRulePattern!.trim(),
            );
    if (!mounted) {
      return;
    }

    final selected = await showModalBottomSheet<_TxtTocRuleSheetResult>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final currentPattern = currentSelection?.pattern.trim() ?? '';
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            ListTile(
              leading: Icon(
                currentSelection == null
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
              ),
              title: const Text('自动探测'),
              subtitle: const Text('按全局启用规则自动选择最匹配的 TXT 目录规则。'),
              onTap:
                  () => Navigator.of(
                    context,
                  ).pop(const _TxtTocRuleSheetResult.clear()),
            ),
            const Divider(height: 1),
            for (final rule in rules) ...[
              ListTile(
                leading: Icon(
                  currentPattern == rule.pattern.trim()
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                title: Text(rule.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((rule.example ?? '').trim().isNotEmpty)
                      Text(
                        '示例：${rule.example!.trim()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      rule.enabled ? '全局自动识别：已启用' : '全局自动识别：未启用',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                isThreeLine: (rule.example ?? '').trim().isNotEmpty,
                onTap:
                    () => Navigator.of(
                      context,
                    ).pop(_TxtTocRuleSheetResult.select(rule)),
              ),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    final latestBook = await _localBookRepository.getBookById(_activeBookId);
    if (latestBook == null) {
      return;
    }

    if (selected.clearSelection) {
      await _localBookRepository.upsertBook(
        latestBook.copyWith(
          clearTxtTocRuleName: true,
          clearTxtTocRulePattern: true,
          updatedAt: DateTime.now(),
        ),
      );
      _showMessage('已切换为自动探测目录规则。');
    } else if (selected.rule != null) {
      await _localBookRepository.upsertBook(
        latestBook.copyWith(
          txtTocRuleName: selected.rule!.name,
          txtTocRulePattern: selected.rule!.pattern,
          updatedAt: DateTime.now(),
        ),
      );
      _showMessage('已切换目录规则：${selected.rule!.name}');
    }

    await _load(forceRefresh: true);
  }

  Future<void> _toggleSplitLongChapter() async {
    final localBook = await _localBookRepository.getBookById(_activeBookId);
    if (localBook == null) {
      return;
    }

    final nextValue = !localBook.splitLongChapter;
    await _localBookRepository.upsertBook(
      localBook.copyWith(
        splitLongChapter: nextValue,
        updatedAt: DateTime.now(),
      ),
    );
    _showMessage(nextValue ? '已开启长章节拆分。' : '已关闭长章节拆分。');
    await _load(forceRefresh: true);
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
      ErrorCode.validation => '书源规则不完整，暂时无法加载详情。',
      ErrorCode.ruleParse => '书源规则语法错误，无法解析详情。',
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
      ErrorCode.validation => '目录规则不完整，目录暂不可用。',
      ErrorCode.ruleParse => '目录规则语法错误，目录暂不可用。',
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

  Future<void> _refreshBookshelfState(BookDetailLoadResult result) async {
    final isInBookshelf = await _bookshelfService.contains(
      sourceId: result.detail.sourceId,
      detailUrl: result.detail.detailUrl,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isInBookshelf = isInBookshelf;
    });
  }

  Future<void> _toggleBookshelf() async {
    final result = _result;
    if (result == null) {
      return;
    }

    setState(() {
      _isShelfActionLoading = true;
    });

    try {
      final detail = result.detail;
      final wasInBookshelf = _isInBookshelf;
      if (wasInBookshelf) {
        await _bookshelfService.remove(
          sourceId: detail.sourceId,
          detailUrl: detail.detailUrl,
        );
      } else {
        await _bookshelfService.upsert(
          BookshelfBook(
            bookId: detail.id,
            sourceId: detail.sourceId,
            title: detail.title,
            detailUrl: detail.detailUrl,
            author: detail.author,
            coverUrl: detail.coverUrl,
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

enum _DetailSwitchSourceApplyResult {
  switched,
  switchedWithBookshelfSyncFailed,
  failed,
}

class _TxtTocRuleSheetResult {
  const _TxtTocRuleSheetResult.select(this.rule) : clearSelection = false;
  const _TxtTocRuleSheetResult.clear() : rule = null, clearSelection = true;

  final TxtTocRuleState? rule;
  final bool clearSelection;
}

class _DetailSwitchSourceScope {
  const _DetailSwitchSourceScope({
    required this.sourceIds,
    required this.contentMode,
    this.allowUnscopedSearch = false,
  });

  final List<String> sourceIds;
  final SearchContentMode contentMode;
  final bool allowUnscopedSearch;
}
