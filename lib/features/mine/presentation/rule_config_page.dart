import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../reader/application/local/txt_toc_rule_settings_service.dart';

class RuleConfigPage extends StatefulWidget {
  const RuleConfigPage({super.key});

  @override
  State<RuleConfigPage> createState() => _RuleConfigPageState();
}

class _RuleConfigPageState extends State<RuleConfigPage> {
  final TxtTocRuleSettingsService _txtTocRuleSettingsService =
      TxtTocRuleSettingsService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isResetting = false;
  bool _isImporting = false;
  bool _isExporting = false;
  List<TxtTocRuleState> _rules = const <TxtTocRuleState>[];
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadRules();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    final rules = await _txtTocRuleSettingsService.loadRules();
    if (!mounted) {
      return;
    }
    setState(() {
      _rules = rules;
      _isLoading = false;
    });
  }

  Future<void> _toggleRule(TxtTocRuleState rule, bool enabled) async {
    await _txtTocRuleSettingsService.setRuleEnabled(
      ruleId: rule.id,
      enabled: enabled,
    );
    await _loadRules();
  }

  Future<void> _resetRules() async {
    setState(() {
      _isResetting = true;
    });
    await _txtTocRuleSettingsService.resetRules();
    await _loadRules();
    if (!mounted) {
      return;
    }
    setState(() {
      _isResetting = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已恢复默认 TXT 目录规则开关。')));
  }

  Future<void> _showRuleEditor({TxtTocRuleState? rule}) async {
    final nameController = TextEditingController(text: rule?.name ?? '');
    final patternController = TextEditingController(text: rule?.pattern ?? '');
    final exampleController = TextEditingController(text: rule?.example ?? '');
    var enabled = rule?.enabled ?? true;
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(rule == null ? '新增 TXT 规则' : '编辑 TXT 规则'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '规则名称',
                          hintText: '例如：Chapter 标题',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: patternController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: '正则表达式',
                          hintText: '请输入多行章节匹配正则',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: exampleController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: '示例',
                          hintText: '例如：第一章 初始',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: enabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('参与自动识别'),
                        onChanged: (value) {
                          setDialogState(() {
                            enabled = value;
                          });
                        },
                      ),
                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final pattern = patternController.text.trim();
                    if (name.isEmpty) {
                      setDialogState(() {
                        errorText = '规则名称不能为空。';
                      });
                      return;
                    }
                    if (pattern.isEmpty) {
                      setDialogState(() {
                        errorText = '正则表达式不能为空。';
                      });
                      return;
                    }
                    try {
                      RegExp(pattern, multiLine: true, caseSensitive: false);
                    } catch (error) {
                      setDialogState(() {
                        errorText = '正则语法错误：$error';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      nameController.dispose();
      patternController.dispose();
      exampleController.dispose();
      return;
    }

    final nextRule = TxtTocRuleState(
      id: rule?.id ?? 'rule_${DateTime.now().microsecondsSinceEpoch}',
      name: nameController.text.trim(),
      pattern: patternController.text.trim(),
      example:
          exampleController.text.trim().isEmpty
              ? null
              : exampleController.text.trim(),
      serialNumber: rule?.serialNumber ?? _rules.length,
      enabled: enabled,
    );

    nameController.dispose();
    patternController.dispose();
    exampleController.dispose();

    await _txtTocRuleSettingsService.saveRule(nextRule);
    await _loadRules();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(rule == null ? '已新增规则。' : '已保存规则。')));
  }

  Future<void> _deleteRule(TxtTocRuleState rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除规则'),
          content: Text('确认删除「${rule.name}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await _txtTocRuleSettingsService.deleteRule(rule.id);
    await _loadRules();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除规则：${rule.name}')));
  }

  Future<void> _importRules() async {
    final action = await showMenu<_RuleImportAction>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 12, 0),
      items: const [
        PopupMenuItem(value: _RuleImportAction.paste, child: Text('粘贴导入 JSON')),
        PopupMenuItem(value: _RuleImportAction.url, child: Text('链接导入')),
        PopupMenuItem(value: _RuleImportAction.file, child: Text('文件导入')),
      ],
    );
    if (action == null || !mounted) {
      return;
    }

    switch (action) {
      case _RuleImportAction.paste:
        await _importRulesFromPaste();
        return;
      case _RuleImportAction.url:
        await _importRulesFromUrl();
        return;
      case _RuleImportAction.file:
        await _importRulesFromFile();
        return;
    }
  }

  Future<void> _importRulesFromPaste() async {
    final text = await _showPasteImportPage();
    if (!mounted || text == null) {
      return;
    }

    final content = text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先粘贴规则 JSON 内容。')));
      return;
    }

    await _importRulesFromText(content);
  }

  Future<void> _importRulesFromUrl() async {
    final input = await _showUrlImportPage();
    if (!mounted || input == null) {
      return;
    }

    final rawUrl = input.trim();
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接不能为空。')));
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    final scheme = uri?.scheme.toLowerCase();
    final isHttpScheme = scheme == 'http' || scheme == 'https';
    if (uri == null || uri.host.isEmpty || !isHttpScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('链接格式无效，请输入 http/https 开头的 JSON 地址。')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });
    try {
      final response = await Dio(
        BaseOptions(
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 12),
          followRedirects: true,
          maxRedirects: 5,
          validateStatus:
              (status) => status != null && status >= 200 && status < 400,
          headers: const {'Accept': 'application/json,text/plain,*/*'},
        ),
      ).getUri(uri);
      final content = (response.data ?? '').toString().trim();
      if (content.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('链接导入失败：响应内容为空。')));
        return;
      }
      await _importRulesFromText(content);
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final statusCode = error.response?.statusCode;
      final message =
          statusCode != null
              ? 'HTTP $statusCode'
              : (error.message ?? error.type.name);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('链接导入失败：$message')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('链接导入失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _importRulesFromFile() async {
    setState(() {
      _isImporting = true;
    });
    try {
      final picked = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
        confirmButtonText: '导入规则',
      );
      if (picked == null) {
        return;
      }

      final text = await picked.readAsString();
      await _importRulesFromText(text);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _importRulesFromText(String text) async {
    setState(() {
      _isImporting = true;
    });
    try {
      final imported = await _txtTocRuleSettingsService.importRulesFromJson(
        text,
      );
      await _loadRules();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(imported > 0 ? '已导入 $imported 条规则。' : '没有可导入的规则。'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _exportRules() async {
    setState(() {
      _isExporting = true;
    });
    try {
      final content = await _txtTocRuleSettingsService.exportRulesToJson();
      final fileName =
          'txt_toc_rules_${DateTime.now().millisecondsSinceEpoch}.json';
      final outputPath = await _resolveExportTargetPath(fileName);
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }

      final file = File(outputPath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(content, flush: true);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出成功：${file.path}')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<String?> _resolveExportTargetPath(String suggestedName) async {
    try {
      final saveLocation = await getSaveLocation(
        suggestedName: suggestedName,
        confirmButtonText: '导出规则',
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );
      if (saveLocation == null) {
        return null;
      }
      final path = saveLocation.path.trim();
      return path.toLowerCase().endsWith('.json') ? path : '$path.json';
    } catch (_) {
      try {
        final directoryPath = await getDirectoryPath(
          confirmButtonText: '选择导出目录',
        );
        if (directoryPath == null || directoryPath.trim().isEmpty) {
          return null;
        }
        return _joinPath(directoryPath.trim(), suggestedName);
      } catch (_) {
        final baseDirectory = await getApplicationDocumentsDirectory();
        final exportDirectory = Directory(
          _joinPath(baseDirectory.path, 'flutter_appread_exports'),
        );
        if (!await exportDirectory.exists()) {
          await exportDirectory.create(recursive: true);
        }
        return _joinPath(exportDirectory.path, suggestedName);
      }
    }
  }

  String _joinPath(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
  }

  Future<String?> _showPasteImportPage() {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _RulePasteImportPage()),
    );
  }

  Future<String?> _showUrlImportPage() {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _RuleUrlImportPage()),
    );
  }

  void _handleSearchChanged() {
    final keyword = _searchController.text.trim();
    if (keyword == _searchKeyword) {
      return;
    }
    setState(() {
      _searchKeyword = keyword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final filteredRules =
        _searchKeyword.isEmpty
            ? _rules
            : _rules
                .where((rule) {
                  final keyword = _searchKeyword.toLowerCase();
                  return rule.name.toLowerCase().contains(keyword) ||
                      (rule.example ?? '').toLowerCase().contains(keyword) ||
                      rule.pattern.toLowerCase().contains(keyword);
                })
                .toList(growable: false);

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TXT 目录规则'),
          actions: [
            IconButton(
              tooltip: '新增规则',
              onPressed: _isLoading ? null : () => _showRuleEditor(),
              icon: const Icon(Icons.add_rounded),
            ),
            IconButton(
              tooltip: '导入规则',
              onPressed: _isLoading || _isImporting ? null : _importRules,
              icon:
                  _isImporting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.file_open_rounded),
            ),
            IconButton(
              tooltip: '导出规则',
              onPressed: _isLoading || _isExporting ? null : _exportRules,
              icon:
                  _isExporting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.ios_share_rounded),
            ),
            IconButton(
              tooltip: '恢复默认',
              onPressed: _isLoading || _isResetting ? null : _resetRules,
              icon:
                  _isResetting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.restart_alt_rounded),
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
                    12 + bottomSafe,
                  ),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TXT 目录规则',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '这里控制 TXT 本地书自动识别目录时会参与匹配的规则。关闭高误伤规则可以减少误判；对单本书的具体选规则，会在本地书详情页里单独处理。',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: '搜索规则名称、示例或正则',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon:
                                _searchKeyword.isEmpty
                                    ? null
                                    : IconButton(
                                      tooltip: '清空',
                                      onPressed: _searchController.clear,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                      if (filteredRules.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('没有匹配到规则。'),
                          ),
                        ),
                      for (final rule in filteredRules) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rule.name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            rule.enabled
                                                ? '自动识别：已启用'
                                                : '自动识别：未启用',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: rule.enabled,
                                      onChanged:
                                          (value) => _toggleRule(rule, value),
                                    ),
                                    IconButton(
                                      tooltip: '编辑',
                                      onPressed:
                                          () => _showRuleEditor(rule: rule),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: '删除',
                                      onPressed: () => _deleteRule(rule),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                if ((rule.example ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '示例：${rule.example!.trim()}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  rule.pattern.isEmpty
                                      ? '空规则，作为无规则兜底占位'
                                      : rule.pattern,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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
}

enum _RuleImportAction { paste, url, file }

class _RulePasteImportPage extends StatefulWidget {
  const _RulePasteImportPage();

  @override
  State<_RulePasteImportPage> createState() => _RulePasteImportPageState();
}

class _RulePasteImportPageState extends State<_RulePasteImportPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _readClipboard();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _readClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) {
      return;
    }
    _controller.text = text;
    setState(() {});
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final maxWidth = AppLayout.pageContentMaxWidth(context, maxWidth: 760);
    final keyboardInset = AppLayout.keyboardInset(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canSubmit = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('粘贴导入 TXT 目录规则'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: const Text('导入'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  12 + bottomSafe,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '粘贴 TXT 目录规则 JSON（对象或数组）',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '{...} 或 [{...}]',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: canSubmit ? _submit : null,
                      icon: const Icon(Icons.file_download_rounded),
                      label: const Text('导入'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleUrlImportPage extends StatefulWidget {
  const _RuleUrlImportPage();

  @override
  State<_RuleUrlImportPage> createState() => _RuleUrlImportPageState();
}

class _RuleUrlImportPageState extends State<_RuleUrlImportPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final maxWidth = AppLayout.pageContentMaxWidth(context, maxWidth: 760);
    final keyboardInset = AppLayout.keyboardInset(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canSubmit = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('链接导入 TXT 目录规则'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: const Text('导入'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  12 + bottomSafe,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '请输入规则 JSON 链接（http/https）',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (canSubmit) {
                          _submit();
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'https://example.com/txt_toc_rules.json',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '支持直接粘贴链接，返回后会自动校验并开始导入。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: canSubmit ? _submit : null,
                      icon: const Icon(Icons.file_download_rounded),
                      label: const Text('导入'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
