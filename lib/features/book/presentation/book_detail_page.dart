import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../app/layout/app_spacing.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../reader/presentation/chapter_cache_sheets.dart';
import '../application/book_detail_service.dart';

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({
    super.key,
    required this.bookId,
    this.sourceId,
    this.detailUrl,
    this.title,
  });

  final String bookId;
  final String? sourceId;
  final String? detailUrl;
  final String? title;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final BookDetailService _service = BookDetailService();
  final BookshelfService _bookshelfService = BookshelfService();

  bool _isLoading = false;
  bool _manualTocReversed = false;
  bool _isShelfActionLoading = false;
  bool _isInBookshelf = false;
  String? _errorText;
  BookDetailLoadResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title?.trim().isNotEmpty == true ? widget.title! : '书籍详情',
        ),
        actions: [
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
              const SizedBox(height: 12),
              _buildChapterSection(_result!),
            ],
          ],
        ),
      ),
    );
  }

  bool get _isMissingParams {
    return widget.sourceId == null ||
        widget.sourceId!.trim().isEmpty ||
        widget.detailUrl == null ||
        widget.detailUrl!.trim().isEmpty;
  }

  Widget _buildDetailCard(BookDetailLoadResult result) {
    final detail = result.detail;
    final intro = _resolveIntro(detail.intro);
    final colorScheme = Theme.of(context).colorScheme;

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
                  _buildCoverPreview(detail.coverUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '点击目录章节即可开始阅读',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildMetaChip('来源', result.sourceName),
                            if (detail.author != null &&
                                detail.author!.isNotEmpty)
                              _buildMetaChip('作者', detail.author!),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final availableWidth = constraints.maxWidth;
                            final perButtonWidth =
                                (availableWidth - 10).clamp(0.0, 2000.0) / 2;
                            final useShortLabels = perButtonWidth < 170;

                            final readLabel = useShortLabels ? '阅读' : '开始阅读';
                            final shelfLabel =
                                useShortLabels
                                    ? (_isInBookshelf ? '移出' : '加入')
                                    : (_isInBookshelf ? '移出书架' : '加入书架');

                            return Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed:
                                        result.chapters.isEmpty
                                            ? null
                                            : () => _openChapter(
                                              result.chapters.first,
                                            ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        const Icon(
                                          Icons.chrome_reader_mode_outlined,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.center,
                                            child: Text(
                                              readLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        _isShelfActionLoading
                                            ? null
                                            : _toggleBookshelf,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        if (_isShelfActionLoading)
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else
                                          Icon(
                                            _isInBookshelf
                                                ? Icons.bookmark_remove_outlined
                                                : Icons.bookmark_add_outlined,
                                            size: 18,
                                          ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.center,
                                            child: Text(
                                              shelfLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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

  Widget _buildCoverPreview(String? coverUrl) {
    final uri = Uri.tryParse(coverUrl ?? '');
    if (uri != null && uri.hasScheme) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          coverUrl!,
          width: 96,
          height: 136,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) => _buildCoverFallback('封面加载失败'),
        ),
      );
    }

    return _buildCoverFallback('暂无封面');
  }

  Widget _buildCoverFallback(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      height: 136,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

  Widget _buildLatestChapterCard(Chapter latestChapter) {
    final latestTitle = _normalizeText(latestChapter.title);
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
                      maxLines: 2,
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

    if (widget.sourceId == null || widget.sourceId!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final sourceId = widget.sourceId!.trim();

    return StreamBuilder<int>(
      stream: AppDatabase.instance.watchCachedChapterCount(widget.bookId),
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
                        bookId: widget.bookId,
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
            ],
            const SizedBox(height: 10),
            ...displayedChapters.asMap().entries.map(
              (entry) => _buildChapterTile(
                displayIndex: entry.key,
                chapter: entry.value,
              ),
            ),
          ],
        ),
      ),
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
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openChapter(chapter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
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
                chapter.title,
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

  void _openChapter(Chapter chapter) {
    final route =
        Uri(
          path: '/reader/${widget.bookId}/${chapter.id}',
          queryParameters: {
            'chapterUrl': chapter.chapterUrl,
            'chapterTitle': chapter.title,
            'sourceId': widget.sourceId,
            'detailUrl': widget.detailUrl,
            'chapterIndex': chapter.index.toString(),
          },
        ).toString();

    context.push(route);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!mounted || _isMissingParams) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
      if (forceRefresh) {
        _result = null;
      }
    });

    try {
      final result = await _service.load(
        sourceId: widget.sourceId!,
        bookId: widget.bookId,
        detailUrl: widget.detailUrl!,
        fallbackTitle: widget.title,
        forceRefresh: forceRefresh,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });

      await _refreshBookshelfState(result);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = _toUserReadableError(error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '加载失败，请稍后重试。';
      });
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
}
