import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';

class RuleConfigPage extends StatelessWidget {
  const RuleConfigPage({super.key});

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
        context.go('/mine');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('规则')),
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
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '这里将统一管理净化规则与目录规则。当前先提供结构占位，后续逐步接入编辑、导入导出与调试能力。',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, localConstraints) {
                        final cards = <Widget>[
                          _RuleModuleCard(
                            icon: Icons.cleaning_services_outlined,
                            title: '净化规则',
                            subtitle: '用于正文净化、内容替换、噪声过滤。',
                            examples: const ['替换广告片段', '过滤干扰段落', '标准化标点'],
                          ),
                          _RuleModuleCard(
                            icon: Icons.rule_outlined,
                            title: '目录规则',
                            subtitle: '用于目录解析、标题清洗与章节序号修正。',
                            examples: const ['目录标题清洗', '章节顺序修复', '异常链接兜底'],
                          ),
                        ];

                        if (localConstraints.maxWidth >=
                            AppLayout.railBreakpointWidth) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 10),
                              Expanded(child: cards[1]),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 10),
                            cards[1],
                          ],
                        );
                      },
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
}

class _RuleModuleCard extends StatelessWidget {
  const _RuleModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.examples,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> examples;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 20),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: examples
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.construction_outlined, size: 18),
                label: const Text('开发中'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
