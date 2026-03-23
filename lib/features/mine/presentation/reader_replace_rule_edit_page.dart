import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/reader_replace_rule.dart';
import '../../reader/application/reader_replace_rule_executor.dart';
import '../../reader/application/reader_replace_rule_service.dart';

class ReaderReplaceRuleEditPage extends StatefulWidget {
  const ReaderReplaceRuleEditPage({super.key, this.ruleId});

  final int? ruleId;

  @override
  State<ReaderReplaceRuleEditPage> createState() =>
      _ReaderReplaceRuleEditPageState();
}

class _ReaderReplaceRuleEditPageState extends State<ReaderReplaceRuleEditPage> {
  final ReaderReplaceRuleService _service = ReaderReplaceRuleService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();
  final TextEditingController _patternController = TextEditingController();
  final TextEditingController _replacementController = TextEditingController();
  final TextEditingController _scopeController = TextEditingController();
  final TextEditingController _excludeScopeController = TextEditingController();
  final TextEditingController _timeoutController = TextEditingController();
  final TextEditingController _testTextController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _isEnabled = true;
  bool _isRegex = true;
  bool _scopeContent = true;
  bool _scopeTitle = false;
  ReaderReplaceRuleScopeMode _scopeMode = ReaderReplaceRuleScopeMode.all;
  String? _errorText;
  ReaderReplaceRuleTestResult? _testResult;
  int _ruleId = 0;
  DateTime? _createdAt;

  @override
  void initState() {
    super.initState();
    _loadRule();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    _patternController.dispose();
    _replacementController.dispose();
    _scopeController.dispose();
    _excludeScopeController.dispose();
    _timeoutController.dispose();
    _testTextController.dispose();
    super.dispose();
  }

