import 'dart:async';

// UI-GOV-EXEMPT-FILE: list-performance
// reason: Phase 10 reviewed this Reader settings sheet; bounded shrinkWrap is deferred to Phase 12 sheet migration.

import 'package:flutter/material.dart';

import '../../../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../../../app/widgets/foundation/app_button.dart';
import '../../../../../domain/entities/reader_settings.dart';

Future<void> showReaderTapZoneEditorSheet({
  required BuildContext context,
  required Color backgroundColor,
  required List<ReaderTapZoneAction> actions,
  required ValueChanged<List<ReaderTapZoneAction>> onChanged,
}) {
  return showAdaptiveActionSurface<void>(
    context: context,
    mobileBackgroundColor: backgroundColor,
    showDragHandle: true,
    maxWidth: 520,
    padding: EdgeInsets.zero,
    builder:
        (surfaceContext) =>
            ReaderTapZoneEditorContent(actions: actions, onChanged: onChanged),
  );
}

String readerTapZoneActionLabel(ReaderTapZoneAction action) {
  return switch (action) {
    ReaderTapZoneAction.previousPage => '上一页',
    ReaderTapZoneAction.nextPage => '下一页',
    ReaderTapZoneAction.toggleToolbar => '工具栏',
    ReaderTapZoneAction.catalog => '目录',
    ReaderTapZoneAction.autoRead => '自动阅读',
    ReaderTapZoneAction.bookmark => '灵感',
    ReaderTapZoneAction.nightMode => '夜间模式',
    ReaderTapZoneAction.none => '无操作',
  };
}

IconData readerTapZoneActionIcon(ReaderTapZoneAction action) {
  return switch (action) {
    ReaderTapZoneAction.previousPage => Icons.chevron_left_rounded,
    ReaderTapZoneAction.nextPage => Icons.chevron_right_rounded,
    ReaderTapZoneAction.toggleToolbar => Icons.tune_rounded,
    ReaderTapZoneAction.catalog => Icons.list_alt_outlined,
    ReaderTapZoneAction.autoRead => Icons.play_circle_outline_rounded,
    ReaderTapZoneAction.bookmark => Icons.bookmark_outline_rounded,
    ReaderTapZoneAction.nightMode => Icons.dark_mode_rounded,
    ReaderTapZoneAction.none => Icons.block_rounded,
  };
}

class ReaderTapZoneEditorContent extends StatefulWidget {
  const ReaderTapZoneEditorContent({
    super.key,
    required this.actions,
    required this.onChanged,
  });

  final List<ReaderTapZoneAction> actions;
  final ValueChanged<List<ReaderTapZoneAction>> onChanged;

  @override
  State<ReaderTapZoneEditorContent> createState() =>
      _ReaderTapZoneEditorContentState();
}

class _ReaderTapZoneEditorContentState
    extends State<ReaderTapZoneEditorContent> {
  late List<ReaderTapZoneAction> _localActions = _normalizeActions(
    widget.actions,
  );

  static List<ReaderTapZoneAction> _normalizeActions(
    List<ReaderTapZoneAction> actions,
  ) {
    final normalized = List<ReaderTapZoneAction>.from(actions);
    while (normalized.length < 9) {
      normalized.add(
        ReaderSettings.defaultTapZoneActions[normalized.length.clamp(0, 8)],
      );
    }
    if (normalized.length > 9) {
      return normalized.take(9).toList(growable: false);
    }
    return normalized;
  }

  Future<void> _editCell(BuildContext context, int index) async {
    final selected = await showAdaptiveActionSurface<ReaderTapZoneAction>(
      context: context,
      showDragHandle: true,
      maxWidth: 420,
      builder:
          (menuContext) => Column(
            mainAxisSize: MainAxisSize.min,
            children: ReaderTapZoneAction.values
                .map(
                  (action) => ListTile(
                    leading: Icon(readerTapZoneActionIcon(action)),
                    title: Text(readerTapZoneActionLabel(action)),
                    trailing:
                        _localActions[index] == action
                            ? const Icon(Icons.check_rounded)
                            : null,
                    onTap: () => Navigator.of(menuContext).pop(action),
                  ),
                )
                .toList(growable: false),
          ),
    );
    if (selected == null || !mounted) {
      return;
    }
    final nextActions = List<ReaderTapZoneAction>.from(_localActions);
    nextActions[index] = selected;
    setState(() {
      _localActions = nextActions;
    });
    widget.onChanged(nextActions);
  }

  void _restoreDefaults() {
    final nextActions = List<ReaderTapZoneAction>.from(
      ReaderSettings.defaultTapZoneActions,
    );
    setState(() {
      _localActions = nextActions;
    });
    widget.onChanged(nextActions);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '点击分区',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '首次安装后只提示一次，后续可在这里调整 3×3 点击动作。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              itemCount: 9,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.18,
              ),
              itemBuilder: (context, index) {
                final action = _localActions[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => unawaited(_editCell(context, index)),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(readerTapZoneActionIcon(action), size: 18),
                        const SizedBox(height: 6),
                        Text(
                          readerTapZoneActionLabel(action),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: _restoreDefaults,
                  label: '恢复默认',
                ),
                const Spacer(),
                AppButton(
                  onPressed: () => Navigator.of(context).pop(),
                  label: '完成',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
