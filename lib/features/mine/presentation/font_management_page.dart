import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../reader/application/reader_font_registry_service.dart';

class FontManagementPage extends StatefulWidget {
  const FontManagementPage({super.key});

  @override
  State<FontManagementPage> createState() => _FontManagementPageState();
}

class _FontManagementPageState extends State<FontManagementPage> {
  final ReaderFontRegistryService _fontRegistryService =
      ReaderFontRegistryService();

  bool _isLoading = true;
  bool _isImporting = false;
  String? _errorText;
  List<ReaderCustomFontEntry> _fonts = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final fonts = await _fontRegistryService.listRegisteredFonts();
      if (!mounted) {
        return;
      }
      setState(() {
        _fonts = fonts;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '字体列表加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

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
          title: const Text('字体管理'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go('/mine');
            },
          ),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: _isLoading ? null : () => unawaited(_reload()),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isImporting ? null : _importFont,
          icon:
              _isImporting
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.file_upload_outlined),
          label: Text(_isImporting ? '导入中...' : '导入字体'),
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.systemSettingsContentMaxWidth,
            );
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      12,
                      horizontal,
                      88 + bottomSafe,
                    ),
                    children: [
                      _buildHero(context),
                      const SizedBox(height: 12),
                      _buildPlanSection(context),
                      const SizedBox(height: 12),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_errorText != null)
                        _buildErrorCard(context)
                      else ...[
                        _buildLibraryHeader(context),
                        const SizedBox(height: 10),
                        if (_fonts.isEmpty)
                          _buildEmptyLibraryCard(context)
                        else
                          ..._fonts.map(
                            (font) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildFontCard(context, font),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.font_download_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '统一管理应用与阅读器字体',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '这版先把字体库、预览、导入删除和后续开发规划放到同一页，便于继续往“作用域配置”和“全局应用”推进。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.45,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip(context, '已导入 ${_fonts.length} 款'),
              _buildHeroChip(context, '支持 TTF / OTF'),
              _buildHeroChip(context, '下一步：作用域配置'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildPlanSection(BuildContext context) {
    final phases = const <_FontPlanPhase>[
      _FontPlanPhase(
        title: '阶段 1',
        subtitle: '字体库与预览',
        description: '当前页先把导入、删除、预览、文件状态和未来扩展位准备好。',
      ),
      _FontPlanPhase(
        title: '阶段 2',
        subtitle: '作用域配置',
        description: '补齐“应用界面 / 阅读正文 / 标题装饰”三类使用范围切换。',
      ),
      _FontPlanPhase(
        title: '阶段 3',
        subtitle: '同步与推荐',
        description: '后续接入字体分组、云端备份、多端恢复和默认方案推荐。',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '开发梳理',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...phases.map(
          (phase) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                leading: CircleAvatar(
                  radius: 18,
                  child: Text(
                    phase.title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(phase.subtitle),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(phase.description),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我的字体库',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '已导入字体会立即出现在这里，后续可继续扩展作用域和默认应用入口。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '加载失败',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _errorText ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => unawaited(_reload()),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLibraryCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '还没有导入字体',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '可以先导入 `.ttf` 或 `.otf`，这里会直接展示预览效果。后续再把“应用界面”和“阅读器正文”的作用域切换接上。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontCard(BuildContext context, ReaderCustomFontEntry font) {
    final colorScheme = Theme.of(context).colorScheme;
    final file = File(font.filePath);
    final exists = file.existsSync();
    final importedAt = DateTime.fromMillisecondsSinceEpoch(
      font.importedAtEpochMs,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        font.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exists ? '文件可用' : '文件已丢失',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              exists
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      unawaited(_removeFont(font));
                    }
                  },
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('删除字体'),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '阅读预览',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '今天的阅读不只是在翻页，也是在塑造自己的语言节奏。',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: exists ? font.fontFamilyKey : null,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FontMetaChip(text: '阅读正文'),
                _FontMetaChip(text: '应用界面（规划中）'),
                _FontMetaChip(text: _formatTime(importedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFont() async {
    setState(() {
      _isImporting = true;
    });
    try {
      final entry = await _fontRegistryService.pickAndImportFont();
      if (!mounted || entry == null) {
        return;
      }
      await _reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导入字体：${entry.displayName}')));
    } on ReaderFontRegistryException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入字体失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _removeFont(ReaderCustomFontEntry font) async {
    await _fontRegistryService.removeFont(font.fontFamilyKey);
    if (!mounted) {
      return;
    }
    await _reload();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除字体：${font.displayName}')));
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}

class _FontPlanPhase {
  const _FontPlanPhase({
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final String title;
  final String subtitle;
  final String description;
}

class _FontMetaChip extends StatelessWidget {
  const _FontMetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
