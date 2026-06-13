import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/layout/app_adaptive.dart';
import '../../../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../../../app/widgets/import_export_task_overlay.dart';
import '../../../../../domain/entities/reader_settings.dart';
import '../../../application/reader_font_registry_service.dart';

typedef ReaderFontImportCallback =
    Future<ReaderCustomFontEntry?> Function(
      ValueChanged<ImportExportTaskStatus> onInlineStatus,
    );

Future<void> showReaderFontPickerSheet({
  required BuildContext context,
  required ReaderSettings settings,
  required List<ReaderCustomFontEntry> availableCustomFonts,
  required ValueChanged<ReaderSettings> onChanged,
  required ReaderFontImportCallback onImportCustomFont,
  required Future<void> Function() onManageFonts,
}) {
  return showAdaptiveActionSurface<void>(
    context: context,
    maxWidth: 560,
    maxHeightFactor: 0.72,
    padding: EdgeInsets.zero,
    builder:
        (sheetContext) => ReaderFontPickerSheetContent(
          settings: settings,
          availableCustomFonts: availableCustomFonts,
          onChanged: onChanged,
          onImportCustomFont: onImportCustomFont,
          onClose: () => Navigator.of(sheetContext).pop(),
          onManageFonts: () async {
            Navigator.of(sheetContext).pop();
            await onManageFonts();
          },
        ),
  );
}

