import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../domain/entities/launch_image_gallery.dart';
import '../application/advanced_theme_provider.dart';
import '../application/launch_image_gallery_provider.dart';
import '../application/launch_image_gallery_service.dart';

class LaunchImageGalleryPage extends StatefulWidget {
  const LaunchImageGalleryPage({super.key});

  @override
  State<LaunchImageGalleryPage> createState() => _LaunchImageGalleryPageState();
}

class _LaunchImageGalleryPageState extends State<LaunchImageGalleryPage> {
  final LaunchImageGalleryService _service = LaunchImageGalleryService();

  List<LaunchImageGallery> _galleries = const <LaunchImageGallery>[];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final galleries = await _service.loadGalleries();
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
    final container = ProviderScope.containerOf(context);
    setState(() {
      _isSaving = true;
    });
    try {
      final gallery = await _service.createGallery();
      container.read(launchImageGalleryRevisionProvider.notifier).markChanged();
      await _load();
      if (!mounted) {
        return;
      }
      await context.push('/appearance/launch-image/editor?id=${gallery.id}');
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openGalleryEditor(LaunchImageGallery gallery) async {
    await context.push('/appearance/launch-image/editor?id=${gallery.id}');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final activeAdvancedTheme =
            ref.watch(activeAdvancedThemeProvider).valueOrNull;
        final backdrop = resolveAdvancedThemeBackdrop(
          Theme.of(context).colorScheme,
          activeAdvancedTheme,
        );
        final horizontal = AppSpacing.pageHorizontal(context);
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
              title: const Text('启动图集'),
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
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView(
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  topInset + 12,
                                  horizontal,
                                  16 + bottomSafe,
                                ),
                                children: [
                                  if (_galleries.isEmpty)
                                    _buildEmptyState(context)
                                  else
                                    ..._galleries.map(
                                      (gallery) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _buildGalleryCard(
                                          context,
                                          gallery,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rocket_launch_outlined,
            size: 34,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            '还没有启动图集',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '点击右上角新增，准备你的启动页素材。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryCard(BuildContext context, LaunchImageGallery gallery) {
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
            Text(
              gallery.name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '${gallery.imagePaths.length} 张启动图',
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
            SizedBox(
              height: 92,
              child: Row(
                children: List.generate(previewCount, (index) {
                  final previewPath =
                      index < gallery.imagePaths.length
                          ? _service.resolveGalleryPreviewPath(
                            gallery.copyWith(
                              imagePaths: <String>[gallery.imagePaths[index]],
                            ),
                          )
                          : null;
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
                        child:
                            previewPath == null
                                ? Icon(
                                  Icons.image_outlined,
                                  color: colorScheme.onSurfaceVariant,
                                )
                                : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(previewPath),
                                    fit: BoxFit.cover,
                                  ),
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
}
