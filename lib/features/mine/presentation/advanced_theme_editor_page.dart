import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/platform/app_input_focus_behavior.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/adaptive_fullscreen_preview.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/text_cover_placeholder.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/storage/managed_file_path_resolver.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../../../domain/entities/launch_image_gallery.dart';
import '../../reader/application/reader_font_registry_service.dart';
import '../application/advanced_theme_provider.dart';
import '../application/advanced_theme_editor_state_service.dart';
import '../application/advanced_theme_service.dart';
import '../application/theme_semantic_spec.dart';
import '../providers.dart';

part 'advanced_theme_editor_page_flow.dart';

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
  static const double _resourcePickerSheetHeightFactor = 0.7;
  static final ManagedFilePathResolver _pathResolver =
      ManagedFilePathResolver();

  late final AdvancedThemeService _service;
  late final AdvancedThemeEditorStateService _stateService;
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
  final ValueNotifier<int> _colorPreviewRevision = ValueNotifier<int>(0);

  AppAdvancedTheme? _draft;
  AppAdvancedThemeMode _selectedMode = AppAdvancedThemeMode.light;
  List<String> _backgroundLibraryPaths = const <String>[];
  List<String> _readerBackgroundLibraryPaths = const <String>[];
  List<BottomNavIconGallery> _bottomNavGalleries =
      const <BottomNavIconGallery>[];
  List<CoverGallery> _coverGalleries = const <CoverGallery>[];
  List<LaunchImageGallery> _launchImageGalleries = const <LaunchImageGallery>[];
  List<ReaderCustomFontEntry> _availableFonts = const <ReaderCustomFontEntry>[];
  String? _activeBottomNavGalleryName;
  bool _strengthControlsExpanded = true;
  bool _isEditingName = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _didInitialize = false;

  @override
  void initState() {
    super.initState();
    for (final controllers in _colorControllersByMode.values) {
      for (final controller in controllers.values) {
        controller.addListener(_handleColorControllerChanged);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    _service = ref.read(advancedThemeServiceProvider);
    _stateService = ref.read(advancedThemeEditorStateServiceProvider);
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
        controller.removeListener(_handleColorControllerChanged);
        controller.dispose();
      }
    }
    _colorPreviewRevision.dispose();
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

  void _updateAdvancedThemeEditorState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  void _handleColorControllerChanged() {
    _colorPreviewRevision.value++;
  }

  Future<void> _initializeDraft() => _initializeDraftImpl();

  Future<void> _loadAppearanceLinks() => _loadAppearanceLinksImpl();

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

  Future<void> _saveTheme() => _saveThemeImpl();

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
    final draft = _draft;
    final currentFit =
        draft?.configFor(_selectedMode).wallpaperFit ??
        AppAdvancedThemeWallpaperFit.cover;
    String? selectedPath =
        draft == null ? null : _selectedWallpaperPreviewPath(draft);
    final imagePaths = _existingImagePaths(_backgroundLibraryPaths);
    var selectedFit = currentFit;
    final result = await showAdaptiveActionSurface<_WallpaperSelectionResult>(
      context: context,
      maxWidth: 720,
      maxHeightFactor: _resourcePickerSheetHeightFactor,
      padding: EdgeInsets.zero,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildResourcePickerSheet(
              context,
              title: '选择壁纸',
              helperText: '显示的是背景页素材列表，长按图片可放大预览。',
              content: Column(
                children: [
                  _buildListSectionBody(
                    context,
                    child: _buildCompactFitRow(
                      context,
                      label: '壁纸图片适配',
                      fit: selectedFit,
                      onChanged:
                          (fit) => setSheetState(() {
                            selectedFit = fit;
                          }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child:
                        imagePaths.isEmpty
                            ? _buildEmptyResourceState(
                              context,
                              icon: Icons.wallpaper_outlined,
                              title: '还没有背景素材',
                              description: '先去背景页添加图片，再回来选择。',
                            )
                            : _buildImageSelectionGrid(
                              context,
                              imagePaths: imagePaths,
                              selectedPath: selectedPath,
                              titleBuilder: (_) => '壁纸',
                              onSelected: (path) {
                                setSheetState(() {
                                  selectedPath = path;
                                });
                              },
                            ),
                  ),
                ],
              ),
              actions: [
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
                          : () => Navigator.of(context).pop(
                            _WallpaperSelectionResult(
                              path: selectedPath!,
                              fit: selectedFit,
                            ),
                          ),
                  child: const Text('应用'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    final file = File(result.path);
    if (!await file.exists()) {
      _showMessage('背景图片不存在');
      return;
    }
    final bytes = await file.readAsBytes();
    await _applyPickedWallpaper(
      PickedImageData(bytes: bytes, name: file.uri.pathSegments.last),
    );
    if (!mounted) {
      return;
    }
    _setWallpaperFit(result.fit);
  }

  Future<void> _applyPickedWallpaper(PickedImageData picked) =>
      _applyPickedWallpaperImpl(picked);

  Future<void> _pickReaderWallpaperFromBackgroundLibrary() async {
    if (_isSaving) {
      return;
    }
    final draft = _draft;
    final currentFit =
        draft?.configFor(_selectedMode).readerWallpaperFit ??
        AppAdvancedThemeWallpaperFit.cover;
    String? selectedPath =
        draft == null ? null : _selectedReaderWallpaperPreviewPath(draft);
    final imagePaths = _existingImagePaths(_readerBackgroundLibraryPaths);
    var selectedFit = currentFit;
    final result = await showAdaptiveActionSurface<_WallpaperSelectionResult>(
      context: context,
      maxWidth: 720,
      maxHeightFactor: _resourcePickerSheetHeightFactor,
      padding: EdgeInsets.zero,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildResourcePickerSheet(
              context,
              title: '选择阅读器背景',
              helperText: '显示的是阅读背景页素材列表，长按图片可放大预览。',
              content: Column(
                children: [
                  _buildListSectionBody(
                    context,
                    child: _buildCompactFitRow(
                      context,
                      label: '阅读器图片适配',
                      fit: selectedFit,
                      onChanged:
                          (fit) => setSheetState(() {
                            selectedFit = fit;
                          }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child:
                        imagePaths.isEmpty
                            ? _buildEmptyResourceState(
                              context,
                              icon: Icons.chrome_reader_mode_outlined,
                              title: '还没有阅读背景素材',
                              description: '先去阅读背景页添加图片，再回来选择。',
                            )
                            : _buildImageSelectionGrid(
                              context,
                              imagePaths: imagePaths,
                              selectedPath: selectedPath,
                              titleBuilder: (_) => '阅读器背景',
                              onSelected: (path) {
                                setSheetState(() {
                                  selectedPath = path;
                                });
                              },
                            ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      () => unawaited(
                        _openRouteFromSheet(
                          context,
                          '/appearance/reader-background',
                        ),
                      ),
                  child: const Text('去管理'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed:
                      selectedPath == null
                          ? null
                          : () => Navigator.of(context).pop(
                            _WallpaperSelectionResult(
                              path: selectedPath!,
                              fit: selectedFit,
                            ),
                          ),
                  child: const Text('应用'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.path.trim().isEmpty) {
      return;
    }

    if (draft == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final nextDraft = await _stateService.applyReaderWallpaper(
        draft: draft,
        mode: _selectedMode,
        sourcePath: result.path.trim(),
      );
      if (!mounted) {
        return;
      }
      final updatedConfig = nextDraft
          .configFor(_selectedMode)
          .copyWith(readerWallpaperFit: result.fit);
      setState(() {
        _draft = nextDraft.copyWithModeConfig(_selectedMode, updatedConfig);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
    final nextId = await showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 720,
      maxHeightFactor: _resourcePickerSheetHeightFactor,
      padding: EdgeInsets.zero,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildResourcePickerSheet(
              context,
              title: '选择底栏图集',
              content: ListView.separated(
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
                              style: Theme.of(context).textTheme.labelLarge
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
              actions: [
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

    String? selectedId = _draft?.coverGalleryIdFor(_selectedMode)?.trim();
    final result = await showAdaptiveActionSurface<
      _CoverGallerySelectionResult
    >(
      context: context,
      maxWidth: 720,
      maxHeightFactor: _resourcePickerSheetHeightFactor,
      padding: EdgeInsets.zero,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildResourcePickerSheet(
              context,
              title: '选择${_modeLabel(_selectedMode)}封面图集',
              content:
                  _coverGalleries.isEmpty
                      ? _buildEmptyResourceState(
                        context,
                        icon: Icons.photo_library_outlined,
                        title: '还没有封面图集',
                        description: '先去封面图集页准备素材，再回来绑定。',
                      )
                      : ListView.separated(
                        itemCount: _coverGalleries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final gallery = _coverGalleries[index];
                          final selected = gallery.id == selectedId;
                          final previewPath = _firstExistingImagePath(
                            gallery.imagePaths,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const Spacer(),
                TextButton(
                  onPressed:
                      () => unawaited(
                        _openRouteFromSheet(context, '/cover-galleries'),
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
              ? draft.copyWithCoverGalleryForMode(_selectedMode, clear: true)
              : draft.copyWithCoverGalleryForMode(
                _selectedMode,
                galleryId: result.galleryId,
              );
    });
  }

  Future<void> _pickLaunchImageGallery() async {
    if (_isSaving) {
      return;
    }

    String? selectedId = _draft?.launchImageGalleryId?.trim();
    final result =
        await showAdaptiveActionSurface<_LaunchImageGallerySelectionResult>(
          context: context,
          maxWidth: 720,
          maxHeightFactor: _resourcePickerSheetHeightFactor,
          padding: EdgeInsets.zero,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return _buildResourcePickerSheet(
                  context,
                  title: '选择启动图',
                  helperText: '显示的是启动图集页的列表图，点选图集即可绑定，长按缩略图可放大。',
                  content:
                      _launchImageGalleries.isEmpty
                          ? _buildEmptyResourceState(
                            context,
                            icon: Icons.rocket_launch_outlined,
                            title: '还没有启动图集',
                            description: '先去启动图集页准备素材，再回来绑定。',
                          )
                          : ListView.separated(
                            itemCount: _launchImageGalleries.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final gallery = _launchImageGalleries[index];
                              return _buildLaunchGallerySelectionCard(
                                context,
                                title: gallery.name,
                                subtitle:
                                    gallery.imagePaths.isEmpty
                                        ? '暂无图片'
                                        : '${gallery.imagePaths.length} 张启动图',
                                previewPaths: _existingImagePaths(
                                  gallery.imagePaths,
                                ),
                                selected: gallery.id == selectedId,
                                onTap: () {
                                  setSheetState(() {
                                    selectedId = gallery.id;
                                  });
                                },
                              );
                            },
                          ),
                  actions: [
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
                              '/appearance/launch-image',
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
                                const _LaunchImageGallerySelectionResult(
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
                                _LaunchImageGallerySelectionResult(
                                  applied: true,
                                  galleryId: selectedId,
                                ),
                              ),
                      child: const Text('应用'),
                    ),
                  ],
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
              ? draft.copyWith(clearLaunchImageGalleryId: true)
              : draft.copyWith(launchImageGalleryId: result.galleryId);
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

  String? _selectedWallpaperPreviewPath(AppAdvancedTheme draft) {
    return _wallpaperPreviewPathForMode(draft, _selectedMode);
  }

  String? _wallpaperPreviewPathForMode(
    AppAdvancedTheme draft,
    AppAdvancedThemeMode mode,
  ) {
    return _resolveExistingLocalImagePath(draft.configFor(mode).wallpaperPath);
  }

  String? _selectedReaderWallpaperPreviewPath(AppAdvancedTheme draft) {
    return _resolveExistingLocalImagePath(
      draft.configFor(_selectedMode).readerWallpaperPath,
    );
  }

  CoverGallery? _selectedCoverGallery() {
    final selectedId = _draft?.coverGalleryIdFor(_selectedMode)?.trim();
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

  String? _selectedCoverGalleryPreviewPath() {
    final gallery = _selectedCoverGallery();
    if (gallery == null) {
      return null;
    }
    return _firstExistingImagePath(gallery.imagePaths);
  }

  LaunchImageGallery? _selectedLaunchImageGallery() {
    final selectedId = _draft?.launchImageGalleryId?.trim();
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }
    for (final gallery in _launchImageGalleries) {
      if (gallery.id == selectedId) {
        return gallery;
      }
    }
    return null;
  }

  String? _selectedLaunchImageGalleryPreviewPath() {
    final gallery = _selectedLaunchImageGallery();
    if (gallery == null) {
      return null;
    }
    return _firstExistingImagePath(gallery.imagePaths);
  }

  String? _firstExistingImagePath(List<String> imagePaths) {
    for (final rawPath in imagePaths) {
      final resolved = _resolveExistingLocalImagePath(rawPath);
      if (resolved != null) {
        return resolved;
      }
    }
    return null;
  }

  ReaderCustomFontEntry? _selectedAppInterfaceFont() {
    final familyKey = _draft?.appInterfaceFontFamilyKey?.trim() ?? '';
    if (familyKey.isEmpty) {
      return null;
    }
    for (final entry in _availableFonts) {
      if (entry.fontFamilyKey == familyKey) {
        return entry;
      }
    }
    return null;
  }

  ReaderCustomFontEntry? _selectedReaderFont() {
    final familyKey = _draft?.readerFontFamilyKey?.trim() ?? '';
    if (familyKey.isEmpty) {
      return null;
    }
    for (final entry in _availableFonts) {
      if (entry.fontFamilyKey == familyKey) {
        return entry;
      }
    }
    return null;
  }

  String _resolvedAppInterfaceFontName() {
    final selected = _selectedAppInterfaceFont();
    if (selected != null) {
      return selected.displayName;
    }
    final familyKey = _draft?.appInterfaceFontFamilyKey?.trim() ?? '';
    if (familyKey.isNotEmpty) {
      return '已绑定字体不可用';
    }
    return _availableFonts.isEmpty ? '暂无已导入字体' : '未绑定界面字体';
  }

  String _resolvedReaderFontName() {
    final selected = _selectedReaderFont();
    if (selected != null) {
      return selected.displayName;
    }
    final familyKey = _draft?.readerFontFamilyKey?.trim() ?? '';
    if (familyKey.isNotEmpty) {
      return '已绑定字体不可用';
    }
    return _availableFonts.isEmpty ? '暂无已导入字体' : '未绑定阅读字体';
  }

  Future<void> _pickThemeFont({required bool readerFont}) async {
    if (_isSaving) {
      return;
    }
    String? selectedId =
        (readerFont
                ? _draft?.readerFontFamilyKey
                : _draft?.appInterfaceFontFamilyKey)
            ?.trim();
    final result = await showAdaptiveActionSurface<_ThemeFontSelectionResult>(
      context: context,
      maxWidth: 640,
      maxHeightFactor: _resourcePickerSheetHeightFactor,
      padding: EdgeInsets.zero,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildResourcePickerSheet(
              context,
              title: readerFont ? '选择阅读字体' : '选择界面字体',
              content:
                  _availableFonts.isEmpty
                      ? _buildEmptyResourceState(
                        context,
                        icon: Icons.font_download_outlined,
                        title: '还没有已导入字体',
                        description: '先去字体管理导入字体，再回来绑定。',
                      )
                      : ListView.separated(
                        itemCount: _availableFonts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = _availableFonts[index];
                          final selected = entry.fontFamilyKey == selectedId;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setSheetState(() {
                                selectedId = entry.fontFamilyKey;
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.displayName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontFamily: entry.fontFamilyKey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          readerFont
                                              ? '阅读页启用主题时覆盖正文自定义字体'
                                              : '界面启用主题时覆盖应用自定义字体',
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const Spacer(),
                TextButton(
                  onPressed:
                      () => unawaited(
                        _openRouteFromSheet(context, '/font-management'),
                      ),
                  child: const Text('去管理'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed:
                      selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(
                            const _ThemeFontSelectionResult(
                              applied: true,
                              familyKey: null,
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
                            _ThemeFontSelectionResult(
                              applied: true,
                              familyKey: selectedId,
                            ),
                          ),
                  child: const Text('应用'),
                ),
              ],
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
          result.familyKey == null
              ? (readerFont
                  ? draft.copyWith(clearReaderFontFamilyKey: true)
                  : draft.copyWith(clearAppInterfaceFontFamilyKey: true))
              : (readerFont
                  ? draft.copyWith(readerFontFamilyKey: result.familyKey)
                  : draft.copyWith(
                    appInterfaceFontFamilyKey: result.familyKey,
                  ));
    });
  }

  File _resolveLocalImageFile(String path) {
    final normalized = path.trim();
    if (normalized.startsWith('file://')) {
      return File(Uri.parse(normalized).toFilePath());
    }
    return File(normalized);
  }

  String? _resolveExistingLocalImagePath(String? path) {
    final normalized = path?.trim() ?? '';
    if (normalized.startsWith('assets/')) {
      return normalized;
    }
    return _pathResolver.tryResolveExistingFilePathSync(path);
  }

  Widget _buildResolvedImage(
    String path, {
    required BoxFit fit,
    FilterQuality filterQuality = FilterQuality.medium,
  }) {
    final normalized = path.trim();
    if (normalized.startsWith('assets/')) {
      return Image.asset(normalized, fit: fit, filterQuality: filterQuality);
    }
    return Image.file(
      _resolveLocalImageFile(normalized),
      fit: fit,
      filterQuality: filterQuality,
    );
  }

  List<String> _existingImagePaths(Iterable<String> imagePaths) {
    final existing = <String>[];
    for (final rawPath in imagePaths) {
      final resolved = _resolveExistingLocalImagePath(rawPath);
      if (resolved != null) {
        existing.add(resolved);
      }
    }
    return existing;
  }

  Future<void> _showImagePreviewDialog({
    required String imagePath,
    required String title,
  }) async {
    final resolvedPath = _resolveExistingLocalImagePath(imagePath);
    if (resolvedPath == null) {
      return;
    }
    await showAdaptiveFullscreenPreview<void>(
      context: context,
      title: title,
      helperText: '双指缩放，拖动查看细节',
      builder: (dialogContext) {
        return _buildResolvedImage(
          resolvedPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      },
    );
  }

  Widget _buildResourcePickerSheet(
    BuildContext context, {
    required String title,
    required Widget content,
    required List<Widget> actions,
    String? helperText,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height:
          MediaQuery.sizeOf(context).height * _resourcePickerSheetHeightFactor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (helperText != null && helperText.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                helperText,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(child: content),
            const SizedBox(height: 12),
            Row(children: actions),
          ],
        ),
      ),
    );
  }

  AppAdvancedThemeModeConfig _defaultModeConfigForMode(
    AppAdvancedThemeMode mode,
  ) {
    final seedColor = ref.read(appSeedColorProvider);
    return switch (mode) {
      AppAdvancedThemeMode.light => buildDefaultAdvancedThemeModeConfig(
        buildAppLightColorScheme(seedColor),
      ),
      AppAdvancedThemeMode.dark => buildDefaultAdvancedThemeModeConfig(
        buildAppDarkColorScheme(seedColor),
      ),
    };
  }

  Widget _buildEmptyResourceState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSelectionGrid(
    BuildContext context, {
    required List<String> imagePaths,
    required String? selectedPath,
    required String Function(String imagePath) titleBuilder,
    required ValueChanged<String> onSelected,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = AppLayout.optionGridColumnsForWidth(
          constraints.maxWidth,
        ).clamp(3, 5);
        return GridView.builder(
          itemCount: imagePaths.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 1 / 1.28,
          ),
          itemBuilder: (context, index) {
            final path = imagePaths[index];
            return _buildSelectableImageTile(
              context,
              imagePath: path,
              title: titleBuilder(path),
              selected: path == selectedPath,
              onTap: () => onSelected(path),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectableImageTile(
    BuildContext context, {
    required String imagePath,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final file = _resolveLocalImageFile(imagePath);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress:
            () => unawaited(
              _showImagePreviewDialog(imagePath: file.path, title: title),
            ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        selected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant.withValues(
                              alpha: 0.45,
                            ),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(file, fit: BoxFit.cover),
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
      ),
    );
  }

  Widget _buildLaunchGallerySelectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> previewPaths,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color:
                selected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.46)
                    : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.45),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: Row(
                  children: List.generate(3, (index) {
                    final previewPath =
                        index < previewPaths.length
                            ? previewPaths[index]
                            : null;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
                        child: SizedBox(
                          height: 96,
                          child: _buildGalleryPreviewThumb(
                            context,
                            previewPath: previewPath,
                            title: title,
                            width: double.infinity,
                            height: 96,
                            borderRadius: 12,
                            onTap: onTap,
                            onLongPress:
                                previewPath == null
                                    ? null
                                    : () => unawaited(
                                      _showImagePreviewDialog(
                                        imagePath: previewPath,
                                        title: title,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryPreviewThumb(
    BuildContext context, {
    required String? previewPath,
    required String title,
    double width = 34,
    double height = 48,
    double borderRadius = 8,
    bool useAddPlaceholder = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    late final Widget child;
    if (previewPath == null || previewPath.isEmpty) {
      if (useAddPlaceholder) {
        child = Container(
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
      } else {
        child = SizedBox(
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
    } else {
      child = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: _buildResolvedImage(previewPath, fit: BoxFit.cover),
        ),
      );
    }

    if (onTap == null && onLongPress == null) {
      return child;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }

  void _setWallpaperOverlayOpacity(double value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final currentConfig = draft.configFor(_selectedMode);
    final normalized = value.clamp(0.0, 1.0).toDouble();
    if ((currentConfig.wallpaperOverlayOpacity - normalized).abs() < 0.0001) {
      return;
    }
    setState(() {
      _draft = draft.copyWithModeConfig(
        _selectedMode,
        currentConfig.copyWith(wallpaperOverlayOpacity: normalized),
      );
    });
  }

  void _setWallpaperOpacity(double value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final currentConfig = draft.configFor(_selectedMode);
    final normalized = value.clamp(0.0, 1.0).toDouble();
    if ((currentConfig.wallpaperOpacity - normalized).abs() < 0.0001) {
      return;
    }
    setState(() {
      _draft = draft.copyWithModeConfig(
        _selectedMode,
        currentConfig.copyWith(wallpaperOpacity: normalized),
      );
    });
  }

  void _setWallpaperBlurSigma(double value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final currentConfig = draft.configFor(_selectedMode);
    final normalized = value.clamp(0.0, 24.0).toDouble();
    if ((currentConfig.wallpaperBlurSigma - normalized).abs() < 0.0001) {
      return;
    }
    setState(() {
      _draft = draft.copyWithModeConfig(
        _selectedMode,
        currentConfig.copyWith(wallpaperBlurSigma: normalized),
      );
    });
  }

  void _setWallpaperFit(AppAdvancedThemeWallpaperFit fit) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final currentConfig = draft.configFor(_selectedMode);
    if (currentConfig.wallpaperFit == fit) {
      return;
    }
    setState(() {
      _draft = draft.copyWithModeConfig(
        _selectedMode,
        currentConfig.copyWith(wallpaperFit: fit),
      );
    });
  }

  void _setReaderWallpaperOverlayOpacity(double value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final currentConfig = draft.configFor(_selectedMode);
    final normalized = value.clamp(0.0, 1.0).toDouble();
    if ((currentConfig.readerWallpaperOverlayOpacity - normalized).abs() <
        0.0001) {
      return;
    }
    setState(() {
      _draft = draft.copyWithModeConfig(
        _selectedMode,
        currentConfig.copyWith(readerWallpaperOverlayOpacity: normalized),
      );
    });
  }

  void _setReaderWallpaperOpacity(double value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final currentConfig = draft.configFor(_selectedMode);
    final normalized = value.clamp(0.0, 1.0).toDouble();
    if ((currentConfig.readerWallpaperOpacity - normalized).abs() < 0.0001) {
      return;
    }
    setState(() {
      _draft = draft.copyWithModeConfig(
        _selectedMode,
        currentConfig.copyWith(readerWallpaperOpacity: normalized),
      );
    });
  }

  void _setReaderWallpaperBlurSigma(double value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final currentConfig = draft.configFor(_selectedMode);
    final normalized = value.clamp(0.0, 24.0).toDouble();
    if ((currentConfig.readerWallpaperBlurSigma - normalized).abs() < 0.0001) {
      return;
    }
    setState(() {
      _draft = draft.copyWithModeConfig(
        _selectedMode,
        currentConfig.copyWith(readerWallpaperBlurSigma: normalized),
      );
    });
  }

  void _setShadowIntensity(double value) {
    if (_isSaving) {
      return;
    }
    final controller = _currentControllers[_ThemeColorSlot.shadow]!;
    final fallback = _fallbackColorForSlot(
      _selectedMode,
      _ThemeColorSlot.shadow,
    );
    final currentColor = _resolvedColor(
      _parseHexColor(controller.text.trim()),
      fallback,
    );
    final normalized = value.clamp(0.0, 1.0).toDouble();
    if ((currentColor.a - normalized).abs() < 0.001) {
      return;
    }
    controller.text = _formatHex(
      currentColor.withValues(alpha: normalized).toARGB32(),
    );
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
    final fallback = _fallbackColorForSlot(_selectedMode, slot);
    final selected = await _showColorPickerDialog(
      context,
      title: slot.label,
      initialColorValue: current ?? fallback.toARGB32(),
    );
    if (selected == null || !mounted) {
      return;
    }
    controller.text = _formatHex(selected);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final desktopLike = AppLayout.isDesktopLike(
      context,
      platform: theme.platform,
    );
    final panelRadius = BorderRadius.vertical(
      top: const Radius.circular(28),
      bottom: desktopLike ? const Radius.circular(28) : Radius.zero,
    );

    final result = await showAdaptiveRawSurface<int>(
      context: context,
      showDragHandle: false,
      mobileBackgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Material(
              color: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(borderRadius: panelRadius),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!desktopLike) ...[
                      const AdaptiveSheetDragHandle(),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '选择$title',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _showMessage('吸管取色需要系统截图权限，后续接入。');
                          },
                          tooltip: '吸管取色',
                          icon: const Icon(Icons.colorize_rounded),
                        ),
                        FilledButton.tonal(
                          onPressed:
                              () => Navigator.of(
                                dialogContext,
                              ).pop(draftColor.toARGB32()),
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
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
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                        hintText: '#RRGGBB / #AARRGGBB',
                        filled: true,
                        fillColor: colorScheme.surface.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ColorPicker(
                      pickerColor: draftColor,
                      onColorChanged: (color) {
                        setDialogState(() {
                          draftColor = color;
                        });
                      },
                      enableAlpha: true,
                      displayThumbColor: true,
                      portraitOnly: true,
                      paletteType: PaletteType.hsvWithHue,
                      colorPickerWidth: 360,
                      pickerAreaHeightPercent: 0.62,
                      pickerAreaBorderRadius: const BorderRadius.all(
                        Radius.circular(12),
                      ),
                      labelTypes: const [],
                      hexInputController: hexController,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: draftColor,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: colorScheme.outline.withValues(
                                alpha: 0.38,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _formatHex(draftColor.toARGB32()),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '上方色板调明度和饱和度，第一条调色相，第二条调透明度。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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
    final topInset =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 42 + 6;
    final draft = _draft;
    final theme = Theme.of(context);
    const sectionGap = 8.0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
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
          preferredSize: const Size.fromHeight(42),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow.withValues(
                  alpha: 0.9,
                ),
                borderRadius: BorderRadius.circular(10),
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
                  color: theme.colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                indicatorPadding: const EdgeInsets.all(3),
                labelColor: theme.colorScheme.onSurface,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.light_mode_outlined, size: 16),
                        SizedBox(width: 4),
                        Text('浅色主题'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dark_mode_outlined, size: 16),
                        SizedBox(width: 4),
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
      body: ValueListenableBuilder<int>(
        valueListenable: _colorPreviewRevision,
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
                        ? const Center(
                          key: ValueKey<String>('advanced_theme_loading'),
                          child: CircularProgressIndicator(),
                        )
                        : draft == null
                        ? const Center(
                          key: ValueKey<String>('advanced_theme_missing'),
                          child: Text('高级主题不存在'),
                        )
                        : AppFadeSlideTransition(
                          key: const ValueKey<String>('advanced_theme_editor'),
                          child: ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              topInset,
                              horizontal,
                              10 + bottomSafe,
                            ),
                            children: [
                              _buildColorsSection(context),
                              const SizedBox(height: sectionGap),
                              _buildComponentStylesSection(context, draft),
                              const SizedBox(height: sectionGap),
                              _buildResourceSection(context, draft),
                            ],
                          ),
                        ),
              ),
            );
          },
        ),
        builder: (context, _, child) {
          final editorBackdrop =
              draft == null
                  ? null
                  : resolveAdvancedThemeBackdropFromModeConfig(
                    theme.colorScheme,
                    _previewModeConfig(context, draft, _selectedMode),
                  );
          return DecoratedBox(
            decoration:
                editorBackdrop == null
                    ? const BoxDecoration()
                    : buildAdvancedThemeBackdropDecoration(editorBackdrop),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildColorsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (
          var index = 0;
          index < themeSemanticEditorGroups.length;
          index++
        ) ...[
          _buildThemeFieldSection(
            context,
            title: themeSemanticEditorGroups[index].title,
            tooltipMessage: themeSemanticEditorGroups[index].subtitle,
            fields: _fieldSpecsForGroup(themeSemanticEditorGroups[index]),
          ),
          const SizedBox(height: 8),
        ],
        _buildExpandableColorSection(
          context,
          title: '强度层',
          tooltipMessage: '卡片阴影、壁纸透明度、模糊和遮罩强度',
          expanded: _strengthControlsExpanded,
          onToggle: () {
            setState(() {
              _strengthControlsExpanded = !_strengthControlsExpanded;
            });
          },
          child: _buildStrengthSection(context),
        ),
      ],
    );
  }

  Widget _buildThemeFieldSection(
    BuildContext context, {
    required String title,
    required String tooltipMessage,
    required List<_ThemeColorFieldSpec> fields,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, title, tooltipMessage: tooltipMessage),
        const SizedBox(height: 4),
        _buildListSectionBody(
          context,
          child: Column(children: _buildColorFieldRows(context, fields)),
        ),
      ],
    );
  }

  List<_ThemeColorFieldSpec> _fieldSpecsForGroup(ThemeSemanticGroupSpec group) {
    return group.fields
        .map(
          (field) => _ThemeColorFieldSpec(
            slot: _slotForThemeSemanticField(field.id),
            label: field.label,
            description: field.description,
            scopeLabels: field.scopeLabels,
          ),
        )
        .toList(growable: false);
  }

  Widget _buildStrengthSection(BuildContext context) {
    final draft = _draft;
    if (draft == null) {
      return const SizedBox.shrink();
    }
    final currentConfig = draft.configFor(_selectedMode);
    final shadowColor = _resolvedColor(
      _parseHexColor(_currentControllers[_ThemeColorSlot.shadow]!.text.trim()),
      _fallbackColorForSlot(_selectedMode, _ThemeColorSlot.shadow),
    );
    return _buildListSectionBody(
      context,
      child: Column(
        children: [
          _buildStrengthSliderRow(
            context,
            label: '卡片阴影强度',
            valueLabel: '${(shadowColor.a * 100).round()}%',
            value: shadowColor.a,
            min: 0,
            max: 1,
            onChanged: _isSaving ? null : _setShadowIntensity,
          ),
          const Divider(height: 1),
          _buildWallpaperOverlayOpacityRow(
            context,
            opacity: currentConfig.wallpaperOverlayOpacity,
          ),
          const Divider(height: 1),
          _buildWallpaperOpacityRow(
            context,
            opacity: currentConfig.wallpaperOpacity,
          ),
          const Divider(height: 1),
          _buildWallpaperBlurRow(
            context,
            blurSigma: currentConfig.wallpaperBlurSigma,
          ),
          const Divider(height: 1),
          _buildReaderWallpaperOverlayOpacityRow(
            context,
            opacity: currentConfig.readerWallpaperOverlayOpacity,
          ),
          const Divider(height: 1),
          _buildReaderWallpaperOpacityRow(
            context,
            opacity: currentConfig.readerWallpaperOpacity,
          ),
          const Divider(height: 1),
          _buildReaderWallpaperBlurRow(
            context,
            blurSigma: currentConfig.readerWallpaperBlurSigma,
          ),
        ],
      ),
    );
  }

  Widget _buildComponentStylesSection(
    BuildContext context,
    AppAdvancedTheme draft,
  ) {
    final style = _sharedComponentStyle(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          context,
          '组件风格',
          tooltipMessage: '以下配置按全局共享生效：浅色和深色保持同一套组件结构风格。',
        ),
        const SizedBox(height: 4),
        _buildListSectionBody(
          context,
          child: Column(
            children: [
              _buildStrengthSliderRow(
                context,
                label: '全局圆角',
                valueLabel: style.globalRadiusScale.toStringAsFixed(2),
                value: style.globalRadiusScale,
                min: 0.72,
                max: 1.45,
                divisions: 73,
                onChanged: _isSaving ? null : _setGlobalRadiusScale,
              ),
              const Divider(height: 1),
              _buildStrengthSliderRow(
                context,
                label: '阴影强度',
                valueLabel: '${(style.shadowStrength * 100).round()}%',
                value: style.shadowStrength,
                min: 0.1,
                max: 1,
                divisions: 90,
                onChanged: _isSaving ? null : _setComponentShadowStrength,
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeCardStyle>(
                context,
                label: '卡片风格',
                value: style.cardStyle,
                options:
                    const <_ComponentStyleOption<AppAdvancedThemeCardStyle>>[
                      _ComponentStyleOption(
                        value: AppAdvancedThemeCardStyle.soft,
                        label: '柔和',
                      ),
                      _ComponentStyleOption(
                        value: AppAdvancedThemeCardStyle.outlined,
                        label: '描边',
                      ),
                      _ComponentStyleOption(
                        value: AppAdvancedThemeCardStyle.elevated,
                        label: '抬升',
                      ),
                    ],
                onChanged: _setCardStyle,
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeButtonStyle>(
                context,
                label: '按钮风格',
                value: style.buttonStyle,
                options:
                    const <_ComponentStyleOption<AppAdvancedThemeButtonStyle>>[
                      _ComponentStyleOption(
                        value: AppAdvancedThemeButtonStyle.stadium,
                        label: '胶囊',
                      ),
                      _ComponentStyleOption(
                        value: AppAdvancedThemeButtonStyle.rounded,
                        label: '圆角',
                      ),
                      _ComponentStyleOption(
                        value: AppAdvancedThemeButtonStyle.sharp,
                        label: '利落',
                      ),
                    ],
                onChanged: _setButtonStyle,
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeInputStyle>(
                context,
                label: '输入框风格',
                value: style.inputStyle,
                options:
                    const <_ComponentStyleOption<AppAdvancedThemeInputStyle>>[
                      _ComponentStyleOption(
                        value: AppAdvancedThemeInputStyle.soft,
                        label: '柔和',
                      ),
                      _ComponentStyleOption(
                        value: AppAdvancedThemeInputStyle.outlined,
                        label: '描边',
                      ),
                      _ComponentStyleOption(
                        value: AppAdvancedThemeInputStyle.underlined,
                        label: '扁平',
                      ),
                    ],
                onChanged: _setInputStyle,
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeOverlayStyle>(
                context,
                label: '弹层风格',
                value: style.overlayStyle,
                options:
                    const <_ComponentStyleOption<AppAdvancedThemeOverlayStyle>>[
                      _ComponentStyleOption(
                        value: AppAdvancedThemeOverlayStyle.comfortable,
                        label: '舒展',
                      ),
                      _ComponentStyleOption(
                        value: AppAdvancedThemeOverlayStyle.compact,
                        label: '紧凑',
                      ),
                    ],
                onChanged: _setOverlayStyle,
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeNavigationStyle>(
                context,
                label: '导航栏风格',
                value: style.navigationStyle,
                options: const <
                  _ComponentStyleOption<AppAdvancedThemeNavigationStyle>
                >[
                  _ComponentStyleOption(
                    value: AppAdvancedThemeNavigationStyle.soft,
                    label: '默认',
                  ),
                  _ComponentStyleOption(
                    value: AppAdvancedThemeNavigationStyle.floating,
                    label: '浮层',
                  ),
                  _ComponentStyleOption(
                    value: AppAdvancedThemeNavigationStyle.compact,
                    label: '紧凑',
                  ),
                ],
                onChanged: _setNavigationStyle,
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeSwitchStyle>(
                context,
                label: '切换风格',
                value: style.switchStyle,
                options:
                    const <_ComponentStyleOption<AppAdvancedThemeSwitchStyle>>[
                      _ComponentStyleOption(
                        value: AppAdvancedThemeSwitchStyle.soft,
                        label: '柔和',
                      ),
                      _ComponentStyleOption(
                        value: AppAdvancedThemeSwitchStyle.contrast,
                        label: '高对比',
                      ),
                    ],
                onChanged: _setSwitchStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComponentStyleChoiceRow<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<_ComponentStyleOption<T>> options,
    required ValueChanged<T> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in options)
                  _buildStyleChoiceChip(
                    context,
                    label: option.label,
                    selected: option.value == value,
                    onTap: _isSaving ? null : () => onChanged(option.value),
                    colorScheme: colorScheme,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleChoiceChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor:
              selected ? colorScheme.primaryContainer : colorScheme.surface,
          foregroundColor:
              selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
          side: BorderSide(
            color:
                selected
                    ? colorScheme.primary.withValues(alpha: 0.58)
                    : colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  AppAdvancedThemeComponentStyle _sharedComponentStyle(AppAdvancedTheme draft) {
    return draft.lightConfig.componentStyle;
  }

  void _updateSharedComponentStyle(AppAdvancedThemeComponentStyle style) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    setState(() {
      _draft = draft.copyWith(
        lightConfig: draft.lightConfig.copyWith(componentStyle: style),
        darkConfig: draft.darkConfig.copyWith(componentStyle: style),
      );
    });
    _colorPreviewRevision.value++;
  }

  void _setGlobalRadiusScale(double value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final style = _sharedComponentStyle(draft);
    _updateSharedComponentStyle(
      style.copyWith(globalRadiusScale: value.clamp(0.72, 1.45).toDouble()),
    );
  }

  void _setComponentShadowStrength(double value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final style = _sharedComponentStyle(draft);
    _updateSharedComponentStyle(
      style.copyWith(shadowStrength: value.clamp(0.1, 1).toDouble()),
    );
  }

  void _setCardStyle(AppAdvancedThemeCardStyle value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    _updateSharedComponentStyle(
      _sharedComponentStyle(draft).copyWith(cardStyle: value),
    );
  }

  void _setButtonStyle(AppAdvancedThemeButtonStyle value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    _updateSharedComponentStyle(
      _sharedComponentStyle(draft).copyWith(buttonStyle: value),
    );
  }

  void _setInputStyle(AppAdvancedThemeInputStyle value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    _updateSharedComponentStyle(
      _sharedComponentStyle(draft).copyWith(inputStyle: value),
    );
  }

  void _setOverlayStyle(AppAdvancedThemeOverlayStyle value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    _updateSharedComponentStyle(
      _sharedComponentStyle(draft).copyWith(overlayStyle: value),
    );
  }

  void _setNavigationStyle(AppAdvancedThemeNavigationStyle value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    _updateSharedComponentStyle(
      _sharedComponentStyle(draft).copyWith(navigationStyle: value),
    );
  }

  void _setSwitchStyle(AppAdvancedThemeSwitchStyle value) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    _updateSharedComponentStyle(
      _sharedComponentStyle(draft).copyWith(switchStyle: value),
    );
  }

  Widget _buildResourceSection(BuildContext context, AppAdvancedTheme draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '资源层'),
        const SizedBox(height: 4),
        _buildVisualResourceSection(context, draft),
        const SizedBox(height: 10),
        _buildStyleResourceSection(context, draft),
      ],
    );
  }

  Widget _buildVisualResourceSection(
    BuildContext context,
    AppAdvancedTheme draft,
  ) {
    final wallpaperPath = _selectedWallpaperPreviewPath(draft);
    final readerWallpaperPath = _selectedReaderWallpaperPreviewPath(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '视觉资源'),
        const SizedBox(height: 4),
        _buildPanel(
          context,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildVisualResourceCard(
                      context,
                      title: '壁纸',
                      subtitle: wallpaperPath == null ? '未设置' : '已设置',
                      preview: _buildGalleryPreviewThumb(
                        context,
                        previewPath: wallpaperPath,
                        title: '壁纸',
                        width: 72,
                        height: 72,
                        borderRadius: 12,
                        useAddPlaceholder: true,
                        onLongPress:
                            wallpaperPath == null
                                ? null
                                : () => unawaited(
                                  _showImagePreviewDialog(
                                    imagePath: wallpaperPath,
                                    title: '壁纸',
                                  ),
                                ),
                      ),
                      onTap:
                          _isSaving
                              ? () {}
                              : _pickWallpaperFromBackgroundLibrary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildVisualResourceCard(
                      context,
                      title: '阅读背景',
                      subtitle: readerWallpaperPath == null ? '未设置' : '已设置',
                      preview: _buildGalleryPreviewThumb(
                        context,
                        previewPath: readerWallpaperPath,
                        title: '阅读器背景',
                        width: 72,
                        height: 72,
                        borderRadius: 12,
                        useAddPlaceholder: true,
                        onLongPress:
                            readerWallpaperPath == null
                                ? null
                                : () => unawaited(
                                  _showImagePreviewDialog(
                                    imagePath: readerWallpaperPath,
                                    title: '阅读器背景',
                                  ),
                                ),
                      ),
                      onTap:
                          _isSaving
                              ? () {}
                              : _pickReaderWallpaperFromBackgroundLibrary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildVisualResourceCard(
                      context,
                      title: '封面',
                      subtitle:
                          _selectedCoverGalleryPreviewPath() == null
                              ? '未绑定'
                              : '已绑定',
                      preview: _buildGalleryPreviewThumb(
                        context,
                        previewPath: _selectedCoverGalleryPreviewPath(),
                        title: _selectedCoverGallery()?.name ?? '封面图集',
                        width: 72,
                        height: 72,
                        borderRadius: 12,
                        useAddPlaceholder: true,
                        onLongPress:
                            _selectedCoverGalleryPreviewPath() == null
                                ? null
                                : () => unawaited(
                                  _showImagePreviewDialog(
                                    imagePath:
                                        _selectedCoverGalleryPreviewPath()!,
                                    title:
                                        _selectedCoverGallery()?.name ?? '封面图集',
                                  ),
                                ),
                      ),
                      onTap: _pickCoverGallery,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildVisualResourceCard(
                      context,
                      title: '启动图',
                      subtitle:
                          _selectedLaunchImageGalleryPreviewPath() == null
                              ? '未绑定'
                              : '已绑定',
                      preview: _buildGalleryPreviewThumb(
                        context,
                        previewPath: _selectedLaunchImageGalleryPreviewPath(),
                        title: _selectedLaunchImageGallery()?.name ?? '启动图集',
                        width: 72,
                        height: 72,
                        borderRadius: 12,
                        useAddPlaceholder: true,
                        onLongPress:
                            _selectedLaunchImageGalleryPreviewPath() == null
                                ? null
                                : () => unawaited(
                                  _showImagePreviewDialog(
                                    imagePath:
                                        _selectedLaunchImageGalleryPreviewPath()!,
                                    title:
                                        _selectedLaunchImageGallery()?.name ??
                                        '启动图集',
                                  ),
                                ),
                      ),
                      onTap: _pickLaunchImageGallery,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStyleResourceSection(
    BuildContext context,
    AppAdvancedTheme draft,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '风格组件'),
        const SizedBox(height: 4),
        _buildPanel(
          context,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            children: [
              _buildAppearanceLinkTile(
                context,
                icon: Icons.dashboard_outlined,
                title: '底栏',
                subtitle: _resolvedBottomNavGalleryName(),
                onTap: _pickBottomNavGallery,
              ),
              const Divider(height: 1),
              _buildAppearanceLinkTile(
                context,
                icon: Icons.text_fields_rounded,
                title: '界面字体',
                subtitle: _resolvedAppInterfaceFontName(),
                onTap: () => _pickThemeFont(readerFont: false),
              ),
              const Divider(height: 1),
              _buildAppearanceLinkTile(
                context,
                icon: Icons.menu_book_outlined,
                title: '阅读字体',
                subtitle: _resolvedReaderFontName(),
                onTap: () => _pickThemeFont(readerFont: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisualResourceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget preview,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.34),
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Center(child: preview),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWallpaperOverlayOpacityRow(
    BuildContext context, {
    required double opacity,
  }) {
    final normalizedOpacity = opacity.clamp(0.0, 1.0).toDouble();
    return _buildStrengthSliderRow(
      context,
      label: '壁纸遮罩透明度',
      valueLabel: '${(normalizedOpacity * 100).round()}%',
      value: normalizedOpacity,
      min: 0,
      max: 1,
      onChanged: _isSaving ? null : _setWallpaperOverlayOpacity,
    );
  }

  Widget _buildWallpaperOpacityRow(
    BuildContext context, {
    required double opacity,
  }) {
    final normalizedOpacity = opacity.clamp(0.0, 1.0).toDouble();
    return _buildStrengthSliderRow(
      context,
      label: '壁纸不透明度',
      valueLabel: '${(normalizedOpacity * 100).round()}%',
      value: normalizedOpacity,
      min: 0,
      max: 1,
      onChanged: _isSaving ? null : _setWallpaperOpacity,
    );
  }

  Widget _buildWallpaperBlurRow(
    BuildContext context, {
    required double blurSigma,
  }) {
    final normalizedBlur = blurSigma.clamp(0.0, 24.0).toDouble();
    final blurLabel = normalizedBlur.toStringAsFixed(0);
    return _buildStrengthSliderRow(
      context,
      label: '壁纸模糊程度',
      valueLabel: blurLabel,
      value: normalizedBlur,
      min: 0,
      max: 24,
      divisions: 24,
      onChanged: _isSaving ? null : _setWallpaperBlurSigma,
    );
  }

  Widget _buildReaderWallpaperOverlayOpacityRow(
    BuildContext context, {
    required double opacity,
  }) {
    final normalizedOpacity = opacity.clamp(0.0, 1.0).toDouble();
    return _buildStrengthSliderRow(
      context,
      label: '阅读器遮罩透明度',
      valueLabel: '${(normalizedOpacity * 100).round()}%',
      value: normalizedOpacity,
      min: 0,
      max: 1,
      onChanged: _isSaving ? null : _setReaderWallpaperOverlayOpacity,
    );
  }

  Widget _buildReaderWallpaperOpacityRow(
    BuildContext context, {
    required double opacity,
  }) {
    final normalizedOpacity = opacity.clamp(0.0, 1.0).toDouble();
    return _buildStrengthSliderRow(
      context,
      label: '阅读器背景不透明度',
      valueLabel: '${(normalizedOpacity * 100).round()}%',
      value: normalizedOpacity,
      min: 0,
      max: 1,
      onChanged: _isSaving ? null : _setReaderWallpaperOpacity,
    );
  }

  Widget _buildReaderWallpaperBlurRow(
    BuildContext context, {
    required double blurSigma,
  }) {
    final normalizedBlur = blurSigma.clamp(0.0, 24.0).toDouble();
    return _buildStrengthSliderRow(
      context,
      label: '阅读器背景模糊程度',
      valueLabel: normalizedBlur.toStringAsFixed(0),
      value: normalizedBlur,
      min: 0,
      max: 24,
      divisions: 24,
      onChanged: _isSaving ? null : _setReaderWallpaperBlurSigma,
    );
  }

  Widget _buildCompactFitRow(
    BuildContext context, {
    required String label,
    required AppAdvancedThemeWallpaperFit fit,
    required ValueChanged<AppAdvancedThemeWallpaperFit>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFitChoiceButton(
                context,
                label: '拉伸填充',
                selected: fit == AppAdvancedThemeWallpaperFit.fill,
                onPressed:
                    onChanged == null
                        ? null
                        : () => onChanged(AppAdvancedThemeWallpaperFit.fill),
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 6),
              _buildFitChoiceButton(
                context,
                label: '居中裁剪',
                selected: fit == AppAdvancedThemeWallpaperFit.cover,
                onPressed:
                    onChanged == null
                        ? null
                        : () => onChanged(AppAdvancedThemeWallpaperFit.cover),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthSliderRow(
    BuildContext context, {
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayLabel = _sliderDisplayLabel(label);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 30,
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 55,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor: colorScheme.outlineVariant.withValues(
                  alpha: 0.4,
                ),
                thumbColor: colorScheme.primary,
                overlayColor: colorScheme.primary.withValues(alpha: 0.12),
                trackHeight: 3,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 15,
            child: Text(
              valueLabel,
              textAlign: TextAlign.end,
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

  String _sliderDisplayLabel(String label) {
    return switch (label) {
      '卡片阴影强度' => '阴影强度',
      '壁纸遮罩透明度' => '壁纸遮罩',
      '壁纸不透明度' => '壁纸透明度',
      '壁纸模糊程度' => '壁纸模糊',
      '阅读器遮罩透明度' => '阅读器遮罩',
      '阅读器背景不透明度' => '阅读器透明度',
      '阅读器背景模糊程度' => '阅读器模糊',
      _ => label,
    };
  }

  Widget _buildFitChoiceButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback? onPressed,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor:
              selected ? colorScheme.primaryContainer : colorScheme.surface,
          foregroundColor:
              selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
          side: BorderSide(
            color:
                selected
                    ? colorScheme.primary.withValues(alpha: 0.6)
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildAppearanceLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showSubtitle = true,
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
                  if (showSubtitle) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
    final fallback = _fallbackColorForSlot(_selectedMode, slot);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, _, __) {
        final parsed = _parseHexColor(controller.text.trim());
        final previewColor = _resolvedColor(parsed, fallback);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            field.label,
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (field.tooltipMessage.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _buildInlineTooltipIcon(
                            context,
                            field.tooltipMessage,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 136,
                child: TextField(
                  controller: controller,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: _formatHex(fallback.toARGB32()),
                    hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.2,
                      ),
                    ),
                    suffixIcon: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _isSaving ? null : () => _pickColorForSlot(slot),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(5, 5, 7, 5),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: previewColor,
                            borderRadius: BorderRadius.circular(4),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String title, {
    String? tooltipMessage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (tooltipMessage != null && tooltipMessage.trim().isNotEmpty) ...[
            const SizedBox(width: 4),
            _buildInlineTooltipIcon(context, tooltipMessage),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineTooltipIcon(BuildContext context, String message) {
    return _InfoTooltipIcon(message: message);
  }

  Widget _buildExpandableSectionHeader(
    BuildContext context, {
    required String title,
    String? tooltipMessage,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (tooltipMessage != null &&
                      tooltipMessage.trim().isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _buildInlineTooltipIcon(context, tooltipMessage),
                  ],
                ],
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableColorSection(
    BuildContext context, {
    required String title,
    String? tooltipMessage,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableSectionHeader(
          context,
          title: title,
          tooltipMessage: tooltipMessage,
          expanded: expanded,
          onToggle: onToggle,
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState:
              expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: child,
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required Widget child,
    Color? backgroundColor,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }

  Widget _buildListSectionBody(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: child,
    );
  }

  Map<_ThemeColorSlot, TextEditingController> get _currentControllers {
    return _colorControllersByMode[_selectedMode]!;
  }

  _ThemeColorSlot _slotForThemeSemanticField(ThemeSemanticFieldId id) {
    return switch (id) {
      ThemeSemanticFieldId.accent => _ThemeColorSlot.primary,
      ThemeSemanticFieldId.pageBackground => _ThemeColorSlot.background,
      ThemeSemanticFieldId.modalBackground => _ThemeColorSlot.surface,
      ThemeSemanticFieldId.secondaryBackground =>
        _ThemeColorSlot.elevatedSurface,
      ThemeSemanticFieldId.primaryText => _ThemeColorSlot.textPrimary,
      ThemeSemanticFieldId.secondaryText => _ThemeColorSlot.textSecondary,
      ThemeSemanticFieldId.border => _ThemeColorSlot.outline,
      ThemeSemanticFieldId.cardBackground => _ThemeColorSlot.card,
      ThemeSemanticFieldId.cardText => _ThemeColorSlot.cardText,
      ThemeSemanticFieldId.cardBorder => _ThemeColorSlot.cardBorder,
      ThemeSemanticFieldId.iconBackground => _ThemeColorSlot.iconBackground,
      ThemeSemanticFieldId.emphasisBackground =>
        _ThemeColorSlot.primaryContainer,
      ThemeSemanticFieldId.buttonText => _ThemeColorSlot.buttonText,
      ThemeSemanticFieldId.secondaryAccent => _ThemeColorSlot.secondary,
      ThemeSemanticFieldId.searchFieldBackground =>
        _ThemeColorSlot.searchFieldBackground,
      ThemeSemanticFieldId.noticeAccent => _ThemeColorSlot.noticeAccent,
      ThemeSemanticFieldId.noticeSurface => _ThemeColorSlot.noticeSurface,
      ThemeSemanticFieldId.wallpaperOverlay => _ThemeColorSlot.wallpaperOverlay,
    };
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
        _fallbackColorForSlot(mode, slot),
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

  ResolvedAdvancedThemePalette _resolvedDefaultPaletteForMode(
    AppAdvancedThemeMode mode,
  ) {
    final colorScheme = _colorSchemeForMode(mode);
    return resolveAdvancedThemePaletteFromModeConfig(
      colorScheme,
      _defaultModeConfigForMode(mode),
    );
  }

  ResolvedAdvancedThemeBackdrop _resolvedDefaultBackdropForMode(
    AppAdvancedThemeMode mode,
  ) {
    final colorScheme = _colorSchemeForMode(mode);
    return resolveAdvancedThemeBackdropFromModeConfig(
      colorScheme,
      _defaultModeConfigForMode(mode),
    );
  }

  Color _fallbackColorForSlot(AppAdvancedThemeMode mode, _ThemeColorSlot slot) {
    final palette = _resolvedDefaultPaletteForMode(mode);
    final backdrop = _resolvedDefaultBackdropForMode(mode);
    return switch (slot) {
      _ThemeColorSlot.primary => palette.primaryColor,
      _ThemeColorSlot.secondary => palette.secondaryColor,
      _ThemeColorSlot.noticeAccent => palette.noticeAccentColor,
      _ThemeColorSlot.noticeSurface => palette.noticeSurfaceColor,
      _ThemeColorSlot.primaryContainer => palette.primaryContainerColor,
      _ThemeColorSlot.background => backdrop.backgroundColor,
      _ThemeColorSlot.surface => palette.surfaceColor,
      _ThemeColorSlot.searchFieldBackground =>
        palette.searchFieldBackgroundColor,
      _ThemeColorSlot.elevatedSurface => palette.elevatedSurfaceColor,
      _ThemeColorSlot.card => palette.cardColor,
      _ThemeColorSlot.cardText => palette.cardTextColor,
      _ThemeColorSlot.cardBorder => palette.cardBorderColor,
      _ThemeColorSlot.iconBackground => palette.iconBackgroundColor,
      _ThemeColorSlot.textPrimary => palette.textPrimaryColor,
      _ThemeColorSlot.textSecondary => palette.textSecondaryColor,
      _ThemeColorSlot.buttonText => palette.buttonTextColor,
      _ThemeColorSlot.outline => palette.outlineColor,
      _ThemeColorSlot.shadow => palette.shadowColor,
      _ThemeColorSlot.wallpaperOverlay => backdrop.wallpaperOverlayColor,
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
  primary('强调色', '按钮和链接的颜色'),
  noticeAccent('提示强调', '重要提示和通知强调色'),
  noticeSurface('提示底色', '重要提示块和状态标签的背景色'),
  background('页面背景', '页面底色'),
  surface('弹窗背景', '菜单、弹窗和底部浮层的底色'),
  searchFieldBackground('搜索框背景', '搜索框和搜索触发条的填充颜色'),
  elevatedSurface('次级背景', '分组区域和轻表面的底色'),
  textPrimary('主要文字', '正文和标题的颜色'),
  textSecondary('辅助文字', '提示和说明的颜色'),
  outline('边框', '输入框、分隔线和通用描边颜色'),
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

class _LaunchImageGallerySelectionResult {
  const _LaunchImageGallerySelectionResult({
    required this.applied,
    required this.galleryId,
  });

  final bool applied;
  final String? galleryId;
}

class _WallpaperSelectionResult {
  const _WallpaperSelectionResult({required this.path, required this.fit});

  final String path;
  final AppAdvancedThemeWallpaperFit fit;
}

class _ThemeFontSelectionResult {
  const _ThemeFontSelectionResult({
    required this.applied,
    required this.familyKey,
  });

  final bool applied;
  final String? familyKey;
}

class _ComponentStyleOption<T> {
  const _ComponentStyleOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _ThemeColorFieldSpec {
  const _ThemeColorFieldSpec({
    required this.slot,
    required this.label,
    required this.description,
    required this.scopeLabels,
  });

  final _ThemeColorSlot slot;
  final String label;
  final String description;
  final List<String> scopeLabels;

  String get tooltipMessage {
    final normalizedScopes = scopeLabels
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join(' / ');
    if (normalizedScopes.isEmpty) {
      return description.trim();
    }
    return '${description.trim()}\n影响范围：$normalizedScopes';
  }
}

class _InfoTooltipIcon extends StatefulWidget {
  const _InfoTooltipIcon({required this.message});

  final String message;

  @override
  State<_InfoTooltipIcon> createState() => _InfoTooltipIconState();
}

class _InfoTooltipIconState extends State<_InfoTooltipIcon> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  void _showTooltip() {
    _tooltipKey.currentState?.ensureTooltipVisible();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _showTooltip(),
      child: Tooltip(
        key: _tooltipKey,
        message: widget.message,
        triggerMode: TooltipTriggerMode.tap,
        waitDuration: Duration.zero,
        showDuration: const Duration(seconds: 3),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showTooltip,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.help_outline_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}
