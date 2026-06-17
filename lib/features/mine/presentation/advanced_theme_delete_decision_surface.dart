import 'package:flutter/material.dart';

import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../application/advanced_theme_resource_reference_service.dart';
import '../application/advanced_theme_service.dart';
import 'advanced_theme_list_actions.dart';

Future<AdvancedThemeDeleteDecision?> showAdvancedThemeDeleteDecisionSurface({
  required BuildContext context,
  required AppAdvancedTheme theme,
  required AdvancedThemeDeletePreview preview,
}) {
  return showAdaptiveActionSurface<AdvancedThemeDeleteDecision>(
    context: context,
    maxWidth: 640,
    maxHeightFactor: 0.86,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final selections = <AdvancedThemeDeleteOptionKind, bool>{
        for (final section in preview.sections)
          section.kind: section.defaultSelected,
      };
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              0,
              0,
              MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '删除高级主题',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '即将删除「${theme.name}」。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (preview.sections.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final section in preview.sections) ...[
                      Builder(
                        builder: (context) {
                          final selected = selections[section.kind] ?? false;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color:
                                  selected
                                      ? colorScheme.primaryContainer.withValues(
                                        alpha: 0.26,
                                      )
                                      : colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    selected
                                        ? colorScheme.primary.withValues(
                                          alpha: 0.42,
                                        )
                                        : colorScheme.outlineVariant.withValues(
                                          alpha: 0.45,
                                        ),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setSheetState(() {
                                    selections[section.kind] = !selected;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    10,
                                  ),
                                  child: Row(
                                    children: [
                                      AppSelectionIndicator(
                                        selected: selected,
                                        semanticLabel:
                                            selected ? '已选择删除项' : '未选择删除项',
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          section.title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              () => Navigator.of(sheetContext).pop(
                                const AdvancedThemeDeleteDecision(
                                  confirmed: false,
                                  deleteOptions:
                                      AdvancedThemeDeleteOptions.none(),
                                ),
                              ),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(
                              AdvancedThemeDeleteDecision(
                                confirmed: true,
                                deleteOptions: AdvancedThemeDeleteOptions(
                                  deleteAppearanceWallpapers:
                                      selections[AdvancedThemeDeleteOptionKind
                                          .appearanceWallpapers] ??
                                      false,
                                  deleteReaderWallpapers:
                                      selections[AdvancedThemeDeleteOptionKind
                                          .readerWallpapers] ??
                                      false,
                                  deleteCoverGalleries:
                                      selections[AdvancedThemeDeleteOptionKind
                                          .coverGalleries] ??
                                      false,
                                  deleteLaunchImageGallery:
                                      selections[AdvancedThemeDeleteOptionKind
                                          .launchImageGallery] ??
                                      false,
                                  deleteBottomNavGallery:
                                      selections[AdvancedThemeDeleteOptionKind
                                          .bottomNavGallery] ??
                                      false,
                                  deleteFonts:
                                      selections[AdvancedThemeDeleteOptionKind
                                          .fonts] ??
                                      false,
                                ),
                              ),
                            );
                          },
                          child: const Text('删除'),
                        ),
                      ),
                    ],
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
