import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/widgets/disk_cached_cover_image.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/source_definition.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../reader/application/source_switch_score_service.dart';
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
  late final BookDetailService _service;
  late final BookshelfService _bookshelfService;
  late final SearchService _switchSourceSearchService;
  late final Stream<int> Function(String bookId)
  _cachedChapterCountStreamBuilder;

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
  static final RegExp _kSwitchSourceSpacePattern = RegExp(r'[\u3000\s]+');
  static final RegExp _kSwitchSourceSymbolPattern = RegExp(
    r'''[·•\-_:：|/\\\(\)\[\]【】<>《》"'‘’,.，。!?！？]''',
  );
  static final RegExp _kSwitchSourceChapterPattern = RegExp(
    r'第?\s*(\d{1,5})\s*章',
  );
  static final RegExp _kSwitchSourceChapterEnglishPattern = RegExp(
    r'^(chapter|chap)\s*\d{1,5}\b',
  );
  static final RegExp _kSwitchSourceNumberPattern = RegExp(r'(\d{1,5})');

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
  final SearchHitCacheService _searchHitCacheService = SearchHitCacheService();
  final SourceSwitchScoreService _switchSourceScoreService =
      SourceSwitchScoreService();

  @override
  void initState() {
    super.initState();
    _service = widget.bookDetailService ?? BookDetailService();
    _bookshelfService = widget.bookshelfService ?? BookshelfService();
    _switchSourceSearchService =
        widget.switchSourceSearchService ?? SearchService();
    _cachedChapterCountStreamBuilder =
        widget.cachedChapterCountStreamBuilder ??
        AppDatabase.instance.watchCachedChapterCount;
    _activeSourceId = _normalizeRouteParam(widget.sourceId);
    _activeDetailUrl = _normalizeRouteParam(widget.detailUrl);
    _activeBookId = widget.bookId.trim();
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
          actions: [
            IconButton(
              onPressed:
                  (_isLoading || _isSwitchingSource || _isMissingParams)
                      ? null
                      : _handleSwitchSource,
              tooltip: '切换书源',
              icon:
                  _isSwitchingSource
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.swap_horiz_rounded),
            ),
            IconButton(
              onPressed: _isLoading ? null : () => _load(forceRefresh: true),
              tooltip: '刷新目录',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colorScheme.surface, colorScheme.surfaceContainerLow],
            ),
          ),
          child: ListView(
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
                          style: TextStyle(color: colorScheme.onErrorContainer),
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

  Widget _buildCacheCard(BookDetailLoadResult result) {
    final totalChapters = result.chapters.length;
    final colorScheme = Theme.of(context).colorScheme;

    final sourceId = _activeSourceId;
    if (sourceId == null || sourceId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<int>(
      stream: _cachedChapterCountStreamBuilder(_activeBookId),
      builder: (context, snapshot) {
        final cached = snapshot.data ?? 0;
        final cappedCached = cached.clamp(0, totalChapters);
        final isAllCached = totalChapters > 0 && cappedCached >= totalChapters;

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
              child: Row(
                children: [
                  Icon(icon, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '缓存',
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '缓存: $cappedCached/$totalChapters',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                  '目录暂时为空，可点击右上角刷新重试。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
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

    final lookupStateNotifier = ValueNotifier<_DetailSwitchSourceLookupState>(
      _DetailSwitchSourceLookupState.loading(
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

    _DetailSwitchSourceCandidate? selected;
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
    required ValueNotifier<_DetailSwitchSourceLookupState> lookupStateNotifier,
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
          lookupStateNotifier.value = _DetailSwitchSourceLookupState(
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
      lookupStateNotifier.value = _DetailSwitchSourceLookupState(
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
      lookupStateNotifier.value = _DetailSwitchSourceLookupState(
        isLoading: false,
        sourceCount:
            requestScopedSourceIds == null ? 0 : requestScopedSourceIds.length,
        processedSourceCount: 0,
        candidates: const <_DetailSwitchSourceCandidate>[],
        errorText: '查找可切换书源失败：${error.briefMessage}',
        scoreRankingEnabled: scoreRankingEnabled,
      );
    } catch (_) {
      if (cancellationToken.isCancelled) {
        return;
      }
      lookupStateNotifier.value = _DetailSwitchSourceLookupState(
        isLoading: false,
        sourceCount:
            requestScopedSourceIds == null ? 0 : requestScopedSourceIds.length,
        processedSourceCount: 0,
        candidates: const <_DetailSwitchSourceCandidate>[],
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

  List<_DetailSwitchSourceCandidate> _buildSwitchSourceCandidates({
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
    final normalizedTargetTitle = _normalizeSwitchSourceText(targetTitle);
    final normalizedTargetAuthor = _normalizeSwitchSourceText(
      targetAuthor ?? '',
    );
    final bestBySource = <String, _DetailSwitchSourceCandidate>{};
    for (final book in books) {
      if (book.sourceId == currentSourceId) {
        continue;
      }
      final baseScore = _scoreSwitchSourceCandidate(
        book,
        normalizedTargetTitle: normalizedTargetTitle,
        normalizedTargetAuthor: normalizedTargetAuthor,
      );
      final hitCount = hitCountBySource[book.sourceId] ?? 0;
      final sourceScore = scoreStore.sourceScores[book.sourceId] ?? 0;
      final bookScore =
          scoreStore.bookScores[_switchSourceScoreService.buildBookScoreKey(
            sourceId: book.sourceId,
            title: book.title,
            author: book.author,
          )] ??
          0;
      final score = _composeSwitchSourceCandidateScore(
        baseScore: baseScore,
        hitCount: hitCount,
        sourceScore: sourceScore,
        bookScore: bookScore,
        scoreRankingEnabled: scoreRankingEnabled,
      );
      final latestChapterLabel = _formatSwitchSourceLatestChapter(
        book.latestChapter,
      );
      final latestChapterNumber = _extractSwitchSourceChapterNumber(
        latestChapterLabel,
      );
      final isPotentiallyOutdated =
          currentChapterCount > 0 &&
          latestChapterNumber != null &&
          latestChapterNumber + _kSwitchSourceLagTolerance <
              currentChapterCount;
      final candidate = _DetailSwitchSourceCandidate(
        book: book,
        sourceName: sourceNames[book.sourceId] ?? book.sourceId,
        baseScore: baseScore,
        hitCount: hitCount,
        sourceScore: sourceScore,
        bookScore: bookScore,
        latestChapterLabel: latestChapterLabel,
        latestChapterNumber: latestChapterNumber,
        isPotentiallyOutdated: isPotentiallyOutdated,
        score: score,
      );
      final existing = bestBySource[book.sourceId];
      if (existing == null || candidate.score > existing.score) {
        bestBySource[book.sourceId] = candidate;
      }
    }

    final candidates = _sortSwitchSourceCandidates(
      bestBySource.values.toList(growable: false),
    );
    if (candidates.length <= _kSwitchSourceCandidateLimit) {
      return candidates;
    }
    return candidates
        .take(_kSwitchSourceCandidateLimit)
        .toList(growable: false);
  }

  List<_DetailSwitchSourceCandidate> _sortSwitchSourceCandidates(
    List<_DetailSwitchSourceCandidate> candidates,
  ) {
    candidates.sort((a, b) {
      final scoreDiff = b.score.compareTo(a.score);
      if (scoreDiff != 0) {
        return scoreDiff;
      }
      final latestDiff = (b.latestChapterNumber ?? -1).compareTo(
        a.latestChapterNumber ?? -1,
      );
      if (latestDiff != 0) {
        return latestDiff;
      }
      return a.sourceName.compareTo(b.sourceName);
    });
    return candidates;
  }

  int _composeSwitchSourceCandidateScore({
    required int baseScore,
    required int hitCount,
    required int sourceScore,
    required int bookScore,
    required bool scoreRankingEnabled,
  }) {
    final hitBonus = _resolveSwitchSourceHitBonus(hitCount);
    if (!scoreRankingEnabled) {
      return baseScore + hitBonus;
    }
    return baseScore + hitBonus + sourceScore + bookScore;
  }

  int _resolveSwitchSourceHitBonus(int hitCount) {
    final normalizedCount = max(0, hitCount);
    final capped = min(_kSwitchSourceHitCountCap, normalizedCount);
    return capped * _kSwitchSourceHitCountWeight;
  }

  int _scoreSwitchSourceCandidate(
    Book book, {
    required String normalizedTargetTitle,
    required String normalizedTargetAuthor,
  }) {
    final normalizedTitle = _normalizeSwitchSourceText(book.title);
    var score = 0;
    if (normalizedTargetTitle.isEmpty) {
      score += 40;
    } else if (normalizedTitle == normalizedTargetTitle) {
      score += 140;
    } else if (normalizedTitle.startsWith(normalizedTargetTitle) ||
        normalizedTargetTitle.startsWith(normalizedTitle)) {
      score += 110;
    } else if (normalizedTitle.contains(normalizedTargetTitle) ||
        normalizedTargetTitle.contains(normalizedTitle)) {
      score += 85;
    } else {
      score += 50;
    }

    final normalizedAuthor = _normalizeSwitchSourceText(book.author ?? '');
    if (normalizedTargetAuthor.isNotEmpty && normalizedAuthor.isNotEmpty) {
      if (normalizedAuthor == normalizedTargetAuthor) {
        score += 24;
      } else if (normalizedAuthor.contains(normalizedTargetAuthor) ||
          normalizedTargetAuthor.contains(normalizedAuthor)) {
        score += 12;
      }
    }

    if (book.latestChapter?.trim().isNotEmpty == true) {
      score += 2;
    }
    return score;
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
      final detailResult = await _service.load(
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

  String _normalizeSwitchSourceText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(_kSwitchSourceSpacePattern, '')
        .replaceAll(_kSwitchSourceSymbolPattern, '');
  }

  String _formatSwitchSourceLatestChapter(String? latestChapter) {
    final normalized = latestChapter?.replaceAll(
      _kSwitchSourceSpacePattern,
      ' ',
    );
    final text = normalized?.trim() ?? '';
    if (text.isEmpty) {
      return '未知';
    }
    return text;
  }

  int? _extractSwitchSourceChapterNumber(String text) {
    final chapterMatch = _kSwitchSourceChapterPattern.firstMatch(text);
    if (chapterMatch != null) {
      return int.tryParse(chapterMatch.group(1)!);
    }
    final numberMatch = _kSwitchSourceNumberPattern.firstMatch(text);
    if (numberMatch != null) {
      return int.tryParse(numberMatch.group(1)!);
    }
    return null;
  }

  Future<_DetailSwitchSourceCandidate?> _showSwitchSourceCandidateSheet(
    ValueNotifier<_DetailSwitchSourceLookupState> lookupStateNotifier, {
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    return showModalBottomSheet<_DetailSwitchSourceCandidate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final horizontal = AppSpacing.pageHorizontal(context);
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
        final currentTitle =
            (_result?.detail.title ?? _displayTitle ?? '').trim();
        final currentChapterCount = _result?.chapters.length ?? 0;

        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 12),
            child: ValueListenableBuilder<_DetailSwitchSourceLookupState>(
              valueListenable: lookupStateNotifier,
              builder: (context, lookupState, _) {
                final candidates = lookupState.candidates;
                final colorScheme = Theme.of(context).colorScheme;
                final progressText =
                    lookupState.sourceCount <= 0
                        ? '正在准备书源列表...'
                        : '已扫描 ${lookupState.processedSourceCount}/${lookupState.sourceCount} 个书源';
                final emptyMessage =
                    lookupState.errorText ?? '没有检索到可切换书源，请稍后重试。';

                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '切换书源（${candidates.length}）',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '当前书名：${currentTitle.isEmpty ? '未知' : currentTitle}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '当前目录：$currentChapterCount 章',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        progressText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        lookupState.scoreRankingEnabled
                            ? '评分排序：已启用（匹配分 + 源评分 + 本书评分）'
                            : '评分排序：已关闭（仅按匹配分排序）',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          candidates.isEmpty
                              ? lookupState.isLoading
                                  ? _buildSwitchSourceLoadingPlaceholderList(
                                    colorScheme,
                                  )
                                  : Center(
                                    child: Text(
                                      emptyMessage,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                              : ListView.separated(
                                itemCount: candidates.length,
                                separatorBuilder:
                                    (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final candidate = candidates[index];
                                  final author = candidate.book.author?.trim();
                                  final subtitle =
                                      (author == null || author.isEmpty)
                                          ? candidate.sourceName
                                          : '${candidate.sourceName} · $author';

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      candidate.book.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '最新：${candidate.latestChapterLabel}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color:
                                                candidate.isPotentiallyOutdated
                                                    ? colorScheme.error
                                                    : colorScheme
                                                        .onSurfaceVariant,
                                            fontWeight:
                                                candidate.isPotentiallyOutdated
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          lookupState.scoreRankingEnabled
                                              ? '匹配:${candidate.baseScore} · 命中:${candidate.hitCount} · 源评:${_formatSignedScore(candidate.sourceScore)} · 书评:${_formatSignedScore(candidate.bookScore)}'
                                              : '匹配:${candidate.baseScore} · 命中:${candidate.hitCount}（评分排序关闭）',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (candidate
                                            .isPotentiallyOutdated) ...[
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: colorScheme.error,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 2),
                                        ],
                                        PopupMenuButton<
                                          _DetailSwitchSourceScoreAction
                                        >(
                                          tooltip: '评分',
                                          icon: const Icon(
                                            Icons.thumb_up_alt_outlined,
                                            size: 18,
                                          ),
                                          onSelected: (action) {
                                            unawaited(
                                              _applySwitchSourceScoreAction(
                                                candidate: candidate,
                                                action: action,
                                                lookupStateNotifier:
                                                    lookupStateNotifier,
                                                scoreStore: scoreStore,
                                                scoreRankingEnabled:
                                                    scoreRankingEnabled,
                                              ),
                                            );
                                          },
                                          itemBuilder:
                                              (context) => const [
                                                PopupMenuItem(
                                                  value:
                                                      _DetailSwitchSourceScoreAction
                                                          .upvote,
                                                  child: Text('推荐 +1'),
                                                ),
                                                PopupMenuItem(
                                                  value:
                                                      _DetailSwitchSourceScoreAction
                                                          .downvote,
                                                  child: Text('降权 -1'),
                                                ),
                                                PopupMenuItem(
                                                  value:
                                                      _DetailSwitchSourceScoreAction
                                                          .reset,
                                                  child: Text('重置本书评分'),
                                                ),
                                              ],
                                        ),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                    onTap:
                                        () => Navigator.of(
                                          context,
                                        ).pop(candidate),
                                  );
                                },
                              ),
                    ),
                    if (lookupState.isLoading && candidates.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '正在继续检索其他书源...',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: bottomInset),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _applySwitchSourceScoreAction({
    required _DetailSwitchSourceCandidate candidate,
    required _DetailSwitchSourceScoreAction action,
    required ValueNotifier<_DetailSwitchSourceLookupState> lookupStateNotifier,
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    try {
      final update = switch (action) {
        _DetailSwitchSourceScoreAction.upvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: _kSwitchSourceScoreStep,
            ),
        _DetailSwitchSourceScoreAction.downvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: -_kSwitchSourceScoreStep,
            ),
        _DetailSwitchSourceScoreAction.reset => _switchSourceScoreService
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
        candidates: _sortSwitchSourceCandidates(nextCandidates),
      );

      if (!mounted) {
        return;
      }

      final actionLabel = switch (action) {
        _DetailSwitchSourceScoreAction.upvote => '已推荐',
        _DetailSwitchSourceScoreAction.downvote => '已降权',
        _DetailSwitchSourceScoreAction.reset => '已重置',
      };
      _showMessage(
        '$actionLabel ${candidate.sourceName}（源评 ${_formatSignedScore(resolved.sourceScore)}，书评 ${_formatSignedScore(resolved.bookScore)}）',
      );
    } catch (_) {
      _showMessage('更新评分失败，请稍后重试。');
    }
  }

  Widget _buildSwitchSourceLoadingPlaceholderList(ColorScheme colorScheme) {
    final placeholderColor = colorScheme.surfaceContainerHigh;
    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final titleWidth = 110.0 + (index % 3) * 42.0;
        final subtitleWidth = 150.0 + (index % 2) * 56.0;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: titleWidth,
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: subtitleWidth,
                height: 12,
                decoration: BoxDecoration(
                  color: placeholderColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          trailing: Icon(
            Icons.hourglass_top_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 18,
          ),
        );
      },
    );
  }

  _DetailSwitchSourceCandidate _rebuildSwitchSourceCandidateScore(
    _DetailSwitchSourceCandidate candidate, {
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) {
    final sourceScore = scoreStore.sourceScores[candidate.book.sourceId] ?? 0;
    final bookScore =
        scoreStore.bookScores[_switchSourceScoreService.buildBookScoreKey(
          sourceId: candidate.book.sourceId,
          title: candidate.book.title,
          author: candidate.book.author,
        )] ??
        0;
    return candidate.copyWith(
      sourceScore: sourceScore,
      bookScore: bookScore,
      score: _composeSwitchSourceCandidateScore(
        baseScore: candidate.baseScore,
        hitCount: candidate.hitCount,
        sourceScore: sourceScore,
        bookScore: bookScore,
        scoreRankingEnabled: scoreRankingEnabled,
      ),
    );
  }

  String _formatSignedScore(int score) {
    if (score > 0) {
      return '+$score';
    }
    return '$score';
  }

  Future<_DetailSwitchSourceApplyResult> _switchToCandidateSource(
    _DetailSwitchSourceCandidate candidate,
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
      final result = await _service.load(
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

      await _refreshBookshelfState(result);
      return true;
    } on AppException catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _errorText = _toUserReadableError(error);
        _tocWarningText = null;
      });
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _errorText = '加载失败，请稍后重试。';
        _tocWarningText = null;
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

  String _toUserReadableError(AppException error) {
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

class _DetailSwitchSourceCandidate {
  const _DetailSwitchSourceCandidate({
    required this.book,
    required this.sourceName,
    required this.baseScore,
    required this.hitCount,
    required this.sourceScore,
    required this.bookScore,
    required this.latestChapterLabel,
    required this.latestChapterNumber,
    required this.isPotentiallyOutdated,
    required this.score,
  });

  final Book book;
  final String sourceName;
  final int baseScore;
  final int hitCount;
  final int sourceScore;
  final int bookScore;
  final String latestChapterLabel;
  final int? latestChapterNumber;
  final bool isPotentiallyOutdated;
  final int score;

  _DetailSwitchSourceCandidate copyWith({
    int? score,
    int? sourceScore,
    int? bookScore,
  }) {
    return _DetailSwitchSourceCandidate(
      book: book,
      sourceName: sourceName,
      baseScore: baseScore,
      hitCount: hitCount,
      sourceScore: sourceScore ?? this.sourceScore,
      bookScore: bookScore ?? this.bookScore,
      latestChapterLabel: latestChapterLabel,
      latestChapterNumber: latestChapterNumber,
      isPotentiallyOutdated: isPotentiallyOutdated,
      score: score ?? this.score,
    );
  }
}

class _DetailSwitchSourceLookupState {
  const _DetailSwitchSourceLookupState({
    required this.isLoading,
    required this.sourceCount,
    required this.processedSourceCount,
    required this.candidates,
    required this.errorText,
    required this.scoreRankingEnabled,
  });

  const _DetailSwitchSourceLookupState.loading({
    required int sourceCount,
    required bool scoreRankingEnabled,
  }) : this(
         isLoading: true,
         sourceCount: sourceCount,
         processedSourceCount: 0,
         candidates: const <_DetailSwitchSourceCandidate>[],
         errorText: null,
         scoreRankingEnabled: scoreRankingEnabled,
       );

  final bool isLoading;
  final int sourceCount;
  final int processedSourceCount;
  final List<_DetailSwitchSourceCandidate> candidates;
  final String? errorText;
  final bool scoreRankingEnabled;

  _DetailSwitchSourceLookupState copyWith({
    bool? isLoading,
    int? sourceCount,
    int? processedSourceCount,
    List<_DetailSwitchSourceCandidate>? candidates,
    String? errorText,
    bool clearErrorText = false,
    bool? scoreRankingEnabled,
  }) {
    return _DetailSwitchSourceLookupState(
      isLoading: isLoading ?? this.isLoading,
      sourceCount: sourceCount ?? this.sourceCount,
      processedSourceCount: processedSourceCount ?? this.processedSourceCount,
      candidates: candidates ?? this.candidates,
      errorText: clearErrorText ? null : (errorText ?? this.errorText),
      scoreRankingEnabled: scoreRankingEnabled ?? this.scoreRankingEnabled,
    );
  }
}

enum _DetailSwitchSourceScoreAction { upvote, downvote, reset }
