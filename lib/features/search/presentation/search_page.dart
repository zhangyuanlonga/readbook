import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/errors/app_exception.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/repositories/source_repository.dart';
import '../application/search_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _keywordController = TextEditingController();
  final SourceRepository _sourceRepository = SourceRepositoryImpl(
    AppDatabase.instance,
  );
  late final SearchService _searchService;

  bool _isSearching = false;
  SearchExecutionReport? _report;
  SearchCancellationToken? _activeSearchToken;
  int _searchSessionId = 0;

  @override
  void initState() {
    super.initState();
    _searchService = SearchService(sourceRepository: _sourceRepository);
  }

  @override
  void dispose() {
    _activeSearchToken?.cancel();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/bookshelf');
          },
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('搜索'),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            _buildSearchInputCard(),
            const SizedBox(height: 12),
            if (_isSearching || _report != null) _buildProgressCard(),
            if (_report != null) ...[
              const SizedBox(height: 12),
              _buildReportSummary(_report!),
              if (_report!.failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildFailureBanner(_report!),
              ],
              const SizedBox(height: 12),
              _buildResultList(_report!),
            ] else if (!_isSearching)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '输入关键词后开始搜索。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInputCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.outline),
              ),
              child: TextField(
                controller: _keywordController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
                decoration: const InputDecoration(
                  hintText: '输入书名或作者，例如：凡人修仙传',
                  border: InputBorder.none,
                  filled: false,
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _runSearch,
                    child: Text(_isSearching ? '取消并重新搜索' : '搜索'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSearching
                            ? null
                            : () {
                              _keywordController.clear();
                              setState(() {
                                _report = null;
                              });
                            },
                    child: const Text('清空结果'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final report = _report;
    final sourceCount = report?.sourceCount ?? 1;
    final processedCount = report?.processedSourceCount ?? 0;
    final progressValue =
        sourceCount == 0 ? 0.0 : (processedCount / sourceCount).clamp(0.0, 1.0);
    final progressPercent = (progressValue * 100).round();

    final progressText =
        report == null ? '正在搜索书源...' : '正在搜索 $processedCount/$sourceCount 个书源';

    return Card(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(progressText)),
                Text(
                  '$progressPercent%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSummary(SearchExecutionReport report) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSummaryChip('关键词', report.keyword),
        _buildSummaryChip('结果', '${report.books.length} 本'),
        _buildSummaryChip(
          '成功源',
          '${report.successSourceCount}/${report.sourceCount}',
        ),
        if (report.failedSourceCount > 0)
          _buildSummaryChip('失败源', '${report.failedSourceCount}'),
      ],
    );
  }

  Widget _buildSummaryChip(String label, String value) {
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

  Widget _buildFailureBanner(SearchExecutionReport report) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = report.failures.take(3).toList(growable: false);
    final canOpenDetail = report.failures.length > 3;

    final content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${report.failedSourceCount} 个书源异常',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canOpenDetail)
                Icon(Icons.chevron_right, color: colorScheme.onErrorContainer),
            ],
          ),
          const SizedBox(height: 6),
          ...preview.map(
            (failure) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${failure.sourceName} (${failure.code.name}): ${failure.message}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
          if (canOpenDetail)
            Text(
              '点击查看全部异常明细',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (report.failures.length > preview.length)
            Text(
              '其余 ${report.failures.length - preview.length} 条可在错误中心查看',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
        ],
      ),
    );

    if (!canOpenDetail) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showFailureDetails(report),
      child: content,
    );
  }

  Future<void> _showFailureDetails(SearchExecutionReport report) async {
    if (!mounted || report.failures.length <= 3) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '书源异常明细 (${report.failures.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: report.failures.length,
                    separatorBuilder:
                        (_, __) => Divider(
                          height: 1,
                          color: colorScheme.outlineVariant,
                        ),
                    itemBuilder: (context, index) {
                      final failure = report.failures[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          failure.sourceName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          '[${failure.code.name}] ${failure.message}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  Widget _buildResultList(SearchExecutionReport report) {
    final books = report.books;
    if (books.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '暂无可展示结果，请检查书源规则或更换关键词。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      children: books
          .map((book) => _buildBookCard(book, report.sourceNames))
          .toList(growable: false),
    );
  }

  Widget _buildBookCard(Book book, Map<String, String> sourceNames) {
    final sourceName = sourceNames[book.sourceId] ?? book.sourceId;
    final latestChapter = _normalizeSnippet(book.latestChapter);
    final intro = _normalizeSnippet(book.intro);
    final author = book.author?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final route =
              Uri(
                path: '/book/${book.id}',
                queryParameters: {
                  'sourceId': book.sourceId,
                  'detailUrl': book.detailUrl,
                  'title': book.title,
                },
              ).toString();
          context.push(route);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCoverPreview(book.coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildInfoPill('来源', sourceName),
                        if (author != null && author.isNotEmpty)
                          _buildInfoPill('作者', author),
                      ],
                    ),
                    if (latestChapter != null && latestChapter.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '最新章节: $latestChapter',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (intro != null && intro.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            intro,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Center(
                child: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  Widget _buildCoverPreview(String? coverUrl) {
    final uri = Uri.tryParse(coverUrl ?? '');
    if (uri == null || !uri.hasScheme) {
      return _buildCoverFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        coverUrl!,
        width: 56,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildCoverFallback(),
      ),
    );
  }

  Widget _buildCoverFallback() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 56,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('封面', style: Theme.of(context).textTheme.labelSmall),
    );
  }

  String? _normalizeSnippet(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    var normalized = text
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    normalized = normalized
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

    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _runSearch() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      _showMessage('请输入关键词。');
      return;
    }

    FocusScope.of(context).unfocus();

    final sessionId = ++_searchSessionId;
    if (_isSearching) {
      _activeSearchToken?.cancel();
    }

    final token = SearchCancellationToken();
    _activeSearchToken = token;

    setState(() {
      _isSearching = true;
      _report = null;
    });

    try {
      final report = await _searchService.search(
        keyword: keyword,
        cancellationToken: token,
        onProgress: (progress) {
          if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
            return;
          }
          setState(() {
            _report = progress;
          });
        },
      );

      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }

      setState(() {
        _report = report;
      });

      if (report.books.isEmpty) {
        _showMessage('搜索完成，但没有命中结果。');
      }
    } on AppException catch (error) {
      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }
      _showMessage(error.briefMessage);
    } catch (_) {
      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }
      _showMessage('搜索失败，请稍后重试。');
    } finally {
      if (mounted && sessionId == _searchSessionId) {
        setState(() {
          _isSearching = false;
          if (identical(_activeSearchToken, token)) {
            _activeSearchToken = null;
          }
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
