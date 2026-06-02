import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../core/network/api_client.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../application/discover_source_provider.dart';
import '../domain/discover_source_summary.dart';

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchKeyword = '';
  String? _expandedSourceId;
  Timer? _searchDebounce;
  String _remoteSearchKeyword = '';
  AsyncValue<List<DiscoverSourceSummary>>? _remoteSearchAsync;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _searchKeyword.trim().isNotEmpty) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 360) {
      ref.read(discoverSourcePagerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final activeAdvancedTheme = ref.watch(activeAdvancedThemeProvider);
    final activeTheme = activeAdvancedTheme.valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      theme.colorScheme,
      activeTheme,
    );
    final palette = resolveAdvancedThemePalette(theme.colorScheme, activeTheme);
    final sourcesAsync = ref.watch(discoverSourcePagerProvider);
    final horizontal = metrics.pagePadding;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final isWide = AppLayout.isMediumUp(context);
    final topInset =
        isWide ? 0.0 : MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar:
          isWide
              ? null
              : AppBar(
                title: const Text('发现'),
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                actions: [
                  IconButton(
                    tooltip: '刷新',
                    onPressed: () {
                      _searchDebounce?.cancel();
                      _searchController.clear();
                      setState(() {
                        _searchKeyword = '';
                        _expandedSourceId = null;
                        _remoteSearchKeyword = '';
                        _remoteSearchAsync = null;
                      });
                      ref.read(discoverSourcePagerProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
      body: DecoratedBox(
        decoration: buildAdvancedThemeBackdropDecoration(backdrop),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppLayout.pageContentMaxWidth(
                context,
                maxWidth:
                    isWide
                        ? AppLayout.discoverExpandedContentMaxWidth
                        : AppLayout.discoverMediumContentMaxWidth,
              ),
            ),
            child: _buildBody(
              context: context,
              sourcesAsync: sourcesAsync,
              palette: palette,
              isWide: isWide,
              horizontal: horizontal,
              topInset: topInset,
              bottomSafe: bottomSafe,
              metrics: metrics,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AsyncValue<DiscoverSourcePagerState> sourcesAsync,
    required ResolvedAdvancedThemePalette palette,
    required bool isWide,
    required double horizontal,
    required double topInset,
    required double bottomSafe,
    required AppAdaptiveMetrics metrics,
  }) {
    final theme = Theme.of(context);

    if (sourcesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sourcesAsync.hasError) {
      final failure =
          sourcesAsync.error is ApiException
              ? (sourcesAsync.error as ApiException).gatewayFailure
              : null;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              failure?.message ?? '加载失败',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              failure == null
                  ? '请点击刷新重试'
                  : '${failure.displayCode}：${failure.displayHint}',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final pager = sourcesAsync.valueOrNull;
    final sources = pager?.items ?? const <DiscoverSourceSummary>[];
    final normalizedKeyword = _searchKeyword.trim();
    final localFilteredSources = _filterSources(sources);
    final showRemoteResults =
        normalizedKeyword.isNotEmpty &&
        localFilteredSources.isEmpty &&
        _remoteSearchKeyword == normalizedKeyword;
    final remoteSearchAsync = showRemoteResults ? _remoteSearchAsync : null;
    final filteredSources =
        remoteSearchAsync?.valueOrNull ?? localFilteredSources;
    final isRemoteSearchLoading = remoteSearchAsync?.isLoading == true;
    final remoteSearchError = remoteSearchAsync?.hasError == true;

    if (sources.isEmpty && normalizedKeyword.isEmpty) {
      return Center(
        child: AppEmptyStateCard(
          icon: Icons.travel_explore_rounded,
          title: '暂无书源',
          description: '服务器暂未返回书源列表',
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 顶部间距 + 搜索框
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topInset + 10,
            horizontal,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _buildSearchBar(
              context,
              palette,
              counterText: _sourceCounterText(
                pager: pager,
                filteredCount: filteredSources.length,
                isRemoteResult: remoteSearchAsync?.hasValue == true,
              ),
            ),
          ),
        ),
        // 书源列表
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            12,
            horizontal,
            bottomSafe + metrics.sectionGap,
          ),
          sliver: SliverList.builder(
            itemCount: filteredSources.length,
            itemBuilder: (context, index) {
              final source = filteredSources[index];
              return AppFadeSlideTransition(
                delay: Duration(milliseconds: (index % 10) * 18),
                child: _SourceRow(
                  source: source,
                  isExpanded: _expandedSourceId == source.id,
                  palette: palette,
                  onTap: () {
                    setState(() {
                      _expandedSourceId =
                          _expandedSourceId == source.id ? null : source.id;
                    });
                  },
                  onCategoryTap: (sourceContext, loadedSource, category) {
                    _openCategoryWithReveal(
                      sourceContext,
                      source: loadedSource,
                      category: category,
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (isRemoteSearchLoading)
          const SliverPadding(
            padding: EdgeInsets.only(top: 36),
            sliver: SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (remoteSearchError)
          SliverPadding(
            padding: const EdgeInsets.only(top: 36),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: AppEmptyStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: '服务器搜索失败',
                  description: '本地未找到匹配书源，远程查询暂时不可用',
                  actionLabel: '重试',
                  onAction: () => _startRemoteSearch(normalizedKeyword),
                ),
              ),
            ),
          ),
        if (normalizedKeyword.isEmpty)
          SliverToBoxAdapter(
            child: _LoadMoreFooter(
              state: pager,
              onRetry:
                  () =>
                      ref.read(discoverSourcePagerProvider.notifier).loadMore(),
            ),
          ),
        // 无搜索结果提示
        if (filteredSources.isEmpty &&
            normalizedKeyword.isNotEmpty &&
            !isRemoteSearchLoading &&
            !remoteSearchError)
          SliverPadding(
            padding: EdgeInsets.only(top: 48),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '没有找到 "$normalizedKeyword"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    ResolvedAdvancedThemePalette palette, {
    required String counterText,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = palette.cardBorderColor.withValues(alpha: 0.42);
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.cardColor.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              Icons.search_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                cursorColor: colorScheme.primary,
                decoration: InputDecoration(
                  hintText: '搜索书源名称',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
                textInputAction: TextInputAction.search,
                onChanged: _handleSearchChanged,
                onSubmitted: _handleSearchSubmitted,
              ),
            ),
            const SizedBox(width: 8),
            _SourceCountBadge(text: counterText),
            if (_searchKeyword.isNotEmpty)
              IconButton(
                tooltip: '清空',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  setState(() {
                    _searchKeyword = '';
                    _remoteSearchKeyword = '';
                    _remoteSearchAsync = null;
                    _searchController.clear();
                  });
                },
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchKeyword = value;
    });
    _scheduleRemoteSearchIfNeeded(value);
  }

  void _handleSearchSubmitted(String value) {
    final keyword = value.trim();
    if (keyword.isEmpty) {
      return;
    }
    final localHits = _filterSources(
      ref.read(discoverSourcePagerProvider).valueOrNull?.items ??
          const <DiscoverSourceSummary>[],
      keyword: keyword,
    );
    if (localHits.isEmpty) {
      _startRemoteSearch(keyword);
    }
  }

  void _scheduleRemoteSearchIfNeeded(String value) {
    _searchDebounce?.cancel();
    final keyword = value.trim();
    if (keyword.isEmpty) {
      setState(() {
        _remoteSearchKeyword = '';
        _remoteSearchAsync = null;
      });
      return;
    }
    final localHits = _filterSources(
      ref.read(discoverSourcePagerProvider).valueOrNull?.items ??
          const <DiscoverSourceSummary>[],
      keyword: keyword,
    );
    if (localHits.isNotEmpty) {
      setState(() {
        _remoteSearchKeyword = '';
        _remoteSearchAsync = null;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _startRemoteSearch(keyword),
    );
  }

  void _startRemoteSearch(String keyword) {
    final normalized = keyword.trim();
    if (normalized.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _remoteSearchKeyword = normalized;
      _remoteSearchAsync = const AsyncLoading<List<DiscoverSourceSummary>>();
    });
    ref
        .read(discoverSourcePagerProvider.notifier)
        .searchRemote(normalized)
        .then((items) {
          if (!mounted || _searchKeyword.trim() != normalized) {
            return;
          }
          setState(() {
            _remoteSearchAsync = AsyncData(items);
          });
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!mounted || _searchKeyword.trim() != normalized) {
            return;
          }
          setState(() {
            _remoteSearchAsync = AsyncError<List<DiscoverSourceSummary>>(
              error,
              stackTrace,
            );
          });
        });
  }

  List<DiscoverSourceSummary> _filterSources(
    List<DiscoverSourceSummary> sources, {
    String? keyword,
  }) {
    final normalizedKeyword = (keyword ?? _searchKeyword).trim();
    if (normalizedKeyword.isEmpty) {
      return sources;
    }
    return sources.where((source) {
      final needle = normalizedKeyword.toLowerCase();
      return source.name.toLowerCase().contains(needle) ||
          (source.sourceUrl ?? '').toLowerCase().contains(needle);
    }).toList();
  }

  String _sourceCounterText({
    required DiscoverSourcePagerState? pager,
    required int filteredCount,
    required bool isRemoteResult,
  }) {
    if (isRemoteResult) {
      return '远程 $filteredCount';
    }
    final loaded = pager?.loadedCount ?? 0;
    final total = pager?.total ?? loaded;
    if (_searchKeyword.trim().isNotEmpty) {
      return '$filteredCount / 已载 $loaded';
    }
    if (total > loaded) {
      return '已载 $loaded / $total';
    }
    return '共 $loaded 个';
  }

  Future<void> _openCategoryWithReveal(
    BuildContext sourceContext, {
    required DiscoverSourceSummary source,
    required DiscoverSourceCategory category,
  }) async {
    final route =
        '/discover/source/${Uri.encodeComponent(source.id)}/category/${Uri.encodeComponent(category.id)}';
    final overlay = CircularThemeRevealOverlay.of(sourceContext);
    if (overlay == null) {
      await context.push(route);
      return;
    }
    final center = CircularThemeRevealOverlay.getCenterFromContext(
      sourceContext,
    );
    await overlay.startTransition(
      center: center,
      reverse: false,
      onThemeChange: () {
        context.push(route);
      },
    );
  }
}

class _SourceCountBadge extends StatelessWidget {
  const _SourceCountBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onRetry});

  final DiscoverSourcePagerState? state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final current = state;
    if (current == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    if (current.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text('正在加载更多书源...', style: textStyle),
            ],
          ),
        ),
      );
    }

    if (current.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('加载更多失败，点击重试'),
          ),
        ),
      );
    }

    if (!current.hasMore && current.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Center(child: Text('已加载全部书源', style: textStyle)),
      );
    }

    return const SizedBox(height: 24);
  }
}

