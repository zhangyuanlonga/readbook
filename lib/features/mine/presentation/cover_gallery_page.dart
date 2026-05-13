import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../application/advanced_theme_provider.dart';
import '../application/cover_gallery_provider.dart';
import '../application/cover_gallery_service.dart';
import 'widgets/image_resource_collection_widgets.dart';

enum _CoverGalleryAction { edit, rename, duplicate, delete }

class CoverGalleryPage extends ConsumerStatefulWidget {
  const CoverGalleryPage({super.key});

  @override
  ConsumerState<CoverGalleryPage> createState() => _CoverGalleryPageState();
}

class _CoverGalleryPageState extends ConsumerState<CoverGalleryPage> {
  late final CoverGalleryService _service;
  final TextEditingController _searchController = TextEditingController();

  List<CoverGalleryIndexItem> _galleries = const <CoverGalleryIndexItem>[];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _service = ref.read(coverGalleryServiceProvider);
    _load();
  }

  Future<void> _load() async {
    final galleries = await _service.loadGalleryIndex();
    if (!mounted) {
      return;
    }
    setState(() {
      _galleries = galleries;
      _isLoading = false;
    });
  }

  Future<void> _createGallery() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final gallery = await _service.createGallery();
      ref.read(coverGalleryRevisionProvider.notifier).markChanged();
      await _load();
      if (!mounted) {
        return;
      }
      await _pushMineRoute('/cover-galleries/editor?id=${gallery.id}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openGalleryEditor(CoverGalleryIndexItem gallery) async {
    await _pushMineRoute('/cover-galleries/editor?id=${gallery.id}');
  }

  Future<String?> _showNameDialog({
    required String title,
    required String initialValue,
  }) async {
    final value = await showImageResourceNameSurface(
      context: context,
      title: title,
      initialValue: initialValue,
      labelText: '图集名称',
    );
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  Future<void> _renameGallery(CoverGalleryIndexItem gallery) async {
    final name = await _showNameDialog(
      title: '重命名图集',
      initialValue: gallery.name,
    );
    if (name == null || !mounted) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.renameGallery(galleryId: gallery.id, name: name);
      ref.read(coverGalleryRevisionProvider.notifier).markChanged();
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _duplicateGallery(CoverGalleryIndexItem gallery) async {
    final name = await _showNameDialog(
      title: '复制图集',
      initialValue: '${gallery.name} 副本',
    );
    if (name == null || !mounted) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final copied = await _service.duplicateGallery(
        sourceGalleryId: gallery.id,
        name: name,
      );
      ref.read(coverGalleryRevisionProvider.notifier).markChanged();
      await _load();
      if (!mounted) {
        return;
      }
      await _pushMineRoute('/cover-galleries/editor?id=${copied.id}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteGallery(CoverGalleryIndexItem gallery) async {
    final confirmed = await showImageResourceConfirmSurface(
      context: context,
      title: '删除图集',
      message: '确定删除「${gallery.name}」吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.deleteGallery(gallery.id);
      ref.read(coverGalleryRevisionProvider.notifier).markChanged();
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pushMineRoute(String route) async {
    await context.push(route);
    if (!mounted) {
      return;
    }
    await _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CoverGalleryIndexItem> get _visibleGalleries {
    final keyword = _searchQuery.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _galleries;
    }
    return _galleries
        .where((gallery) => gallery.name.toLowerCase().contains(keyword))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('封面图集'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: '新增图集',
              onPressed: _isLoading || _isSaving ? null : _createGallery,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
            );
            return DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: AppAnimatedSwitcher(
                    child:
                        _isLoading
                            ? const Center(
                              key: ValueKey('cover_gallery_loading'),
                              child: CircularProgressIndicator(),
                            )
                            : _buildGalleryContent(
                              context,
                              metrics: metrics,
                              horizontal: horizontal,
                              topInset: topInset,
                              bottomSafe: bottomSafe,
                            ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const ImageResourceEmptyStateCard(
      icon: Icons.photo_library_outlined,
      title: '还没有封面图集',
      description: '点击右上角新增，准备书架和主题可复用的封面素材。',
    );
  }

  Widget _buildGalleryContent(
    BuildContext context, {
    required AppAdaptiveMetrics metrics,
    required double horizontal,
    required double topInset,
    required double bottomSafe,
  }) {
    final visible = _visibleGalleries;
    final search = AppFadeSlideTransition(
      child: CompactCollectionSearchField(
        controller: _searchController,
        hintText: '搜索封面图集',
        query: _searchQuery,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        onClear: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
          });
        },
      ),
    );
    if (visible.isEmpty) {
      return ListView(
        key: const ValueKey('cover_gallery_content_empty'),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          topInset + metrics.contentGap,
          horizontal,
          metrics.sectionGap + bottomSafe,
        ),
        children: [
          search,
          SizedBox(height: metrics.contentGap),
          _buildEmptyState(context),
        ],
      );
    }
    if (!metrics.isMediumUpWindow) {
      return ListView.builder(
        key: const ValueKey('cover_gallery_content'),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          topInset + metrics.contentGap,
          horizontal,
          metrics.sectionGap + bottomSafe,
        ),
        itemCount: visible.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: metrics.contentGap),
              child: search,
            );
          }
          return Padding(
            padding: EdgeInsets.only(bottom: metrics.contentGap),
            child: _buildGalleryCard(context, visible[index - 1]),
          );
        },
      );
    }
    return CustomScrollView(
      key: const ValueKey('cover_gallery_desktop_grid'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topInset + metrics.contentGap,
            horizontal,
            metrics.contentGap,
          ),
          sliver: SliverToBoxAdapter(child: search),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            0,
            horizontal,
            metrics.sectionGap + bottomSafe,
          ),
          sliver: SliverGrid.builder(
            itemCount: visible.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: metrics.isExpandedWindow ? 320 : 280,
              mainAxisExtent: 176,
              mainAxisSpacing: metrics.contentGap,
              crossAxisSpacing: metrics.contentGap,
            ),
            itemBuilder:
                (context, index) => _buildGalleryCard(context, visible[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryCard(
    BuildContext context,
    CoverGalleryIndexItem gallery,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    const previewCount = 4;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openGalleryEditor(gallery),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    gallery.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<_CoverGalleryAction>(
                  onSelected: (action) {
                    switch (action) {
                      case _CoverGalleryAction.edit:
                        _openGalleryEditor(gallery);
                        break;
                      case _CoverGalleryAction.rename:
                        _renameGallery(gallery);
                        break;
                      case _CoverGalleryAction.duplicate:
                        _duplicateGallery(gallery);
                        break;
                      case _CoverGalleryAction.delete:
                        _deleteGallery(gallery);
                        break;
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem<_CoverGalleryAction>(
                          value: _CoverGalleryAction.edit,
                          child: Text('编辑图集'),
                        ),
                        const PopupMenuItem<_CoverGalleryAction>(
                          value: _CoverGalleryAction.rename,
                          child: Text('重命名'),
                        ),
                        const PopupMenuItem<_CoverGalleryAction>(
                          value: _CoverGalleryAction.duplicate,
                          child: Text('复制图集'),
                        ),
                        const PopupMenuItem<_CoverGalleryAction>(
                          value: _CoverGalleryAction.delete,
                          child: Text('删除图集'),
                        ),
                      ],
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '${gallery.imageCount} 张封面',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 3.1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(previewCount, (index) {
                  final path = index == 0 ? gallery.previewPath : null;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == previewCount - 1 ? 0 : 6,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: _buildPreviewSlot(
                          context,
                          path: path,
                          cacheWidth: 280,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSlot(
    BuildContext context, {
    required String? path,
    required int cacheWidth,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (path == null) {
      return ColoredBox(
        color: colorScheme.surfaceContainerLow,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 24,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return LazyFileImage(
      path: path,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      borderRadius: BorderRadius.circular(10),
      placeholderIcon: Icons.broken_image_outlined,
    );
  }
}
