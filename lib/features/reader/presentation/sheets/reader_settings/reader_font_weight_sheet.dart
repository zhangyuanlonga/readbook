import 'package:flutter/material.dart';

import '../../../../../app/layout/app_spacing.dart';
import '../../../../../domain/entities/reader_settings.dart';

typedef ReaderFloatingSettingsSheetFrameBuilder =
    Widget Function({
      required BuildContext context,
      required ThemeData readerModalTheme,
      required double keyboardInset,
      required double safeBottom,
      required double sheetHorizontal,
      required double maxWidth,
      required double heightFactor,
      required Widget child,
    });

Future<void> showReaderFontWeightSheet({
  required BuildContext context,
  required ThemeData readerModalTheme,
  required ReaderSettings settings,
  required ReaderFloatingSettingsSheetFrameBuilder frameBuilder,
  required double Function(BuildContext context) bottomSafeInset,
  required ValueChanged<ReaderSettings> onChanged,
}) {
  return _showReaderFloatingSettingsSubSheet(
    context: context,
    readerModalTheme: readerModalTheme,
    frameBuilder: frameBuilder,
    bottomSafeInset: bottomSafeInset,
    maxWidth: 560,
    heightFactor: 0.34,
    builder:
        (sheetContext) => ReaderFontWeightSheetContent(
          settings: settings,
          onChanged: onChanged,
        ),
  );
}

String readerFontWeightLevelLabel(ReaderFontWeightLevel level) {
  return switch (level) {
    ReaderFontWeightLevel.light => '细',
    ReaderFontWeightLevel.regular => '常规',
    ReaderFontWeightLevel.medium => '粗',
  };
}

int readerFontWeightValueForLevel(ReaderFontWeightLevel level) {
  return switch (level) {
    ReaderFontWeightLevel.light => 400,
    ReaderFontWeightLevel.regular => 500,
    ReaderFontWeightLevel.medium => 600,
  };
}

ReaderFontWeightLevel nearestReaderFontWeightLevel(int value) {
  if (value <= 450) {
    return ReaderFontWeightLevel.light;
  }
  if (value >= 550) {
    return ReaderFontWeightLevel.medium;
  }
  return ReaderFontWeightLevel.regular;
}

int effectiveReaderFontWeightValue(ReaderSettings settings) {
  return settings.fontWeightValue ??
      readerFontWeightValueForLevel(settings.fontWeightLevel);
}

String readerFontWeightDisplayLabel(ReaderSettings settings) {
  final value = effectiveReaderFontWeightValue(settings);
  final mappedLevel = nearestReaderFontWeightLevel(value);
  final presetValue = readerFontWeightValueForLevel(mappedLevel);
  if (value == presetValue) {
    return readerFontWeightLevelLabel(mappedLevel);
  }
  return '$value';
}

class ReaderFontWeightSheetContent extends StatefulWidget {
  const ReaderFontWeightSheetContent({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  State<ReaderFontWeightSheetContent> createState() =>
      _ReaderFontWeightSheetContentState();
}

class _ReaderFontWeightSheetContentState
    extends State<ReaderFontWeightSheetContent> {
  late ReaderSettings _settings = widget.settings;

  void _apply(ReaderSettings next) {
    setState(() {
      _settings = next;
    });
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = effectiveReaderFontWeightValue(_settings);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            '字重',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '当前 $currentValue',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    label: Text(readerFontWeightLevelLabel(level)),
                    selected:
                        currentValue == readerFontWeightValueForLevel(level),
                    onSelected: (_) {
                      _apply(
                        _settings.copyWith(
                          fontWeightLevel: level,
                          fontWeightValue: readerFontWeightValueForLevel(level),
                        ),
                      );
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
              _apply(
                _settings.copyWith(
                  fontWeightLevel: nearestReaderFontWeightLevel(normalized),
                  fontWeightValue: normalized,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _showReaderFloatingSettingsSubSheet({
  required BuildContext context,
  required ThemeData readerModalTheme,
  required ReaderFloatingSettingsSheetFrameBuilder frameBuilder,
  required double Function(BuildContext context) bottomSafeInset,
  required WidgetBuilder builder,
  double maxWidth = 680,
  double heightFactor = 0.5,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'reader-sub-sheet',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.03),
    pageBuilder: (dialogContext, _, __) {
      return Theme(
        data: readerModalTheme,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(dialogContext).pop(),
                child: const SizedBox.shrink(),
              ),
            ),
            Builder(
              builder: (sheetContext) {
                return frameBuilder(
                  context: sheetContext,
                  readerModalTheme: readerModalTheme,
                  keyboardInset: MediaQuery.viewInsetsOf(sheetContext).bottom,
                  safeBottom: bottomSafeInset(sheetContext),
                  sheetHorizontal: AppSpacing.pageHorizontal(sheetContext),
                  maxWidth: maxWidth,
                  heightFactor: heightFactor,
                  child: Material(
                    color: Colors.transparent,
                    child: builder(sheetContext),
                  ),
                );
              },
            ),
          ],
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