typedef _DiscoverCategoryTap =
    void Function(
      BuildContext sourceContext,
      DiscoverSourceSummary source,
      DiscoverSourceCategory category,
    );

class _SourceRow extends ConsumerWidget {
  const _SourceRow({
    required this.source,
    required this.isExpanded,
    required this.palette,
    required this.onTap,
    required this.onCategoryTap,
  });

  final DiscoverSourceSummary source;
  final bool isExpanded;
  final ResolvedAdvancedThemePalette palette;
  final VoidCallback onTap;
  final _DiscoverCategoryTap onCategoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoriesAsync =
        isExpanded ? ref.watch(discoverSourceCategoriesProvider(source)) : null;
    final loadedSource = categoriesAsync?.valueOrNull ?? source;
    final latencyMs = loadedSource.latencyMs;
    final statusColor = _getStatusColor(
      loadedSource.status,
      latencyMs,
      colorScheme,
    );
    final showLoadedMeta =
        categoriesAsync?.hasValue == true &&
        (loadedSource.categories.isNotEmpty || latencyMs != null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: palette.cardColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 54),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: palette.cardBorderColor.withValues(alpha: 0.34),
                  ),
                ),
                child: Row(
                  children: [
                    _StatusDot(
                      color: statusColor,
                      label: _statusLabel(loadedSource.status),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loadedSource.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: palette.cardTextColor,
                        ),
                      ),
                    ),
                    if (showLoadedMeta) ...[
                      const SizedBox(width: 10),
                      _SourceRowLoadedMeta(source: loadedSource),
                    ],
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: palette.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child:
                isExpanded
                    ? _CategoryPanel(
                      source: loadedSource,
                      categoriesAsync: categoriesAsync,
                      palette: palette,
                      onCategoryTap: onCategoryTap,
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(
    DiscoverSourceStatus status,
    int? latencyMs,
    ColorScheme colorScheme,
  ) {
    return switch (status) {
      DiscoverSourceStatus.available =>
        latencyMs != null && latencyMs > 1500 ? Colors.orange : Colors.green,
      DiscoverSourceStatus.slow => Colors.orange,
      DiscoverSourceStatus.unavailable => colorScheme.error,
    };
  }

  static String _statusLabel(DiscoverSourceStatus status) {
    return switch (status) {
      DiscoverSourceStatus.available => '可用',
      DiscoverSourceStatus.slow => '较慢',
      DiscoverSourceStatus.unavailable => '异常',
    };
  }

  static String _latencyText(int? latencyMs) {
    if (latencyMs == null || latencyMs <= 0) {
      return '-';
    }
    if (latencyMs < 1000) {
      return '${latencyMs}ms';
    }
    return '${(latencyMs / 1000).toStringAsFixed(1)}s';
  }

  static String? _failureText(DiscoverSourceSummary source) {
    final failure = source.failure;
    if (failure == null) return null;
    final actionHint = failure.actionHint.trim();
    if (actionHint.isEmpty) {
      return '${failure.displayCode}：${failure.displayHint}';
    }
    return '${failure.displayCode}：${failure.displayHint}\n$actionHint';
  }
}

