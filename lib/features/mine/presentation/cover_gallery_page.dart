import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../application/advanced_theme_provider.dart';
import '../application/cover_gallery_provider.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../application/cover_gallery_service.dart';
import 'widgets/image_resource_collection_widgets.dart';

class CoverGalleryPage extends ConsumerStatefulWidget {
  const CoverGalleryPage({super.key});

  @override
  ConsumerState<CoverGalleryPage> createState() => _CoverGalleryPageState();
}

class _CoverGalleryPageState extends ConsumerState<CoverGalleryPage> {
  late final CoverGalleryService _service;
  final TextEditingController _searchController = TextEditingController();

  List<CoverGallery> _galleries = const <CoverGallery>[];
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
      await context.push('/cover-galleries/editor?id=${gallery.id}');
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openGalleryEditor(CoverGallery gallery) async {
    await context.push('/cover-galleries/editor?id=${gallery.id}');
    await _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CoverGallery> get _visibleGalleries {
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
                              TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  hintText: '搜索封面图集',
                                  suffixIcon:
                                      _searchQuery.trim().isEmpty
                                          ? null
                                          : IconButton(
                                            tooltip: '清空搜索',
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchQuery = '';
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.close_rounded,
                                            ),
                                          ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_visibleGalleries.isEmpty)
                                _buildEmptyState(context)
                              else
                                ..._visibleGalleries.map(
                                  (gallery) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildGalleryCard(context, gallery),
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
  }

  Widget _buildEmptyState(BuildContext context) {
    return const ImageResourceEmptyStateCard(
      icon: Icons.photo_library_outlined,
      title: '还没有封面图集',
      description: '点击右上角新增，准备书架和主题可复用的封面素材。',
    );
  }

  Widget _buildGalleryCard(BuildContext context, CoverGallery gallery) {
    final colorScheme = Theme.of(context).colorScheme;
    const previewCount = 5;
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
                  '${gallery.imagePaths.length} 张封面',
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
              height: 62,
              child: Row(
                children: List.generate(previewCount, (index) {
                  final path =
                      index < gallery.imagePaths.length
                          ? gallery.imagePaths[index]
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
                            path != null && File(path).existsSync()
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => Icon(
                                          Icons.broken_image_outlined,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                )
                                : Icon(
                                  Icons.image_outlined,
                                  color: colorScheme.onSurfaceVariant,
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
