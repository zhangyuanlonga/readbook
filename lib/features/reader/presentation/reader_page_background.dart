part of 'reader_page.dart';

class _ReaderBackgroundAssetStore {
  final Map<String, Uint8List> presetBytes = <String, Uint8List>{};
  final Map<String, String> presetBase64 = <String, String>{};
  final Map<String, Uint8List> customPreviewBytes = <String, Uint8List>{};
  final List<_ReaderBackgroundPreset> presets = <_ReaderBackgroundPreset>[];
  String? cachedBackgroundImageKey;
  MemoryImage? cachedBackgroundImage;
}

extension _ReaderPageBackgroundAssetAccessors on _ReaderPageState {
  Map<String, Uint8List> get _backgroundPresetBytes =>
      _backgroundAssets.presetBytes;

  Map<String, String> get _backgroundPresetBase64 =>
      _backgroundAssets.presetBase64;

  Map<String, Uint8List> get _customBackgroundPreviewBytes =>
      _backgroundAssets.customPreviewBytes;

  List<_ReaderBackgroundPreset> get _backgroundPresets =>
      _backgroundAssets.presets;

  String? get _cachedBackgroundImageKey =>
      _backgroundAssets.cachedBackgroundImageKey;

  set _cachedBackgroundImageKey(String? value) {
    _backgroundAssets.cachedBackgroundImageKey = value;
  }

  MemoryImage? get _cachedBackgroundImage =>
      _backgroundAssets.cachedBackgroundImage;

  set _cachedBackgroundImage(MemoryImage? value) {
    _backgroundAssets.cachedBackgroundImage = value;
  }
}

extension _ReaderPageBackgroundExtension on _ReaderPageState {
  Decoration _buildReaderBackgroundDecorationImpl(_ReaderThemeColors colors) {
    final resolvedBackground = _resolveReaderBackgroundVisualImpl();
    final (backgroundColor, surfaceColor) = switch (_settings.backgroundStyle) {
      ReaderBackgroundStyle.plain => (colors.background, colors.background),
      ReaderBackgroundStyle.paper => (
        _shiftLightness(colors.background, 0.03),
        _shiftLightness(colors.background, -0.02),
      ),
      ReaderBackgroundStyle.warm => (
        _shiftLightness(colors.background, 0.03),
        _shiftLightness(colors.background, -0.02),
      ),
    };
    return buildImageBackdropDecoration(
      backgroundColor: backgroundColor,
      surfaceColor: surfaceColor,
      imageProvider: resolvedBackground?.imageProvider,
      imageOpacity: resolvedBackground?.opacity ?? 1,
      imageBlurSigma: resolvedBackground?.blurSigma ?? 0,
      imageFit: resolvedBackground?.fit ?? BoxFit.cover,
      overlayColor: colors.background,
      overlayOpacity: resolvedBackground?.overlayOpacity ?? 0,
    );
  }

  _ResolvedReaderBackgroundVisual? _resolveReaderBackgroundVisualImpl() {
    final raw = _effectiveReaderBackgroundPath();
    if (raw == null || raw.isEmpty) {
      _cachedBackgroundImageKey = null;
      _cachedBackgroundImage = null;
      return null;
    }
    final themeModeConfig = _effectiveReaderBackgroundThemeConfig();
    final fit = switch (themeModeConfig?.readerWallpaperFit) {
      AppAdvancedThemeWallpaperFit.fill => BoxFit.fill,
      AppAdvancedThemeWallpaperFit.cover || null => BoxFit.cover,
    };
    final opacity = (themeModeConfig?.readerWallpaperOpacity ?? 1).clamp(
      0.0,
      1.0,
    );
    final blurSigma = (themeModeConfig?.readerWallpaperBlurSigma ?? 0).clamp(
      0.0,
      24.0,
    );
    final overlayOpacity = (themeModeConfig?.readerWallpaperOverlayOpacity ?? 0)
        .clamp(0.0, 1.0);

    if (_isPresetBackgroundAssetPathImpl(raw)) {
      _cachedBackgroundImageKey = null;
      _cachedBackgroundImage = null;
      return _ResolvedReaderBackgroundVisual(
        imageProvider: AssetImage(raw),
        fit: fit,
        opacity: opacity,
        blurSigma: blurSigma,
        overlayOpacity: overlayOpacity,
      );
    }

    if (_isManagedBackgroundPathImpl(raw)) {
      final file =
          raw.startsWith('file://')
              ? File(Uri.parse(raw).toFilePath())
              : File(raw);
      if (!file.existsSync()) {
        _cachedBackgroundImageKey = null;
        _cachedBackgroundImage = null;
        return null;
      }
      return _ResolvedReaderBackgroundVisual(
        imageProvider: FileImage(file),
        fit: fit,
        opacity: opacity,
        blurSigma: blurSigma,
        overlayOpacity: overlayOpacity,
      );
    }

    if (_cachedBackgroundImageKey != raw || _cachedBackgroundImage == null) {
      final bytes = _tryDecodeBase64Impl(raw);
      if (bytes == null) {
        _cachedBackgroundImageKey = null;
        _cachedBackgroundImage = null;
        return null;
      }
      _cachedBackgroundImageKey = raw;
      _cachedBackgroundImage = MemoryImage(bytes);
    }

    return _ResolvedReaderBackgroundVisual(
      imageProvider: _cachedBackgroundImage!,
      fit: fit,
      opacity: opacity,
      blurSigma: blurSigma,
      overlayOpacity: overlayOpacity,
    );
  }

