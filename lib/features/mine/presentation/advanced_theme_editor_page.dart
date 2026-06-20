// UI-GOV-EXEMPT-FILE: scaffold list-children
// reason: Phase 10 reviewed this advanced theme editor shell; resource binding logic remains covered by feature tests.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:ambient_effects_container/ambient_effects_container.dart';
import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_component_theme_tokens.dart';
import '../../../app/theme/app_theme_effects.dart';
import '../../../app/theme/app_theme_source_provider.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/adaptive_fullscreen_preview.dart';
import '../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../app/widgets/adaptive_route_top_bar.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/foundation/app_button.dart';
import '../../../app/widgets/foundation/app_feedback.dart';
import '../../../app/widgets/foundation/app_progress.dart';
import '../../../app/widgets/foundation/app_surface.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../../../domain/entities/launch_image_gallery.dart';
import '../../reader/application/reader_font_registry_service.dart';
import '../application/advanced_theme_editor_page_state.dart';
import '../application/advanced_theme_editor_controller.dart';
import '../application/advanced_theme_provider.dart';
import '../application/advanced_theme_editor_resource_service.dart';
import '../application/advanced_theme_editor_state_service.dart';
import '../application/advanced_theme_editor_validation_service.dart';
import '../application/advanced_theme_service.dart';
import '../application/theme_semantic_spec.dart';
import '../providers.dart';
import 'advanced_theme_editor_models.dart';
import 'widgets/advanced_theme_basic_section.dart';
import 'widgets/advanced_theme_editor_shell_widgets.dart';
import 'widgets/advanced_theme_font_section.dart';
import 'widgets/advanced_theme_wallpaper_section.dart';
import 'widgets/advanced_theme_launch_gallery_selection_card.dart';
import 'widgets/advanced_theme_preview_panel.dart';
import 'widgets/advanced_theme_resource_picker_widgets.dart';

