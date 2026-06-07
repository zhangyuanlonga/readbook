import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../../core/media/image_selection_service.dart';
import '../../../core/storage/managed_file_path_resolver.dart';

/// 高级主题编辑器资源解析服务。
///
/// 页面只关心“是否有可显示图片”和“如何构造 Image”，真实路径、file URI、
/// managed file 回退和本地读取集中在这里，后续迁移到 managed asset store 时
/// 不需要再改表单 UI。
class AdvancedThemeEditorResourceService {
  AdvancedThemeEditorResourceService({ManagedFilePathResolver? pathResolver})
    : _pathResolver = pathResolver ?? ManagedFilePathResolver();

  final ManagedFilePathResolver _pathResolver;

  String? resolveExistingImagePath(String? path) {
    final normalized = path?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.startsWith('assets/')) {
      return normalized;
    }
    return _pathResolver.tryResolveExistingFilePathSync(path);
  }

  List<String> existingImagePaths(Iterable<String> imagePaths) {
    final existing = <String>[];
    for (final rawPath in imagePaths) {
      final resolved = resolveExistingImagePath(rawPath);
      if (resolved != null) {
        existing.add(resolved);
      }
    }
    return existing;
  }

  ImageProvider imageProviderFor(String path) {
    final normalized = path.trim();
    if (normalized.startsWith('assets/')) {
      return AssetImage(normalized);
    }
    return FileImage(resolveLocalImageFile(normalized));
  }

  Future<PickedImageData?> pickedImageFromPath(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final file = resolveLocalImageFile(normalized);
    if (!await file.exists()) {
      return null;
    }
    return PickedImageData(
      bytes: await file.readAsBytes(),
      name: p.basename(file.path),
    );
  }

  File resolveLocalImageFile(String path) {
    final normalized = path.trim();
    if (normalized.startsWith('file://')) {
      return File(Uri.parse(normalized).toFilePath());
    }
    return File(normalized);
  }
}
