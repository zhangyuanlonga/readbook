import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/app_status_state_card.dart';
import '../application/advanced_theme_provider.dart';
import '../../reader/application/local/txt_chapter_rule_service.dart';

class ChapterRuleManagementPage extends StatefulWidget {
  const ChapterRuleManagementPage({
    super.key,
    this.loadTimeout = const Duration(seconds: 8),
  });

  final Duration loadTimeout;

  @override
  State<ChapterRuleManagementPage> createState() =>
      _ChapterRuleManagementPageState();
}

class _ChapterRuleManagementPageState extends State<ChapterRuleManagementPage> {
  late final TxtChapterRuleService _ruleService;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadErrorText;
  List<TxtChapterRule> _rules = const <TxtChapterRule>[];

  @override
  void initState() {
    super.initState();
    _ruleService = TxtChapterRuleService();
    _load();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadErrorText = null;
      });
    }

    try {
      final rules = await _ruleService.loadRules().timeout(widget.loadTimeout);
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorText = null;
        _rules = rules;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorText = '分章规则加载超时，请重试。';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorText = '分章规则加载失败，请重试。';
      });
    }
  }

  Future<void> _showRuleEditor({TxtChapterRule? initialRule}) async {
    final result = await showModalBottomSheet<_RuleEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      requestFocus: false,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.5;
        var name = initialRule?.name ?? '';
        var pattern = initialRule?.pattern ?? '';
        var sample = initialRule?.example ?? '';
        var enabled = initialRule?.enabled ?? true;
        String? nameError;
        String? patternError;

        _RuleDebugState buildDebugState() {
          final normalizedPattern = pattern.trim();
          final normalizedSample = sample.trim();
          if (normalizedPattern.isEmpty) {
            return const _RuleDebugState(message: '输入正则后，这里会显示命中结果。');
          }
          try {
            final expression = RegExp(
              normalizedPattern,
              multiLine: true,
              caseSensitive: false,
            );
            if (normalizedSample.isEmpty) {
              return const _RuleDebugState(message: '输入调试文本后即可验证规则。');
            }
            final matches = expression
                .allMatches(normalizedSample)
                .map((match) => match.group(0)?.trim() ?? '')
                .where((item) => item.isNotEmpty)
                .take(5)
                .toList(growable: false);
            if (matches.isEmpty) {
              return const _RuleDebugState(message: '当前规则未命中调试文本。');
            }
            return _RuleDebugState(
              message: '已命中 ${matches.length} 处',
              matches: matches,
            );
          } catch (_) {
            return const _RuleDebugState(error: '正则表达式格式不正确。');
          }
        }

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final debugState = buildDebugState();

            void submit() {
              final nextName = name.trim();
              final nextPattern = pattern.trim();
              String? nextNameError;
              String? nextPatternError;

              if (nextName.isEmpty) {
                nextNameError = '请输入规则名称';
              }
              if (nextPattern.isEmpty) {
                nextPatternError = '请输入正则表达式';
              } else {
                try {
                  RegExp(nextPattern, multiLine: true, caseSensitive: false);
                } catch (_) {
                  nextPatternError = '正则表达式格式不正确';
                }
              }

              if (nextNameError != null || nextPatternError != null) {
                setSheetState(() {
                  nameError = nextNameError;
                  patternError = nextPatternError;
                });
                return;
              }

              Navigator.of(sheetContext).pop(
                _RuleEditorResult.save(
                  TxtChapterRule(
                    id: initialRule?.id ?? _ruleService.buildRuleId(),
                    name: nextName,
                    pattern: nextPattern,
                    enabled: enabled,
                    example: sample.trim().isEmpty ? null : sample.trim(),
                  ),
                ),
              );
            }

            return SizedBox(
              height: sheetHeight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      initialRule == null ? '新增规则' : '编辑规则',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              initialValue: name,
                              autofocus: false,
                              decoration: InputDecoration(
                                labelText: '规则名称',
                                errorText: nameError,
                              ),
                              onChanged: (value) {
                                name = value;
                                if (nameError != null) {
                                  setSheetState(() {
                                    nameError = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: pattern,
                              minLines: 2,
                              maxLines: 4,
                              autofocus: false,
                              decoration: InputDecoration(
                                labelText: '正则表达式',
                                helperText: '按多行模式匹配章节标题',
                                errorText: patternError,
                              ),
                              onChanged: (value) {
                                pattern = value;
                                if (patternError != null) {
                                  setSheetState(() {
                                    patternError = null;
                                  });
                                } else {
                                  setSheetState(() {});
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: sample,
                              minLines: 4,
                              maxLines: 6,
                              autofocus: false,
                              decoration: const InputDecoration(
                                labelText: '调试文本',
                                helperText: '新增和编辑时直接在这里调试规则效果',
                              ),
                              onChanged: (value) {
                                sample = value;
                                setSheetState(() {});
                              },
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: enabled,
                              title: const Text('启用规则'),
                              onChanged: (value) {
                                setSheetState(() {
                                  enabled = value;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildDebugCard(sheetContext, debugState),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (initialRule != null) ...[
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(
                                  sheetContext,
                                ).pop(_RuleEditorResult.delete(initialRule));
                              },
                              child: const Text('删除'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: submit,
                            child: Text(initialRule == null ? '新增' : '保存'),
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

    if (result == null || !mounted) {
      return;
    }

    if (result.deleteTarget != null) {
      await _deleteRule(result.deleteTarget!);
      return;
    }

    final saved = result.savedRule;
    if (saved == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      await _ruleService.upsertRule(saved);
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage(saved.id == initialRule?.id ? '规则已保存。' : '规则已新增。');
    } catch (_) {
      _showMessage('规则保存失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteRule(TxtChapterRule rule) async {
    setState(() {
      _isSaving = true;
    });
    try {
      await _ruleService.deleteRule(rule.id);
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage('规则已删除。');
    } catch (_) {
      _showMessage('删除失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final activeAdvancedTheme =
            ref.watch(activeAdvancedThemeProvider).valueOrNull;
        final backdrop = resolveAdvancedThemeBackdrop(
          Theme.of(context).colorScheme,
          activeAdvancedTheme,
        );
        final horizontal = AppSpacing.pageHorizontal(context);
        final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
        final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

        return PopScope<void>(
          canPop: context.canPop(),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !context.mounted) {
              return;
            }
            context.go('/mine');
          },
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('分章规则'),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _isSaving ? null : () => unawaited(_showRuleEditor()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('新增规则'),
            ),
            body: LayoutBuilder(
              builder: (context, _) {
                final maxWidth = AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: AppLayout.settingsContentMaxWidth,
                );

                return DecoratedBox(
                  decoration: buildAdvancedThemeBackdropDecoration(backdrop),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView(
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  topInset + 12,
                                  horizontal,
                                  96 + bottomSafe,
                                ),
                                children: [
                                  if (_loadErrorText != null) ...[
                                    _buildErrorCard(
                                      context,
                                      _loadErrorText!,
                                      onRetry:
                                          () => unawaited(
                                            _load(showLoading: true),
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (_rules.isEmpty)
                                    AppEmptyStateCard(
                                      icon: Icons.rule_folder_outlined,
                                      title: '还没有规则',
                                      description: '点击右下角新增即可。',
                                      compact: true,
                                    )
                                  else
                                    Column(
                                      children: [
                                        for (
                                          var index = 0;
                                          index < _rules.length;
                                          index++
                                        ) ...[
                                          _buildRuleTile(
                                            context,
                                            _rules[index],
                                          ),
                                          if (index < _rules.length - 1)
                                            const SizedBox(height: 10),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRuleTile(BuildContext context, TxtChapterRule rule) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap:
          _isSaving
              ? null
              : () => unawaited(_showRuleEditor(initialRule: rule)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow.withValues(
            alpha: rule.enabled ? 1 : 0.75,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.36),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rule.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    rule.enabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (rule.example ?? '').trim().isNotEmpty
                  ? rule.example!.trim()
                  : '未填写示例章节名',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugCard(BuildContext context, _RuleDebugState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasError = state.error != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color:
            hasError
                ? colorScheme.errorContainer.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              hasError
                  ? colorScheme.error.withValues(alpha: 0.25)
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '即时调试',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            state.error ?? state.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color:
                  hasError
                      ? colorScheme.onErrorContainer
                      : colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (state.matches.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final match in state.matches)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $match',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    return AppStatusStateCard(
      icon: Icons.error_outline_rounded,
      title: '加载失败',
      message: message,
      tone: AppStatusStateTone.error,
      actionLabel: onRetry == null ? null : '重试',
      onAction: onRetry,
      compact: true,
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RuleEditorResult {
  const _RuleEditorResult._({this.savedRule, this.deleteTarget});

  const _RuleEditorResult.save(TxtChapterRule rule) : this._(savedRule: rule);

  const _RuleEditorResult.delete(TxtChapterRule rule)
    : this._(deleteTarget: rule);

  final TxtChapterRule? savedRule;
  final TxtChapterRule? deleteTarget;
}

class _RuleDebugState {
  const _RuleDebugState({
    this.message = '',
    this.matches = const <String>[],
    this.error,
  });

  final String message;
  final List<String> matches;
  final String? error;
}
