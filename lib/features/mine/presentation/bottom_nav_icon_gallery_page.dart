import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_provider.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_service.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_tab_mapper.dart';
import '../../../app/navigation/bottom_nav_icon_resolver.dart';
import '../../../app/shell_navigation_provider.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_grid_sliver.dart';
import '../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/bottom_nav_icon_view.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import '../application/advanced_theme_provider.dart';
import '../application/gallery_index_models.dart';
import 'widgets/image_resource_collection_widgets.dart';
import 'widgets/mine_route_top_bar.dart';

class BottomNavIconGalleryPage extends ConsumerStatefulWidget {
  const BottomNavIconGalleryPage({super.key});

  @override
  ConsumerState<BottomNavIconGalleryPage> createState() =>
      _BottomNavIconGalleryPageState();
}

enum _GalleryAction { activate, edit, rename, duplicate, delete }

class _BottomNavIconGalleryPageState
    extends ConsumerState<BottomNavIconGalleryPage> {
  late final BottomNavIconGalleryService _service;
  final TextEditingController _searchController = TextEditingController();

  List<BottomNavIconGalleryIndexItem> _galleries =
      const <BottomNavIconGalleryIndexItem>[];
  String? _activeGalleryId;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _service = ref.read(bottomNavIconGalleryServiceProvider);
    _load();
  }

  Future<void> _load() async {
    final galleries = await _service.loadGalleryIndex();
    final activeGallery = await _service.loadActiveGallery();
    if (!mounted) {
      return;
    }
    setState(() {
      _galleries = galleries;
      _activeGalleryId = activeGallery?.id;
      _isLoading = false;
    });
  }

  Future<void> _setActiveGallery(String id) async {
    if (_isSaving || _activeGalleryId == id) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.saveActiveGalleryId(id);
      ref.read(bottomNavIconGalleryRevisionProvider.notifier).markChanged();
      if (!mounted) {
        return;
      }
      setState(() {
        _activeGalleryId = id;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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

  Future<void> _createGallery() async {
    if (_isSaving || !mounted) return;
    setState(() {
      _isSaving = true;
    });
    try {
      final gallery = await _service.createGallery(name: '未命名图集');
      ref.read(bottomNavIconGalleryRevisionProvider.notifier).markChanged();
      await _load();
      if (!mounted) return;
      await _openEditor(gallery.id);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _renameGallery(BottomNavIconGalleryIndexItem gallery) async {
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
      ref.read(bottomNavIconGalleryRevisionProvider.notifier).markChanged();
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _duplicateGallery(BottomNavIconGalleryIndexItem gallery) async {
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
      ref.read(bottomNavIconGalleryRevisionProvider.notifier).markChanged();
      await _load();
      if (!mounted) {
        return;
      }
      await _openEditor(copied.id);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteGallery(BottomNavIconGalleryIndexItem gallery) async {
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
      ref.read(bottomNavIconGalleryRevisionProvider.notifier).markChanged();
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BottomNavIconGalleryIndexItem> get _visibleGalleries {
    final keyword = _searchQuery.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _galleries;
    }
    return _galleries
        .where((gallery) => gallery.name.toLowerCase().contains(keyword))
        .toList(growable: false);
  }

  Future<void> _openEditor(String galleryId) async {
    await context.push('/bottom-nav-icon-galleries/editor?id=$galleryId');
    if (!mounted) {
      return;
    }
    await _load();
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
    final routeTopBar = _buildRouteTopBar(context);
    final topInset =
        MediaQuery.paddingOf(context).top + routeTopBar.preferredSize.height;

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
        appBar: routeTopBar,
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
                              key: ValueKey('bottom_nav_gallery_loading'),
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

  PreferredSizeWidget _buildRouteTopBar(BuildContext context) {
    final enabled = !_isLoading && !_isSaving;
    return buildMineRouteTopBar(
      context: context,
      title: '底栏图集',
      subtitle: '移动端底栏图标素材',
      actions: <AdaptiveOverflowToolbarItem>[
        AdaptiveOverflowToolbarItem(
          icon: Icons.add_rounded,
          label: '新增图集',
          priority: 10,
          enabled: enabled,
          onPressed: enabled ? _createGallery : null,
        ),
      ],
      mobileActions: <Widget>[
        IconButton(
          tooltip: '新增图集',
          onPressed: enabled ? _createGallery : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }

  Widget _buildGalleryCard(
    BuildContext context, {
    required BottomNavIconGalleryIndexItem gallery,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final active = gallery.id == _activeGalleryId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(metrics.cardRadius + 2),
        onTap: _isSaving ? null : () => _openEditor(gallery.id),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color:
                active
                    ? colorScheme.secondaryContainer.withValues(alpha: 0.32)
                    : colorScheme.surface,
            borderRadius: BorderRadius.circular(metrics.cardRadius + 2),
            border: Border.all(
              color:
                  active
                      ? colorScheme.primary.withValues(alpha: 0.3)
                      : colorScheme.outlineVariant.withValues(alpha: 0.48),
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
                  if (gallery.isBuiltIn) _buildPill(context, label: '内置'),
                  if (!gallery.isBuiltIn) _buildPill(context, label: '自定义'),
                  const SizedBox(width: 6),
                  if (_isSaving && active)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  else
                    PopupMenuButton<_GalleryAction>(
                      onSelected: (action) {
                        switch (action) {
                          case _GalleryAction.activate:
                            _setActiveGallery(gallery.id);
                            break;
                          case _GalleryAction.edit:
                            _openEditor(gallery.id);
                            break;
                          case _GalleryAction.rename:
                            _renameGallery(gallery);
                            break;
                          case _GalleryAction.duplicate:
                            _duplicateGallery(gallery);
                            break;
                          case _GalleryAction.delete:
                            _deleteGallery(gallery);
                            break;
                        }
                      },
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry<_GalleryAction>>[
                          if (!active)
                            const PopupMenuItem<_GalleryAction>(
                              value: _GalleryAction.activate,
                              child: Text('设为默认'),
                            ),
                          const PopupMenuItem<_GalleryAction>(
                            value: _GalleryAction.edit,
                            child: Text('编辑图标'),
                          ),
                        ];

                        if (gallery.isEditable) {
                          items.add(
                            const PopupMenuItem<_GalleryAction>(
                              value: _GalleryAction.rename,
                              child: Text('重命名'),
                            ),
                          );
                        }
                        items.add(
                          const PopupMenuItem<_GalleryAction>(
                            value: _GalleryAction.duplicate,
                            child: Text('复制图集'),
                          ),
                        );
                        if (gallery.isDeletable) {
                          items.add(
                            const PopupMenuItem<_GalleryAction>(
                              value: _GalleryAction.delete,
                              child: Text('删除图集'),
                            ),
                          );
                        }
                        return items;
                      },
                      icon: Icon(
                        active
                            ? Icons.check_circle_rounded
                            : Icons.more_horiz_rounded,
                        color:
                            active ? colorScheme.primary : colorScheme.outline,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                active ? '当前已启用' : '点击设为默认图集',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 5.2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final tab in bottomNavIconGalleryTabs) ...[
                      Expanded(
                        child: _buildLightPreviewSlot(
                          context,
                          gallery: gallery,
                          tab: tab,
                          active: active,
                        ),
                      ),
                      if (tab != bottomNavIconGalleryTabs.last)
                        const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
        hintText: '搜索底栏图集',
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
        key: const ValueKey('bottom_nav_gallery_content_empty'),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          topInset + metrics.contentGap,
          horizontal,
          metrics.sectionGap + bottomSafe,
        ),
        children: [
          search,
          SizedBox(height: metrics.contentGap),
          const AppAnimatedSwitcher(
            child: ImageResourceEmptyStateCard(
              key: ValueKey('bottom_nav_gallery_empty'),
              icon: Icons.dock_outlined,
              title: '没有匹配的底栏图集',
              description: '换个关键词，或点击右上角新增自定义图集。',
            ),
          ),
        ],
      );
    }
    if (!metrics.isMediumUpWindow) {
      return ListView.builder(
        key: const ValueKey('bottom_nav_gallery_content'),
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
            padding: EdgeInsets.only(
              bottom: index == visible.length ? 0 : metrics.contentGap,
            ),
            child: _buildGalleryCard(context, gallery: visible[index - 1]),
          );
        },
      );
    }
    return CustomScrollView(
      key: const ValueKey('bottom_nav_gallery_desktop_grid'),
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
          sliver: AdaptiveGridSliver(
            itemCount: visible.length,
            minItemWidth: metrics.isExpandedWindow ? 240 : 220,
            maxColumns: 3,
            crossSpacing: metrics.contentGap,
            mainSpacing: metrics.contentGap,
            childAspectRatio: 1.61,
            itemBuilder:
                (context, index) =>
                    _buildGalleryCard(context, gallery: visible[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildLightPreviewSlot(
    BuildContext context, {
    required BottomNavIconGalleryIndexItem gallery,
    required BottomNavIconGalleryTab tab,
    required bool active,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconSet = gallery.previewItems[tab] ?? const BottomNavIconSet();
    final asset = iconSet.lightUnselected ?? iconSet.lightSelected;
    final resolved = _fallbackIconForTab(tab).copyWith(assetRef: asset);
    return Container(
      decoration: BoxDecoration(
        color:
            active
                ? colorScheme.primaryContainer.withValues(alpha: 0.34)
                : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      alignment: Alignment.center,
      child: BottomNavIconView(
        icon: resolved,
        size: 18,
        fallbackColor:
            active ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
    );
  }

  ResolvedBottomNavIcon _fallbackIconForTab(BottomNavIconGalleryTab tab) {
    final shellTab = switch (tab) {
      BottomNavIconGalleryTab.bookshelf => AppShellTab.bookshelf,
      BottomNavIconGalleryTab.discover => AppShellTab.discover,
      BottomNavIconGalleryTab.stats => AppShellTab.stats,
      BottomNavIconGalleryTab.mine => AppShellTab.mine,
    };
    return resolveCupertinoBottomNavIcon(
      tab: shellTab,
      selected: false,
      brightness: Brightness.light,
    );
  }

  Widget _buildPill(BuildContext context, {required String label}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
