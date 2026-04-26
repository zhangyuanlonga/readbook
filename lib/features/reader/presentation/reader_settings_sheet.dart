import 'package:flutter/material.dart';

import '../../../domain/entities/reader_settings.dart';
import '../application/reader_settings_groups.dart';
import '../application/reader_settings_preset_service.dart';

enum ReaderSettingsSheetTab { basic, advanced }

enum ReaderSettingsSheetGroupKey {
  typography,
  bodyLayout,
  chapterHeader,
  infoBar,
  visualDecoration,
}

typedef ReaderSettingsSheetBodyBuilder =
    Widget Function(
      BuildContext context,
      ReaderSettingsSheetState state,
      ReaderSettingsSheetCallbacks callbacks,
    );

typedef ReaderSettingsSheetGroupBuilder =
    Widget? Function(
      BuildContext context,
      ReaderSettingsSheetGroupDescriptor group,
      ReaderSettingsSheetState state,
      ReaderSettingsSheetCallbacks callbacks,
    );

class ReaderSettingsSheetGroupDescriptor {
  const ReaderSettingsSheetGroupDescriptor({
    required this.key,
    required this.title,
    required this.subtitle,
  });

  final ReaderSettingsSheetGroupKey key;
  final String title;
  final String subtitle;
}

class ReaderSettingsSheetPresetSelection {
  const ReaderSettingsSheetPresetSelection({
    this.typography,
    this.spacing,
    this.chapterHeader,
    this.infoStyle,
    this.font,
  });

  final ReaderTypographyPreset? typography;
  final ReaderSpacingPreset? spacing;
  final ReaderChapterHeaderPreset? chapterHeader;
  final ReaderInfoStylePreset? infoStyle;
  final ReaderFontPreset? font;
}

class ReaderSettingsSheetPresetInput {
  ReaderSettingsSheetPresetInput({
    required this.settings,
    required this.selection,
    List<ReaderTypographyPreset>? typographyPresets,
    List<ReaderSpacingPreset>? spacingPresets,
    List<ReaderChapterHeaderPreset>? chapterHeaderPresets,
    List<ReaderInfoStylePreset>? infoStylePresets,
    List<ReaderFontPreset>? fontPresets,
  }) : typographyPresets = List<ReaderTypographyPreset>.unmodifiable(
         typographyPresets ?? ReaderTypographyPreset.values,
       ),
       spacingPresets = List<ReaderSpacingPreset>.unmodifiable(
         spacingPresets ?? ReaderSpacingPreset.values,
       ),
       chapterHeaderPresets = List<ReaderChapterHeaderPreset>.unmodifiable(
         chapterHeaderPresets ?? ReaderChapterHeaderPreset.values,
       ),
       infoStylePresets = List<ReaderInfoStylePreset>.unmodifiable(
         infoStylePresets ?? ReaderInfoStylePreset.values,
       ),
       fontPresets = List<ReaderFontPreset>.unmodifiable(
         fontPresets ?? ReaderFontPreset.values,
       );

  final ReaderSettings settings;
  final ReaderSettingsSheetPresetSelection selection;
  final List<ReaderTypographyPreset> typographyPresets;
  final List<ReaderSpacingPreset> spacingPresets;
  final List<ReaderChapterHeaderPreset> chapterHeaderPresets;
  final List<ReaderInfoStylePreset> infoStylePresets;
  final List<ReaderFontPreset> fontPresets;
}

class ReaderSettingsSheetSemanticInput {
  const ReaderSettingsSheetSemanticInput({
    required this.groups,
    required this.groupDescriptors,
  });

  final ReaderSettingsGroups groups;
  final List<ReaderSettingsSheetGroupDescriptor> groupDescriptors;
}

class ReaderSettingsSheetBasicInput {
  const ReaderSettingsSheetBasicInput({
    required this.settings,
    required this.groups,
    required this.currentFontLabel,
    required this.enabledInfoItemCount,
    this.showsPinnedChapterHeader = false,
    this.showsBatteryWarning = false,
  });

  final ReaderSettings settings;
  final ReaderSettingsGroups groups;
  final String currentFontLabel;
  final int enabledInfoItemCount;
  final bool showsPinnedChapterHeader;
  final bool showsBatteryWarning;
}

