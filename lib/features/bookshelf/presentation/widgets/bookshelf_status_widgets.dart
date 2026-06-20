import 'package:flutter/material.dart';

import '../../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../../app/widgets/app_empty_state_card.dart';
import '../../../../app/widgets/app_status_state_card.dart';
import '../../../../app/widgets/foundation/foundation.dart';

class BookshelfEmptyCard extends StatelessWidget {
  const BookshelfEmptyCard({
    super.key,
    required this.onImportLocal,
    required this.palette,
    this.showImportAction = true,
  });

  final VoidCallback onImportLocal;
  final ResolvedAdvancedThemePalette palette;
  final bool showImportAction;

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      icon: Icons.import_contacts_outlined,
      title: '书架暂无内容',
      description: '请先在搜索结果或详情页加入书架。',
      footer:
          showImportAction
              ? AppButton(
                label: '导入本地图书',
                icon: const Icon(Icons.library_add_rounded),
                onPressed: onImportLocal,
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(palette.primaryColor),
                  foregroundColor: WidgetStatePropertyAll(
                    _readableButtonForeground(palette.primaryColor),
                  ),
                ),
              )
              : null,
    );
  }
}

Color _readableButtonForeground(Color backgroundColor) {
  return ThemeData.estimateBrightnessForColor(backgroundColor) ==
          Brightness.dark
      ? Colors.white
      : Colors.black;
}

class BookshelfFilterEmptyCard extends StatelessWidget {
  const BookshelfFilterEmptyCard({
    super.key,
    required this.label,
    required this.palette,
    this.searchKeyword,
  });

  final String label;
  final ResolvedAdvancedThemePalette palette;
  final String? searchKeyword;

  @override
  Widget build(BuildContext context) {
    final normalizedKeyword = searchKeyword?.trim() ?? '';
    final hasSearchKeyword = normalizedKeyword.isNotEmpty;
    return AppEmptyStateCard(
      icon:
          hasSearchKeyword
              ? Icons.search_off_rounded
              : Icons.filter_alt_off_rounded,
      title: hasSearchKeyword ? '没有匹配书籍' : '当前分类暂无书籍',
      description:
          hasSearchKeyword
              ? '当前“$label”中没有匹配“$normalizedKeyword”的书籍'
              : '当前“$label”分类暂无书籍',
      compact: true,
    );
  }
}

class BookshelfLoadErrorCard extends StatelessWidget {
  const BookshelfLoadErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    required this.palette,
  });

  final String message;
  final VoidCallback onRetry;
  final ResolvedAdvancedThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return AppStatusStateCard(
      icon: Icons.error_outline_rounded,
      title: '书架加载失败',
      message: message,
      tone: AppStatusStateTone.error,
      footer: Align(
        alignment: Alignment.centerLeft,
        child: AppButton(
          label: '重试',
          variant: AppButtonVariant.tonal,
          onPressed: onRetry,
        ),
      ),
      compact: true,
    );
  }
}

class BookshelfContinueReadingPromptCard extends StatelessWidget {
  const BookshelfContinueReadingPromptCard({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 1.15),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: child,
        ),
      ),
    );
  }
}