class _SourceRowLoadedMeta extends StatelessWidget {
  const _SourceRowLoadedMeta({required this.source});

  final DiscoverSourceSummary source;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final latency = _SourceRow._latencyText(source.latencyMs);
    final parts = <String>['${source.categoryCount}类'];
    if (latency != '-') {
      parts.add(latency);
    }
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CategoryPanel extends ConsumerWidget {
  const _CategoryPanel({
    required this.source,
    required this.categoriesAsync,
    required this.palette,
    required this.onCategoryTap,
  });

  final DiscoverSourceSummary source;
  final AsyncValue<DiscoverSourceSummary>? categoriesAsync;
  final ResolvedAdvancedThemePalette palette;
  final _DiscoverCategoryTap onCategoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final async = categoriesAsync;
    final loadedSource = async?.valueOrNull ?? source;
    final categories = loadedSource.categories;

    Widget message(String text, {VoidCallback? onRetry}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 33, right: 14),
      child: switch (async) {
        AsyncValue(:final isLoading) when isLoading => message(
          '正在加载该书源的发现分类...',
        ),
        AsyncValue(:final hasError) when hasError => message(
          _SourceRow._failureText(loadedSource) ?? '分类加载失败，请稍后重试',
          onRetry:
              () => ref.invalidate(discoverSourceCategoriesProvider(source)),
        ),
        _ when categories.isEmpty => message(
          _SourceRow._failureText(loadedSource) ??
              '暂无可浏览分类${_loadMetaText(loadedSource)}',
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryLoadMeta(source: loadedSource),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children:
                  categories
                      .map(
                        (category) => _CategoryChip(
                          category: category,
                          palette: palette,
                          onTap:
                              (sourceContext) => onCategoryTap(
                                sourceContext,
                                loadedSource,
                                category,
                              ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      },
    );
  }

  String _loadMetaText(DiscoverSourceSummary source) {
    final latency = _SourceRow._latencyText(source.latencyMs);
    if (latency == '-') {
      return '';
    }
    return '，用时 $latency';
  }
}

class _CategoryLoadMeta extends StatelessWidget {
  const _CategoryLoadMeta({required this.source});

  final DiscoverSourceSummary source;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final latency = _SourceRow._latencyText(source.latencyMs);
    final parts = <String>['已加载 ${source.categoryCount} 个分类'];
    if (latency != '-') {
      parts.add('用时 $latency');
    }
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.palette,
    required this.onTap,
  });

  final DiscoverSourceCategory category;
  final ResolvedAdvancedThemePalette palette;
  final ValueChanged<BuildContext> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.cardTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: palette.textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: '状态：$label',
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
