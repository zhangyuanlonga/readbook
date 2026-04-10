import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_service.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';

class BottomNavIconGalleryPage extends StatefulWidget {
  const BottomNavIconGalleryPage({super.key});

  @override
  State<BottomNavIconGalleryPage> createState() =>
      _BottomNavIconGalleryPageState();
}

class _BottomNavIconGalleryPageState extends State<BottomNavIconGalleryPage> {
  final BottomNavIconGalleryService _service = BottomNavIconGalleryService();

  List<BottomNavIconGallery> _galleries = const <BottomNavIconGallery>[];
  String? _activeGalleryId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final galleries = await _service.loadGalleries();
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
        context.go('/mine');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('底栏图集')),
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
                        : ListView(
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            12,
                            horizontal,
                            16 + bottomSafe,
                          ),
                          children: [
                            Text(
                              '当前先提供默认图集与启用切换，新增/编辑会在下一阶段接入。',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(height: 1.35),
                            ),
                            const SizedBox(height: 12),
                            for (
                              var index = 0;
                              index < _galleries.length;
                              index++
                            )
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      index == _galleries.length - 1 ? 0 : 10,
                                ),
                                child: _buildGalleryCard(
                                  context,
                                  gallery: _galleries[index],
                                ),
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

  Widget _buildGalleryCard(
    BuildContext context, {
    required BottomNavIconGallery gallery,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = gallery.id == _activeGalleryId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _isSaving ? null : () => _setActiveGallery(gallery.id),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color:
                active
                    ? colorScheme.secondaryContainer.withValues(alpha: 0.32)
                    : colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  active
                      ? colorScheme.primary.withValues(alpha: 0.3)
                      : colorScheme.outlineVariant.withValues(alpha: 0.48),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      active
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.dock_outlined,
                  color:
                      active
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            gallery.name,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (gallery.isBuiltIn) _buildPill(context, label: '内置'),
                        if (!gallery.isBuiltIn)
                          _buildPill(context, label: '自定义'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      active ? '当前已启用' : '点击设为默认图集',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
                Icon(
                  active ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: active ? colorScheme.primary : colorScheme.outline,
                ),
            ],
          ),
        ),
      ),
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
