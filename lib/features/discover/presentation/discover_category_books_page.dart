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
import '../../../domain/entities/book.dart';
import '../../book/presentation/book_detail_route.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../mine/application/advanced_theme_provider.dart';
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
    final sourcesAsync = ref.watch(discoverSourceSummariesProvider);

    return sourcesAsync.when(
      loading:
          () => Scaffold(
            extendBodyBehindAppBar: true,
            appBar: _buildAppBar(context, '分类'),
            body: DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: const Center(child: CircularProgressIndicator()),
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
      data: (sources) {
        final selected = _findCategory(sources);
        final source = selected?.$1;
        final category = selected?.$2;
        final title = category?.name ?? '分类';

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
                    category == null || source == null
                        ? _MissingCategoryState(metrics: metrics)
                        : _CategoryBooksGrid(
                          source: source,
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

  (DiscoverSourceSummary, DiscoverSourceCategory)? _findCategory(
    List<DiscoverSourceSummary> sources,
  ) {
    final decodedSourceId = Uri.decodeComponent(sourceId);
    final decodedCategoryId = Uri.decodeComponent(categoryId);
    for (final source in sources) {
      if (source.id != decodedSourceId) {
        continue;
      }
      for (final category in source.categories) {
        if (category.id == decodedCategoryId) {
          return (source, category);
        }
      }
    }
    return null;
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
      return const Center(child: CircularProgressIndicator());
    }

    if (booksAsync.hasError) {
      final failure =
          booksAsync.error is ApiException
              ? (booksAsync.error as ApiException).gatewayFailure
              : null;
      final description =
          failure == null
              ? '该分类书籍暂时无法加载，请稍后重试'
              : '${failure.displayCode}：${failure.displayHint}';
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

    return CustomScrollView(
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
    );
  }
}

class _DiscoverBookTile extends StatelessWidget {
  const _DiscoverBookTile({
    required this.source,
    required this.book,
    required this.palette,
  });

  final DiscoverSourceSummary source;
  final DiscoverCategoryBook book;
  final ResolvedAdvancedThemePalette palette;

  @override
  Widget build(BuildContext context) {
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
              child: _MockBookCover(book: book, palette: palette),
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

class _MockBookCover extends StatelessWidget {
  const _MockBookCover({required this.book, required this.palette});

  final DiscoverCategoryBook book;
  final ResolvedAdvancedThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _coverColors(colorScheme, book.coverSeed);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 10,
            right: 10,
            bottom: 12,
            child: Text(
              book.name.characters.take(4).toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _coverColors(ColorScheme colorScheme, int seed) {
    final palettes = <List<Color>>[
      [const Color(0xFF355C7D), const Color(0xFF6C5B7B)],
      [const Color(0xFF2F4858), const Color(0xFF33658A)],
      [const Color(0xFF4B644A), const Color(0xFF7A9E7E)],
      [const Color(0xFF5B3758), const Color(0xFFB56576)],
      [const Color(0xFF284B63), const Color(0xFF3C6E71)],
      [const Color(0xFF5F4B66), const Color(0xFFB565A7)],
    ];
    return palettes[seed % palettes.length];
  }
}
