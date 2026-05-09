import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as ip;

enum ImageSelectionSource { auto, gallery, files }

class PickedImageData {
  const PickedImageData({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

class ImageSelectionException implements Exception {
  const ImageSelectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImageSelectionService {
  ImageSelectionService({ip.ImagePicker? mobilePicker})
    : _mobilePicker = mobilePicker ?? ip.ImagePicker();

  final ip.ImagePicker _mobilePicker;

  Future<ImageSelectionSource?> chooseImageSource(
    BuildContext context, {
    required String title,
    String gallerySubtitle = '从系统照片库选择图片',
    String filesSubtitle = '从文件 App 或本地目录选择图片',
    bool useRootNavigator = false,
  }) {
    return showModalBottomSheet<ImageSelectionSource>(
      context: context,
      useRootNavigator: useRootNavigator,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final bottomInset = _bottomSafeInset(context);
        return SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 12 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('相册'),
                  subtitle: Text(gallerySubtitle),
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
                  subtitle: Text(filesSubtitle),
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

  Future<List<PickedImageData>> pickImages({
    required String confirmButtonText,
    Set<String> allowedExtensions = const {'jpg', 'jpeg', 'png', 'webp'},
    ImageSelectionSource source = ImageSelectionSource.auto,
  }) async {
    final normalizedExtensions = _normalizeExtensions(allowedExtensions);
    if (normalizedExtensions.isEmpty) {
      throw const ImageSelectionException('未配置可选图片格式。');
    }

    return switch (source) {
      ImageSelectionSource.gallery => _pickMultipleWithSystemPicker(
        confirmButtonText: confirmButtonText,
        allowedExtensions: normalizedExtensions,
      ),
      ImageSelectionSource.files => _pickMultipleWithFileSelector(
        confirmButtonText: confirmButtonText,
        allowedExtensions: normalizedExtensions,
      ),
      ImageSelectionSource.auto =>
        kIsWeb || _usesDesktopFileSelector(defaultTargetPlatform)
            ? _pickMultipleWithFileSelector(
              confirmButtonText: confirmButtonText,
              allowedExtensions: normalizedExtensions,
            )
            : _pickMultipleWithSystemPicker(
              confirmButtonText: confirmButtonText,
              allowedExtensions: normalizedExtensions,
            ),
    };
  }

  Future<PickedImageData?> pickImage({
    required String confirmButtonText,
    Set<String> allowedExtensions = const {'jpg', 'jpeg', 'png', 'webp'},
    ImageSelectionSource source = ImageSelectionSource.auto,
  }) async {
    final normalizedExtensions = _normalizeExtensions(allowedExtensions);
    if (normalizedExtensions.isEmpty) {
      throw const ImageSelectionException('未配置可选图片格式。');
    }

    return switch (source) {
      ImageSelectionSource.gallery => _pickWithSystemPicker(
        confirmButtonText: confirmButtonText,
        allowedExtensions: normalizedExtensions,
      ),
      ImageSelectionSource.files => _pickWithFileSelector(
        confirmButtonText: confirmButtonText,
        allowedExtensions: normalizedExtensions,
      ),
      ImageSelectionSource.auto =>
        kIsWeb || _usesDesktopFileSelector(defaultTargetPlatform)
            ? _pickWithFileSelector(
              confirmButtonText: confirmButtonText,
              allowedExtensions: normalizedExtensions,
            )
            : _pickWithSystemPicker(
              confirmButtonText: confirmButtonText,
              allowedExtensions: normalizedExtensions,
            ),
    };
  }

  bool _usesDesktopFileSelector(TargetPlatform platform) {
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
  }

  Future<PickedImageData?> _pickWithSystemPicker({
    required String confirmButtonText,
    required Set<String> allowedExtensions,
  }) async {
    if (kIsWeb || _usesDesktopFileSelector(defaultTargetPlatform)) {
      return _pickWithFileSelector(
        confirmButtonText: confirmButtonText,
        allowedExtensions: allowedExtensions,
      );
    }
    final picked = await _mobilePicker.pickImage(
      source: ip.ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (picked == null) {
      return null;
    }

    return _toPickedImageData(
      bytes: await picked.readAsBytes(),
      fileName: picked.name,
      allowedExtensions: allowedExtensions,
    );
  }

  Future<PickedImageData?> _pickWithFileSelector({
    required String confirmButtonText,
    required Set<String> allowedExtensions,
  }) async {
    final picked = await fs.openFile(
      acceptedTypeGroups: [_buildTypeGroup(allowedExtensions)],
      confirmButtonText: confirmButtonText,
    );
    if (picked == null) {
      return null;
    }

    return _toPickedImageData(
      bytes: await picked.readAsBytes(),
      fileName: picked.name,
      allowedExtensions: allowedExtensions,
    );
  }

  Future<List<PickedImageData>> _pickMultipleWithSystemPicker({
    required String confirmButtonText,
    required Set<String> allowedExtensions,
  }) async {
    if (kIsWeb || _usesDesktopFileSelector(defaultTargetPlatform)) {
      return _pickMultipleWithFileSelector(
        confirmButtonText: confirmButtonText,
        allowedExtensions: allowedExtensions,
      );
    }
    final picked = await _mobilePicker.pickMultiImage(
      requestFullMetadata: false,
    );
    if (picked.isEmpty) {
      return const <PickedImageData>[];
    }

    final results = <PickedImageData>[];
    for (final item in picked) {
      results.add(
        _toPickedImageData(
          bytes: await item.readAsBytes(),
          fileName: item.name,
          allowedExtensions: allowedExtensions,
        ),
      );
    }
    return results;
  }

  Future<List<PickedImageData>> _pickMultipleWithFileSelector({
    required String confirmButtonText,
    required Set<String> allowedExtensions,
  }) async {
    final picked = await fs.openFiles(
      acceptedTypeGroups: <fs.XTypeGroup>[_buildTypeGroup(allowedExtensions)],
      confirmButtonText: confirmButtonText,
    );
    if (picked.isEmpty) {
      return const <PickedImageData>[];
    }

    final results = <PickedImageData>[];
    for (final item in picked) {
      results.add(
        _toPickedImageData(
          bytes: await item.readAsBytes(),
          fileName: item.name,
          allowedExtensions: allowedExtensions,
        ),
      );
    }
    return results;
  }

  PickedImageData _toPickedImageData({
    required Uint8List bytes,
    required String fileName,
    required Set<String> allowedExtensions,
  }) {
    if (bytes.isEmpty) {
      throw const ImageSelectionException('图片读取失败，请重新选择。');
    }

    final normalizedFileName = fileName.trim();
    if (normalizedFileName.isEmpty) {
      throw const ImageSelectionException('图片文件名无效，请重新选择。');
    }

    final extension = _extractExtension(normalizedFileName);
    if (!allowedExtensions.contains(extension)) {
      final labels = allowedExtensions
          .map((item) => '.${item.toUpperCase()}')
          .join(' / ');
      throw ImageSelectionException('仅支持 $labels 图片。');
    }

    return PickedImageData(bytes: bytes, name: normalizedFileName);
  }

  fs.XTypeGroup _buildTypeGroup(Set<String> allowedExtensions) {
    final extensions = allowedExtensions.toList(growable: false);
    final mimeTypes = <String>[];
    final utis = <String>[];

    if (allowedExtensions.contains('jpg') ||
        allowedExtensions.contains('jpeg')) {
      mimeTypes.add('image/jpeg');
      utis.add('public.jpeg');
    }
    if (allowedExtensions.contains('png')) {
      mimeTypes.add('image/png');
      utis.add('public.png');
    }
    if (allowedExtensions.contains('webp')) {
      mimeTypes.add('image/webp');
      utis.add('org.webmproject.webp');
    }
    if (allowedExtensions.contains('gif')) {
      mimeTypes.add('image/gif');
      utis.add('com.compuserve.gif');
    }
    if (allowedExtensions.contains('svg')) {
      mimeTypes.add('image/svg+xml');
      utis.add('public.svg-image');
    }

    return fs.XTypeGroup(
      label: 'images',
      extensions: extensions,
      mimeTypes: mimeTypes.isEmpty ? null : mimeTypes,
      uniformTypeIdentifiers: utis.isEmpty ? null : utis,
    );
  }

  Set<String> _normalizeExtensions(Set<String> extensions) {
    return extensions
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  String _extractExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex >= fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).trim().toLowerCase();
  }

  double _bottomSafeInset(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context).bottom;
    return viewPadding > gestureInsets ? viewPadding : gestureInsets;
  }
}
