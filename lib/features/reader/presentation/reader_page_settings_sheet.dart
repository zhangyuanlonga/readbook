part of 'reader_page.dart';

extension _ReaderPageSettingsSheetExtension on _ReaderPageState {
  Future<void> _showSettingsSheet({
    _ReaderSettingsTab initialTab = _ReaderSettingsTab.reading,
    String? initialSettingsGroupKey,
    bool startAutoReadAfterApplyInitially = false,
  }) async {
    final entryPlan = _settingsEntryController.buildOpenPlan(
      overlayVisible: _showOverlayControls,
    );
    if (entryPlan.shouldStopAutoRead) {
      _stopAutoReadSession();
    }
    if (entryPlan.shouldSuspendOverlayAutoHide) {
      _suspendOverlayAutoHide();
    }
    if (entryPlan.shouldRestoreOverlayAfterClose) {
      _hideOverlayControls(resumeAutoRead: false, syncSystemUi: false);
    }

    var draft = _settings;
    final isMangaChapter = _isMangaChapter;
    if (!isMangaChapter && !draft.pageTurnMode.usesScrollLayout) {
      draft = draft.copyWith(pageTurnMode: ReaderPageTurnMode.tapAndSwipe);
    }
    var availableCustomFonts = List<ReaderCustomFontEntry>.from(_customFonts);
    var startAutoReadAfterApply = startAutoReadAfterApplyInitially;
    var isPersistingDraft = false;
    final showInterfaceSettings = initialTab == _ReaderSettingsTab.interface;
    final isAudioChapter = _currentContentMode == ReaderContentMode.audio;
    String? activeSettingsGroupKey = initialSettingsGroupKey;
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
        await _persistResolvedReaderSettingsLayers(normalized);
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

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'reader-settings',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AppFadeSlideTransition(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const SizedBox.shrink(),
                ),
              ),
              Theme(
                data: readerModalTheme,
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    final brightness = Theme.of(context).brightness;
                    final interactionSheetAlpha =
                        brightness == Brightness.dark ? 0.16 : 0.22;
                    final sheetSurfaceColor = readerModalTheme
                        .colorScheme
                        .surface
                        .withValues(
                          alpha:
                              isSliderInteracting ? interactionSheetAlpha : 1.0,
                        );

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
                        _preferencesService.saveCustomBackgroundImages(
                          nextCustoms,
                        ),
                      );
                    }

                    void updateCustomBackgroundsInSheet(
                      List<String> nextCustoms,
                    ) {
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
                      await _preferencesService.saveRecentBodyTextColors(
                        nextColors,
                      );
                    }

                    void previewDraftSettings() {
                      if (!mounted) {
                        return;
                      }

                      if (isSliderInteracting) {
                        schedulePersistDraft();
                      } else {
                        unawaited(persistDraftNow(draft));
                      }
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
                        _applyReaderSettingsWithModeRestore(
                          nextSettings: draft,
                        );
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

                    Future<void> applyCustomBackgroundImage() async {
                      final storedPath = await _pickBackgroundImagePath();
                      if (storedPath == null || !context.mounted) {
                        return;
                      }

                      final nextCustoms =
                          List<String>.from(_customBackgroundImages)
                            ..removeWhere((entry) => entry == storedPath)
                            ..add(storedPath);

                      updateDraft(
                        draft.copyWith(backgroundImageBase64: storedPath),
                      );
                      setModalState(() {
                        _customBackgroundImages = nextCustoms;
                      });
                      updateCustomBackgrounds(nextCustoms);
                    }

                    Future<void> applyStoredCustomBackground(
                      String source,
                    ) async {
                      final normalized = source.trim();
                      if (normalized.isEmpty) {
                        return;
                      }
                      updateDraft(
                        draft.copyWith(backgroundImageBase64: normalized),
                      );
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
                        final nextCustoms = List<String>.from(
                          _customBackgroundImages,
                        )..removeWhere((entry) => entry == active);
                        updateCustomBackgroundsInSheet(nextCustoms);
                        unawaited(_deleteManagedBackgroundFileIfNeeded(active));
                      }
                    }

                    Future<ReaderCustomFontEntry?> importCustomFont(
                      void Function(ImportExportTaskStatus status)
                      onInlineStatus,
                    ) async {
                      try {
                        final importedFonts =
                            await _fontRegistryService.pickAndImportFonts();
                        if (importedFonts.isEmpty || !context.mounted) {
                          return null;
                        }
                        final imported = importedFonts.first;
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
                        onInlineStatus(
                          ImportExportTaskStatus(
                            title: '字体导入完成',
                            message:
                                importedFonts.length == 1
                                    ? '已完成字体注册，正在应用到当前阅读设置…'
                                    : '已导入 ${importedFonts.length} 个字体，正在应用首个字体…',
                            detail:
                                importedFonts.length == 1
                                    ? imported.displayName
                                    : imported.displayName,
                            presentation:
                                ImportExportTaskPresentation.inlineCompact,
                            progress: 1,
                            result: ImportExportTaskResult.success,
                          ),
                        );
                        return imported;
                      } on PlatformException catch (error) {
                        onInlineStatus(
                          ImportExportTaskStatus(
                            title: '导入字体失败',
                            message: error.message ?? error.code,
                            presentation:
                                ImportExportTaskPresentation.inlineCompact,
                            result: ImportExportTaskResult.failure,
                          ),
                        );
                        _showMessage('导入字体失败：${error.message ?? error.code}');
                        return null;
                      } on ReaderFontRegistryException catch (error) {
                        onInlineStatus(
                          ImportExportTaskStatus(
                            title: '导入字体失败',
                            message: error.message,
                            presentation:
                                ImportExportTaskPresentation.inlineCompact,
                            result: ImportExportTaskResult.failure,
                          ),
                        );
                        _showMessage(error.message);
                        return null;
                      } catch (error) {
                        onInlineStatus(
                          ImportExportTaskStatus(
                            title: '导入字体失败',
                            message: '$error',
                            presentation:
                                ImportExportTaskPresentation.inlineCompact,
                            result: ImportExportTaskResult.failure,
                          ),
                        );
                        _showMessage('导入字体失败：$error');
                        return null;
                      }
                    }

                    ReaderSettingsGroups semanticGroups() =>
                        settingsGroupingService.split(draft);

                    Future<void> openFontPickerSheet() async {
                      if (!context.mounted) {
                        return;
                      }
                      await showReaderFontPickerSheet(
                        context: context,
                        settings: draft,
                        availableCustomFonts: availableCustomFonts,
                        onChanged:
                            (next) => setModalState(() {
                              draft = next;
                            }),
                        onImportCustomFont: importCustomFont,
                        onManageFonts: openMineFontManagement,
                      );
                    }

                    Future<void> openFontWeightTabSheet() async {
                      if (!context.mounted) {
                        return;
                      }
                      await showReaderFontWeightSheet(
                        context: context,
                        readerModalTheme: readerModalTheme,
                        settings: draft,
                        frameBuilder:
                            ({
                              required context,
                              required readerModalTheme,
                              required keyboardInset,
                              required safeBottom,
                              required sheetHorizontal,
                              required maxWidth,
                              required heightFactor,
                              required child,
                            }) => _buildFloatingReaderSettingsSheet(
                              context: context,
                              readerModalTheme: readerModalTheme,
                              keyboardInset: keyboardInset,
                              safeBottom: safeBottom,
                              sheetHorizontal: sheetHorizontal,
                              maxWidth: maxWidth,
                              heightFactor: heightFactor,
                              child: child,
                            ),
                        bottomSafeInset: _bottomSafeInset,
                        onChanged:
                            (next) => setModalState(() {
                              draft = next;
                            }),
                      );
                    }

                    final presetTileScale =
                        (AppLayout.pageContentMaxWidth(context, maxWidth: 760) /
                                360.0)
                            .clamp(0.94, 1.18)
                            .toDouble();
                    final backgroundColorOptions =
                        _readerBackgroundColorOptions()
                            .map(
                              (option) => ReaderThemeBackgroundColorOption(
                                label: option.label,
                                previewColor: option.previewColor,
                                mode: option.mode,
                                backgroundStyle: option.backgroundStyle,
                                backgroundTone: option.backgroundTone,
                              ),
                            )
                            .toList(growable: false);
                    final presetBackgroundTiles =
                        <ReaderBackgroundImageTileData>[];
                    for (final preset in _backgroundPresets) {
                      final previewBytes =
                          _backgroundPresetBytes[preset.assetPath];
                      final presetBase64 =
                          _backgroundPresetBase64[preset.assetPath];
                      if (previewBytes == null) {
                        continue;
                      }
                      presetBackgroundTiles.add(
                        ReaderBackgroundImageTileData(
                          label: preset.label,
                          selected:
                              activeBackgroundBase64 == preset.assetPath ||
                              (presetBase64 != null &&
                                  activeBackgroundBase64 == presetBase64),
                          previewBytes: previewBytes,
                          showLabel: false,
                          onTap: () {
                            updateDraft(
                              draft.copyWith(
                                backgroundImageBase64: preset.assetPath,
                              ),
                            );
                          },
                        ),
                      );
                    }
                    final customBackgroundTiles =
                        <ReaderBackgroundImageTileData>[];
                    for (
                      var index = 0;
                      index < customBackgrounds.length;
                      index += 1
                    ) {
                      final source = customBackgrounds[index];
                      final previewBytes =
                          _customBackgroundPreviewBytes[source];
                      final isSelected =
                          hasBackgroundImage &&
                          !isPresetBackground &&
                          activeBackgroundBase64 == source;
                      customBackgroundTiles.add(
                        ReaderBackgroundImageTileData(
                          label: '自定义${index + 1}',
                          selected: isSelected,
                          previewBytes: previewBytes,
                          showLabel: true,
                          icon:
                              previewBytes == null
                                  ? Icons.broken_image_outlined
                                  : null,
                          onTap:
                              () => unawaited(
                                applyStoredCustomBackground(source),
                              ),
                        ),
                      );
                    }
                    final keyboardInset =
                        MediaQuery.viewInsetsOf(context).bottom;
                    final safeBottom = _bottomSafeInset(context);
                    final metrics = AppAdaptiveMetrics.of(context);
                    final sheetHorizontal = metrics.pagePadding;
                    final compactSheetBaseWidth = 360.0;
                    final compactSheetVisualWidth = min(
                      AppLayout.pageContentMaxWidth(context, maxWidth: 760),
                      max(
                        320.0,
                        MediaQuery.sizeOf(context).width -
                            (sheetHorizontal * 2),
                      ),
                    );
                    final compactSheetScale =
                        (compactSheetVisualWidth / compactSheetBaseWidth)
                            .clamp(0.88, 1.08)
                            .toDouble();
                    double compactScaleValue(double value) =>
                        value * compactSheetScale;

                    Widget buildSettingsGroupEntryCard({
                      required IconData icon,
                      required String title,
                      required String subtitle,
                      required VoidCallback onTap,
                    }) => ReaderSettingsGroupEntryCard(
                      icon: icon,
                      title: title,
                      subtitle: subtitle,
                      onTap: onTap,
                      compactScale: compactSheetScale,
                      interactionPreviewActive: isSliderInteracting,
                    );

                    Widget buildTextReaderSettingsSheet() {
                      Widget buildOwnershipHintCard(String groupKey) {
                        final descriptor = _readerSettingsPresenter
                            .ownershipDescriptor(groupKey);
                        final colorScheme = Theme.of(context).colorScheme;
                        return Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: compactScaleValue(8)),
                          padding: EdgeInsets.fromLTRB(
                            compactScaleValue(12),
                            compactScaleValue(10),
                            compactScaleValue(12),
                            compactScaleValue(10),
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.22,
                            ),
                            borderRadius: BorderRadius.circular(
                              compactScaleValue(16),
                            ),
                            border: Border.all(
                              color: colorScheme.primary.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                descriptor.title,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: compactScaleValue(4)),
                              Text(
                                descriptor.description,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      Future<void> openTapZoneEditorSheet() async {
                        await showReaderTapZoneEditorSheet(
                          context: context,
                          backgroundColor: sheetSurfaceColor,
                          actions: draft.tapZoneActions,
                          onChanged:
                              (nextActions) => updateDraft(
                                draft.copyWith(tapZoneActions: nextActions),
                              ),
                        );
                      }

                      List<Widget> wrapSettingsSection({
                        required String? groupKey,
                        required bool showInterfaceSettings,
                        required List<Widget> children,
                      }) {
                        if (children.isEmpty) {
                          return children;
                        }
                        return switch (groupKey) {
                          'typography' => <Widget>[
                            ReaderTypographySettingsSection(children: children),
                          ],
                          'quick_margins' ||
                          'info_layout' ||
                          'info' => <Widget>[
                            ReaderLayoutSettingsSection(children: children),
                          ],
                          'interaction' || 'behavior' => <Widget>[
                            ReaderPageTurnSettingsSection(children: children),
                          ],
                          'auto_read' => <Widget>[
                            ReaderAutoReadSettingsSection(children: children),
                          ],
                          'audio' => <Widget>[
                            ReaderAudioSettingsSection(children: children),
                          ],
                          'manga' => <Widget>[
                            ReaderMangaSettingsSection(children: children),
                          ],
                          null when showInterfaceSettings => <Widget>[
                            ReaderThemeBackgroundSettingsSection(
                              children: children,
                            ),
                          ],
                          _ => children,
                        };
                      }

                      final rawSelectedCards = switch (activeSettingsGroupKey) {
                        null =>
                          showInterfaceSettings
                              ? <Widget>[
                                ReaderThemeBackgroundSettingsPanel(
                                  settings: draft,
                                  contentMode: _currentContentMode,
                                  compactScale: compactSheetScale,
                                  backgroundTileScale: presetTileScale,
                                  sliderBuilder: buildPreviewAwareSlider,
                                  colorOptions: backgroundColorOptions,
                                  presetBackgroundTiles: presetBackgroundTiles,
                                  customBackgroundTiles: customBackgroundTiles,
                                  hasBackgroundImage: hasBackgroundImage,
                                  pageAnimationLabel: _pageAnimationLabel,
                                  onChanged: updateDraft,
                                  onSelectSettingsGroup:
                                      (groupKey) => setModalState(() {
                                        activeSettingsGroupKey = groupKey;
                                      }),
                                  onClearBackgroundImage:
                                      () => updateDraft(
                                        draft.copyWith(
                                          clearBackgroundImage: true,
                                        ),
                                      ),
                                  onApplyCustomBackgroundImage:
                                      () => unawaited(
                                        applyCustomBackgroundImage(),
                                      ),
                                  onOpenBackgroundManagement:
                                      () => unawaited(
                                        openMineReaderBackgroundManagement(),
                                      ),
                                  onRemoveActiveBackground:
                                      hasBackgroundImage
                                          ? () => unawaited(
                                            removeActiveBackground(),
                                          )
                                          : null,
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
                                  title: isMangaChapter ? '漫画阅读' : '自动阅读',
                                  subtitle:
                                      isMangaChapter
                                          ? '阅读模式、留白、图间距与加载策略'
                                          : isAudioChapter
                                          ? '播放速度与本次听书行为'
                                          : '启动方式、速度与本次自动阅读行为',
                                  onTap:
                                      () => setModalState(() {
                                        activeSettingsGroupKey =
                                            isMangaChapter
                                                ? 'manga'
                                                : isAudioChapter
                                                ? 'audio'
                                                : 'auto_read';
                                      }),
                                ),
                              ],
                        'quick_margins' => <Widget>[
                          buildOwnershipHintCard('quick_margins'),
                          ReaderLayoutInfoSettingsPanel(
                            settings: draft,
                            groups: semanticGroups(),
                            compactScale: compactSheetScale,
                            marginControlStep:
                                _ReaderPageState._kMarginControlStep,
                            sliderBuilder: buildPreviewAwareSlider,
                            formatLayoutMarginValue: _formatLayoutMarginValue,
                            letterSpacingSliderValue: _letterSpacingSliderValue,
                            letterSpacingValueLabel: _letterSpacingValueLabel,
                            letterSpacingFromSliderValue:
                                _letterSpacingFromSliderValue,
                            lineHeightSliderValue: _lineHeightSliderValue,
                            lineHeightValueLabel: _lineHeightValueLabel,
                            lineHeightFromSliderValue:
                                ({required sliderValue, required settings}) =>
                                    _lineHeightFromSliderValue(
                                      sliderValue: sliderValue,
                                      settings: settings,
                                    ),
                            paragraphSpacingValueLabel:
                                _paragraphSpacingValueLabel,
                            paragraphIndentValueLabel:
                                _paragraphIndentValueLabel,
                            readerBatteryReadFailed: _readerBatteryReadFailed,
                            onChanged:
                                (next) => setModalState(() {
                                  draft = next;
                                }),
                          ),
                        ],
                        'info_layout' => <Widget>[
                          buildOwnershipHintCard('info_layout'),
                          ReaderLayoutInfoSettingsPanel(
                            settings: draft,
                            groups: semanticGroups(),
                            compactScale: compactSheetScale,
                            marginControlStep:
                                _ReaderPageState._kMarginControlStep,
                            sliderBuilder: buildPreviewAwareSlider,
                            formatLayoutMarginValue: _formatLayoutMarginValue,
                            letterSpacingSliderValue: _letterSpacingSliderValue,
                            letterSpacingValueLabel: _letterSpacingValueLabel,
                            letterSpacingFromSliderValue:
                                _letterSpacingFromSliderValue,
                            lineHeightSliderValue: _lineHeightSliderValue,
                            lineHeightValueLabel: _lineHeightValueLabel,
                            lineHeightFromSliderValue:
                                ({required sliderValue, required settings}) =>
                                    _lineHeightFromSliderValue(
                                      sliderValue: sliderValue,
                                      settings: settings,
                                    ),
                            paragraphSpacingValueLabel:
                                _paragraphSpacingValueLabel,
                            paragraphIndentValueLabel:
                                _paragraphIndentValueLabel,
                            readerBatteryReadFailed: _readerBatteryReadFailed,
                            onChanged:
                                (next) => setModalState(() {
                                  draft = next;
                                }),
                          ),
                        ],
                        'typography' => <Widget>[
                          buildOwnershipHintCard('typography'),
                          ReaderTypographySettingsPanel(
                            settings: draft,
                            currentFontLabel: readerCurrentFontLabel(
                              draft,
                              availableCustomFonts,
                            ),
                            fontWeightLabel: readerFontWeightDisplayLabel(
                              draft,
                            ),
                            compactScale: compactSheetScale,
                            sliderBuilder: buildPreviewAwareSlider,
                            onChanged:
                                (next) => setModalState(() {
                                  draft = next;
                                }),
                            onOpenFontPicker:
                                () => unawaited(openFontPickerSheet()),
                            onManageFonts:
                                () => unawaited(openMineFontManagement()),
                            onOpenFontWeightSheet:
                                () => unawaited(openFontWeightTabSheet()),
                            onPickBodyTextColor:
                                (pickerContext, initialColorValue) =>
                                    _showBodyTextColorPickerDialog(
                                      pickerContext,
                                      initialColorValue: initialColorValue,
                                    ),
                            onRememberBodyTextColor: rememberBodyTextColor,
                            onPickBodyTextShadowColor:
                                (pickerContext, initialColorValue) =>
                                    _showBodyTextShadowColorPickerDialog(
                                      pickerContext,
                                      initialColorValue: initialColorValue,
                                    ),
                            onPickBodyTextDecorationColor:
                                (pickerContext, initialColorValue) =>
                                    _showBodyTextDecorationColorPickerDialog(
                                      pickerContext,
                                      initialColorValue: initialColorValue,
                                    ),
                          ),
                        ],
                        'interaction' => <Widget>[
                          buildOwnershipHintCard('interaction'),
                          ReaderPageTurnInteractionSettingsPanel(
                            settings: draft,
                            compactScale: compactSheetScale,
                            isVolumeKeyPagingSupported:
                                _platformBridgeService
                                    .isVolumeKeyPagingSupported,
                            onOpenTapZoneEditor:
                                () => unawaited(openTapZoneEditorSheet()),
                            onChanged:
                                (next) => setModalState(() {
                                  draft = next;
                                }),
                          ),
                        ],
                        'info' => <Widget>[
                          ReaderLayoutInfoSettingsPanel(
                            settings: draft,
                            groups: semanticGroups(),
                            compactScale: compactSheetScale,
                            marginControlStep:
                                _ReaderPageState._kMarginControlStep,
                            sliderBuilder: buildPreviewAwareSlider,
                            formatLayoutMarginValue: _formatLayoutMarginValue,
                            letterSpacingSliderValue: _letterSpacingSliderValue,
                            letterSpacingValueLabel: _letterSpacingValueLabel,
                            letterSpacingFromSliderValue:
                                _letterSpacingFromSliderValue,
                            lineHeightSliderValue: _lineHeightSliderValue,
                            lineHeightValueLabel: _lineHeightValueLabel,
                            lineHeightFromSliderValue:
                                ({required sliderValue, required settings}) =>
                                    _lineHeightFromSliderValue(
                                      sliderValue: sliderValue,
                                      settings: settings,
                                    ),
                            paragraphSpacingValueLabel:
                                _paragraphSpacingValueLabel,
                            paragraphIndentValueLabel:
                                _paragraphIndentValueLabel,
                            readerBatteryReadFailed: _readerBatteryReadFailed,
                            onChanged:
                                (next) => setModalState(() {
                                  draft = next;
                                }),
                          ),
                        ],
                        'behavior' => <Widget>[
                          ReaderReadingBehaviorSettingsPanel(
                            settings: draft,
                            compactScale: compactSheetScale,
                            isVolumeKeyPagingSupported:
                                _platformBridgeService
                                    .isVolumeKeyPagingSupported,
                            volumeKeySupportDescription:
                                _volumeKeyPageSupportDescription,
                            onChanged:
                                (next) => setModalState(() {
                                  draft = next;
                                }),
                          ),
                        ],
                        'auto_read' => <Widget>[
                          buildOwnershipHintCard('auto_read'),
                          ReaderAutoReadSettingsPanel(
                            settings: draft,
                            compactScale: compactSheetScale,
                            sliderBuilder: buildPreviewAwareSlider,
                            startAfterApply: startAutoReadAfterApply,
                            resolvePagedHoldDuration:
                                _autoReadCoordinator.resolvePagedHoldDuration,
                            onStartAfterApplyChanged:
                                (enabled) => setModalState(() {
                                  startAutoReadAfterApply = enabled;
                                }),
                            onChanged:
                                (next) => setModalState(() {
                                  draft = next;
                                }),
                          ),
                        ],
                        'manga' => <Widget>[
                          ReaderMangaSettingsPanel(
                            settings: draft,
                            compactScale: compactSheetScale,
                            onChanged:
                                (next) => setModalState(() {
                                  draft = next;
                                }),
                          ),
                        ],
                        'audio' => <Widget>[
                          buildOwnershipHintCard('audio'),
                          ReaderAudioSettingsPanel(
                            settings: draft,
                            compactScale: compactSheetScale,
                            sliderBuilder: buildPreviewAwareSlider,
                            isVolumeKeyPagingSupported:
                                _platformBridgeService
                                    .isVolumeKeyPagingSupported,
                            onChanged:
                                (next) => setModalState(() {
                                  draft = next;
                                }),
                          ),
                        ],
                        _ => const <Widget>[],
                      };
                      final selectedCards = wrapSettingsSection(
                        groupKey: activeSettingsGroupKey,
                        showInterfaceSettings: showInterfaceSettings,
                        children: rawSelectedCards,
                      );
                      final sheetTitle = _readerSettingsPresenter.sectionTitle(
                        groupKey: activeSettingsGroupKey,
                        showInterfaceSettings: showInterfaceSettings,
                      );
                      final textSheetMaxWidth = min(
                        AppLayout.pageContentMaxWidth(context, maxWidth: 760),
                        metrics.bottomSheetMaxWidth,
                      );
                      final settingsSheetHeightFactor =
                          showInterfaceSettings &&
                                  activeSettingsGroupKey == null
                              ? _adaptiveReaderSheetHeightFactor(
                                context,
                                compact: 0.58,
                                regular: 0.54,
                                large: 0.58,
                              )
                              : activeSettingsGroupKey == 'typography'
                              ? _adaptiveReaderSheetHeightFactor(
                                context,
                                compact: 0.50,
                                regular: 0.46,
                                large: 0.50,
                              )
                              : _adaptiveReaderSheetHeightFactor(
                                context,
                                compact: 0.80,
                                regular: 0.72,
                                large: 0.80,
                              );

                      return AnimatedTheme(
                        duration: const Duration(milliseconds: 160),
                        data: readerModalTheme.copyWith(
                          bottomSheetTheme: readerModalTheme.bottomSheetTheme
                              .copyWith(
                                backgroundColor: sheetSurfaceColor,
                                modalBackgroundColor: sheetSurfaceColor,
                              ),
                        ),
                        child: _buildFloatingReaderSettingsSheet(
                          context: context,
                          readerModalTheme: readerModalTheme,
                          keyboardInset: keyboardInset,
                          safeBottom: safeBottom,
                          sheetHorizontal: sheetHorizontal,
                          maxWidth:
                              metrics.isExpandedWindow
                                  ? 520
                                  : textSheetMaxWidth,
                          heightFactor: settingsSheetHeightFactor,
                          backgroundColor: sheetSurfaceColor,
                          child: Material(
                            color: Colors.transparent,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                metrics.pagePadding,
                                metrics.isCompactDensity ? 6 : 8,
                                metrics.pagePadding,
                                max(6.0, safeBottom * 0.35),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 4,
                                    margin: EdgeInsets.only(
                                      bottom: metrics.isCompactDensity ? 8 : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  SizedBox(
                                    height: metrics.controlHeight,
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
                                  SizedBox(
                                    height: metrics.isCompactDensity ? 4 : 6,
                                  ),
                                  Expanded(
                                    child: ListView(
                                      padding: EdgeInsets.only(
                                        bottom: max(4.0, safeBottom * 0.18),
                                      ),
                                      children: selectedCards,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    previewDraftSettings();
                    return buildTextReaderSettingsSheet();
                  },
                ),
              ),
            ],
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

    if (entryPlan.shouldRestoreOverlayAfterClose) {
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
    await _persistResolvedReaderSettingsLayers(appliedResult);
    if (activeSettingsGroupKey == 'auto_read') {
      await _preferencesService.saveAutoReadConfigured(true);
    }

    try {
      if (shouldEnableAutoRead && mounted) {
        await _toggleAutoReadSession();
      }
    } finally {
      _resumeOverlayAutoHide();
    }
  }

  Future<void> _ensureBackgroundPresetsReady() =>
      _ensureBackgroundPresetsReadyImpl();

  List<ReaderBackgroundColorOption> _readerBackgroundColorOptions() {
    return <ReaderBackgroundColorOption>[
      _createReaderBackgroundColorOption(
        label: '明亮',
        mode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.surface,
      ),
      _createReaderBackgroundColorOption(
        label: '护眼',
        mode: ReaderThemeMode.sepia,
        backgroundStyle: ReaderBackgroundStyle.warm,
        backgroundTone: ReaderBackgroundTone.container,
      ),
      _createReaderBackgroundColorOption(
        label: '浅灰',
        mode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.paper,
        backgroundTone: ReaderBackgroundTone.containerHigh,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeFlameOrangeOption,
        backgroundTone: ReaderBackgroundTone.flameOrangeTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemePineGreenOption,
        backgroundTone: ReaderBackgroundTone.pineGreenTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeSeaBlueOption,
        backgroundTone: ReaderBackgroundTone.seaBlueTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeNightPurpleOption,
        backgroundTone: ReaderBackgroundTone.nightPurpleTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeMistTealOption,
        backgroundTone: ReaderBackgroundTone.mistTealTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeBerryRoseOption,
        backgroundTone: ReaderBackgroundTone.berryRoseTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeAmberGoldOption,
        backgroundTone: ReaderBackgroundTone.amberGoldTint,
      ),
      _createReaderBackgroundColorOption(
        label: '夜间',
        mode: ReaderThemeMode.dark,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.pureBlack,
      ),
    ];
  }

  ReaderBackgroundColorOption _createReaderBackgroundColorOption({
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
    return ReaderBackgroundColorOption(
      label: label,
      previewColor: previewColors.background,
      mode: mode,
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
    );
  }

  ReaderBackgroundColorOption _createReaderThemePaletteBackgroundColorOption({
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

  Future<String?> _pickBackgroundImagePath() async {
    try {
      final picked = await _imageSelectionService.pickImage(
        confirmButtonText: '选择背景',
      );
      if (picked == null) {
        return null;
      }

      final Uint8List bytes = picked.bytes;
      if (bytes.isEmpty) {
        _showMessage('背景图片读取失败。');
        return null;
      }
      final storedPath = await _storeCustomBackgroundImage(bytes);
      return storedPath;
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
      return null;
    } on PlatformException catch (error) {
      _showMessage('选择背景失败：${error.message ?? error.code}');
      return null;
    } catch (error) {
      _showMessage('选择背景失败：$error');
      return null;
    }
  }

  String _formatTypographyValue({
    required double value,
    required int fractionDigits,
    String unit = '',
  }) {
    final normalized = value == 0 ? 0.0 : value;
    return '${normalized.toStringAsFixed(fractionDigits)}$unit';
  }
}
