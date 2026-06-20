// UI-GOV-EXEMPT-FILE: list-performance
// reason: Phase 10 reviewed this Reader settings section; bounded shrinkWrap is deferred to Phase 12 sheet migration.

import 'package:flutter/material.dart';

import '../../../../../domain/entities/reader_settings.dart';
import '../../../application/reader_mode_model.dart';
import 'reader_settings_components.dart';
import 'reader_tap_zone_editor_sheet.dart';

class ReaderInlinePageAnimationSelector extends StatelessWidget {
  const ReaderInlinePageAnimationSelector({
    super.key,
    required this.settings,
    required this.pageAnimationLabel,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final String Function(ReaderPageAnimationStyle style) pageAnimationLabel;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    const animationStyles = <ReaderPageAnimationStyle>[
      ReaderPageAnimationStyle.paperCurl,
      ReaderPageAnimationStyle.curl,
      ReaderPageAnimationStyle.cover,
      ReaderPageAnimationStyle.translate,
      ReaderPageAnimationStyle.fade,
      ReaderPageAnimationStyle.none,
    ];

    void applyTextPresentationMode({
      required bool useScrollLayout,
      ReaderPageAnimationStyle? style,
    }) {
      onChanged(
        settings.copyWith(
          pageTurnMode:
              useScrollLayout
                  ? ReaderPageTurnMode.scroll
                  : ReaderPageTurnMode.tapAndSwipe,
          pageAnimationStyle: style ?? settings.pageAnimationStyle,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...animationStyles.map(
            (style) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: pageAnimationLabel(style),
                child: ChoiceChip(
                  label: Text(pageAnimationLabel(style)),
                  selected:
                      !settings.pageTurnMode.usesScrollLayout &&
                      settings.pageAnimationStyle == style,
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('滚动'),
              selected: settings.pageTurnMode.usesScrollLayout,
              showCheckmark: false,
              onSelected: (_) {
                applyTextPresentationMode(useScrollLayout: true);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderPageTurnInteractionSettingsPanel extends StatelessWidget {
  const ReaderPageTurnInteractionSettingsPanel({
    super.key,
    required this.settings,
    required this.compactScale,
    required this.onChanged,
    required this.isVolumeKeyPagingSupported,
    required this.onOpenTapZoneEditor,
  });

  final ReaderSettings settings;
  final double compactScale;
  final ValueChanged<ReaderSettings> onChanged;
  final bool isVolumeKeyPagingSupported;
  final VoidCallback onOpenTapZoneEditor;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsCard(
      compactScale: compactScale,
      children: [
        ReaderSettingsCompactTitle(title: '排版对齐', compactScale: compactScale),
        const SizedBox(height: 10),
        ReaderSettingsToggleRow(
          label: '文字两端对齐',
          value: settings.textFullJustifyEnabled,
          compactScale: compactScale,
          onChanged:
              (enabled) =>
                  onChanged(settings.copyWith(textFullJustifyEnabled: enabled)),
        ),
        ReaderSettingsDivider(compactScale: compactScale),
        ReaderSettingsToggleRow(
          label: '文字底部对齐',
          value: settings.textBottomJustifyEnabled,
          compactScale: compactScale,
          onChanged:
              settings.pageTurnMode.usesScrollLayout
                  ? null
                  : (enabled) => onChanged(
                    settings.copyWith(textBottomJustifyEnabled: enabled),
                  ),
        ),
        if (settings.pageTurnMode.usesScrollLayout) ...[
          const SizedBox(height: 4),
          Text(
            '底部对齐仅在分页阅读下生效，滚动阅读不会分配页内剩余高度。',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        ReaderSettingsDivider(compactScale: compactScale),
        ReaderSettingsCompactTitle(title: '音量键翻页', compactScale: compactScale),
        const SizedBox(height: 10),
        ReaderSettingsToggleRow(
          label: '启用',
          value: settings.volumeKeyPageEnabled,
          compactScale: compactScale,
          onChanged:
              isVolumeKeyPagingSupported
                  ? (enabled) => onChanged(
                    settings.copyWith(volumeKeyPageEnabled: enabled),
                  )
                  : null,
        ),
        ReaderSettingsDivider(compactScale: compactScale),
        ReaderSettingsCompactTitle(title: '正文点击分区', compactScale: compactScale),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onOpenTapZoneEditor,
          icon: const Icon(Icons.grid_view_rounded, size: 16),
          label: const Text('编辑 3×3 分区'),
        ),
        const SizedBox(height: 8),
        _TapZonePreviewGrid(actions: settings.tapZoneActions),
      ],
    );
  }
}

class ReaderReadingBehaviorSettingsPanel extends StatelessWidget {
  const ReaderReadingBehaviorSettingsPanel({
    super.key,
    required this.settings,
    required this.compactScale,
    required this.onChanged,
    required this.isVolumeKeyPagingSupported,
    required this.volumeKeySupportDescription,
  });

  final ReaderSettings settings;
  final double compactScale;
  final ValueChanged<ReaderSettings> onChanged;
  final bool isVolumeKeyPagingSupported;
  final String volumeKeySupportDescription;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsSectionCard(
      icon: Icons.toggle_on_rounded,
      title: '快捷开关',
      compactScale: compactScale,
      children: [
        ReaderSettingsToggleRow(
          label: '文字两端对齐',
          value: settings.textFullJustifyEnabled,
          compactScale: compactScale,
          onChanged:
              (enabled) =>
                  onChanged(settings.copyWith(textFullJustifyEnabled: enabled)),
        ),
        ReaderSettingsDivider(compactScale: compactScale),
        ReaderSettingsToggleRow(
          label: '音量键翻页',
          value: settings.volumeKeyPageEnabled,
          compactScale: compactScale,
          onChanged:
              isVolumeKeyPagingSupported
                  ? (enabled) => onChanged(
                    settings.copyWith(volumeKeyPageEnabled: enabled),
                  )
                  : null,
        ),
        if (!isVolumeKeyPagingSupported) ...[
          const SizedBox(height: 4),
          Text(
            volumeKeySupportDescription,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _TapZonePreviewGrid extends StatelessWidget {
  const _TapZonePreviewGrid({required this.actions});

  final List<ReaderTapZoneAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 9,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.36),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(readerTapZoneActionIcon(action), size: 14),
              const SizedBox(height: 4),
              Text(
                readerTapZoneActionLabel(action),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
