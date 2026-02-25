import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/source_definition.dart';
import '../application/explore_service.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const double _expandedBreakpoint = 840;
  static const int _bookPageSize = 24;
  static const int _compactCategoryPreviewCount = 10;
  static const Set<PointerDeviceKind> _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  late final ExploreService _exploreService;
  final ScrollController _booksScrollController = ScrollController();

  bool _isLoadingSources = false;
  bool _isLoadingCategories = false;
  bool _isLoadingBooks = false;
  bool _isLoadingMore = false;
  int _enabledSourceCount = 0;
  int _discoverCapableCount = 0;

  List<SourceDefinition> _discoverSources = const <SourceDefinition>[];
  SourceDefinition? _selectedSource;
  List<ExploreCategoryItem> _categories = const <ExploreCategoryItem>[];
  int _selectedCategoryIndex = -1;
  List<Book> _books = const <Book>[];

  int _nextPage = 1;
  bool _hasMore = false;
  String? _requestUrl;

  String? _sourceErrorText;
  String? _bookErrorText;

  int _sourceRequestToken = 0;
  int _categoryRequestToken = 0;
  int _bookRequestToken = 0;

  ExploreCategoryItem? get _selectedCategory {
    if (_selectedCategoryIndex < 0 ||
        _selectedCategoryIndex >= _categories.length) {
      return null;
    }
    return _categories[_selectedCategoryIndex];
  }

  @override
  void initState() {
    super.initState();
    _exploreService = ExploreService();
    _booksScrollController.addListener(_onBookListScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadSources());
    });
  }

  @override
  void dispose() {
    _booksScrollController.removeListener(_onBookListScroll);
    _booksScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
        actions: <Widget>[
          IconButton(
            onPressed:
                _isLoadingSources || _discoverSources.isEmpty
                    ? null
                    : _showSourcePicker,
            tooltip: '切换书源',
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              colorScheme.surface,
              colorScheme.surfaceContainerLow,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _expandedBreakpoint) {
                  return _buildWideLayout(
                    context,
                    sidePanelWidth: 300,
                    maxContentWidth: 980,
                  );
                }
                if (constraints.maxWidth >= AppLayout.railBreakpointWidth) {
                  return _buildWideLayout(
                    context,
                    sidePanelWidth: 250,
                    maxContentWidth: 880,
                  );
                }
                return _buildCompactLayout(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _onBookListScroll() {
    if (!_booksScrollController.hasClients ||
        _isLoadingBooks ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }
    final position = _booksScrollController.position;
    if (position.pixels + 280 >= position.maxScrollExtent) {
      unawaited(_loadBooks(reset: false));
    }
  }

  Widget _buildCompactLayout(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: _dragDevices,
      ),
      child: RefreshIndicator(
        onRefresh: _refreshCurrentView,
        child: ListView(
          controller: _booksScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            _buildSourceSelectorCard(context),
            const SizedBox(height: 12),
            _buildCategoryStripCard(context),
            const SizedBox(height: 12),
            _buildBooksPaneContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context, {
    required double sidePanelWidth,
    required double maxContentWidth,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(width: sidePanelWidth, child: _buildSidePanel(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: _dragDevices,
                ),
                child: RefreshIndicator(
                  onRefresh: _refreshCurrentView,
                  child: ListView(
                    controller: _booksScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      _buildBooksHeaderCard(context),
                      const SizedBox(height: 12),
                      _buildBooksPaneContent(context, includeHeader: false),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildSourceSelectorCard(context),
        const SizedBox(height: 12),
        Expanded(child: _buildCategoryPanelCard(context)),
      ],
    );
  }

  Widget _buildSourceSelectorCard(BuildContext context) {
    final source = _selectedSource;
    final summary =
        source == null
            ? (_isLoadingSources ? '正在加载可用书源...' : '请选择书源')
            : _buildSourceSummary(source);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '当前书源',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _isLoadingSources || _discoverSources.isEmpty
                          ? null
                          : _showSourcePicker,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('切换'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_isLoadingSources) ...<Widget>[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 8),
            ],
            Text(
              source?.name ?? '未选择书源',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_enabledSourceCount > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '已启用书源：$_enabledSourceCount · 支持发现：$_discoverCapableCount',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryStripCard(BuildContext context) {
    if (_isLoadingSources && _discoverSources.isEmpty) {
      return _buildLoadingCard(context, message: '正在加载发现书源...');
    }
    if (_discoverSources.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_sourceErrorText != null) {
      return _buildErrorCard(
        context,
        message: _sourceErrorText!,
        onRetry: _reloadCurrentSource,
      );
    }
    if (_isLoadingCategories) {
      return _buildLoadingCard(context, message: '正在解析分类...');
    }
    if (_categories.isEmpty) {
      return _buildInfoCard(context, message: '该书源没有可用的发现分类。');
    }

    final previewCount = math.min(
      _categories.length,
      _compactCategoryPreviewCount,
    );
    final hiddenCount = _categories.length - previewCount;
    final children = <Widget>[
      for (var index = 0; index < previewCount; index++)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _buildCategoryChip(context, index, _categories[index]),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '发现分类',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showCategoryPicker,
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text('全部 ${_categories.length}'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: children),
            ),
            if (hiddenCount > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '还有 $hiddenCount 个分类，可点“全部”查看。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    int index,
    ExploreCategoryItem item,
  ) {
    final isSelected = index == _selectedCategoryIndex;
    if (item.isActionable) {
      return ChoiceChip(
        label: Text(item.title),
        selected: isSelected,
        onSelected: (_) => _selectCategory(index),
      );
    }

    return Chip(
      avatar: Icon(
        Icons.label_outline_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      label: Text(item.title),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildCategoryPanelCard(BuildContext context) {
    if (_isLoadingSources && _discoverSources.isEmpty) {
      return _buildLoadingCard(context, message: '正在加载发现书源...');
    }
    if (_discoverSources.isEmpty) {
      return _buildInfoCard(context, message: '暂无支持发现的书源。');
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          ListTile(
            title: Text(
              '发现分类',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${_categories.length} 个分类'),
            trailing: IconButton(
              onPressed: _categories.isEmpty ? null : _showCategoryPicker,
              tooltip: '全部分类',
              icon: const Icon(Icons.list_alt_rounded),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildCategoryPanelBody(context)),
        ],
      ),
    );
  }

  Widget _buildCategoryPanelBody(BuildContext context) {
    if (_sourceErrorText != null) {
      return _buildPanelMessage(
        context,
        message: _sourceErrorText!,
        icon: Icons.warning_amber_rounded,
      );
    }
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_categories.isEmpty) {
      return _buildPanelMessage(
        context,
        message: '该书源没有可用的发现分类。',
        icon: Icons.grid_off_rounded,
      );
    }

    return ListView.separated(
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _categories[index];
        final selected = index == _selectedCategoryIndex;
        final textColor =
            item.isActionable
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant;

        return Material(
          color:
              selected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Colors.transparent,
          child: InkWell(
            onTap: item.isActionable ? () => _selectCategory(index) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (!item.isActionable)
                    Text(
                      '分组',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (selected) ...<Widget>[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBooksHeaderCard(BuildContext context) {
    final source = _selectedSource;
    final category = _selectedCategory;
    final sourceName = source?.name ?? '未选择书源';
    final categoryName = category?.title ?? '未选择分类';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _refreshCurrentView,
                  tooltip: '刷新',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildInfoPill(context, label: '书籍', value: '${_books.length}'),
                if (_hasMore)
                  _buildInfoPill(context, label: '下一页', value: '$_nextPage'),
              ],
            ),
            if (_requestUrl != null && _requestUrl!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _requestUrl!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBooksPaneContent(
    BuildContext context, {
    bool includeHeader = true,
  }) {
    if (_isLoadingSources && _discoverSources.isEmpty) {
      return _buildLoadingCard(context, message: '正在加载发现书源...');
    }
    if (_discoverSources.isEmpty) {
      return _buildNoSourceCard(context);
    }
    if (_sourceErrorText != null) {
      return _buildErrorCard(
        context,
        message: _sourceErrorText!,
        onRetry: _reloadCurrentSource,
      );
    }
    if (_isLoadingCategories) {
      return _buildLoadingCard(context, message: '正在解析发现分类...');
    }
    if (_categories.isEmpty) {
      return _buildInfoCard(context, message: '该书源没有可用的发现分类。');
    }

    final category = _selectedCategory;
    if (category == null) {
      return _buildInfoCard(context, message: '请选择分类以加载书单。');
    }
    if (!category.isActionable) {
      return _buildInfoCard(context, message: '当前分类不可点击，请切换其他分类。');
    }
    if (_isLoadingBooks && _books.isEmpty) {
      return _buildLoadingCard(context, message: '正在加载书单...');
    }
    if (_bookErrorText != null && _books.isEmpty) {
      return _buildErrorCard(
        context,
        message: _bookErrorText!,
        onRetry: () => _loadBooks(reset: true),
      );
    }
    if (_books.isEmpty) {
      return _buildInfoCard(context, message: '当前分类暂无书籍。');
    }

    final children = <Widget>[
      for (final entry in _books.asMap().entries)
        _buildBookCard(context, entry.value, listIndex: entry.key),
    ];

    if (_bookErrorText != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildErrorCard(
            context,
            message: _bookErrorText!,
            onRetry: () => _loadBooks(reset: false),
            actionLabel: '重试翻页',
          ),
        ),
      );
    }

    if (_isLoadingMore) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (_hasMore) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton.icon(
            onPressed: () => _loadBooks(reset: false),
            icon: const Icon(Icons.expand_more_rounded),
            label: const Text('加载下一页'),
          ),
        ),
      );
    } else {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '已加载全部内容',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (!includeHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildBooksHeaderCard(context),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildBookCard(
    BuildContext context,
    Book book, {
    required int listIndex,
  }) {
    final author = _normalizeSnippet(book.author);
    final latestChapter = _normalizeSnippet(book.latestChapter);
    final intro = _normalizeSnippet(book.intro);
    final heroTag = _buildBookCoverHeroTag(book: book, listIndex: listIndex);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openBookDetail(book, heroTag: heroTag),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _buildCoverPreview(book.coverUrl, heroTag: heroTag),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
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
                      children: <Widget>[
                        _buildInfoPill(
                          context,
                          label: '来源',
                          value: _selectedSource?.name ?? book.sourceId,
                        ),
                        if (author != null && author.isNotEmpty)
                          _buildInfoPill(context, label: '作者', value: author),
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
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPreview(String? coverUrl, {required String heroTag}) {
    final trimmed = coverUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return Hero(tag: heroTag, child: _buildCoverFallback());
    }

    return Hero(
      tag: heroTag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          trimmed,
          width: 52,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildCoverFallback(),
        ),
      ),
    );
  }

  Widget _buildCoverFallback() {
    return Container(
      width: 52,
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_rounded,
        size: 22,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildInfoPill(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colorScheme.secondaryContainer,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '$label: $value',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context, {required String message}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
    String actionLabel = '重试',
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String message}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _buildNoSourceCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '暂无支持发现的已启用书源',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '请先在书源页导入并启用带 `exploreUrl + ruleExplore` 的书源。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_enabledSourceCount > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '当前已启用：$_enabledSourceCount，支持发现：$_discoverCapableCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go('/source'),
              icon: const Icon(Icons.storage_rounded),
              label: const Text('前往书源页'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadSources,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('刷新识别结果'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelMessage(
    BuildContext context, {
    required String message,
    required IconData icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSources() async {
    final requestToken = ++_sourceRequestToken;
    final previousSourceId = _selectedSource?.id;

    setState(() {
      _isLoadingSources = true;
      _sourceErrorText = null;
      _bookErrorText = null;
    });

    try {
      final summary = await _exploreService.loadDiscoverSourceSummary();
      final loadedSources = summary.discoverSources;
      loadedSources.sort((left, right) {
        final groupCompare = (left.group ?? '').compareTo(right.group ?? '');
        if (groupCompare != 0) {
          return groupCompare;
        }
        return left.name.compareTo(right.name);
      });

      if (!mounted || requestToken != _sourceRequestToken) {
        return;
      }

      final selected = _findSourceById(loadedSources, previousSourceId);
      setState(() {
        _enabledSourceCount = summary.enabledSourceCount;
        _discoverCapableCount = summary.discoverCapableCount;
        _discoverSources = loadedSources;
        _selectedSource = selected;
        _isLoadingSources = false;
        _categories = const <ExploreCategoryItem>[];
        _selectedCategoryIndex = -1;
        _books = const <Book>[];
        _nextPage = 1;
        _hasMore = false;
        _requestUrl = null;
      });

      if (selected != null) {
        await _loadCategoriesForSource(
          selected,
          preserveCurrentCategory: false,
        );
      }
    } catch (error) {
      if (!mounted || requestToken != _sourceRequestToken) {
        return;
      }
      setState(() {
        _enabledSourceCount = 0;
        _discoverCapableCount = 0;
        _isLoadingSources = false;
        _sourceErrorText = _toReadableError(error, fallback: '加载发现书源失败');
      });
    }
  }

  Future<void> _reloadCurrentSource() async {
    final source = _selectedSource;
    if (source == null) {
      await _loadSources();
      return;
    }
    await _loadCategoriesForSource(source, preserveCurrentCategory: true);
  }

  Future<void> _loadCategoriesForSource(
    SourceDefinition source, {
    required bool preserveCurrentCategory,
  }) async {
    final requestToken = ++_categoryRequestToken;
    final previousCategory = preserveCurrentCategory ? _selectedCategory : null;

    setState(() {
      _selectedSource = source;
      _isLoadingCategories = true;
      _sourceErrorText = null;
      _bookErrorText = null;
      _categories = const <ExploreCategoryItem>[];
      _selectedCategoryIndex = -1;
      _books = const <Book>[];
      _nextPage = 1;
      _hasMore = false;
      _requestUrl = null;
    });

    try {
      final parsedCategories = _exploreService.parseCategories(source);
      if (!mounted || requestToken != _categoryRequestToken) {
        return;
      }

      final nextCategoryIndex = _resolveCategorySelection(
        categories: parsedCategories,
        previousCategory: previousCategory,
      );

      setState(() {
        _isLoadingCategories = false;
        _categories = parsedCategories;
        _selectedCategoryIndex = nextCategoryIndex;
      });

      if (nextCategoryIndex >= 0 &&
          nextCategoryIndex < parsedCategories.length &&
          parsedCategories[nextCategoryIndex].isActionable) {
        await _loadBooks(reset: true);
      }
    } catch (error) {
      if (!mounted || requestToken != _categoryRequestToken) {
        return;
      }
      setState(() {
        _isLoadingCategories = false;
        _sourceErrorText = _toReadableError(error, fallback: '解析发现分类失败');
      });
    }
  }

  Future<void> _loadBooks({required bool reset}) async {
    final source = _selectedSource;
    final category = _selectedCategory;
    if (source == null || category == null || !category.isActionable) {
      return;
    }
    if (!reset && (_isLoadingMore || _isLoadingBooks || !_hasMore)) {
      return;
    }

    final requestToken = ++_bookRequestToken;
    final targetPage = reset ? 1 : _nextPage;

    setState(() {
      _bookErrorText = null;
      if (reset) {
        _isLoadingBooks = true;
        _books = const <Book>[];
        _nextPage = 1;
        _hasMore = false;
        _requestUrl = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final result = await _exploreService.loadBooks(
        source: source,
        category: category,
        page: targetPage,
        pageSize: _bookPageSize,
      );

      if (!mounted || requestToken != _bookRequestToken) {
        return;
      }

      final mergedBooks =
          reset ? result.books : <Book>[..._books, ...result.books];
      final deduplicatedBooks = _deduplicateBooks(mergedBooks);

      setState(() {
        _books = deduplicatedBooks;
        _nextPage = result.page + 1;
        _hasMore = result.hasMore && result.books.isNotEmpty;
        _requestUrl = result.requestUrl;
        _isLoadingBooks = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestToken != _bookRequestToken) {
        return;
      }
      setState(() {
        _isLoadingBooks = false;
        _isLoadingMore = false;
        _hasMore = !reset;
        if (reset) {
          _books = const <Book>[];
        }
        _bookErrorText = _toReadableError(error, fallback: '加载书单失败');
      });
    }
  }

  Future<void> _refreshCurrentView() async {
    final category = _selectedCategory;
    if (category != null && category.isActionable) {
      await _loadBooks(reset: true);
      return;
    }

    final source = _selectedSource;
    if (source != null) {
      await _loadCategoriesForSource(source, preserveCurrentCategory: true);
      return;
    }
    await _loadSources();
  }

  int _resolveCategorySelection({
    required List<ExploreCategoryItem> categories,
    ExploreCategoryItem? previousCategory,
  }) {
    if (categories.isEmpty) {
      return -1;
    }

    if (previousCategory != null) {
      final matchIndex = categories.indexWhere(
        (item) =>
            item.title == previousCategory.title &&
            item.url == previousCategory.url,
      );
      if (matchIndex >= 0) {
        return matchIndex;
      }
    }

    final firstActionableIndex = categories.indexWhere(
      (item) => item.isActionable,
    );
    if (firstActionableIndex >= 0) {
      return firstActionableIndex;
    }
    return 0;
  }

  void _selectCategory(int index) {
    if (index < 0 || index >= _categories.length) {
      return;
    }
    if (index == _selectedCategoryIndex && _books.isNotEmpty) {
      return;
    }

    final item = _categories[index];
    setState(() {
      _selectedCategoryIndex = index;
      _bookErrorText = null;
      _requestUrl = null;
      _nextPage = 1;
      _hasMore = false;
      _books = const <Book>[];
    });

    if (!item.isActionable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该分类为分组标题，无法直接加载书单。')));
      return;
    }
    unawaited(_loadBooks(reset: true));
  }

  Future<void> _showSourcePicker() async {
    if (_discoverSources.isEmpty) {
      return;
    }

    final selected = await showModalBottomSheet<SourceDefinition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => _SourcePickerSheet(
            sources: _discoverSources,
            selectedSourceId: _selectedSource?.id,
          ),
    );
    if (!mounted || selected == null || selected.id == _selectedSource?.id) {
      return;
    }
    await _loadCategoriesForSource(selected, preserveCurrentCategory: false);
  }

  Future<void> _showCategoryPicker() async {
    if (_categories.isEmpty) {
      return;
    }

    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => _CategoryPickerSheet(
            categories: _categories,
            selectedIndex: _selectedCategoryIndex,
          ),
    );
    if (!mounted || selectedIndex == null) {
      return;
    }
    _selectCategory(selectedIndex);
  }

  SourceDefinition? _findSourceById(
    List<SourceDefinition> sources,
    String? sourceId,
  ) {
    if (sourceId == null || sourceId.isEmpty) {
      return sources.isEmpty ? null : sources.first;
    }
    for (final source in sources) {
      if (source.id == sourceId) {
        return source;
      }
    }
    return sources.isEmpty ? null : sources.first;
  }

  List<Book> _deduplicateBooks(List<Book> books) {
    final seenIds = <String>{};
    final output = <Book>[];
    for (final book in books) {
      if (seenIds.add(book.id)) {
        output.add(book);
      }
    }
    return output;
  }

  void _openBookDetail(Book book, {required String heroTag}) {
    final route =
        Uri(
          path: '/book/${book.id}',
          queryParameters: <String, String>{
            'sourceId': book.sourceId,
            'detailUrl': book.detailUrl,
            'title': book.title,
            'heroTag': heroTag,
          },
        ).toString();
    context.push(route);
  }

  String _buildBookCoverHeroTag({required Book book, required int listIndex}) {
    return 'discover_cover_${book.sourceId}_${book.id}_${book.detailUrl.hashCode}_$listIndex';
  }

  String _buildSourceSummary(SourceDefinition source) {
    final group = source.group?.trim();
    final host = _extractHost(source.baseUrl);
    if (group == null || group.isEmpty) {
      return host;
    }
    return '$group · $host';
  }

  String _extractHost(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    return host.isEmpty ? url : host;
  }

  String _toReadableError(Object error, {required String fallback}) {
    if (error is AppException) {
      return error.briefMessage;
    }
    return '$fallback：$error';
  }

  String? _normalizeSnippet(String? text) {
    if (text == null) {
      return null;
    }

    var normalized = text.trim();
    if (normalized.isEmpty) {
      return null;
    }

    normalized =
        normalized
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll(RegExp(r'[\u3000\s]+'), ' ')
            .trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class _SourcePickerSheet extends StatefulWidget {
  const _SourcePickerSheet({
    required this.sources,
    required this.selectedSourceId,
  });

  final List<SourceDefinition> sources;
  final String? selectedSourceId;

  @override
  State<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<_SourcePickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  List<SourceDefinition> get _filteredSources {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      return widget.sources;
    }
    return widget.sources
        .where((source) {
          final host = _extractHost(source.baseUrl).toLowerCase();
          final group = (source.group ?? '').toLowerCase();
          final name = source.name.toLowerCase();
          return name.contains(keyword) ||
              group.contains(keyword) ||
              host.contains(keyword);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSources = _filteredSources;
    final horizontal = AppSpacing.pageHorizontal(context);
    final height = MediaQuery.sizeOf(context).height;
    final heightFactor = height < 700 ? 0.92 : 0.85;

    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 16),
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '切换发现书源',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索书源名称、分组或域名',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  filteredSources.isEmpty
                      ? Center(
                        child: Text(
                          '没有匹配的书源',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                      : ListView.separated(
                        itemCount: filteredSources.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final source = filteredSources[index];
                          final selected = source.id == widget.selectedSourceId;
                          return ListTile(
                            onTap: () => Navigator.of(context).pop(source),
                            leading: const Icon(Icons.storage_outlined),
                            title: Text(
                              source.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _buildSourceSummary(source),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing:
                                selected
                                    ? Icon(
                                      Icons.check_circle_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    )
                                    : null,
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSourceSummary(SourceDefinition source) {
    final host = _extractHost(source.baseUrl);
    final group = source.group?.trim();
    if (group == null || group.isEmpty) {
      return host;
    }
    return '$group · $host';
  }

  String _extractHost(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    return host.isEmpty ? url : host;
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedIndex,
  });

  final List<ExploreCategoryItem> categories;
  final int selectedIndex;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchController.text.trim();
    final lowerKeyword = keyword.toLowerCase();
    final indexed = widget.categories
        .asMap()
        .entries
        .where((entry) {
          if (lowerKeyword.isEmpty) {
            return true;
          }
          return entry.value.title.toLowerCase().contains(lowerKeyword);
        })
        .toList(growable: false);

    final horizontal = AppSpacing.pageHorizontal(context);
    final height = MediaQuery.sizeOf(context).height;
    final heightFactor = height < 700 ? 0.92 : 0.85;

    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 16),
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '选择分类',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索分类',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  indexed.isEmpty
                      ? Center(
                        child: Text(
                          '没有匹配的分类',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                      : ListView.separated(
                        itemCount: indexed.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, row) {
                          final index = indexed[row].key;
                          final item = indexed[row].value;
                          final selected = index == widget.selectedIndex;

                          return ListTile(
                            enabled: item.isActionable,
                            onTap:
                                item.isActionable
                                    ? () => Navigator.of(context).pop(index)
                                    : null,
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle:
                                item.isActionable
                                    ? null
                                    : const Text('分组标题，不可直接加载'),
                            trailing:
                                selected
                                    ? Icon(
                                      Icons.check_circle_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    )
                                    : null,
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
