import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/navigation/mobile_bottom_navigation_inset.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_border_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../app/widgets/runtime_feedback_card.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/source_health.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../book/presentation/book_detail_route.dart';
import '../application/discover_book_presentation_service.dart';
import '../application/discover_preferences_service.dart';
import '../application/explore_service.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../../source/application/source_health_service.dart';
import '../../source/application/source_runtime_scheduler_service.dart';
import '../../source/application/source_runtime_task_conflict_service.dart';
import '../providers.dart';

part 'discover_page_pickers.dart';

enum _SourceRuntimeStatus {
  unknown,
  checking,
  ready,
  parseFailed,
  requestFailed,
}

enum _SourceTypeFilter { all, novel, manga, unknown }

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({
    super.key,
    ExploreService? exploreService,
    DiscoverPreferencesService? discoverPreferencesService,
  }) : _exploreService = exploreService,
       _discoverPreferencesService = discoverPreferencesService;

  final ExploreService? _exploreService;
  final DiscoverPreferencesService? _discoverPreferencesService;

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage>
    with AutomaticKeepAliveClientMixin<DiscoverPage> {
  static const int _bookPageSize = 24;
  static const int _compactCategoryPreviewCount = 8;
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
  late final SourceHealthService _sourceHealthService;
  late final SourceRuntimeTaskConflictService _taskConflictService;
  late final SourceRuntimeSchedulerService _taskScheduler;
  late final DiscoverBookPresentationService _bookPresentationService;
  final ScrollController _booksScrollController = ScrollController();
  Timer? _sourceRefreshDebounce;

  bool _isLoadingSources = false;
  bool _isLoadingCategories = false;
  bool _isLoadingBooks = false;
  bool _isLoadingMore = false;
  int _enabledSourceCount = 0;
  int _discoverCapableCount = 0;

  List<DiscoverSource> _discoverSources = const <DiscoverSource>[];
  DiscoverSource? _selectedSource;
  List<ExploreCategoryItem> _categories = const <ExploreCategoryItem>[];
  int _selectedCategoryIndex = -1;
  List<Book> _books = const <Book>[];
  Map<String, SourceHealthSnapshot> _sourceHealthById =
      const <String, SourceHealthSnapshot>{};

  int _nextPage = 1;
  bool _hasMore = false;

  String? _sourceErrorText;
  String? _bookErrorText;

  int _sourceRequestToken = 0;
  int _categoryRequestToken = 0;
  int _bookRequestToken = 0;
  String? _rememberedSourceId;
  bool _isSwitchingSource = false;

  bool get _isDiscoverLoading {
    return _isLoadingSources ||
        _isLoadingCategories ||
        _isLoadingBooks ||
        _isLoadingMore;
  }

  bool get _isDiscoverBusy {
    return _isDiscoverLoading || _isSwitchingSource;
  }

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
    _exploreService =
        widget._exploreService ?? ref.read(discoverExploreServiceProvider);
    _discoverPreferencesService =
        widget._discoverPreferencesService ??
        ref.read(discoverPreferencesServiceProvider);
    _sourceHealthService = ref.read(discoverSourceHealthServiceProvider);
    _taskConflictService = ref.read(discoverTaskConflictServiceProvider);
    _taskScheduler = ref.read(discoverTaskSchedulerProvider);
    _bookPresentationService = ref.read(
      discoverBookPresentationServiceProvider,
    );
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
    ref.watch(activeAdvancedThemeProvider);
    ref.watch(coverGalleriesProvider);
    final backdrop = _resolvedBackdrop(context);
    final horizontal = AppSpacing.pageHorizontal(context);
    final platform = Theme.of(context).platform;
    final effectiveNavigationStyle = resolveAppNavigationStyle(
      ref.watch(appNavigationStylePreferenceProvider),
      isWeb: false,
      platform: platform,
    );
    final showNavigationLabels = ref.watch(
      appNavigationLabelVisibilityProvider,
    );
    final contentBottomInset = mobileBottomNavigationBodyInset(
      context,
      style: effectiveNavigationStyle,
      showNavigationLabels: showNavigationLabels,
    );
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('发现'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      body: LayoutBuilder(
        builder: (context, _) {
          final maxWidth = AppLayout.pageContentMaxWidth(
            context,
            maxWidth:
                AppLayout.discoverExpandedContentMaxWidth +
                AppLayout.discoverExpandedSidePanelWidth +
                12,
          );

          return DecoratedBox(
            decoration: buildAdvancedThemeBackdropDecoration(backdrop),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontal),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (AppLayout.isExpandedWidth(constraints.maxWidth)) {
                        return _buildWideLayout(
                          context,
                          sidePanelWidth:
                              AppLayout.discoverExpandedSidePanelWidth,
                          maxContentWidth:
                              AppLayout.discoverExpandedContentMaxWidth,
                          topContentPadding: topInset + 12,
                          bottomContentPadding: 12 + contentBottomInset,
                        );
                      }
                      if (constraints.maxWidth >=
                          AppLayout.railBreakpointWidth) {
                        return _buildWideLayout(
                          context,
                          sidePanelWidth:
                              AppLayout.discoverMediumSidePanelWidth,
                          maxContentWidth:
                              AppLayout.discoverMediumContentMaxWidth,
                          topContentPadding: topInset + 12,
                          bottomContentPadding: 12 + contentBottomInset,
                        );
                      }
                      return _buildCompactLayout(
                        context,
                        topContentPadding: topInset + 12,
                        bottomContentPadding: 12 + contentBottomInset,
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  ResolvedAdvancedThemePalette _resolvedPalette(BuildContext context) {
    return resolveAdvancedThemePalette(
      Theme.of(context).colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
  }

  ResolvedAdvancedThemeBackdrop _resolvedBackdrop(BuildContext context) {
    return resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
  }

  RoundedRectangleBorder _cardShape(BuildContext context) {
    final palette = _resolvedPalette(context);
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: resolveAppBorderSide(
        Theme.of(context).colorScheme,
        baseColor: palette.cardBorderColor,
        containerColor: palette.cardColor,
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

  Future<void> _bootstrapDiscoverState() async {
    List<DiscoverSource> cachedSources = const <DiscoverSource>[];
    List<ExploreCategoryItem> cachedCategories = const <ExploreCategoryItem>[];
    try {
      _rememberedSourceId =
          await _discoverPreferencesService.loadSelectedSourceId();
    } catch (_) {
      _rememberedSourceId = null;
    }

    try {
      cachedSources = await _discoverPreferencesService.loadSourceSnapshot();
    } catch (_) {
      cachedSources = const <DiscoverSource>[];
    }

    if (cachedSources.isNotEmpty) {
      cachedSources = List<DiscoverSource>.from(cachedSources, growable: false)
        ..sort((left, right) {
          final groupCompare = (left.group ?? '').compareTo(right.group ?? '');
          if (groupCompare != 0) {
            return groupCompare;
          }
          return left.name.compareTo(right.name);
        });
      final cachedSelected = _findSourceById(
        cachedSources,
        _rememberedSourceId,
      );
      if (cachedSelected != null) {
        try {
          cachedCategories = await _discoverPreferencesService
              .loadCategorySnapshot(cachedSelected.id);
        } catch (_) {
          cachedCategories = const <ExploreCategoryItem>[];
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _discoverSources = cachedSources;
        _sourceHealthById = _captureSourceHealth(cachedSources);
        _selectedSource = cachedSelected;
        _categories = cachedCategories;
        _selectedCategoryIndex = _resolveCategorySelection(
          categories: cachedCategories,
          previousCategory: null,
        );
        _books = const <Book>[];
        _nextPage = 1;
        _hasMore = false;
      });
    }

    if (!mounted) {
      return;
    }
    await _loadSources();
  }

  Widget _buildCompactLayout(
    BuildContext context, {
    required double topContentPadding,
    required double bottomContentPadding,
  }) {
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
            SliverToBoxAdapter(child: SizedBox(height: topContentPadding)),
            SliverToBoxAdapter(child: _buildSourceSelectorCard(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(child: _buildCategoryStripCard(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ..._buildBooksPaneSlivers(context),
            SliverToBoxAdapter(child: SizedBox(height: bottomContentPadding)),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context, {
    required double sidePanelWidth,
    required double maxContentWidth,
    required double topContentPadding,
    required double bottomContentPadding,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        topContentPadding,
        0,
        bottomContentPadding,
      ),
      child: Row(
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
                      slivers: <Widget>[
                        ..._buildBooksPaneSlivers(context),
                        SliverToBoxAdapter(
                          child: SizedBox(height: bottomContentPadding),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 420) {
          final categoryHeight = math.max(220.0, constraints.maxHeight * 0.72);
          return SingleChildScrollView(
            child: Column(
              children: <Widget>[
                _buildSourceSelectorCard(context),
                const SizedBox(height: 12),
                SizedBox(
                  height: categoryHeight,
                  child: _buildCategoryPanelCard(context),
                ),
              ],
            ),
          );
        }

        return Column(
          children: <Widget>[
            _buildSourceSelectorCard(context),
            const SizedBox(height: 12),
            Expanded(child: _buildCategoryPanelCard(context)),
          ],
        );
      },
    );
  }

  Widget _buildSourceSelectorCard(BuildContext context) {
    final source = _selectedSource;
    final summary =
        source == null
            ? (_isLoadingSources ? '正在加载可用书源...' : '请选择书源')
            : _buildSourceSummary(source);
    final categoryName = _selectedCategory?.title ?? '未选分类';
    final status = _resolveSourceStatus(source?.id);
    final statusDetail = _sourceStatusDetail(source?.id);
    final palette = _resolvedPalette(context);
    final textTheme = Theme.of(context).textTheme;
    final hasMultipleSources = _discoverSources.length > 1;

    return Card(
      color: palette.cardColor,
      shape: _cardShape(context),
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
                    '当前书源',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.textSecondaryColor,
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  key: const Key('discover_source_switch_button'),
                  onPressed:
                      _isDiscoverBusy || _discoverSources.isEmpty
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
              source?.name ?? '未选择书源',
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
                color: palette.textSecondaryColor,
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
                  color: palette.elevatedSurfaceColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '分类：$categoryName · 书籍：${_books.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: palette.textSecondaryColor,
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

    final actionableEntries = _actionableCategoryEntries;
    if (actionableEntries.isEmpty) {
      return _buildInfoCard(context, message: '该书源暂无可点击分类。');
    }

    final previewCount = math.min(
      actionableEntries.length,
      _compactCategoryPreviewCount,
    );
    return Card(
      color: _resolvedPalette(context).cardColor,
      shape: _cardShape(context),
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
    final palette = _resolvedPalette(context);
    final isSelected = index == _selectedCategoryIndex;
    if (item.isActionable) {
      return Tooltip(
        message: item.title,
        waitDuration: const Duration(milliseconds: 250),
        child: ChoiceChip(
          label: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: palette.primaryContainerColor,
          side: BorderSide(
            color: isSelected ? palette.primaryColor : palette.cardBorderColor,
          ),
          labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: palette.textPrimaryColor,
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
        ).textTheme.labelLarge?.copyWith(color: palette.textSecondaryColor),
        side: BorderSide(color: palette.cardBorderColor),
        visualDensity: VisualDensity.compact,
        backgroundColor: palette.elevatedSurfaceColor,
      ),
    );
  }

  Widget _buildCategoryPanelCard(BuildContext context) {
    if (_isLoadingSources && _discoverSources.isEmpty) {
      return _buildLoadingCard(context, message: '正在加载发现书源...');
    }
    if (_discoverSources.isEmpty) {
      return _buildInfoCard(context, message: '暂无支持发现的书源。');
    }
    final actionableCount = _actionableCategoryEntries.length;

    return Card(
      color: _resolvedPalette(context).cardColor,
      shape: _cardShape(context),
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
        message: '该书源暂无可点击分类。',
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
        final palette = _resolvedPalette(context);
        final textColor =
            selected
                ? palette.textPrimaryColor
                : Theme.of(context).colorScheme.onSurface;

        return Material(
          color: selected ? palette.primaryContainerColor : Colors.transparent,
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
                      color: palette.textPrimaryColor,
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
          child: _buildLoadingCard(context, message: '正在加载发现书源...'),
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
          child: _buildInfoCard(context, message: '该书源没有可用的发现分类。'),
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
    final palette = _resolvedPalette(context);
    final latestChapter = _normalizeSnippet(book.latestChapter);
    final heroTag = _buildBookCoverHeroTag(book: book, listIndex: listIndex);

    return FutureBuilder<BookMetadataPresentation>(
      future: _resolvePresentedBook(book),
      builder: (context, snapshot) {
        final presented = snapshot.data;
        final displayTitle =
            presented?.displayTitle.trim().isNotEmpty == true
                ? presented!.displayTitle
                : book.title;
        final displayAuthor = _normalizeSnippet(
          presented?.displayAuthor ?? book.author,
        );
        final displayIntro = _normalizeSnippet(
          presented?.displayIntro ?? book.intro,
        );
        final displayCover = presented?.displayCover ?? book.coverUrl;
        return LayoutBuilder(
          builder: (context, constraints) {
            final useCondensedPhoneDensity =
                AppLayout.useCondensedPhoneDensityForWidth(
                  constraints.maxWidth,
                );
            final cardVerticalPadding = useCondensedPhoneDensity ? 10.0 : 12.0;
            final cardHorizontalPadding =
                useCondensedPhoneDensity ? 10.0 : 12.0;
            final cardBottomMargin = useCondensedPhoneDensity ? 8.0 : 10.0;
            final coverWidth = useCondensedPhoneDensity ? 46.0 : 52.0;
            final coverHeight = useCondensedPhoneDensity ? 64.0 : 72.0;
            final introMaxLines = useCondensedPhoneDensity ? 1 : 2;
            final sectionGap = useCondensedPhoneDensity ? 5.0 : 6.0;
            final compactPill = useCondensedPhoneDensity;

            return Card(
              color: palette.cardColor,
              shape: _cardShape(context),
              margin: EdgeInsets.only(bottom: cardBottomMargin),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openBookDetail(book, heroTag: heroTag),
                borderRadius: BorderRadius.circular(12),
                mouseCursor: SystemMouseCursors.click,
                hoverColor: palette.primaryColor.withValues(alpha: 0.06),
                focusColor: palette.primaryColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: cardHorizontalPadding,
                    vertical: cardVerticalPadding,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _buildCoverPreview(
                        realCoverUrl: displayCover,
                        title: displayTitle,
                        author: displayAuthor,
                        bookId: book.id,
                        sourceId: book.sourceId,
                        detailUrl: book.detailUrl,
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
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: palette.cardTextColor,
                              ),
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
                                if (displayAuthor != null &&
                                    displayAuthor.isNotEmpty)
                                  _buildInfoPill(
                                    context,
                                    label: '作者',
                                    value: displayAuthor,
                                    compact: compactPill,
                                  ),
                              ],
                            ),
                            if (latestChapter != null &&
                                latestChapter.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: sectionGap),
                                child: Text(
                                  '最新章节: $latestChapter',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            if (displayIntro != null && displayIntro.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: sectionGap),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: useCondensedPhoneDensity ? 5 : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.elevatedSurfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    displayIntro,
                                    maxLines: introMaxLines,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: palette.textSecondaryColor,
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
                        color: palette.textSecondaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<BookMetadataPresentation> _resolvePresentedBook(Book book) async {
    return _bookPresentationService.resolvePresentedBook(book);
  }

  Widget _buildCoverPreview({
    String? realCoverUrl,
    required String title,
    String? author,
    String? bookId,
    String? sourceId,
    String? detailUrl,
    required String heroTag,
    required double width,
    required double height,
  }) {
    final resolvedCover = resolveBookCover(
      realCoverUrl: realCoverUrl,
      activeTheme: ref.read(activeAdvancedThemeProvider).valueOrNull,
      galleries: ref.read(coverGalleriesProvider).valueOrNull ?? const [],
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );

    return Hero(
      tag: heroTag,
      child: ResolvedBookCoverView(
        cover: resolvedCover,
        title: title,
        author: author,
        width: width,
        height: height,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildInfoPill(
    BuildContext context, {
    required String label,
    required String value,
    bool compact = false,
  }) {
    final palette = _resolvedPalette(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: palette.noticeSurfaceColor,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 8,
          vertical: compact ? 3 : 4,
        ),
        child: Text(
          '$label: $value',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: palette.noticeAccentColor),
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context, {required String message}) {
    return RuntimeFeedbackCard(
      title: '正在加载',
      message: message,
      tone: RuntimeFeedbackTone.loading,
      compact: true,
    );
  }

  Widget _buildErrorCard(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
    String actionLabel = '重试',
  }) {
    return RuntimeFeedbackCard(
      title: '加载失败',
      message: message,
      tone: RuntimeFeedbackTone.error,
      compact: true,
      actions: [
        FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(actionLabel),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String message}) {
    return RuntimeFeedbackCard(
      title: '提示',
      message: message,
      tone: RuntimeFeedbackTone.info,
      compact: true,
    );
  }

  Widget _buildNoSourceCard(BuildContext context) {
    final palette = _resolvedPalette(context);
    return Card(
      color: palette.cardColor,
      shape: _cardShape(context),
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
              '请先在书源页导入并启用声明了 `discover` 能力、且实现 `discoverCategories + discoverBooks` 的书源。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_enabledSourceCount > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '当前已启用：$_enabledSourceCount，支持发现：$_discoverCapableCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.textSecondaryColor,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/source'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.primaryColor,
                foregroundColor: palette.buttonTextColor,
              ),
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
                color: _resolvedPalette(context).textSecondaryColor,
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
                Icon(icon, color: _resolvedPalette(context).textSecondaryColor),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _resolvedPalette(context).textSecondaryColor,
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
        _enabledSourceCount = summary.enabledSourceCount;
        _discoverCapableCount = summary.discoverCapableCount;
        _discoverSources = loadedSources;
        _sourceHealthById = _captureSourceHealth(loadedSources);
        _selectedSource = selected;
        _isLoadingSources = false;
        _categories = const <ExploreCategoryItem>[];
        _selectedCategoryIndex = -1;
        _books = const <Book>[];
        _nextPage = 1;
        _hasMore = false;
      });

      unawaited(_persistSelectedSourceId(selected?.id));
      unawaited(_discoverPreferencesService.saveSourceSnapshot(loadedSources));

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
        _sourceHealthById = const <String, SourceHealthSnapshot>{};
        _isLoadingSources = false;
        _sourceErrorText = _toReadableError(error, fallback: '加载发现书源失败');
      });
    }
  }

  Map<String, SourceHealthSnapshot> _captureSourceHealth(
    List<DiscoverSource> sources,
  ) {
    final snapshots = <String, SourceHealthSnapshot>{};
    for (final source in sources) {
      snapshots[source.id] = _sourceHealthService.snapshotFor(source.id);
    }
    return Map<String, SourceHealthSnapshot>.unmodifiable(snapshots);
  }

  void _refreshSourceHealth(String sourceId) {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return;
    }
    _sourceHealthById = <String, SourceHealthSnapshot>{
      ..._sourceHealthById,
      normalized: _sourceHealthService.snapshotFor(normalized),
    };
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
    _cancelBackgroundRefreshConflictForSource(source.id);
    final lease = await _taskScheduler.acquire(
      scene: SourceRuntimeSchedulerScene.discover,
      conflictKeys: <String>[
        _taskConflictService.conflictKeyForSource(source.id),
      ],
    );
    if (lease == null) {
      return;
    }
    final requestToken = ++_categoryRequestToken;
    final previousCategory = preserveCurrentCategory ? _selectedCategory : null;
    var shouldLoadBooks = false;
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
        _refreshSourceHealth(source.id);
        _categories = parsedCategories;
        _selectedCategoryIndex = nextCategoryIndex;
      });
      unawaited(
        _discoverPreferencesService.saveCategorySnapshot(
          source.id,
          parsedCategories,
        ),
      );

      if (nextCategoryIndex >= 0 &&
          nextCategoryIndex < parsedCategories.length &&
          parsedCategories[nextCategoryIndex].isActionable) {
        shouldLoadBooks = true;
      }
    } catch (error) {
      if (!mounted || requestToken != _categoryRequestToken) {
        return;
      }
      setState(() {
        _isLoadingCategories = false;
        final message = _toReadableError(error, fallback: '解析发现分类失败');
        _sourceErrorText = message;
        _refreshSourceHealth(source.id);
      });
    } finally {
      lease.release();
    }

    if (shouldLoadBooks) {
      await _loadBooks(reset: true);
    }
  }

  Future<void> _loadBooks({required bool reset}) async {
    final source = _selectedSource;
    final category = _selectedCategory;
    if (source == null || category == null || !category.isActionable) {
      return;
    }
    _cancelBackgroundRefreshConflictForSource(source.id);
    final lease = await _taskScheduler.acquire(
      scene: SourceRuntimeSchedulerScene.discover,
      conflictKeys: <String>[
        _taskConflictService.conflictKeyForSource(source.id),
      ],
    );
    if (lease == null) {
      return;
    }
    if (!reset && (_isLoadingMore || _isLoadingBooks || !_hasMore)) {
      lease.release();
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
        _refreshSourceHealth(source.id);
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
        _refreshSourceHealth(source.id);
      });
    } finally {
      lease.release();
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
    if (_discoverSources.isEmpty || _isDiscoverBusy) {
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
            healthBySourceId: _sourceHealthById,
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
      fallback: '切换书源失败',
    );
  }

  Future<void> _runSourceSwitchAction({
    required Future<void> Function() action,
    required String fallback,
  }) async {
    if (_isSwitchingSource || _isDiscoverLoading || !mounted) {
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
    if (_isDiscoverLoading) {
      return;
    }

    final sources = List<DiscoverSource>.of(_discoverSources, growable: false);
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
      if (_resolveSourceStatus(candidate.id) ==
          _SourceRuntimeStatus.parseFailed) {
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
    if (_isDiscoverLoading) {
      return;
    }

    final sources = List<DiscoverSource>.of(_discoverSources, growable: false);
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
      if (_resolveSourceStatus(candidate.id) ==
          _SourceRuntimeStatus.parseFailed) {
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

  void _cancelBackgroundRefreshConflictForSource(String sourceId) {
    final conflictKey = _taskConflictService.conflictKeyForSource(sourceId);
    if (conflictKey.isEmpty) {
      return;
    }
    _taskConflictService.cancelBackgroundWorkFor(
      conflictKey: conflictKey,
      byScene: SourceRuntimeConflictScene.discover,
    );
  }

  _SourceRuntimeStatus _resolveSourceStatus(String? sourceId) {
    if (sourceId == null || sourceId.isEmpty) {
      return _SourceRuntimeStatus.unknown;
    }
    if (sourceId == _selectedSource?.id &&
        (_isLoadingCategories || _isLoadingBooks || _isLoadingMore)) {
      return _SourceRuntimeStatus.checking;
    }
    final snapshot = _sourceHealthById[sourceId];
    if (snapshot == null) {
      return _SourceRuntimeStatus.unknown;
    }
    return _sourceRuntimeStatusFromHealth(snapshot);
  }

  String? _sourceStatusDetail(String? sourceId) {
    if (sourceId == null || sourceId.isEmpty) {
      return null;
    }
    final status = _resolveSourceStatus(sourceId);
    if (status == _SourceRuntimeStatus.ready ||
        status == _SourceRuntimeStatus.checking ||
        status == _SourceRuntimeStatus.unknown) {
      return null;
    }
    final snapshot = _sourceHealthById[sourceId];
    if (snapshot == null) {
      return null;
    }
    final detail = snapshot.lastFailureReason?.trim();
    return detail == null || detail.isEmpty ? null : detail;
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
        return '书源异常';
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
      author: book.author,
      coverUrl: book.coverUrl,
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

_SourceRuntimeStatus _resolveSourceRuntimeStatus({
  SourceHealthSnapshot? snapshot,
}) {
  if (snapshot == null) {
    return _SourceRuntimeStatus.unknown;
  }
  return _sourceRuntimeStatusFromHealth(snapshot);
}

_SourceRuntimeStatus _sourceRuntimeStatusFromHealth(
  SourceHealthSnapshot snapshot,
) {
  switch (snapshot.level) {
    case SourceHealthLevel.healthy:
      return _SourceRuntimeStatus.ready;
    case SourceHealthLevel.unchecked:
      return _SourceRuntimeStatus.unknown;
    case SourceHealthLevel.warning:
    case SourceHealthLevel.risky:
    case SourceHealthLevel.unavailable:
      final failureKind = snapshot.lastFailureKind;
      if (failureKind == SourceHealthFailureKind.parser ||
          failureKind == SourceHealthFailureKind.disabled) {
        return _SourceRuntimeStatus.parseFailed;
      }
      return _SourceRuntimeStatus.requestFailed;
  }
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
      return '书源异常';
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