class ReaderSettingsSheetExtensionSection {
  const ReaderSettingsSheetExtensionSection({
    required this.id,
    required this.title,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
}

class ReaderSettingsSheetAdvancedInput {
  const ReaderSettingsSheetAdvancedInput({
    required this.settings,
    required this.semantic,
    this.activeGroup,
    this.extensions = const <ReaderSettingsSheetExtensionSection>[],
    this.activeExtensionId,
  });

  final ReaderSettings settings;
  final ReaderSettingsSheetSemanticInput semantic;
  final ReaderSettingsSheetGroupKey? activeGroup;
  final List<ReaderSettingsSheetExtensionSection> extensions;
  final String? activeExtensionId;
}

class ReaderSettingsSheetState {
  ReaderSettingsSheetState({
    required this.settings,
    required this.groups,
    required this.showInterfaceSettings,
    this.activeGroupKey,
    this.activeTab = ReaderSettingsSheetTab.basic,
    this.currentFontLabel = '系统默认',
    this.presetSelection = const ReaderSettingsSheetPresetSelection(),
    List<ReaderSettingsSheetGroupDescriptor>? groupDescriptors,
    this.extensionSections = const <ReaderSettingsSheetExtensionSection>[],
    this.activeExtensionId,
    this.showsPinnedChapterHeader = false,
    this.showsBatteryWarning = false,
  }) : groupDescriptors = List<ReaderSettingsSheetGroupDescriptor>.unmodifiable(
         groupDescriptors ?? _defaultGroupDescriptors,
       );

  factory ReaderSettingsSheetState.fromSettings({
    required ReaderSettings settings,
    required bool showInterfaceSettings,
    String currentFontLabel = '系统默认',
    String? activeGroupKey,
    ReaderSettingsSheetTab activeTab = ReaderSettingsSheetTab.basic,
    ReaderSettingsSheetPresetSelection? presetSelection,
    List<ReaderSettingsSheetGroupDescriptor>? groupDescriptors,
    List<ReaderSettingsSheetExtensionSection> extensionSections =
        const <ReaderSettingsSheetExtensionSection>[],
    String? activeExtensionId,
    bool showsPinnedChapterHeader = false,
    bool showsBatteryWarning = false,
    ReaderSettingsGroupingService groupingService =
        const ReaderSettingsGroupingService(),
  }) {
    return ReaderSettingsSheetState(
      settings: settings,
      groups: groupingService.split(settings),
      showInterfaceSettings: showInterfaceSettings,
      activeGroupKey: activeGroupKey,
      activeTab: activeTab,
      currentFontLabel: currentFontLabel,
      presetSelection: presetSelection ?? _inferPresetSelection(settings),
      groupDescriptors: groupDescriptors,
      extensionSections: extensionSections,
      activeExtensionId: activeExtensionId,
      showsPinnedChapterHeader: showsPinnedChapterHeader,
      showsBatteryWarning: showsBatteryWarning,
    );
  }

  final ReaderSettings settings;
  final ReaderSettingsGroups groups;
  final bool showInterfaceSettings;
  final String? activeGroupKey;
  final ReaderSettingsSheetTab activeTab;
  final String currentFontLabel;
  final ReaderSettingsSheetPresetSelection presetSelection;
  final List<ReaderSettingsSheetGroupDescriptor> groupDescriptors;
  final List<ReaderSettingsSheetExtensionSection> extensionSections;
  final String? activeExtensionId;
  final bool showsPinnedChapterHeader;
  final bool showsBatteryWarning;

  ReaderSettingsSheetPresetInput get presetInput =>
      ReaderSettingsSheetPresetInput(
        settings: settings,
        selection: presetSelection,
      );

  ReaderSettingsSheetSemanticInput get semanticInput =>
      ReaderSettingsSheetSemanticInput(
        groups: groups,
        groupDescriptors: groupDescriptors,
      );

  ReaderSettingsSheetBasicInput get basicInput => ReaderSettingsSheetBasicInput(
    settings: settings,
    groups: groups,
    currentFontLabel: currentFontLabel,
    enabledInfoItemCount: _enabledInfoItemCount(settings),
    showsPinnedChapterHeader: showsPinnedChapterHeader,
    showsBatteryWarning: showsBatteryWarning,
  );

  ReaderSettingsSheetAdvancedInput get advancedInput =>
      ReaderSettingsSheetAdvancedInput(
        settings: settings,
        semantic: semanticInput,
        activeGroup: activeGroup,
        extensions: extensionSections,
        activeExtensionId: activeExtensionId,
      );

  ReaderSettingsSheetGroupKey? get activeGroup {
    final key = activeGroupKey;
    if (key == null) {
      return null;
    }
    for (final descriptor in groupDescriptors) {
      if (descriptor.storageKey == key) {
        return descriptor.key;
      }
    }
    return null;
  }

  ReaderSettingsSheetGroupDescriptor? get activeGroupDescriptor {
    final group = activeGroup;
    if (group == null) {
      return null;
    }
    for (final descriptor in groupDescriptors) {
      if (descriptor.key == group) {
        return descriptor;
      }
    }
    return null;
  }

  ReaderSettings settingsFor(
    ReaderSettingsPresetService presetService, {
    ReaderTypographyPreset? typographyPreset,
    ReaderSpacingPreset? spacingPreset,
    ReaderChapterHeaderPreset? chapterHeaderPreset,
    ReaderInfoStylePreset? infoStylePreset,
    ReaderFontPreset? fontPreset,
  }) {
    var next = settings;
    if (typographyPreset != null) {
      next = presetService.applyTypographyPreset(next, typographyPreset);
    }
    if (spacingPreset != null) {
      next = presetService.applySpacingPreset(next, spacingPreset);
    }
    if (chapterHeaderPreset != null) {
      next = presetService.applyChapterHeaderPreset(next, chapterHeaderPreset);
    }
    if (infoStylePreset != null) {
      next = presetService.applyInfoStylePreset(next, infoStylePreset);
    }
    if (fontPreset != null) {
      next = presetService.applyFontPreset(next, fontPreset);
    }
    return next;
  }

  static int _enabledInfoItemCount(ReaderSettings settings) {
    var count = 0;
    if (settings.infoShowTime) {
      count += 1;
    }
    if (settings.infoShowBattery) {
      count += 1;
    }
    if (settings.infoShowProgress) {
      count += 1;
    }
    if (settings.infoShowChapter) {
      count += 1;
    }
    return count;
  }

  static ReaderSettingsSheetPresetSelection _inferPresetSelection(
    ReaderSettings settings,
  ) {
    final service = const ReaderSettingsPresetService();
    return ReaderSettingsSheetPresetSelection(
      typography: _firstMatchingOrNull(ReaderTypographyPreset.values, (preset) {
        final applied = service.applyTypographyPreset(settings, preset);
        return applied.fontSize == settings.fontSize &&
            applied.lineHeight == settings.lineHeight &&
            applied.letterSpacing == settings.letterSpacing &&
            applied.textFullJustifyEnabled == settings.textFullJustifyEnabled;
      }),
      spacing: _firstMatchingOrNull(ReaderSpacingPreset.values, (preset) {
        final applied = service.applySpacingPreset(settings, preset);
        return applied.paragraphSpacing == settings.paragraphSpacing &&
            applied.paragraphIndent == settings.paragraphIndent;
      }),
      chapterHeader: _firstMatchingOrNull(ReaderChapterHeaderPreset.values, (
        preset,
      ) {
        final applied = service.applyChapterHeaderPreset(settings, preset);
        return applied.pinnedChapterHeaderOffsetX ==
                settings.pinnedChapterHeaderOffsetX &&
            applied.pinnedChapterHeaderOffsetY ==
                settings.pinnedChapterHeaderOffsetY;
      }),
      infoStyle: _firstMatchingOrNull(ReaderInfoStylePreset.values, (preset) {
        final applied = service.applyInfoStylePreset(settings, preset);
        return applied.infoHeaderEnabled == settings.infoHeaderEnabled &&
            applied.infoFooterEnabled == settings.infoFooterEnabled &&
            applied.infoShowTime == settings.infoShowTime &&
            applied.infoShowBattery == settings.infoShowBattery &&
            applied.infoShowProgress == settings.infoShowProgress &&
            applied.infoHeaderPadding == settings.infoHeaderPadding &&
            applied.infoFooterPadding == settings.infoFooterPadding;
      }),
      font: _firstMatchingOrNull(ReaderFontPreset.values, (preset) {
        final applied = service.applyFontPreset(settings, preset);
        return applied.fontSource == settings.fontSource &&
            applied.systemFontPreset == settings.systemFontPreset;
      }),
    );
  }

  static T? _firstMatchingOrNull<T>(
    Iterable<T> values,
    bool Function(T value) predicate,
  ) {
    for (final value in values) {
      if (predicate(value)) {
        return value;
      }
    }
    return null;
  }
}

class ReaderSettingsSheetCallbacks {
  const ReaderSettingsSheetCallbacks({
    this.onBack,
    this.onCloseRequested,
    this.onTabChanged,
    this.onAdvancedGroupChanged,
    this.onAdvancedExtensionChanged,
    this.onSettingsChanged,
    this.onOpenFontPickerRequested,
    this.onOpenFontWeightPickerRequested,
    this.onTypographyPresetSelected,
    this.onSpacingPresetSelected,
    this.onChapterHeaderPresetSelected,
    this.onInfoStylePresetSelected,
    this.onFontPresetSelected,
  });

  final VoidCallback? onBack;
  final VoidCallback? onCloseRequested;
  final ValueChanged<ReaderSettingsSheetTab>? onTabChanged;
  final ValueChanged<ReaderSettingsSheetGroupKey?>? onAdvancedGroupChanged;
  final ValueChanged<String?>? onAdvancedExtensionChanged;
  final ValueChanged<ReaderSettings>? onSettingsChanged;
  final VoidCallback? onOpenFontPickerRequested;
  final VoidCallback? onOpenFontWeightPickerRequested;
  final ValueChanged<ReaderTypographyPreset>? onTypographyPresetSelected;
  final ValueChanged<ReaderSpacingPreset>? onSpacingPresetSelected;
  final ValueChanged<ReaderChapterHeaderPreset>? onChapterHeaderPresetSelected;
  final ValueChanged<ReaderInfoStylePreset>? onInfoStylePresetSelected;
  final ValueChanged<ReaderFontPreset>? onFontPresetSelected;
}

class ReaderSettingsSheet extends StatelessWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.title,
    required this.state,
    this.content,
    this.onBack,
    this.callbacks = const ReaderSettingsSheetCallbacks(),
    this.basicBuilder,
    this.advancedOverviewBuilder,
    this.advancedGroupBuilder,
  });

  final String title;
  final ReaderSettingsSheetState state;
  final Widget? content;
  final VoidCallback? onBack;
  final ReaderSettingsSheetCallbacks callbacks;
  final ReaderSettingsSheetBodyBuilder? basicBuilder;
  final ReaderSettingsSheetBodyBuilder? advancedOverviewBuilder;
  final ReaderSettingsSheetGroupBuilder? advancedGroupBuilder;

  @override
  Widget build(BuildContext context) {
    final sheetBody =
        content ??
        switch (state.activeTab) {
          ReaderSettingsSheetTab.basic => _buildBasicContent(context),
          ReaderSettingsSheetTab.advanced => _buildAdvancedContent(context),
        };

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (state.activeGroupKey != null && onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: callbacks.onBack ?? onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: callbacks.onCloseRequested,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SegmentedButton<ReaderSettingsSheetTab>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: ReaderSettingsSheetTab.basic,
              label: Text('基础设置'),
            ),
            ButtonSegment(
              value: ReaderSettingsSheetTab.advanced,
              label: Text('高级设置'),
            ),
          ],
          selected: {state.activeTab},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              callbacks.onTabChanged?.call(selection.first);
            }
          },
        ),
        const SizedBox(height: 10),
        Expanded(child: sheetBody),
      ],
    );
  }

  Widget _buildBasicContent(BuildContext context) {
    if (basicBuilder != null) {
      return basicBuilder!(context, state, callbacks);
    }
    return _ReaderSettingsSheetBasicSkeleton(
      state: state,
      callbacks: callbacks,
    );
  }

  Widget _buildAdvancedContent(BuildContext context) {
    final group = state.activeGroupDescriptor;
    if (group != null && advancedGroupBuilder != null) {
      final built = advancedGroupBuilder!(context, group, state, callbacks);
      if (built != null) {
        return built;
      }
    }
    if (advancedOverviewBuilder != null) {
      return advancedOverviewBuilder!(context, state, callbacks);
    }
    return _ReaderSettingsSheetAdvancedSkeleton(
      state: state,
      callbacks: callbacks,
    );
  }
}

