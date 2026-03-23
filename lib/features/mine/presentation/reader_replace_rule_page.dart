import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/reader_replace_rule.dart';
import '../../reader/application/reader_replace_rule_service.dart';

class ReaderReplaceRulePage extends StatefulWidget {
  const ReaderReplaceRulePage({super.key});

  @override
  State<ReaderReplaceRulePage> createState() => _ReaderReplaceRulePageState();
}

enum _ReaderReplaceRuleSortMode { orderAsc, orderDesc, nameAsc, nameDesc }

enum _ReaderReplaceRulePageAction { persistCurrentSort }

enum _ReaderReplaceRuleImportAction { paste, url, file }

enum _ReaderReplaceRuleItemAction { duplicate, copyJson, delete }

class _ReaderReplaceRulePageState extends State<ReaderReplaceRulePage> {
  final ReaderReplaceRuleService _service = ReaderReplaceRuleService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isImporting = false;
  bool _isExporting = false;
  bool _isUpdatingDefault = false;
  bool _enabledByDefault = true;
  String _searchKeyword = '';
  String _selectedGroup = '全部';
  _ReaderReplaceRuleSortMode _sortMode = _ReaderReplaceRuleSortMode.orderAsc;
  List<ReaderReplaceRule> _rules = const <ReaderReplaceRule>[];

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
    final rules = await _service.listAll();
    final enabledByDefault = await _service.loadEnabledByDefault();
    if (!mounted) {
      return;
    }
    setState(() {
      _rules = rules;
      _enabledByDefault = enabledByDefault;
      _isLoading = false;
    });
  }

  Future<void> _toggleEnabledByDefault(bool enabled) async {
    setState(() {
      _enabledByDefault = enabled;
      _isUpdatingDefault = true;
    });

    try {
      await _service.saveEnabledByDefault(enabled);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabledByDefault = !enabled;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存默认开关失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDefault = false;
        });
      }
    }
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _searchKeyword) {
      return;
    }
    setState(() {
      _searchKeyword = next;
    });
  }

  Future<void> _openEditor({ReaderReplaceRule? rule}) async {
    final suffix = rule == null ? '' : '?id=${rule.id}';
    await context.push('/reader-replace-rules/edit$suffix');
    await _loadRules();
  }

  Future<void> _toggleRule(ReaderReplaceRule rule, bool enabled) async {
    await _service.saveRule(
      rule.copyWith(isEnabled: enabled, updatedAt: DateTime.now()),
    );
    await _loadRules();
  }

  Future<void> _deleteRule(ReaderReplaceRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除净化规则'),
          content: Text('确认删除「${rule.name}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _service.deleteRule(rule.id);
    await _loadRules();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除规则：${rule.name}')));
  }

  Future<void> _duplicateRule(ReaderReplaceRule rule) async {
    final maxSortOrder = _rules.fold<int>(
      0,
      (previousValue, item) =>
          item.sortOrder > previousValue ? item.sortOrder : previousValue,
    );
    final duplicate = rule.copyWith(
      id: 0,
      name: _duplicateRuleName(rule.name),
      sortOrder: maxSortOrder + 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _service.saveRule(duplicate);
    await _loadRules();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已克隆规则：${duplicate.name}')));
  }

  Future<void> _copyRuleJson(ReaderReplaceRule rule) async {
    final payload = const JsonEncoder.withIndent('  ').convert(rule.toJson());
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已复制 ${rule.name} 的 JSON')));
  }

  Future<void> _persistCurrentSort() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('保存当前排序'),
          content: Text(
            '会按当前排序方式重写全部规则顺序。保存后，切回“按顺序升序”时也会沿用这套顺序。\n\n当前方式：${_sortModeLabel(_sortMode)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('保存顺序'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    final now = DateTime.now();
    final sortedRules = _sortRules(_rules, _sortMode);
    for (var index = 0; index < sortedRules.length; index += 1) {
      final rule = sortedRules[index];
      await _service.saveRule(rule.copyWith(sortOrder: index, updatedAt: now));
    }

    await _loadRules();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已将当前排序写入规则顺序。')));
  }

  Future<void> _importRules() async {
    final action = await showMenu<_ReaderReplaceRuleImportAction>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 12, 0),
      items: const [
        PopupMenuItem(
          value: _ReaderReplaceRuleImportAction.paste,
          child: Text('粘贴导入 JSON'),
        ),
        PopupMenuItem(
          value: _ReaderReplaceRuleImportAction.url,
          child: Text('链接导入'),
        ),
        PopupMenuItem(
          value: _ReaderReplaceRuleImportAction.file,
          child: Text('文件导入'),
        ),
      ],
    );
    if (action == null || !mounted) {
      return;
    }

    switch (action) {
      case _ReaderReplaceRuleImportAction.paste:
        await _importRulesFromPaste();
        return;
      case _ReaderReplaceRuleImportAction.url:
        await _importRulesFromUrl();
        return;
      case _ReaderReplaceRuleImportAction.file:
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
      ).showSnackBar(const SnackBar(content: Text('请先粘贴净化规则 JSON 内容。')));
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
    XFile? file;
    try {
      file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
        confirmButtonText: '导入规则',
      );
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开文件选择器失败：${error.message ?? error.code}')),
      );
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开文件选择器失败：$error')));
      return;
    }
    if (file == null || !mounted) {
      return;
    }

    await _importRulesFromText(await file.readAsString());
  }

  Future<void> _importRulesFromText(String raw) async {
    setState(() {
      _isImporting = true;
    });

    try {
      final importedRules = _service.parseImportPayload(raw);

      for (final rule in importedRules) {
        await _service.saveRule(
          rule.copyWith(
            id: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      await _loadRules();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${importedRules.length} 条净化规则。')),
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

  Future<String?> _showPasteImportPage() {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _ReaderReplaceRulePasteImportPage(),
      ),
    );
  }

  Future<String?> _showUrlImportPage() {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _ReaderReplaceRuleUrlImportPage(),
      ),
    );
  }

  Future<void> _exportRules() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/reader_replace_rules_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      final payload = _service.exportPayload(_rules);
      await file.writeAsString(payload, flush: true);

      final location = await getSaveLocation(
        suggestedName: file.uri.pathSegments.last,
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
        confirmButtonText: '导出规则',
      );
      if (location == null || !mounted) {
        return;
      }

      await file.copy(location.path);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导出到：${location.path}')));
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

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final filteredRules = _sortRules(
      _rules.where((rule) {
        final keyword = _searchKeyword.toLowerCase();
        final matchesKeyword =
            keyword.isEmpty ||
            rule.name.toLowerCase().contains(keyword) ||
            (rule.group ?? '').toLowerCase().contains(keyword) ||
            rule.pattern.toLowerCase().contains(keyword) ||
            rule.replacement.toLowerCase().contains(keyword) ||
            (rule.scope ?? '').toLowerCase().contains(keyword) ||
            (rule.excludeScope ?? '').toLowerCase().contains(keyword);
        final group = (rule.group ?? '').trim();
        final matchesGroup =
            _selectedGroup == '全部' ||
            (_selectedGroup == '未分组' ? group.isEmpty : group == _selectedGroup);
        return matchesKeyword && matchesGroup;
      }),
      _sortMode,
    );

    final totalCount = _rules.length;
    final enabledCount = _rules.where((item) => item.isEnabled).length;
    final regexCount = _rules.where((item) => item.isRegex).length;
    final groups = <String>{
      '全部',
      '未分组',
      ..._rules
          .map((rule) => (rule.group ?? '').trim())
          .where((group) => group.isNotEmpty),
    }.toList(growable: false);

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/rule-config');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('净化规则'),
          actions: [
            PopupMenuButton<_ReaderReplaceRuleSortMode>(
              tooltip: '排序方式',
              onSelected: (value) {
                setState(() {
                  _sortMode = value;
                });
              },
              itemBuilder:
                  (context) => const [
                    PopupMenuItem(
                      value: _ReaderReplaceRuleSortMode.orderAsc,
                      child: Text('按顺序升序'),
                    ),
                    PopupMenuItem(
                      value: _ReaderReplaceRuleSortMode.orderDesc,
                      child: Text('按顺序降序'),
                    ),
                    PopupMenuItem(
                      value: _ReaderReplaceRuleSortMode.nameAsc,
                      child: Text('按名称升序'),
                    ),
                    PopupMenuItem(
                      value: _ReaderReplaceRuleSortMode.nameDesc,
                      child: Text('按名称降序'),
                    ),
                  ],
              icon: const Icon(Icons.sort_rounded),
            ),
            PopupMenuButton<_ReaderReplaceRulePageAction>(
              tooltip: '更多操作',
              onSelected: (value) {
                switch (value) {
                  case _ReaderReplaceRulePageAction.persistCurrentSort:
                    _persistCurrentSort();
                    break;
                }
              },
              itemBuilder:
                  (context) => const [
                    PopupMenuItem(
                      value: _ReaderReplaceRulePageAction.persistCurrentSort,
                      child: Text('将当前排序写入顺序'),
                    ),
                  ],
              icon: const Icon(Icons.more_horiz_rounded),
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
              onPressed:
                  _isLoading || _isExporting || _rules.isEmpty
                      ? null
                      : _exportRules,
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
              tooltip: '新增规则',
              onPressed: _isLoading ? null : () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
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
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.44,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer
                                      .withValues(alpha: 0.84),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.cleaning_services_outlined,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '用户净化规则',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '这套规则会在阅读展示前对正文再做一层用户级清洗，用来去广告、去水印、做文本替换。',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildStatChip(
                                context,
                                icon: Icons.rule_folder_outlined,
                                label: '总数 $totalCount',
                              ),
                              _buildStatChip(
                                context,
                                icon: Icons.toggle_on_outlined,
                                label: '启用 $enabledCount',
                              ),
                              _buildStatChip(
                                context,
                                icon: Icons.code_rounded,
                                label: '正则 $regexCount',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _enabledByDefault ? '默认启用净化' : '默认关闭净化',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_isUpdatingDefault)
                                const Padding(
                                  padding: EdgeInsets.only(right: 10),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              Switch.adaptive(
                                value: _enabledByDefault,
                                onChanged:
                                    _isUpdatingDefault
                                        ? null
                                        : _toggleEnabledByDefault,
                              ),
                            ],
                          ),
                          Text(
                            '新书默认跟随这个开关；单本书可在阅读页“本章净化”里单独覆盖。',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: '搜索规则名称、范围、正则或替换文本',
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
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: groups
                                    .map(
                                      (group) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(group),
                                          selected: _selectedGroup == group,
                                          onSelected: (_) {
                                            setState(() {
                                              _selectedGroup = group;
                                            });
                                          },
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildTag(context, '当前分组：$_selectedGroup'),
                            _buildTag(context, _sortModeLabel(_sortMode)),
                            _buildTag(context, '命中 ${filteredRules.length} 条'),
                          ],
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
                    else if (filteredRules.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('还没有匹配到净化规则。'),
                        ),
                      )
                    else
                      ...filteredRules.map(
                        (rule) => Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
                                            style: textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              _buildTag(
                                                context,
                                                rule.isEnabled ? '已启用' : '已停用',
                                              ),
                                              _buildTag(
                                                context,
                                                rule.isRegex ? '正则替换' : '普通替换',
                                              ),
                                              _buildTag(
                                                context,
                                                _scopeModeLabel(rule.scopeMode),
                                              ),
                                              _buildTag(
                                                context,
                                                '顺序 ${rule.sortOrder}',
                                              ),
                                              if ((rule.group ?? '')
                                                  .trim()
                                                  .isNotEmpty)
                                                _buildTag(
                                                  context,
                                                  rule.group!.trim(),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch.adaptive(
                                      value: rule.isEnabled,
                                      onChanged:
                                          (value) => _toggleRule(rule, value),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildRuleLine(
                                  context,
                                  label: '匹配',
                                  value: rule.pattern,
                                ),
                                _buildRuleLine(
                                  context,
                                  label: '替换',
                                  value:
                                      rule.replacement.isEmpty
                                          ? '(替换为空，相当于删除)'
                                          : rule.replacement,
                                ),
                                if ((rule.scope ?? '').trim().isNotEmpty)
                                  _buildRuleLine(
                                    context,
                                    label: '范围',
                                    value: rule.scope!.trim(),
                                  ),
                                if ((rule.excludeScope ?? '').trim().isNotEmpty)
                                  _buildRuleLine(
                                    context,
                                    label: '排除',
                                    value: rule.excludeScope!.trim(),
                                  ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _openEditor(rule: rule),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('编辑'),
                                    ),
                                    const Spacer(),
                                    PopupMenuButton<
                                      _ReaderReplaceRuleItemAction
                                    >(
                                      tooltip: '更多操作',
                                      onSelected: (value) {
                                        switch (value) {
                                          case _ReaderReplaceRuleItemAction
                                              .duplicate:
                                            _duplicateRule(rule);
                                            break;
                                          case _ReaderReplaceRuleItemAction
                                              .copyJson:
                                            _copyRuleJson(rule);
                                            break;
                                          case _ReaderReplaceRuleItemAction
                                              .delete:
                                            _deleteRule(rule);
                                            break;
                                        }
                                      },
                                      itemBuilder:
                                          (context) => [
                                            const PopupMenuItem(
                                              value:
                                                  _ReaderReplaceRuleItemAction
                                                      .duplicate,
                                              child: Text('克隆规则'),
                                            ),
                                            const PopupMenuItem(
                                              value:
                                                  _ReaderReplaceRuleItemAction
                                                      .copyJson,
                                              child: Text('复制 JSON'),
                                            ),
                                            PopupMenuItem(
                                              value:
                                                  _ReaderReplaceRuleItemAction
                                                      .delete,
                                              child: Text(
                                                '删除规则',
                                                style: TextStyle(
                                                  color: colorScheme.error,
                                                ),
                                              ),
                                            ),
                                          ],
                                      icon: const Icon(
                                        Icons.more_horiz_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRuleLine(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
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

  String _sortModeLabel(_ReaderReplaceRuleSortMode mode) {
    return switch (mode) {
      _ReaderReplaceRuleSortMode.orderAsc => '排序：顺序升序',
      _ReaderReplaceRuleSortMode.orderDesc => '排序：顺序降序',
      _ReaderReplaceRuleSortMode.nameAsc => '排序：名称升序',
      _ReaderReplaceRuleSortMode.nameDesc => '排序：名称降序',
    };
  }

  List<ReaderReplaceRule> _sortRules(
    Iterable<ReaderReplaceRule> rules,
    _ReaderReplaceRuleSortMode sortMode,
  ) {
    return rules.toList(growable: true)..sort((left, right) {
      switch (sortMode) {
        case _ReaderReplaceRuleSortMode.orderAsc:
          final orderCompare = left.sortOrder.compareTo(right.sortOrder);
          if (orderCompare != 0) {
            return orderCompare;
          }
          return left.id.compareTo(right.id);
        case _ReaderReplaceRuleSortMode.orderDesc:
          final orderCompare = right.sortOrder.compareTo(left.sortOrder);
          if (orderCompare != 0) {
            return orderCompare;
          }
          return right.id.compareTo(left.id);
        case _ReaderReplaceRuleSortMode.nameAsc:
          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        case _ReaderReplaceRuleSortMode.nameDesc:
          return right.name.toLowerCase().compareTo(left.name.toLowerCase());
      }
    });
  }

  String _duplicateRuleName(String name) {
    if (name.endsWith('（副本）')) {
      return '$name 2';
    }
    return '$name（副本）';
  }
}

class _ReaderReplaceRulePasteImportPage extends StatefulWidget {
  const _ReaderReplaceRulePasteImportPage();

  @override
  State<_ReaderReplaceRulePasteImportPage> createState() =>
      _ReaderReplaceRulePasteImportPageState();
}

class _ReaderReplaceRulePasteImportPageState
    extends State<_ReaderReplaceRulePasteImportPage> {
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
        title: const Text('粘贴导入净化规则'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: const Text('导入'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                12,
                horizontal,
                12 + bottomSafe + keyboardInset,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '粘贴净化规则 JSON（对象或数组）',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    minLines: 10,
                    maxLines: 18,
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
    );
  }
}

class _ReaderReplaceRuleUrlImportPage extends StatefulWidget {
  const _ReaderReplaceRuleUrlImportPage();

  @override
  State<_ReaderReplaceRuleUrlImportPage> createState() =>
      _ReaderReplaceRuleUrlImportPageState();
}

class _ReaderReplaceRuleUrlImportPageState
    extends State<_ReaderReplaceRuleUrlImportPage> {
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
        title: const Text('链接导入净化规则'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: const Text('导入'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                12,
                horizontal,
                12 + bottomSafe + keyboardInset,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '请输入净化规则 JSON 链接（http/https）',
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
                      hintText: 'https://example.com/reader_replace_rules.json',
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
                  const SizedBox(height: 16),
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
    );
  }
}
