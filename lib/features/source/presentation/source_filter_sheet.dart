import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../data/datasources/local/app_database.dart';

class SourceFilterSheetConfig {
  const SourceFilterSheetConfig({
    required this.initialSelectedIds,
    this.enabledOnly = true,
    this.isMangaSource,
    this.title = '指定书源',
    this.searchHintText = '搜索书源名称或域名',
    this.allSelectionLabel = '全部书源',
    this.allSummaryLabel = '全部',
    this.cancelButtonText = '取消',
    this.applyButtonText = '应用筛选',
  });

  final Set<String> initialSelectedIds;
  final bool enabledOnly;
  final bool? isMangaSource;
  final String title;
  final String searchHintText;
  final String allSelectionLabel;
  final String allSummaryLabel;
  final String cancelButtonText;
  final String applyButtonText;
}

Future<Set<String>?> showSourceFilterSheet({
  required BuildContext context,
  required SourceFilterSheetConfig config,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _SourceFilterSheet(config: config),
  );
}

class _SourceFilterSheet extends StatefulWidget {
  const _SourceFilterSheet({required this.config});

  final SourceFilterSheetConfig config;

  @override
  State<_SourceFilterSheet> createState() => _SourceFilterSheetState();
}

class _SourceFilterSheetState extends State<_SourceFilterSheet> {
  static const int _kPageSize = 80;
  static const Duration _kPageLoadTimeout = Duration(seconds: 8);

  final TextEditingController _keywordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _searchDebounce;
  late Set<String> _draftSelectedIds;
  List<SourceListItem> _visibleSources = const <SourceListItem>[];
  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  bool _hasMorePages = true;
  int _nextOffset = 0;
  int _totalCount = 0;
  int _queryTicket = 0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _draftSelectedIds = <String>{...widget.config.initialSelectedIds};
    _keywordController.addListener(_onKeywordChanged);
    _scrollController.addListener(_onScroll);
    unawaited(_reloadSourcePage(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _keywordController.removeListener(_onKeywordChanged);
    _keywordController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onKeywordChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_reloadSourcePage(reset: true));
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isInitialLoading || _isPageLoading) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels + 320 >= position.maxScrollExtent) {
      unawaited(_reloadSourcePage(reset: false));
    }
  }

  Future<void> _reloadSourcePage({required bool reset}) async {
    if (!reset && (!_hasMorePages || _isPageLoading)) {
      return;
    }

    final keyword = _keywordController.text.trim();
    final ticket = reset ? ++_queryTicket : _queryTicket;

    setState(() {
      _isPageLoading = true;
      if (reset) {
        _isInitialLoading = true;
        _hasMorePages = true;
        _nextOffset = 0;
        _totalCount = 0;
        _visibleSources = const <SourceListItem>[];
        _errorText = null;
      }
    });

    try {
      final pageFuture = AppDatabase.instance.querySourceListItems(
        offset: reset ? 0 : _nextOffset,
        limit: _kPageSize,
        keyword: keyword,
        enabledOnly: widget.config.enabledOnly,
        isMangaSource: widget.config.isMangaSource,
      );

      final totalFuture =
          reset
              ? AppDatabase.instance.countSourceListItems(
                keyword: keyword,
                enabledOnly: widget.config.enabledOnly,
                isMangaSource: widget.config.isMangaSource,
              )
              : Future<int>.value(_totalCount);

      final page = await pageFuture.timeout(_kPageLoadTimeout);
      final total = await totalFuture.timeout(_kPageLoadTimeout);

      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _totalCount = total;
        _visibleSources = reset ? page : [..._visibleSources, ...page];
        _nextOffset = reset ? page.length : (_nextOffset + page.length);
        _hasMorePages = _nextOffset < _totalCount;
        _isInitialLoading = false;
        _isPageLoading = false;
        _errorText = null;
      });
    } on TimeoutException {
      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _isInitialLoading = false;
        _isPageLoading = false;
        _errorText = '加载书源超时，请稍后重试。';
      });
    } catch (error) {
      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _isInitialLoading = false;
        _isPageLoading = false;
        _errorText = '加载书源失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final heightFactor = AppLayout.sheetHeightFactor(
      context,
      compact: 0.9,
      regular: 0.85,
      large: 0.82,
    );
    final horizontal = AppSpacing.pageHorizontal(context);

    final summaryText =
        _draftSelectedIds.isEmpty
            ? '当前：${widget.config.allSummaryLabel} ($_totalCount)'
            : '当前：${_draftSelectedIds.length} 个';
    final summaryStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.config.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.config.searchHintText,
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final actionButtons = <Widget>[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _draftSelectedIds = <String>{};
                      });
                    },
                    child: Text(widget.config.allSelectionLabel),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _draftSelectedIds.addAll(
                          _visibleSources.map((item) => item.id),
                        );
                      });
                    },
                    child: const Text('全选已加载'),
                  ),
                ];

                if (constraints.maxWidth < AppLayout.actionWrapWidth) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, runSpacing: 0, children: actionButtons),
                      const SizedBox(height: 2),
                      Text(summaryText, style: summaryStyle),
                    ],
                  );
                }

                return Row(
                  children: [
                    ...actionButtons,
                    const Spacer(),
                    Text(summaryText, style: summaryStyle),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildBody()),
            const SizedBox(height: 8),
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(widget.config.cancelButtonText),
                ),
                FilledButton(
                  onPressed:
                      () =>
                          Navigator.of(context).pop(_draftSelectedIds.toSet()),
                  child: Text(widget.config.applyButtonText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorText != null && _visibleSources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorText!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => unawaited(_reloadSourcePage(reset: true)),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_visibleSources.isEmpty) {
      return Center(
        child: Text('未匹配到书源', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final itemCount = _visibleSources.length + (_isPageLoading ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _visibleSources.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final source = _visibleSources[index];
        final selected = _draftSelectedIds.contains(source.id);
        return CheckboxListTile(
          value: selected,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            source.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            source.baseUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onChanged: (value) {
            setState(() {
              if (value ?? false) {
                _draftSelectedIds.add(source.id);
              } else {
                _draftSelectedIds.remove(source.id);
              }
            });
          },
        );
      },
    );
  }
}
