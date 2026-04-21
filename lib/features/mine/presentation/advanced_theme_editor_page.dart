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
import '../../../app/platform/app_input_focus_behavior.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_border_tokens.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/text_cover_placeholder.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../application/advanced_theme_provider.dart';
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
        searchFieldBackgroundColorValue:
            colorScheme.surfaceContainerHighest.toARGB32(),
        elevatedSurfaceColorValue: colorScheme.surfaceContainerHigh.toARGB32(),
        cardColorValue: colorScheme.surface.toARGB32(),
        cardTextColorValue: colorScheme.onSurface.toARGB32(),
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
      ref.read(advancedThemeRevisionProvider.notifier).markChanged();
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
      searchFieldBackgroundColorValue:
          values[_ThemeColorSlot.searchFieldBackground],
      elevatedSurfaceColorValue: values[_ThemeColorSlot.elevatedSurface],
      cardColorValue: values[_ThemeColorSlot.card],
      cardTextColorValue: values[_ThemeColorSlot.cardText],
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
    if (_isSaving) {
      return;
    }
    String? selectedPath;
    final confirmedPath = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
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
                    if (_backgroundLibraryPaths.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wallpaper_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '还没有背景素材',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '先去背景页添加图片，再回来选择。',
                              textAlign: TextAlign.center,
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
                      Flexible(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 8.0;
                            final columns = AppLayout.optionGridColumnsForWidth(
                              constraints.maxWidth,
                            ).clamp(3, 5);
                            final itemWidth =
                                (constraints.maxWidth -
                                    ((columns - 1) * spacing)) /
                                columns;
                            return SingleChildScrollView(
                              child: Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: _backgroundLibraryPaths
                                    .map((path) {
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
                                              width: itemWidth,
                                              height: itemWidth * 1.28,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color:
                                                      selected
                                                          ? colorScheme.primary
                                                          : colorScheme
                                                              .outlineVariant
                                                              .withValues(
                                                                alpha: 0.45,
                                                              ),
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
                                    })
                                    .toList(growable: false),
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
                        TextButton(
                          onPressed:
                              () => unawaited(
                                _openRouteFromSheet(
                                  context,
                                  '/appearance?section=background',
                                ),
                              ),
                          child: const Text('去管理'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed:
                              selectedPath == null
                                  ? null
                                  : () =>
                                      Navigator.of(context).pop(selectedPath),
                          child: const Text('应用'),
                        ),
                      ],
                    ),
                  ],
                ),
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

  Future<void> _pickReaderWallpaperFromBackgroundLibrary() async {
    if (_isSaving) {
      return;
    }
    String? selectedPath;
    final confirmedPath = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择阅读器背景',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_backgroundLibraryPaths.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.wallpaper_outlined,
                              size: 22,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '还没有背景素材',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '先去背景页添加图片，再回来选择。',
                              textAlign: TextAlign.center,
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
                      Flexible(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 8.0;
                            final columns = AppLayout.optionGridColumnsForWidth(
                              constraints.maxWidth,
                            ).clamp(3, 5);
                            final itemWidth =
                                (constraints.maxWidth -
                                    ((columns - 1) * spacing)) /
                                columns;
                            return SingleChildScrollView(
                              child: Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: _backgroundLibraryPaths
                                    .map((path) {
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
                                              width: itemWidth,
                                              height: itemWidth * 1.28,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color:
                                                      selected
                                                          ? colorScheme.primary
                                                          : colorScheme
                                                              .outlineVariant
                                                              .withValues(
                                                                alpha: 0.45,
                                                              ),
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
                                    })
                                    .toList(growable: false),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                selectedPath == null
                                    ? null
                                    : () =>
                                        Navigator.of(context).pop(selectedPath),
                            child: const Text('应用'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmedPath == null || confirmedPath.trim().isEmpty) {
      return;
    }

    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }

    final normalized = confirmedPath.trim();
    final currentConfig = draft.configFor(_selectedMode);
    setState(() {
      _draft = draft.copyWithModeConfig(
        _selectedMode,
        currentConfig.copyWith(readerWallpaperPath: normalized),
      );
    });
  }

  Future<void> _openRouteFromSheet(
    BuildContext sheetContext,
    String route,
  ) async {
    Navigator.of(sheetContext).pop();
    await context.push(route);
    await _loadAppearanceLinks();
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

    String? selectedId = _draft?.coverGalleryId?.trim();
    final result = await showModalBottomSheet<_CoverGallerySelectionResult>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
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
                    if (_coverGalleries.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '还没有封面图集',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '先去封面图集页准备素材，再回来绑定。',
                              textAlign: TextAlign.center,
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
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelLarge?.copyWith(
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
                                              color:
                                                  colorScheme.onSurfaceVariant,
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
                              () => unawaited(
                                _openRouteFromSheet(
                                  context,
                                  '/cover-galleries',
                                ),
                              ),
                          child: const Text('去管理'),
                        ),
                        const SizedBox(width: 8),
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

  String _resolvedWallpaperName(AppAdvancedTheme draft) {
    final path = _selectedWallpaperPreviewPath(draft);
    if (path != null && path.isNotEmpty) {
      return '当前模式已设置壁纸';
    }
    return '未设置壁纸';
  }

  String _resolvedReaderWallpaperName(AppAdvancedTheme draft) {
    final path = _selectedReaderWallpaperPreviewPath(draft);
    if (path != null && path.isNotEmpty) {
      return '当前模式已设置阅读器背景';
    }
    return '未设置阅读器背景';
  }

  String? _selectedWallpaperPreviewPath(AppAdvancedTheme draft) {
    final path = draft.configFor(_selectedMode).wallpaperPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    return File(path).existsSync() ? path : null;
  }

  String? _selectedReaderWallpaperPreviewPath(AppAdvancedTheme draft) {
    final path = draft.configFor(_selectedMode).readerWallpaperPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    return File(path).existsSync() ? path : null;
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
    bool useAddPlaceholder = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (previewPath == null || previewPath.isEmpty) {
      if (useAddPlaceholder) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            Icons.add_rounded,
            size: width >= 40 ? 22 : 18,
            color: colorScheme.onSurfaceVariant,
          ),
        );
      }
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

  Future<void> _clearReaderWallpaper() async {
    final draft = _draft;
    final currentConfig = draft?.configFor(_selectedMode);
    final path = currentConfig?.readerWallpaperPath?.trim() ?? '';
    if (draft == null || currentConfig == null || path.isEmpty || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = draft.copyWithModeConfig(
          _selectedMode,
          currentConfig.copyWith(clearReaderWallpaperPath: true),
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
    final editorBackdrop =
        draft == null
            ? null
            : resolveAdvancedThemeBackdropFromModeConfig(
              theme.colorScheme,
              _previewModeConfig(context, draft, _selectedMode),
            );

    return Scaffold(
      appBar: AppBar(
        title:
            _isEditingName
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
            tooltip: '保存主题',
            onPressed: _isLoading || _isSaving ? null : _saveTheme,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration:
            editorBackdrop == null
                ? const BoxDecoration()
                : buildAdvancedThemeBackdropDecoration(editorBackdrop),
        child: LayoutBuilder(
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
                            _buildResourceSection(context, draft),
                            const SizedBox(height: sectionGap),
                            _buildPreviewSection(context, draft),
                          ],
                        ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildColorsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '基础主题层'),
        const SizedBox(height: 4),
        _buildSectionDescription(
          context,
          '这一层决定整体风格，会影响大面积背景、输入区、选中态、文字层级和通用边框。',
        ),
        const SizedBox(height: 6),
        _buildPanel(
          context,
          child: Column(
            children: _buildColorFieldRows(context, const [
              _ThemeColorFieldSpec(
                slot: _ThemeColorSlot.primary,
                label: '强调色',
                description: '按钮和链接的颜色',
              ),
              _ThemeColorFieldSpec(
                slot: _ThemeColorSlot.background,
                label: '页面背景',
                description: '页面底色',
              ),
              _ThemeColorFieldSpec(
                slot: _ThemeColorSlot.surface,
                label: '次级背景',
                description: '搜索区、分割区域和次级面板底色',
              ),
              _ThemeColorFieldSpec(
                slot: _ThemeColorSlot.searchFieldBackground,
                label: '搜索框背景',
                description: '搜索框和搜索触发条的填充颜色',
              ),
              _ThemeColorFieldSpec(
                slot: _ThemeColorSlot.elevatedSurface,
                label: '高层级背景',
                description: '弹层和高层级面板背景',
              ),
              _ThemeColorFieldSpec(
                slot: _ThemeColorSlot.textPrimary,
                label: '主要文字',
                description: '正文和标题的颜色',
              ),
              _ThemeColorFieldSpec(
                slot: _ThemeColorSlot.textSecondary,
                label: '辅助文字',
                description: '提示和说明的颜色',
              ),
              _ThemeColorFieldSpec(
                slot: _ThemeColorSlot.outline,
                label: '通用边框',
                description: '输入框、分隔线和通用描边颜色',
              ),
              _ThemeColorFieldSpec(
                slot: _ThemeColorSlot.primaryContainer,
                label: '强调背景',
                description: '标签、筛选和选中态背景色',
              ),
              _ThemeColorFieldSpec(
                slot: _ThemeColorSlot.secondary,
                label: '辅助强调',
                description: '次级徽标和辅助操作的强调色',
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        _buildSectionLabel(context, '精细覆盖层'),
        const SizedBox(height: 4),
        _buildSectionDescription(
          context,
          '这一层负责局部精修，主要影响卡片、提示块、图标承托、按钮文字和阴影等具体视觉块。',
        ),
        const SizedBox(height: 6),
        _buildPanel(
          context,
          child: Column(
            children: [
              ..._buildColorFieldRows(context, const [
                _ThemeColorFieldSpec(
                  slot: _ThemeColorSlot.card,
                  label: '卡片背景',
                  description: '列表项和弹框的底色',
                ),
                _ThemeColorFieldSpec(
                  slot: _ThemeColorSlot.cardText,
                  label: '卡片文字',
                  description: '卡片内主要文字的颜色',
                ),
                _ThemeColorFieldSpec(
                  slot: _ThemeColorSlot.cardBorder,
                  label: '卡片边框',
                  description: '卡片和面板描边颜色',
                ),
                _ThemeColorFieldSpec(
                  slot: _ThemeColorSlot.noticeAccent,
                  label: '提示强调',
                  description: '重要提示和通知强调色',
                ),
                _ThemeColorFieldSpec(
                  slot: _ThemeColorSlot.noticeSurface,
                  label: '提示底色',
                  description: '重要提示块和状态标签的背景色',
                ),
                _ThemeColorFieldSpec(
                  slot: _ThemeColorSlot.iconBackground,
                  label: '图标底色',
                  description: '图标圆底和辅助视觉底色',
                ),
                _ThemeColorFieldSpec(
                  slot: _ThemeColorSlot.buttonText,
                  label: '按钮文字',
                  description: '主按钮和高亮按钮上的文字颜色',
                ),
                _ThemeColorFieldSpec(
                  slot: _ThemeColorSlot.shadow,
                  label: '阴影',
                  description: '卡片和浮层的阴影或光晕颜色',
                ),
              ]),
              const Divider(height: 1),
              _buildInfoRow(
                context,
                label: '卡片背景模糊',
                description: '当前暂未独立支持，后续再补成单独效果项',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '当前联动',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDescription(BuildContext context, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        description,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildResourceSection(BuildContext context, AppAdvancedTheme draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '资源层'),
        const SizedBox(height: 4),
        _buildSectionDescription(
          context,
          '资源层统一管理壁纸、封面图集和底栏图集等素材，不参与基础主题层和精细覆盖层的颜色计算。',
        ),
        const SizedBox(height: 6),
        _buildAppearanceLinkSection(context, draft),
      ],
    );
  }

  Widget _buildAppearanceLinkSection(
    BuildContext context,
    AppAdvancedTheme draft,
  ) {
    final wallpaperPath = _selectedWallpaperPreviewPath(draft);
    final hasWallpaper = wallpaperPath != null && wallpaperPath.isNotEmpty;
    final readerWallpaperPath = _selectedReaderWallpaperPreviewPath(draft);
    final hasReaderWallpaper =
        readerWallpaperPath != null && readerWallpaperPath.isNotEmpty;
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
                icon: Icons.wallpaper_outlined,
                title: '壁纸',
                subtitle: _resolvedWallpaperName(draft),
                onTap: _isSaving ? () {} : _pickWallpaperFromBackgroundLibrary,
                trailing: SizedBox(
                  width: 46,
                  height: 46,
                  child: _buildGalleryPreviewThumb(
                    context,
                    previewPath: wallpaperPath,
                    title: '壁纸',
                    width: 46,
                    height: 46,
                    borderRadius: 10,
                    useAddPlaceholder: true,
                  ),
                ),
              ),
              if (hasWallpaper) ...[
                const Divider(height: 1),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isSaving ? null : _clearWallpaper,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('移除当前壁纸'),
                  ),
                ),
                const Divider(height: 1),
              ] else
                const Divider(height: 1),
              _buildAppearanceLinkTile(
                context,
                icon: Icons.chrome_reader_mode_outlined,
                title: '阅读器背景',
                subtitle: _resolvedReaderWallpaperName(draft),
                onTap:
                    _isSaving
                        ? () {}
                        : _pickReaderWallpaperFromBackgroundLibrary,
                trailing: SizedBox(
                  width: 46,
                  height: 46,
                  child: _buildGalleryPreviewThumb(
                    context,
                    previewPath: readerWallpaperPath,
                    title: '阅读器背景',
                    width: 46,
                    height: 46,
                    borderRadius: 10,
                    useAddPlaceholder: true,
                  ),
                ),
              ),
              if (hasReaderWallpaper) ...[
                const Divider(height: 1),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isSaving ? null : _clearReaderWallpaper,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('移除阅读器背景'),
                  ),
                ),
                const Divider(height: 1),
              ] else
                const Divider(height: 1),
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
                    useAddPlaceholder: true,
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
            Icon(trailingIcon, size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
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
    final previewConfig = _previewModeConfig(context, draft, _selectedMode);
    final colorScheme = _colorSchemeForMode(_selectedMode);
    final palette = resolveAdvancedThemePaletteFromModeConfig(
      colorScheme,
      previewConfig,
    );
    final backdrop = resolveAdvancedThemeBackdropFromModeConfig(
      colorScheme,
      previewConfig,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '预览'),
        const SizedBox(height: 6),
        _buildPanel(
          context,
          backgroundColor: palette.surfaceColor,
          child: Container(
            constraints: const BoxConstraints(minHeight: 180),
            decoration: buildAdvancedThemeBackdropDecoration(
              backdrop,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: resolveAppBorderColor(
                  colorScheme,
                  baseColor: palette.cardBorderColor,
                  containerColor: backdrop.backgroundColor,
                ),
              ),
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
                      color: palette.primaryColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.cardColor.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: resolveAppBorderColor(
                          colorScheme,
                          baseColor: palette.cardBorderColor,
                          containerColor: palette.cardColor,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.shadowColor,
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 9,
                          decoration: BoxDecoration(
                            color: palette.cardTextColor.withValues(
                              alpha: 0.88,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 122,
                          height: 6,
                          decoration: BoxDecoration(
                            color: palette.textSecondaryColor.withValues(
                              alpha: 0.74,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildPreviewTokenChip(
                              context,
                              label: '高层级',
                              backgroundColor: palette.elevatedSurfaceColor,
                              borderColor: resolveAppBorderColor(
                                colorScheme,
                                baseColor: palette.cardBorderColor,
                                containerColor: palette.elevatedSurfaceColor,
                                tone: AppBorderTone.subtle,
                              ),
                              dotColor: palette.primaryColor,
                              textColor: palette.cardTextColor,
                            ),
                            _buildPreviewTokenChip(
                              context,
                              label: '提示',
                              backgroundColor: palette.noticeSurfaceColor,
                              borderColor: palette.noticeAccentColor,
                              dotColor: palette.noticeAccentColor,
                              textColor: palette.cardTextColor,
                            ),
                            _buildPreviewTokenChip(
                              context,
                              label: '标签',
                              backgroundColor: palette.primaryContainerColor,
                              borderColor: resolveAppBorderColor(
                                colorScheme,
                                baseColor: palette.outlineColor,
                                containerColor: palette.primaryContainerColor,
                                tone: AppBorderTone.subtle,
                              ),
                              dotColor: palette.secondaryColor,
                              textColor: palette.textPrimaryColor,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: palette.iconBackgroundColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.palette_outlined,
                                    size: 12,
                                    color: palette.textPrimaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '图标',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall?.copyWith(
                                      color: palette.cardTextColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 78,
                          height: 26,
                          decoration: BoxDecoration(
                            color: palette.primaryColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '按钮',
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              color: palette.buttonTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

  List<Widget> _buildColorFieldRows(
    BuildContext context,
    List<_ThemeColorFieldSpec> fields,
  ) {
    return [
      for (var index = 0; index < fields.length; index++) ...[
        _buildColorFieldRow(context, fields[index]),
        if (index != fields.length - 1) const Divider(height: 1),
      ],
    ];
  }

  Widget _buildColorFieldRow(BuildContext context, _ThemeColorFieldSpec field) {
    final slot = field.slot;
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
                  field.label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  field.description,
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
                FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
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
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.2,
                  ),
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

  ColorScheme _colorSchemeForMode(AppAdvancedThemeMode mode) {
    final seedColor = ref.read(appSeedColorProvider);
    return mode == AppAdvancedThemeMode.light
        ? buildAppLightColorScheme(seedColor)
        : buildAppDarkColorScheme(seedColor);
  }

  AppAdvancedThemeModeConfig _previewModeConfig(
    BuildContext context,
    AppAdvancedTheme draft,
    AppAdvancedThemeMode mode,
  ) {
    final currentConfig = draft.configFor(mode);

    Color resolvedSlotColor(_ThemeColorSlot slot) {
      final raw = _colorControllersByMode[mode]![slot]!.text.trim();
      return _resolvedColor(
        _parseHexColor(raw),
        _fallbackColorForSlot(context, mode, slot),
      );
    }

    return currentConfig.copyWith(
      colors: AppAdvancedThemeColors(
        primaryColorValue:
            resolvedSlotColor(_ThemeColorSlot.primary).toARGB32(),
        secondaryColorValue:
            resolvedSlotColor(_ThemeColorSlot.secondary).toARGB32(),
        noticeAccentColorValue:
            resolvedSlotColor(_ThemeColorSlot.noticeAccent).toARGB32(),
        noticeSurfaceColorValue:
            resolvedSlotColor(_ThemeColorSlot.noticeSurface).toARGB32(),
        primaryContainerColorValue:
            resolvedSlotColor(_ThemeColorSlot.primaryContainer).toARGB32(),
        backgroundColorValue:
            resolvedSlotColor(_ThemeColorSlot.background).toARGB32(),
        surfaceColorValue:
            resolvedSlotColor(_ThemeColorSlot.surface).toARGB32(),
        searchFieldBackgroundColorValue:
            resolvedSlotColor(_ThemeColorSlot.searchFieldBackground).toARGB32(),
        elevatedSurfaceColorValue:
            resolvedSlotColor(_ThemeColorSlot.elevatedSurface).toARGB32(),
        cardColorValue: resolvedSlotColor(_ThemeColorSlot.card).toARGB32(),
        cardTextColorValue:
            resolvedSlotColor(_ThemeColorSlot.cardText).toARGB32(),
        cardBorderColorValue:
            resolvedSlotColor(_ThemeColorSlot.cardBorder).toARGB32(),
        iconBackgroundColorValue:
            resolvedSlotColor(_ThemeColorSlot.iconBackground).toARGB32(),
        textPrimaryColorValue:
            resolvedSlotColor(_ThemeColorSlot.textPrimary).toARGB32(),
        textSecondaryColorValue:
            resolvedSlotColor(_ThemeColorSlot.textSecondary).toARGB32(),
        buttonTextColorValue:
            resolvedSlotColor(_ThemeColorSlot.buttonText).toARGB32(),
        outlineColorValue:
            resolvedSlotColor(_ThemeColorSlot.outline).toARGB32(),
        shadowColorValue: resolvedSlotColor(_ThemeColorSlot.shadow).toARGB32(),
        wallpaperOverlayColorValue:
            resolvedSlotColor(_ThemeColorSlot.wallpaperOverlay).toARGB32(),
      ),
    );
  }

  Color _fallbackColorForSlot(
    BuildContext context,
    AppAdvancedThemeMode mode,
    _ThemeColorSlot slot,
  ) {
    final colorScheme = _colorSchemeForMode(mode);
    return switch (slot) {
      _ThemeColorSlot.primary => colorScheme.primary,
      _ThemeColorSlot.secondary => colorScheme.secondary,
      _ThemeColorSlot.noticeAccent => colorScheme.tertiary,
      _ThemeColorSlot.noticeSurface => colorScheme.tertiaryContainer,
      _ThemeColorSlot.primaryContainer => colorScheme.primaryContainer,
      _ThemeColorSlot.background => colorScheme.surface,
      _ThemeColorSlot.surface => colorScheme.surfaceContainerLow,
      _ThemeColorSlot.searchFieldBackground =>
        colorScheme.surfaceContainerHighest,
      _ThemeColorSlot.elevatedSurface => colorScheme.surfaceContainerHigh,
      _ThemeColorSlot.card => colorScheme.surface,
      _ThemeColorSlot.cardText => colorScheme.onSurface,
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
      _ThemeColorSlot.searchFieldBackground =>
        colors.searchFieldBackgroundColorValue,
      _ThemeColorSlot.elevatedSurface => colors.elevatedSurfaceColorValue,
      _ThemeColorSlot.card => colors.cardColorValue,
      _ThemeColorSlot.cardText => colors.cardTextColorValue,
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
  noticeSurface('提示底色', '重要提示块和状态标签的背景色'),
  background('页面背景', '页面底色'),
  surface('次级背景', '搜索区、分割区域和次级面板底色'),
  searchFieldBackground('搜索框背景', '搜索框和搜索触发条的填充颜色'),
  elevatedSurface('高层级背景', '弹层和高层级面板背景'),
  textPrimary('主要文字', '正文和标题的颜色'),
  textSecondary('辅助文字', '提示和说明的颜色'),
  outline('通用边框', '输入框、分隔线和通用描边颜色'),
  card('卡片背景', '列表项和弹窗的底色'),
  cardText('卡片文字', '卡片内主要文字的颜色'),
  cardBorder('卡片边框', '卡片和面板描边颜色'),
  iconBackground('图标底色', '我的页小卡片图标圆底背景'),
  primaryContainer('强调背景', '标签、筛选和选中态背景色'),
  secondary('辅助强调', '次级徽标和辅助操作的强调色'),
  buttonText('按钮文字', '主按钮和高亮按钮上的文字'),
  shadow('阴影', '卡片和浮层的阴影或光晕颜色'),
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

class _ThemeColorFieldSpec {
  const _ThemeColorFieldSpec({
    required this.slot,
    required this.label,
    required this.description,
  });

  final _ThemeColorSlot slot;
  final String label;
  final String description;
}
