part of 'reader_page.dart';

extension _ReaderPageSettingsSheetExtension on _ReaderPageState {
  Future<void> _showSettingsSheet({
    _ReaderSettingsTab initialTab = _ReaderSettingsTab.reading,
    String? initialSettingsGroupKey,
    bool startAutoReadAfterApplyInitially = false,
  }) async {
    final entryPlan = _settingsEntryController.buildOpenPlan(
      overlayVisible: _overlayController.showOverlayControls,
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
    final showInterfaceSettings = initialTab == _ReaderSettingsTab.interface;
    final isAudioChapter = _currentContentMode == ReaderContentMode.audio;
    String? activeSettingsGroupKey = initialSettingsGroupKey;
    const settingsGroupingService = ReaderSettingsGroupingService();
    const backgroundTilesPresenter = ReaderSettingsBackgroundTilesPresenter();
    final settingsSession = ReaderSettingsSheetSession(
      initialSettings: _settings,
      currentDraft: () => draft,
      isMounted: () => mounted,
      persistSettings: _persistResolvedReaderSettingsLayers,
    );

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
              ReaderFullScreenHitTestLayer(
                strategy: ReaderFullScreenHitTestStrategy.interceptWhenVisible,
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox.shrink(),
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
                              settingsSession.isSliderInteracting
                                  ? interactionSheetAlpha
                                  : 1.0,
                        );

                    final backgroundSelection = backgroundTilesPresenter
                        .resolveSelection(
                          activeBackgroundValue: draft.backgroundImageBase64,
                          presetValues: _backgroundPresetBase64.values,
                        );
                    final activeBackgroundBase64 =
                        backgroundSelection.activeBackgroundValue;
                    final hasBackgroundImage =
                        backgroundSelection.hasBackgroundImage;
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

                      if (settingsSession.isSliderInteracting) {
                        settingsSession.schedulePersistDraft();
                      } else {
                        unawaited(settingsSession.persistNow(draft));
                      }
                      final currentFingerprint =
                          ReaderSettingsSheetSession.fingerprintFor(_settings);
                      final draftFingerprint =
                          ReaderSettingsSheetSession.fingerprintFor(draft);
                      if (currentFingerprint == draftFingerprint) {
                        return;
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted ||
                            ReaderSettingsSheetSession.fingerprintFor(
                                  _settings,
                                ) ==
                                ReaderSettingsSheetSession.fingerprintFor(
                                  draft,
                                )) {
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
                      settingsSession.setSliderInteractionPreview(
                        active,
                        delayedRestore: delayedRestore,
                        canUpdate: () => mounted && context.mounted,
                        notifyChanged: () => setModalState(() {}),
                      );
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
                        const ReaderSettingsBackgroundColorOptionsPresenter()
                            .build(
                              resolvePreviewColor:
                                  (mode, settings) =>
                                      _resolveThemeColors(
                                        mode,
                                        settings,
                                      ).background,
                            );
                    final presetBackgroundTiles = backgroundTilesPresenter
                        .buildPresetTiles(
                          presets: _backgroundPresets,
                          presetBytes: _backgroundPresetBytes,
                          presetBase64: _backgroundPresetBase64,
                          activeBackgroundValue: activeBackgroundBase64,
                          onSelectPreset:
                              (assetPath) => updateDraft(
                                draft.copyWith(
                                  backgroundImageBase64: assetPath,
                                ),
                              ),
                        );
                    final customBackgroundTiles = backgroundTilesPresenter
                        .buildCustomTiles(
                          customBackgrounds: customBackgrounds,
                          customPreviewBytes: _customBackgroundPreviewBytes,
                          selection: backgroundSelection,
                          onSelectCustom:
                              (source) => unawaited(
                                applyStoredCustomBackground(source),
                              ),
                        );
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
                      interactionPreviewActive:
                          settingsSession.isSliderInteracting,
                    );

                    Widget buildTextReaderSettingsSheet() {
                      Widget buildOwnershipHintCard(String groupKey) {
                        final descriptor = _readerSettingsPresenter
                            .ownershipDescriptor(groupKey);
                        return ReaderSettingsOwnershipHintCard(
                          title: descriptor.title,
                          description: descriptor.description,
                          compactScale: compactSheetScale,
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

                      Widget buildLayoutInfoSettingsPanel() {
                        return ReaderLayoutInfoSettingsPanel(
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
                          paragraphIndentValueLabel: _paragraphIndentValueLabel,
                          readerBatteryReadFailed: _readerBatteryReadFailed,
                          onChanged:
                              (next) => setModalState(() {
                                draft = next;
                              }),
                        );
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
                          buildLayoutInfoSettingsPanel(),
                        ],
                        'info_layout' => <Widget>[
                          buildOwnershipHintCard('info_layout'),
                          buildLayoutInfoSettingsPanel(),
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
                        'info' => <Widget>[buildLayoutInfoSettingsPanel()],
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
                          child: ReaderSettingsSheetFrame(
                            title: sheetTitle,
                            safeBottom: safeBottom,
                            onBack:
                                activeSettingsGroupKey == null
                                    ? null
                                    : () => setModalState(() {
                                      activeSettingsGroupKey = null;
                                    }),
                            children: selectedCards,
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
    settingsSession.cancelTimers();
    await settingsSession.persistNow(draft);

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
}
