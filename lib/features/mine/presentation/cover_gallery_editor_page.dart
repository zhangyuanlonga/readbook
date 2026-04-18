import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/platform/app_input_focus_behavior.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../application/cover_gallery_service.dart';

class CoverGalleryEditorPage extends StatefulWidget {
  const CoverGalleryEditorPage({super.key, required this.galleryId});

  final String galleryId;

  @override
  State<CoverGalleryEditorPage> createState() => _CoverGalleryEditorPageState();
}

class _CoverGalleryEditorPageState extends State<CoverGalleryEditorPage> {
  final CoverGalleryService _service = CoverGalleryService();
  final ImageSelectionService _imageSelectionService = ImageSelectionService();
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
    try {
      final source = await _selectImageSource();
      if (source == null || !mounted) {
        return;
      }
      final picked = await _imageSelectionService.pickImage(
        confirmButtonText: '选择封面',
        allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp'},
        source: source,
      );
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _isSaving = true;
      });
      final saved = await _service.importImage(
        galleryId: gallery.id,
        bytes: picked.bytes,
        fileName: picked.name,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _gallery = saved;
      });
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<ImageSelectionSource?> _selectImageSource() async {
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
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
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : gallery == null
                        ? const Center(child: Text('图集不存在'))
                        : GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            12,
                            horizontal,
                            16 + bottomSafe,
                          ),
                          itemCount: gallery.imagePaths.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.72,
                              ),
                          itemBuilder: (context, index) {
                            final path = gallery.imagePaths[index];
                            final selected = _selectedPaths.contains(path);
                            return GestureDetector(
                              onLongPress: () => _toggleSelection(path),
                              onTap:
                                  _isSelectionMode
                                      ? () => _toggleSelection(path)
                                      : () => _openPreview(path),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(path),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) => Container(
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerLow,
                                            ),
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
            );
          },
        ),
      ),
    );
  }
}
