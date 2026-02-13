import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../bookshelf/application/bookshelf_service.dart';
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
          IconButton(
            onPressed:
                _isLoading || _result == null || _isShelfActionLoading
                    ? null
                    : _toggleBookshelf,
            tooltip: _isInBookshelf ? '移出书架' : '加入书架',
            icon:
                _isShelfActionLoading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Icon(
                      _isInBookshelf
                          ? Icons.bookmark_added
                          : Icons.bookmark_add_outlined,
                    ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '加载失败',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
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
            if (_resolveLatestChapter(_result!) != null) ...[
              const SizedBox(height: 12),
              _buildLatestChapterCard(_resolveLatestChapter(_result!)!),
            ],
            const SizedBox(height: 12),
            _buildChapterSection(_result!),
          ],
        ],
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCoverPreview(detail.coverUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '点击目录章节即可开始阅读',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaChip('来源', result.sourceName),
                if (detail.author != null && detail.author!.isNotEmpty)
                  _buildMetaChip('作者', detail.author!),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      result.chapters.isEmpty
                          ? null
                          : () => _openChapter(result.chapters.first),
                  icon: const Icon(Icons.chrome_reader_mode_outlined),
                  label: const Text('开始阅读'),
                ),
                OutlinedButton.icon(
                  onPressed: _isShelfActionLoading ? null : _toggleBookshelf,
                  icon:
                      _isShelfActionLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            _isInBookshelf
                                ? Icons.bookmark_remove_outlined
                                : Icons.bookmark_add_outlined,
                          ),
                  label: Text(_isInBookshelf ? '移出书架' : '加入书架'),
                ),
              ],
            ),
            if (intro != null) ...[
              const SizedBox(height: 12),
              _buildIntroCard(intro),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPreview(String? coverUrl) {
    final uri = Uri.tryParse(coverUrl ?? '');
    if (uri != null && uri.hasScheme) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          coverUrl!,
          width: 92,
          height: 132,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) => _buildCoverFallback('封面加载失败'),
        ),
      );
    }

    return _buildCoverFallback('暂无封面');
  }

  Widget _buildCoverFallback(String text) {
    return Container(
      width: 92,
      height: 132,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildMetaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall,
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: const Icon(Icons.new_releases_outlined),
        title: const Text('最新章节'),
        subtitle: Text(
          latestTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: FilledButton.tonal(
          onPressed: () => _openChapter(latestChapter),
          child: const Text('去阅读'),
        ),
        onTap: () => _openChapter(latestChapter),
      ),
    );
  }

  Widget _buildIntroCard(String intro) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('简介', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(intro, style: Theme.of(context).textTheme.bodyMedium),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '目录（${displayedChapters.length} 章）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (result.tocFromCache)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '来自缓存',
                      style: Theme.of(context).textTheme.bodySmall,
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
                  icon: const Icon(Icons.swap_vert),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _manualTocReversed ? '当前展示：倒序' : '当前展示：正序',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (displayedChapters.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () => _openChapter(displayedChapters.first),
                    child: const Text('阅读当前首章'),
                  ),
                  OutlinedButton(
                    onPressed: () => _openChapter(displayedChapters.last),
                    child: const Text('阅读当前末章'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
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
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 28,
        child: Text(
          '${displayIndex + 1}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      title: Text(chapter.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openChapter(chapter),
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
