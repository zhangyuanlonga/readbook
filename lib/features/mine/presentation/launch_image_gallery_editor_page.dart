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
import '../../../domain/entities/launch_image_gallery.dart';
import '../application/launch_image_gallery_provider.dart';
import '../application/launch_image_gallery_service.dart';
import '../providers.dart';
import 'widgets/image_resource_collection_widgets.dart';

class LaunchImageGalleryEditorPage extends ConsumerStatefulWidget {
  const LaunchImageGalleryEditorPage({super.key, required this.galleryId});

  final String galleryId;

  @override
  ConsumerState<LaunchImageGalleryEditorPage> createState() =>
      _LaunchImageGalleryEditorPageState();
}

class _LaunchImageGalleryEditorPageState
    extends ConsumerState<LaunchImageGalleryEditorPage> {
  late final LaunchImageGalleryService _service;
  late final ImageSelectionService _imageSelectionService;
  final TextEditingController _nameController = TextEditingController();

  LaunchImageGallery? _gallery;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditingName = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = <String>{};

  bool get _isBuiltInGallery => _gallery?.isBuiltIn ?? false;

  String get _emptyDescription =>
      _isBuiltInGallery ? '内置启动图集随应用提供，不能编辑。' : '点击右上角新增，准备启动页和主题可复用的启动素材。';

  @override
  void initState() {
    super.initState();
    _service = ref.read(launchImageGalleryServiceProvider);
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
    if (gallery == null || !gallery.isEditable) {
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
    if (gallery == null || _isSaving || !gallery.isEditable) {
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
      ref.read(launchImageGalleryRevisionProvider.notifier).markChanged();
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
    if (gallery == null || _isSaving || !gallery.isEditable) {
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
        confirmButtonText: '选择启动图',
        allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp', 'gif'},
        source: source,
      );
      if (pickedImages.isEmpty || !mounted) {
        return;
      }
      setState(() {
        _isSaving = true;
      });
      taskId = 'launch-gallery-import:${DateTime.now().microsecondsSinceEpoch}';
      taskManager = ref.read(appTaskManagerProvider);
      taskManager!.startTask(
        id: taskId,
        status: AppTaskStatusData(
          title: '正在导入启动图集',
          message: '准备导入 ${pickedImages.length} 张启动图…',
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
            title: '正在导入启动图集',
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
      ref.read(launchImageGalleryRevisionProvider.notifier).markChanged();
      if (!mounted) {
        return;
      }
      setState(() {
        _gallery = saved;
      });
      taskManager.updateTask(
        taskId,
        AppTaskStatusData(
          title: '启动图集导入完成',
          message: '已添加 ${pickedImages.length} 张启动图。',
          kind: AppTaskStatusKind.galleryImport,
          progress: 1,
          result: AppTaskStatusResult.success,
        ),
      );
      _showMessage('已添加 ${pickedImages.length} 张启动图');
    } on ImageSelectionException catch (error) {
      if (taskId != null && taskManager != null) {
        taskManager.updateTask(
          taskId,
          AppTaskStatusData(
            title: '启动图集导入失败',
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
            title: '启动图集导入失败',
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
      title: '添加启动图',
      gallerySubtitle: '从系统照片库选择启动图片',
      filesSubtitle: '从文件 App 或本地目录选择启动图片',
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
    if (gallery == null ||
        _selectedPaths.isEmpty ||
        _isSaving ||
        !gallery.isEditable) {
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
      ref.read(launchImageGalleryRevisionProvider.notifier).markChanged();
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
    if (gallery == null || _isSaving || !gallery.isDeletable) {
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
      ref.read(launchImageGalleryRevisionProvider.notifier).markChanged();
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
        context.go('/appearance/launch-image');
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
                    onTap: _isBuiltInGallery ? null : _startEditingName,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            gallery?.name ?? '启动图集',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_isBuiltInGallery) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
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
                onPressed:
                    _isLoading || _isSaving || _isBuiltInGallery
                        ? null
                        : _pickImages,
                icon: const Icon(Icons.add_rounded),
              ),
              if (!_isBuiltInGallery)
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
                            key: ValueKey('launch_editor_loading'),
                            child: CircularProgressIndicator(),
                          )
                          : gallery == null
                          ? const Center(
                            key: ValueKey('launch_editor_missing'),
                            child: Text('图集不存在'),
                          )
                          : gallery.imagePaths.isEmpty
                          ? AppFadeSlideTransition(
                            key: const ValueKey('launch_editor_empty'),
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                horizontal,
                                metrics.contentGap,
                                horizontal,
                                metrics.sectionGap + bottomSafe,
                              ),
                              children: [
                                ImageResourceEmptyStateCard(
                                  icon: Icons.rocket_launch_outlined,
                                  title: '还没有启动图片',
                                  description: _emptyDescription,
                                ),
                              ],
                            ),
                          )
                          : LayoutBuilder(
                            key: const ValueKey('launch_editor_grid'),
                            builder: (context, constraints) {
                              final columns = metrics.gridColumnsFor(
                                availableWidth:
                                    constraints.maxWidth - horizontal * 2,
                                minItemWidth: 120,
                                maxColumns: 5,
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
                                      childAspectRatio: 0.66,
                                    ),
                                itemBuilder: (context, index) {
                                  final path = gallery.imagePaths[index];
                                  final selected = _selectedPaths.contains(
                                    path,
                                  );
                                  return GestureDetector(
                                    onLongPress:
                                        _isBuiltInGallery
                                            ? null
                                            : () => _toggleSelection(path),
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
