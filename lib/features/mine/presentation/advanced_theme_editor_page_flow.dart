part of 'advanced_theme_editor_page.dart';

extension on _AdvancedThemeEditorPageState {
  Future<void> _initializeDraftImpl() async {
    try {
      final themeId = widget.themeId?.trim() ?? '';
      if (themeId.isEmpty) {
        final draft = _stateService.createDraftFromModeConfigs(
          lightConfig: _defaultModeConfigForMode(AppAdvancedThemeMode.light),
          darkConfig: _defaultModeConfigForMode(AppAdvancedThemeMode.dark),
        );
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      _updateAdvancedThemeEditorState(() {
        _draft = null;
        _isLoading = false;
      });
      _showMessage('加载高级主题失败');
    }
  }

  Future<void> _loadAppearanceLinksImpl() async {
    try {
      final links = await _stateService.loadAppearanceLinks();
      if (!mounted) {
        return;
      }
      _pageStateNotifier.update(
        (state) => _editorController.applyAppearanceLinks(state, links),
      );
      _refreshAdvancedThemeEditorState();
    } catch (_) {
      if (mounted) {
        _showMessage('加载主题资源失败');
      }
    }
  }

  Future<void> _saveThemeImpl({
    required CircularThemeRevealOverlayState? revealOverlay,
    required Offset revealCenter,
  }) async {
    final draft = _draft;
    if (draft == null || _isSaving) {
      return;
    }
    final normalizedName = _nameController.text.trim();
    _commitNameToDraft(normalizedName);
    final parsedLightColors = _parseColorsForMode(AppAdvancedThemeMode.light);
    if (parsedLightColors == null) {
      return;
    }
    final parsedDarkColors = _parseColorsForMode(AppAdvancedThemeMode.dark);
    if (parsedDarkColors == null) {
      return;
    }
    final validation = _validationService.validateSave(
      name: normalizedName,
      lightColors: parsedLightColors,
      darkColors: parsedDarkColors,
    );
    if (!validation.isValid) {
      final message = validation.message;
      if (message != null) {
        _showMessage(message);
      }
      switch (validation.focus) {
        case AdvancedThemeEditorValidationFocus.light:
          _selectMode(AppAdvancedThemeMode.light);
        case AdvancedThemeEditorValidationFocus.dark:
          _selectMode(AppAdvancedThemeMode.dark);
        case AdvancedThemeEditorValidationFocus.name:
        case null:
          break;
      }
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
      await _closeWithRevealAt(
        overlay: revealOverlay,
        center: revealCenter,
        result: '已保存高级主题',
      );
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
