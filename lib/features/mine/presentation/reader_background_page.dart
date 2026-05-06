import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
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
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return ImageSelectionSource.files;
    }

    return showModalBottomSheet<ImageSelectionSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('相册'),
                  subtitle: const Text('从系统照片库选择一张图片'),
                  onTap:
                      () => Navigator.of(
                        context,
                      ).pop(ImageSelectionSource.gallery),
                ),
                ListTile(
                  leading: Icon(
                    Icons.folder_open_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('文件'),
                  subtitle: const Text('从文件 App 或本地目录选择图片'),
                  onTap:
                      () =>
                          Navigator.of(context).pop(ImageSelectionSource.files),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteBackground(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除阅读背景'),
            content: const Text('确定要删除这个阅读背景吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
    if (confirmed != true) {
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
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Image.file(File(path), fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
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
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              topInset + 12,
                              horizontal,
                              10,
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search_rounded),
                                hintText: '搜索阅读背景文件名',
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
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                              ),
                            ),
                          ),
                          Expanded(
                            child:
                                _visibleBackgroundPaths.isEmpty
                                    ? ListView(
                                      padding: EdgeInsets.fromLTRB(
                                        horizontal,
                                        0,
                                        horizontal,
                                        16 + bottomSafe,
                                      ),
                                      children: [_buildEmptyState(context)],
                                    )
                                    : GridView.builder(
                                      padding: EdgeInsets.fromLTRB(
                                        horizontal,
                                        0,
                                        horizontal,
                                        16 + bottomSafe,
                                      ),
                                      itemCount: _visibleBackgroundPaths.length,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            crossAxisSpacing: 10,
                                            mainAxisSpacing: 10,
                                            childAspectRatio: 0.78,
                                          ),
                                      itemBuilder: (context, index) {
                                        final path =
                                            _visibleBackgroundPaths[index];
                                        return _buildBackgroundCard(
                                          context,
                                          path,
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => ColoredBox(
                        color: colorScheme.surfaceContainerLow,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                ),
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
