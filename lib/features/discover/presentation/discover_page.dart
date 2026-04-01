import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/widgets/disk_cached_cover_image.dart';
import '../../../app/widgets/text_cover_placeholder.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/book.dart';
import '../../book/presentation/book_detail_route.dart';
import '../application/discover_preferences_service.dart';
import '../application/explore_service.dart';

enum _SourceRuntimeStatus {
  unknown,
  checking,
  ready,
  parseFailed,
  requestFailed,
}

enum _SourceTypeFilter { all, novel, manga, unknown }

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    ExploreService? exploreService,
    DiscoverPreferencesService? discoverPreferencesService,
  }) : _exploreService = exploreService,
       _discoverPreferencesService = discoverPreferencesService;

  final ExploreService? _exploreService;
  final DiscoverPreferencesService? _discoverPreferencesService;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with AutomaticKeepAliveClientMixin<DiscoverPage> {
  static const int _bookPageSize = 24;
  static const int _compactCategoryPreviewCount = 8;
  static const int _backgroundProbeBatchLimit = 60;
  static const Set<PointerDeviceKind> _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  late final ExploreService _exploreService;
  late final DiscoverPreferencesService _discoverPreferencesService;
  final ScrollController _booksScrollController = ScrollController();
  Timer? _sourceRefreshDebounce;

  bool _isLoadingSources = false;
  bool _isLoadingCategories = false;
  bool _isLoadingBooks = false;
  bool _isLoadingMore = false;
  int _enabledSourceCount = 0;
  int _discoverCapableCount = 0;
  int _sourceProbeToken = 0;

  List<DiscoverSource> _discoverSources = const <DiscoverSource>[];
  DiscoverSource? _selectedSource;
  List<ExploreCategoryItem> _categories = const <ExploreCategoryItem>[];
  int _selectedCategoryIndex = -1;
  List<Book> _books = const <Book>[];
  final Set<String> _probingSourceIds = <String>{};
  final Set<String> _verifiedSourceIds = <String>{};
  final Map<String, String> _sourceParseErrorById = <String, String>{};
  final Map<String, String> _sourceBookErrorById = <String, String>{};

  int _nextPage = 1;
  bool _hasMore = false;

  String? _sourceErrorText;
  String? _bookErrorText;

  int _sourceRequestToken = 0;
  int _categoryRequestToken = 0;
  int _bookRequestToken = 0;
  String? _rememberedSourceId;
  bool _isSwitchingSource = false;

  ExploreCategoryItem? get _selectedCategory {
    if (_selectedCategoryIndex < 0 ||
        _selectedCategoryIndex >= _categories.length) {
      return null;
    }
    return _categories[_selectedCategoryIndex];
  }

  List<MapEntry<int, ExploreCategoryItem>> get _actionableCategoryEntries {
    return _categories
        .asMap()
        .entries
        .where((entry) => entry.value.isActionable)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _exploreService = widget._exploreService ?? ExploreService();
    _discoverPreferencesService =
        widget._discoverPreferencesService ?? DiscoverPreferencesService();
    _booksScrollController.addListener(_onBookListScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_bootstrapDiscoverState());
    });
  }

  @override
  void dispose() {
    _sourceRefreshDebounce?.cancel();
    _booksScrollController.removeListener(_onBookListScroll);
    _booksScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);

    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
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
                if (AppLayout.isExpandedWidth(constraints.maxWidth)) {
                  return _buildWideLayout(
                    context,
                    sidePanelWidth: AppLayout.discoverExpandedSidePanelWidth,
                    maxContentWidth: AppLayout.discoverExpandedContentMaxWidth,
                  );
                }
                if (constraints.maxWidth >= AppLayout.railBreakpointWidth) {
                  return _buildWideLayout(
                    context,
                    sidePanelWidth: AppLayout.discoverMediumSidePanelWidth,
                    maxContentWidth: AppLayout.discoverMediumContentMaxWidth,
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

  @override
  bool get wantKeepAlive => true;

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

  Future<void> _bootstrapDiscoverState() async {
    try {
      _rememberedSourceId =
          await _discoverPreferencesService.loadSelectedSourceId();
    } catch (_) {
      _rememberedSourceId = null;
    }
    if (!mounted) {
      return;
    }
    await _loadSources();
  }

  Widget _buildCompactLayout(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: _dragDevices,
      ),
      child: RefreshIndicator(
        onRefresh: _refreshCurrentView,
        child: CustomScrollView(
          controller: _booksScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildSourceSelectorCard(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(child: _buildCategoryStripCard(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ..._buildBooksPaneSlivers(context),
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
                  child: CustomScrollView(
                    controller: _booksScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: _buildBooksPaneSlivers(context),
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
            ? (_isLoadingSources ? '正在加载可用源脚本...' : '请选择源脚本')
            : _buildSourceSummary(source);
    final categoryName = _selectedCategory?.title ?? '未选分类';
    final status = _resolveSourceStatus(source?.id);
    final statusDetail = _sourceStatusDetail(source?.id);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasMultipleSources = _discoverSources.length > 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // -- Row 1: status pill + switch button --
            Row(
              children: <Widget>[
                if (source != null)
                  _buildSourceStatusPill(context, status)
                else
                  Text(
                    '当前源脚本',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  key: const Key('discover_source_switch_button'),
                  onPressed:
                      _isLoadingSources || _discoverSources.isEmpty
                          ? null
                          : _showSourcePicker,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('切换'),
                ),
              ],
            ),

            // -- Loading indicator --
            if (_isLoadingSources) ...<Widget>[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 6),
            ],

            // -- Row 2: source name (prominent) --
            Text(
              source?.name ?? '未选择源脚本',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),

            // -- Row 3: source summary (group · host) --
            Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            // -- Error detail --
            if (source != null && statusDetail != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                statusDetail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: _sourceStatusColor(context, status),
                ),
              ),
              if (hasMultipleSources &&
                  status == _SourceRuntimeStatus.parseFailed) ...<Widget>[
                const SizedBox(height: 2),
                TextButton.icon(
                  onPressed: _switchToNextHealthySource,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text('切换到下一个可用源'),
                ),
              ],
            ],

            // -- Context summary box --
            if (source != null) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '分类：$categoryName · 书籍：${_books.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            ],

            // -- Source switcher buttons (fixed bottom) --
            if (source != null && hasMultipleSources) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildSourceSwitchButton(
                      key: const Key('discover_prev_source'),
                      icon: Icons.chevron_left_rounded,
                      label: '上一源',
                      compact: true,
                      onPressed: () => _handleSourceSwitch(-1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSourceSwitchButton(
                      key: const Key('discover_next_source'),
                      icon: Icons.chevron_right_rounded,
                      label: '下一源',
                      compact: true,
                      onPressed: () => _handleSourceSwitch(1),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryStripCard(BuildContext context) {
    if (_isLoadingSources && _discoverSources.isEmpty) {
      return _buildLoadingCard(context, message: '正在加载发现源脚本...');
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
      return _buildInfoCard(context, message: '该源脚本没有可用的发现分类。');
    }

    final actionableEntries = _actionableCategoryEntries;
    if (actionableEntries.isEmpty) {
      return _buildInfoCard(context, message: '该源脚本暂无可点击分类。');
    }

    final previewCount = math.min(
      actionableEntries.length,
      _compactCategoryPreviewCount,
    );
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
                  label: Text('全部 ${actionableEntries.length}'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (
                    var index = 0;
                    index < previewCount;
                    index++
                  ) ...<Widget>[
                    if (index > 0) const SizedBox(width: 8),
                    _buildCategoryChip(
                      context,
                      actionableEntries[index].key,
                      actionableEntries[index].value,
                    ),
                  ],
                ],
              ),
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = index == _selectedCategoryIndex;
    if (item.isActionable) {
      return Tooltip(
        message: item.title,
        waitDuration: const Duration(milliseconds: 250),
        child: ChoiceChip(
          label: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: colorScheme.secondaryContainer,
          side: BorderSide(
            color:
                isSelected ? colorScheme.secondary : colorScheme.outlineVariant,
          ),
          labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color:
                isSelected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          mouseCursor: SystemMouseCursors.click,
          onSelected: (_) => _selectCategory(index),
        ),
      );
    }

    return Tooltip(
      message: item.title,
      waitDuration: const Duration(milliseconds: 250),
      child: Chip(
        avatar: Icon(
          Icons.label_outline_rounded,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        label: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        labelStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        side: BorderSide(color: colorScheme.outlineVariant),
        visualDensity: VisualDensity.compact,
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildCategoryPanelCard(BuildContext context) {
    if (_isLoadingSources && _discoverSources.isEmpty) {
      return _buildLoadingCard(context, message: '正在加载发现源脚本...');
    }
    if (_discoverSources.isEmpty) {
      return _buildInfoCard(context, message: '暂无支持发现的源脚本。');
    }
    final actionableCount = _actionableCategoryEntries.length;

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
            subtitle: Text('$actionableCount 个分类'),
            trailing: IconButton(
              onPressed: actionableCount == 0 ? null : _showCategoryPicker,
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
    final actionableEntries = _actionableCategoryEntries;
    if (actionableEntries.isEmpty) {
      return _buildPanelMessage(
        context,
        message: '该源脚本暂无可点击分类。',
        icon: Icons.grid_off_rounded,
      );
    }

    return ListView.separated(
      itemCount: actionableEntries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, row) {
        final entry = actionableEntries[row];
        final index = entry.key;
        final item = entry.value;
        final selected = index == _selectedCategoryIndex;
        final textColor = Theme.of(context).colorScheme.onSurface;

        return Material(
          color:
              selected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Colors.transparent,
          child: InkWell(
            onTap: () => _selectCategory(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        if (_buildCategoryStyleHintText(item)
                            case final hint?) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
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

  List<Widget> _buildBooksPaneSlivers(BuildContext context) {
    if (_isLoadingSources && _discoverSources.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildLoadingCard(context, message: '正在加载发现源脚本...'),
        ),
      ];
    }
    if (_discoverSources.isEmpty) {
      return <Widget>[SliverToBoxAdapter(child: _buildNoSourceCard(context))];
    }
    if (_sourceErrorText != null) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildErrorCard(
            context,
            message: _sourceErrorText!,
            onRetry: _reloadCurrentSource,
          ),
        ),
      ];
    }
    if (_isLoadingCategories) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildLoadingCard(context, message: '正在解析发现分类...'),
        ),
      ];
    }
    if (_categories.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildInfoCard(context, message: '该源脚本没有可用的发现分类。'),
        ),
      ];
    }

    final category = _selectedCategory;
    if (category == null) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildInfoCard(context, message: '请选择分类以加载书单。'),
        ),
      ];
    }
    if (!category.isActionable) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildInfoCard(context, message: '当前分类不可点击，请切换其他分类。'),
        ),
      ];
    }
    if (_isLoadingBooks && _books.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildLoadingCard(context, message: '正在加载书单...'),
        ),
      ];
    }
    if (_bookErrorText != null && _books.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildErrorCard(
            context,
            message: _bookErrorText!,
            onRetry: () => _loadBooks(reset: true),
          ),
        ),
      ];
    }
    if (_books.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildInfoCard(context, message: '当前分类暂无书籍。'),
        ),
      ];
    }

    final footerCount = (_bookErrorText != null ? 1 : 0) + 1;
    return <Widget>[
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index < _books.length) {
            final book = _books[index];
            return _buildBookCard(context, book, listIndex: index);
          }

          var footerIndex = index - _books.length;
          if (_bookErrorText != null) {
            if (footerIndex == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildErrorCard(
                  context,
                  message: _bookErrorText!,
                  onRetry: () => _loadBooks(reset: false),
                  actionLabel: '重试翻页',
                ),
              );
            }
            footerIndex -= 1;
          }

          if (footerIndex == 0) {
            if (_isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_hasMore) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  onPressed: () => _loadBooks(reset: false),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('加载下一页'),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '已加载全部内容',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        }, childCount: _books.length + footerCount),
      ),
    ];
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCondensedPhoneDensity =
            AppLayout.useCondensedPhoneDensityForWidth(constraints.maxWidth);
        final cardVerticalPadding = useCondensedPhoneDensity ? 10.0 : 12.0;
        final cardHorizontalPadding = useCondensedPhoneDensity ? 10.0 : 12.0;
        final cardBottomMargin = useCondensedPhoneDensity ? 8.0 : 10.0;
        final coverWidth = useCondensedPhoneDensity ? 46.0 : 52.0;
        final coverHeight = useCondensedPhoneDensity ? 64.0 : 72.0;
        final introMaxLines = useCondensedPhoneDensity ? 1 : 2;
        final sectionGap = useCondensedPhoneDensity ? 5.0 : 6.0;
        final compactPill = useCondensedPhoneDensity;

        return Card(
          margin: EdgeInsets.only(bottom: cardBottomMargin),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openBookDetail(book, heroTag: heroTag),
            borderRadius: BorderRadius.circular(12),
            mouseCursor: SystemMouseCursors.click,
            hoverColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.06),
            focusColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.1),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: cardHorizontalPadding,
                vertical: cardVerticalPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _buildCoverPreview(
                    book.coverUrl,
                    title: book.title,
                    author: book.author,
                    heroTag: heroTag,
                    width: coverWidth,
                    height: coverHeight,
                  ),
                  SizedBox(width: useCondensedPhoneDensity ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: useCondensedPhoneDensity ? 3 : 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            _buildInfoPill(
                              context,
                              label: '来源',
                              value: _selectedSource?.name ?? book.sourceId,
                              compact: compactPill,
                            ),
                            if (author != null && author.isNotEmpty)
                              _buildInfoPill(
                                context,
                                label: '作者',
                                value: author,
                                compact: compactPill,
                              ),
                          ],
                        ),
                        if (latestChapter != null && latestChapter.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: sectionGap),
                            child: Text(
                              '最新章节: $latestChapter',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        if (intro != null && intro.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: sectionGap),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: useCondensedPhoneDensity ? 5 : 6,
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
                                maxLines: introMaxLines,
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
      },
    );
  }

  Widget _buildCoverPreview(
    String? coverUrl, {
    required String title,
    String? author,
    required String heroTag,
    required double width,
    required double height,
  }) {
    final trimmed = coverUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return Hero(
        tag: heroTag,
        child: _buildCoverFallback(
          title: title,
          author: author,
          width: width,
          height: height,
        ),
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      return Hero(
        tag: heroTag,
        child: _buildCoverFallback(
          title: title,
          author: author,
          width: width,
          height: height,
        ),
      );
    }

    return Hero(
      tag: heroTag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DiskCachedCoverImage(
          imageUrl: trimmed,
          width: width,
          height: height,
          fit: BoxFit.cover,
          fallback: _buildCoverFallback(
            title: title,
            author: author,
            width: width,
            height: height,
          ),
        ),
      ),
    );
  }

  Widget _buildCoverFallback({
    required String title,
    String? author,
    required double width,
    required double height,
  }) {
    return TextCoverPlaceholder(
      title: title,
      author: author,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(8),
    );
  }

  Widget _buildInfoPill(
    BuildContext context, {
    required String label,
    required String value,
    bool compact = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colorScheme.secondaryContainer,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 8,
          vertical: compact ? 3 : 4,
        ),
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
              '暂无支持发现的已启用源脚本',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '请先在源脚本页导入并启用支持 `discoverCategories + discoverBooks` 的源脚本。',
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
              onPressed: () => context.push('/source'),
              icon: const Icon(Icons.storage_rounded),
              label: const Text('前往源脚本页'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 96) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
      },
    );
  }

  Future<void> _loadSources() async {
    final requestToken = ++_sourceRequestToken;
    final previousSourceId = _selectedSource?.id ?? _rememberedSourceId;

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
        _syncSourceRuntimeCache(loadedSources);
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
      });

      unawaited(_persistSelectedSourceId(selected?.id));

      if (selected != null) {
        await _loadCategoriesForSource(
          selected,
          preserveCurrentCategory: false,
        );
      }

      unawaited(
        _probeSourceCompatibilityInBackground(
          _buildInitialProbeSources(
            sources: loadedSources,
            selectedSourceId: selected?.id,
          ),
        ),
      );
    } catch (error) {
      if (!mounted || requestToken != _sourceRequestToken) {
        return;
      }
      setState(() {
        _probingSourceIds.clear();
        _verifiedSourceIds.clear();
        _sourceParseErrorById.clear();
        _sourceBookErrorById.clear();
        _enabledSourceCount = 0;
        _discoverCapableCount = 0;
        _isLoadingSources = false;
        _sourceErrorText = _toReadableError(error, fallback: '加载发现源脚本失败');
      });
    }
  }

  void _syncSourceRuntimeCache(List<DiscoverSource> sources) {
    final sourceIdSet = sources.map((item) => item.id).toSet();
    _probingSourceIds.removeWhere((id) => !sourceIdSet.contains(id));
    _verifiedSourceIds.removeWhere((id) => !sourceIdSet.contains(id));
    _sourceParseErrorById.removeWhere((id, _) => !sourceIdSet.contains(id));
    _sourceBookErrorById.removeWhere((id, _) => !sourceIdSet.contains(id));
  }

  List<DiscoverSource> _buildInitialProbeSources({
    required List<DiscoverSource> sources,
    required String? selectedSourceId,
  }) {
    if (sources.isEmpty) {
      return const <DiscoverSource>[];
    }

    final output = <DiscoverSource>[];
    if (selectedSourceId != null && selectedSourceId.isNotEmpty) {
      for (final source in sources) {
        if (source.id == selectedSourceId) {
          output.add(source);
          break;
        }
      }
    }

    for (final source in sources) {
      if (output.length >= _backgroundProbeBatchLimit) {
        break;
      }
      if (output.any((item) => item.id == source.id)) {
        continue;
      }
      output.add(source);
    }
    return output;
  }

  Future<void> _probeSourceCompatibilityInBackground(
    List<DiscoverSource> sources,
  ) async {
    if (sources.isEmpty || !mounted) {
      return;
    }

    final token = ++_sourceProbeToken;
    setState(() {
      _probingSourceIds.addAll(sources.map((item) => item.id));
    });

    for (final source in sources) {
      if (!mounted || token != _sourceProbeToken) {
        return;
      }

      String? parseError;
      try {
        final categories = await _exploreService.parseCategories(
          source,
          evaluateScript: false,
        );
        if (!categories.any((item) => item.isActionable)) {
          parseError = '发现分类均不可点击。';
        }
      } catch (error) {
        parseError = _toReadableError(error, fallback: '发现分类解析失败');
      }

      if (!mounted || token != _sourceProbeToken) {
        return;
      }

      setState(() {
        _probingSourceIds.remove(source.id);
        _verifiedSourceIds.add(source.id);
        if (parseError == null || parseError.isEmpty) {
          _sourceParseErrorById.remove(source.id);
        } else {
          _sourceParseErrorById[source.id] = parseError;
        }
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
    DiscoverSource source, {
    required bool preserveCurrentCategory,
  }) async {
    final requestToken = ++_categoryRequestToken;
    final previousCategory = preserveCurrentCategory ? _selectedCategory : null;
    unawaited(_persistSelectedSourceId(source.id));

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
    });

    try {
      final parsedCategories = await _exploreService.parseCategories(
        source,
        evaluateScript: true,
        allowComplexJs: false,
      );
      if (!mounted || requestToken != _categoryRequestToken) {
        return;
      }

      final nextCategoryIndex = _resolveCategorySelection(
        categories: parsedCategories,
        previousCategory: previousCategory,
      );

      setState(() {
        _isLoadingCategories = false;
        _verifiedSourceIds.add(source.id);
        _sourceParseErrorById.remove(source.id);
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
        _verifiedSourceIds.add(source.id);
        final message = _toReadableError(error, fallback: '解析发现分类失败');
        _sourceErrorText = message;
        _sourceParseErrorById[source.id] = message;
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
        _isLoadingBooks = false;
        _isLoadingMore = false;
        _sourceBookErrorById.remove(source.id);
      });
    } catch (error) {
      if (!mounted || requestToken != _bookRequestToken) {
        return;
      }
      setState(() {
        final message = _toReadableError(error, fallback: '加载书单失败');
        _isLoadingBooks = false;
        _isLoadingMore = false;
        _hasMore = !reset;
        if (reset) {
          _books = const <Book>[];
        }
        _bookErrorText = message;
        _sourceBookErrorById[source.id] = message;
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

    final selected = await showModalBottomSheet<DiscoverSource>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => _SourcePickerSheet(
            sources: _discoverSources,
            selectedSourceId: _selectedSource?.id,
            checkingSourceIds: _probingSourceIds,
            parseErrorBySourceId: _sourceParseErrorById,
            bookErrorBySourceId: _sourceBookErrorById,
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

  Future<void> _handleSourceSwitch(int offset) async {
    await _runSourceSwitchAction(
      action: () => _switchSourceByOffset(offset),
      fallback: '切换源脚本失败',
    );
  }

  Future<void> _runSourceSwitchAction({
    required Future<void> Function() action,
    required String fallback,
  }) async {
    if (_isSwitchingSource || !mounted) {
      return;
    }
    _isSwitchingSource = true;
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _toReadableError(error, fallback: fallback);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      _isSwitchingSource = false;
    }
  }

  Future<void> _switchSourceByOffset(int offset) async {
    if (_isLoadingSources || _isLoadingCategories) {
      return;
    }

    final sources = List<DiscoverSource>.of(
      _discoverSources,
      growable: false,
    );
    if (sources.length < 2) {
      return;
    }

    final currentIndex = sources.indexWhere(
      (item) => item.id == _selectedSource?.id,
    );
    final baseIndex = currentIndex >= 0 ? currentIndex : 0;
    final nextIndex = _wrapIndex(baseIndex + offset, sources.length);
    if (nextIndex == baseIndex ||
        nextIndex < 0 ||
        nextIndex >= sources.length) {
      return;
    }

    for (var step = 1; step < sources.length; step++) {
      final candidateIndex = _wrapIndex(
        baseIndex + (offset * step),
        sources.length,
      );
      if (candidateIndex == baseIndex ||
          candidateIndex < 0 ||
          candidateIndex >= sources.length) {
        continue;
      }
      final candidate = sources[candidateIndex];
      if (_sourceParseErrorById.containsKey(candidate.id)) {
        continue;
      }
      await _loadCategoriesForSource(candidate, preserveCurrentCategory: false);
      return;
    }

    await _loadCategoriesForSource(
      sources[nextIndex],
      preserveCurrentCategory: false,
    );
  }

  Future<void> _persistSelectedSourceId(String? sourceId) async {
    _rememberedSourceId = sourceId;
    try {
      await _discoverPreferencesService.saveSelectedSourceId(sourceId);
    } catch (_) {
      // Preferences persistence failure should not block discover interaction.
    }
  }

  Future<void> _switchToNextHealthySource() async {
    await _runSourceSwitchAction(
      action: _switchToNextHealthySourceInternal,
      fallback: '切换到下一个可用源失败',
    );
  }

  Future<void> _switchToNextHealthySourceInternal() async {
    if (_isLoadingSources || _isLoadingCategories) {
      return;
    }

    final sources = List<DiscoverSource>.of(
      _discoverSources,
      growable: false,
    );
    if (sources.length < 2) {
      return;
    }

    final currentIndex = sources.indexWhere(
      (item) => item.id == _selectedSource?.id,
    );
    final baseIndex = currentIndex >= 0 ? currentIndex : 0;

    for (var step = 1; step < sources.length; step++) {
      final index = _wrapIndex(baseIndex + step, sources.length);
      if (index < 0 || index >= sources.length) {
        continue;
      }
      final candidate = sources[index];
      if (_sourceParseErrorById.containsKey(candidate.id)) {
        continue;
      }
      await _loadCategoriesForSource(candidate, preserveCurrentCategory: false);
      return;
    }

    final fallbackIndex = _wrapIndex(baseIndex + 1, sources.length);
    if (fallbackIndex < 0 || fallbackIndex >= sources.length) {
      return;
    }
    await _loadCategoriesForSource(
      sources[fallbackIndex],
      preserveCurrentCategory: false,
    );
  }

  int _wrapIndex(int value, int length) {
    final mod = value % length;
    return mod < 0 ? mod + length : mod;
  }

  _SourceRuntimeStatus _resolveSourceStatus(String? sourceId) {
    if (sourceId == null || sourceId.isEmpty) {
      return _SourceRuntimeStatus.unknown;
    }
    if (_probingSourceIds.contains(sourceId)) {
      return _SourceRuntimeStatus.checking;
    }
    if (_sourceParseErrorById.containsKey(sourceId)) {
      return _SourceRuntimeStatus.parseFailed;
    }
    if (_sourceBookErrorById.containsKey(sourceId)) {
      return _SourceRuntimeStatus.requestFailed;
    }
    if (!_verifiedSourceIds.contains(sourceId)) {
      return _SourceRuntimeStatus.unknown;
    }
    return _SourceRuntimeStatus.ready;
  }

  String? _sourceStatusDetail(String? sourceId) {
    if (sourceId == null || sourceId.isEmpty) {
      return null;
    }
    final parseError = _sourceParseErrorById[sourceId];
    if (parseError != null && parseError.isNotEmpty) {
      return parseError;
    }

    final bookError = _sourceBookErrorById[sourceId];
    if (bookError != null && bookError.isNotEmpty) {
      return bookError;
    }
    return null;
  }

  Widget _buildSourceStatusPill(
    BuildContext context,
    _SourceRuntimeStatus status,
  ) {
    final color = _sourceStatusColor(context, status);
    final icon = _sourceStatusIcon(status);
    final label = _sourceStatusLabel(status);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSwitchButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool compact = false,
  }) {
    final callback = _isLoadingCategories ? null : onPressed;
    final style = OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 10,
      ),
    );
    if (compact) {
      return OutlinedButton(
        key: key,
        onPressed: callback,
        style: style,
        child: Text(label),
      );
    }

    return OutlinedButton.icon(
      key: key,
      onPressed: callback,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  IconData _sourceStatusIcon(_SourceRuntimeStatus status) {
    switch (status) {
      case _SourceRuntimeStatus.ready:
        return Icons.check_circle_rounded;
      case _SourceRuntimeStatus.checking:
        return Icons.sync_rounded;
      case _SourceRuntimeStatus.parseFailed:
        return Icons.rule_folder_outlined;
      case _SourceRuntimeStatus.requestFailed:
        return Icons.wifi_off_rounded;
      case _SourceRuntimeStatus.unknown:
        return Icons.help_outline_rounded;
    }
  }

  String _sourceStatusLabel(_SourceRuntimeStatus status) {
    switch (status) {
      case _SourceRuntimeStatus.ready:
        return '可用';
      case _SourceRuntimeStatus.checking:
        return '检查中';
      case _SourceRuntimeStatus.parseFailed:
        return '脚本异常';
      case _SourceRuntimeStatus.requestFailed:
        return '访问失败';
      case _SourceRuntimeStatus.unknown:
        return '未识别';
    }
  }

  Color _sourceStatusColor(BuildContext context, _SourceRuntimeStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case _SourceRuntimeStatus.ready:
        return scheme.primary;
      case _SourceRuntimeStatus.checking:
        return scheme.tertiary;
      case _SourceRuntimeStatus.parseFailed:
        return scheme.error;
      case _SourceRuntimeStatus.requestFailed:
        return scheme.error;
      case _SourceRuntimeStatus.unknown:
        return scheme.onSurfaceVariant;
    }
  }

  DiscoverSource? _findSourceById(
    List<DiscoverSource> sources,
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
    final route = buildBookDetailRoute(
      bookId: book.id,
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      title: book.title,
      heroTag: heroTag,
    );
    context.push(route);
  }

  String _buildBookCoverHeroTag({required Book book, required int listIndex}) {
    return 'discover_cover_${book.sourceId}_${book.id}_${book.detailUrl.hashCode}_$listIndex';
  }

  String _buildSourceSummary(DiscoverSource source) {
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
    required this.checkingSourceIds,
    required this.parseErrorBySourceId,
    required this.bookErrorBySourceId,
  });

  final List<DiscoverSource> sources;
  final String? selectedSourceId;
  final Set<String> checkingSourceIds;
  final Map<String, String> parseErrorBySourceId;
  final Map<String, String> bookErrorBySourceId;

  @override
  State<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<_SourcePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  _SourceTypeFilter _sourceTypeFilter = _SourceTypeFilter.all;

  List<DiscoverSource> get _filteredSources {
    final keyword = _searchController.text.trim().toLowerCase();
    final result = widget.sources
        .where((source) {
          if (!_matchesSourceTypeFilter(source)) {
            return false;
          }
          if (keyword.isEmpty) {
            return true;
          }
          final name = source.name.toLowerCase();
          final baseUrl = source.baseUrl.toLowerCase();
          final host = _extractHost(source.baseUrl).toLowerCase();
          return name.contains(keyword) ||
              baseUrl.contains(keyword) ||
              host.contains(keyword);
        })
        .toList(growable: true);

    result.sort((left, right) {
      final leftStatus = _resolveSourceRuntimeStatus(
        sourceId: left.id,
        checkingSourceIds: widget.checkingSourceIds,
        parseErrorBySourceId: widget.parseErrorBySourceId,
        bookErrorBySourceId: widget.bookErrorBySourceId,
      );
      final rightStatus = _resolveSourceRuntimeStatus(
        sourceId: right.id,
        checkingSourceIds: widget.checkingSourceIds,
        parseErrorBySourceId: widget.parseErrorBySourceId,
        bookErrorBySourceId: widget.bookErrorBySourceId,
      );
      final statusCompare = _sourceStatusRank(
        leftStatus,
      ).compareTo(_sourceStatusRank(rightStatus));
      if (statusCompare != 0) {
        return statusCompare;
      }
      return left.name.compareTo(right.name);
    });

    return result;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSources = _filteredSources;
    final allCount = widget.sources.length;
    final novelCount = _countByType(_SourceTypeFilter.novel);
    final mangaCount = _countByType(_SourceTypeFilter.manga);
    final unknownCount = _countByType(_SourceTypeFilter.unknown);
    final horizontal = AppSpacing.pageHorizontal(context);
    final heightFactor = AppLayout.sheetHeightFactor(
      context,
      compact: 0.92,
      regular: 0.9,
      large: 0.85,
    );

    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 16),
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '切换发现源脚本',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '共 ${widget.sources.length} 个发现源脚本',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索源脚本名称或域名',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _buildTypeFilterChip(
                  key: const Key('discover_source_filter_all'),
                  filter: _SourceTypeFilter.all,
                  label: '全部',
                  count: allCount,
                ),
                _buildTypeFilterChip(
                  key: const Key('discover_source_filter_novel'),
                  filter: _SourceTypeFilter.novel,
                  label: '小说',
                  count: novelCount,
                ),
                _buildTypeFilterChip(
                  key: const Key('discover_source_filter_manga'),
                  filter: _SourceTypeFilter.manga,
                  label: '漫画',
                  count: mangaCount,
                ),
                _buildTypeFilterChip(
                  key: const Key('discover_source_filter_unknown'),
                  filter: _SourceTypeFilter.unknown,
                  label: '未知',
                  count: unknownCount,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  filteredSources.isEmpty
                      ? Center(
                        child: Text(
                          '没有匹配的源脚本',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                      : ListView.separated(
                        itemCount: filteredSources.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final source = filteredSources[index];
                          final selected = source.id == widget.selectedSourceId;
                          final status = _resolveSourceRuntimeStatus(
                            sourceId: source.id,
                            checkingSourceIds: widget.checkingSourceIds,
                            parseErrorBySourceId: widget.parseErrorBySourceId,
                            bookErrorBySourceId: widget.bookErrorBySourceId,
                          );
                          final statusColor = _sourceStatusColor(
                            context,
                            status,
                          );
                          return ListTile(
                            onTap: () => Navigator.of(context).pop(source),
                            selected: selected,
                            selectedTileColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.5),
                            title: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    source.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        selected
                                            ? Theme.of(
                                              context,
                                            ).textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            )
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildSourceTypePill(context, source),
                                const SizedBox(width: 6),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(
                                          _sourceStatusIcon(status),
                                          size: 12,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          _sourceStatusLabel(status),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: statusColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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

  Widget _buildTypeFilterChip({
    required Key key,
    required _SourceTypeFilter filter,
    required String label,
    required int count,
  }) {
    return ChoiceChip(
      key: key,
      label: Text('$label ($count)'),
      selected: _sourceTypeFilter == filter,
      onSelected: (_) {
        setState(() {
          _sourceTypeFilter = filter;
        });
      },
    );
  }

  Widget _buildSourceTypePill(BuildContext context, DiscoverSource source) {
    final typeColor = _sourceTypeColor(context, source);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          _sourceTypeLabel(source),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: typeColor),
        ),
      ),
    );
  }

  bool _matchesSourceTypeFilter(DiscoverSource source) {
    switch (_sourceTypeFilter) {
      case _SourceTypeFilter.all:
        return true;
      case _SourceTypeFilter.novel:
        return _isNovelSource(source);
      case _SourceTypeFilter.manga:
        return _isMangaSource(source);
      case _SourceTypeFilter.unknown:
        return _isUnknownSource(source);
    }
  }

  int _countByType(_SourceTypeFilter filter) {
    return widget.sources.where((source) {
      switch (filter) {
        case _SourceTypeFilter.all:
          return true;
        case _SourceTypeFilter.novel:
          return _isNovelSource(source);
        case _SourceTypeFilter.manga:
          return _isMangaSource(source);
        case _SourceTypeFilter.unknown:
          return _isUnknownSource(source);
      }
    }).length;
  }

  bool _isNovelSource(DiscoverSource source) {
    return source.sourceType == 0 && !source.isMangaSource;
  }

  bool _isMangaSource(DiscoverSource source) {
    return source.isMangaSource;
  }

  bool _isUnknownSource(DiscoverSource source) {
    return !_isNovelSource(source) && !_isMangaSource(source);
  }

  String _sourceTypeLabel(DiscoverSource source) {
    if (_isMangaSource(source)) {
      return '漫画';
    }
    if (_isNovelSource(source)) {
      return '小说';
    }
    return '未知';
  }

  Color _sourceTypeColor(BuildContext context, DiscoverSource source) {
    final scheme = Theme.of(context).colorScheme;
    if (_isMangaSource(source)) {
      return scheme.tertiary;
    }
    if (_isNovelSource(source)) {
      return scheme.primary;
    }
    return scheme.onSurfaceVariant;
  }

  String _buildSourceSummary(DiscoverSource source) {
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

_SourceRuntimeStatus _resolveSourceRuntimeStatus({
  required String sourceId,
  required Set<String> checkingSourceIds,
  required Map<String, String> parseErrorBySourceId,
  required Map<String, String> bookErrorBySourceId,
}) {
  if (sourceId.isEmpty) {
    return _SourceRuntimeStatus.unknown;
  }
  if (checkingSourceIds.contains(sourceId)) {
    return _SourceRuntimeStatus.checking;
  }
  if (parseErrorBySourceId.containsKey(sourceId)) {
    return _SourceRuntimeStatus.parseFailed;
  }
  if (bookErrorBySourceId.containsKey(sourceId)) {
    return _SourceRuntimeStatus.requestFailed;
  }
  return _SourceRuntimeStatus.ready;
}

int _sourceStatusRank(_SourceRuntimeStatus status) {
  switch (status) {
    case _SourceRuntimeStatus.ready:
      return 0;
    case _SourceRuntimeStatus.checking:
      return 1;
    case _SourceRuntimeStatus.requestFailed:
      return 2;
    case _SourceRuntimeStatus.parseFailed:
      return 3;
    case _SourceRuntimeStatus.unknown:
      return 4;
  }
}

IconData _sourceStatusIcon(_SourceRuntimeStatus status) {
  switch (status) {
    case _SourceRuntimeStatus.ready:
      return Icons.check_circle_rounded;
    case _SourceRuntimeStatus.checking:
      return Icons.sync_rounded;
    case _SourceRuntimeStatus.parseFailed:
      return Icons.rule_folder_outlined;
    case _SourceRuntimeStatus.requestFailed:
      return Icons.wifi_off_rounded;
    case _SourceRuntimeStatus.unknown:
      return Icons.help_outline_rounded;
  }
}

String _sourceStatusLabel(_SourceRuntimeStatus status) {
  switch (status) {
    case _SourceRuntimeStatus.ready:
      return '可用';
    case _SourceRuntimeStatus.checking:
      return '检查中';
    case _SourceRuntimeStatus.parseFailed:
      return '脚本异常';
    case _SourceRuntimeStatus.requestFailed:
      return '访问失败';
    case _SourceRuntimeStatus.unknown:
      return '未识别';
  }
}

Color _sourceStatusColor(BuildContext context, _SourceRuntimeStatus status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case _SourceRuntimeStatus.ready:
      return scheme.primary;
    case _SourceRuntimeStatus.checking:
      return scheme.tertiary;
    case _SourceRuntimeStatus.parseFailed:
      return scheme.error;
    case _SourceRuntimeStatus.requestFailed:
      return scheme.error;
    case _SourceRuntimeStatus.unknown:
      return scheme.onSurfaceVariant;
  }
}

double? _normalizeCategoryBasisPercent(ExploreCategoryItem item) {
  final rawBasis = item.style.layoutFlexBasisPercent;
  if (rawBasis == null || rawBasis <= 0) {
    return null;
  }

  final normalized = rawBasis > 1 ? rawBasis / 100 : rawBasis;
  return normalized.clamp(0.2, 1.0);
}

String? _buildCategoryStyleHintText(ExploreCategoryItem item) {
  final basisPercent = _normalizeCategoryBasisPercent(item);
  if (basisPercent != null) {
    final percent = (basisPercent * 100).round();
    return '建议宽度: $percent%';
  }

  final grow = item.style.layoutFlexGrow;
  if (grow != null && grow > 0) {
    final compactValue =
        grow == grow.roundToDouble()
            ? grow.toInt().toString()
            : grow.toString();
    return '布局权重: $compactValue';
  }

  return null;
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
          if (!entry.value.isActionable) {
            return false;
          }
          if (lowerKeyword.isEmpty) {
            return true;
          }
          return entry.value.title.toLowerCase().contains(lowerKeyword);
        })
        .toList(growable: false);

    final horizontal = AppSpacing.pageHorizontal(context);
    final heightFactor = AppLayout.sheetHeightFactor(
      context,
      compact: 0.92,
      regular: 0.9,
      large: 0.85,
    );

    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 16),
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '选择分类',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '共 ${indexed.length} 个可用分类',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
                            onTap: () => Navigator.of(context).pop(index),
                            selected: selected,
                            selectedTileColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.5),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  selected
                                      ? Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      )
                                      : null,
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
}
