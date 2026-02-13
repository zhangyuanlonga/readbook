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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSearchInput(context),
          const SizedBox(height: 12),
          if (_isSearching) _buildSearchingCard() else const SizedBox.shrink(),
          if (_report != null) ...[
            const SizedBox(height: 12),
            _buildReportSummary(_report!),
            const SizedBox(height: 12),
            if (_report!.failures.isNotEmpty) _buildFailureList(_report!),
            const SizedBox(height: 12),
            _buildResultList(_report!),
          ] else if (!_isSearching)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('输入关键词后开始搜索。'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchInput(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _keywordController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: const InputDecoration(
                hintText: '输入书名或作者，例如：凡人修仙传',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _runSearch,
                  icon: Icon(_isSearching ? Icons.refresh : Icons.search),
                  label: Text(_isSearching ? '取消并重新搜索' : '搜索'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingCard() {
    final report = _report;
    final progressText =
        report == null
            ? '正在搜索，请稍候...'
            : '正在搜索，已完成 ${report.processedSourceCount}/${report.sourceCount} 个书源，命中 ${report.books.length} 本。';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(progressText)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSummary(SearchExecutionReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('关键词：${report.keyword}'),
            const SizedBox(height: 6),
            Text(
              '命中 ${report.books.length} 本，成功源 ${report.successSourceCount}/${report.sourceCount}，失败 ${report.failedSourceCount}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureList(SearchExecutionReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('失败书源', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...report.failures.map(
              (failure) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${failure.sourceName} (${failure.code.name})',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        failure.message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      if (failure.requestUrl != null &&
                          failure.requestUrl!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SelectableText(
                          failure.requestUrl!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultList(SearchExecutionReport report) {
    final books = report.books;
    if (books.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无可展示结果，请检查书源规则或更换关键词。'),
        ),
      );
    }

    return Column(
      children:
          books
              .map((book) => _buildBookCard(book, report.sourceNames))
              .toList(),
    );
  }

  Widget _buildBookCard(Book book, Map<String, String> sourceNames) {
    final sourceName = sourceNames[book.sourceId] ?? book.sourceId;
    final latestChapter = _normalizeSnippet(book.latestChapter);
    final intro = _normalizeSnippet(book.intro);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        minLeadingWidth: 56,
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
        leading: _buildCoverPreview(book.coverUrl),
        title: Text(book.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildInfoPill('来源', sourceName),
                  if (book.author != null && book.author!.isNotEmpty)
                    _buildInfoPill('作者', book.author!),
                ],
              ),
              if (latestChapter != null && latestChapter.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '最新章节：$latestChapter',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (intro != null && intro.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    intro,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildInfoPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  Widget _buildCoverPreview(String? coverUrl) {
    final uri = Uri.tryParse(coverUrl ?? '');
    if (uri == null || !uri.hasScheme) {
      return _buildCoverFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        coverUrl!,
        width: 52,
        height: 74,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildCoverFallback(),
      ),
    );
  }

  Widget _buildCoverFallback() {
    return Container(
      width: 52,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('封面', style: TextStyle(fontSize: 11)),
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
    } catch (error) {
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
