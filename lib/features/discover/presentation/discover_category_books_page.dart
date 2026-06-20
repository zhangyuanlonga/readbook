// UI-GOV-EXEMPT-FILE: scaffold
// reason: Phase 10 reviewed discover category shell; custom scaffold preserves existing route chrome.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/gateway_failure.dart';
import '../../../domain/entities/book.dart';
import '../../book/presentation/book_detail_route.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/foundation/app_refresh_indicator.dart';
import '../../../app/widgets/foundation/app_skeleton.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../application/discover_source_provider.dart';
import '../domain/discover_source_summary.dart';

class DiscoverCategoryBooksPage extends ConsumerWidget {
  const DiscoverCategoryBooksPage({
    super.key,
    required this.sourceId,
    required this.categoryId,
  });

  final String sourceId;
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return sourcesAsync.when(
      loading:
          () => Scaffold(
            extendBodyBehindAppBar: true,
            appBar: _buildAppBar(context, '分类'),
            body: DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: _DiscoverCategoryShellLoading(metrics: metrics),
            ),
          ),
      error:
          (_, _) => Scaffold(
            extendBodyBehindAppBar: true,
            appBar: _buildAppBar(context, '分类'),
            body: DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: Center(
                child: AppEmptyStateCard(
                  icon: Icons.error_outline_rounded,
                  title: '加载失败',
                  description: '分类书籍暂时无法加载',
                ),
              ),
            ),
          ),
      data: (sourceState) {
        final source = _findSource(sourceState.items) ?? _sourceFromRoute();
        final categoriesAsync = ref.watch(
          discoverSourceCategoriesProvider(source),
        );
        final loadedSource = categoriesAsync.valueOrNull ?? source;
        final category = _findCategory(loadedSource);
        final title = category?.name ?? loadedSource.name;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(context, title),
          body: DecoratedBox(
            decoration: buildAdvancedThemeBackdropDecoration(backdrop),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppLayout.pageContentMaxWidth(
                    context,
                    maxWidth: AppLayout.discoverMediumContentMaxWidth,
                  ),
                ),
                child:
                    categoriesAsync.isLoading
                        ? _DiscoverCategoryShellLoading(metrics: metrics)
                        : categoriesAsync.hasError
                        ? _CategoryLoadFailureState(
                          metrics: metrics,
                          onRetry:
                              () => ref.invalidate(
                                discoverSourceCategoriesProvider(source),
                              ),
                        )
                        : category == null
                        ? _MissingCategoryState(metrics: metrics)
                        : _CategoryBooksGrid(
                          source: loadedSource,
                          category: category,
                          metrics: metrics,
                          palette: palette,
                        ),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String title) {
    return AppBar(
      title: Text(title),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      leading: Builder(
        builder:
            (leadingContext) => IconButton(
              onPressed: () => _closeWithReveal(context, leadingContext),
              tooltip: '返回',
              icon: const Icon(Icons.arrow_back),
            ),
      ),
    );
  }

  Future<void> _closeWithReveal(
    BuildContext context,
    BuildContext sourceContext,
  ) async {
    final overlay = CircularThemeRevealOverlay.of(sourceContext);
    Future<void> closeRoute() async {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go('/discover');
    }

    if (overlay == null) {
      await closeRoute();
      return;
    }
    final center = CircularThemeRevealOverlay.getCenterFromContext(
      sourceContext,
    );
    await overlay.startTransition(
      center: center,
      reverse: false,
      onThemeChange: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go('/discover');
      },
    );
  }

  DiscoverSourceSummary? _findSource(List<DiscoverSourceSummary> sources) {
    final decodedSourceId = Uri.decodeComponent(sourceId);
    for (final source in sources) {
      if (source.id == decodedSourceId) {
        return source;
      }
    }
    return null;
  }

  DiscoverSourceSummary _sourceFromRoute() {
    final decodedSourceId = Uri.decodeComponent(sourceId);
    return DiscoverSourceSummary(
      id: decodedSourceId,
      name: '分类',
      categoryCount: 0,
      status: DiscoverSourceStatus.available,
      latencyMs: null,
      categories: const <DiscoverSourceCategory>[],
    );
  }

  DiscoverSourceCategory? _findCategory(DiscoverSourceSummary source) {
    final decodedCategoryId = Uri.decodeComponent(categoryId);
    for (final category in source.categories) {
      if (category.id == decodedCategoryId) {
        return category;
      }
    }
    return null;
  }
}