part 'advanced_theme_editor_page_flow.dart';
part 'widgets/advanced_theme_color_section.dart';

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

  late final AdvancedThemeService _service;
  late final AdvancedThemeEditorStateService _stateService;
  final AdvancedThemeEditorController _editorController =
      const AdvancedThemeEditorController();
  final AdvancedThemeEditorValidationService _validationService =
      const AdvancedThemeEditorValidationService();
  final AdvancedThemeEditorResourceService _resourceService =
      AdvancedThemeEditorResourceService();
  final TextEditingController _nameController = TextEditingController();
  late final TabController _modeTabController = TabController(
    length: AppAdvancedThemeMode.values.length,
    vsync: this,
  )..addListener(_handleModeTabChanged);
  late final Map<
    AppAdvancedThemeMode,
    Map<AdvancedThemeColorSlot, TextEditingController>
  >
  _colorControllersByMode = {
    for (final mode in AppAdvancedThemeMode.values)
      mode: {
        for (final slot in AdvancedThemeColorSlot.values)
          slot: TextEditingController(),
      },
  };
  final ValueNotifier<int> _colorPreviewRevision = ValueNotifier<int>(0);

  AdvancedThemeEditorPageState get _pageState =>
      ref.read(advancedThemeEditorPageStateProvider);

  AdvancedThemeEditorPageStateNotifier get _pageStateNotifier =>
      ref.read(advancedThemeEditorPageStateProvider.notifier);

  AppAdvancedTheme? get _draft => _pageState.draft;
  set _draft(AppAdvancedTheme? value) {
    _pageStateNotifier.update(
      (state) => _editorController.setDraft(state, value),
    );
  }

  AppAdvancedThemeMode get _selectedMode => _pageState.selectedMode;
  set _selectedMode(AppAdvancedThemeMode value) {
    _pageStateNotifier.update(
      (state) => _editorController.setSelectedMode(state, value),
    );
  }

  List<String> get _backgroundLibraryPaths => _pageState.backgroundLibraryPaths;

  List<String> get _readerBackgroundLibraryPaths =>
      _pageState.readerBackgroundLibraryPaths;

  List<BottomNavIconGallery> get _bottomNavGalleries =>
      _pageState.bottomNavGalleries;

  List<CoverGallery> get _coverGalleries => _pageState.coverGalleries;

  List<LaunchImageGallery> get _launchImageGalleries =>
      _pageState.launchImageGalleries;

  List<ReaderCustomFontEntry> get _availableFonts => _pageState.availableFonts;

  bool get _advancedParametersExpanded => _pageState.componentControlsExpanded;
  set _advancedParametersExpanded(bool value) {
    _pageStateNotifier.update(
      (state) => _editorController.setComponentControlsExpanded(state, value),
    );
  }

  bool get _isEditingName => _pageState.isEditingName;
  set _isEditingName(bool value) {
    _pageStateNotifier.update(
      (state) => _editorController.setEditingName(state, value),
    );
  }

  bool get _isLoading => _pageState.isLoading;
  set _isLoading(bool value) {
    _pageStateNotifier.update(
      (state) => _editorController.setLoading(state, value),
    );
  }

  bool get _isSaving => _pageState.isSaving;
  set _isSaving(bool value) {
    _pageStateNotifier.update(
      (state) => _editorController.setSaving(state, value),
    );
  }

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
    unawaited(
      Future<void>(() async {
        await _initializeDraft();
      }),
    );
    unawaited(
      Future<void>(() async {
        await _loadAppearanceLinks();
      }),
    );
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
    mutation();
    _refreshAdvancedThemeEditorState();
  }

  void _refreshAdvancedThemeEditorState() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleColorControllerChanged() {
    _colorPreviewRevision.value++;
  }

  Future<void> _initializeDraft() => _initializeDraftImpl();

  Future<void> _loadAppearanceLinks() => _loadAppearanceLinksImpl();

  void _syncControllersFromDraft(AppAdvancedTheme theme) {
    _nameController.text = theme.name;
    for (final mode in AppAdvancedThemeMode.values) {
      for (final slot in AdvancedThemeColorSlot.values) {
        _colorControllersByMode[mode]![slot]!
            .text = AdvancedThemeColorCodec.formatHex(
          _valueForSlot(theme.configFor(mode).colors, slot),
        );
      }
    }
  }

  void _commitNameToDraft(String rawName, {bool finishEditing = false}) {
    final normalized = rawName.trim();
    final draft = _draft;
    if (draft == null) {
      return;
    }
    if (normalized.isEmpty) {
      if (finishEditing) {
        _showMessage('请先填写主题名称');
      }
      return;
    }
    _updateAdvancedThemeEditorState(() {
      _draft =
          draft.name == normalized ? draft : draft.copyWith(name: normalized);
      if (finishEditing) {
        _isEditingName = false;
      }
    });
  }

  Future<void> _saveTheme(BuildContext sourceContext) {
    final overlay = CircularThemeRevealOverlay.of(sourceContext);
    final center = CircularThemeRevealOverlay.getCenterFromContext(
      sourceContext,
    );
    return _saveThemeImpl(revealOverlay: overlay, revealCenter: center);
  }

  Future<void> _saveThemeFromCurrentContext() {
    return _saveTheme(context);
  }

  Future<void> _previewTheme() async {
    _showMessage('当前页面背景已实时预览主题效果');
  }

  Future<void> _closeWithReveal(
    BuildContext sourceContext, {
    String? result,
  }) async {
    final overlay = CircularThemeRevealOverlay.of(sourceContext);
    final center = CircularThemeRevealOverlay.getCenterFromContext(
      sourceContext,
    );

    await _closeWithRevealAt(overlay: overlay, center: center, result: result);
  }

  Future<void> _closeWithRevealAt({
    required CircularThemeRevealOverlayState? overlay,
    required Offset center,
    String? result,
  }) async {
    void closeRoute() {
      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop(result);
        return;
      }
      context.go('/appearance/advanced-themes');
    }

    if (overlay == null) {
      closeRoute();
      return;
    }

    await overlay.startTransition(
      center: center,
      reverse: false,
      onThemeChange: closeRoute,
    );
  }

  AppAdvancedThemeColors? _parseColorsForMode(AppAdvancedThemeMode mode) {
    final values = <AdvancedThemeColorSlot, int?>{};
    for (final slot in AdvancedThemeColorSlot.values) {
      final raw = _colorControllersByMode[mode]![slot]!.text.trim();
      final parsed = AdvancedThemeColorCodec.parseHexColor(raw);
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
      primaryColorValue: values[AdvancedThemeColorSlot.primary],
      secondaryColorValue: values[AdvancedThemeColorSlot.secondary],
      noticeAccentColorValue: values[AdvancedThemeColorSlot.noticeAccent],
      noticeSurfaceColorValue: values[AdvancedThemeColorSlot.noticeSurface],
      primaryContainerColorValue:
          values[AdvancedThemeColorSlot.primaryContainer],
      backgroundColorValue: values[AdvancedThemeColorSlot.background],
      surfaceColorValue: values[AdvancedThemeColorSlot.surface],
      searchFieldBackgroundColorValue:
          values[AdvancedThemeColorSlot.searchFieldBackground],
      elevatedSurfaceColorValue: values[AdvancedThemeColorSlot.elevatedSurface],
      cardColorValue: values[AdvancedThemeColorSlot.card],
      cardTextColorValue: values[AdvancedThemeColorSlot.cardText],
      cardBorderColorValue: values[AdvancedThemeColorSlot.cardBorder],
      iconBackgroundColorValue: values[AdvancedThemeColorSlot.iconBackground],
      textPrimaryColorValue: values[AdvancedThemeColorSlot.textPrimary],
      textSecondaryColorValue: values[AdvancedThemeColorSlot.textSecondary],
      buttonTextColorValue: values[AdvancedThemeColorSlot.buttonText],
      outlineColorValue: values[AdvancedThemeColorSlot.outline],
      dividerColorValue: values[AdvancedThemeColorSlot.divider],
      shadowColorValue: values[AdvancedThemeColorSlot.shadow],
      wallpaperOverlayColorValue:
          values[AdvancedThemeColorSlot.wallpaperOverlay],
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
    final result =
        await showAdaptiveActionSurface<AdvancedThemeWallpaperSelectionResult>(
          context: context,
          maxWidth: 720,
          maxHeightFactor: _resourcePickerSheetHeightFactor,
          padding: EdgeInsets.zero,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return _buildResourcePickerSheet(
                  context,
                  title: '选择应用背景',
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
                                  titleBuilder: (_) => '应用背景',
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
                    AppButton(
                      variant: AppButtonVariant.text,
                      onPressed: () => Navigator.of(context).pop(),
                      label: '取消',
                    ),
                    const Spacer(),
                    AppButton(
                      variant: AppButtonVariant.text,
                      onPressed:
                          () => unawaited(
                            _openRouteFromSheet(
                              context,
                              '/appearance?section=background',
                            ),
                          ),
                      label: '去管理',
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      variant: AppButtonVariant.text,
                      onPressed:
                          selectedPath == null
                              ? null
                              : () => Navigator.of(context).pop(
                                const AdvancedThemeWallpaperSelectionResult(
                                  path: null,
                                ),
                              ),
                      label: '取消绑定',
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      onPressed:
                          selectedPath == null
                              ? null
                              : () => Navigator.of(context).pop(
                                AdvancedThemeWallpaperSelectionResult(
                                  path: selectedPath!,
                                  fit: selectedFit,
                                ),
                              ),
                      label: '应用',
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
    if (result.path == null) {
      final draft = _draft;
      if (draft == null) {
        return;
      }
      final currentConfig = draft.configFor(_selectedMode);
      setState(() {
        _draft = draft.copyWithModeConfig(
          _selectedMode,
          currentConfig.copyWith(clearWallpaperPath: true),
        );
      });
      return;
    }
    final picked = await _resourceService.pickedImageFromPath(result.path!);
    if (picked == null) {
      _showMessage('背景图片不存在');
      return;
    }
    await _applyPickedWallpaper(picked);
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
    final result =
        await showAdaptiveActionSurface<AdvancedThemeWallpaperSelectionResult>(
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
                    AppButton(
                      variant: AppButtonVariant.text,
                      onPressed:
                          () => unawaited(
                            _openRouteFromSheet(
                              context,
                              '/appearance/reader-background',
                            ),
                          ),
                      label: '去管理',
                    ),
                    const Spacer(),
                    AppButton(
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                      label: '取消',
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      variant: AppButtonVariant.text,
                      onPressed:
                          selectedPath == null
                              ? null
                              : () => Navigator.of(context).pop(
                                const AdvancedThemeWallpaperSelectionResult(
                                  path: null,
                                ),
                              ),
                      label: '取消绑定',
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      onPressed:
                          selectedPath == null
                              ? null
                              : () => Navigator.of(context).pop(
                                AdvancedThemeWallpaperSelectionResult(
                                  path: selectedPath!,
                                  fit: selectedFit,
                                ),
                              ),
                      label: '应用',
                    ),
                  ],
                );
              },
            );
          },
        );

    if (result == null) {
      return;
    }

    if (draft == null || _isSaving) {
      return;
    }

    final resultPath = result.path?.trim();
    if (resultPath == null || resultPath.isEmpty) {
      final currentConfig = draft.configFor(_selectedMode);
      setState(() {
        _draft = draft.copyWithModeConfig(
          _selectedMode,
          currentConfig.copyWith(clearReaderWallpaperPath: true),
        );
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final nextDraft = await _stateService.applyReaderWallpaper(
        draft: draft,
        mode: _selectedMode,
        sourcePath: resultPath,
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
    String? selectedId = _draft?.bottomNavGalleryId;
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
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(context).pop(),
                  label: '取消',
                ),
                const Spacer(),
                AppButton(
                  onPressed:
                      selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(selectedId),
                  label: '应用',
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
      AdvancedThemeCoverGallerySelectionResult
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
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(context).pop(),
                  label: '取消',
                ),
                const Spacer(),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed:
                      () => unawaited(
                        _openRouteFromSheet(context, '/cover-galleries'),
                      ),
                  label: '去管理',
                ),
                const SizedBox(width: 8),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed:
                      selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(
                            const AdvancedThemeCoverGallerySelectionResult(
                              applied: true,
                              galleryId: null,
                            ),
                          ),
                  label: '取消绑定',
                ),
                const SizedBox(width: 8),
                AppButton(
                  onPressed:
                      selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(
                            AdvancedThemeCoverGallerySelectionResult(
                              applied: true,
                              galleryId: selectedId,
                            ),
                          ),
                  label: '应用',
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
    final result = await showAdaptiveActionSurface<
      AdvancedThemeLaunchImageGallerySelectionResult
    >(
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
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final gallery = _launchImageGalleries[index];
                          return AdvancedThemeLaunchGallerySelectionCard(
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
                            previewThumbBuilder:
                                ({
                                  required previewPath,
                                  required title,
                                  required width,
                                  required height,
                                  required borderRadius,
                                  required onTap,
                                  onLongPress,
                                }) => _buildGalleryPreviewThumb(
                                  context,
                                  previewPath: previewPath,
                                  title: title,
                                  width: width,
                                  height: height,
                                  borderRadius: borderRadius,
                                  onTap: onTap,
                                  onLongPress: onLongPress,
                                ),
                            onPreviewLongPress:
                                (previewPath) => unawaited(
                                  _showImagePreviewDialog(
                                    imagePath: previewPath,
                                    title: gallery.name,
                                  ),
                                ),
                          );
                        },
                      ),
              actions: [
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(context).pop(),
                  label: '取消',
                ),
                const Spacer(),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed:
                      () => unawaited(
                        _openRouteFromSheet(
                          context,
                          '/appearance/launch-image',
                        ),
                      ),
                  label: '去管理',
                ),
                const SizedBox(width: 8),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed:
                      selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(
                            const AdvancedThemeLaunchImageGallerySelectionResult(
                              applied: true,
                              galleryId: null,
                            ),
                          ),
                  label: '取消绑定',
                ),
                const SizedBox(width: 8),
                AppButton(
                  onPressed:
                      selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(
                            AdvancedThemeLaunchImageGallerySelectionResult(
                              applied: true,
                              galleryId: selectedId,
                            ),
                          ),
                  label: '应用',
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

  Future<void> _pickThemeEffect() async {
    if (_isSaving) {
      return;
    }

    var selectedEffect = _draft?.themeEffect ?? AppAdvancedThemeEffect.none;
    final result = await showAdaptiveActionSurface<AppAdvancedThemeEffect>(
      context: context,
      maxWidth: 560,
      maxHeightFactor: 0.56,
      padding: EdgeInsets.zero,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final componentTokens = appComponentThemeTokensOf(context);
        final itemRadius = BorderRadius.all(
          Radius.circular(componentTokens.button.radius),
        );
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildResourcePickerSheet(
              context,
              title: '选择主题特效',
              helperText: '特效跟随高级主题生效，会叠加在应用界面上，不影响点击和滚动。',
              content: ListView.separated(
                itemCount: appAdvancedThemeEffectOptions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final effect = appAdvancedThemeEffectOptions[index];
                  final selected = effect == selectedEffect;
                  return InkWell(
                    borderRadius: itemRadius,
                    onTap: () {
                      setSheetState(() {
                        selectedEffect = effect;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _buildThemeEffectPreviewThumb(
                            context,
                            effect: effect,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              appAdvancedThemeEffectLabel(effect),
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
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(context).pop(),
                  label: '取消',
                ),
                const Spacer(),
                AppButton(
                  onPressed: () => Navigator.of(context).pop(selectedEffect),
                  label: '应用',
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
    final draft = _draft;
    if (draft == null) {
      return;
    }
    setState(() {
      _draft = draft.copyWith(themeEffect: result);
    });
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
    return '未设置';
  }

  BottomNavIconGallery? _selectedBottomNavGallery() {
    final selectedId = _draft?.bottomNavGalleryId?.trim();
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }
    for (final gallery in _bottomNavGalleries) {
      if (gallery.id == selectedId) {
        return gallery;
      }
    }
    return null;
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
    return '未设置';
  }

  String _resolvedReaderFontName() {
    final selected = _selectedReaderFont();
    if (selected != null) {
      return selected.displayName;
    }
    return '未设置';
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
    final result = await showAdaptiveActionSurface<
      AdvancedThemeFontSelectionResult
    >(
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
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(context).pop(),
                  label: '取消',
                ),
                const Spacer(),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed:
                      () => unawaited(
                        _openRouteFromSheet(context, '/font-management'),
                      ),
                  label: '去管理',
                ),
                const SizedBox(width: 8),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed:
                      selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(
                            const AdvancedThemeFontSelectionResult(
                              applied: true,
                              familyKey: null,
                            ),
                          ),
                  label: '取消绑定',
                ),
                const SizedBox(width: 8),
                AppButton(
                  onPressed:
                      selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(
                            AdvancedThemeFontSelectionResult(
                              applied: true,
                              familyKey: selectedId,
                            ),
                          ),
                  label: '应用',
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

  String? _resolveExistingLocalImagePath(String? path) {
    return _resourceService.resolveExistingImagePath(path);
  }

  Widget _buildResolvedImage(
    String path, {
    required BoxFit fit,
    FilterQuality filterQuality = FilterQuality.medium,
  }) {
    return Image(
      image: _resourceService.imageProviderFor(path),
      fit: fit,
      filterQuality: filterQuality,
    );
  }

  List<String> _existingImagePaths(Iterable<String> imagePaths) {
    return _resourceService.existingImagePaths(imagePaths);
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
    return AdvancedThemeResourcePickerSheet(
      title: title,
      content: content,
      actions: actions,
      heightFactor: _resourcePickerSheetHeightFactor,
      helperText: helperText,
    );
  }

  AppAdvancedThemeModeConfig _defaultModeConfigForMode(
    AppAdvancedThemeMode mode,
  ) {
    final activeSnapshot = ref.read(activeThemeAppearanceSnapshotProvider);
    final snapshotConfig =
        mode == AppAdvancedThemeMode.light
            ? activeSnapshot?.lightConfig
            : activeSnapshot?.darkConfig;
    if (snapshotConfig != null) {
      return snapshotConfig;
    }
    return switch (mode) {
      AppAdvancedThemeMode.light => buildDefaultAdvancedThemeModeConfig(
        _colorSchemeForMode(mode),
      ),
      AppAdvancedThemeMode.dark => buildDefaultAdvancedThemeModeConfig(
        _colorSchemeForMode(mode),
      ),
    };
  }

  AppAdvancedThemeModeConfig _previewModeConfig(
    AppAdvancedTheme draft,
    AppAdvancedThemeMode mode,
  ) {
    final currentConfig = draft.configFor(mode);

    Color resolvedSlotColor(AdvancedThemeColorSlot slot) {
      final raw = _colorControllersByMode[mode]![slot]!.text.trim();
      return AdvancedThemeColorCodec.resolvedColor(
        AdvancedThemeColorCodec.parseHexColor(raw),
        _fallbackColorForSlot(mode, slot),
      );
    }

    return currentConfig.copyWith(
      colors: AppAdvancedThemeColors(
        primaryColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.primary).toARGB32(),
        secondaryColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.secondary).toARGB32(),
        noticeAccentColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.noticeAccent).toARGB32(),
        noticeSurfaceColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.noticeSurface).toARGB32(),
        primaryContainerColorValue:
            resolvedSlotColor(
              AdvancedThemeColorSlot.primaryContainer,
            ).toARGB32(),
        backgroundColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.background).toARGB32(),
        surfaceColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.surface).toARGB32(),
        searchFieldBackgroundColorValue:
            resolvedSlotColor(
              AdvancedThemeColorSlot.searchFieldBackground,
            ).toARGB32(),
        elevatedSurfaceColorValue:
            resolvedSlotColor(
              AdvancedThemeColorSlot.elevatedSurface,
            ).toARGB32(),
        cardColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.card).toARGB32(),
        cardTextColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.cardText).toARGB32(),
        cardBorderColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.cardBorder).toARGB32(),
        iconBackgroundColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.iconBackground).toARGB32(),
        textPrimaryColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.textPrimary).toARGB32(),
        textSecondaryColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.textSecondary).toARGB32(),
        buttonTextColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.buttonText).toARGB32(),
        outlineColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.outline).toARGB32(),
        dividerColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.divider).toARGB32(),
        shadowColorValue:
            resolvedSlotColor(AdvancedThemeColorSlot.shadow).toARGB32(),
        wallpaperOverlayColorValue:
            resolvedSlotColor(
              AdvancedThemeColorSlot.wallpaperOverlay,
            ).toARGB32(),
      ),
    );
  }

  Widget _buildEmptyResourceState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return AdvancedThemeEmptyResourceState(
      icon: icon,
      title: title,
      description: description,
    );
  }

  Widget _buildImageSelectionGrid(
    BuildContext context, {
    required List<String> imagePaths,
    required String? selectedPath,
    required String Function(String imagePath) titleBuilder,
    required ValueChanged<String> onSelected,
  }) {
    return AdvancedThemeImageSelectionGrid(
      imagePaths: imagePaths,
      selectedPath: selectedPath,
      titleBuilder: titleBuilder,
      onSelected: onSelected,
      imageBuilder: (context, path, fit) => _buildResolvedImage(path, fit: fit),
      onPreview:
          (imagePath, title) => unawaited(
            _showImagePreviewDialog(imagePath: imagePath, title: title),
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
    return AdvancedThemeGalleryPreviewThumb(
      previewPath: previewPath,
      title: title,
      width: width,
      height: height,
      borderRadius: borderRadius,
      useAddPlaceholder: useAddPlaceholder,
      imageBuilder: (context, path, fit) => _buildResolvedImage(path, fit: fit),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildBottomNavGalleryPreview(
    BuildContext context, {
    required BottomNavIconGallery? gallery,
  }) {
    return AdvancedThemeBottomNavGalleryPreview(gallery: gallery);
  }

  Widget _buildThemeEffectPreviewThumb(
    BuildContext context, {
    required AppAdvancedThemeEffect effect,
    double size = 72,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final componentTokens = appComponentThemeTokensOf(context);
    final radius = BorderRadius.all(
      Radius.circular(componentTokens.card.radius),
    );
    final config = appAmbientEffectConfigFor(effect, preview: true);
    final base = AppSurface(
      padding: EdgeInsets.zero,
      borderRadius: radius,
      backgroundColor: colorScheme.surfaceContainerHighest,
      borderColor: colorScheme.outlineVariant,
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Icon(
          config == null
              ? Icons.motion_photos_off_outlined
              : Icons.auto_awesome_rounded,
          size: size >= 60 ? 22 : 18,
          color:
              config == null
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.primary,
        ),
      ),
    );
    final preview = SizedBox(width: size, height: size, child: base);
    if (config == null) {
      return preview;
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: radius,
        child: AmbientEffectsContainer(
          foregroundEffect: config,
          performanceMode: PerformanceMode.low,
          renderStyle: EffectRenderStyle.layered,
          child: base,
        ),
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

  void _updateComponentStyle(
    AppAdvancedThemeComponentStyle Function(
      AppAdvancedThemeComponentStyle current,
    )
    update,
  ) {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final currentConfig = draft.configFor(_selectedMode);
    setState(() {
      _draft = draft.copyWithModeConfig(
        _selectedMode,
        currentConfig.copyWith(
          componentStyle: update(currentConfig.componentStyle),
        ),
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
    _commitNameToDraft(normalized, finishEditing: true);
  }

  Future<void> _pickColorForSlot(AdvancedThemeColorSlot slot) async {
    final controller = _currentControllers[slot]!;
    final current = AdvancedThemeColorCodec.parseHexColor(
      controller.text.trim(),
    );
    final fallback = _fallbackColorForSlot(_selectedMode, slot);
    final selected = await _showColorPickerDialog(
      context,
      title: slot.label,
      initialColorValue: current ?? fallback.toARGB32(),
    );
    if (selected == null || !mounted) {
      return;
    }
    controller.text = AdvancedThemeColorCodec.formatHex(selected);
  }

  Future<int?> _showColorPickerDialog(
    BuildContext context, {
    required String title,
    required int initialColorValue,
  }) async {
    Color draftColor = Color(initialColorValue);
    final hexController = TextEditingController(
      text: AdvancedThemeColorCodec.formatHex(draftColor.toARGB32()),
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
                        AppButton(
                          variant: AppButtonVariant.tonal,
                          onPressed:
                              () => Navigator.of(
                                dialogContext,
                              ).pop(draftColor.toARGB32()),
                          label: '保存',
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
                        final parsed = AdvancedThemeColorCodec.parseHexColor(
                          value,
                        );
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
                            AdvancedThemeColorCodec.formatHex(
                              draftColor.toARGB32(),
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        AppButton(
                          variant: AppButtonVariant.text,
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          label: '取消',
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
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone:
          message.contains('失败') ? AppFeedbackTone.error : AppFeedbackTone.info,
      useHaptics: false,
    );
  }

  PreferredSizeWidget _buildRouteTopBar(
    BuildContext context,
    AppAdvancedTheme? draft,
  ) {
    final title = draft == null ? '高级主题' : draft.name;
    final colorScheme = Theme.of(context).colorScheme;
    return AdaptiveRouteTopBar(
      title: title,
      subtitle: _modeLabel(_selectedMode),
      titleWidget: AdvancedThemeEditorTitle(
        isEditing: _isEditingName,
        nameController: _nameController,
        title: title,
        onStartEditing: _startEditingName,
        onChanged: _commitNameToDraft,
        onSubmitted: (_) => _finishEditingName(),
      ),
      leading: Builder(
        builder:
            (leadingContext) => IconButton(
              tooltip: '返回',
              onPressed: () => unawaited(_closeWithReveal(leadingContext)),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
      ),
      actions: _buildDesktopTopBarActions(),
      mobileActions: _buildMobileTopBarActions(),
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      dividerColor: Colors.transparent,
      desktopHeight: kToolbarHeight,
      titleMaxWidth: 220,
      bottom: _buildModeTabBar(context),
    );
  }

  List<AdaptiveOverflowToolbarItem> _buildDesktopTopBarActions() {
    return [
      AdaptiveOverflowToolbarItem(
        icon: Icons.save_outlined,
        label: '保存',
        priority: 20,
        enabled: !_isLoading && !_isSaving,
        onPressed:
            _isLoading || _isSaving
                ? null
                : () => unawaited(_saveThemeFromCurrentContext()),
      ),
      AdaptiveOverflowToolbarItem(
        icon: Icons.visibility_outlined,
        label: '预览',
        priority: 10,
        enabled: !_isLoading,
        onPressed: _isLoading ? null : () => unawaited(_previewTheme()),
      ),
      AdaptiveOverflowToolbarItem(
        icon: Icons.check_rounded,
        label: '确认名称',
        enabled: _isEditingName,
        onPressed: _isEditingName ? _finishEditingName : null,
      ),
    ];
  }

  List<Widget> _buildMobileTopBarActions() {
    return [
      if (_isEditingName)
        IconButton(
          tooltip: '确认名称',
          onPressed: _finishEditingName,
          icon: const Icon(Icons.check_rounded),
        ),
      IconButton(
        tooltip: '保存主题',
        onPressed:
            _isLoading || _isSaving ? null : _saveThemeFromCurrentContext,
        icon: const Icon(Icons.save_outlined),
      ),
    ];
  }

  PreferredSizeWidget _buildModeTabBar(BuildContext context) {
    final theme = Theme.of(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _modeTabController,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: theme.colorScheme.onPrimaryContainer,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
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
                    SizedBox(width: 4),
                    Text('深色主题'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(advancedThemeEditorPageStateProvider);
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 42 + 6;
    final draft = _draft;
    const sectionGap = 8.0;
    final editorColorScheme = _colorSchemeForMode(_selectedMode);
    final baseTheme = Theme.of(context);
    final editorTextTheme = baseTheme.textTheme.apply(
      bodyColor: editorColorScheme.onSurface,
      displayColor: editorColorScheme.onSurface,
    );
    final editorTheme = baseTheme.copyWith(
      colorScheme: editorColorScheme,
      scaffoldBackgroundColor: editorColorScheme.surface,
      textTheme: editorTextTheme,
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        bodyColor: editorColorScheme.onSurface,
        displayColor: editorColorScheme.onSurface,
      ),
    );
    return Theme(
      data: editorTheme,
      child: Builder(
        builder: (context) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: editorColorScheme.surface,
            resizeToAvoidBottomInset: true,
            appBar: _buildRouteTopBar(context, draft),
            body: ValueListenableBuilder<int>(
              valueListenable: _colorPreviewRevision,
              builder: (context, _, __) {
                final previewModeConfig =
                    draft == null
                        ? _defaultModeConfigForMode(_selectedMode)
                        : _previewModeConfig(draft, _selectedMode);
                final decoration = buildAdvancedThemeBackdropDecoration(
                  resolveAdvancedThemeBackdropFromModeConfig(
                    editorColorScheme,
                    previewModeConfig,
                  ),
                );
                final maxWidth = AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: AppLayout.settingsContentMaxWidth,
                );
                return AdvancedThemePreviewPanel(
                  decoration: decoration,
                  maxWidth: maxWidth,
                  child: LayoutBuilder(
                    builder: (context, _) {
                      return _isLoading
                          ? const Center(
                            key: ValueKey<String>('advanced_theme_loading'),
                            child: AppProgressIndicator(
                              semanticLabel: '加载高级主题',
                            ),
                          )
                          : draft == null
                          ? const Center(
                            key: ValueKey<String>('advanced_theme_missing'),
                            child: Text('高级主题不存在'),
                          )
                          : AppFadeSlideTransition(
                            key: const ValueKey<String>(
                              'advanced_theme_editor',
                            ),
                            child: ListView(
                              key: const ValueKey<String>(
                                'advanced_theme_editor_scroll',
                              ),
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
                                _buildResourceSection(context, draft),
                              ],
                            ),
                          );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeFieldSection(
    BuildContext context, {
    required String title,
    required String tooltipMessage,
    required List<AdvancedThemeColorFieldSpec> fields,
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

  List<AdvancedThemeColorFieldSpec> _fieldSpecsForGroup(
    ThemeSemanticGroupSpec group,
  ) {
    return group.fields
        .map(
          (field) => AdvancedThemeColorFieldSpec(
            slot: AdvancedThemeColorSlot.fromSemanticField(field.id),
            label: field.label,
            description: field.description,
            scopeLabels: field.scopeLabels,
          ),
        )
        .toList(growable: false);
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
    final coverGalleryPreviewPath = _selectedCoverGalleryPreviewPath();
    final launchGalleryPreviewPath = _selectedLaunchImageGalleryPreviewPath();
    final bottomNavGallery = _selectedBottomNavGallery();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, '视觉资源'),
        const SizedBox(height: 4),
        _buildPanel(
          context,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gridSpacing = 10.0;
              const gridItemExtent = 216.0;
              const gridHeight = gridItemExtent * 2 + gridSpacing;
              final gridWidth =
                  constraints.maxWidth < AppLayout.mediumBreakpointWidth
                      ? AppLayout.mediumBreakpointWidth
                      : constraints.maxWidth;
              return SizedBox(
                height: gridHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: gridWidth,
                    height: gridHeight,
                    child: GridView(
                      key: const ValueKey<String>(
                        'advanced_theme_visual_resource_grid',
                      ),
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: gridSpacing,
                            mainAxisSpacing: gridSpacing,
                            mainAxisExtent: gridItemExtent,
                          ),
                      children: [
                        AdvancedThemeWallpaperResourceCard(
                          title: '应用背景',
                          subtitle: wallpaperPath == null ? '未设置' : '已设置',
                          badges: _visualResourceBadges(
                            draft,
                            hasResource: wallpaperPath != null,
                          ),
                          preview: _buildGalleryPreviewThumb(
                            context,
                            previewPath: wallpaperPath,
                            title: '应用背景',
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
                                        title: '应用背景',
                                      ),
                                    ),
                          ),
                          onTap:
                              _isSaving
                                  ? () {}
                                  : _pickWallpaperFromBackgroundLibrary,
                        ),
                        AdvancedThemeWallpaperResourceCard(
                          title: '阅读背景',
                          subtitle: readerWallpaperPath == null ? '未设置' : '已设置',
                          badges: _visualResourceBadges(
                            draft,
                            hasResource: readerWallpaperPath != null,
                          ),
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
                        AdvancedThemeWallpaperResourceCard(
                          title: '书籍封面',
                          subtitle:
                              coverGalleryPreviewPath == null ? '未设置' : '已设置',
                          badges: _visualResourceBadges(
                            draft,
                            hasResource: coverGalleryPreviewPath != null,
                          ),
                          preview: _buildGalleryPreviewThumb(
                            context,
                            previewPath: coverGalleryPreviewPath,
                            title: _selectedCoverGallery()?.name ?? '书籍封面',
                            width: 72,
                            height: 72,
                            borderRadius: 12,
                            useAddPlaceholder: true,
                            onLongPress:
                                coverGalleryPreviewPath == null
                                    ? null
                                    : () => unawaited(
                                      _showImagePreviewDialog(
                                        imagePath: coverGalleryPreviewPath,
                                        title:
                                            _selectedCoverGallery()?.name ??
                                            '书籍封面',
                                      ),
                                    ),
                          ),
                          onTap: _pickCoverGallery,
                        ),
                        AdvancedThemeWallpaperResourceCard(
                          title: '启动图集',
                          subtitle:
                              launchGalleryPreviewPath == null ? '未设置' : '已设置',
                          badges: _visualResourceBadges(
                            draft,
                            hasResource: launchGalleryPreviewPath != null,
                          ),
                          preview: _buildGalleryPreviewThumb(
                            context,
                            previewPath: launchGalleryPreviewPath,
                            title:
                                _selectedLaunchImageGallery()?.name ?? '启动图集',
                            width: 72,
                            height: 72,
                            borderRadius: 12,
                            useAddPlaceholder: true,
                            onLongPress:
                                launchGalleryPreviewPath == null
                                    ? null
                                    : () => unawaited(
                                      _showImagePreviewDialog(
                                        imagePath: launchGalleryPreviewPath,
                                        title:
                                            _selectedLaunchImageGallery()
                                                ?.name ??
                                            '启动图集',
                                      ),
                                    ),
                          ),
                          onTap: _pickLaunchImageGallery,
                        ),
                        AdvancedThemeWallpaperResourceCard(
                          title: '底栏图集',
                          subtitle: _resolvedBottomNavGalleryName(),
                          badges: _visualResourceBadges(
                            draft,
                            hasResource: bottomNavGallery != null,
                          ),
                          preview: _buildBottomNavGalleryPreview(
                            context,
                            gallery: bottomNavGallery,
                          ),
                          onTap: _isSaving ? () {} : _pickBottomNavGallery,
                        ),
                        AdvancedThemeWallpaperResourceCard(
                          title: '主题特效',
                          subtitle: appAdvancedThemeEffectStatus(
                            draft.themeEffect,
                          ),
                          badges: _visualResourceBadges(
                            draft,
                            hasResource:
                                draft.themeEffect !=
                                AppAdvancedThemeEffect.none,
                          ),
                          preview: _buildThemeEffectPreviewThumb(
                            context,
                            effect: draft.themeEffect,
                          ),
                          onTap: _isSaving ? () {} : _pickThemeEffect,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _buildBackgroundResourceTuningSection(context, draft),
      ],
    );
  }

  List<String> _visualResourceBadges(
    AppAdvancedTheme draft, {
    required bool hasResource,
  }) {
    if (!hasResource) {
      return const <String>['默认'];
    }
    final activeThemeId = ref.watch(activeAdvancedThemeIdProvider);
    return <String>['高级主题引用', if (activeThemeId == draft.id) '当前主题'];
  }

  Widget _buildBackgroundResourceTuningSection(
    BuildContext context,
    AppAdvancedTheme draft,
  ) {
    final currentConfig = draft.configFor(_selectedMode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          context,
          '背景资源参数',
          tooltipMessage: '应用背景和阅读背景的透明度、遮罩和模糊参数。',
        ),
        const SizedBox(height: 4),
        _buildPanel(
          context,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            children: [
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
        _buildSectionLabel(context, '组件'),
        const SizedBox(height: 4),
        _buildComponentStyleSection(context, draft),
        const SizedBox(height: 10),
        _buildThemeFieldSection(
          context,
          title: modalThemeSemanticGroup.title,
          tooltipMessage: modalThemeSemanticGroup.subtitle,
          fields: _fieldSpecsForGroup(modalThemeSemanticGroup),
        ),
        const SizedBox(height: 6),
        _buildModalComponentPreview(context),
        const SizedBox(height: 10),
        _buildThemeFieldSection(
          context,
          title: cardThemeSemanticGroup.title,
          tooltipMessage: cardThemeSemanticGroup.subtitle,
          fields: _fieldSpecsForGroup(cardThemeSemanticGroup),
        ),
        const SizedBox(height: 10),
        _buildThemeFieldSection(
          context,
          title: inputThemeSemanticGroup.title,
          tooltipMessage: inputThemeSemanticGroup.subtitle,
          fields: _fieldSpecsForGroup(inputThemeSemanticGroup),
        ),
        const SizedBox(height: 10),
        _buildPanel(
          context,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            children: [
              AdvancedThemeFontSection(
                interfaceFontName: _resolvedAppInterfaceFontName(),
                readerFontName: _resolvedReaderFontName(),
                onPickInterfaceFont: () => _pickThemeFont(readerFont: false),
                onPickReaderFont: () => _pickThemeFont(readerFont: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildAdvancedParametersSection(context, draft),
      ],
    );
  }

  Widget _buildModalComponentPreview(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _colorPreviewRevision,
      builder: (context, _, __) {
        final colorScheme = Theme.of(context).colorScheme;
        final modalColor = _resolvedCurrentSlotColor(
          AdvancedThemeColorSlot.surface,
        );
        final textColor = _readableTextColorFor(context, modalColor);
        return _buildPanel(
          context,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '弹窗预览',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 136,
                    child: AppSurface(
                      backgroundColor: modalColor,
                      borderColor: colorScheme.outlineVariant,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '普通弹窗',
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '内容区域',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: textColor.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 136,
                    child: AppSurface(
                      backgroundColor: modalColor,
                      borderColor: colorScheme.outlineVariant,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '底部面板',
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 48,
                            height: 4,
                            color: textColor.withValues(alpha: 0.24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdvancedParametersSection(
    BuildContext context,
    AppAdvancedTheme draft,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdvancedThemeExpandableSectionHeader(
          title: '高级参数',
          tooltipMessage: '低频颜色和旧组件样式默认收起，便于后续继续删减。',
          expanded: _advancedParametersExpanded,
          onToggle: () {
            _updateAdvancedThemeEditorState(() {
              _advancedParametersExpanded = !_advancedParametersExpanded;
            });
          },
        ),
        if (_advancedParametersExpanded) ...[
          const SizedBox(height: 4),
          _buildAdvancedComponentStyleSection(context, draft),
          const SizedBox(height: 10),
          _buildThemeFieldSection(
            context,
            title: advancedColorThemeSemanticGroup.title,
            tooltipMessage: advancedColorThemeSemanticGroup.subtitle,
            fields: _fieldSpecsForGroup(advancedColorThemeSemanticGroup),
          ),
          const SizedBox(height: 10),
          _buildThemeFieldSection(
            context,
            title: buttonThemeSemanticGroup.title,
            tooltipMessage: buttonThemeSemanticGroup.subtitle,
            fields: _fieldSpecsForGroup(buttonThemeSemanticGroup),
          ),
          const SizedBox(height: 10),
          _buildThemeFieldSection(
            context,
            title: optionThemeSemanticGroup.title,
            tooltipMessage: optionThemeSemanticGroup.subtitle,
            fields: _fieldSpecsForGroup(optionThemeSemanticGroup),
          ),
          const SizedBox(height: 10),
          _buildThemeFieldSection(
            context,
            title: pageEffectThemeSemanticGroup.title,
            tooltipMessage: pageEffectThemeSemanticGroup.subtitle,
            fields: _fieldSpecsForGroup(pageEffectThemeSemanticGroup),
          ),
        ],
      ],
    );
  }

  Widget _buildAdvancedComponentStyleSection(
    BuildContext context,
    AppAdvancedTheme draft,
  ) {
    final style = draft.configFor(_selectedMode).componentStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          context,
          '组件样式',
          tooltipMessage: '历史组件样式字段，默认收起用于兼容旧主题。',
        ),
        const SizedBox(height: 4),
        _buildPanel(
          context,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            children: [
              _buildComponentStyleChoiceRow<AppAdvancedThemeCardStyle>(
                context,
                label: '卡片样式',
                value: style.cardStyle,
                choices: const [
                  AdvancedThemeComponentStyleChoice<AppAdvancedThemeCardStyle>(
                    AppAdvancedThemeCardStyle.soft,
                    '柔和',
                  ),
                  AdvancedThemeComponentStyleChoice<AppAdvancedThemeCardStyle>(
                    AppAdvancedThemeCardStyle.outlined,
                    '描边',
                  ),
                  AdvancedThemeComponentStyleChoice<AppAdvancedThemeCardStyle>(
                    AppAdvancedThemeCardStyle.elevated,
                    '悬浮',
                  ),
                ],
                onChanged:
                    _isSaving
                        ? null
                        : (value) => _updateComponentStyle(
                          (current) => current.copyWith(cardStyle: value),
                        ),
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeButtonStyle>(
                context,
                label: '按钮样式',
                value: style.buttonStyle,
                choices: const [
                  AdvancedThemeComponentStyleChoice<
                    AppAdvancedThemeButtonStyle
                  >(AppAdvancedThemeButtonStyle.stadium, '胶囊'),
                  AdvancedThemeComponentStyleChoice<
                    AppAdvancedThemeButtonStyle
                  >(AppAdvancedThemeButtonStyle.rounded, '圆角'),
                  AdvancedThemeComponentStyleChoice<
                    AppAdvancedThemeButtonStyle
                  >(AppAdvancedThemeButtonStyle.sharp, '利落'),
                ],
                onChanged:
                    _isSaving
                        ? null
                        : (value) => _updateComponentStyle(
                          (current) => current.copyWith(buttonStyle: value),
                        ),
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeInputStyle>(
                context,
                label: '输入框样式',
                value: style.inputStyle,
                choices: const [
                  AdvancedThemeComponentStyleChoice<AppAdvancedThemeInputStyle>(
                    AppAdvancedThemeInputStyle.soft,
                    '柔和',
                  ),
                  AdvancedThemeComponentStyleChoice<AppAdvancedThemeInputStyle>(
                    AppAdvancedThemeInputStyle.outlined,
                    '描边',
                  ),
                  AdvancedThemeComponentStyleChoice<AppAdvancedThemeInputStyle>(
                    AppAdvancedThemeInputStyle.underlined,
                    '下划线',
                  ),
                ],
                onChanged:
                    _isSaving
                        ? null
                        : (value) => _updateComponentStyle(
                          (current) => current.copyWith(inputStyle: value),
                        ),
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeOverlayStyle>(
                context,
                label: '弹窗样式',
                value: style.overlayStyle,
                choices: const [
                  AdvancedThemeComponentStyleChoice<
                    AppAdvancedThemeOverlayStyle
                  >(AppAdvancedThemeOverlayStyle.comfortable, '舒展'),
                  AdvancedThemeComponentStyleChoice<
                    AppAdvancedThemeOverlayStyle
                  >(AppAdvancedThemeOverlayStyle.compact, '紧凑'),
                ],
                onChanged:
                    _isSaving
                        ? null
                        : (value) => _updateComponentStyle(
                          (current) => current.copyWith(overlayStyle: value),
                        ),
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeNavigationStyle>(
                context,
                label: '导航样式',
                value: style.navigationStyle,
                choices: const [
                  AdvancedThemeComponentStyleChoice<
                    AppAdvancedThemeNavigationStyle
                  >(AppAdvancedThemeNavigationStyle.soft, '柔和'),
                  AdvancedThemeComponentStyleChoice<
                    AppAdvancedThemeNavigationStyle
                  >(AppAdvancedThemeNavigationStyle.floating, '悬浮'),
                  AdvancedThemeComponentStyleChoice<
                    AppAdvancedThemeNavigationStyle
                  >(AppAdvancedThemeNavigationStyle.compact, '紧凑'),
                ],
                onChanged:
                    _isSaving
                        ? null
                        : (value) => _updateComponentStyle(
                          (current) => current.copyWith(navigationStyle: value),
                        ),
              ),
              const Divider(height: 1),
              _buildComponentStyleChoiceRow<AppAdvancedThemeSwitchStyle>(
                context,
                label: '切换样式',
                value: style.switchStyle,
                choices: const [
                  AdvancedThemeComponentStyleChoice<
                    AppAdvancedThemeSwitchStyle
                  >(AppAdvancedThemeSwitchStyle.soft, '柔和'),
                  AdvancedThemeComponentStyleChoice<
                    AppAdvancedThemeSwitchStyle
                  >(AppAdvancedThemeSwitchStyle.contrast, '高对比'),
                ],
                onChanged:
                    _isSaving
                        ? null
                        : (value) => _updateComponentStyle(
                          (current) => current.copyWith(switchStyle: value),
                        ),
              ),
              const Divider(height: 1),
              _buildComponentShadowStrengthRow(context, style.shadowStrength),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComponentStyleSection(
    BuildContext context,
    AppAdvancedTheme draft,
  ) {
    final style = draft.configFor(_selectedMode).componentStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          context,
          '圆角比例',
          tooltipMessage: '控制卡片、按钮、输入框和弹窗的整体圆角。',
        ),
        const SizedBox(height: 4),
        _buildPanel(
          context,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            children: [
              _buildComponentStyleChoiceRow<double>(
                context,
                label: '圆角比例',
                value: _nearestRadiusScaleChoice(style.globalRadiusScale),
                choices: const [
                  AdvancedThemeComponentStyleChoice<double>(0.75, '利落'),
                  AdvancedThemeComponentStyleChoice<double>(1.00, '标准'),
                  AdvancedThemeComponentStyleChoice<double>(1.20, '柔和'),
                  AdvancedThemeComponentStyleChoice<double>(1.40, '圆润'),
                ],
                onChanged:
                    _isSaving
                        ? null
                        : (value) => _updateComponentStyle(
                          (current) =>
                              current.copyWith(globalRadiusScale: value),
                        ),
              ),
              const Divider(height: 1),
              _buildComponentRadiusPreview(context, style.globalRadiusScale),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComponentRadiusPreview(BuildContext context, double scale) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = (12 * scale).clamp(6.0, 24.0).toDouble();
    final inputRadius = (10 * scale).clamp(6.0, 22.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '圆角预览',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRadiusPreviewChip(
                context,
                label: '卡片',
                borderRadius: radius,
                backgroundColor: colorScheme.surface,
              ),
              _buildRadiusPreviewChip(
                context,
                label: '按钮',
                borderRadius: inputRadius,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
              _buildRadiusPreviewChip(
                context,
                label: '输入框',
                borderRadius: inputRadius,
                backgroundColor: colorScheme.surface,
              ),
              _buildRadiusPreviewChip(
                context,
                label: '弹窗',
                borderRadius: radius,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusPreviewChip(
    BuildContext context, {
    required String label,
    required double borderRadius,
    required Color backgroundColor,
    Color? foregroundColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 70,
      height: 34,
      child: AppSurface(
        padding: EdgeInsets.zero,
        backgroundColor: backgroundColor,
        // UI-GOV-EXEMPT: radius preview intentionally visualizes the selected radius value.
        borderRadius: BorderRadius.circular(borderRadius),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor ?? colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  double _nearestRadiusScaleChoice(double value) {
    const choices = <double>[0.75, 1, 1.2, 1.4];
    var nearest = choices.first;
    var nearestDistance = (value - nearest).abs();
    for (final choice in choices.skip(1)) {
      final distance = (value - choice).abs();
      if (distance < nearestDistance) {
        nearest = choice;
        nearestDistance = distance;
      }
    }
    return nearest;
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

  Widget _buildComponentShadowStrengthRow(
    BuildContext context,
    double shadowStrength,
  ) {
    final normalizedStrength = shadowStrength.clamp(0.1, 1.0).toDouble();
    return _buildStrengthSliderRow(
      context,
      label: '组件阴影强度',
      valueLabel: '${(normalizedStrength * 100).round()}%',
      value: normalizedStrength,
      min: 0.1,
      max: 1,
      divisions: 9,
      onChanged:
          _isSaving
              ? null
              : (value) => _updateComponentStyle(
                (current) => current.copyWith(shadowStrength: value),
              ),
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
      '全局圆角比例' => '圆角比例',
      '组件阴影强度' => '组件阴影',
      '壁纸遮罩透明度' => '壁纸遮罩',
      '壁纸不透明度' => '壁纸透明度',
      '壁纸模糊程度' => '壁纸模糊',
      '阅读器遮罩透明度' => '阅读器遮罩',
      '阅读器背景不透明度' => '阅读器透明度',
      '阅读器背景模糊程度' => '阅读器模糊',
      _ => label,
    };
  }

  Widget _buildComponentStyleChoiceRow<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<AdvancedThemeComponentStyleChoice<T>> choices,
    required ValueChanged<T>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 9, 2, 9),
      child: Row(
        children: [
          Expanded(
            flex: 30,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 70,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final choice in choices)
                  _buildFitChoiceButton(
                    context,
                    label: choice.label,
                    selected: choice.value == value,
                    onPressed:
                        onChanged == null
                            ? null
                            : () => onChanged(choice.value),
                    colorScheme: colorScheme,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
      child: AppButton(
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.compact,
        onPressed: onPressed,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10),
          ),
          backgroundColor: WidgetStatePropertyAll(
            selected ? colorScheme.primaryContainer : colorScheme.surface,
          ),
          foregroundColor: WidgetStatePropertyAll(
            selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(
              color:
                  selected
                      ? colorScheme.primary.withValues(alpha: 0.6)
                      : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          shape: WidgetStatePropertyAll(
            // UI-GOV-EXEMPT: hardcoded-style resource fit chips use a compact fixed shape inside image controls.
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          textStyle: WidgetStatePropertyAll(
            Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        label: label,
      ),
    );
  }

  List<Widget> _buildColorFieldRows(
    BuildContext context,
    List<AdvancedThemeColorFieldSpec> fields,
  ) {
    return [
      for (var index = 0; index < fields.length; index++) ...[
        _buildColorFieldRow(context, fields[index]),
        if (index != fields.length - 1) const Divider(height: 1),
      ],
    ];
  }

  Widget _buildColorFieldRow(
    BuildContext context,
    AdvancedThemeColorFieldSpec field,
  ) {
    final slot = field.slot;
    final colorScheme = Theme.of(context).colorScheme;
    final controller = _currentControllers[slot]!;
    final fallback = _fallbackColorForSlot(_selectedMode, slot);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, _, __) {
        final parsed = AdvancedThemeColorCodec.parseHexColor(
          controller.text.trim(),
        );
        final previewColor = AdvancedThemeColorCodec.resolvedColor(
          parsed,
          fallback,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (field.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        field.description.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
                    hintText: AdvancedThemeColorCodec.formatHex(
                      fallback.toARGB32(),
                    ),
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
    return AdvancedThemeSectionLabel(
      title: title,
      tooltipMessage: tooltipMessage,
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required Widget child,
    Color? backgroundColor,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
  }) {
    return AdvancedThemePanel(
      backgroundColor: backgroundColor,
      padding: padding,
      child: child,
    );
  }

  Widget _buildListSectionBody(BuildContext context, {required Widget child}) {
    return AdvancedThemeListSectionBody(child: child);
  }

  Map<AdvancedThemeColorSlot, TextEditingController> get _currentControllers {
    return _colorControllersByMode[_selectedMode]!;
  }

  String _modeLabel(AppAdvancedThemeMode mode) {
    return switch (mode) {
      AppAdvancedThemeMode.light => '浅色',
      AppAdvancedThemeMode.dark => '深色',
    };
  }

  ColorScheme _colorSchemeForMode(AppAdvancedThemeMode mode) {
    final themeSource = ref.read(appThemeSourceProvider);
    return mode == AppAdvancedThemeMode.light
        ? themeSource.lightScheme
        : themeSource.darkScheme;
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

  Color _fallbackColorForSlot(
    AppAdvancedThemeMode mode,
    AdvancedThemeColorSlot slot,
  ) {
    final palette = _resolvedDefaultPaletteForMode(mode);
    final backdrop = _resolvedDefaultBackdropForMode(mode);
    return switch (slot) {
      AdvancedThemeColorSlot.primary => palette.primaryColor,
      AdvancedThemeColorSlot.secondary => palette.secondaryColor,
      AdvancedThemeColorSlot.noticeAccent => palette.noticeAccentColor,
      AdvancedThemeColorSlot.noticeSurface => palette.noticeSurfaceColor,
      AdvancedThemeColorSlot.primaryContainer => palette.primaryContainerColor,
      AdvancedThemeColorSlot.background => backdrop.backgroundColor,
      AdvancedThemeColorSlot.surface => palette.surfaceColor,
      AdvancedThemeColorSlot.searchFieldBackground =>
        palette.searchFieldBackgroundColor,
      AdvancedThemeColorSlot.elevatedSurface => palette.elevatedSurfaceColor,
      AdvancedThemeColorSlot.card => palette.cardColor,
      AdvancedThemeColorSlot.cardText => palette.cardTextColor,
      AdvancedThemeColorSlot.cardBorder => palette.cardBorderColor,
      AdvancedThemeColorSlot.iconBackground => palette.iconBackgroundColor,
      AdvancedThemeColorSlot.textPrimary => palette.textPrimaryColor,
      AdvancedThemeColorSlot.textSecondary => palette.textSecondaryColor,
      AdvancedThemeColorSlot.buttonText => palette.buttonTextColor,
      AdvancedThemeColorSlot.outline => palette.outlineColor,
      AdvancedThemeColorSlot.divider => palette.dividerColor,
      AdvancedThemeColorSlot.shadow => palette.shadowColor,
      AdvancedThemeColorSlot.wallpaperOverlay => backdrop.wallpaperOverlayColor,
    };
  }

  Color _resolvedCurrentSlotColor(AdvancedThemeColorSlot slot) {
    final raw = _currentControllers[slot]!.text.trim();
    return AdvancedThemeColorCodec.resolvedColor(
      AdvancedThemeColorCodec.parseHexColor(raw),
      _fallbackColorForSlot(_selectedMode, slot),
    );
  }

  Color _readableTextColorFor(BuildContext context, Color backgroundColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.dark
        ? colorScheme.surface
        : colorScheme.onSurface;
  }

  int? _valueForSlot(
    AppAdvancedThemeColors colors,
    AdvancedThemeColorSlot slot,
  ) {
    return switch (slot) {
      AdvancedThemeColorSlot.primary => colors.primaryColorValue,
      AdvancedThemeColorSlot.secondary => colors.secondaryColorValue,
      AdvancedThemeColorSlot.noticeAccent => colors.noticeAccentColorValue,
      AdvancedThemeColorSlot.noticeSurface => colors.noticeSurfaceColorValue,
      AdvancedThemeColorSlot.primaryContainer =>
        colors.primaryContainerColorValue,
      AdvancedThemeColorSlot.background => colors.backgroundColorValue,
      AdvancedThemeColorSlot.surface => colors.surfaceColorValue,
      AdvancedThemeColorSlot.searchFieldBackground =>
        colors.searchFieldBackgroundColorValue,
      AdvancedThemeColorSlot.elevatedSurface =>
        colors.elevatedSurfaceColorValue,
      AdvancedThemeColorSlot.card => colors.cardColorValue,
      AdvancedThemeColorSlot.cardText => colors.cardTextColorValue,
      AdvancedThemeColorSlot.cardBorder => colors.cardBorderColorValue,
      AdvancedThemeColorSlot.iconBackground => colors.iconBackgroundColorValue,
      AdvancedThemeColorSlot.textPrimary => colors.textPrimaryColorValue,
      AdvancedThemeColorSlot.textSecondary => colors.textSecondaryColorValue,
      AdvancedThemeColorSlot.buttonText => colors.buttonTextColorValue,
      AdvancedThemeColorSlot.outline => colors.outlineColorValue,
      AdvancedThemeColorSlot.divider => colors.dividerColorValue,
      AdvancedThemeColorSlot.shadow => colors.shadowColorValue,
      AdvancedThemeColorSlot.wallpaperOverlay =>
        colors.wallpaperOverlayColorValue,
    };
  }
}
