import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/navigation/bottom_nav_icon_gallery_service.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../app/widgets/text_cover_placeholder.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../application/advanced_theme_service.dart';
import '../application/cover_gallery_service.dart';

class AdvancedThemeEditorPage extends ConsumerStatefulWidget {
  const AdvancedThemeEditorPage({super.key, this.themeId});

  final String? themeId;

  @override
  ConsumerState<AdvancedThemeEditorPage> createState() =>
      _AdvancedThemeEditorPageState();
}

class _AdvancedThemeEditorPageState
    extends ConsumerState<AdvancedThemeEditorPage>
    with SingleTickerProviderStateMixin {
  final AdvancedThemeService _service = AdvancedThemeService();
  final BottomNavIconGalleryService _bottomNavIconGalleryService =
      BottomNavIconGalleryService();
  final CoverGalleryService _coverGalleryService = CoverGalleryService();
  final TextEditingController _nameController = TextEditingController();
  late final TabController _modeTabController = TabController(
    length: AppAdvancedThemeMode.values.length,
    vsync: this,
  )..addListener(_handleModeTabChanged);
  late final Map<
    AppAdvancedThemeMode,
    Map<_ThemeColorSlot, TextEditingController>
  >
  _colorControllersByMode = {
    for (final mode in AppAdvancedThemeMode.values)
      mode: {
        for (final slot in _ThemeColorSlot.values)
          slot: TextEditingController(),
      },
  };

  AppAdvancedTheme? _draft;
  AppAdvancedThemeMode _selectedMode = AppAdvancedThemeMode.light;
  List<String> _backgroundLibraryPaths = const <String>[];
  List<BottomNavIconGallery> _bottomNavGalleries =
      const <BottomNavIconGallery>[];
  List<CoverGallery> _coverGalleries = const <CoverGallery>[];
  String? _activeBottomNavGalleryName;
  bool _isEditingName = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _didInitialize = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    unawaited(_initializeDraft());
    unawaited(_loadAppearanceLinks());
  }

  @override
  void dispose() {
    _modeTabController.removeListener(_handleModeTabChanged);
    _modeTabController.dispose();
    _nameController.dispose();
    for (final controllers in _colorControllersByMode.values) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _handleModeTabChanged() {
    if (_modeTabController.indexIsChanging) {
      return;
    }
    final nextMode = AppAdvancedThemeMode.values[_modeTabController.index];
    if (nextMode == _selectedMode) {
      return;
    }
    setState(() {
      _selectedMode = nextMode;
    });
  }

  Future<void> _initializeDraft() async {
    final themeId = widget.themeId?.trim() ?? '';
    if (themeId.isEmpty) {
      final seedColor = ref.read(appSeedColorProvider);
      final now = DateTime.now().toUtc();
      final draft = AppAdvancedTheme(
        id: _service.createThemeId(),
        name: '未命名主题',
        createdAt: now,
        updatedAt: now,
        lightConfig: _modeConfigFromScheme(buildAppLightColorScheme(seedColor)),
        darkConfig: _modeConfigFromScheme(buildAppDarkColorScheme(seedColor)),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = draft;
        _isLoading = false;
      });
      _syncControllersFromDraft(draft);
      return;
    }

    final themes = await _service.loadThemes();
    AppAdvancedTheme? target;
    for (final theme in themes) {
      if (theme.id == themeId) {
        target = theme;
        break;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _draft = target;
      _isLoading = false;
    });
    if (target != null) {
      _syncControllersFromDraft(target);
    }
  }

  AppAdvancedThemeModeConfig _modeConfigFromScheme(ColorScheme colorScheme) {
    return AppAdvancedThemeModeConfig(
      colors: AppAdvancedThemeColors(
        primaryColorValue: colorScheme.primary.toARGB32(),
        secondaryColorValue: colorScheme.secondary.toARGB32(),
        noticeAccentColorValue: colorScheme.tertiary.toARGB32(),
        noticeSurfaceColorValue: colorScheme.tertiaryContainer.toARGB32(),
        primaryContainerColorValue: colorScheme.primaryContainer.toARGB32(),
        backgroundColorValue: colorScheme.surface.toARGB32(),
        surfaceColorValue: colorScheme.surfaceContainerLow.toARGB32(),
        elevatedSurfaceColorValue: colorScheme.surfaceContainerHigh.toARGB32(),
        cardColorValue: colorScheme.surface.toARGB32(),
        cardBorderColorValue: colorScheme.outlineVariant.toARGB32(),
        iconBackgroundColorValue:
            Color.alphaBlend(
              colorScheme.onSurface.withValues(alpha: 0.04),
              colorScheme.surface,
            ).toARGB32(),
        textPrimaryColorValue: colorScheme.onSurface.toARGB32(),
        textSecondaryColorValue: colorScheme.onSurfaceVariant.toARGB32(),
        buttonTextColorValue: colorScheme.onPrimary.toARGB32(),
        outlineColorValue: colorScheme.outline.toARGB32(),
        shadowColorValue:
            colorScheme.primary.withValues(alpha: 0.18).toARGB32(),
        wallpaperOverlayColorValue: colorScheme.surface.toARGB32(),
      ),
      wallpaperOverlayOpacity:
          colorScheme.brightness == Brightness.dark ? 0.46 : 0.28,
    );
  }

  Future<void> _loadAppearanceLinks() async {
    final documents = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${documents.path}/backgrounds');
    final backgroundPaths = <String>[];
    if (await bgDir.exists()) {
      backgroundPaths.addAll(
        bgDir
            .listSync()
            .whereType<File>()
            .where(
              (file) =>
                  file.path.endsWith('.jpg') ||
                  file.path.endsWith('.jpeg') ||
                  file.path.endsWith('.png'),
            )
            .map((file) => file.path)
            .toList(growable: false),
      );
    }
    final activeGallery =
        await _bottomNavIconGalleryService.loadActiveGallery();
    final galleries = await _bottomNavIconGalleryService.loadGalleries();
    final coverGalleries = await _coverGalleryService.loadGalleries();
    if (!mounted) {
      return;
    }
    setState(() {
      _backgroundLibraryPaths = backgroundPaths;
      _bottomNavGalleries = galleries;
      _coverGalleries = coverGalleries;
      _activeBottomNavGalleryName = activeGallery?.name;
    });
  }

  void _syncControllersFromDraft(AppAdvancedTheme theme) {
    _nameController.text = theme.name;
    for (final mode in AppAdvancedThemeMode.values) {
      for (final slot in _ThemeColorSlot.values) {
        _colorControllersByMode[mode]![slot]!.text = _formatHex(
          _valueForSlot(theme.configFor(mode).colors, slot),
        );
      }
    }
  }

  Future<void> _saveTheme() async {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final normalizedName = _nameController.text.trim();
    if (normalizedName.isEmpty) {
      _showMessage('请先填写主题名称');
      return;
    }

    final parsedLightColors = _parseColorsForMode(AppAdvancedThemeMode.light);
    if (parsedLightColors == null) {
      return;
    }
    final parsedDarkColors = _parseColorsForMode(AppAdvancedThemeMode.dark);
    if (parsedDarkColors == null) {
      return;
    }
    if (parsedLightColors.configuredColorCount == 0) {
      _showMessage('请先完成浅色配置');
      _selectMode(AppAdvancedThemeMode.light);
      return;
    }
    if (parsedDarkColors.configuredColorCount == 0) {
      _showMessage('请先完成深色配置');
      _selectMode(AppAdvancedThemeMode.dark);
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final saved = await _service.saveTheme(
        draft.copyWith(
          name: normalizedName,
          lightConfig: draft.lightConfig.copyWith(colors: parsedLightColors),
          darkConfig: draft.darkConfig.copyWith(colors: parsedDarkColors),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = saved;
      });
      context.pop('已保存高级主题');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  AppAdvancedThemeColors? _parseColorsForMode(AppAdvancedThemeMode mode) {
    final values = <_ThemeColorSlot, int?>{};
    for (final slot in _ThemeColorSlot.values) {
      final raw = _colorControllersByMode[mode]![slot]!.text.trim();
      final parsed = _parseHexColor(raw);
      if (raw.isNotEmpty && parsed == null) {
        _showMessage(
          '${_modeLabel(mode)} ${slot.label} 颜色格式无效，支持 #RRGGBB 或 #AARRGGBB',
        );
        _selectMode(mode);
        return null;
      }
      values[slot] = parsed;
    }
    return AppAdvancedThemeColors(
      primaryColorValue: values[_ThemeColorSlot.primary],
      secondaryColorValue: values[_ThemeColorSlot.secondary],
      noticeAccentColorValue: values[_ThemeColorSlot.noticeAccent],
      noticeSurfaceColorValue: values[_ThemeColorSlot.noticeSurface],
      primaryContainerColorValue: values[_ThemeColorSlot.primaryContainer],
      backgroundColorValue: values[_ThemeColorSlot.background],
      surfaceColorValue: values[_ThemeColorSlot.surface],
      elevatedSurfaceColorValue: values[_ThemeColorSlot.elevatedSurface],
      cardColorValue: values[_ThemeColorSlot.card],
      cardBorderColorValue: values[_ThemeColorSlot.cardBorder],
      iconBackgroundColorValue: values[_ThemeColorSlot.iconBackground],
      textPrimaryColorValue: values[_ThemeColorSlot.textPrimary],
      textSecondaryColorValue: values[_ThemeColorSlot.textSecondary],
      buttonTextColorValue: values[_ThemeColorSlot.buttonText],
      outlineColorValue: values[_ThemeColorSlot.outline],
      shadowColorValue: values[_ThemeColorSlot.shadow],
      wallpaperOverlayColorValue: values[_ThemeColorSlot.wallpaperOverlay],
    );
  }

  Future<void> _pickWallpaperFromBackgroundLibrary() async {
    if (_backgroundLibraryPaths.isEmpty || _isSaving) {
      return;
    }
    String? selectedPath;
    final confirmedPath = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择背景库图片',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 116,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _backgroundLibraryPaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final path = _backgroundLibraryPaths[index];
                        final selected = path == selectedPath;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setSheetState(() {
                              selectedPath = path;
                            });
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 88,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        selected
                                            ? colorScheme.primary
                                            : colorScheme.outlineVariant
                                                .withValues(alpha: 0.45),
                                    width: selected ? 2 : 1,
                                  ),
                                  image: DecorationImage(
                                    image: FileImage(File(path)),
                                    fit: BoxFit.cover,
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
                                      color: colorScheme.primary,
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed:
                            selectedPath == null
                                ? null
                                : () => Navigator.of(context).pop(selectedPath),
                        child: const Text('应用'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (confirmedPath == null || !mounted) {
      return;
    }
    final file = File(confirmedPath);
    if (!await file.exists()) {
      _showMessage('背景图片不存在');
      return;
    }
    final bytes = await file.readAsBytes();
    await _applyPickedWallpaper(
      PickedImageData(bytes: bytes, name: file.uri.pathSegments.last),
    );
  }

  Future<void> _applyPickedWallpaper(PickedImageData picked) async {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    final currentConfig = draft.configFor(_selectedMode);
    try {
      final previousPath = currentConfig.wallpaperPath?.trim();
      final path = await _service.saveWallpaper(
        themeId: draft.id,
        mode: _selectedMode,
        bytes: picked.bytes,
        fileName: picked.name,
      );
      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != path) {
        await _service.deleteWallpaper(previousPath);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = draft.copyWithModeConfig(
          _selectedMode,
          currentConfig.copyWith(wallpaperPath: path),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickBottomNavGallery() async {
    if (_bottomNavGalleries.isEmpty || _isSaving) {
      return;
    }
    String? selectedId = _draft?.bottomNavGalleryId ?? _activeGalleryId;
    final nextId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择底栏图集',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _bottomNavGalleries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final gallery = _bottomNavGalleries[index];
                        final selected = gallery.id == selectedId;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setSheetState(() {
                              selectedId = gallery.id;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    gallery.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_rounded,
                                    color: colorScheme.primary,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed:
                            selectedId == null
                                ? null
                                : () => Navigator.of(context).pop(selectedId),
                        child: const Text('应用'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (nextId == null || !mounted) {
      return;
    }
    final draft = _draft;
    if (draft == null) {
      return;
    }
    setState(() {
      _draft = draft.copyWith(bottomNavGalleryId: nextId);
    });
  }

  Future<void> _pickCoverGallery() async {
    if (_isSaving) {
      return;
    }
    if (_coverGalleries.isEmpty) {
      if (!mounted) {
        return;
      }
      _showMessage('请先在封面图集里准备素材');
      unawaited(context.push('/appearance?section=cover'));
      return;
    }

    String? selectedId = _draft?.coverGalleryId?.trim();
    final result = await showModalBottomSheet<_CoverGallerySelectionResult>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择封面图集',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _coverGalleries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final gallery = _coverGalleries[index];
                        final selected = gallery.id == selectedId;
                        final previewPath = _firstExistingGalleryImagePath(
                          gallery,
                        );
                        final imageCount = gallery.imagePaths.length;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setSheetState(() {
                              selectedId = gallery.id;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                _buildGalleryPreviewThumb(
                                  context,
                                  previewPath: previewPath,
                                  title: gallery.name,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        gallery.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        imageCount <= 0
                                            ? '暂无图片'
                                            : '$imageCount 张图片',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_rounded,
                                    color: colorScheme.primary,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed:
                            selectedId == null
                                ? null
                                : () => Navigator.of(context).pop(
                                  const _CoverGallerySelectionResult(
                                    applied: true,
                                    galleryId: null,
                                  ),
                                ),
                        child: const Text('取消绑定'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed:
                            selectedId == null
                                ? null
                                : () => Navigator.of(context).pop(
                                  _CoverGallerySelectionResult(
                                    applied: true,
                                    galleryId: selectedId,
                                  ),
                                ),
                        child: const Text('应用'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result == null || !result.applied || !mounted) {
      return;
    }
    final draft = _draft;
    if (draft == null) {
      return;
    }
    setState(() {
      _draft =
          result.galleryId == null
              ? draft.copyWith(clearCoverGalleryId: true)
              : draft.copyWith(coverGalleryId: result.galleryId);
    });
  }

  String? get _activeGalleryId {
    if ((_draft?.bottomNavGalleryId?.trim().isNotEmpty ?? false)) {
      return _draft!.bottomNavGalleryId;
    }
    for (final gallery in _bottomNavGalleries) {
      if (gallery.name == _activeBottomNavGalleryName) {
        return gallery.id;
      }
    }
    return null;
  }

  String _resolvedBottomNavGalleryName() {
    final selectedId = _draft?.bottomNavGalleryId?.trim();
    if (selectedId != null && selectedId.isNotEmpty) {
      for (final gallery in _bottomNavGalleries) {
        if (gallery.id == selectedId) {
          return gallery.name;
        }
      }
    }
    final fallback = _activeBottomNavGalleryName?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return '默认图集';
  }

  CoverGallery? _selectedCoverGallery() {
    final selectedId = _draft?.coverGalleryId?.trim();
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }
    for (final gallery in _coverGalleries) {
      if (gallery.id == selectedId) {
        return gallery;
      }
    }
    return null;
  }

  String _resolvedCoverGalleryName() {
    final selectedGallery = _selectedCoverGallery();
    if (selectedGallery != null) {
      return selectedGallery.name;
    }
    final selectedId = _draft?.coverGalleryId?.trim();
    if (selectedId != null && selectedId.isNotEmpty) {
      return '已绑定图集不可用';
    }
    if (_coverGalleries.isEmpty) {
      return '暂无封面图集，点击前往管理';
    }
    return '未绑定封面图集';
  }

  String? _selectedCoverGalleryPreviewPath() {
    final gallery = _selectedCoverGallery();
    if (gallery == null) {
      return null;
    }
    return _firstExistingGalleryImagePath(gallery);
  }

  String? _firstExistingGalleryImagePath(CoverGallery gallery) {
    for (final rawPath in gallery.imagePaths) {
      final normalized = rawPath.trim();
      if (normalized.isEmpty) {
        continue;
      }
      final file = File(normalized);
      if (file.existsSync()) {
        return normalized;
      }
    }
    return null;
  }

  Widget _buildGalleryPreviewThumb(
    BuildContext context, {
    required String? previewPath,
    required String title,
    double width = 34,
    double height = 48,
    double borderRadius = 8,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (previewPath == null || previewPath.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: TextCoverPlaceholder(
            title: title,
            width: width,
            height: height,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        image: DecorationImage(
          image: FileImage(File(previewPath)),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Future<void> _clearWallpaper() async {
    final draft = _draft;
    final currentConfig = draft?.configFor(_selectedMode);
    final path = currentConfig?.wallpaperPath?.trim() ?? '';
    if (draft == null || currentConfig == null || path.isEmpty || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.deleteWallpaper(path);
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = draft.copyWithModeConfig(
          _selectedMode,
          currentConfig.copyWith(clearWallpaperPath: true),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _fillFromCurrentTheme() {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    final seedColor = ref.read(appSeedColorProvider);
    final currentConfig =
        _selectedMode == AppAdvancedThemeMode.light
            ? _modeConfigFromScheme(buildAppLightColorScheme(seedColor))
            : _modeConfigFromScheme(buildAppDarkColorScheme(seedColor));
    final next = draft.copyWithModeConfig(_selectedMode, currentConfig);
    setState(() {
      _draft = next;
    });
    _syncControllersFromDraft(next);
  }

  void _setWallpaperOverlayOpacity(double value) {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    final normalized = value.clamp(0.0, 1.0);
    setState(() {
      _draft = draft.copyWithModeConfig(
        _selectedMode,
        draft
            .configFor(_selectedMode)
            .copyWith(wallpaperOverlayOpacity: normalized),
      );
    });
  }

  void _selectMode(AppAdvancedThemeMode mode) {
    _modeTabController.animateTo(mode.index);
    setState(() {
      _selectedMode = mode;
    });
  }

  void _startEditingName() {
    _nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _nameController.text.length,
    );
    setState(() {
      _isEditingName = true;
    });
  }

  void _finishEditingName() {
    final normalized = _nameController.text.trim();
    if (normalized.isEmpty) {
      _showMessage('请先填写主题名称');
      return;
    }
    final draft = _draft;
    setState(() {
      _isEditingName = false;
      if (draft != null) {
        _draft = draft.copyWith(name: normalized);
      }
    });
  }

  Future<void> _pickColorForSlot(_ThemeColorSlot slot) async {
    final controller = _currentControllers[slot]!;
    final current = _parseHexColor(controller.text.trim());
    final fallback = _fallbackColorForSlot(context, _selectedMode, slot);
    final selected = await _showColorPickerDialog(
      context,
      title: slot.label,
      initialColorValue: current ?? fallback.toARGB32(),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      controller.text = _formatHex(selected);
    });
  }

  Future<int?> _showColorPickerDialog(
    BuildContext context, {
    required String title,
    required int initialColorValue,
  }) async {
    Color draftColor = Color(initialColorValue);
    final hexController = TextEditingController(
      text: _formatHex(draftColor.toARGB32()),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
              contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              title: Row(
                children: [
                  Expanded(child: Text('选择$title')),
                  TextButton(
                    onPressed:
                        () => Navigator.of(
                          dialogContext,
                        ).pop(draftColor.toARGB32()),
                    child: const Text('保存'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: hexController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[#0-9a-fA-F]'),
                        ),
                      ],
                      onChanged: (value) {
                        final parsed = _parseHexColor(value);
                        if (parsed == null) {
                          return;
                        }
                        setDialogState(() {
                          draftColor = Color(parsed);
                        });
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '#RRGGBB / #AARRGGBB',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ColorPicker(
                      pickerColor: draftColor,
                      onColorChanged: (color) {
                        setDialogState(() {
                          draftColor = color;
                          hexController.text = _formatHex(color.toARGB32());
                          hexController.selection = TextSelection.collapsed(
                            offset: hexController.text.length,
                          );
                        });
                      },
                      enableAlpha: false,
                      displayThumbColor: true,
                      portraitOnly: true,
                      paletteType: PaletteType.hueWheel,
                      pickerAreaHeightPercent: 0.72,
                      labelTypes: const [],
                      hexInputBar: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );
    hexController.dispose();
    return result;
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
    final draft = _draft;
    final theme = Theme.of(context);
    const sectionGap = 10.0;

    return Scaffold(
      appBar: AppBar(
        title:
            _isEditingName
                ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _finishEditingName(),
                  ),
                )
                : GestureDetector(
                  onTap: _startEditingName,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          draft == null ? '高级主题' : draft.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.45,
                  ),
                ),
              ),
              child: TabBar(
                controller: _modeTabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                indicatorPadding: const EdgeInsets.all(3),
                labelColor: theme.colorScheme.onSurface,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.light_mode_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('浅色主题'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dark_mode_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('深色主题'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (_isEditingName)
            IconButton(
              tooltip: '确认名称',
              onPressed: _finishEditingName,
              icon: const Icon(Icons.check_rounded),
            ),
          IconButton(
            tooltip: '回填当前主题',
            onPressed: _isLoading || _isSaving ? null : _fillFromCurrentTheme,
            icon: const Icon(Icons.color_lens_outlined),
          ),
          IconButton(
            tooltip: '保存主题',
            onPressed: _isLoading || _isSaving ? null : _saveTheme,
            icon: const Icon(Icons.save_outlined),
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
                      : draft == null
                      ? const Center(child: Text('高级主题不存在'))
                      : ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          8,
                          horizontal,
                          12 + bottomSafe,
                        ),
                        children: [
                          _buildColorsSection(context),
                          const SizedBox(height: sectionGap),
                          _buildWallpaperSection(context, draft),
                          const SizedBox(height: sectionGap),
                          _buildAppearanceLinkSection(context),
                          const SizedBox(height: sectionGap),
                          _buildPreviewSection(context, draft),
                        ],
                      ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '颜色'),
        const SizedBox(height: 6),
        _buildPanel(
          context,
          child: Column(
            children: _buildColorRows(context, const [
              _ThemeColorSlot.primary,
              _ThemeColorSlot.noticeAccent,
              _ThemeColorSlot.noticeSurface,
              _ThemeColorSlot.background,
              _ThemeColorSlot.surface,
              _ThemeColorSlot.elevatedSurface,
              _ThemeColorSlot.textPrimary,
              _ThemeColorSlot.textSecondary,
              _ThemeColorSlot.outline,
            ]),
          ),
        ),
        const SizedBox(height: 10),
        _buildSectionLabel(context, '卡片'),
        const SizedBox(height: 6),
        _buildPanel(
          context,
          child: Column(
            children: _buildColorRows(context, const [
              _ThemeColorSlot.card,
              _ThemeColorSlot.cardBorder,
              _ThemeColorSlot.iconBackground,
              _ThemeColorSlot.primaryContainer,
              _ThemeColorSlot.secondary,
              _ThemeColorSlot.buttonText,
              _ThemeColorSlot.shadow,
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildWallpaperSection(BuildContext context, AppAdvancedTheme draft) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentConfig = draft.configFor(_selectedMode);
    final wallpaperPath = currentConfig.wallpaperPath?.trim();
    final hasWallpaper =
        wallpaperPath != null &&
        wallpaperPath.isNotEmpty &&
        File(wallpaperPath).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '壁纸'),
        const SizedBox(height: 6),
        _buildPanel(
          context,
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap:
                    _isSaving
                        ? null
                        : (_backgroundLibraryPaths.isNotEmpty
                            ? _pickWallpaperFromBackgroundLibrary
                            : () =>
                                context.push('/appearance?section=background')),
                child: Container(
                  height: 108,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    image:
                        hasWallpaper
                            ? DecorationImage(
                              image: FileImage(File(wallpaperPath)),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child: Stack(
                    children: [
                      if (!hasWallpaper)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 24,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _backgroundLibraryPaths.isNotEmpty
                                    ? '点击 + 选择背景'
                                    : '先去背景页准备图片素材',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(
                                alpha: 0.88,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_backgroundLibraryPaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _backgroundLibraryPaths.length.clamp(0, 8),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final path = _backgroundLibraryPaths[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap:
                            _isSaving
                                ? null
                                : () => _applyPickedWallpaper(
                                  PickedImageData(
                                    bytes: File(path).readAsBytesSync(),
                                    name: File(path).uri.pathSegments.last,
                                  ),
                                ),
                        child: Container(
                          width: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            image: DecorationImage(
                              image: FileImage(File(path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ..._buildColorRows(context, const [
                _ThemeColorSlot.wallpaperOverlay,
              ]),
              const Divider(height: 1),
              _buildWallpaperOverlayOpacityRow(context),
              if (hasWallpaper) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isSaving ? null : _clearWallpaper,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('移除'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceLinkSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '其他外观'),
        const SizedBox(height: 6),
        _buildPanel(
          context,
          child: Column(
            children: [
              _buildAppearanceLinkTile(
                context,
                icon: Icons.photo_library_outlined,
                title: '封面',
                subtitle: _resolvedCoverGalleryName(),
                onTap: _pickCoverGallery,
                trailing: SizedBox(
                  width: 30,
                  height: 42,
                  child: _buildGalleryPreviewThumb(
                    context,
                    previewPath: _selectedCoverGalleryPreviewPath(),
                    title: _selectedCoverGallery()?.name ?? '封面图集',
                    width: 30,
                    height: 42,
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildAppearanceLinkTile(
                context,
                icon: Icons.dashboard_outlined,
                title: '底栏',
                subtitle: _resolvedBottomNavGalleryName(),
                onTap: _pickBottomNavGallery,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    IconData trailingIcon = Icons.chevron_right_rounded,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing],
            const SizedBox(width: 6),
            Icon(
              trailingIcon,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWallpaperOverlayOpacityRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final opacity = (_draft?.configFor(_selectedMode).wallpaperOverlayOpacity ??
            0.32)
        .clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '壁纸遮罩强度',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${(opacity * 100).round()}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: opacity,
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: _isSaving ? null : _setWallpaperOverlayOpacity,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTokenChip(
    BuildContext context, {
    required String label,
    required Color backgroundColor,
    required Color borderColor,
    required Color dotColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context, AppAdvancedTheme draft) {
    final currentConfig = draft.configFor(_selectedMode);
    final backgroundColor = _resolvedColor(
      _parseHexColor(
        _currentControllers[_ThemeColorSlot.background]!.text.trim(),
      ),
      _fallbackColorForSlot(context, _selectedMode, _ThemeColorSlot.background),
    );
    final surfaceColor = _resolvedColor(
      _parseHexColor(_currentControllers[_ThemeColorSlot.surface]!.text.trim()),
      _fallbackColorForSlot(context, _selectedMode, _ThemeColorSlot.surface),
    );
    final elevatedSurfaceColor = _resolvedColor(
      _parseHexColor(
        _currentControllers[_ThemeColorSlot.elevatedSurface]!.text.trim(),
      ),
      _fallbackColorForSlot(
        context,
        _selectedMode,
        _ThemeColorSlot.elevatedSurface,
      ),
    );
    final cardColor = _resolvedColor(
      _parseHexColor(_currentControllers[_ThemeColorSlot.card]!.text.trim()),
      _fallbackColorForSlot(context, _selectedMode, _ThemeColorSlot.card),
    );
    final primaryColor = _resolvedColor(
      _parseHexColor(_currentControllers[_ThemeColorSlot.primary]!.text.trim()),
      _fallbackColorForSlot(context, _selectedMode, _ThemeColorSlot.primary),
    );
    final noticeAccentColor = _resolvedColor(
      _parseHexColor(
        _currentControllers[_ThemeColorSlot.noticeAccent]!.text.trim(),
      ),
      _fallbackColorForSlot(
        context,
        _selectedMode,
        _ThemeColorSlot.noticeAccent,
      ),
    );
    final noticeSurfaceColor = _resolvedColor(
      _parseHexColor(
        _currentControllers[_ThemeColorSlot.noticeSurface]!.text.trim(),
      ),
      _fallbackColorForSlot(
        context,
        _selectedMode,
        _ThemeColorSlot.noticeSurface,
      ),
    );
    final iconBackgroundColor = _resolvedColor(
      _parseHexColor(
        _currentControllers[_ThemeColorSlot.iconBackground]!.text.trim(),
      ),
      _fallbackColorForSlot(
        context,
        _selectedMode,
        _ThemeColorSlot.iconBackground,
      ),
    );
    final textPrimaryColor = _resolvedColor(
      _parseHexColor(
        _currentControllers[_ThemeColorSlot.textPrimary]!.text.trim(),
      ),
      _fallbackColorForSlot(
        context,
        _selectedMode,
        _ThemeColorSlot.textPrimary,
      ),
    );
    final textSecondaryColor = _resolvedColor(
      _parseHexColor(
        _currentControllers[_ThemeColorSlot.textSecondary]!.text.trim(),
      ),
      _fallbackColorForSlot(
        context,
        _selectedMode,
        _ThemeColorSlot.textSecondary,
      ),
    );
    final cardBorderColor = _resolvedColor(
      _parseHexColor(
        _currentControllers[_ThemeColorSlot.cardBorder]!.text.trim(),
      ),
      _fallbackColorForSlot(context, _selectedMode, _ThemeColorSlot.cardBorder),
    );
    final wallpaperOverlayColor = _resolvedColor(
      _parseHexColor(
        _currentControllers[_ThemeColorSlot.wallpaperOverlay]!.text.trim(),
      ),
      _fallbackColorForSlot(
        context,
        _selectedMode,
        _ThemeColorSlot.wallpaperOverlay,
      ),
    );
    final wallpaperOverlayOpacity = currentConfig.wallpaperOverlayOpacity.clamp(
      0.0,
      1.0,
    );
    final wallpaperPath = currentConfig.wallpaperPath?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '预览'),
        const SizedBox(height: 6),
        _buildPanel(
          context,
          backgroundColor: surfaceColor,
          child: Container(
            height: 164,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cardBorderColor.withValues(alpha: 0.45),
              ),
              image:
                  wallpaperPath != null &&
                          wallpaperPath.isNotEmpty &&
                          File(wallpaperPath).existsSync()
                      ? DecorationImage(
                        image: FileImage(File(wallpaperPath)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          wallpaperOverlayColor.withValues(
                            alpha: wallpaperOverlayOpacity,
                          ),
                          BlendMode.srcOver,
                        ),
                      )
                      : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 86,
                    height: 10,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cardBorderColor.withValues(alpha: 0.72),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            height: 9,
                            decoration: BoxDecoration(
                              color: textPrimaryColor.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 122,
                            height: 6,
                            decoration: BoxDecoration(
                              color: textSecondaryColor.withValues(alpha: 0.74),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildPreviewTokenChip(
                                context,
                                label: '高层级',
                                backgroundColor: elevatedSurfaceColor,
                                borderColor: cardBorderColor.withValues(
                                  alpha: 0.35,
                                ),
                                dotColor: primaryColor,
                                textColor: textPrimaryColor,
                              ),
                              _buildPreviewTokenChip(
                                context,
                                label: '提示',
                                backgroundColor: noticeSurfaceColor,
                                borderColor: noticeAccentColor.withValues(
                                  alpha: 0.45,
                                ),
                                dotColor: noticeAccentColor,
                                textColor: textPrimaryColor,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: iconBackgroundColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.palette_outlined,
                                      size: 12,
                                      color: textPrimaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '图标',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall?.copyWith(
                                        color: textPrimaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            width: 78,
                            height: 28,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '按钮',
                              style: Theme.of(
                                context,
                              ).textTheme.labelMedium?.copyWith(
                                color: _resolvedColor(
                                  _parseHexColor(
                                    _currentControllers[_ThemeColorSlot
                                            .buttonText]!
                                        .text
                                        .trim(),
                                  ),
                                  _fallbackColorForSlot(
                                    context,
                                    _selectedMode,
                                    _ThemeColorSlot.buttonText,
                                  ),
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildColorRows(
    BuildContext context,
    List<_ThemeColorSlot> slots,
  ) {
    return [
      for (var index = 0; index < slots.length; index++) ...[
        _buildColorRow(context, slots[index]),
        if (index != slots.length - 1) const Divider(height: 1),
      ],
    ];
  }

  Widget _buildColorRow(BuildContext context, _ThemeColorSlot slot) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = _currentControllers[slot]!;
    final parsed = _parseHexColor(controller.text.trim());
    final fallback = _fallbackColorForSlot(context, _selectedMode, slot);
    final previewColor = _resolvedColor(parsed, fallback);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  slot.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 164,
            child: TextField(
              controller: controller,
              enabled: !_isSaving,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[#0-9a-fA-F]'),
                ),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: _formatHex(fallback.toARGB32()),
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
                ),
                suffixIcon: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isSaving ? null : () => _pickColorForSlot(slot),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: previewColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '恢复默认',
            onPressed:
                _isSaving
                    ? null
                    : () {
                      controller.text = _formatHex(fallback.toARGB32());
                      setState(() {});
                    },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required Widget child,
    Color? backgroundColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }

  Map<_ThemeColorSlot, TextEditingController> get _currentControllers {
    return _colorControllersByMode[_selectedMode]!;
  }

  String _modeLabel(AppAdvancedThemeMode mode) {
    return switch (mode) {
      AppAdvancedThemeMode.light => '浅色',
      AppAdvancedThemeMode.dark => '深色',
    };
  }

  Color _fallbackColorForSlot(
    BuildContext context,
    AppAdvancedThemeMode mode,
    _ThemeColorSlot slot,
  ) {
    final seedColor = ref.read(appSeedColorProvider);
    final colorScheme =
        mode == AppAdvancedThemeMode.light
            ? buildAppLightColorScheme(seedColor)
            : buildAppDarkColorScheme(seedColor);
    return switch (slot) {
      _ThemeColorSlot.primary => colorScheme.primary,
      _ThemeColorSlot.secondary => colorScheme.secondary,
      _ThemeColorSlot.noticeAccent => colorScheme.tertiary,
      _ThemeColorSlot.noticeSurface => colorScheme.tertiaryContainer,
      _ThemeColorSlot.primaryContainer => colorScheme.primaryContainer,
      _ThemeColorSlot.background => colorScheme.surface,
      _ThemeColorSlot.surface => colorScheme.surfaceContainerLow,
      _ThemeColorSlot.elevatedSurface => colorScheme.surfaceContainerHigh,
      _ThemeColorSlot.card => colorScheme.surface,
      _ThemeColorSlot.cardBorder => colorScheme.outlineVariant,
      _ThemeColorSlot.iconBackground => Color.alphaBlend(
        colorScheme.onSurface.withValues(alpha: 0.04),
        colorScheme.surface,
      ),
      _ThemeColorSlot.textPrimary => colorScheme.onSurface,
      _ThemeColorSlot.textSecondary => colorScheme.onSurfaceVariant,
      _ThemeColorSlot.buttonText => colorScheme.onPrimary,
      _ThemeColorSlot.outline => colorScheme.outline,
      _ThemeColorSlot.shadow => colorScheme.primary.withValues(alpha: 0.18),
      _ThemeColorSlot.wallpaperOverlay => colorScheme.surface,
    };
  }

  int? _valueForSlot(AppAdvancedThemeColors colors, _ThemeColorSlot slot) {
    return switch (slot) {
      _ThemeColorSlot.primary => colors.primaryColorValue,
      _ThemeColorSlot.secondary => colors.secondaryColorValue,
      _ThemeColorSlot.noticeAccent => colors.noticeAccentColorValue,
      _ThemeColorSlot.noticeSurface => colors.noticeSurfaceColorValue,
      _ThemeColorSlot.primaryContainer => colors.primaryContainerColorValue,
      _ThemeColorSlot.background => colors.backgroundColorValue,
      _ThemeColorSlot.surface => colors.surfaceColorValue,
      _ThemeColorSlot.elevatedSurface => colors.elevatedSurfaceColorValue,
      _ThemeColorSlot.card => colors.cardColorValue,
      _ThemeColorSlot.cardBorder => colors.cardBorderColorValue,
      _ThemeColorSlot.iconBackground => colors.iconBackgroundColorValue,
      _ThemeColorSlot.textPrimary => colors.textPrimaryColorValue,
      _ThemeColorSlot.textSecondary => colors.textSecondaryColorValue,
      _ThemeColorSlot.buttonText => colors.buttonTextColorValue,
      _ThemeColorSlot.outline => colors.outlineColorValue,
      _ThemeColorSlot.shadow => colors.shadowColorValue,
      _ThemeColorSlot.wallpaperOverlay => colors.wallpaperOverlayColorValue,
    };
  }

  int? _parseHexColor(String raw) {
    final normalized = raw.trim().toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }
    final body =
        normalized.startsWith('#') ? normalized.substring(1) : normalized;
    if (body.length == 6) {
      return int.tryParse('FF$body', radix: 16);
    }
    if (body.length == 8) {
      return int.tryParse(body, radix: 16);
    }
    return null;
  }

  String _formatHex(int? value) {
    if (value == null) {
      return '';
    }
    final hex = value.toRadixString(16).toUpperCase().padLeft(8, '0');
    if (hex.startsWith('FF')) {
      return '#${hex.substring(2)}';
    }
    return '#$hex';
  }

  Color _resolvedColor(int? value, Color fallback) {
    if (value == null) {
      return fallback;
    }
    return Color(value);
  }
}

enum _ThemeColorSlot {
  primary('强调色', '按钮和链接接的颜色'),
  noticeAccent('提示强调', '重要提示和通知强调色'),
  noticeSurface('提示底色', '重要提示块的背景色'),
  background('页面背景', '页面底色'),
  surface('次级背景', '输入框和分隔区域的底色'),
  elevatedSurface('高层级背景', '弹层和高层级面板背景'),
  textPrimary('主要文字', '正文和标题的颜色'),
  textSecondary('辅助文字', '提示和说明的颜色'),
  outline('边框', '分隔线和边框的颜色'),
  card('卡片背景', '列表项和弹窗的底色'),
  cardBorder('卡片边框', '卡片描边颜色'),
  iconBackground('图标底色', '我的页小卡片图标圆底背景'),
  primaryContainer('选中底色', '标签和选中区域底色'),
  secondary('辅助强调', '次级操作的强调色'),
  buttonText('按钮文字', '主按钮上的文字'),
  shadow('阴影', '卡片阴影或光晕色'),
  wallpaperOverlay('壁纸遮罩色', '壁纸上层覆盖的颜色');

  const _ThemeColorSlot(this.label, this.description);

  final String label;
  final String description;
}

class _CoverGallerySelectionResult {
  const _CoverGallerySelectionResult({
    required this.applied,
    required this.galleryId,
  });

  final bool applied;
  final String? galleryId;
}