class _CategoryLoadFailureState extends StatelessWidget {
  const _CategoryLoadFailureState({
    required this.metrics,
    required this.onRetry,
  });

  final AppAdaptiveMetrics metrics;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        topInset + metrics.sectionGap,
        metrics.pagePadding,
        metrics.sectionGap,
      ),
      child: Center(
        child: AppEmptyStateCard(
          icon: Icons.error_outline_rounded,
          title: '分类加载失败',
          description: '该书源分类暂时无法加载，请稍后重试',
          actionLabel: '重试',
          onAction: onRetry,
        ),
      ),
    );
  }
}

class _MissingCategoryState extends StatelessWidget {
  const _MissingCategoryState({required this.metrics});

  final AppAdaptiveMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        topInset + metrics.sectionGap,
        metrics.pagePadding,
        metrics.sectionGap,
      ),
      child: const Center(
        child: AppEmptyStateCard(
          icon: Icons.travel_explore_rounded,
          title: '分类不存在',
          description: '该书源分类可能已更新，请返回后刷新书源列表',
        ),
      ),
    );
  }
}

class _CategoryBooksGrid extends ConsumerWidget {
  const _CategoryBooksGrid({
    required this.source,
    required this.category,
    required this.metrics,
    required this.palette,
  });

  final DiscoverSourceSummary source;
  final DiscoverSourceCategory category;
  final AppAdaptiveMetrics metrics;
  final ResolvedAdvancedThemePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final request = DiscoverCategoryBooksRequest(
      source: source,
      category: category,
    );
    final booksAsync = ref.watch(discoverCategoryBooksProvider(request));

    if (booksAsync.isLoading) {
      return _DiscoverBooksGridLoadingState(metrics: metrics);
    }

    if (booksAsync.hasError) {
      final failure =
          booksAsync.error is ApiException
              ? (booksAsync.error as ApiException).gatewayFailure
              : null;
      final description =
          failure == null ? '该分类书籍暂时无法加载，请稍后重试' : _failureDescription(failure);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.pagePadding,
          topInset + metrics.sectionGap,
          metrics.pagePadding,
          metrics.sectionGap,
        ),
        child: Center(
          child: AppEmptyStateCard(
            icon: Icons.error_outline_rounded,
            title: failure?.message ?? '加载失败',
            description: description,
            actionLabel: failure?.retryable == false ? null : '重试',
            onAction:
                failure?.retryable == false
                    ? null
                    : () =>
                        ref.invalidate(discoverCategoryBooksProvider(request)),
          ),
        ),
      );
    }

    final books = booksAsync.value ?? const <DiscoverCategoryBook>[];

    if (books.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.pagePadding,
          topInset + metrics.sectionGap,
          metrics.pagePadding,
          metrics.sectionGap,
        ),
        child: const Center(
          child: AppEmptyStateCard(
            icon: Icons.menu_book_outlined,
            title: '暂无书籍',
            description: '该分类暂时没有可展示的书籍',
          ),
        ),
      );
    }

    return AppRefreshIndicator(
      semanticsLabel: '刷新分类书籍',
      onRefresh: () async {
        ref.invalidate(discoverCategoryBooksProvider(request));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              metrics.pagePadding,
              topInset + 8,
              metrics.pagePadding,
              bottomSafe + metrics.sectionGap,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 14,
                childAspectRatio: 0.56,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return AppFadeSlideTransition(
                  delay: Duration(milliseconds: (index % 9) * 18),
                  child: _DiscoverBookTile(
                    source: source,
                    book: book,
                    palette: palette,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _failureDescription(GatewayFailure failure) {
    final actionHint = failure.actionHint.trim();
    if (actionHint.isEmpty) {
      return '${failure.displayCode}：${failure.displayHint}';
    }
    return '${failure.displayCode}：${failure.displayHint}\n$actionHint';
  }
}

class _DiscoverCategoryShellLoading extends StatelessWidget {
  const _DiscoverCategoryShellLoading({required this.metrics});

  final AppAdaptiveMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            metrics.pagePadding,
            topInset + metrics.sectionGap,
            metrics.pagePadding,
            metrics.sectionGap + bottomSafe,
          ),
          sliver: const SliverToBoxAdapter(
            child: AppSkeletonList(
              itemCount: 4,
              itemHeight: 56,
              showLeading: false,
              showTrailing: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiscoverBooksGridLoadingState extends StatelessWidget {
  const _DiscoverBooksGridLoadingState({required this.metrics});

  final AppAdaptiveMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        topInset + 8,
        metrics.pagePadding,
        bottomSafe + metrics.sectionGap,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 14,
        childAspectRatio: 0.56,
      ),
      itemCount: 6,
      itemBuilder:
          (context, index) => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: AppSkeletonBlock(height: 160)),
              SizedBox(height: 6),
              AppSkeletonBlock(height: 12),
              SizedBox(height: 5),
              AppSkeletonBlock(width: 56, height: 12),
            ],
          ),
    );
  }
}

