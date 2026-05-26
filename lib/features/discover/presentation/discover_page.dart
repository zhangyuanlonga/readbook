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
  String _searchKeyword = '';
  String? _expandedSourceId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final sourcesAsync = ref.watch(discoverSourceSummariesProvider);
    final horizontal = metrics.pagePadding;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final isWide = AppLayout.isMediumUp(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('发现'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () {
              ref.invalidate(discoverSourceSummariesProvider);
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
    required AsyncValue<List<DiscoverSourceSummary>> sourcesAsync,
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

    final sources = sourcesAsync.value ?? [];
    final filteredSources = _filterSources(sources);

    if (sources.isEmpty) {
      return Center(
        child: AppEmptyStateCard(
          icon: Icons.travel_explore_rounded,
          title: '暂无书源',
          description: '服务器暂未返回书源列表',
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // 顶部间距 + 搜索框
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topInset + 10,
            horizontal,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _buildSearchBar(context, palette)),
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
                  showColumns: isWide,
                  isExpanded: _expandedSourceId == source.id,
                  palette: palette,
                  onTap: () {
                    setState(() {
                      _expandedSourceId =
                          _expandedSourceId == source.id ? null : source.id;
                    });
                  },
                  onCategoryTap: (sourceContext, category) {
                    _openCategoryWithReveal(
                      sourceContext,
                      source: source,
                      category: category,
                    );
                  },
                ),
              );
            },
          ),
        ),
        // 无搜索结果提示
        if (filteredSources.isEmpty && _searchKeyword.isNotEmpty)
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
                      '没有找到 "$_searchKeyword"',
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
    ResolvedAdvancedThemePalette palette,
  ) {
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
                onChanged: (value) {
                  setState(() {
                    _searchKeyword = value;
                  });
                },
              ),
            ),
            if (_searchKeyword.isNotEmpty)
              IconButton(
                tooltip: '清空',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  setState(() {
                    _searchKeyword = '';
                    _searchController.clear();
                  });
                },
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  List<DiscoverSourceSummary> _filterSources(
    List<DiscoverSourceSummary> sources,
  ) {
    if (_searchKeyword.isEmpty) {
      return sources;
    }
    return sources.where((source) {
      return source.name.toLowerCase().contains(_searchKeyword.toLowerCase());
    }).toList();
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

typedef _DiscoverCategoryTap =
    void Function(BuildContext sourceContext, DiscoverSourceCategory category);

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.showColumns,
    required this.isExpanded,
    required this.palette,
    required this.onTap,
    required this.onCategoryTap,
  });

  final DiscoverSourceSummary source;
  final bool showColumns;
  final bool isExpanded;
  final ResolvedAdvancedThemePalette palette;
  final VoidCallback onTap;
  final _DiscoverCategoryTap onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final latencyMs = source.latencyMs;
    final statusColor = _getStatusColor(source.status, latencyMs, colorScheme);
    final latencyColor = _getLatencyColor(latencyMs, colorScheme);

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
                constraints: BoxConstraints(minHeight: showColumns ? 50 : 54),
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
                      label: _statusLabel(source.status),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: palette.cardTextColor,
                        ),
                      ),
                    ),
                    if (showColumns) ...[
                      _ValueCell(
                        label: '${source.categoryCount}类',
                        width: 72,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      _ValueCell(
                        label: _latencyText(latencyMs),
                        width: 74,
                        alignEnd: true,
                        color: latencyColor,
                      ),
                    ] else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MetaText(
                            text: '${source.categoryCount}类',
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          _MetaText(
                            text: _latencyText(latencyMs),
                            color: latencyColor,
                          ),
                        ],
                      ),
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
                      failureText: _failureText(source),
                      categories: source.categories,
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

  Color _getLatencyColor(int? latencyMs, ColorScheme colorScheme) {
    if (latencyMs == null || latencyMs <= 0) {
      return colorScheme.onSurfaceVariant;
    }
    if (latencyMs < 500) {
      return Colors.green;
    }
    if (latencyMs < 1500) {
      return Colors.orange;
    }
    return colorScheme.error;
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
    return '${failure.displayCode}：${failure.displayHint}';
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.failureText,
    required this.categories,
    required this.palette,
    required this.onCategoryTap,
  });

  final String? failureText;
  final List<DiscoverSourceCategory> categories;
  final ResolvedAdvancedThemePalette palette;
  final _DiscoverCategoryTap onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 33, right: 14),
      child:
          categories.isEmpty
              ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  failureText ?? '暂无可浏览分类',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              : Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    categories
                        .map(
                          (category) => _CategoryChip(
                            category: category,
                            palette: palette,
                            onTap:
                                (sourceContext) =>
                                    onCategoryTap(sourceContext, category),
                          ),
                        )
                        .toList(),
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

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({
    required this.label,
    required this.width,
    this.alignEnd = false,
    this.color,
  });

  final String label;
  final double width;
  final bool alignEnd;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: alignEnd ? TextAlign.end : TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