class _ReaderSettingsSheetBasicSkeleton extends StatelessWidget {
  const _ReaderSettingsSheetBasicSkeleton({
    required this.state,
    required this.callbacks,
  });

  final ReaderSettingsSheetState state;
  final ReaderSettingsSheetCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final basic = state.basicInput;
    final presetInput = state.presetInput;
    return ListView(
      children: [
        _ReaderSettingsCard(
          title: '主题',
          subtitle: '基础设置只保留高频主题入口。',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReaderThemeMode.values
                .map(
                  (mode) => ChoiceChip(
                    label: Text(_themeModeLabel(mode)),
                    selected: basic.settings.themeMode == mode,
                    showCheckmark: false,
                    onSelected:
                        (_) => callbacks.onSettingsChanged?.call(
                          basic.settings.copyWith(themeMode: mode),
                        ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        _ReaderSettingsCard(
          title: 'Preset',
          subtitle: '基础设置先承接 preset，兼容 ReaderSettingsPresetService。',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...presetInput.typographyPresets.map(
                (preset) => ChoiceChip(
                  label: Text(_typographyPresetLabel(preset)),
                  selected: presetInput.selection.typography == preset,
                  showCheckmark: false,
                  onSelected:
                      (_) => callbacks.onTypographyPresetSelected?.call(preset),
                ),
              ),
              ...presetInput.spacingPresets.map(
                (preset) => ChoiceChip(
                  label: Text(_spacingPresetLabel(preset)),
                  selected: presetInput.selection.spacing == preset,
                  showCheckmark: false,
                  onSelected:
                      (_) => callbacks.onSpacingPresetSelected?.call(preset),
                ),
              ),
              ...presetInput.fontPresets.map(
                (preset) => ChoiceChip(
                  label: Text(_fontPresetLabel(preset)),
                  selected: presetInput.selection.font == preset,
                  showCheckmark: false,
                  onSelected:
                      (_) => callbacks.onFontPresetSelected?.call(preset),
                ),
              ),
            ],
          ),
        ),
        _ReaderSettingsCard(
          title: '正文排版',
          subtitle:
              '字号 ${basic.groups.typography.fontSize.toStringAsFixed(0)} / 行距 ${basic.groups.typography.lineHeight.toStringAsFixed(2)} / 段距 ${basic.groups.typography.paragraphSpacing.toStringAsFixed(0)} / 字距 ${basic.groups.typography.letterSpacing.toStringAsFixed(2)}',
          child: _ReaderSettingsSummaryList(
            items: [
              '字体：${basic.currentFontLabel}',
              '缩进：${basic.groups.typography.paragraphIndent.toStringAsFixed(0)}',
              '两端对齐：${basic.groups.typography.textFullJustifyEnabled ? '开' : '关'}',
            ],
          ),
        ),
        _ReaderSettingsCard(
          title: '字号',
          subtitle: '高频入口保留字号直调。',
          child: _ReaderSettingsSliderRow(
            label: '字号',
            value: basic.settings.fontSize,
            min: 12,
            max: 30,
            divisions: 18,
            valueLabel: basic.settings.fontSize.toStringAsFixed(0),
            onChanged:
                (value) => callbacks.onSettingsChanged?.call(
                  basic.settings.copyWith(fontSize: value),
                ),
          ),
        ),
        _ReaderSettingsCard(
          title: '正文版面',
          subtitle: '基础设置聚焦边距 preset。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReaderBodyMarginPreset.values
                    .map(
                      (preset) => ChoiceChip(
                        label: Text(_bodyMarginPresetLabel(preset)),
                        selected:
                            basic.groups.bodyLayout.bodyMarginMode ==
                                ReaderBodyMarginMode.preset &&
                            basic.groups.bodyLayout.bodyMarginPreset == preset,
                        showCheckmark: false,
                        onSelected:
                            (_) => callbacks.onSettingsChanged?.call(
                              basic.settings.copyWith(
                                bodyMarginMode: ReaderBodyMarginMode.preset,
                                bodyMarginPreset: preset,
                              ),
                            ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              _ReaderSettingsSummaryList(
                items: [
                  '模式：${_bodyMarginModeLabel(basic.groups.bodyLayout.bodyMarginMode)}',
                  '预设：${_bodyMarginPresetLabel(basic.groups.bodyLayout.bodyMarginPreset)}',
                  '左/右：${basic.groups.bodyLayout.bodyMarginLeft.toStringAsFixed(0)} / ${basic.groups.bodyLayout.bodyMarginRight.toStringAsFixed(0)}',
                ],
              ),
            ],
          ),
        ),
        _ReaderSettingsCard(
          title: '章节头与信息栏',
          subtitle: '基础设置只放高频摘要，高级设置再进入分组细调。',
          child: _ReaderSettingsSummaryList(
            items: [
              '章节头位置：${basic.groups.chapterHeader.pinnedChapterHeaderOffsetX.toStringAsFixed(2)} / ${basic.groups.chapterHeader.pinnedChapterHeaderOffsetY.toStringAsFixed(0)}',
              '信息项：${basic.enabledInfoItemCount}',
              '页眉/页脚：${basic.groups.infoBar.infoHeaderEnabled ? '开' : '关'} / ${basic.groups.infoBar.infoFooterEnabled ? '开' : '关'}',
            ],
          ),
        ),
        _ReaderSettingsCard(
          title: '信息样式',
          subtitle: 'preset 作为基础入口，避免重复堆 raw fields。',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presetInput.infoStylePresets
                .map(
                  (preset) => ChoiceChip(
                    label: Text(_infoStylePresetLabel(preset)),
                    selected: presetInput.selection.infoStyle == preset,
                    showCheckmark: false,
                    onSelected:
                        (_) =>
                            callbacks.onInfoStylePresetSelected?.call(preset),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _ReaderSettingsSheetAdvancedSkeleton extends StatelessWidget {
  const _ReaderSettingsSheetAdvancedSkeleton({
    required this.state,
    required this.callbacks,
  });

  final ReaderSettingsSheetState state;
  final ReaderSettingsSheetCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final advanced = state.advancedInput;
    final group = advanced.activeGroup;
    if (group != null) {
      return _buildActiveGroup(context, group);
    }
    return ListView(
      children: [
        _ReaderSettingsCard(
          title: '语义分组',
          subtitle: '主线程后续可以把旧 UI 一组一组迁进来，而不是继续堆在 reader_page.dart 里。',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: advanced.semantic.groupDescriptors
                .map(
                  (descriptor) => FilterChip(
                    label: Text(descriptor.title),
                    selected: advanced.activeGroup == descriptor.key,
                    showCheckmark: false,
                    onSelected:
                        (_) => callbacks.onAdvancedGroupChanged?.call(
                          descriptor.key,
                        ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        ...advanced.semantic.groupDescriptors.map(
          (descriptor) => _ReaderSettingsCard(
            title: descriptor.title,
            subtitle: descriptor.subtitle,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed:
                    () =>
                        callbacks.onAdvancedGroupChanged?.call(descriptor.key),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('进入分组'),
              ),
            ),
          ),
        ),
        if (advanced.extensions.isNotEmpty)
          _ReaderSettingsCard(
            title: '扩展挂载点',
            subtitle: '自动阅读、缓存、交互等非核心排版项，后续统一挂在这里。',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: advanced.extensions
                  .map(
                    (section) => ActionChip(
                      label: Text(section.title),
                      onPressed:
                          () => callbacks.onAdvancedExtensionChanged?.call(
                            section.id,
                          ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveGroup(
    BuildContext context,
    ReaderSettingsSheetGroupKey group,
  ) {
    return switch (group) {
      ReaderSettingsSheetGroupKey.typography => _buildTypographyGroup(context),
      ReaderSettingsSheetGroupKey.bodyLayout => _buildBodyLayoutGroup(context),
      ReaderSettingsSheetGroupKey.chapterHeader => _buildChapterHeaderGroup(
        context,
      ),
      ReaderSettingsSheetGroupKey.infoBar => _buildInfoBarGroup(context),
      ReaderSettingsSheetGroupKey.visualDecoration => _buildVisualGroup(
        context,
      ),
    };
  }

  Widget _buildTypographyGroup(BuildContext context) {
    final settings = state.settings;
    return ListView(
      children: [
        _ReaderSettingsCard(
          title: '正文排版',
          subtitle: '字距、段距、缩进等低频项下沉到高级设置。',
          child: Column(
            children: [
              _ReaderSettingsActionRow(
                label: '字体',
                value: state.currentFontLabel,
                onTap: callbacks.onOpenFontPickerRequested,
              ),
              _ReaderSettingsActionRow(
                label: '字重',
                value: _fontWeightValueLabel(settings),
                onTap: callbacks.onOpenFontWeightPickerRequested,
              ),
              _ReaderSettingsSliderRow(
                label: '字号',
                value: settings.fontSize,
                min: 12,
                max: 30,
                divisions: 18,
                valueLabel: settings.fontSize.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(fontSize: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '行距',
                value: settings.lineHeight,
                min: 1.2,
                max: 2.2,
                divisions: 20,
                valueLabel: settings.lineHeight.toStringAsFixed(2),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(lineHeight: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '段距',
                value: settings.paragraphSpacing,
                min: 0,
                max: 32,
                divisions: 16,
                valueLabel: settings.paragraphSpacing.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(paragraphSpacing: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '缩进',
                value: settings.paragraphIndent,
                min: 0,
                max: 6,
                divisions: 6,
                valueLabel: settings.paragraphIndent.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(paragraphIndent: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '字距',
                value: settings.letterSpacing,
                min: ReaderSettings.minLetterSpacing,
                max: ReaderSettings.maxLetterSpacing,
                divisions: 20,
                valueLabel: settings.letterSpacing.toStringAsFixed(2),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(letterSpacing: value),
                    ),
              ),
              const SizedBox(height: 8),
              _ReaderSettingsToggleRow(
                label: '两端对齐',
                value: settings.textFullJustifyEnabled,
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(textFullJustifyEnabled: value),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBodyLayoutGroup(BuildContext context) {
    final settings = state.settings;
    return ListView(
      children: [
        _ReaderSettingsCard(
          title: '正文版面',
          subtitle: 'preset 作为默认入口，自定义边距下沉。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReaderBodyMarginMode.values
                    .map(
                      (mode) => ChoiceChip(
                        label: Text(_bodyMarginModeLabel(mode)),
                        selected: settings.bodyMarginMode == mode,
                        showCheckmark: false,
                        onSelected:
                            (_) => callbacks.onSettingsChanged?.call(
                              settings.copyWith(bodyMarginMode: mode),
                            ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReaderBodyMarginPreset.values
                    .map(
                      (preset) => ChoiceChip(
                        label: Text(_bodyMarginPresetLabel(preset)),
                        selected:
                            settings.bodyMarginMode ==
                                ReaderBodyMarginMode.preset &&
                            settings.bodyMarginPreset == preset,
                        showCheckmark: false,
                        onSelected:
                            (_) => callbacks.onSettingsChanged?.call(
                              settings.copyWith(
                                bodyMarginMode: ReaderBodyMarginMode.preset,
                                bodyMarginPreset: preset,
                              ),
                            ),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (settings.bodyMarginMode == ReaderBodyMarginMode.custom) ...[
                const SizedBox(height: 12),
                _ReaderSettingsSliderRow(
                  label: '上边距',
                  value: settings.bodyMarginTop,
                  min: ReaderSettings.minLayoutMargin,
                  max: ReaderSettings.maxLayoutMargin,
                  divisions: 20,
                  valueLabel: settings.bodyMarginTop.toStringAsFixed(0),
                  onChanged:
                      (value) => callbacks.onSettingsChanged?.call(
                        settings.copyWith(
                          bodyMarginMode: ReaderBodyMarginMode.custom,
                          bodyMarginTop: value,
                        ),
                      ),
                ),
                _ReaderSettingsSliderRow(
                  label: '下边距',
                  value: settings.bodyMarginBottom,
                  min: ReaderSettings.minLayoutMargin,
                  max: ReaderSettings.maxLayoutMargin,
                  divisions: 20,
                  valueLabel: settings.bodyMarginBottom.toStringAsFixed(0),
                  onChanged:
                      (value) => callbacks.onSettingsChanged?.call(
                        settings.copyWith(
                          bodyMarginMode: ReaderBodyMarginMode.custom,
                          bodyMarginBottom: value,
                        ),
                      ),
                ),
                _ReaderSettingsSliderRow(
                  label: '左边距',
                  value: settings.bodyMarginLeft,
                  min: ReaderSettings.minLayoutMargin,
                  max: ReaderSettings.maxLayoutMargin,
                  divisions: 20,
                  valueLabel: settings.bodyMarginLeft.toStringAsFixed(0),
                  onChanged:
                      (value) => callbacks.onSettingsChanged?.call(
                        settings.copyWith(
                          bodyMarginMode: ReaderBodyMarginMode.custom,
                          bodyMarginLeft: value,
                        ),
                      ),
                ),
                _ReaderSettingsSliderRow(
                  label: '右边距',
                  value: settings.bodyMarginRight,
                  min: ReaderSettings.minLayoutMargin,
                  max: ReaderSettings.maxLayoutMargin,
                  divisions: 20,
                  valueLabel: settings.bodyMarginRight.toStringAsFixed(0),
                  onChanged:
                      (value) => callbacks.onSettingsChanged?.call(
                        settings.copyWith(
                          bodyMarginMode: ReaderBodyMarginMode.custom,
                          bodyMarginRight: value,
                        ),
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChapterHeaderGroup(BuildContext context) {
    final settings = state.settings;
    return ListView(
      children: [
        _ReaderSettingsCard(
          title: '章节头',
          subtitle: '保留 preset 和位置微调。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReaderChapterHeaderPreset.values
                    .map(
                      (preset) => ChoiceChip(
                        label: Text(_chapterHeaderPresetLabel(preset)),
                        selected:
                            state.presetInput.selection.chapterHeader == preset,
                        showCheckmark: false,
                        onSelected:
                            (_) => callbacks.onChapterHeaderPresetSelected
                                ?.call(preset),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              _ReaderSettingsSliderRow(
                label: '横向位置',
                value: settings.pinnedChapterHeaderOffsetX,
                min: ReaderSettings.minPinnedHeaderOffsetX,
                max: ReaderSettings.maxPinnedHeaderOffsetX,
                divisions: 100,
                valueLabel: settings.pinnedChapterHeaderOffsetX.toStringAsFixed(
                  2,
                ),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(pinnedChapterHeaderOffsetX: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '纵向位置',
                value: settings.pinnedChapterHeaderOffsetY,
                min: ReaderSettings.minPinnedHeaderOffsetY,
                max: ReaderSettings.maxPinnedHeaderOffsetY,
                divisions:
                    (ReaderSettings.maxPinnedHeaderOffsetY -
                            ReaderSettings.minPinnedHeaderOffsetY)
                        .round(),
                valueLabel: settings.pinnedChapterHeaderOffsetY.toStringAsFixed(
                  0,
                ),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(pinnedChapterHeaderOffsetY: value),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBarGroup(BuildContext context) {
    final settings = state.settings;
    return ListView(
      children: [
        _ReaderSettingsCard(
          title: '信息栏',
          subtitle: '基础设置保留信息样式 preset，高级设置放 padding/margin 细调。',
          child: Column(
            children: [
              _ReaderSettingsToggleRow(
                label: '显示页眉',
                value: settings.infoHeaderEnabled,
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoHeaderEnabled: value),
                    ),
              ),
              _ReaderSettingsToggleRow(
                label: '显示页脚',
                value: settings.infoFooterEnabled,
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoFooterEnabled: value),
                    ),
              ),
              _ReaderSettingsToggleRow(
                label: '时间',
                value: settings.infoShowTime,
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoShowTime: value),
                    ),
              ),
              _ReaderSettingsToggleRow(
                label: '电量',
                value: settings.infoShowBattery,
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoShowBattery: value),
                    ),
              ),
              _ReaderSettingsToggleRow(
                label: '进度',
                value: settings.infoShowProgress,
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoShowProgress: value),
                    ),
              ),
              _ReaderSettingsToggleRow(
                label: '章节',
                value: settings.infoShowChapter,
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoShowChapter: value),
                    ),
              ),
              _ReaderSettingsToggleRow(
                label: '页眉分隔线',
                value: settings.infoHeaderDividerEnabled,
                onChanged:
                    settings.infoHeaderEnabled
                        ? (value) => callbacks.onSettingsChanged?.call(
                          settings.copyWith(infoHeaderDividerEnabled: value),
                        )
                        : null,
              ),
              _ReaderSettingsToggleRow(
                label: '页脚分隔线',
                value: settings.infoFooterDividerEnabled,
                onChanged:
                    settings.infoFooterEnabled
                        ? (value) => callbacks.onSettingsChanged?.call(
                          settings.copyWith(infoFooterDividerEnabled: value),
                        )
                        : null,
              ),
              const SizedBox(height: 8),
              _ReaderSettingsSliderRow(
                label: '页眉内边距',
                value: settings.infoHeaderPadding,
                min: ReaderSettings.minInfoBarPadding,
                max: ReaderSettings.maxInfoBarPadding,
                divisions: 24,
                valueLabel: settings.infoHeaderPadding.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoHeaderPadding: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '页脚内边距',
                value: settings.infoFooterPadding,
                min: ReaderSettings.minInfoBarPadding,
                max: ReaderSettings.maxInfoBarPadding,
                divisions: 24,
                valueLabel: settings.infoFooterPadding.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoFooterPadding: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '页眉上边距',
                value: settings.infoHeaderMarginTop,
                min: ReaderSettings.minLayoutMargin,
                max: ReaderSettings.maxLayoutMargin,
                divisions: 20,
                valueLabel: settings.infoHeaderMarginTop.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoHeaderMarginTop: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '页眉下边距',
                value: settings.infoHeaderMarginBottom,
                min: ReaderSettings.minLayoutMargin,
                max: ReaderSettings.maxLayoutMargin,
                divisions: 20,
                valueLabel: settings.infoHeaderMarginBottom.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoHeaderMarginBottom: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '页眉左边距',
                value: settings.infoHeaderMarginLeft,
                min: ReaderSettings.minLayoutMargin,
                max: ReaderSettings.maxLayoutMargin,
                divisions: 20,
                valueLabel: settings.infoHeaderMarginLeft.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoHeaderMarginLeft: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '页眉右边距',
                value: settings.infoHeaderMarginRight,
                min: ReaderSettings.minLayoutMargin,
                max: ReaderSettings.maxLayoutMargin,
                divisions: 20,
                valueLabel: settings.infoHeaderMarginRight.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoHeaderMarginRight: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '页脚上边距',
                value: settings.infoFooterMarginTop,
                min: ReaderSettings.minLayoutMargin,
                max: ReaderSettings.maxLayoutMargin,
                divisions: 20,
                valueLabel: settings.infoFooterMarginTop.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoFooterMarginTop: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '页脚下边距',
                value: settings.infoFooterMarginBottom,
                min: ReaderSettings.minLayoutMargin,
                max: ReaderSettings.maxLayoutMargin,
                divisions: 20,
                valueLabel: settings.infoFooterMarginBottom.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoFooterMarginBottom: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '页脚左边距',
                value: settings.infoFooterMarginLeft,
                min: ReaderSettings.minLayoutMargin,
                max: ReaderSettings.maxLayoutMargin,
                divisions: 20,
                valueLabel: settings.infoFooterMarginLeft.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoFooterMarginLeft: value),
                    ),
              ),
              _ReaderSettingsSliderRow(
                label: '页脚右边距',
                value: settings.infoFooterMarginRight,
                min: ReaderSettings.minLayoutMargin,
                max: ReaderSettings.maxLayoutMargin,
                divisions: 20,
                valueLabel: settings.infoFooterMarginRight.toStringAsFixed(0),
                onChanged:
                    (value) => callbacks.onSettingsChanged?.call(
                      settings.copyWith(infoFooterMarginRight: value),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisualGroup(BuildContext context) {
    final settings = state.settings;
    return ListView(
      children: [
        _ReaderSettingsCard(
          title: '视觉装饰',
          subtitle: '阶段 H 先将主题语义收口到唯一入口。',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReaderThemeMode.values
                .map(
                  (mode) => ChoiceChip(
                    label: Text(_themeModeLabel(mode)),
                    selected: settings.themeMode == mode,
                    showCheckmark: false,
                    onSelected:
                        (_) => callbacks.onSettingsChanged?.call(
                          settings.copyWith(themeMode: mode),
                        ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _ReaderSettingsCard extends StatelessWidget {
  const _ReaderSettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ReaderSettingsSummaryList extends StatelessWidget {
  const _ReaderSettingsSummaryList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(item, style: Theme.of(context).textTheme.bodyMedium),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ReaderSettingsToggleRow extends StatelessWidget {
  const _ReaderSettingsToggleRow({
    required this.label,
    required this.value,
    this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ReaderSettingsActionRow extends StatelessWidget {
  const _ReaderSettingsActionRow({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _ReaderSettingsSliderRow extends StatelessWidget {
  const _ReaderSettingsSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                valueLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

const List<ReaderSettingsSheetGroupDescriptor> _defaultGroupDescriptors = [
  ReaderSettingsSheetGroupDescriptor(
    key: ReaderSettingsSheetGroupKey.typography,
    title: '正文排版',
    subtitle: '字号、字距、行距、段距、缩进、字体与字重。',
  ),
  ReaderSettingsSheetGroupDescriptor(
    key: ReaderSettingsSheetGroupKey.bodyLayout,
    title: '正文版面',
    subtitle: '正文边距、留白与 margin preset/custom。',
  ),
  ReaderSettingsSheetGroupDescriptor(
    key: ReaderSettingsSheetGroupKey.chapterHeader,
    title: '章节头',
    subtitle: '章节头位置、显示策略与 pinned header 调整。',
  ),
  ReaderSettingsSheetGroupDescriptor(
    key: ReaderSettingsSheetGroupKey.infoBar,
    title: '信息栏',
    subtitle: '页眉页脚信息项、padding、margin 与 divider。',
  ),
  ReaderSettingsSheetGroupDescriptor(
    key: ReaderSettingsSheetGroupKey.visualDecoration,
    title: '视觉装饰',
    subtitle: '背景、文字效果、下划线、阴影与文字颜色。',
  ),
];

extension on ReaderSettingsSheetGroupDescriptor {
  String get storageKey {
    return readerSettingsSheetGroupStorageKey(key);
  }
}

String readerSettingsSheetGroupStorageKey(ReaderSettingsSheetGroupKey key) {
  return switch (key) {
    ReaderSettingsSheetGroupKey.typography => 'typography',
    ReaderSettingsSheetGroupKey.bodyLayout => 'body_layout',
    ReaderSettingsSheetGroupKey.chapterHeader => 'chapter_header',
    ReaderSettingsSheetGroupKey.infoBar => 'info_bar',
    ReaderSettingsSheetGroupKey.visualDecoration => 'visual_decoration',
  };
}

String _themeModeLabel(ReaderThemeMode mode) {
  return switch (mode) {
    ReaderThemeMode.light => '浅色',
    ReaderThemeMode.sepia => '护眼',
    ReaderThemeMode.dark => '深色',
  };
}

String _typographyPresetLabel(ReaderTypographyPreset preset) {
  return switch (preset) {
    ReaderTypographyPreset.md3Balanced => '均衡',
    ReaderTypographyPreset.md3Compact => '紧凑',
    ReaderTypographyPreset.md3Comfortable => '舒展',
  };
}

String _spacingPresetLabel(ReaderSpacingPreset preset) {
  return switch (preset) {
    ReaderSpacingPreset.compact => '紧凑',
    ReaderSpacingPreset.balanced => '均衡',
    ReaderSpacingPreset.relaxed => '舒展',
  };
}

String _fontPresetLabel(ReaderFontPreset preset) {
  return switch (preset) {
    ReaderFontPreset.systemSans => '系统默认',
    ReaderFontPreset.systemSerif => '衬线',
    ReaderFontPreset.systemMonospace => '等宽',
  };
}

String _fontWeightValueLabel(ReaderSettings settings) {
  final value =
      settings.fontWeightValue ??
      switch (settings.fontWeightLevel) {
        ReaderFontWeightLevel.light => 400,
        ReaderFontWeightLevel.regular => 500,
        ReaderFontWeightLevel.medium => 600,
      };
  return '$value';
}

String _chapterHeaderPresetLabel(ReaderChapterHeaderPreset preset) {
  return switch (preset) {
    ReaderChapterHeaderPreset.standard => '标准',
    ReaderChapterHeaderPreset.compact => '贴顶',
    ReaderChapterHeaderPreset.immersive => '沉浸',
  };
}

String _infoStylePresetLabel(ReaderInfoStylePreset preset) {
  return switch (preset) {
    ReaderInfoStylePreset.minimalFooter => '极简页脚',
    ReaderInfoStylePreset.balanced => '上下平衡',
    ReaderInfoStylePreset.readingFocused => '专注阅读',
  };
}

String _bodyMarginModeLabel(ReaderBodyMarginMode mode) {
  return switch (mode) {
    ReaderBodyMarginMode.preset => '预设',
    ReaderBodyMarginMode.custom => '自定义',
  };
}

String _bodyMarginPresetLabel(ReaderBodyMarginPreset preset) {
  return switch (preset) {
    ReaderBodyMarginPreset.compact => '紧凑',
    ReaderBodyMarginPreset.standard => '标准',
    ReaderBodyMarginPreset.relaxed => '舒展',
    ReaderBodyMarginPreset.immersive => '沉浸',
  };
}