ReaderCustomFontEntry? resolveReaderSelectedCustomFont(
  ReaderSettings settings,
  List<ReaderCustomFontEntry> availableCustomFonts,
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

String readerSystemFontPresetLabel(ReaderSystemFontPreset preset) {
  return switch (preset) {
    ReaderSystemFontPreset.defaultSans => '默认',
    ReaderSystemFontPreset.serif => '衬线',
    ReaderSystemFontPreset.monospace => '等宽',
  };
}

String readerCurrentFontLabel(
  ReaderSettings settings,
  List<ReaderCustomFontEntry> availableCustomFonts,
) {
  final selectedCustomFont = resolveReaderSelectedCustomFont(
    settings,
    availableCustomFonts,
  );
  if (selectedCustomFont != null) {
    return selectedCustomFont.displayName;
  }
  return readerSystemFontPresetLabel(settings.systemFontPreset);
}

class ReaderFontPickerSheetContent extends StatefulWidget {
  const ReaderFontPickerSheetContent({
    super.key,
    required this.settings,
    required this.availableCustomFonts,
    required this.onChanged,
    required this.onImportCustomFont,
    required this.onClose,
    required this.onManageFonts,
  });

  final ReaderSettings settings;
  final List<ReaderCustomFontEntry> availableCustomFonts;
  final ValueChanged<ReaderSettings> onChanged;
  final ReaderFontImportCallback onImportCustomFont;
  final VoidCallback onClose;
  final Future<void> Function() onManageFonts;

  @override
  State<ReaderFontPickerSheetContent> createState() =>
      _ReaderFontPickerSheetContentState();
}

class _ReaderFontPickerSheetContentState
    extends State<ReaderFontPickerSheetContent> {
  bool _isImporting = false;
  ImportExportTaskStatus? _inlineImportStatus;

  Future<void> _selectSystemFont(ReaderSystemFontPreset preset) async {
    widget.onChanged(
      widget.settings.copyWith(
        fontSource: ReaderFontSource.system,
        systemFontPreset: preset,
        clearFontFamilyKey: true,
        clearCustomFontPath: true,
      ),
    );
    widget.onClose();
  }

  Future<void> _selectCustomFont(ReaderCustomFontEntry entry) async {
    widget.onChanged(
      widget.settings.copyWith(
        fontSource: ReaderFontSource.custom,
        fontFamilyKey: entry.fontFamilyKey,
        customFontPath: entry.filePath,
      ),
    );
    widget.onClose();
  }

  Future<void> _importCustomFont() async {
    if (_isImporting) {
      return;
    }
    setState(() {
      _isImporting = true;
      _inlineImportStatus = const ImportExportTaskStatus(
        title: '正在导入字体',
        message: '正在选择并注册字体到阅读设置…',
        presentation: ImportExportTaskPresentation.inlineCompact,
      );
    });

    final imported = await widget.onImportCustomFont((status) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineImportStatus = status;
      });
    });
    if (!mounted) {
      return;
    }
    setState(() {
      _isImporting = false;
      _inlineImportStatus =
          imported == null
              ? _inlineImportStatus
              : ImportExportTaskStatus(
                title: '字体导入完成',
                message: '已完成字体注册，正在应用到阅读设置…',
                detail: imported.displayName,
                progress: 1,
                presentation: ImportExportTaskPresentation.inlineCompact,
                result: ImportExportTaskResult.success,
              );
    });
    if (imported != null) {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCustomFont = resolveReaderSelectedCustomFont(
      widget.settings,
      widget.availableCustomFonts,
    );
    final children = <Widget>[
      _ReaderFontChoiceTile(
        label: readerSystemFontPresetLabel(ReaderSystemFontPreset.defaultSans),
        selected:
            widget.settings.fontSource == ReaderFontSource.system &&
            widget.settings.systemFontPreset ==
                ReaderSystemFontPreset.defaultSans,
        icon: Icons.font_download_outlined,
        onTap: () => _selectSystemFont(ReaderSystemFontPreset.defaultSans),
      ),
      _ReaderFontChoiceTile(
        label: readerSystemFontPresetLabel(ReaderSystemFontPreset.serif),
        selected:
            widget.settings.fontSource == ReaderFontSource.system &&
            widget.settings.systemFontPreset == ReaderSystemFontPreset.serif,
        icon: Icons.format_shapes_rounded,
        onTap: () => _selectSystemFont(ReaderSystemFontPreset.serif),
      ),
      _ReaderFontChoiceTile(
        label: readerSystemFontPresetLabel(ReaderSystemFontPreset.monospace),
        selected:
            widget.settings.fontSource == ReaderFontSource.system &&
            widget.settings.systemFontPreset ==
                ReaderSystemFontPreset.monospace,
        icon: Icons.code_rounded,
        onTap: () => _selectSystemFont(ReaderSystemFontPreset.monospace),
      ),
      ...widget.availableCustomFonts.map(
        (entry) => _ReaderFontChoiceTile(
          label: entry.displayName,
          selected: selectedCustomFont?.fontFamilyKey == entry.fontFamilyKey,
          icon: Icons.font_download_outlined,
          onTap: () => _selectCustomFont(entry),
        ),
      ),
      _ReaderFontChoiceTile(
        label: '自定义',
        selected: false,
        loading: _isImporting,
        icon: Icons.upload_file_rounded,
        onTap: _importCustomFont,
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '支持默认、衬线、等宽和自定义字体。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (_inlineImportStatus != null) ...[
              ImportExportInlineStatus(status: _inlineImportStatus!),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => unawaited(widget.onManageFonts()),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('去我的管理字体'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridMetrics = AppAdaptiveMetrics.resolveForConstraints(
                    context,
                    constraints,
                  );
                  final columns = gridMetrics.gridColumnsFor(
                    availableWidth: constraints.maxWidth,
                    minItemWidth: 136,
                    minColumns: 2,
                    maxColumns: 4,
                    spacing: gridMetrics.contentGap,
                  );
                  return GridView.count(
                    crossAxisCount: columns,
                    crossAxisSpacing: gridMetrics.contentGap,
                    mainAxisSpacing: gridMetrics.contentGap,
                    childAspectRatio: gridMetrics.isCompactDensity ? 2.1 : 2.35,
                    children: children,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderFontChoiceTile extends StatelessWidget {
  const _ReaderFontChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.loading = false,
  });

  final String label;
  final bool selected;
  final Future<void> Function()? onTap;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap == null ? null : () => unawaited(onTap!()),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color:
                selected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerLow,
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary.withValues(alpha: 0.45)
                      : colorScheme.outlineVariant.withValues(alpha: 0.35),
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
              if (icon != null || loading) const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color:
                        selected
                            ? colorScheme.onPrimaryContainer
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
}
