part of 'reader_page.dart';

extension _ReaderPageSettingsSheetExtension on _ReaderPageState {
  Future<void> _showSettingsSheet({
    _ReaderSettingsTab initialTab = _ReaderSettingsTab.reading,
  }) async {
    _stopAutoReadSession();
    final shouldRestoreOverlay = _showOverlayControls;
    if (shouldRestoreOverlay) {
      _hideOverlayControls(resumeAutoRead: false, syncSystemUi: false);
    }

    var draft = _settings;
    final isMangaChapter = _isMangaChapter;
    if (!isMangaChapter && !draft.pageTurnMode.usesScrollLayout) {
      draft = draft.copyWith(pageTurnMode: ReaderPageTurnMode.tapAndSwipe);
    }
    var availableCustomFonts = List<ReaderCustomFontEntry>.from(_customFonts);
    var startAutoReadAfterApply = false;
    var isPersistingDraft = false;
    final showInterfaceSettings = initialTab == _ReaderSettingsTab.interface;
    String? activeSettingsGroupKey;
    Timer? persistDraftTimer;
    Timer? sliderInteractionTimer;
    var isSliderInteracting = false;
    const settingsGroupingService = ReaderSettingsGroupingService();

    String fingerprint(ReaderSettings settings) {
      return jsonEncode(settings.copyWith(autoReadEnabled: false).toJson());
    }

    var persistedFingerprint = fingerprint(_settings);

    Future<void> persistDraftNow(ReaderSettings settings) async {
      final normalized = settings.copyWith(autoReadEnabled: false);
      final nextFingerprint = fingerprint(normalized);
      if (nextFingerprint == persistedFingerprint || isPersistingDraft) {
        return;
      }

      isPersistingDraft = true;
      try {
        await _preferencesService.saveSettings(normalized);
        persistedFingerprint = nextFingerprint;
      } catch (_) {
        // Keep in-memory preview even when persistence fails.
      } finally {
        isPersistingDraft = false;
      }
    }

    void schedulePersistDraft() {
      persistDraftTimer?.cancel();
      persistDraftTimer = Timer(const Duration(milliseconds: 220), () {
        if (!mounted) {
          return;
        }
        unawaited(persistDraftNow(draft));
      });
    }

    await _ensureBackgroundPresetsReady();
    if (!mounted) {
      return;
    }
    final activeBackgroundBase64 = _settings.backgroundImageBase64?.trim();
    final hasActiveBackground =
        activeBackgroundBase64 != null && activeBackgroundBase64.isNotEmpty;
    final isActivePreset =
        hasActiveBackground && _isPresetBackgroundValue(activeBackgroundBase64);
    if (hasActiveBackground && !isActivePreset) {
      final nextCustoms = List<String>.from(_customBackgroundImages);
      if (!nextCustoms.contains(activeBackgroundBase64)) {
        nextCustoms.add(activeBackgroundBase64);
        _customBackgroundImages = nextCustoms;
        unawaited(_preferencesService.saveCustomBackgroundImages(nextCustoms));
      }
    }
    final readerModalTheme = _readerModalTheme();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Theme(
          data: readerModalTheme,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final sheetSurfaceColor = readerModalTheme.colorScheme.surface
                  .withValues(alpha: isSliderInteracting ? 0.42 : 1.0);

              Widget wrapSheetSurface(Widget child) {
                return AnimatedTheme(
                  duration: const Duration(milliseconds: 160),
                  data: readerModalTheme.copyWith(
                    bottomSheetTheme: readerModalTheme.bottomSheetTheme
                        .copyWith(
                          backgroundColor: sheetSurfaceColor,
                          modalBackgroundColor: sheetSurfaceColor,
                        ),
                  ),
                  child: Material(color: sheetSurfaceColor, child: child),
                );
              }

              final activeBackgroundBase64 =
                  draft.backgroundImageBase64?.trim();
              final hasBackgroundImage =
                  activeBackgroundBase64 != null &&
                  activeBackgroundBase64.isNotEmpty;
              final isPresetBackground =
                  hasBackgroundImage &&
                  _backgroundPresetBase64.values.contains(
                    activeBackgroundBase64,
                  );
              final customBackgrounds = _customBackgroundImages;
              Future<void> openMineFontManagement() async {
                if (!context.mounted) {
                  return;
                }
                await context.push('/font-management');
                await _refreshSharedReaderAssets(
                  updateModalState: setModalState,
                );
              }

              Future<void> openMineReaderBackgroundManagement() async {
                if (!context.mounted) {
                  return;
                }
                await context.push('/appearance/reader-background');
                await _refreshSharedReaderAssets(
                  updateModalState: setModalState,
                );
              }

              void updateCustomBackgrounds(List<String> nextCustoms) {
                if (mounted) {
                  _updateReaderState(() {
                    _customBackgroundImages = nextCustoms;
                  });
                } else {
                  _customBackgroundImages = nextCustoms;
                }
                unawaited(_preloadCustomBackgroundPreviews(nextCustoms));
                unawaited(
                  _preferencesService.saveCustomBackgroundImages(nextCustoms),
                );
              }

              void updateCustomBackgroundsInSheet(List<String> nextCustoms) {
                setModalState(() {
                  _customBackgroundImages = nextCustoms;
                });
                updateCustomBackgrounds(nextCustoms);
              }

              Future<void> rememberBodyTextColor(int value) async {
                final nextColors = <int>[value, ..._recentBodyTextColors];
                nextColors.removeWhere((entry) => entry == value);
                nextColors.insert(0, value);
                if (nextColors.length > 8) {
                  nextColors.removeRange(8, nextColors.length);
                }
                if (mounted) {
                  _updateReaderState(() {
                    _recentBodyTextColors = nextColors;
                  });
                } else {
                  _recentBodyTextColors = nextColors;
                }
                await _preferencesService.saveRecentBodyTextColors(nextColors);
              }

              void previewDraftSettings() {
                if (!mounted) {
                  return;
                }

                schedulePersistDraft();
                final currentFingerprint = fingerprint(_settings);
                final draftFingerprint = fingerprint(draft);
                if (currentFingerprint == draftFingerprint) {
                  return;
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted ||
                      fingerprint(_settings) == fingerprint(draft)) {
                    return;
                  }
                  _applyReaderSettingsWithModeRestore(nextSettings: draft);
                });
              }

              void updateDraft(ReaderSettings next) {
                setModalState(() {
                  draft = next;
                });
                previewDraftSettings();
              }

              void setSliderInteractionPreview(
                bool active, {
                bool delayedRestore = false,
              }) {
                sliderInteractionTimer?.cancel();
                if (delayedRestore && !active) {
                  sliderInteractionTimer = Timer(
                    const Duration(milliseconds: 180),
                    () {
                      if (!mounted ||
                          !context.mounted ||
                          !isSliderInteracting) {
                        return;
                      }
                      setModalState(() {
                        isSliderInteracting = false;
                      });
                    },
                  );
                  return;
                }
                if (isSliderInteracting == active) {
                  return;
                }
                setModalState(() {
                  isSliderInteracting = active;
                });
              }

              Slider buildPreviewAwareSlider({
                required double min,
                required double max,
                required int? divisions,
                required double value,
                required ValueChanged<double>? onChanged,
                String? label,
              }) {
                return Slider(
                  min: min,
                  max: max,
                  divisions: divisions,
                  value: value,
                  label: label,
                  onChangeStart:
                      onChanged == null
                          ? null
                          : (_) => setSliderInteractionPreview(true),
                  onChangeEnd:
                      onChanged == null
                          ? null
                          : (_) => setSliderInteractionPreview(
                            false,
                            delayedRestore: true,
                          ),
                  onChanged: onChanged,
                );
              }

              Future<void> persistBackgroundDraftNow(
                ReaderSettings nextDraft,
              ) async {
                if (mounted) {
                  _updateReaderState(() {
                    _settings = nextDraft;
                  });
                  unawaited(_syncVolumeKeyPageInterception());
                } else {
                  _settings = nextDraft;
                }
                _debugLogReaderBackground('persist', nextDraft);
                await persistDraftNow(nextDraft);
              }

              Future<void> applyCustomBackgroundImage() async {
                final storedPath = await _pickBackgroundImagePath();
                if (storedPath == null || !context.mounted) {
                  return;
                }

                final nextCustoms =
                    List<String>.from(_customBackgroundImages)
                      ..removeWhere((entry) => entry == storedPath)
                      ..add(storedPath);

                updateDraft(draft.copyWith(backgroundImageBase64: storedPath));
                setModalState(() {
                  _customBackgroundImages = nextCustoms;
                });
                updateCustomBackgrounds(nextCustoms);
              }

              Future<void> applyStoredCustomBackground(String source) async {
                final normalized = source.trim();
                if (normalized.isEmpty) {
                  return;
                }
                updateDraft(draft.copyWith(backgroundImageBase64: normalized));
              }

              Future<void> removeActiveBackground() async {
                final active = draft.backgroundImageBase64?.trim();
                final isActivePreset =
                    active != null &&
                    active.isNotEmpty &&
                    _isPresetBackgroundValue(active);

                updateDraft(draft.copyWith(clearBackgroundImage: true));

                if (active != null &&
                    active.isNotEmpty &&
                    !isActivePreset &&
                    _customBackgroundImages.contains(active)) {
                  final nextCustoms = List<String>.from(_customBackgroundImages)
                    ..removeWhere((entry) => entry == active);
                  updateCustomBackgroundsInSheet(nextCustoms);
                  unawaited(_deleteManagedBackgroundFileIfNeeded(active));
                }
              }

              Future<ReaderCustomFontEntry?> importCustomFont() async {
                try {
                  final imported =
                      await _fontRegistryService.pickAndImportFont();
                  if (imported == null || !context.mounted) {
                    return null;
                  }
                  final refreshedFonts =
                      await _fontRegistryService.listRegisteredFonts();
                  setModalState(() {
                    availableCustomFonts = refreshedFonts;
                    draft = draft.copyWith(
                      fontSource: ReaderFontSource.custom,
                      fontFamilyKey: imported.fontFamilyKey,
                      customFontPath: imported.filePath,
                    );
                  });
                  if (mounted) {
                    _updateReaderState(() {
                      _customFonts = refreshedFonts;
                    });
                  }
                  return imported;
                } on PlatformException catch (error) {
                  _showMessage('导入字体失败：${error.message ?? error.code}');
                  return null;
                } on ReaderFontRegistryException catch (error) {
                  _showMessage(error.message);
                  return null;
                } catch (error) {
                  _showMessage('导入字体失败：$error');
                  return null;
                }
              }

              ReaderCustomFontEntry? resolveSelectedCustomFont(
                ReaderSettings settings,
              ) {
                if (settings.fontSource != ReaderFontSource.custom) {
                  return null;
                }
                final familyKey = settings.fontFamilyKey;
                if (familyKey == null || familyKey.isEmpty) {
                  return null;
                }
                for (final entry in availableCustomFonts) {
                  if (entry.fontFamilyKey == familyKey) {
                    return entry;
                  }
                }
                return null;
              }

              String systemFontPresetLabel(ReaderSystemFontPreset preset) {
                return switch (preset) {
                  ReaderSystemFontPreset.defaultSans => '系统默认',
                  ReaderSystemFontPreset.serif => '衬线',
                  ReaderSystemFontPreset.monospace => '等宽',
                };
              }

              String currentFontLabel() {
                final selectedCustomFont = resolveSelectedCustomFont(draft);
                if (selectedCustomFont != null) {
                  return selectedCustomFont.displayName;
                }
                return systemFontPresetLabel(draft.systemFontPreset);
              }

              ReaderSettingsGroups semanticGroups() =>
                  settingsGroupingService.split(draft);

