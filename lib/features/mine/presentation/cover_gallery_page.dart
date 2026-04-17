import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../application/cover_gallery_service.dart';

class CoverGalleryPage extends StatefulWidget {
  const CoverGalleryPage({super.key});

  @override
  State<CoverGalleryPage> createState() => _CoverGalleryPageState();
}

class _CoverGalleryPageState extends State<CoverGalleryPage> {
  final CoverGalleryService _service = CoverGalleryService();

  List<CoverGallery> _galleries = const <CoverGallery>[];
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
    setState(() {
      _isSaving = true;
    });
    try {
      final gallery = await _service.createGallery();
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
        appBar: AppBar(
          title: const Text('封面图集'),
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
                            if (_galleries.isEmpty)
                              _buildEmptyState(context)
                            else
                              ..._galleries.map(
                                (gallery) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildGalleryCard(context, gallery),
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
            Icons.photo_library_outlined,
            size: 34,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            '还没有封面图集',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '点击右上角新增，开始管理你的封面图片。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
                          image:
                              path != null && File(path).existsSync()
                                  ? DecorationImage(
                                    image: FileImage(File(path)),
                                    fit: BoxFit.cover,
                                  )
                                  : null,
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
