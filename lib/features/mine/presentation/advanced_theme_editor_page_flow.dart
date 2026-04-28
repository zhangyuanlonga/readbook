part of 'advanced_theme_editor_page.dart';

extension on _AdvancedThemeEditorPageState {
  Future<void> _initializeDraftImpl() async {
    final themeId = widget.themeId?.trim() ?? '';
    if (themeId.isEmpty) {
      final seedColor = ref.read(appSeedColorProvider);
      final draft = _stateService.createDraft(seedColor);
      if (!mounted) {
        return;
      }
      _updateAdvancedThemeEditorState(() {
        _draft = draft;
        _isLoading = false;
      });
      _syncControllersFromDraft(draft);
      return;
    }

    final target = await _stateService.loadDraft(themeId);
    if (!mounted) {
      return;
    }
    _updateAdvancedThemeEditorState(() {
      _draft = target;
      _isLoading = false;
    });
    if (target != null) {
      _syncControllersFromDraft(target);
    }
  }

  Future<void> _loadAppearanceLinksImpl() async {
    final links = await _stateService.loadAppearanceLinks();
    if (!mounted) {
      return;
    }
    _updateAdvancedThemeEditorState(() {
      _backgroundLibraryPaths = links.backgroundLibraryPaths.toList(
        growable: false,
      );
      _readerBackgroundLibraryPaths = links.readerBackgroundLibraryPaths.toList(
        growable: false,
      );
      _bottomNavGalleries = links.bottomNavGalleries.toList(growable: false);
      _coverGalleries = links.coverGalleries.toList(growable: false);
      _launchImageGalleries =
          links.launchImageGalleries.toList(growable: false);
      _availableFonts = links.availableFonts.toList(growable: false);
      _activeBottomNavGalleryName = links.activeBottomNavGalleryName;
    });
  }

  Future<void> _saveThemeImpl() async {
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

    _updateAdvancedThemeEditorState(() {
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
      _updateAdvancedThemeEditorState(() {
        _draft = saved;
      });
      context.pop('已保存高级主题');
    } finally {
      if (mounted) {
        _updateAdvancedThemeEditorState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _applyPickedWallpaperImpl(PickedImageData picked) async {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    _updateAdvancedThemeEditorState(() {
      _isSaving = true;
    });
    try {
      final nextDraft = await _stateService.applyWallpaper(
        draft: draft,
        mode: _selectedMode,
        picked: picked,
      );
      if (!mounted) {
        return;
      }
      _updateAdvancedThemeEditorState(() {
        _draft = nextDraft;
      });
    } finally {
      if (mounted) {
        _updateAdvancedThemeEditorState(() {
          _isSaving = false;
        });
      }
    }
  }
}