              Future<void> openFontPickerSheet() async {
                if (!context.mounted) {
                  return;
                }

                await showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  useSafeArea: true,
                  backgroundColor: readerModalTheme.colorScheme.surface,
                  builder: (sheetContext) {
                    bool isImporting = false;
                    return StatefulBuilder(
                      builder: (sheetContext, setFontSheetState) {
                        Widget buildFontChoiceTile({
                          required String label,
                          required bool selected,
                          required Future<void> Function()? onTap,
                          IconData? icon,
                          bool loading = false,
                        }) {
                          final colorScheme =
                              Theme.of(sheetContext).colorScheme;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap:
                                  onTap == null
                                      ? null
                                      : () => unawaited(onTap()),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color:
                                      selected
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerLow,
                                  border: Border.all(
                                    color:
                                        selected
                                            ? colorScheme.primary.withValues(
                                              alpha: 0.45,
                                            )
                                            : colorScheme.outlineVariant
                                                .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (loading)
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      )
                                    else if (icon != null)
                                      Icon(
                                        icon,
                                        size: 14,
                                        color:
                                            selected
                                                ? colorScheme.onPrimaryContainer
                                                : colorScheme.onSurfaceVariant,
                                      ),
                                    if (icon != null || loading)
                                      const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(
                                          sheetContext,
                                        ).textTheme.labelMedium?.copyWith(
                                          color:
                                              selected
                                                  ? colorScheme
                                                      .onPrimaryContainer
                                                  : colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        Future<void> selectSystemFont(
                          ReaderSystemFontPreset preset,
                        ) async {
                          setModalState(() {
                            draft = draft.copyWith(
                              fontSource: ReaderFontSource.system,
                              systemFontPreset: preset,
                              clearFontFamilyKey: true,
                              clearCustomFontPath: true,
                            );
                          });
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        }

                        Future<void> selectCustomFont(
                          ReaderCustomFontEntry entry,
                        ) async {
                          setModalState(() {
                            draft = draft.copyWith(
                              fontSource: ReaderFontSource.custom,
                              fontFamilyKey: entry.fontFamilyKey,
                              customFontPath: entry.filePath,
                            );
                          });
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        }

                        Future<void> importCustomFontFromSheet() async {
                          if (isImporting) {
                            return;
                          }
                          setFontSheetState(() {
                            isImporting = true;
                          });
                          final imported = await importCustomFont();
                          if (!sheetContext.mounted) {
                            return;
                          }
                          setFontSheetState(() {
                            isImporting = false;
                          });
                          if (imported != null && sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        }

                        final selectedCustomFont = resolveSelectedCustomFont(
                          draft,
                        );

                        final children = <Widget>[
                          buildFontChoiceTile(
                            label: systemFontPresetLabel(
                              ReaderSystemFontPreset.defaultSans,
                            ),
                            selected:
                                draft.fontSource == ReaderFontSource.system &&
                                draft.systemFontPreset ==
                                    ReaderSystemFontPreset.defaultSans,
                            icon: Icons.font_download_outlined,
                            onTap:
                                () => selectSystemFont(
                                  ReaderSystemFontPreset.defaultSans,
                                ),
                          ),
                          buildFontChoiceTile(
                            label: systemFontPresetLabel(
                              ReaderSystemFontPreset.serif,
                            ),
                            selected:
                                draft.fontSource == ReaderFontSource.system &&
                                draft.systemFontPreset ==
                                    ReaderSystemFontPreset.serif,
                            icon: Icons.format_shapes_rounded,
                            onTap:
                                () => selectSystemFont(
                                  ReaderSystemFontPreset.serif,
                                ),
                          ),
                          buildFontChoiceTile(
                            label: systemFontPresetLabel(
                              ReaderSystemFontPreset.monospace,
                            ),
                            selected:
                                draft.fontSource == ReaderFontSource.system &&
                                draft.systemFontPreset ==
                                    ReaderSystemFontPreset.monospace,
                            icon: Icons.code_rounded,
                            onTap:
                                () => selectSystemFont(
                                  ReaderSystemFontPreset.monospace,
                                ),
                          ),
                          ...availableCustomFonts.map(
                            (entry) => buildFontChoiceTile(
                              label: entry.displayName,
                              selected:
                                  selectedCustomFont?.fontFamilyKey ==
                                  entry.fontFamilyKey,
                              icon: Icons.font_download_outlined,
                              onTap: () => selectCustomFont(entry),
                            ),
                          ),
                          buildFontChoiceTile(
                            label: '自定义',
                            selected: false,
                            loading: isImporting,
                            icon: Icons.upload_file_rounded,
                            onTap: importCustomFontFromSheet,
                          ),
                        ];

                        return SizedBox(
                          height: 320,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '选择字体',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '支持系统默认、衬线、等宽和自定义字体。',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    sheetContext,
                                  ).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(
                                          sheetContext,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      Navigator.of(sheetContext).pop();
                                      await openMineFontManagement();
                                    },
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('去我的管理字体'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: GridView.count(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 2.35,
                                    children: children,
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
              }

              String fontWeightLevelLabel(ReaderFontWeightLevel level) {
                return switch (level) {
                  ReaderFontWeightLevel.light => '细',
                  ReaderFontWeightLevel.regular => '常规',
                  ReaderFontWeightLevel.medium => '粗',
                };
              }

              String decorationStyleLabel(ReaderBodyTextDecorationStyle style) {
                return switch (style) {
                  ReaderBodyTextDecorationStyle.none => '无',
                  ReaderBodyTextDecorationStyle.solid => '实线',
                  ReaderBodyTextDecorationStyle.dashed => '虚线',
                };
              }

              int fontWeightValueForLevel(ReaderFontWeightLevel level) {
                return switch (level) {
                  ReaderFontWeightLevel.light => 400,
                  ReaderFontWeightLevel.regular => 500,
                  ReaderFontWeightLevel.medium => 600,
                };
              }

              ReaderFontWeightLevel nearestFontWeightLevel(int value) {
                if (value <= 450) {
                  return ReaderFontWeightLevel.light;
                }
                if (value >= 550) {
                  return ReaderFontWeightLevel.medium;
                }
                return ReaderFontWeightLevel.regular;
              }

              int effectiveFontWeightValue(ReaderSettings settings) {
                return settings.fontWeightValue ??
                    fontWeightValueForLevel(settings.fontWeightLevel);
              }

              String fontWeightDisplayLabel(ReaderSettings settings) {
                final value = effectiveFontWeightValue(settings);
                final mappedLevel = nearestFontWeightLevel(value);
                final presetValue = fontWeightValueForLevel(mappedLevel);
                if (value == presetValue) {
                  return fontWeightLevelLabel(mappedLevel);
                }
                return '$value';
              }

              Widget buildReadingActionTab({
                required String label,
                String? value,
                required VoidCallback onTap,
              }) {
                final colorScheme = Theme.of(context).colorScheme;
                final displayText =
                    value == null || value.isEmpty ? label : '$label · $value';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onTap,
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: colorScheme.surfaceContainerLow,
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Text(
                          displayText,
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              Color interactiveCardColor(Color baseColor, {double alpha = 1}) {
                final targetAlpha =
                    isSliderInteracting ? alpha.clamp(0.0, 1.0) : 1.0;
                return baseColor.withValues(alpha: targetAlpha);
              }

              Future<void> showFloatingReaderSubSheet({
                required Widget Function(
                  BuildContext sheetContext,
                  StateSetter setSheetState,
                )
                builder,
                double maxWidth = 680,
                double heightFactor = 0.5,
              }) async {
                if (!context.mounted) {
                  return;
                }

                await showGeneralDialog<void>(
                  context: context,
                  barrierLabel: 'reader-sub-sheet',
                  barrierDismissible: true,
                  barrierColor: Colors.black.withValues(alpha: 0.03),
                  pageBuilder: (dialogContext, _, __) {
                    return Theme(
                      data: readerModalTheme,
                      child: StatefulBuilder(
                        builder: (sheetContext, setSheetState) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap:
                                      () => Navigator.of(dialogContext).pop(),
                                  child: const SizedBox.shrink(),
                                ),
                              ),
                              _buildFloatingReaderSettingsSheet(
                                context: sheetContext,
                                readerModalTheme: readerModalTheme,
                                keyboardInset:
                                    MediaQuery.viewInsetsOf(
                                      sheetContext,
                                    ).bottom,
                                safeBottom: _bottomSafeInset(sheetContext),
                                sheetHorizontal: AppSpacing.pageHorizontal(
                                  sheetContext,
                                ),
                                maxWidth: maxWidth,
                                heightFactor: heightFactor,
                                child: builder(sheetContext, setSheetState),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 180),
                  transitionBuilder: (context, animation, _, child) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                );
              }

              Future<void> openFontWeightTabSheet() async {
                if (!context.mounted) {
                  return;
                }

                await showFloatingReaderSubSheet(
                  maxWidth: 560,
                  heightFactor: 0.34,
                  builder: (sheetContext, setFontWeightState) {
                    final currentValue = effectiveFontWeightValue(draft);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Text(
                            '字重',
                            textAlign: TextAlign.center,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '当前 $currentValue',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              sheetContext,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    sheetContext,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: ReaderFontWeightLevel.values
                                .map(
                                  (level) => ChoiceChip(
                                    label: Text(fontWeightLevelLabel(level)),
                                    selected:
                                        currentValue ==
                                        fontWeightValueForLevel(level),
                                    onSelected: (_) {
                                      setModalState(() {
                                        draft = draft.copyWith(
                                          fontWeightLevel: level,
                                          fontWeightValue:
                                              fontWeightValueForLevel(level),
                                        );
                                      });
                                      setFontWeightState(() {});
                                    },
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 12),
                          Slider(
                            min: ReaderSettings.minFontWeightValue.toDouble(),
                            max: ReaderSettings.maxFontWeightValue.toDouble(),
                            divisions:
                                (ReaderSettings.maxFontWeightValue -
                                    ReaderSettings.minFontWeightValue) ~/
                                50,
                            value: currentValue.toDouble(),
                            label: '$currentValue',
                            onChanged: (value) {
                              final normalized = (value / 50).round() * 50;
                              setModalState(() {
                                draft = draft.copyWith(
                                  fontWeightLevel: nearestFontWeightLevel(
                                    normalized,
                                  ),
                                  fontWeightValue: normalized,
                                );
                              });
                              setFontWeightState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              Future<void> openHorizontalPaddingTabSheet() async {
                if (!context.mounted) {
                  return;
                }

                await showFloatingReaderSubSheet(
                  maxWidth: 720,
                  heightFactor: 0.72,
                  builder: (sheetContext, setPaddingState) {
                    final colorScheme = Theme.of(sheetContext).colorScheme;
                    final textTheme = Theme.of(sheetContext).textTheme;

                    void updatePaddingSettings(ReaderSettings next) {
                      setModalState(() {
                        draft = next;
                      });
                      setPaddingState(() {});
                    }

                    void updateBodyMargins({
                      double? top,
                      double? bottom,
                      double? left,
                      double? right,
                    }) {
                      final next = draft.copyWith(
                        bodyMarginTop: top ?? draft.bodyMarginTop,
                        bodyMarginBottom: bottom ?? draft.bodyMarginBottom,
                        bodyMarginLeft: left ?? draft.bodyMarginLeft,
                        bodyMarginRight: right ?? draft.bodyMarginRight,
                      );
                      updatePaddingSettings(next);
                    }

                    void resetBodyMarginsToDefault() {
                      updatePaddingSettings(
                        draft.copyWith(
                          bodyMarginTop: 6,
                          bodyMarginBottom: 6,
                          bodyMarginLeft: 16,
                          bodyMarginRight: 16,
                        ),
                      );
                    }

                    Future<double?> promptExactMarginValue({
                      required String label,
                      required double currentValue,
                    }) async {
                      var draftValue = _formatLayoutMarginValue(currentValue);
                      String? errorText;

                      final result = await showDialog<double>(
                        context: sheetContext,
                        builder: (dialogContext) {
                          return StatefulBuilder(
                            builder: (dialogContext, setDialogState) {
                              void submit() {
                                final raw = draftValue.trim();
                                final parsed = double.tryParse(raw);
                                if (parsed == null) {
                                  setDialogState(() {
                                    errorText = '请输入数字';
                                  });
                                  return;
                                }
                                if (parsed < ReaderSettings.minLayoutMargin ||
                                    parsed > ReaderSettings.maxLayoutMargin) {
                                  setDialogState(() {
                                    errorText =
                                        '请输入 ${ReaderSettings.minLayoutMargin.toInt()} - ${ReaderSettings.maxLayoutMargin.toInt()}';
                                  });
                                  return;
                                }
                                Navigator.of(dialogContext).pop(parsed);
                              }

                              return AlertDialog(
                                title: Text('$label 精确输入'),
                                content: TextFormField(
                                  initialValue: draftValue,
                                  autofocus: appEnableAutoFocusForTextInput,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: '边距数值',
                                    helperText:
                                        '范围 ${ReaderSettings.minLayoutMargin.toInt()} - ${ReaderSettings.maxLayoutMargin.toInt()}',
                                    errorText: errorText,
                                  ),
                                  onChanged: (value) {
                                    draftValue = value;
                                    if (errorText != null) {
                                      setDialogState(() {
                                        errorText = null;
                                      });
                                    }
                                  },
                                  onFieldSubmitted: (_) => submit(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(dialogContext).pop(),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: submit,
                                    child: const Text('应用'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );

                      if (result == null) {
                        return null;
                      }
                      return ((result * 2).round() / 2).toDouble();
                    }

                    Widget buildMarginControlRow({
                      required String label,
                      required double value,
                      required ValueChanged<double> onChanged,
                    }) {
                      final safeValue =
                          value
                              .clamp(
                                ReaderSettings.minLayoutMargin,
                                ReaderSettings.maxLayoutMargin,
                              )
                              .toDouble();

                      void nudge(double delta) {
                        final next =
                            (safeValue + delta)
                                .clamp(
                                  ReaderSettings.minLayoutMargin,
                                  ReaderSettings.maxLayoutMargin,
                                )
                                .toDouble();
                        onChanged(next);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 52,
                              child: Text(label, style: textTheme.bodyMedium),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed:
                                  () => nudge(
                                    -_ReaderPageState._kMarginControlStep,
                                  ),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            Expanded(
                              child: buildPreviewAwareSlider(
                                min: ReaderSettings.minLayoutMargin,
                                max: ReaderSettings.maxLayoutMargin,
                                divisions:
                                    ((ReaderSettings.maxLayoutMargin -
                                                ReaderSettings
                                                    .minLayoutMargin) /
                                            _ReaderPageState
                                                ._kMarginControlStep)
                                        .round(),
                                value: safeValue,
                                onChanged: onChanged,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed:
                                  () => nudge(
                                    _ReaderPageState._kMarginControlStep,
                                  ),
                              icon: const Icon(Icons.add_rounded),
                            ),
                            SizedBox(
                              width: 52,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  final exact = await promptExactMarginValue(
                                    label: label,
                                    currentValue: safeValue,
                                  );
                                  if (exact == null) {
                                    return;
                                  }
                                  onChanged(exact);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    _formatLayoutMarginValue(safeValue),
                                    textAlign: TextAlign.right,
                                    style: textTheme.labelLarge?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    Widget buildSectionTitle({
                      required String title,
                      bool? dividerEnabled,
                      ValueChanged<bool>? onDividerChanged,
                      bool dividerInteractive = true,
                    }) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              title,
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (dividerEnabled != null &&
                                onDividerChanged != null)
                              FilterChip(
                                label: const Text('显示分隔线'),
                                selected: dividerInteractive && dividerEnabled,
                                showCheckmark: false,
                                onSelected:
                                    dividerInteractive
                                        ? onDividerChanged
                                        : null,
                              ),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Text(
                            '边距',
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView(
                              children: [
                                buildSectionTitle(title: '正文边距'),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: resetBodyMarginsToDefault,
                                    icon: const Icon(
                                      Icons.restart_alt_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('恢复默认'),
                                  ),
                                ),
                                buildMarginControlRow(
                                  label: '上边距',
                                  value: draft.bodyMarginTop,
                                  onChanged:
                                      (value) => updateBodyMargins(top: value),
                                ),
                                buildMarginControlRow(
                                  label: '下边距',
                                  value: draft.bodyMarginBottom,
                                  onChanged:
                                      (value) =>
                                          updateBodyMargins(bottom: value),
                                ),
                                buildMarginControlRow(
                                  label: '左边距',
                                  value: draft.bodyMarginLeft,
                                  onChanged:
                                      (value) => updateBodyMargins(left: value),
                                ),
                                buildMarginControlRow(
                                  label: '右边距',
                                  value: draft.bodyMarginRight,
                                  onChanged:
                                      (value) =>
                                          updateBodyMargins(right: value),
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final margins =
                                        draft.effectiveBodyMarginValues;
                                    return Text(
                                      '当前正文边距：上 ${margins.top.round()} / 下 ${margins.bottom.round()} / 左 ${margins.left.round()} / 右 ${margins.right.round()}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                buildSectionTitle(title: '信息栏精调'),
                                buildSectionTitle(
                                  title: '页脚',
                                  dividerEnabled:
                                      draft.infoFooterDividerEnabled,
                                  dividerInteractive: draft.infoFooterEnabled,
                                  onDividerChanged: (selected) {
                                    updatePaddingSettings(
                                      draft.copyWith(
                                        infoFooterDividerEnabled: selected,
                                      ),
                                    );
                                  },
                                ),
                                buildMarginControlRow(
                                  label: '上边距',
                                  value: draft.infoFooterMarginTop,
                                  onChanged: (value) {
                                    updatePaddingSettings(
                                      draft.copyWith(
                                        infoFooterMarginTop: value,
                                      ),
                                    );
                                  },
                                ),
                                buildMarginControlRow(
                                  label: '下边距',
                                  value: draft.infoFooterMarginBottom,
                                  onChanged: (value) {
                                    updatePaddingSettings(
                                      draft.copyWith(
                                        infoFooterMarginBottom: value,
                                      ),
                                    );
                                  },
                                ),
                                buildMarginControlRow(
                                  label: '左边距',
                                  value: draft.infoFooterMarginLeft,
                                  onChanged: (value) {
                                    updatePaddingSettings(
                                      draft.copyWith(
                                        infoFooterMarginLeft: value,
                                      ),
                                    );
                                  },
                                ),
                                buildMarginControlRow(
                                  label: '右边距',
                                  value: draft.infoFooterMarginRight,
                                  onChanged: (value) {
                                    updatePaddingSettings(
                                      draft.copyWith(
                                        infoFooterMarginRight: value,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              final showInterfaceSection =
                  initialTab == _ReaderSettingsTab.interface;
              final showReadingSection =
                  initialTab == _ReaderSettingsTab.reading;
              final presetTileScale =
                  (AppLayout.pageContentMaxWidth(context, maxWidth: 760) /
                          360.0)
                      .clamp(0.94, 1.18)
                      .toDouble();
              final presetBackgroundTiles = <Widget>[];
              for (final preset in _backgroundPresets) {
                final previewBytes = _backgroundPresetBytes[preset.assetPath];
                final presetBase64 = _backgroundPresetBase64[preset.assetPath];
                if (previewBytes == null) {
                  continue;
                }
                presetBackgroundTiles.add(
                  Padding(
                    padding: EdgeInsets.only(right: 8 * presetTileScale),
                    child: _buildBackgroundTile(
                      label: preset.label,
                      selected:
                          activeBackgroundBase64 == preset.assetPath ||
                          (presetBase64 != null &&
                              activeBackgroundBase64 == presetBase64),
                      previewBytes: previewBytes,
                      showLabel: false,
                      scale: presetTileScale,
                      onTap: () {
                        updateDraft(
                          draft.copyWith(
                            backgroundImageBase64: preset.assetPath,
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
              final customBackgroundTiles = <Widget>[];
              for (
                var index = 0;
                index < customBackgrounds.length;
                index += 1
              ) {
                final source = customBackgrounds[index];
                final previewBytes = _customBackgroundPreviewBytes[source];
                final isSelected =
                    hasBackgroundImage &&
                    !isPresetBackground &&
                    activeBackgroundBase64 == source;
                customBackgroundTiles.add(
                  Padding(
                    padding: EdgeInsets.only(right: 8 * presetTileScale),
                    child: _buildBackgroundTile(
                      label: '自定义${index + 1}',
                      selected: isSelected,
                      previewBytes: previewBytes,
                      showLabel: true,
                      scale: presetTileScale,
                      icon:
                          previewBytes == null
                              ? Icons.broken_image_outlined
                              : null,
                      onTap:
                          () => unawaited(applyStoredCustomBackground(source)),
                    ),
                  ),
                );
              }
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
              final safeBottom = _bottomSafeInset(context);
              final sheetHeightFactor = _adaptiveReaderSheetHeightFactor(
                context,
                compact: 0.70,
                regular: 0.70,
                large: 0.70,
              );
              final sheetHorizontal = AppSpacing.pageHorizontal(context);
              final maxSheetWidth = AppLayout.pageContentMaxWidth(
                context,
                maxWidth: showReadingSection && !isMangaChapter ? 700 : 640,
              );
              final compactSheetBaseWidth = 360.0;
              final compactSheetVisualWidth = min(
                AppLayout.pageContentMaxWidth(context, maxWidth: 760),
                max(
                  320.0,
                  MediaQuery.sizeOf(context).width - (sheetHorizontal * 2),
                ),
              );
              final compactSheetScale =
                  (compactSheetVisualWidth / compactSheetBaseWidth)
                      .clamp(0.88, 1.08)
                      .toDouble();
              double compactScaleValue(double value) =>
                  value * compactSheetScale;
              final animationPolicy = _resolveAnimationPolicy(
                modeOverride:
                    isMangaChapter
                        ? ReaderContentMode.comic
                        : ReaderContentMode.text,
                pageTurnModeOverride: draft.pageTurnMode,
              );

              void applyTextPresentationMode({
                required bool useScrollLayout,
                ReaderPageAnimationStyle? style,
              }) {
                setModalState(() {
                  draft = draft.copyWith(
                    pageTurnMode:
                        useScrollLayout
                            ? ReaderPageTurnMode.scroll
                            : ReaderPageTurnMode.tapAndSwipe,
                    pageAnimationStyle: style ?? draft.pageAnimationStyle,
                  );
                });
              }

              Widget buildPageAnimationSelector() {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('滚动'),
                          selected: draft.pageTurnMode.usesScrollLayout,
                          showCheckmark: false,
                          onSelected: (_) {
                            applyTextPresentationMode(useScrollLayout: true);
                          },
                        ),
                      ),
                      ...const [
                        ReaderPageAnimationStyle.curl,
                        ReaderPageAnimationStyle.cover,
                        ReaderPageAnimationStyle.translate,
                        ReaderPageAnimationStyle.fade,
                        ReaderPageAnimationStyle.none,
                      ].map(
                        (style) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Tooltip(
                            message: _pageAnimationLabel(style),
                            child: ChoiceChip(
                              label: Text(_pageAnimationLabel(style)),
                              selected:
                                  !draft.pageTurnMode.usesScrollLayout &&
                                  draft.pageAnimationStyle == style,
                              showCheckmark: false,
                              onSelected: (_) {
                                applyTextPresentationMode(
                                  useScrollLayout: false,
                                  style: style,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              Widget buildTypographySliderRow({
                required String label,
                required double value,
                required double min,
                required double max,
                required int divisions,
                required String valueLabel,
                required ValueChanged<double> onChanged,
                double step = 1,
                bool showValueLabel = true,
              }) {
                final safeValue = value.clamp(min, max).toDouble();

                void nudge(double delta) {
                  final next = (safeValue + delta).clamp(min, max).toDouble();
                  onChanged(next);
                }

                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: compactScaleValue(0.5),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: compactScaleValue(28),
                        child: Text(
                          label,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontSize:
                                (Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.fontSize ??
                                    12) *
                                compactSheetScale *
                                0.95,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: BoxConstraints(
                          minWidth: compactScaleValue(28),
                          minHeight: compactScaleValue(28),
                        ),
                        onPressed: () => nudge(-step),
                        icon: Icon(
                          Icons.remove_rounded,
                          size: compactScaleValue(16),
                        ),
                      ),
                      Expanded(
                        child: buildPreviewAwareSlider(
                          min: min,
                          max: max,
                          divisions: divisions,
                          value: safeValue,
                          onChanged: onChanged,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: BoxConstraints(
                          minWidth: compactScaleValue(28),
                          minHeight: compactScaleValue(28),
                        ),
                        onPressed: () => nudge(step),
                        icon: Icon(
                          Icons.add_rounded,
                          size: compactScaleValue(16),
                        ),
                      ),
                      if (showValueLabel)
                        SizedBox(
                          width: compactScaleValue(54),
                          child: Text(
                            valueLabel,
                            textAlign: TextAlign.right,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              fontSize:
                                  (Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.fontSize ??
                                      12) *
                                  compactSheetScale *
                                  0.94,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }

              Widget buildSettingsSectionCard({
                required IconData icon,
                required String title,
                String? subtitle,
                required List<Widget> children,
              }) {
                final colorScheme = Theme.of(context).colorScheme;
                final textTheme = Theme.of(context).textTheme;

                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: compactScaleValue(8)),
                  padding: EdgeInsets.fromLTRB(
                    compactScaleValue(10),
                    compactScaleValue(10),
                    compactScaleValue(10),
                    compactScaleValue(10),
                  ),
                  decoration: BoxDecoration(
                    color: interactiveCardColor(
                      colorScheme.surfaceContainerLow,
                      alpha: 0.54,
                    ),
                    borderRadius: BorderRadius.circular(compactScaleValue(16)),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: compactScaleValue(26),
                            height: compactScaleValue(26),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: 0.76,
                              ),
                              borderRadius: BorderRadius.circular(
                                compactScaleValue(9),
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: compactScaleValue(14),
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          SizedBox(width: compactScaleValue(8)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize:
                                        (textTheme.titleSmall?.fontSize ?? 14) *
                                        compactSheetScale *
                                        0.92,
                                  ),
                                ),
                                if (subtitle != null &&
                                    subtitle.trim().isNotEmpty) ...[
                                  SizedBox(height: compactScaleValue(1)),
                                  Text(
                                    subtitle,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.35,
                                      fontSize:
                                          (textTheme.bodySmall?.fontSize ??
                                              12) *
                                          compactSheetScale *
                                          0.92,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compactScaleValue(10)),
                      ...children,
                    ],
                  ),
                );
              }

              Widget buildSettingsGroupEntryCard({
                required IconData icon,
                required String title,
                required String subtitle,
                required VoidCallback onTap,
              }) {
                final colorScheme = Theme.of(context).colorScheme;
                return InkWell(
                  borderRadius: BorderRadius.circular(compactScaleValue(16)),
                  onTap: onTap,
                  child: Ink(
                    padding: EdgeInsets.fromLTRB(
                      compactScaleValue(12),
                      compactScaleValue(10),
                      compactScaleValue(12),
                      compactScaleValue(10),
                    ),
                    decoration: BoxDecoration(
                      color: interactiveCardColor(
                        colorScheme.surfaceContainerLow,
                        alpha: 0.54,
                      ),
                      borderRadius: BorderRadius.circular(
                        compactScaleValue(16),
                      ),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.38,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: compactScaleValue(28),
                          height: compactScaleValue(28),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.72,
                            ),
                            borderRadius: BorderRadius.circular(
                              compactScaleValue(10),
                            ),
                          ),
                          child: Icon(
                            icon,
                            size: compactScaleValue(14),
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        SizedBox(width: compactScaleValue(9)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize:
                                      (Theme.of(
                                            context,
                                          ).textTheme.titleSmall?.fontSize ??
                                          14) *
                                      compactSheetScale *
                                      0.92,
                                ),
                              ),
                              SizedBox(height: compactScaleValue(2)),
                              Text(
                                subtitle,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                  fontSize:
                                      (Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.fontSize ??
                                          12) *
                                      compactSheetScale *
                                      0.92,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: compactScaleValue(6)),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.onSurfaceVariant,
                          size: compactScaleValue(18),
                        ),
                      ],
                    ),
                  ),
                );
              }

              Widget buildCompactToggleRow({
                required String label,
                required bool value,
                required ValueChanged<bool>? onChanged,
                bool isSaving = false,
              }) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: compactScaleValue(1)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize:
                                (Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.fontSize ??
                                    14) *
                                compactSheetScale *
                                0.94,
                          ),
                        ),
                      ),
                      if (isSaving)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Switch.adaptive(value: value, onChanged: onChanged),
                    ],
                  ),
                );
              }

              Widget buildSectionDivider() {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: compactScaleValue(2.5),
                  ),
                  child: Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                );
              }

              Widget buildTextReaderSettingsSheet() {
                Widget buildCompactSectionTitle(
                  String title, {
                  Widget? trailing,
                }) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          fontSize:
                              (Theme.of(
                                    context,
                                  ).textTheme.titleSmall?.fontSize ??
                                  14) *
                              compactSheetScale *
                              0.9,
                        ),
                      ),
                      const Spacer(),
                      if (trailing != null) trailing,
                    ],
                  );
                }

                Widget buildCompactSettingsCard(List<Widget> children) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: compactScaleValue(8)),
                    padding: EdgeInsets.fromLTRB(
                      compactScaleValue(12),
                      compactScaleValue(12),
                      compactScaleValue(12),
                      compactScaleValue(12),
                    ),
                    decoration: BoxDecoration(
                      color: interactiveCardColor(
                        colorScheme.surfaceContainerLow,
                        alpha: 0.54,
                      ),
                      borderRadius: BorderRadius.circular(
                        compactScaleValue(18),
                      ),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.32,
                        ),
                      ),
                    ),
                    child: Column(children: children),
                  );
                }

                Widget buildInterfaceCapsuleEntry({
                  required IconData icon,
                  required String title,
                  required VoidCallback onTap,
                  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
                }) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Padding(
                    padding: margin,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onTap,
                        child: Ink(
                          padding: EdgeInsets.symmetric(
                            horizontal: compactScaleValue(10),
                            vertical: compactScaleValue(7),
                          ),
                          decoration: BoxDecoration(
                            color: interactiveCardColor(
                              colorScheme.surfaceContainerLow,
                              alpha: 0.54,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.38,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: compactScaleValue(22),
                                height: compactScaleValue(22),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer
                                      .withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  size: compactScaleValue(12),
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              SizedBox(width: compactScaleValue(7)),
                              Expanded(
                                child: Text(
                                  title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize:
                                        (Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.fontSize ??
                                            14) *
                                        compactSheetScale *
                                        0.9,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: compactScaleValue(18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                Widget buildInterfaceInlineCapsule({
                  required Widget child,
                  EdgeInsetsGeometry? padding,
                  Color? backgroundColor,
                  Color? borderColor,
                }) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Container(
                    padding:
                        padding ??
                        EdgeInsets.symmetric(
                          horizontal: compactScaleValue(12),
                          vertical: compactScaleValue(8),
                        ),
                    decoration: BoxDecoration(
                      color: backgroundColor ?? colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            borderColor ??
                            colorScheme.outlineVariant.withValues(alpha: 0.38),
                      ),
                    ),
                    child: child,
                  );
                }

                Widget buildInterfaceSecondaryCapsule({
                  required IconData icon,
                  required String title,
                  required VoidCallback onTap,
                }) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return buildInterfaceInlineCapsule(
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: compactScaleValue(38),
                      child: TextButton(
                        onPressed: onTap,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.symmetric(
                            horizontal: compactScaleValue(8),
                            vertical: compactScaleValue(6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: compactScaleValue(20),
                              height: compactScaleValue(20),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(
                                  alpha: 0.8,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                size: compactScaleValue(11),
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            SizedBox(width: compactScaleValue(6)),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize:
                                      (Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.fontSize ??
                                          14) *
                                      compactSheetScale *
                                      0.88,
                                ),
                              ),
                            ),
                            SizedBox(width: compactScaleValue(2)),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: compactScaleValue(14),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                Widget buildInterfaceIconCapsule({
                  required IconData icon,
                  required String tooltip,
                  required VoidCallback onTap,
                }) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return buildInterfaceInlineCapsule(
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: compactScaleValue(38),
                      width: compactScaleValue(38),
                      child: IconButton(
                        tooltip: tooltip,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: onTap,
                        icon: Icon(
                          icon,
                          size: compactScaleValue(16),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                List<Widget> buildQuickMarginCards() {
                  final marginDivisions =
                      ((ReaderSettings.maxLayoutMargin -
                                  ReaderSettings.minLayoutMargin) /
                              _ReaderPageState._kMarginControlStep)
                          .round();
                  final effectiveMargins = draft.effectiveBodyMarginValues;
                  final groups = semanticGroups();
                  return <Widget>[
                    buildCompactSettingsCard([
                      Row(
                        children: [
                          Expanded(child: buildCompactSectionTitle('正文边距')),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                draft = draft.copyWith(
                                  bodyMarginTop: 6,
                                  bodyMarginBottom: 6,
                                  bodyMarginLeft: 16,
                                  bodyMarginRight: 16,
                                );
                              });
                            },
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 16,
                            ),
                            label: const Text('恢复默认'),
                          ),
                        ],
                      ),
                      Text(
                        '当前：上 ${groups.bodyLayout.bodyMarginTop.toStringAsFixed(0)} / 下 ${groups.bodyLayout.bodyMarginBottom.toStringAsFixed(0)} / 左 ${groups.bodyLayout.bodyMarginLeft.toStringAsFixed(0)} / 右 ${groups.bodyLayout.bodyMarginRight.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      buildTypographySliderRow(
                        label: '上',
                        min: ReaderSettings.minLayoutMargin,
                        max: ReaderSettings.maxLayoutMargin,
                        divisions: marginDivisions,
                        value: draft.bodyMarginTop,
                        step: _ReaderPageState._kMarginControlStep,
                        valueLabel: _formatLayoutMarginValue(
                          draft.bodyMarginTop,
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(bodyMarginTop: value);
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '下',
                        min: ReaderSettings.minLayoutMargin,
                        max: ReaderSettings.maxLayoutMargin,
                        divisions: marginDivisions,
                        value: draft.bodyMarginBottom,
                        step: _ReaderPageState._kMarginControlStep,
                        valueLabel: _formatLayoutMarginValue(
                          draft.bodyMarginBottom,
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(bodyMarginBottom: value);
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '左',
                        min: ReaderSettings.minLayoutMargin,
                        max: ReaderSettings.maxLayoutMargin,
                        divisions: marginDivisions,
                        value: draft.bodyMarginLeft,
                        step: _ReaderPageState._kMarginControlStep,
                        valueLabel: _formatLayoutMarginValue(
                          draft.bodyMarginLeft,
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(bodyMarginLeft: value);
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '右',
                        min: ReaderSettings.minLayoutMargin,
                        max: ReaderSettings.maxLayoutMargin,
                        divisions: marginDivisions,
                        value: draft.bodyMarginRight,
                        step: _ReaderPageState._kMarginControlStep,
                        valueLabel: _formatLayoutMarginValue(
                          draft.bodyMarginRight,
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(bodyMarginRight: value);
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '直接调整正文四边留白，默认口径对齐成熟阅读器的页面 padding。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '当前正文边距：上 ${effectiveMargins.top.round()} / 下 ${effectiveMargins.bottom.round()} / 左 ${effectiveMargins.left.round()} / 右 ${effectiveMargins.right.round()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ]),
                    buildCompactSettingsCard([
                      Row(
                        children: [
                          Expanded(child: buildCompactSectionTitle('阅读排版')),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                draft = draft.copyWith(
                                  lineHeight: 1.67,
                                  paragraphSpacing: 2,
                                  paragraphIndent: 2,
                                  letterSpacing:
                                      ReaderSettings.defaultLetterSpacing,
                                );
                              });
                            },
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 16,
                            ),
                            label: const Text('恢复默认'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      buildTypographySliderRow(
                        label: '字距',
                        min: 0,
                        max: 100,
                        divisions: 100,
                        value: _letterSpacingSliderValue(draft),
                        step: 1,
                        valueLabel: _letterSpacingValueLabel(draft),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              letterSpacing: _letterSpacingFromSliderValue(
                                value,
                              ),
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '行距',
                        min: 0,
                        max: 20,
                        divisions: 20,
                        value: _lineHeightSliderValue(draft),
                        step: 1,
                        valueLabel: _lineHeightValueLabel(draft),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              lineHeight: _lineHeightFromSliderValue(
                                sliderValue: value,
                                settings: draft,
                              ),
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '段距',
                        min: 0,
                        max: 20,
                        divisions: 20,
                        value: draft.paragraphSpacing,
                        step: 1,
                        valueLabel: _paragraphSpacingValueLabel(draft),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(paragraphSpacing: value);
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '缩进',
                        min: 0,
                        max: 4,
                        divisions: 4,
                        value: draft.paragraphIndent.clamp(0, 4).toDouble(),
                        step: 1,
                        valueLabel: _paragraphIndentValueLabel(draft),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              paragraphIndent:
                                  value.round().clamp(0, 4).toDouble(),
                            );
                          });
                        },
                      ),
                    ]),
                    buildCompactSettingsCard([
                      Row(
                        children: [
                          Expanded(child: buildCompactSectionTitle('章节头')),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                draft = draft.copyWith(
                                  chapterHeaderHorizontalOffset: 0,
                                  chapterHeaderVerticalOffset: 0,
                                );
                              });
                            },
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 16,
                            ),
                            label: const Text('恢复默认'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      buildTypographySliderRow(
                        label: '横向',
                        min: ReaderSettings.minPinnedHeaderOffsetX,
                        max: ReaderSettings.maxPinnedHeaderOffsetX,
                        divisions: 100,
                        value: draft.chapterHeaderHorizontalOffset,
                        step: 0.01,
                        valueLabel:
                            (draft.chapterHeaderHorizontalOffset * 100)
                                .round()
                                .toString(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              chapterHeaderHorizontalOffset: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '纵向',
                        min: ReaderSettings.minChapterHeaderVerticalOffset,
                        max: ReaderSettings.maxChapterHeaderSpacing,
                        divisions:
                            (ReaderSettings.maxChapterHeaderSpacing -
                                    ReaderSettings
                                        .minChapterHeaderVerticalOffset)
                                .round(),
                        value: draft.chapterHeaderVerticalOffset,
                        step: 1,
                        valueLabel:
                            draft.chapterHeaderVerticalOffset
                                .round()
                                .toString(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              chapterHeaderVerticalOffset: value,
                            );
                          });
                        },
                      ),
                    ]),
                  ];
                }

                final quickToggleCard = buildSettingsSectionCard(
                  icon: Icons.toggle_on_rounded,
                  title: '快捷开关',
                  children: [
                    buildCompactToggleRow(
                      label: '文字两端对齐',
                      value: draft.textFullJustifyEnabled,
                      onChanged: (enabled) {
                        setModalState(() {
                          draft = draft.copyWith(
                            textFullJustifyEnabled: enabled,
                          );
                        });
                      },
                    ),
                    buildSectionDivider(),
                    buildCompactToggleRow(
                      label: '音量键翻页',
                      value: draft.volumeKeyPageEnabled,
                      onChanged:
                          ReaderVolumeKeyPageBridge.instance.isSupported
                              ? (enabled) {
                                setModalState(() {
                                  draft = draft.copyWith(
                                    volumeKeyPageEnabled: enabled,
                                  );
                                });
                              }
                              : null,
                    ),
                    if (!ReaderVolumeKeyPageBridge.instance.isSupported) ...[
                      const SizedBox(height: 4),
                      Text(
                        _volumeKeyPageSupportDescription,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                );

                final selectedCards = switch (activeSettingsGroupKey) {
                  null =>
                    showInterfaceSettings
                        ? <Widget>[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '亮度',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          draft.followSystemBrightness
                                              ? '当前跟随系统亮度变化'
                                              : '关闭后可单独调节阅读器亮度',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: draft.followSystemBrightness,
                                    onChanged: (enabled) {
                                      setModalState(() {
                                        draft = draft.copyWith(
                                          followSystemBrightness: enabled,
                                        );
                                      });
                                    },
                                  ),
                                  SizedBox(
                                    height: 48,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        final selected =
                                            draft.themeMode !=
                                            ReaderThemeMode.sepia;
                                        setModalState(() {
                                          draft = draft.copyWith(
                                            themeMode:
                                                selected
                                                    ? ReaderThemeMode.sepia
                                                    : ReaderThemeMode.light,
                                            backgroundStyle:
                                                selected
                                                    ? ReaderBackgroundStyle.warm
                                                    : ReaderBackgroundStyle
                                                        .plain,
                                            backgroundTone:
                                                selected
                                                    ? ReaderBackgroundTone
                                                        .container
                                                    : ReaderBackgroundTone
                                                        .surface,
                                          );
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: compactScaleValue(6),
                                          vertical: compactScaleValue(10),
                                        ),
                                      ),
                                      icon: Icon(
                                        draft.themeMode == ReaderThemeMode.sepia
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_outlined,
                                        size: compactScaleValue(16),
                                        color:
                                            draft.themeMode ==
                                                    ReaderThemeMode.sepia
                                                ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                                : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                      ),
                                      label: Text(
                                        '护眼',
                                        style: TextStyle(
                                          color:
                                              draft.themeMode ==
                                                      ReaderThemeMode.sepia
                                                  ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                  : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: buildPreviewAwareSlider(
                                      min: 0.2,
                                      max: 1,
                                      divisions: 8,
                                      value: draft.brightness,
                                      onChanged:
                                          draft.followSystemBrightness
                                              ? null
                                              : (value) {
                                                setModalState(() {
                                                  draft = draft.copyWith(
                                                    brightness: value,
                                                  );
                                                });
                                              },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 52,
                                    child: Text(
                                      draft.followSystemBrightness
                                          ? '系统'
                                          : '${(draft.brightness * 100).round()}%',
                                      textAlign: TextAlign.right,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: compactScaleValue(8)),
                          Row(
                            children: [
                              Expanded(
                                child: buildInterfaceCapsuleEntry(
                                  icon: Icons.format_size_rounded,
                                  title: '字体',
                                  margin: EdgeInsets.zero,
                                  onTap:
                                      () => setModalState(() {
                                        activeSettingsGroupKey = 'typography';
                                      }),
                                ),
                              ),
                              SizedBox(width: compactScaleValue(8)),
                              Expanded(
                                child: buildInterfaceCapsuleEntry(
                                  icon: Icons.fit_screen_rounded,
                                  title: '边距',
                                  margin: EdgeInsets.zero,
                                  onTap:
                                      () => setModalState(() {
                                        activeSettingsGroupKey =
                                            'quick_margins';
                                      }),
                                ),
                              ),
                              SizedBox(width: compactScaleValue(8)),
                              Expanded(
                                child: buildInterfaceCapsuleEntry(
                                  icon: Icons.info_outline_rounded,
                                  title: '信息',
                                  margin: EdgeInsets.zero,
                                  onTap:
                                      () => setModalState(() {
                                        activeSettingsGroupKey = 'info';
                                      }),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compactScaleValue(8)),
                          Padding(
                            padding: EdgeInsets.only(
                              left: compactScaleValue(2),
                            ),
                            child: Text(
                              '字号',
                              style: Theme.of(
                                context,
                              ).textTheme.labelMedium?.copyWith(
                                fontSize:
                                    (Theme.of(
                                          context,
                                        ).textTheme.labelMedium?.fontSize ??
                                        12) *
                                    compactSheetScale *
                                    0.9,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(height: compactScaleValue(4)),
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: buildInterfaceInlineCapsule(
                                  padding: EdgeInsets.zero,
                                  child: SizedBox(
                                    height: compactScaleValue(38),
                                    child: Row(
                                      children: [
                                        SizedBox(width: compactScaleValue(6)),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: BoxConstraints(
                                            minWidth: compactScaleValue(26),
                                            minHeight: compactScaleValue(26),
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            final next =
                                                (draft.fontSize - 1)
                                                    .clamp(5, 50)
                                                    .toDouble();
                                            setModalState(() {
                                              draft = draft.copyWith(
                                                fontSize: next,
                                              );
                                            });
                                          },
                                          icon: Icon(
                                            Icons.remove_rounded,
                                            size: compactScaleValue(15),
                                          ),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              draft.fontSize.toStringAsFixed(0),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                height: 1,
                                                fontSize:
                                                    (Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.fontSize ??
                                                        14) *
                                                    compactSheetScale *
                                                    0.95,
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: BoxConstraints(
                                            minWidth: compactScaleValue(26),
                                            minHeight: compactScaleValue(26),
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            final next =
                                                (draft.fontSize + 1)
                                                    .clamp(5, 50)
                                                    .toDouble();
                                            setModalState(() {
                                              draft = draft.copyWith(
                                                fontSize: next,
                                              );
                                            });
                                          },
                                          icon: Icon(
                                            Icons.add_rounded,
                                            size: compactScaleValue(15),
                                          ),
                                        ),
                                        SizedBox(width: compactScaleValue(6)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: compactScaleValue(6)),
                              Expanded(
                                flex: 4,
                                child: buildInterfaceSecondaryCapsule(
                                  icon: Icons.format_size_rounded,
                                  title: currentFontLabel(),
                                  onTap: openFontPickerSheet,
                                ),
                              ),
                              SizedBox(width: compactScaleValue(6)),
                              buildInterfaceIconCapsule(
                                icon: Icons.tune_rounded,
                                tooltip: '更多',
                                onTap:
                                    () => setModalState(() {
                                      activeSettingsGroupKey = 'interaction';
                                    }),
                              ),
                            ],
                          ),
                          SizedBox(height: compactScaleValue(14)),
                          buildCompactSectionTitle('背景色'),
                          SizedBox(height: compactScaleValue(10)),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _readerBackgroundColorOptions()
                                  .map(
                                    (option) => _buildThemeColorDot(
                                      draft: draft,
                                      color: option.previewColor,
                                      label: option.label,
                                      mode: option.mode,
                                      backgroundStyle: option.backgroundStyle,
                                      backgroundTone: option.backgroundTone,
                                      scale: compactSheetScale,
                                      onChanged: updateDraft,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                          SizedBox(height: compactScaleValue(14)),
                          buildCompactSectionTitle('背景图'),
                          SizedBox(height: compactScaleValue(10)),
                          ScrollConfiguration(
                            behavior: ScrollConfiguration.of(
                              context,
                            ).copyWith(
                              dragDevices: _ReaderPageState._kScrollDragDevices,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildBackgroundTile(
                                    label: '无背景',
                                    selected: !hasBackgroundImage,
                                    icon: Icons.hide_image_outlined,
                                    scale: compactSheetScale,
                                    onTap: () {
                                      updateDraft(
                                        draft.copyWith(
                                          clearBackgroundImage: true,
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(width: compactScaleValue(8)),
                                  ...presetBackgroundTiles,
                                  ...customBackgroundTiles,
                                  _buildBackgroundTile(
                                    label: '自定义',
                                    selected: false,
                                    icon: Icons.upload_file_rounded,
                                    showLabel: true,
                                    scale: compactSheetScale,
                                    onTap: applyCustomBackgroundImage,
                                  ),
                                  SizedBox(width: compactScaleValue(8)),
                                  OutlinedButton.icon(
                                    onPressed:
                                        () => unawaited(
                                          openMineReaderBackgroundManagement(),
                                        ),
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('去我的管理'),
                                  ),
                                  if (hasBackgroundImage) ...[
                                    SizedBox(width: compactScaleValue(8)),
                                    OutlinedButton(
                                      onPressed:
                                          () => unawaited(
                                            removeActiveBackground(),
                                          ),
                                      child: const Text('移除'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          buildCompactSectionTitle('翻页动画'),
                          const SizedBox(height: 10),
                          buildPageAnimationSelector(),
                          const SizedBox(height: 8),
                          Text(
                            draft.pageTurnMode.usesScrollLayout
                                ? '当前为滚动阅读。分页时默认固定为点按 + 滑动。'
                                : '当前为分页阅读，默认固定使用点按 + 滑动翻页。',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ]
                        : <Widget>[
                          buildSettingsGroupEntryCard(
                            icon: Icons.toggle_on_rounded,
                            title: '阅读行为',
                            subtitle: '对齐、按键行为等常用开关',
                            onTap:
                                () => setModalState(() {
                                  activeSettingsGroupKey = 'behavior';
                                }),
                          ),
                          const SizedBox(height: 10),
                          buildSettingsGroupEntryCard(
                            icon: Icons.auto_awesome_motion_outlined,
                            title: '自动阅读',
                            subtitle: '启动方式、速度与本次自动阅读行为',
                            onTap:
                                () => setModalState(() {
                                  activeSettingsGroupKey = 'auto_read';
                                }),
                          ),
                        ],
                  'quick_margins' => buildQuickMarginCards(),
                  'typography' => <Widget>[
                    buildCompactSectionTitle('字体样式'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          currentFontLabel(),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => unawaited(openFontWeightTabSheet()),
                          child: Text(fontWeightDisplayLabel(draft)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => unawaited(openMineFontManagement()),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('去我的管理'),
                        ),
                      ],
                    ),
                    buildSectionDivider(),
                    buildCompactSectionTitle(
                      '颜色样式',
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                draft = draft.copyWith(
                                  clearBodyTextColor: true,
                                );
                              });
                            },
                            child: const Text('跟随主题'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final selectedColor =
                                  await _showBodyTextColorPickerDialog(
                                    context,
                                    initialColorValue: draft.bodyTextColorValue,
                                  );
                              if (selectedColor == null || !context.mounted) {
                                return;
                              }
                              setModalState(() {
                                draft = draft.copyWith(
                                  bodyTextColorValue: selectedColor,
                                );
                              });
                              unawaited(rememberBodyTextColor(selectedColor));
                            },
                            icon: const Icon(Icons.colorize_rounded, size: 16),
                            label: const Text('自定义'),
                          ),
                        ],
                      ),
                    ),
                    if (draft.bodyTextColorValue != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(draft.bodyTextColorValue!),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                    buildSectionDivider(),
                    buildCompactSectionTitle('字体细节'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('斜体'),
                          selected: draft.bodyTextItalicEnabled,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setModalState(() {
                              draft = draft.copyWith(
                                bodyTextItalicEnabled: selected,
                              );
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('阴影'),
                          selected: draft.bodyTextShadowEnabled,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setModalState(() {
                              draft = draft.copyWith(
                                bodyTextShadowEnabled: selected,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    if (draft.bodyTextShadowEnabled) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final selectedColor =
                                  await _showBodyTextShadowColorPickerDialog(
                                    context,
                                    initialColorValue:
                                        draft.bodyTextShadowColorValue,
                                  );
                              if (selectedColor == null || !context.mounted) {
                                return;
                              }
                              setModalState(() {
                                draft = draft.copyWith(
                                  bodyTextShadowColorValue: selectedColor,
                                );
                              });
                            },
                            icon: const Icon(Icons.blur_on_rounded, size: 16),
                            label: const Text('阴影颜色'),
                          ),
                          if (draft.bodyTextShadowColorValue != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(draft.bodyTextShadowColorValue!),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      buildTypographySliderRow(
                        label: '模糊',
                        min: 0,
                        max: 32,
                        divisions: 32,
                        value: draft.bodyTextShadowBlurRadius,
                        step: 1,
                        valueLabel:
                            draft.bodyTextShadowBlurRadius.round().toString(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyTextShadowBlurRadius: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: 'X轴',
                        min: -24,
                        max: 24,
                        divisions: 48,
                        value: draft.bodyTextShadowOffsetDx,
                        step: 1,
                        valueLabel: draft.bodyTextShadowOffsetDx
                            .toStringAsFixed(0),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyTextShadowOffsetDx: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: 'Y轴',
                        min: -24,
                        max: 24,
                        divisions: 48,
                        value: draft.bodyTextShadowOffsetDy,
                        step: 1,
                        valueLabel: draft.bodyTextShadowOffsetDy
                            .toStringAsFixed(0),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyTextShadowOffsetDy: value,
                            );
                          });
                        },
                      ),
                    ],
                    buildSectionDivider(),
                    buildCompactSectionTitle('下划线'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('下划线'),
                          selected:
                              draft.bodyTextDecorationStyle !=
                              ReaderBodyTextDecorationStyle.none,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setModalState(() {
                              draft = draft.copyWith(
                                bodyTextDecorationStyle:
                                    selected
                                        ? ReaderBodyTextDecorationStyle.solid
                                        : ReaderBodyTextDecorationStyle.none,
                              );
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('虚线'),
                          selected:
                              draft.bodyTextDecorationStyle ==
                              ReaderBodyTextDecorationStyle.dashed,
                          showCheckmark: false,
                          onSelected:
                              draft.bodyTextDecorationStyle ==
                                      ReaderBodyTextDecorationStyle.none
                                  ? null
                                  : (selected) {
                                    setModalState(() {
                                      draft = draft.copyWith(
                                        bodyTextDecorationStyle:
                                            selected
                                                ? ReaderBodyTextDecorationStyle
                                                    .dashed
                                                : ReaderBodyTextDecorationStyle
                                                    .solid,
                                      );
                                    });
                                  },
                        ),
                      ],
                    ),
                    if (draft.bodyTextDecorationStyle !=
                        ReaderBodyTextDecorationStyle.none) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setModalState(() {
                                draft = draft.copyWith(
                                  clearBodyTextDecorationColor: true,
                                );
                              });
                            },
                            icon: const Icon(Icons.format_color_reset_rounded),
                            label: const Text('下划线颜色'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final selectedColor =
                                  await _showBodyTextDecorationColorPickerDialog(
                                    context,
                                    initialColorValue:
                                        draft.bodyTextDecorationColorValue,
                                  );
                              if (selectedColor == null || !context.mounted) {
                                return;
                              }
                              setModalState(() {
                                draft = draft.copyWith(
                                  bodyTextDecorationColorValue: selectedColor,
                                );
                              });
                            },
                            icon: const Icon(Icons.colorize_rounded, size: 16),
                            label: const Text('自定义颜色'),
                          ),
                          if (draft.bodyTextDecorationColorValue != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(
                                  draft.bodyTextDecorationColorValue!,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      buildTypographySliderRow(
                        label: '线段高度',
                        min: 1,
                        max: 10,
                        divisions: 18,
                        value: draft.bodyTextUnderlineThickness,
                        step: 0.5,
                        valueLabel: draft.bodyTextUnderlineThickness
                            .toStringAsFixed(1),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyTextUnderlineThickness: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '离字间距',
                        min: 0,
                        max: 16,
                        divisions: 16,
                        value: draft.bodyTextUnderlineGap,
                        step: 1,
                        valueLabel:
                            draft.bodyTextUnderlineGap.round().toString(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(bodyTextUnderlineGap: value);
                          });
                        },
                      ),
                      if (draft.bodyTextDecorationStyle ==
                          ReaderBodyTextDecorationStyle.dashed) ...[
                        buildTypographySliderRow(
                          label: '线段长',
                          min: 1,
                          max: 24,
                          divisions: 23,
                          value: draft.bodyTextUnderlineDashLength,
                          step: 1,
                          valueLabel:
                              draft.bodyTextUnderlineDashLength
                                  .round()
                                  .toString(),
                          onChanged: (value) {
                            setModalState(() {
                              draft = draft.copyWith(
                                bodyTextUnderlineDashLength: value,
                              );
                            });
                          },
                        ),
                        buildTypographySliderRow(
                          label: '空隙比例',
                          min: 1,
                          max: 12,
                          divisions: 11,
                          value: draft.bodyTextUnderlineDashGapRatio,
                          step: 1,
                          valueLabel:
                              draft.bodyTextUnderlineDashGapRatio
                                  .round()
                                  .toString(),
                          onChanged: (value) {
                            setModalState(() {
                              draft = draft.copyWith(
                                bodyTextUnderlineDashGapRatio: value,
                              );
                            });
                          },
                        ),
                      ],
                    ],
                    buildSectionDivider(),
                  ],
                  'interaction' => <Widget>[
                    buildCompactSettingsCard([
                      buildCompactSectionTitle('排版对齐'),
                      const SizedBox(height: 10),
                      buildCompactToggleRow(
                        label: '文字两端对齐',
                        value: draft.textFullJustifyEnabled,
                        onChanged: (enabled) {
                          setModalState(() {
                            draft = draft.copyWith(
                              textFullJustifyEnabled: enabled,
                            );
                          });
                        },
                      ),
                      buildSectionDivider(),
                      buildCompactToggleRow(
                        label: '文字底部对齐',
                        value: draft.textBottomJustifyEnabled,
                        onChanged:
                            draft.pageTurnMode.usesScrollLayout
                                ? null
                                : (enabled) {
                                  setModalState(() {
                                    draft = draft.copyWith(
                                      textBottomJustifyEnabled: enabled,
                                    );
                                  });
                                },
                      ),
                      if (draft.pageTurnMode.usesScrollLayout) ...[
                        const SizedBox(height: 4),
                        Text(
                          '底部对齐仅在分页阅读下生效，滚动阅读不会分配页内剩余高度。',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                      buildSectionDivider(),
                      buildCompactSectionTitle('音量键翻页'),
                      const SizedBox(height: 10),
                      buildCompactToggleRow(
                        label: '启用',
                        value: draft.volumeKeyPageEnabled,
                        onChanged:
                            ReaderVolumeKeyPageBridge.instance.isSupported
                                ? (enabled) {
                                  setModalState(() {
                                    draft = draft.copyWith(
                                      volumeKeyPageEnabled: enabled,
                                    );
                                  });
                                }
                                : null,
                      ),
                    ]),
                  ],
                  'info' => <Widget>[
                    buildCompactSettingsCard([
                      buildCompactSectionTitle('信息位'),
                      const SizedBox(height: 10),
                      buildCompactToggleRow(
                        label: '显示页脚',
                        value: draft.infoFooterEnabled,
                        onChanged: (enabled) {
                          setModalState(() {
                            draft = draft.copyWith(
                              infoFooterEnabled: enabled,
                              infoFooterDividerEnabled:
                                  enabled
                                      ? draft.infoFooterDividerEnabled
                                      : false,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('时间'),
                            selected: draft.infoShowTime,
                            onSelected: (selected) {
                              setModalState(() {
                                draft = draft.copyWith(
                                  infoShowTime: selected,
                                  infoShowProgress:
                                      !selected &&
                                              !draft.infoShowBattery &&
                                              !draft.infoShowProgress
                                          ? true
                                          : draft.infoShowProgress,
                                );
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('电量'),
                            selected: draft.infoShowBattery,
                            onSelected: (selected) {
                              setModalState(() {
                                draft = draft.copyWith(
                                  infoShowBattery: selected,
                                  infoShowProgress:
                                      !selected &&
                                              !draft.infoShowTime &&
                                              !draft.infoShowProgress
                                          ? true
                                          : draft.infoShowProgress,
                                );
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('进度'),
                            selected: draft.infoShowProgress,
                            onSelected: (selected) {
                              setModalState(() {
                                draft = draft.copyWith(
                                  infoShowProgress:
                                      selected ||
                                              (!draft.infoShowTime &&
                                                  !draft.infoShowBattery)
                                          ? true
                                          : selected,
                                );
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('章节'),
                            selected: draft.infoShowChapter,
                            onSelected: (selected) {
                              setModalState(() {
                                draft = draft.copyWith(
                                  infoShowChapter: selected,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      buildCompactSectionTitle('页脚样式'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('页脚分隔线'),
                            selected:
                                draft.infoFooterEnabled &&
                                draft.infoFooterDividerEnabled,
                            showCheckmark: false,
                            onSelected:
                                draft.infoFooterEnabled
                                    ? (selected) {
                                      setModalState(() {
                                        draft = draft.copyWith(
                                          infoFooterDividerEnabled: selected,
                                        );
                                      });
                                    }
                                    : null,
                          ),
                        ],
                      ),
                      buildTypographySliderRow(
                        label: '页脚内距',
                        min: ReaderSettings.minInfoBarPadding,
                        max: ReaderSettings.maxInfoBarPadding,
                        divisions: 24,
                        value: draft.infoFooterPadding,
                        step: 1,
                        valueLabel: draft.infoFooterPadding.round().toString(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(infoFooterPadding: value);
                          });
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            const defaults = ReaderSettings();
                            setModalState(() {
                              draft = draft.copyWith(
                                infoFooterDividerEnabled:
                                    defaults.infoFooterDividerEnabled,
                                infoFooterPadding: defaults.infoFooterPadding,
                              );
                            });
                          },
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text('恢复默认'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '页脚内距只控制左右向内收缩，拉高后页脚信息会从两边明显往中间聚拢。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      if (draft.infoShowBattery) ...[
                        const SizedBox(height: 6),
                        Text(
                          _readerBatteryReadFailed
                              ? '当前平台未返回电量值，已显示为 N/A。'
                              : '电量为实时读取，约每 30 秒刷新一次。',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ]),
                  ],
                  'behavior' => <Widget>[
                    buildCompactSettingsCard([quickToggleCard]),
                  ],
                  'auto_read' => <Widget>[
                    buildCompactSettingsCard([
                      buildCompactSectionTitle('自动阅读'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              startAutoReadAfterApply
                                  ? '关闭弹窗后立即启动自动阅读'
                                  : '本次不启动自动阅读',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Switch.adaptive(
                            value: startAutoReadAfterApply,
                            onChanged: (enabled) {
                              setModalState(() {
                                startAutoReadAfterApply = enabled;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '速度 ${draft.autoReadSpeed.round()} px/s',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      buildPreviewAwareSlider(
                        min: ReaderSettings.minAutoReadSpeed,
                        max: ReaderSettings.maxAutoReadSpeed,
                        divisions: 20,
                        label: '${draft.autoReadSpeed.round()}',
                        value:
                            draft.autoReadSpeed
                                .clamp(
                                  ReaderSettings.minAutoReadSpeed,
                                  ReaderSettings.maxAutoReadSpeed,
                                )
                                .toDouble(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(autoReadSpeed: value);
                          });
                        },
                      ),
                    ]),
                  ],
                  _ => const <Widget>[],
                };
                final sheetTitle = switch (activeSettingsGroupKey) {
                  'quick_margins' => '边距与排版',
                  'typography' => '字体',
                  'interaction' => '翻页与动画',
                  'info' => '信息排版',
                  'behavior' => '阅读行为',
                  'auto_read' => '自动阅读',
                  _ => showInterfaceSettings ? '界面设置' : '设置',
                };
                final textSheetMaxWidth = AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: 760,
                );

                return AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: SafeArea(
                    child: FractionallySizedBox(
                      heightFactor: _adaptiveReaderSheetHeightFactor(
                        context,
                        compact: 0.84,
                        regular: 0.76,
                        large: 0.7,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: textSheetMaxWidth,
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              sheetHorizontal,
                              8,
                              sheetHorizontal,
                              14,
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 40,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (activeSettingsGroupKey != null)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              setModalState(() {
                                                activeSettingsGroupKey = null;
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.arrow_back_rounded,
                                            ),
                                          ),
                                        ),
                                      Center(
                                        child: Text(
                                          sheetTitle,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView(
                                    padding: EdgeInsets.only(
                                      bottom: safeBottom + 12,
                                    ),
                                    children: selectedCards,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              previewDraftSettings();

              if (!isMangaChapter) {
                return wrapSheetSurface(buildTextReaderSettingsSheet());
              }

              return wrapSheetSurface(
                AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: SafeArea(
                    child: FractionallySizedBox(
                      heightFactor: sheetHeightFactor,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxSheetWidth),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              sheetHorizontal,
                              8,
                              sheetHorizontal,
                              14,
                            ),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    showInterfaceSection
                                        ? _readerModeCapabilities
                                            .interfaceSettingsTitle
                                        : _readerModeCapabilities
                                            .readingSettingsTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView(
                                    padding: EdgeInsets.only(
                                      bottom: safeBottom + 12,
                                    ),
                                    children: [
                                      if (showInterfaceSection) ...[
                                        _buildSettingLine(
                                          context: context,
                                          label: '亮度',
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      draft.followSystemBrightness
                                                          ? '当前跟随系统亮度变化'
                                                          : '关闭后可单独调节阅读器亮度',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Switch.adaptive(
                                                    value:
                                                        draft
                                                            .followSystemBrightness,
                                                    onChanged: (enabled) {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          followSystemBrightness:
                                                              enabled,
                                                        );
                                                      });
                                                      previewDraftSettings();
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: buildPreviewAwareSlider(
                                                      min: 0.2,
                                                      max: 1,
                                                      divisions: 8,
                                                      value: draft.brightness,
                                                      label:
                                                          '${(draft.brightness * 100).round()}%',
                                                      onChanged:
                                                          draft.followSystemBrightness
                                                              ? null
                                                              : (value) {
                                                                setModalState(() {
                                                                  draft = draft
                                                                      .copyWith(
                                                                        brightness:
                                                                            value,
                                                                      );
                                                                });
                                                                previewDraftSettings();
                                                              },
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 44,
                                                    child: Text(
                                                      draft.followSystemBrightness
                                                          ? '系统'
                                                          : '${(draft.brightness * 100).round()}%',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                      _createReaderBackgroundColorOption(
                                                        label: '浅色',
                                                        mode:
                                                            ReaderThemeMode
                                                                .light,
                                                        backgroundStyle:
                                                            ReaderBackgroundStyle
                                                                .plain,
                                                        backgroundTone:
                                                            ReaderBackgroundTone
                                                                .surface,
                                                      ),
                                                      _createReaderBackgroundColorOption(
                                                        label: '护眼',
                                                        mode:
                                                            ReaderThemeMode
                                                                .sepia,
                                                        backgroundStyle:
                                                            ReaderBackgroundStyle
                                                                .warm,
                                                        backgroundTone:
                                                            ReaderBackgroundTone
                                                                .container,
                                                      ),
                                                      _createReaderBackgroundColorOption(
                                                        label: '深色',
                                                        mode:
                                                            ReaderThemeMode
                                                                .dark,
                                                        backgroundStyle:
                                                            ReaderBackgroundStyle
                                                                .plain,
                                                        backgroundTone:
                                                            ReaderBackgroundTone
                                                                .pureBlack,
                                                      ),
                                                      _createReaderBackgroundColorOption(
                                                        label: '纸张',
                                                        mode:
                                                            ReaderThemeMode
                                                                .light,
                                                        backgroundStyle:
                                                            ReaderBackgroundStyle
                                                                .paper,
                                                        backgroundTone:
                                                            ReaderBackgroundTone
                                                                .containerHigh,
                                                      ),
                                                    ]
                                                    .map((option) {
                                                      final normalizedTone =
                                                          normalizeReaderBackgroundTone(
                                                            mode:
                                                                draft.themeMode,
                                                            tone:
                                                                draft
                                                                    .backgroundTone,
                                                          );
                                                      final selected =
                                                          draft.themeMode ==
                                                              option.mode &&
                                                          draft.backgroundStyle ==
                                                              option
                                                                  .backgroundStyle &&
                                                          normalizedTone ==
                                                              option
                                                                  .backgroundTone;
                                                      return ChoiceChip(
                                                        label: Text(
                                                          option.label,
                                                        ),
                                                        selected: selected,
                                                        showCheckmark: false,
                                                        onSelected: (_) {
                                                          setModalState(() {
                                                            draft = draft.copyWith(
                                                              themeMode:
                                                                  option.mode,
                                                              backgroundStyle:
                                                                  option
                                                                      .backgroundStyle,
                                                              backgroundTone:
                                                                  option
                                                                      .backgroundTone,
                                                            );
                                                          });
                                                          previewDraftSettings();
                                                        },
                                                      );
                                                    })
                                                    .toList(growable: false),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isMangaChapter) ...[
                                          const Divider(height: 1),
                                          _buildSettingLine(
                                            context: context,
                                            label: '字号',
                                            child: Row(
                                              children: [
                                                IconButton.filledTonal(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () {
                                                    final next =
                                                        (draft.fontSize - 1)
                                                            .clamp(5, 50)
                                                            .toDouble();
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        fontSize: next,
                                                      );
                                                    });
                                                  },
                                                  icon: const Icon(
                                                    Icons.remove,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 40,
                                                  child: Center(
                                                    child: Text(
                                                      draft.fontSize
                                                          .toStringAsFixed(0),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                IconButton.filledTonal(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () {
                                                    final next =
                                                        (draft.fontSize + 1)
                                                            .clamp(5, 50)
                                                            .toDouble();
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        fontSize: next,
                                                      );
                                                    });
                                                  },
                                                  icon: const Icon(Icons.add),
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: OutlinedButton(
                                                    onPressed:
                                                        openFontPickerSheet,
                                                    style:
                                                        OutlinedButton.styleFrom(
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          alignment:
                                                              Alignment.center,
                                                        ),
                                                    child: Text(
                                                      currentFontLabel(),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const Divider(height: 1),
                                        _buildSettingLine(
                                          context: context,
                                          label: '背景颜色',
                                          labelWidth: 72,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: _readerBackgroundColorOptions()
                                                  .map(
                                                    (
                                                      option,
                                                    ) => _buildThemeColorDot(
                                                      draft: draft,
                                                      color:
                                                          option.previewColor,
                                                      label: option.label,
                                                      mode: option.mode,
                                                      backgroundStyle:
                                                          option
                                                              .backgroundStyle,
                                                      backgroundTone:
                                                          option.backgroundTone,
                                                      onChanged: (next) {
                                                        setModalState(() {
                                                          draft = next;
                                                        });
                                                      },
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            ),
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        _buildSettingLine(
                                          context: context,
                                          label: '背景',
                                          child: ScrollConfiguration(
                                            behavior: ScrollConfiguration.of(
                                              context,
                                            ).copyWith(
                                              dragDevices:
                                                  _ReaderPageState
                                                      ._kScrollDragDevices,
                                            ),
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children: [
                                                  _buildBackgroundTile(
                                                    label: '无背景',
                                                    selected:
                                                        !hasBackgroundImage,
                                                    icon:
                                                        Icons
                                                            .hide_image_outlined,
                                                    onTap: () {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          clearBackgroundImage:
                                                              true,
                                                        );
                                                      });
                                                      unawaited(
                                                        persistBackgroundDraftNow(
                                                          draft,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ...presetBackgroundTiles,
                                                  ...customBackgroundTiles,
                                                  _buildBackgroundTile(
                                                    label: '自定义',
                                                    selected: false,
                                                    icon:
                                                        Icons
                                                            .upload_file_rounded,
                                                    showLabel: true,
                                                    onTap:
                                                        applyCustomBackgroundImage,
                                                  ),
                                                  if (hasBackgroundImage) ...[
                                                    const SizedBox(width: 8),
                                                    OutlinedButton(
                                                      onPressed:
                                                          () => unawaited(
                                                            removeActiveBackground(),
                                                          ),
                                                      child: const Text('移除'),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (showReadingSection) ...[
                                        if (showInterfaceSection)
                                          const Divider(height: 1),
                                        if (!isMangaChapter)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children: [
                                                  buildReadingActionTab(
                                                    label: '字重',
                                                    value:
                                                        fontWeightDisplayLabel(
                                                          draft,
                                                        ),
                                                    onTap:
                                                        () => unawaited(
                                                          openFontWeightTabSheet(),
                                                        ),
                                                  ),
                                                  buildReadingActionTab(
                                                    label: '边距',
                                                    value:
                                                        _bodyMarginDisplayValue(
                                                          draft,
                                                        ),
                                                    onTap:
                                                        () => unawaited(
                                                          openHorizontalPaddingTabSheet(),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        if (!isMangaChapter)
                                          const Divider(height: 1),
                                        if (!isMangaChapter)
                                          _buildSettingLine(
                                            context: context,
                                            label: '排版',
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    const Spacer(),
                                                    Switch.adaptive(
                                                      value:
                                                          draft
                                                              .textFullJustifyEnabled,
                                                      onChanged: (enabled) {
                                                        setModalState(() {
                                                          draft = draft.copyWith(
                                                            textFullJustifyEnabled:
                                                                enabled,
                                                          );
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '斜体',
                                                      style:
                                                          Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium,
                                                    ),
                                                    const Spacer(),
                                                    Switch.adaptive(
                                                      value:
                                                          draft
                                                              .bodyTextItalicEnabled,
                                                      onChanged: (enabled) {
                                                        setModalState(() {
                                                          draft = draft.copyWith(
                                                            bodyTextItalicEnabled:
                                                                enabled,
                                                          );
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '阴影',
                                                      style:
                                                          Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium,
                                                    ),
                                                    const Spacer(),
                                                    Switch.adaptive(
                                                      value:
                                                          draft
                                                              .bodyTextShadowEnabled,
                                                      onChanged: (enabled) {
                                                        setModalState(() {
                                                          draft = draft.copyWith(
                                                            bodyTextShadowEnabled:
                                                                enabled,
                                                          );
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                if (draft.bodyTextShadowEnabled)
                                                  buildTypographySliderRow(
                                                    label: '模糊',
                                                    min: 0,
                                                    max: 32,
                                                    divisions: 32,
                                                    value:
                                                        draft
                                                            .bodyTextShadowBlurRadius,
                                                    step: 1,
                                                    valueLabel:
                                                        draft
                                                            .bodyTextShadowBlurRadius
                                                            .round()
                                                            .toString(),
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          bodyTextShadowBlurRadius:
                                                              value,
                                                        );
                                                      });
                                                    },
                                                  ),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: ReaderBodyTextDecorationStyle
                                                      .values
                                                      .map(
                                                        (style) => ChoiceChip(
                                                          label: Text(
                                                            decorationStyleLabel(
                                                              style,
                                                            ),
                                                          ),
                                                          selected:
                                                              draft
                                                                  .bodyTextDecorationStyle ==
                                                              style,
                                                          onSelected: (_) {
                                                            setModalState(() {
                                                              draft = draft
                                                                  .copyWith(
                                                                    bodyTextDecorationStyle:
                                                                        style,
                                                                  );
                                                            });
                                                          },
                                                        ),
                                                      )
                                                      .toList(growable: false),
                                                ),
                                                if (draft
                                                        .bodyTextDecorationStyle !=
                                                    ReaderBodyTextDecorationStyle
                                                        .none)
                                                  Row(
                                                    children: [
                                                      OutlinedButton(
                                                        onPressed: () {
                                                          setModalState(() {
                                                            draft = draft.copyWith(
                                                              clearBodyTextDecorationColor:
                                                                  true,
                                                            );
                                                          });
                                                        },
                                                        child: const Text(
                                                          '下划线跟随文字',
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      OutlinedButton(
                                                        onPressed: () async {
                                                          final selectedColor =
                                                              await _showBodyTextDecorationColorPickerDialog(
                                                                context,
                                                                initialColorValue:
                                                                    draft
                                                                        .bodyTextDecorationColorValue,
                                                              );
                                                          if (selectedColor ==
                                                                  null ||
                                                              !context
                                                                  .mounted) {
                                                            return;
                                                          }
                                                          setModalState(() {
                                                            draft = draft.copyWith(
                                                              bodyTextDecorationColorValue:
                                                                  selectedColor,
                                                            );
                                                          });
                                                        },
                                                        child: const Text(
                                                          '下划线颜色',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                if (draft
                                                        .bodyTextDecorationStyle !=
                                                    ReaderBodyTextDecorationStyle
                                                        .none)
                                                  buildTypographySliderRow(
                                                    label: '粗细',
                                                    min: 1,
                                                    max: 10,
                                                    divisions: 18,
                                                    value:
                                                        draft
                                                            .bodyTextUnderlineThickness,
                                                    step: 0.5,
                                                    valueLabel: draft
                                                        .bodyTextUnderlineThickness
                                                        .toStringAsFixed(1),
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          bodyTextUnderlineThickness:
                                                              value,
                                                        );
                                                      });
                                                    },
                                                  ),
                                                if (draft
                                                        .bodyTextDecorationStyle !=
                                                    ReaderBodyTextDecorationStyle
                                                        .none)
                                                  buildTypographySliderRow(
                                                    label: '间距',
                                                    min: 0,
                                                    max: 16,
                                                    divisions: 16,
                                                    value:
                                                        draft
                                                            .bodyTextUnderlineGap,
                                                    step: 1,
                                                    valueLabel:
                                                        draft
                                                            .bodyTextUnderlineGap
                                                            .round()
                                                            .toString(),
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          bodyTextUnderlineGap:
                                                              value,
                                                        );
                                                      });
                                                    },
                                                  ),
                                                if (draft
                                                        .bodyTextDecorationStyle ==
                                                    ReaderBodyTextDecorationStyle
                                                        .dashed)
                                                  buildTypographySliderRow(
                                                    label: '线长',
                                                    min: 1,
                                                    max: 24,
                                                    divisions: 23,
                                                    value:
                                                        draft
                                                            .bodyTextUnderlineDashLength,
                                                    step: 1,
                                                    valueLabel:
                                                        draft
                                                            .bodyTextUnderlineDashLength
                                                            .round()
                                                            .toString(),
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          bodyTextUnderlineDashLength:
                                                              value,
                                                        );
                                                      });
                                                    },
                                                  ),
                                                if (draft
                                                        .bodyTextDecorationStyle ==
                                                    ReaderBodyTextDecorationStyle
                                                        .dashed)
                                                  buildTypographySliderRow(
                                                    label: '比例',
                                                    min: 1,
                                                    max: 12,
                                                    divisions: 11,
                                                    value:
                                                        draft
                                                            .bodyTextUnderlineDashGapRatio,
                                                    step: 1,
                                                    valueLabel:
                                                        draft
                                                            .bodyTextUnderlineDashGapRatio
                                                            .round()
                                                            .toString(),
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          bodyTextUnderlineDashGapRatio:
                                                              value,
                                                        );
                                                      });
                                                    },
                                                  ),
                                                const SizedBox(height: 8),
                                                buildTypographySliderRow(
                                                  label: '字号',
                                                  min: 5,
                                                  max: 50,
                                                  divisions: 45,
                                                  value: draft.fontSize,
                                                  step: 1,
                                                  valueLabel:
                                                      _fontSizeValueLabel(
                                                        draft,
                                                      ),
                                                  showValueLabel: false,
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        fontSize: value,
                                                      );
                                                    });
                                                  },
                                                ),
                                                buildTypographySliderRow(
                                                  label: '字距',
                                                  min: 0,
                                                  max: 100,
                                                  divisions: 100,
                                                  value:
                                                      _letterSpacingSliderValue(
                                                        draft,
                                                      ),
                                                  step: 1,
                                                  valueLabel:
                                                      _letterSpacingValueLabel(
                                                        draft,
                                                      ),
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        letterSpacing:
                                                            _letterSpacingFromSliderValue(
                                                              value,
                                                            ),
                                                      );
                                                    });
                                                  },
                                                ),
                                                buildTypographySliderRow(
                                                  label: '行距',
                                                  min: 0,
                                                  max: 20,
                                                  divisions: 20,
                                                  value: _lineHeightSliderValue(
                                                    draft,
                                                  ),
                                                  step: 1,
                                                  valueLabel:
                                                      _lineHeightValueLabel(
                                                        draft,
                                                      ),
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        lineHeight:
                                                            _lineHeightFromSliderValue(
                                                              sliderValue:
                                                                  value,
                                                              settings: draft,
                                                            ),
                                                      );
                                                    });
                                                  },
                                                ),
                                                buildTypographySliderRow(
                                                  label: '段距',
                                                  min: 0,
                                                  max: 20,
                                                  divisions: 20,
                                                  value: draft.paragraphSpacing,
                                                  step: 1,
                                                  valueLabel:
                                                      _paragraphSpacingValueLabel(
                                                        draft,
                                                      ),
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        paragraphSpacing: value,
                                                      );
                                                    });
                                                  },
                                                ),
                                                buildTypographySliderRow(
                                                  label: '缩进',
                                                  min: 0,
                                                  max: 8,
                                                  divisions: 8,
                                                  value:
                                                      draft.paragraphIndent
                                                          .clamp(0, 8)
                                                          .toDouble(),
                                                  step: 1,
                                                  valueLabel:
                                                      _paragraphIndentValueLabel(
                                                        draft,
                                                      ),
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        paragraphIndent:
                                                            value
                                                                .round()
                                                                .toDouble(),
                                                      );
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (!isMangaChapter)
                                          const Divider(height: 1),
                                        _buildSettingLine(
                                          context: context,
                                          label:
                                              !isMangaChapter ? '阅读方式' : '翻页',
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (!isMangaChapter ||
                                                  animationPolicy
                                                      .supportsTextPageTurnAnimations)
                                                buildPageAnimationSelector()
                                              else
                                                Text(
                                                  animationPolicy
                                                          .inactiveReason ??
                                                      '当前模式不使用正文翻页动画。',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall?.copyWith(
                                                    color:
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              if (!isMangaChapter) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  draft
                                                          .pageTurnMode
                                                          .usesScrollLayout
                                                      ? '当前为滚动阅读。分页时默认固定为点按 + 滑动。'
                                                      : '当前为分页阅读，默认固定使用点按 + 滑动翻页。',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        _buildSettingLine(
                                          context: context,
                                          label: '音量键翻页',
                                          labelWidth: 96,
                                          stackOnCompact: true,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      draft.volumeKeyPageEnabled
                                                          ? '音量上键上一页，音量下键下一页'
                                                          : '保留系统音量键行为',
                                                      style:
                                                          Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium,
                                                    ),
                                                  ),
                                                  Switch.adaptive(
                                                    value:
                                                        draft
                                                            .volumeKeyPageEnabled,
                                                    onChanged:
                                                        ReaderVolumeKeyPageBridge
                                                                .instance
                                                                .isSupported
                                                            ? (enabled) {
                                                              setModalState(() {
                                                                draft = draft
                                                                    .copyWith(
                                                                      volumeKeyPageEnabled:
                                                                          enabled,
                                                                    );
                                                              });
                                                            }
                                                            : null,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _volumeKeyPageSupportDescription,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        _buildSettingLine(
                                          context: context,
                                          label: isMangaChapter ? '其他' : '自动读',
                                          child:
                                              isMangaChapter
                                                  ? Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: ReaderMangaReadMode
                                                            .values
                                                            .map(
                                                              (
                                                                mode,
                                                              ) => ChoiceChip(
                                                                label: Text(
                                                                  _mangaReadModeLabel(
                                                                    mode,
                                                                  ),
                                                                ),
                                                                selected:
                                                                    draft
                                                                        .mangaReadMode ==
                                                                    mode,
                                                                onSelected: (
                                                                  _,
                                                                ) {
                                                                  setModalState(() {
                                                                    draft = draft
                                                                        .copyWith(
                                                                          mangaReadMode:
                                                                              mode,
                                                                        );
                                                                  });
                                                                },
                                                              ),
                                                            )
                                                            .toList(
                                                              growable: false,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        '留白',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: const [
                                                              0.0,
                                                              4.0,
                                                              8.0,
                                                              12.0,
                                                              16.0,
                                                            ]
                                                            .map(
                                                              (
                                                                value,
                                                              ) => ChoiceChip(
                                                                label: Text(
                                                                  '${value.toInt()}',
                                                                ),
                                                                selected:
                                                                    (draft.mangaImagePadding -
                                                                            value)
                                                                        .abs() <
                                                                    0.2,
                                                                onSelected: (
                                                                  _,
                                                                ) {
                                                                  setModalState(() {
                                                                    draft = draft.copyWith(
                                                                      mangaImagePadding:
                                                                          value,
                                                                    );
                                                                  });
                                                                },
                                                              ),
                                                            )
                                                            .toList(
                                                              growable: false,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        '图间距',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: const [
                                                              0.0,
                                                              6.0,
                                                              10.0,
                                                              14.0,
                                                              18.0,
                                                            ]
                                                            .map(
                                                              (
                                                                value,
                                                              ) => ChoiceChip(
                                                                label: Text(
                                                                  '${value.toInt()}',
                                                                ),
                                                                selected:
                                                                    (draft.mangaImageSpacing -
                                                                            value)
                                                                        .abs() <
                                                                    0.2,
                                                                onSelected: (
                                                                  _,
                                                                ) {
                                                                  setModalState(() {
                                                                    draft = draft.copyWith(
                                                                      mangaImageSpacing:
                                                                          value,
                                                                    );
                                                                  });
                                                                },
                                                              ),
                                                            )
                                                            .toList(
                                                              growable: false,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        '背景颜色',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: _readerBackgroundColorOptions()
                                                            .map(
                                                              (
                                                                option,
                                                              ) => _buildBackgroundColorChoiceChip(
                                                                draft: draft,
                                                                option: option,
                                                                onChanged: (
                                                                  next,
                                                                ) {
                                                                  setModalState(
                                                                    () {
                                                                      draft =
                                                                          next;
                                                                    },
                                                                  );
                                                                },
                                                              ),
                                                            )
                                                            .toList(
                                                              growable: false,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        '加载策略',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: ReaderMangaLoadStrategy
                                                            .values
                                                            .map(
                                                              (
                                                                strategy,
                                                              ) => ChoiceChip(
                                                                label: Text(
                                                                  _mangaLoadStrategyLabel(
                                                                    strategy,
                                                                  ),
                                                                ),
                                                                selected:
                                                                    draft
                                                                        .mangaLoadStrategy ==
                                                                    strategy,
                                                                onSelected: (
                                                                  _,
                                                                ) {
                                                                  setModalState(() {
                                                                    draft = draft.copyWith(
                                                                      mangaLoadStrategy:
                                                                          strategy,
                                                                    );
                                                                  });
                                                                },
                                                              ),
                                                            )
                                                            .toList(
                                                              growable: false,
                                                            ),
                                                      ),
                                                    ],
                                                  )
                                                  : Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              startAutoReadAfterApply
                                                                  ? '关闭弹窗后立即启动自动阅读'
                                                                  : '本次不启动自动阅读',
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodyMedium,
                                                            ),
                                                          ),
                                                          Switch.adaptive(
                                                            value:
                                                                startAutoReadAfterApply,
                                                            onChanged: (
                                                              enabled,
                                                            ) {
                                                              setModalState(() {
                                                                startAutoReadAfterApply =
                                                                    enabled;
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '一次性操作，不会保存为默认状态',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '自动阅读速度：${_autoReadSpeedLevelLabel(draft.autoReadSpeed)} · ${draft.autoReadSpeed.round()} px/s',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                            ),
                                                      ),
                                                      Slider(
                                                        min:
                                                            ReaderSettings
                                                                .minAutoReadSpeed,
                                                        max:
                                                            ReaderSettings
                                                                .maxAutoReadSpeed,
                                                        divisions: 20,
                                                        label:
                                                            '${draft.autoReadSpeed.round()}',
                                                        value:
                                                            draft.autoReadSpeed
                                                                .clamp(
                                                                  ReaderSettings
                                                                      .minAutoReadSpeed,
                                                                  ReaderSettings
                                                                      .maxAutoReadSpeed,
                                                                )
                                                                .toDouble(),
                                                        onChanged: (value) {
                                                          setModalState(() {
                                                            draft = draft
                                                                .copyWith(
                                                                  autoReadSpeed:
                                                                      value,
                                                                );
                                                          });
                                                        },
                                                      ),
                                                      Row(
                                                        children: [
                                                          Text(
                                                            '慢',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                          ),
                                                          const Spacer(),
                                                          Text(
                                                            '快',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    sliderInteractionTimer?.cancel();

    persistDraftTimer?.cancel();
    await persistDraftNow(draft);

    if (!mounted) {
      return;
    }

    if (shouldRestoreOverlay) {
      _setOverlayControlsVisibility(true);
    }

    final shouldEnableAutoRead = !isMangaChapter && startAutoReadAfterApply;
    final selectedResult = draft;
    var appliedResult = selectedResult.copyWith(autoReadEnabled: false);
    var refreshedCustomFonts = _customFonts;

    try {
      appliedResult = await _fontRegistryService.normalizeCustomFontSettings(
        appliedResult,
      );
    } catch (_) {
      appliedResult = appliedResult.copyWith(
        fontSource: ReaderFontSource.system,
        clearFontFamilyKey: true,
        clearCustomFontPath: true,
      );
    }

    if (selectedResult.fontSource == ReaderFontSource.custom &&
        appliedResult.fontSource != ReaderFontSource.custom) {
      _showMessage('自定义字体不可用，已自动切回系统字体。');
    }

    try {
      refreshedCustomFonts = await _fontRegistryService.listRegisteredFonts();
    } catch (_) {
      refreshedCustomFonts = const <ReaderCustomFontEntry>[];
    }

    _updateReaderState(() {
      _settings = appliedResult;
      _customFonts = refreshedCustomFonts;
    });
    _syncContinuousTextFlowAfterSettingsApplied();
    _clearSelectionState();
    await _preferencesService.saveSettings(appliedResult);

    if (shouldEnableAutoRead && mounted) {
      await _toggleAutoReadSession();
    }
  }

  Future<void> _ensureBackgroundPresetsReady() =>
      _ensureBackgroundPresetsReadyImpl();

  Widget _buildSettingLine({
    required BuildContext context,
    required String label,
    required Widget child,
    double labelWidth = 42,
    String? helpText,
    bool stackOnCompact = false,
  }) => _buildSettingLineImpl(
    context: context,
    label: label,
    child: child,
    labelWidth: labelWidth,
    helpText: helpText,
    stackOnCompact: stackOnCompact,
  );

  Widget _buildSettingLineLabel({
    required BuildContext context,
    required String label,
    String? helpText,
    required int maxLines,
  }) => _buildSettingLineLabelImpl(
    context: context,
    label: label,
    helpText: helpText,
    maxLines: maxLines,
  );

  List<_ReaderBackgroundColorOption> _readerBackgroundColorOptions() =>
      _readerBackgroundColorOptionsImpl();

  _ReaderBackgroundColorOption _createReaderBackgroundColorOption({
    required String label,
    required ReaderThemeMode mode,
    required ReaderBackgroundStyle backgroundStyle,
    required ReaderBackgroundTone backgroundTone,
  }) {
    final previewSettings = ReaderSettings(
      themeMode: mode,
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
    );
    final previewColors = _resolveThemeColors(mode, previewSettings);
    return _ReaderBackgroundColorOption(
      label: label,
      previewColor: previewColors.background,
      mode: mode,
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
    );
  }

  _ReaderBackgroundColorOption _createReaderThemePaletteBackgroundColorOption({
    required AppThemeSeedOption themeOption,
    required ReaderBackgroundTone backgroundTone,
  }) {
    return _createReaderBackgroundColorOption(
      label: themeOption.label,
      mode: ReaderThemeMode.light,
      backgroundStyle: ReaderBackgroundStyle.paper,
      backgroundTone: backgroundTone,
    );
  }

  ReaderSettings _applyReaderBackgroundColorOption(
    ReaderSettings settings,
    _ReaderBackgroundColorOption option,
  ) {
    return settings.copyWith(
      themeMode: option.mode,
      backgroundStyle: option.backgroundStyle,
      backgroundTone: option.backgroundTone,
      clearBackgroundImage: true,
    );
  }

  bool _isReaderBackgroundColorOptionSelected(
    ReaderSettings settings,
    _ReaderBackgroundColorOption option,
  ) {
    final normalizedTone = normalizeReaderBackgroundTone(
      mode: settings.themeMode,
      tone: settings.backgroundTone,
    );
    return settings.themeMode == option.mode &&
        settings.backgroundStyle == option.backgroundStyle &&
        normalizedTone == option.backgroundTone;
  }

  Widget _buildBackgroundColorChoiceChip({
    required ReaderSettings draft,
    required _ReaderBackgroundColorOption option,
    required ValueChanged<ReaderSettings> onChanged,
  }) => _buildBackgroundColorChoiceChipImpl(
    draft: draft,
    option: option,
    onChanged: onChanged,
  );

  Color? _readerPaletteSeedColorForTone(ReaderBackgroundTone tone) {
    return switch (tone) {
      ReaderBackgroundTone.flameOrangeTint => appThemeFlameOrangeOption.color,
      ReaderBackgroundTone.pineGreenTint => appThemePineGreenOption.color,
      ReaderBackgroundTone.seaBlueTint => appThemeSeaBlueOption.color,
      ReaderBackgroundTone.nightPurpleTint => appThemeNightPurpleOption.color,
      ReaderBackgroundTone.mistTealTint => appThemeMistTealOption.color,
      ReaderBackgroundTone.berryRoseTint => appThemeBerryRoseOption.color,
      ReaderBackgroundTone.amberGoldTint => appThemeAmberGoldOption.color,
      _ => null,
    };
  }

  Widget _buildThemeColorDot({
    required ReaderSettings draft,
    required Color color,
    required String label,
    required ReaderThemeMode mode,
    required ReaderBackgroundStyle backgroundStyle,
    required ReaderBackgroundTone backgroundTone,
    required ValueChanged<ReaderSettings> onChanged,
    double scale = 1.0,
  }) => _buildThemeColorDotImpl(
    draft: draft,
    color: color,
    label: label,
    mode: mode,
    backgroundStyle: backgroundStyle,
    backgroundTone: backgroundTone,
    onChanged: onChanged,
    scale: scale,
  );

  Widget _buildBackgroundTile({
    required String label,
    required bool selected,
    Uint8List? previewBytes,
    VoidCallback? onTap,
    bool showLabel = true,
    IconData? icon,
    double scale = 1.0,
  }) => _buildBackgroundTileImpl(
    label: label,
    selected: selected,
    previewBytes: previewBytes,
    onTap: onTap,
    showLabel: showLabel,
    icon: icon,
    scale: scale,
  );

  Future<String?> _pickBackgroundImagePath() async {
    try {
      debugPrint('[reader-bg][pick] start');
      final picked = await _imageSelectionService.pickImage(
        confirmButtonText: '选择背景',
      );
      if (picked == null) {
        debugPrint('[reader-bg][pick] cancelled');
        return null;
      }

      final Uint8List bytes = picked.bytes;
      if (bytes.isEmpty) {
        debugPrint('[reader-bg][pick] empty-bytes');
        _showMessage('背景图片读取失败。');
        return null;
      }
      final storedPath = await _storeCustomBackgroundImage(bytes);
      debugPrint('[reader-bg][pick] stored=$storedPath');
      return storedPath;
    } on ImageSelectionException catch (error) {
      debugPrint('[reader-bg][pick] image-selection-error=${error.message}');
      _showMessage(error.message);
      return null;
    } on PlatformException catch (error) {
      debugPrint(
        '[reader-bg][pick] platform-error=${error.message ?? error.code}',
      );
      _showMessage('选择背景失败：${error.message ?? error.code}');
      return null;
    } catch (error) {
      debugPrint('[reader-bg][pick] error=$error');
      _showMessage('选择背景失败：$error');
      return null;
    }
  }

  String _autoReadSpeedLevelLabel(double speed) {
    if (speed < 42) {
      return '慢速';
    }
    if (speed < 78) {
      return '中速';
    }
    return '快速';
  }

  String _formatTypographyValue({
    required double value,
    required int fractionDigits,
    String unit = '',
  }) {
    final normalized = value == 0 ? 0.0 : value;
    return '${normalized.toStringAsFixed(fractionDigits)}$unit';
  }

  String _fontSizeValueLabel(ReaderSettings settings) {
    return _formatTypographyValue(
      value: settings.fontSize,
      fractionDigits: 0,
      unit: 'px',
    );
  }

}
