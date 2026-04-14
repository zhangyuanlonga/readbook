import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_service.dart';
import '../../../app/shell_navigation_provider.dart';
import '../../../app/widgets/bottom_nav_icon_view.dart';
import '../../../app/navigation/bottom_nav_icon_resolver.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';

class BottomNavIconGalleryEditorPage extends StatefulWidget {
  const BottomNavIconGalleryEditorPage({
    super.key,
    required this.galleryId,
  });

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

  @override
  void initState() {
    super.initState();
    _load();
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

    final picked = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Bottom nav icons',
          extensions: ['svg', 'png'],
          mimeTypes: ['image/svg+xml', 'image/png'],
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
        appBar: AppBar(
          title: Text(_gallery?.name ?? '编辑底栏图集'),
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
                            _buildModeSection(
                              context,
                              title: '日间',
                              configured: _configuredCountForBrightness(
                                Brightness.light,
                              ),
                              unselectedSlot:
                                  BottomNavIconVariantSlot.lightUnselected,
                              selectedSlot:
                                  BottomNavIconVariantSlot.lightSelected,
                            ),
                            const SizedBox(height: 16),
                            _buildModeSection(
                              context,
                              title: '夜间',
                              configured: _configuredCountForBrightness(
                                Brightness.dark,
                              ),
                              unselectedSlot:
                                  BottomNavIconVariantSlot.darkUnselected,
                              selectedSlot:
                                  BottomNavIconVariantSlot.darkSelected,
                            ),
                          ],
                        ),
              ),
            );
          },
        ),
      ),
    );
  }

  int _configuredCountForBrightness(Brightness brightness) {
    final gallery = _gallery;
    if (gallery == null) {
      return 0;
    }
    var count = 0;
    for (final tab in BottomNavIconGalleryTab.values) {
      final iconSet = gallery.items[tab];
      if (iconSet == null) {
        continue;
      }
      final unselected = brightness == Brightness.light
          ? iconSet.lightUnselected
          : iconSet.darkUnselected;
      final selected = brightness == Brightness.light
          ? iconSet.lightSelected
          : iconSet.darkSelected;
      if (unselected != null) {
        count += 1;
      }
      if (selected != null) {
        count += 1;
      }
    }
    return count;
  }

  Widget _buildModeSection(
    BuildContext context, {
    required String title,
    required int configured,
    required BottomNavIconVariantSlot unselectedSlot,
    required BottomNavIconVariantSlot selectedSlot,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$title · 已配置 $configured/8',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                const SizedBox(width: 72, child: Text('未选中')),
                const SizedBox(width: 12),
                const SizedBox(width: 72, child: Text('已选中')),
              ],
            ),
          ),
          for (var index = 0; index < BottomNavIconGalleryTab.values.length; index++)
            Column(
              children: [
                if (index > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tabLabel(BottomNavIconGalleryTab.values[index]),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _buildSlotCell(
                        context,
                        tab: BottomNavIconGalleryTab.values[index],
                        slot: unselectedSlot,
                      ),
                      const SizedBox(width: 12),
                      _buildSlotCell(
                        context,
                        tab: BottomNavIconGalleryTab.values[index],
                        slot: selectedSlot,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSlotCell(
    BuildContext context, {
    required BottomNavIconGalleryTab tab,
    required BottomNavIconVariantSlot slot,
  }) {
    final gallery = _gallery!;
    final iconSet = gallery.items[tab] ?? const BottomNavIconSet();
    final asset = iconSet.assetForSlot(slot);
    final isSelectedSlot = slot == BottomNavIconVariantSlot.lightSelected ||
        slot == BottomNavIconVariantSlot.darkSelected;
    final fallback = resolveCupertinoBottomNavIcon(
      tab: switch (tab) {
        BottomNavIconGalleryTab.bookshelf => AppShellTab.bookshelf,
        BottomNavIconGalleryTab.discover => AppShellTab.discover,
        BottomNavIconGalleryTab.stats => AppShellTab.stats,
        BottomNavIconGalleryTab.mine => AppShellTab.mine,
      },
      selected: isSelectedSlot,
      brightness: slot == BottomNavIconVariantSlot.darkSelected ||
              slot == BottomNavIconVariantSlot.darkUnselected
          ? Brightness.dark
          : Brightness.light,
    );

    return InkWell(
      onTap: _isSaving ? null : () => _pickForSlot(tab, slot),
      borderRadius: BorderRadius.circular(12),
      onLongPress: asset == null || _isSaving ? null : () => _clearSlot(tab, slot),
      child: Container(
        width: 72,
        height: 52,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(
              alpha: 0.55,
            ),
          ),
        ),
        alignment: Alignment.center,
        child:
            asset == null
                ? const Icon(Icons.add_rounded)
                : BottomNavIconView(icon: fallback.copyWith(assetRef: asset), size: 24),
      ),
    );
  }

  String _tabLabel(BottomNavIconGalleryTab tab) {
    return switch (tab) {
      BottomNavIconGalleryTab.bookshelf => '书架',
      BottomNavIconGalleryTab.discover => '发现',
      BottomNavIconGalleryTab.stats => '统计',
      BottomNavIconGalleryTab.mine => '我的',
    };
  }
}
