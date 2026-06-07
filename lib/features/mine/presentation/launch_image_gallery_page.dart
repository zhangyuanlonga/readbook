import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_grid_sliver.dart';
import '../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../application/advanced_theme_provider.dart';
import '../application/gallery_index_models.dart';
import '../application/launch_image_gallery_provider.dart';
import '../application/launch_image_gallery_service.dart';
import 'widgets/image_resource_collection_widgets.dart';
import 'widgets/mine_route_top_bar.dart';

enum _LaunchGalleryAction { setDefault, edit, rename, duplicate, delete }

class LaunchImageGalleryPage extends ConsumerStatefulWidget {
  const LaunchImageGalleryPage({super.key});

  @override
  ConsumerState<LaunchImageGalleryPage> createState() =>
      _LaunchImageGalleryPageState();
}

class _LaunchImageGalleryPageState
    extends ConsumerState<LaunchImageGalleryPage> {
  late final LaunchImageGalleryService _service;
  final TextEditingController _searchController = TextEditingController();

  List<LaunchImageGalleryIndexItem> _galleries =
      const <LaunchImageGalleryIndexItem>[];
  String _searchQuery = '';
  bool _startupEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _service = ref.read(launchImageGalleryServiceProvider);
    _load();
  }

  Future<void> _load() async {
    final galleries = await _service.loadGalleryIndex();
    final startupEnabled = await _service.loadStartupEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _galleries = galleries;
      _startupEnabled = startupEnabled;
      _isLoading = false;
    });
  }

  Future<void> _setStartupEnabled(bool enabled) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _startupEnabled = enabled;
      _isSaving = true;
    });
    try {
      await _service.saveStartupEnabled(enabled);
      ref.read(launchImageGalleryRevisionProvider.notifier).markChanged();
      if (mounted) {
        _showMessage(enabled ? '启动图已开启' : '启动图已关闭');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
      ref.read(launchImageGalleryRevisionProvider.notifier).markChanged();
      await _load();
      if (!mounted) {
        return;
      }
      await _pushMineRoute('/appearance/launch-image/editor?id=${gallery.id}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openGalleryEditor(LaunchImageGalleryIndexItem gallery) async {
    await _pushMineRoute('/appearance/launch-image/editor?id=${gallery.id}');
  }

  Future<void> _setDefaultGallery(LaunchImageGalleryIndexItem gallery) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.saveActiveGalleryId(gallery.id);
      ref.read(launchImageGalleryRevisionProvider.notifier).markChanged();
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _renameGallery(LaunchImageGalleryIndexItem gallery) async {
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
      ref.read(launchImageGalleryRevisionProvider.notifier).markChanged();
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _duplicateGallery(LaunchImageGalleryIndexItem gallery) async {
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
      ref.read(launchImageGalleryRevisionProvider.notifier).markChanged();
      await _load();
      if (!mounted) {
        return;
      }
      await _pushMineRoute('/appearance/launch-image/editor?id=${copied.id}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteGallery(LaunchImageGalleryIndexItem gallery) async {
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
      ref.read(launchImageGalleryRevisionProvider.notifier).markChanged();
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LaunchImageGalleryIndexItem> get _visibleGalleries {
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
                              key: ValueKey('launch_gallery_loading'),
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
      title: '启动图集',
      subtitle: _startupEnabled ? '启动展示已开启' : '启动展示已关闭',
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

  Widget _buildEmptyState(BuildContext context) {
    return const ImageResourceEmptyStateCard(
      icon: Icons.rocket_launch_outlined,
      title: '还没有启动图集',
      description: '点击右上角新增，准备启动页和主题可复用的启动素材。',
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
    final toolbar = AppFadeSlideTransition(
      child: _buildSearchAndStartupSwitch(context),
    );
    if (visible.isEmpty) {
      return ListView(
        key: const ValueKey('launch_gallery_content_empty'),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          topInset + metrics.contentGap,
          horizontal,
          metrics.sectionGap + bottomSafe,
        ),
        children: [
          toolbar,
          SizedBox(height: metrics.contentGap),
          _buildEmptyState(context),
        ],
      );
    }
    if (!metrics.isMediumUpWindow) {
      return ListView.builder(
        key: const ValueKey('launch_gallery_content'),
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
              child: toolbar,
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
      key: const ValueKey('launch_gallery_desktop_grid'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topInset + metrics.contentGap,
            horizontal,
            metrics.contentGap,
          ),
          sliver: SliverToBoxAdapter(child: toolbar),
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
            childAspectRatio: 1.38,
            itemBuilder:
                (context, index) => _buildGalleryCard(context, visible[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndStartupSwitch(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: CompactCollectionSearchField(
            controller: _searchController,
            hintText: '搜索启动图集',
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
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: _startupEnabled ? '启动时显示启动图' : '启动时不显示启动图',
          child: Container(
            height: 40,
            padding: const EdgeInsets.only(left: 10, right: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.rocket_launch_outlined,
                  size: 18,
                  color:
                      _startupEnabled
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 38,
                  height: 28,
                  child: Transform.scale(
                    scale: 0.78,
                    child: Switch.adaptive(
                      value: _startupEnabled,
                      onChanged: _isSaving ? null : _setStartupEnabled,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryCard(
    BuildContext context,
    LaunchImageGalleryIndexItem gallery,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    const previewCount = 3;
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
                PopupMenuButton<_LaunchGalleryAction>(
                  onSelected: (action) {
                    switch (action) {
                      case _LaunchGalleryAction.setDefault:
                        _setDefaultGallery(gallery);
                        break;
                      case _LaunchGalleryAction.edit:
                        _openGalleryEditor(gallery);
                        break;
                      case _LaunchGalleryAction.rename:
                        _renameGallery(gallery);
                        break;
                      case _LaunchGalleryAction.duplicate:
                        _duplicateGallery(gallery);
                        break;
                      case _LaunchGalleryAction.delete:
                        _deleteGallery(gallery);
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<_LaunchGalleryAction>>[
                      const PopupMenuItem<_LaunchGalleryAction>(
                        value: _LaunchGalleryAction.setDefault,
                        child: Text('设为默认'),
                      ),
                      const PopupMenuItem<_LaunchGalleryAction>(
                        value: _LaunchGalleryAction.edit,
                        child: Text('编辑图集'),
                      ),
                    ];
                    if (gallery.isEditable) {
                      items.add(
                        const PopupMenuItem<_LaunchGalleryAction>(
                          value: _LaunchGalleryAction.rename,
                          child: Text('重命名'),
                        ),
                      );
                      items.add(
                        const PopupMenuItem<_LaunchGalleryAction>(
                          value: _LaunchGalleryAction.duplicate,
                          child: Text('复制图集'),
                        ),
                      );
                      if (gallery.isDeletable) {
                        items.add(
                          const PopupMenuItem<_LaunchGalleryAction>(
                            value: _LaunchGalleryAction.delete,
                            child: Text('删除图集'),
                          ),
                        );
                      }
                    }
                    return items;
                  },
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
                  '${gallery.imageCount} 张启动图',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (gallery.isBuiltIn) ...[
                  const SizedBox(width: 8),
                  _buildPill(context, label: '内置'),
                ],
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
                  final previewPath = index == 0 ? gallery.previewPath : null;
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
                          path: previewPath,
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