  Uint8List? _tryDecodeBase64Impl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    try {
      final bytes = base64Decode(normalized);
      if (bytes.isEmpty) {
        return null;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  bool _isManagedBackgroundPathImpl(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.startsWith('/') || normalized.startsWith('file://');
  }

  bool _isPresetBackgroundValueImpl(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return _isPresetBackgroundAssetPathImpl(normalized) ||
        _backgroundPresetBytes.containsKey(normalized) ||
        _backgroundPresetBase64.values.contains(normalized);
  }

  bool _isPresetBackgroundAssetPathImpl(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    if (_ReaderPageState._kFallbackBackgroundPresetPaths.contains(normalized)) {
      return true;
    }
    for (final preset in _backgroundPresets) {
      if (preset.assetPath == normalized) {
        return true;
      }
    }
    return normalized.startsWith('assets/reader/backgrounds/');
  }

  Future<void> _preloadCustomBackgroundPreviewsImpl(
    List<String> sources,
  ) async {
    final normalizedSources =
        sources
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toSet();
    _customBackgroundPreviewBytes.removeWhere(
      (key, _) => !normalizedSources.contains(key),
    );

    for (final source in normalizedSources) {
      if (_customBackgroundPreviewBytes.containsKey(source)) {
        continue;
      }
      final preview = await _loadBackgroundPreviewBytesImpl(source);
      if (preview != null) {
        _customBackgroundPreviewBytes[source] = preview;
      }
    }
  }

  Future<Uint8List?> _loadBackgroundPreviewBytesImpl(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (_isManagedBackgroundPathImpl(normalized)) {
      try {
        final file =
            normalized.startsWith('file://')
                ? File(Uri.parse(normalized).toFilePath())
                : File(normalized);
        if (!await file.exists()) {
          return null;
        }
        final bytes = await file.readAsBytes();
        return _resizeImageBytesImpl(
          bytes,
          maxDimension: _ReaderPageState._kCustomBackgroundPreviewMaxDimension,
          quality: 72,
        );
      } catch (_) {
        return null;
      }
    }
    return _tryDecodeBase64Impl(normalized);
  }

  Uint8List? _resizeImageBytesImpl(
    Uint8List bytes, {
    required int maxDimension,
    required int quality,
  }) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return bytes;
      }
      img.Image processed = decoded;
      final width = decoded.width;
      final height = decoded.height;
      final longestSide = width > height ? width : height;
      if (longestSide > maxDimension) {
        if (width >= height) {
          processed = img.copyResize(decoded, width: maxDimension);
        } else {
          processed = img.copyResize(decoded, height: maxDimension);
        }
      }
      return Uint8List.fromList(
        img.encodeJpg(processed, quality: quality.clamp(1, 100)),
      );
    } catch (_) {
      return bytes;
    }
  }

  Future<String?> _storeCustomBackgroundImageImpl(Uint8List bytes) async {
    final storedBytes = _resizeImageBytesImpl(
      bytes,
      maxDimension: _ReaderPageState._kCustomBackgroundStoreMaxDimension,
      quality: _ReaderPageState._kCustomBackgroundStoreQuality,
    );
    if (storedBytes == null || storedBytes.isEmpty) {
      return null;
    }
    final filePath = await _readerBackgroundService.importBackground(
      bytes: storedBytes,
      fileName: 'bg_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.jpg',
    );
    _customBackgroundPreviewBytes[filePath] =
        _resizeImageBytesImpl(
          storedBytes,
          maxDimension: _ReaderPageState._kCustomBackgroundPreviewMaxDimension,
          quality: 72,
        ) ??
        storedBytes;
    return filePath;
  }

  Future<void> _deleteManagedBackgroundFileIfNeededImpl(String source) async {
    final normalized = source.trim();
    if (!_isManagedBackgroundPathImpl(normalized)) {
      return;
    }
    try {
      final resolved =
          normalized.startsWith('file://')
              ? Uri.parse(normalized).toFilePath()
              : normalized;
      await _readerBackgroundService.deleteBackground(resolved);
    } catch (_) {
      // ignore cleanup failure
    } finally {
      _customBackgroundPreviewBytes.remove(normalized);
    }
  }

  Future<List<String>> _loadUnifiedCustomBackgroundsImpl() async {
    final stored = await _preferencesService.loadCustomBackgroundImages();
    final managed = await _readerBackgroundService.loadBackgroundPaths();
    final merged = <String>[];
    for (final path in [...managed, ...stored]) {
      final normalized = path.trim();
      if (normalized.isEmpty || merged.contains(normalized)) {
        continue;
      }
      merged.add(normalized);
    }
    return merged;
  }

  Future<void> _refreshSharedReaderAssetsImpl({
    void Function(VoidCallback fn)? updateModalState,
  }) async {
    final fonts = await _fontRegistryService.listRegisteredFonts();
    final backgrounds = await _loadUnifiedCustomBackgroundsImpl();
    if (!mounted) {
      return;
    }
    _updateReaderState(() {
      _customFonts = fonts;
      _customBackgroundImages = backgrounds;
    });
    updateModalState?.call(() {
      _customFonts = fonts;
      _customBackgroundImages = backgrounds;
    });
    unawaited(_preloadCustomBackgroundPreviewsImpl(backgrounds));
    await _preferencesService.saveCustomBackgroundImages(backgrounds);
  }

  Future<void> _ensureBackgroundPresetsReadyImpl() async {
    if (_backgroundPresets.isEmpty) {
      final discoveredPaths = await _loadBackgroundPresetAssetPathsImpl();
      final presetPaths = <String>[];

      void addPresetPath(String path) {
        final normalized = path.trim();
        if (normalized.isEmpty) {
          return;
        }
        if (!presetPaths.contains(normalized)) {
          presetPaths.add(normalized);
        }
      }

      for (final fallbackPath
          in _ReaderPageState._kFallbackBackgroundPresetPaths) {
        addPresetPath(fallbackPath);
      }
      for (final discoveredPath in discoveredPaths) {
        addPresetPath(discoveredPath);
      }

      for (var index = 0; index < presetPaths.length; index += 1) {
        _backgroundPresets.add(
          _ReaderBackgroundPreset(
            label: '预设${index + 1}',
            assetPath: presetPaths[index],
          ),
        );
      }
    }

    for (final preset in _backgroundPresets) {
      final path = preset.assetPath;
      if (_backgroundPresetBytes.containsKey(path) &&
          _backgroundPresetBase64.containsKey(path)) {
        continue;
      }
      try {
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List();
        if (bytes.isEmpty) {
          continue;
        }
        _backgroundPresetBytes[path] = bytes;
        _backgroundPresetBase64[path] = base64Encode(bytes);
      } catch (error) {
        debugPrint('Load reader preset background failed: $path, $error');
      }
    }
  }

  Future<List<String>> _loadBackgroundPresetAssetPathsImpl() async {
    List<String> filterBackgroundPaths(Iterable<String> candidates) {
      final filtered = candidates
          .where((path) => path.startsWith('assets/reader/backgrounds/'))
          .where((path) {
            final lowerPath = path.toLowerCase();
            return lowerPath.endsWith('.jpg') ||
                lowerPath.endsWith('.jpeg') ||
                lowerPath.endsWith('.png') ||
                lowerPath.endsWith('.webp');
          })
          .toList(growable: false);
      filtered.sort();
      return filtered;
    }

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final discovered = filterBackgroundPaths(manifest.listAssets());
      if (discovered.isNotEmpty) {
        return discovered;
      }
    } catch (_) {
      // Keep backward compatibility with runtimes that only expose JSON manifest.
    }

    try {
      final rawManifest = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(rawManifest);
      if (decoded is! Map<String, dynamic>) {
        return const <String>[];
      }
      return filterBackgroundPaths(decoded.keys);
    } catch (_) {
      return const <String>[];
    }
  }
}