  Future<void> _loadRule() async {
    final ruleId = widget.ruleId;
    if (ruleId == null || ruleId <= 0) {
      _timeoutController.text = '3000';
      _testTextController.text = '这里是一段测试正文，包含广告和推广语。';
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final rule = await _service.getById(ruleId);
    if (!mounted) {
      return;
    }

    if (rule == null) {
      setState(() {
        _isLoading = false;
        _errorText = '未找到对应的净化规则。';
      });
      return;
    }

    _ruleId = rule.id;
    _createdAt = rule.createdAt;
    _nameController.text = rule.name;
    _groupController.text = rule.group ?? '';
    _patternController.text = rule.pattern;
    _replacementController.text = rule.replacement;
    _scopeController.text = rule.scope ?? '';
    _excludeScopeController.text = rule.excludeScope ?? '';
    _timeoutController.text = rule.timeoutMs.toString();
    _testTextController.text = '这里是一段测试正文，包含广告和推广语。';
    _isEnabled = rule.isEnabled;
    _isRegex = rule.isRegex;
    _scopeContent = rule.scopeContent;
    _scopeTitle = rule.scopeTitle;
    _scopeMode = rule.scopeMode;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final pattern = _patternController.text.trim();
    final timeout = int.tryParse(_timeoutController.text.trim());

    if (name.isEmpty) {
      setState(() {
        _errorText = '规则名称不能为空。';
      });
      return;
    }
    if (pattern.isEmpty) {
      setState(() {
        _errorText = '匹配内容不能为空。';
      });
      return;
    }
    if (!_scopeContent && !_scopeTitle) {
      setState(() {
        _errorText = '标题或正文至少要选择一个作用目标。';
      });
      return;
    }
    if (_isRegex) {
      try {
        RegExp(pattern, dotAll: true);
      } catch (error) {
        setState(() {
          _errorText = '正则语法错误：$error';
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final now = DateTime.now();
    final rule = ReaderReplaceRule(
      id: _ruleId,
      name: name,
      group:
          _groupController.text.trim().isEmpty
              ? null
              : _groupController.text.trim(),
      pattern: pattern,
      replacement: _replacementController.text,
      scopeMode: _scopeMode,
      scope:
          _scopeController.text.trim().isEmpty
              ? null
              : _scopeController.text.trim(),
      excludeScope:
          _excludeScopeController.text.trim().isEmpty
              ? null
              : _excludeScopeController.text.trim(),
      scopeTitle: _scopeTitle,
      scopeContent: _scopeContent,
      isEnabled: _isEnabled,
      isRegex: _isRegex,
      timeoutMs: timeout ?? 3000,
      createdAt: _createdAt ?? now,
      updatedAt: now,
    );

    await _service.saveRule(rule);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
    });
    context.pop();
  }

  Future<void> _testRule() async {
    final pattern = _patternController.text.trim();
    if (pattern.isEmpty) {
      setState(() {
        _errorText = '请先填写匹配内容。';
      });
      return;
    }
    if (_isRegex) {
      try {
        RegExp(pattern, dotAll: true);
      } catch (error) {
        setState(() {
          _errorText = '正则语法错误：$error';
        });
        return;
      }
    }

    setState(() {
      _isTesting = true;
      _errorText = null;
      _testResult = null;
    });

    final rule = ReaderReplaceRule(
      id: _ruleId,
      name:
          _nameController.text.trim().isEmpty
              ? '未命名规则'
              : _nameController.text.trim(),
      group:
          _groupController.text.trim().isEmpty
              ? null
              : _groupController.text.trim(),
      pattern: pattern,
      replacement: _replacementController.text,
      scopeMode: _scopeMode,
      scope:
          _scopeController.text.trim().isEmpty
              ? null
              : _scopeController.text.trim(),
      excludeScope:
          _excludeScopeController.text.trim().isEmpty
              ? null
              : _excludeScopeController.text.trim(),
      scopeTitle: _scopeTitle,
      scopeContent: _scopeContent,
      isEnabled: _isEnabled,
      isRegex: _isRegex,
      timeoutMs: int.tryParse(_timeoutController.text.trim()) ?? 3000,
      createdAt: _createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final result = await _service.testRuleDetailed(
        rule: rule,
        text: _testTextController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _testResult = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '测试失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/reader-replace-rules');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.ruleId == null ? '新增净化规则' : '编辑净化规则'),
          actions: [
            TextButton(
              onPressed: _isLoading || _isSaving ? null : _save,
              child: const Text('保存'),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    12,
                    horizontal,
                    16 + bottomSafe,
                  ),
                  children: [
                    if (_isLoading)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: '规则名称',
                                  hintText: '例如：去章节尾广告',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _groupController,
                                decoration: const InputDecoration(
                                  labelText: '分组',
                                  hintText: '可选，例如：广告 / 排版',
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<
                                ReaderReplaceRuleScopeMode
                              >(
                                initialValue: _scopeMode,
                                decoration: const InputDecoration(
                                  labelText: '作用范围类型',
                                ),
                                items: ReaderReplaceRuleScopeMode.values
                                    .map(
                                      (mode) => DropdownMenuItem(
                                        value: mode,
                                        child: Text(_scopeModeLabel(mode)),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _scopeMode = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _scopeController,
                                decoration: const InputDecoration(
                                  labelText: '作用范围',
                                  hintText: '多项可用逗号、分号或换行分隔',
                                ),
                                minLines: 2,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _excludeScopeController,
                                decoration: const InputDecoration(
                                  labelText: '排除范围',
                                  hintText: '命中这些范围时不生效',
                                ),
                                minLines: 2,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _patternController,
                                decoration: const InputDecoration(
                                  labelText: '匹配内容',
                                  hintText: '普通文本或正则表达式',
                                ),
                                minLines: 4,
                                maxLines: 8,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _replacementController,
                                decoration: const InputDecoration(
                                  labelText: '替换内容',
                                  hintText: '为空时表示删除命中内容',
                                ),
                                minLines: 3,
                                maxLines: 6,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _timeoutController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '正则超时（毫秒）',
                                  hintText: '默认 3000',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Text('启用规则'),
                                    selected: _isEnabled,
                                    onSelected: (value) {
                                      setState(() {
                                        _isEnabled = value;
                                      });
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('正则替换'),
                                    selected: _isRegex,
                                    onSelected: (value) {
                                      setState(() {
                                        _isRegex = value;
                                      });
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('作用正文'),
                                    selected: _scopeContent,
                                    onSelected: (value) {
                                      setState(() {
                                        _scopeContent = value;
                                      });
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('作用标题'),
                                    selected: _scopeTitle,
                                    onSelected: (value) {
                                      setState(() {
                                        _scopeTitle = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_errorText != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _errorText!,
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '测试规则',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed:
                                        _isLoading || _isTesting
                                            ? null
                                            : _testRule,
                                    icon:
                                        _isTesting
                                            ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : const Icon(
                                              Icons.science_outlined,
                                            ),
                                    label: const Text('测试'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _testTextController,
                                decoration: const InputDecoration(
                                  labelText: '测试文本',
                                  hintText: '粘贴一段正文看看规则是否命中',
                                ),
                                minLines: 6,
                                maxLines: 10,
                              ),
                              const SizedBox(height: 12),
                              if (_testResult == null)
                                _buildEmptyTestState(context)
                              else
                                _buildTestResult(context, _testResult!),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _scopeModeLabel(ReaderReplaceRuleScopeMode mode) {
    return switch (mode) {
      ReaderReplaceRuleScopeMode.all => '全局',
      ReaderReplaceRuleScopeMode.bookTitle => '按书名',
      ReaderReplaceRuleScopeMode.sourceId => '按书源',
      ReaderReplaceRuleScopeMode.mixed => '混合作用域',
    };
  }

  Widget _buildEmptyTestState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        '点击上方“测试”，这里会显示命中状态，以及原文和替换后的结果对照。',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildTestResult(
    BuildContext context,
    ReaderReplaceRuleTestResult result,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusColor =
        result.hasMatch
            ? (result.hasChange ? colorScheme.primary : colorScheme.tertiary)
            : colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusChip(
              context,
              label: result.hasMatch ? '已命中' : '未命中',
              foregroundColor:
                  result.hasMatch
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
              backgroundColor:
                  result.hasMatch
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
            ),
            _buildStatusChip(
              context,
              label: result.hasChange ? '结果已变化' : '结果未变化',
              foregroundColor:
                  result.hasChange
                      ? colorScheme.onTertiaryContainer
                      : colorScheme.onSurfaceVariant,
              backgroundColor:
                  result.hasChange
                      ? colorScheme.tertiaryContainer
                      : colorScheme.surfaceContainerHighest,
            ),
            _buildStatusChip(
              context,
              label: '命中 ${result.matchCount} 处',
              foregroundColor: colorScheme.onSecondaryContainer,
              backgroundColor: colorScheme.secondaryContainer,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            _buildTestSummary(result),
            style: textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= AppLayout.settingsContentMaxWidth;
            final originalPanel = _buildResultPanel(
              context,
              title: '原文',
              subtitle: '测试前的文本',
              value: result.originalText,
              icon: Icons.article_outlined,
            );
            final resultPanel = _buildResultPanel(
              context,
              title: '结果',
              subtitle: result.hasChange ? '替换后的文本' : '替换后与原文一致',
              value: result.resultText,
              icon: Icons.auto_fix_high_outlined,
            );

            if (!wide) {
              return Column(
                children: [
                  originalPanel,
                  const SizedBox(height: 10),
                  resultPanel,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: originalPanel),
                const SizedBox(width: 12),
                Expanded(child: resultPanel),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildResultPanel(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            value.isEmpty ? '(空文本)' : value,
            style: textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context, {
    required String label,
    required Color foregroundColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _buildTestSummary(ReaderReplaceRuleTestResult result) {
    if (!result.hasMatch) {
      return '这条规则没有命中当前测试文本，可以先检查匹配内容、作用范围和正则写法。';
    }
    if (!result.hasChange) {
      return '规则已经命中，但替换前后文本没有变化。通常是替换内容与原文相同，或引用分组后结果仍一致。';
    }
    return '规则已经命中，并且结果发生了变化。可以直接对照下方原文和结果确认是否符合预期。';
  }
}
