import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_fullscreen_preview.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../core/media/image_selection_service.dart';
import '../application/advanced_theme_provider.dart';
import '../application/reader_background_service.dart';
import '../providers.dart';
import 'widgets/image_resource_collection_widgets.dart';

class ReaderBackgroundPage extends ConsumerStatefulWidget {
  const ReaderBackgroundPage({super.key});

  @override
  ConsumerState<ReaderBackgroundPage> createState() =>
      _ReaderBackgroundPageState();
}

class _ReaderBackgroundPageState extends ConsumerState<ReaderBackgroundPage> {
  late final ReaderBackgroundService _service;
  late final ImageSelectionService _imageSelectionService;
  final TextEditingController _searchController = TextEditingController();

  List<String> _backgroundPaths = const <String>[];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _service = ref.read(readerBackgroundServiceProvider);
    _imageSelectionService = ref.read(mineImageSelectionServiceProvider);
    _load();
  }

  Future<void> _load() async {
    final backgrounds = await _service.loadBackgroundPaths();
    if (!mounted) {
      return;
    }
    setState(() {
      _backgroundPaths = backgrounds;
      _isLoading = false;
    });
  }

  Future<void> _uploadBackground() async {
    if (_isSaving) {
      return;
    }
    try {
      final source = await _selectBackgroundImageSource();
      if (source == null || !mounted) {
        return;
      }

      final pickedImages = await _imageSelectionService.pickImages(
        confirmButtonText: '选择阅读背景',
        allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp', 'gif'},
        source: source,
      );
      if (pickedImages.isEmpty || !mounted) {
        return;
      }

      setState(() {
        _isSaving = true;
      });
      for (final picked in pickedImages) {
        await _service.importBackground(
          bytes: picked.bytes,
          fileName: picked.name,
        );
      }
      await _load();
      _showMessage('已添加 ${pickedImages.length} 张阅读背景');
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
    } on PlatformException catch (error) {
      _showMessage('选择阅读背景失败：${error.message ?? error.code}');
    } catch (error) {
      _showMessage('添加阅读背景失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<ImageSelectionSource?> _selectBackgroundImageSource() async {
    return _imageSelectionService.chooseImageSource(
      context,
      title: '添加阅读背景',
      gallerySubtitle: '从系统照片库选择阅读背景',
      filesSubtitle: '从文件 App 或本地目录选择阅读背景',
    );
  }

  Future<void> _confirmDeleteBackground(String path) async {
    final confirmed = await showImageResourceConfirmSurface(
      context: context,
      title: '删除阅读背景',
      message: '确定要删除这个阅读背景吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.deleteBackground(path);
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openPreview(String path) async {
    await showAdaptiveFullscreenPreview<void>(
      context: context,
      helperText: '双指缩放，拖动查看细节',
      builder: (context) {
        return LazyFileImage(path: path, fit: BoxFit.contain, cacheWidth: 1080);
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _visibleBackgroundPaths {
    final keyword = _searchQuery.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _backgroundPaths;
    }
    return _backgroundPaths
        .where((path) => p.basename(path).toLowerCase().contains(keyword))
        .toList(growable: false);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          title: const Text('阅读背景'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: '新增背景',
              onPressed: _isLoading || _isSaving ? null : _uploadBackground,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: buildAdvancedThemeBackdropDecoration(backdrop),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: AppLayout.settingsContentMaxWidth,
                ),
              ),
              child: AppAnimatedSwitcher(
                child: _buildBackgroundBody(
                  context,
                  metrics: metrics,
                  horizontal: horizontal,
                  topInset: topInset,
                  bottomSafe: bottomSafe,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundBody(
    BuildContext context, {
    required AppAdaptiveMetrics metrics,
    required double horizontal,
    required double topInset,
    required double bottomSafe,
  }) {
    if (_isLoading) {
      return const Center(
        key: ValueKey('reader_background_loading'),
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      key: const ValueKey('reader_background_content'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topInset + metrics.contentGap,
            horizontal,
            metrics.contentGap,
          ),
          child: AppFadeSlideTransition(
            child: CompactCollectionSearchField(
              controller: _searchController,
              hintText: '搜索阅读背景文件名',
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
        ),
        Expanded(
          child: AppAnimatedSwitcher(
            child:
                _visibleBackgroundPaths.isEmpty
                    ? ListView(
                      key: const ValueKey('reader_background_empty'),
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        0,
                        horizontal,
                        metrics.sectionGap + bottomSafe,
                      ),
                      children: [_buildEmptyState(context)],
                    )
                    : LayoutBuilder(
                      key: const ValueKey('reader_background_grid'),
                      builder: (context, constraints) {
                        const columns = 3;
                        return GridView.builder(
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            0,
                            horizontal,
                            metrics.sectionGap + bottomSafe,
                          ),
                          itemCount: _visibleBackgroundPaths.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: metrics.contentGap,
                                mainAxisSpacing: metrics.contentGap,
                                childAspectRatio:
                                    metrics.isCompactDensity ? 0.62 : 0.66,
                              ),
                          itemBuilder: (context, index) {
                            final path = _visibleBackgroundPaths[index];
                            return _buildBackgroundCard(context, path);
                          },
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const ImageResourceEmptyStateCard(
      icon: Icons.chrome_reader_mode_outlined,
      title: '还没有阅读背景',
      description: '点击右上角新增，准备高级主题和阅读器可复用的背景素材。',
    );
  }

  Widget _buildBackgroundCard(BuildContext context, String path) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _openPreview(path),
      onLongPress: _isSaving ? null : () => _confirmDeleteBackground(path),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: LazyFileImage(
                path: path,
                fit: BoxFit.cover,
                cacheWidth: 420,
                borderRadius: BorderRadius.circular(18),
                placeholderIcon: Icons.broken_image_outlined,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: const ImageResourceCornerHint(
                label: '长按删除',
                icon: Icons.delete_outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