class _DiscoverBookTile extends ConsumerWidget {
  const _DiscoverBookTile({
    required this.source,
    required this.book,
    required this.palette,
  });

  final DiscoverSourceSummary source;
  final DiscoverCategoryBook book;
  final ResolvedAdvancedThemePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final galleries = ref.watch(coverGalleriesProvider).valueOrNull ?? const [];
    final cover = resolveBookCover(
      realCoverUrl: book.coverUrl,
      activeTheme: activeTheme,
      galleries: galleries,
      brightness: Theme.of(context).brightness,
      bookId: book.id,
      sourceId: source.id,
      detailUrl: book.detailUrl,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openBookDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 68 / 96,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  return ResolvedBookCoverView(
                    cover: cover,
                    title: book.name,
                    author: book.author,
                    width: width,
                    height: height,
                    borderRadius: BorderRadius.circular(12),
                    cacheWidth: _coverDecodeSize(context, width),
                    cacheHeight: _coverDecodeSize(context, height),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              book.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.cardTextColor,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _coverDecodeSize(BuildContext context, double logicalSize) {
    if (!logicalSize.isFinite || logicalSize <= 0) {
      return null;
    }
    final ratio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    return (logicalSize * ratio).round();
  }

  Future<void> _openBookDetail(BuildContext context) async {
    final initialBook =
        book.book ??
        Book(
          id: book.id,
          sourceId: source.id,
          title: book.name,
          detailUrl: book.detailUrl,
          coverUrl: book.coverUrl,
          author: book.author,
          category: source.name,
        );
    final overlay = CircularThemeRevealOverlay.of(context);
    if (overlay == null) {
      final route = buildBookDetailRoute(
        bookId: book.id,
        sourceId: source.id,
        detailUrl: book.detailUrl,
        title: book.name,
        author: book.author,
        coverUrl: book.coverUrl,
      );
      await context.push(route, extra: initialBook);
      return;
    }
    final route = buildBookDetailRoute(
      bookId: book.id,
      sourceId: source.id,
      detailUrl: book.detailUrl,
      title: book.name,
      author: book.author,
      coverUrl: book.coverUrl,
      revealTransition: true,
    );
    final center = CircularThemeRevealOverlay.getCenterFromContext(context);
    await overlay.startTransition(
      center: center,
      reverse: false,
      onThemeChange: () {
        context.push(route, extra: initialBook);
      },
    );
  }
}
