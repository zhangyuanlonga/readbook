import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/local_chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../bookshelf/application/local_book_import_service.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../application/local_book_detail_service.dart';

class LocalBookDetailPage extends StatefulWidget {
  const LocalBookDetailPage({super.key, required this.bookId});

  final String bookId;

  @override
  State<LocalBookDetailPage> createState() => _LocalBookDetailPageState();
}

class _LocalBookDetailPageState extends State<LocalBookDetailPage> {
  final LocalBookDetailService _detailService = LocalBookDetailService();
  final ReaderPreferencesService _readerPreferencesService =
      ReaderPreferencesService();

  bool _isLoading = true;
  String? _errorText;
  LocalBookDetailResult? _result;
  ReadingProgress? _progress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地书籍详情'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _load(forceReindex: true),
            tooltip: '重新索引',
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
            if (_isLoading)
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
                      Expanded(child: Text('正在解析本地书籍章节...')),
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
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorText!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => _load(forceReindex: true),
                        child: const Text('重试解析'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_result != null) ...[
              _buildBookCard(_result!),
              const SizedBox(height: 12),
              _buildChapterList(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(LocalBookDetailResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    final book = result.book;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip('格式', book.format.name.toUpperCase()),
                _buildChip('章节', '${result.chapters.length}'),
                _buildChip('状态', _statusLabel(book.indexStatus)),
                _buildChip(
                  '大小',
                  '${(book.fileSize / 1024).toStringAsFixed(1)} KB',
                ),
              ],
            ),
            if (book.lastError?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                '最近错误：${book.lastError}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        result.chapters.isEmpty
                            ? null
                            : () => _openPreferredChapter(result),
                    icon: const Icon(Icons.chrome_reader_mode_outlined),
                    label: const Text('开始阅读'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterList(LocalBookDetailResult result) {
    if (result.chapters.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '当前没有可读章节，请尝试右上角重新索引。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text(
                  '章节目录',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${result.chapters.length} 章',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...result.chapters.map(_buildChapterTile),
        ],
      ),
    );
  }

  Widget _buildChapterTile(LocalChapter chapter) {
    return ListTile(
      dense: true,
      title: Text(chapter.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('第 ${chapter.chapterIndex + 1} 章'),
      onTap: () => _openChapter(chapter),
    );
  }

  Widget _buildChip(String label, String value) {
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

  Future<void> _load({bool forceReindex = false}) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final result = await _detailService.load(
        bookId: widget.bookId,
        forceReindex: forceReindex,
      );
      final progress = await _readerPreferencesService.loadProgress(
        widget.bookId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _progress =
            progress?.sourceId == LocalBookImportService.localBookSourceId
                ? progress
                : null;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.briefMessage;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '加载本地书籍失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openPreferredChapter(LocalBookDetailResult result) {
    final progress = _progress;
    if (progress != null) {
      LocalChapter? chapter;
      for (final item in result.chapters) {
        if (item.id == progress.chapterId) {
          chapter = item;
          break;
        }
      }
      if (chapter != null) {
        _openChapter(chapter);
        return;
      }
    }

    _openChapter(result.chapters.first);
  }

  void _openChapter(LocalChapter chapter) {
    final route =
        Uri(path: '/local/reader/${chapter.bookId}/${chapter.id}').toString();
    context.push(route);
  }

  String _statusLabel(LocalBookIndexStatus status) {
    return switch (status) {
      LocalBookIndexStatus.pending => '待解析',
      LocalBookIndexStatus.indexing => '解析中',
      LocalBookIndexStatus.ready => '已就绪',
      LocalBookIndexStatus.failed => '解析失败',
    };
  }
}
