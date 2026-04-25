import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_provider.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_service.dart';
import '../../../app/platform/app_input_focus_behavior.dart';
import '../../../app/shell_navigation_provider.dart';
import '../../../app/widgets/bottom_nav_icon_view.dart';
import '../../../app/navigation/bottom_nav_icon_resolver.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';

class BottomNavIconGalleryEditorPage extends StatefulWidget {
  const BottomNavIconGalleryEditorPage({super.key, required this.galleryId});

  final String galleryId;

  @override
  State<BottomNavIconGalleryEditorPage> createState() =>
      _BottomNavIconGalleryEditorPageState();
}

class _BottomNavIconGalleryEditorPageState
    extends State<BottomNavIconGalleryEditorPage> {
  final BottomNavIconGalleryService _service = BottomNavIconGalleryService();

  BottomNavIconGallery? _gallery;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final galleries = await _service.loadGalleries();
    BottomNavIconGallery? gallery;
    for (final item in galleries) {
      if (item.id == widget.galleryId) {
        gallery = item;
        break;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _gallery = gallery;
      _isLoading = false;
    });
  }

  Future<void> _pickForSlot(
    BottomNavIconGalleryTab tab,
    BottomNavIconVariantSlot slot,
  ) async {
    final gallery = _gallery;
    if (gallery == null || _isSaving) {
      return;
    }
    final container = ProviderScope.containerOf(context);

    final picked = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Bottom nav icons',
          extensions: ['svg', 'png'],
          mimeTypes: ['image/svg+xml', 'image/png'],
          uniformTypeIdentifiers: ['public.svg-image', 'public.png'],
        ),
      ],
      confirmButtonText: '选择图标',
    );
    if (picked == null || !mounted) {
      return;
    }

    final extension = picked.name.split('.').last.trim().toLowerCase();
    final format = switch (extension) {
      'svg' => BottomNavIconAssetFormat.svg,
      'png' => BottomNavIconAssetFormat.png,
      _ => null,
    };
    if (format == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final asset = await _service.importIconAsset(
        galleryId: gallery.id,
        tab: tab,
        slot: slot,
        sourcePath: picked.path,
        format: format,
      );
      final currentSet = gallery.items[tab] ?? const BottomNavIconSet();
      final updatedGallery = gallery.copyWithItem(
        tab,
        currentSet.copyWithSlot(slot, asset: asset),
      );
      final saved = await _service.saveGallery(updatedGallery);
      container
          .read(bottomNavIconGalleryRevisionProvider.notifier)
          .markChanged();
      if (!mounted) {
        return;
      }
      setState(() {
        _gallery = saved;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _clearSlot(
    BottomNavIconGalleryTab tab,
    BottomNavIconVariantSlot slot,
  ) async {
    final gallery = _gallery;
    if (gallery == null || _isSaving) {
      return;
    }
    final container = ProviderScope.containerOf(context);

    final currentSet = gallery.items[tab] ?? const BottomNavIconSet();
    final previousAsset = currentSet.assetForSlot(slot);

    setState(() {
      _isSaving = true;
    });
    try {
      if (previousAsset != null) {
        await _service.deleteIconAsset(previousAsset);
      }
      final updatedGallery = gallery.copyWithItem(
        tab,
        currentSet.copyWithSlot(slot, clear: true),
      );
      final saved = await _service.saveGallery(updatedGallery);
      container
          .read(bottomNavIconGalleryRevisionProvider.notifier)
          .markChanged();
      if (!mounted) {
        return;
      }
      setState(() {
        _gallery = saved;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/bottom-nav-icon-galleries');
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title:
              _isEditingName
                  ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: TextField(
                      controller: _nameController,
                      autofocus: appEnableAutoFocusForTextInput,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onSubmitted: (_) => _saveName(),
                    ),
                  )
                  : GestureDetector(
                    onTap: _startEditingName,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _gallery?.name ?? '编辑底栏图集',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
          actions: [
            if (_isEditingName)
              IconButton(
                icon: const Icon(Icons.check_rounded),
                onPressed: _saveName,
                tooltip: '保存名称',
              )
            else
              IconButton(
                icon: const Icon(Icons.save_outlined),
                onPressed: _isSaving ? null : _saveGallery,
                tooltip: '保存',
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
            );
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _gallery == null
                        ? const Center(child: Text('图集不存在'))
                        : ListView(
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            12,
                            horizontal,
                            16 + bottomSafe,
                          ),
                          children: [
                            _buildBatchToolbar(),
                            const SizedBox(height: 10),
                            _buildHeaderRow(),
                            const SizedBox(height: 8),
                            for (
                              var index = 0;
                              index < BottomNavIconGalleryTab.values.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(height: 8),
                              _buildTabSection(
                                BottomNavIconGalleryTab.values[index],
                              ),
                            ],
                          ],
                        ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _startEditingName() {
    final gallery = _gallery;
    if (gallery == null) return;
    _nameController.text = gallery.name;
    setState(() {
      _isEditingName = true;
    });
  }

  Future<void> _saveName() async {
    final gallery = _gallery;
    if (gallery == null || _isSaving) return;
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    final container = ProviderScope.containerOf(context);

    setState(() {
      _isSaving = true;
    });
    try {
      final saved = await _service.saveGallery(
        gallery.copyWith(name: newName, updatedAt: DateTime.now()),
      );
      container
          .read(bottomNavIconGalleryRevisionProvider.notifier)
          .markChanged();
      if (!mounted) return;
      setState(() {
        _gallery = saved;
        _isEditingName = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveGallery() async {
    final gallery = _gallery;
    if (gallery == null || _isSaving) return;
    final container = ProviderScope.containerOf(context);

    setState(() {
      _isSaving = true;
    });
    try {
      final updated = gallery.copyWith(updatedAt: DateTime.now());
      final saved = await _service.saveGallery(updated);
      container
          .read(bottomNavIconGalleryRevisionProvider.notifier)
          .markChanged();
      if (!mounted) return;
      setState(() {
        _gallery = saved;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已保存'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12),
      child: Row(
        children: [
          const SizedBox(width: 42, child: Text('')),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(
                  Icons.light_mode_outlined,
                  size: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(
                  width: 48,
                  child: Text('未选中', textAlign: TextAlign.center),
                ),
                const SizedBox(
                  width: 48,
                  child: Text('已选中', textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(
                  Icons.dark_mode_outlined,
                  size: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(
                  width: 48,
                  child: Text('未选中', textAlign: TextAlign.center),
                ),
                const SizedBox(
                  width: 48,
                  child: Text('已选中', textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchToolbar() {
    final colorScheme = Theme.of(context).colorScheme;
    final allLightConfigured = BottomNavIconGalleryTab.values.every((tab) {
      final set = _gallery?.items[tab] ?? const BottomNavIconSet();
      return set.lightUnselected != null && set.lightSelected != null;
    });

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: allLightConfigured && !_isSaving ? _copyAllLightToDark : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color:
              allLightConfigured
                  ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.copy_all_rounded,
              size: 18,
              color:
                  allLightConfigured
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '全部夜间 ← 同日间',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      allLightConfigured
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            if (!allLightConfigured)
              Text(
                '需先配齐日间',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSection(BottomNavIconGalleryTab tab) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconSet = _gallery!.items[tab] ?? const BottomNavIconSet();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              _tabLabel(tab),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 48,
                  child: _buildCompactSlot(
                    tab: tab,
                    slot: BottomNavIconVariantSlot.lightUnselected,
                    asset: iconSet.lightUnselected,
                    brightnessIcon: Icons.light_mode_outlined,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: _buildCompactSlot(
                    tab: tab,
                    slot: BottomNavIconVariantSlot.lightSelected,
                    asset: iconSet.lightSelected,
                    brightnessIcon: Icons.light_mode_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 48,
                  child: _buildCompactSlot(
                    tab: tab,
                    slot: BottomNavIconVariantSlot.darkUnselected,
                    asset: iconSet.darkUnselected,
                    brightnessIcon: Icons.dark_mode_outlined,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: _buildCompactSlot(
                    tab: tab,
                    slot: BottomNavIconVariantSlot.darkSelected,
                    asset: iconSet.darkSelected,
                    brightnessIcon: Icons.dark_mode_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSlot({
    required BottomNavIconGalleryTab tab,
    required BottomNavIconVariantSlot slot,
    required BottomNavIconAssetRef? asset,
    required IconData brightnessIcon,
  }) {
    final isSelectedSlot =
        slot == BottomNavIconVariantSlot.lightSelected ||
        slot == BottomNavIconVariantSlot.darkSelected;
    final brightness =
        slot == BottomNavIconVariantSlot.darkSelected ||
                slot == BottomNavIconVariantSlot.darkUnselected
            ? Brightness.dark
            : Brightness.light;
    final fallback = resolveCupertinoBottomNavIcon(
      tab: switch (tab) {
        BottomNavIconGalleryTab.home => AppShellTab.home,
        BottomNavIconGalleryTab.bookshelf => AppShellTab.bookshelf,
        BottomNavIconGalleryTab.discover => AppShellTab.discover,
        BottomNavIconGalleryTab.stats => AppShellTab.stats,
        BottomNavIconGalleryTab.mine => AppShellTab.mine,
      },
      selected: isSelectedSlot,
      brightness: brightness,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _isSaving ? null : () => _pickForSlot(tab, slot),
      borderRadius: BorderRadius.circular(10),
      onLongPress:
          asset == null || _isSaving ? null : () => _clearSlot(tab, slot),
      child: Container(
        width: 48,
        height: 44,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child:
            asset == null
                ? Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                )
                : BottomNavIconView(
                  icon: fallback.copyWith(assetRef: asset),
                  size: 24,
                ),
      ),
    );
  }

  Future<void> _copyLightToDark(BottomNavIconGalleryTab tab) async {
    final gallery = _gallery;
    if (gallery == null || _isSaving) return;
    final container = ProviderScope.containerOf(context);

    final lightSet = gallery.items[tab] ?? const BottomNavIconSet();
    if (lightSet.lightUnselected == null && lightSet.lightSelected == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      var darkSet = gallery.items[tab] ?? const BottomNavIconSet();

      if (lightSet.lightUnselected != null) {
        final dupAsset = BottomNavIconAssetRef(
          path: lightSet.lightUnselected!.path,
          format: lightSet.lightUnselected!.format,
          isAsset: lightSet.lightUnselected!.isAsset,
        );
        darkSet = darkSet.copyWithSlot(
          BottomNavIconVariantSlot.darkUnselected,
          asset: dupAsset,
        );
      }

      if (lightSet.lightSelected != null) {
        final dupAsset = BottomNavIconAssetRef(
          path: lightSet.lightSelected!.path,
          format: lightSet.lightSelected!.format,
          isAsset: lightSet.lightSelected!.isAsset,
        );
        darkSet = darkSet.copyWithSlot(
          BottomNavIconVariantSlot.darkSelected,
          asset: dupAsset,
        );
      }

      final updatedGallery = gallery.copyWithItem(tab, darkSet);
      final saved = await _service.saveGallery(updatedGallery);
      container
          .read(bottomNavIconGalleryRevisionProvider.notifier)
          .markChanged();
      if (!mounted) return;
      setState(() {
        _gallery = saved;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _copyAllLightToDark() async {
    for (final tab in BottomNavIconGalleryTab.values) {
      await _copyLightToDark(tab);
    }
  }

  String _tabLabel(BottomNavIconGalleryTab tab) {
    return switch (tab) {
      BottomNavIconGalleryTab.home => '首页',
      BottomNavIconGalleryTab.bookshelf => '书架',
      BottomNavIconGalleryTab.discover => '发现',
      BottomNavIconGalleryTab.stats => '统计',
      BottomNavIconGalleryTab.mine => '我的',
    };
  }
}
