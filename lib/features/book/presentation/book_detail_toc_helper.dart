import 'package:flutter/material.dart';

import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/local_book_repository_impl.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../reader/application/local/txt_toc_rule_settings_service.dart';

class BookDetailTocContext {
  const BookDetailTocContext({
    required this.localBookMeta,
    required this.selectedTxtTocRule,
  });

  final LocalBook? localBookMeta;
  final TxtBookTocRuleSelection? selectedTxtTocRule;
}

class BookDetailTxtTocRuleSheetResult {
  const BookDetailTxtTocRuleSheetResult.select(this.rule)
    : clearSelection = false;
  const BookDetailTxtTocRuleSheetResult.clear()
    : rule = null,
      clearSelection = true;

  final TxtTocRuleState? rule;
  final bool clearSelection;
}

class BookDetailTocHelper {
  BookDetailTocHelper({
    required TxtTocRuleSettingsService txtTocRuleSettingsService,
  }) : _txtTocRuleSettingsService = txtTocRuleSettingsService,
       _localBookRepository = LocalBookRepositoryImpl(AppDatabase.instance);

  final TxtTocRuleSettingsService _txtTocRuleSettingsService;
  final LocalBookRepository _localBookRepository;

  Future<BookDetailTocContext> loadContext({
    required bool isLocalContent,
    required String activeBookId,
  }) async {
    if (!isLocalContent) {
      return const BookDetailTocContext(
        localBookMeta: null,
        selectedTxtTocRule: null,
      );
    }

    final localBook = await _localBookRepository.getBookById(activeBookId);
    final selection =
        localBook == null ||
                (localBook.txtTocRuleName?.trim().isEmpty ?? true) ||
                (localBook.txtTocRulePattern?.trim().isEmpty ?? true)
            ? null
            : TxtBookTocRuleSelection(
              ruleName: localBook.txtTocRuleName!.trim(),
              pattern: localBook.txtTocRulePattern!.trim(),
            );
    return BookDetailTocContext(
      localBookMeta: localBook,
      selectedTxtTocRule: selection,
    );
  }

  Future<BookDetailTxtTocRuleSheetResult?> showRuleSheet({
    required BuildContext context,
    required String activeBookId,
  }) async {
    final rules = await _txtTocRuleSettingsService.loadRules();
    final localBook = await _localBookRepository.getBookById(activeBookId);
    final currentSelection =
        localBook == null ||
                (localBook.txtTocRuleName?.trim().isEmpty ?? true) ||
                (localBook.txtTocRulePattern?.trim().isEmpty ?? true)
            ? null
            : TxtBookTocRuleSelection(
              ruleName: localBook.txtTocRuleName!.trim(),
              pattern: localBook.txtTocRulePattern!.trim(),
            );

    if (!context.mounted) {
      return null;
    }

    return showModalBottomSheet<BookDetailTxtTocRuleSheetResult>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final currentPattern = currentSelection?.pattern.trim() ?? '';
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            ListTile(
              leading: Icon(
                currentSelection == null
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
              ),
              title: const Text('自动探测'),
              subtitle: const Text('按全局启用规则自动选择最匹配的 TXT 目录规则。'),
              onTap:
                  () => Navigator.of(
                    context,
                  ).pop(const BookDetailTxtTocRuleSheetResult.clear()),
            ),
            const Divider(height: 1),
            for (final rule in rules) ...[
              ListTile(
                leading: Icon(
                  currentPattern == rule.pattern.trim()
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                title: Text(rule.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((rule.example ?? '').trim().isNotEmpty)
                      Text(
                        '示例：${rule.example!.trim()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      rule.enabled ? '全局自动识别：已启用' : '全局自动识别：未启用',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                isThreeLine: (rule.example ?? '').trim().isNotEmpty,
                onTap:
                    () => Navigator.of(
                      context,
                    ).pop(BookDetailTxtTocRuleSheetResult.select(rule)),
              ),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }

  Future<String?> applyRuleSheetResult({
    required String activeBookId,
    required BookDetailTxtTocRuleSheetResult selected,
  }) async {
    final latestBook = await _localBookRepository.getBookById(activeBookId);
    if (latestBook == null) {
      return null;
    }

    if (selected.clearSelection) {
      await _localBookRepository.upsertBook(
        latestBook.copyWith(
          clearTxtTocRuleName: true,
          clearTxtTocRulePattern: true,
          updatedAt: DateTime.now(),
        ),
      );
      return '已切换为自动探测目录规则。';
    }
    if (selected.rule != null) {
      await _localBookRepository.upsertBook(
        latestBook.copyWith(
          txtTocRuleName: selected.rule!.name,
          txtTocRulePattern: selected.rule!.pattern,
          updatedAt: DateTime.now(),
        ),
      );
      return '已切换目录规则：${selected.rule!.name}';
    }
    return null;
  }

  Future<bool?> toggleSplitLongChapter({required String activeBookId}) async {
    final localBook = await _localBookRepository.getBookById(activeBookId);
    if (localBook == null) {
      return null;
    }

    final nextValue = !localBook.splitLongChapter;
    await _localBookRepository.upsertBook(
      localBook.copyWith(
        splitLongChapter: nextValue,
        updatedAt: DateTime.now(),
      ),
    );
    return nextValue;
  }

  List<Chapter> buildDisplayedChapters(List<Chapter> chapters, bool reversed) {
    if (!reversed) {
      return chapters;
    }
    return chapters.reversed.toList(growable: false);
  }
}
