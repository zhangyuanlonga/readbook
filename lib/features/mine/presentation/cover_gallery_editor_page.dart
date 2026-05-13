import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/platform/app_input_focus_behavior.dart';
import '../../../app/tasks/app_task_manager.dart';
import '../../../app/widgets/app_task_status.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../application/cover_gallery_provider.dart';
import '../application/cover_gallery_service.dart';
import '../providers.dart';
import 'widgets/image_resource_collection_widgets.dart';

class CoverGalleryEditorPage extends ConsumerStatefulWidget {
  const CoverGalleryEditorPage({super.key, required this.galleryId});

  final String galleryId;

  @override
  ConsumerState<CoverGalleryEditorPage> createState() =>
      _CoverGalleryEditorPageState();
}

class _CoverGalleryEditorPageState
    extends ConsumerState<CoverGalleryEditorPage> {
  late final CoverGalleryService _service;
  late final ImageSelectionService _imageSelectionService;
  final TextEditingController _nameController = TextEditingController();

  CoverGallery? _gallery;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditingName = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = <String>{};

  @override
  void initState() {
    super.initState();
    _service = ref.read(coverGalleryServiceProvider);
    _imageSelectionService = ref.read(mineImageSelectionServiceProvider);
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gallery = await _service.loadGallery(widget.galleryId);
    if (!mounted) {
      return;
    }
    setState(() {
      _gallery = gallery;
      _isLoading = false;
    });
  }

  void _startEditingName() {
    final gallery = _gallery;
    if (gallery == null) {
      return;
    }
    _nameController.text = gallery.name;
    _nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: gallery.name.length,
    );
    setState(() {
      _isEditingName = true;
    });
  }

  Future<void> _saveName() async {
    final gallery = _gallery;
    if (gallery == null || _isSaving) {
      return;
    }
    final nextName = _nameController.text.trim();
    if (nextName.isEmpty) {
      _showMessage('图集名称不能为空');
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.renameGallery(galleryId: gallery.id, name: nextName);
      if (!mounted) {
        return;
      }
      setState(() {
        _gallery = gallery.copyWith(
          name: nextName,
          updatedAt: DateTime.now().toUtc(),
        );
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

  Future<void> _pickImages() async {
    final gallery = _gallery;
    if (gallery == null || _isSaving) {
      return;
    }
    String? taskId;
    AppTaskManager? taskManager;
    try {
      final source = await _selectImageSource();
      if (source == null || !mounted) {
        return;
      }
      final pickedImages = await _imageSelectionService.pickImages(
        confirmButtonText: '选择封面',
        allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp', 'gif'},
        source: source,
      );
      if (pickedImages.isEmpty || !mounted) {
        return;
      }
      setState(() {
        _isSaving = true;
      });
      taskId = 'cover-gallery-import:${DateTime.now().microsecondsSinceEpoch}';
      taskManager = ref.read(appTaskManagerProvider);
      taskManager!.startTask(
        id: taskId,
        status: AppTaskStatusData(
          title: '正在导入封面图集',
          message: '准备导入 ${pickedImages.length} 张封面…',
          kind: AppTaskStatusKind.galleryImport,
        ),
        channel: AppTaskChannel.resourceImport,
        priority: AppTaskPriority.userInitiated,
      );
      var saved = gallery;
      for (var index = 0; index < pickedImages.length; index += 1) {
        final picked = pickedImages[index];
        taskManager.updateTask(
          taskId,
          AppTaskStatusData(
            title: '正在导入封面图集',
            message: '正在导入 ${index + 1}/${pickedImages.length}：${picked.name}',
            kind: AppTaskStatusKind.galleryImport,
            progress: (index + 1) / pickedImages.length,
          ),
        );
        saved = await _service.importImage(
          galleryId: gallery.id,
          bytes: picked.bytes,
          fileName: picked.name,
        );
      }
      ref.read(coverGalleryRevisionProvider.notifier).markChanged();
      if (!mounted) {
        return;
      }
      setState(() {
        _gallery = saved;
      });
      taskManager.updateTask(
        taskId,
        AppTaskStatusData(
          title: '封面图集导入完成',
          message: '已添加 ${pickedImages.length} 张封面。',
          kind: AppTaskStatusKind.galleryImport,
          progress: 1,
          result: AppTaskStatusResult.success,
        ),
      );
      _showMessage('已添加 ${pickedImages.length} 张封面');
    } on ImageSelectionException catch (error) {
      if (taskId != null && taskManager != null) {
        taskManager.updateTask(
          taskId,
          AppTaskStatusData(
            title: '封面图集导入失败',
            message: error.message,
            kind: AppTaskStatusKind.galleryImport,
            result: AppTaskStatusResult.failure,
          ),
        );
      }
      _showMessage(error.message);
    } catch (error) {
      if (taskId != null && taskManager != null) {
        taskManager.updateTask(
          taskId,
          AppTaskStatusData(
            title: '封面图集导入失败',
            message: '$error',
            kind: AppTaskStatusKind.galleryImport,
            result: AppTaskStatusResult.failure,
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<ImageSelectionSource?> _selectImageSource() async {
    return _imageSelectionService.chooseImageSource(
      context,
      title: '添加封面',
      gallerySubtitle: '从系统照片库选择封面图片',
      filesSubtitle: '从文件 App 或本地目录选择封面图片',
    );
  }

  void _toggleSelection(String path) {
    setState(() {
      _isSelectionMode = true;
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
      if (_selectedPaths.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  Future<void> _deleteSelectedImages() async {
    final gallery = _gallery;
    if (gallery == null || _selectedPaths.isEmpty || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final saved = await _service.deleteImages(
        galleryId: gallery.id,
        paths: _selectedPaths.toList(growable: false),
      );
      ref.read(coverGalleryRevisionProvider.notifier).markChanged();
      if (!mounted) {
        return;
      }
      setState(() {
        _gallery = saved;
        _selectedPaths.clear();
        _isSelectionMode = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteGallery() async {
    final gallery = _gallery;
    if (gallery == null || _isSaving) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除图集'),
          content: Text('确定删除「${gallery.name}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.deleteGallery(gallery.id);
      if (!mounted) {
        return;
      }
      context.pop('图集已删除');
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
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: LazyFileImage(
                          path: path,
                          fit: BoxFit.contain,
                          cacheWidth: 1080,
                        ),
                      ),
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final gallery = _gallery;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/cover-galleries');
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading:
              _isSelectionMode
                  ? IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedPaths.clear();
                        _isSelectionMode = false;
                      });
                    },
                    icon: const Icon(Icons.close),
                  )
                  : null,
          title:
              _isSelectionMode
                  ? Text('已选择 ${_selectedPaths.length} 项')
                  : _isEditingName
                  ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: TextField(
                      controller: _nameController,
                      autofocus: appEnableAutoFocusForTextInput,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
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
                        Flexible(
                          child: Text(
                            gallery?.name ?? '封面图集',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
            if (_isSelectionMode)
              IconButton(
                onPressed:
                    _selectedPaths.isEmpty || _isSaving
                        ? null
                        : _deleteSelectedImages,
                icon: const Icon(Icons.delete_outline),
              )
            else ...[
              if (_isEditingName)
                IconButton(
                  onPressed: _saveName,
                  icon: const Icon(Icons.check_rounded),
                ),
              IconButton(
                onPressed: _isLoading || _isSaving ? null : _pickImages,
                icon: const Icon(Icons.add_rounded),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteGallery();
                  }
                },
                itemBuilder:
                    (context) => const [
                      PopupMenuItem(value: 'delete', child: Text('删除图集')),
                    ],
              ),
            ],
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
                child: AppAnimatedSwitcher(
                  child:
                      _isLoading
                          ? const Center(
                            key: ValueKey('cover_editor_loading'),
                            child: CircularProgressIndicator(),
                          )
                          : gallery == null
                          ? const Center(
                            key: ValueKey('cover_editor_missing'),
                            child: Text('图集不存在'),
                          )
                          : gallery.imagePaths.isEmpty
                          ? AppFadeSlideTransition(
                            key: const ValueKey('cover_editor_empty'),
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                horizontal,
                                metrics.contentGap,
                                horizontal,
                                metrics.sectionGap + bottomSafe,
                              ),
                              children: const [
                                ImageResourceEmptyStateCard(
                                  icon: Icons.photo_library_outlined,
                                  title: '还没有封面图片',
                                  description: '点击右上角新增，准备书架和主题可复用的封面素材。',
                                ),
                              ],
                            ),
                          )
                          : LayoutBuilder(
                            key: const ValueKey('cover_editor_grid'),
                            builder: (context, constraints) {
                              final columns = metrics.gridColumnsFor(
                                availableWidth:
                                    constraints.maxWidth - horizontal * 2,
                                minItemWidth: 118,
                                maxColumns: 6,
                                spacing: metrics.contentGap,
                              );
                              return GridView.builder(
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: true,
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  metrics.contentGap,
                                  horizontal,
                                  metrics.sectionGap + bottomSafe,
                                ),
                                itemCount: gallery.imagePaths.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: metrics.contentGap,
                                      mainAxisSpacing: metrics.contentGap,
                                      childAspectRatio: 0.72,
                                    ),
                                itemBuilder: (context, index) {
                                  final path = gallery.imagePaths[index];
                                  final selected = _selectedPaths.contains(
                                    path,
                                  );
                                  return GestureDetector(
                                    onLongPress: () => _toggleSelection(path),
                                    onTap:
                                        _isSelectionMode
                                            ? () => _toggleSelection(path)
                                            : () => _openPreview(path),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: LazyFileImage(
                                            path: path,
                                            fit: BoxFit.cover,
                                            cacheWidth: 360,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            placeholderIcon:
                                                Icons.broken_image_outlined,
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child:
                                              selected
                                                  ? const ImageResourceSelectionBadge()
                                                  : _isSelectionMode
                                                  ? const SizedBox.shrink()
                                                  : const ImageResourceCornerHint(
                                                    label: '长按删除',
                                                    icon: Icons.delete_outline,
                                                  ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
