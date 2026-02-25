import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  static const double _expandedBreakpoint = 840;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);

    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              colorScheme.surface,
              colorScheme.surfaceContainerLow,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _expandedBreakpoint) {
                  return _buildExpandedLayout(context);
                }
                if (constraints.maxWidth >= AppLayout.railBreakpointWidth) {
                  return _buildMediumLayout(context);
                }
                return _buildCompactLayout(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return ListView(
      children: <Widget>[
        _buildPlanCard(context),
        const SizedBox(height: 12),
        _buildCategoryHintCard(context),
      ],
    );
  }

  Widget _buildMediumLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 240, child: _buildCategoryHintCard(context)),
        const SizedBox(width: 12),
        Expanded(child: _buildPlanCard(context)),
      ],
    );
  }

  Widget _buildExpandedLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 280, child: _buildCategoryHintCard(context)),
        const SizedBox(width: 12),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: _buildPlanCard(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '发现页已接入导航',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '下一步将按书源规则加载分类与书单：exploreUrl + ruleExplore。',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const <Widget>[
                _FeatureTag(label: '分类导航'),
                _FeatureTag(label: '榜单书单'),
                _FeatureTag(label: '分页加载'),
                _FeatureTag(label: '进入详情'),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/search'),
              icon: const Icon(Icons.search_rounded),
              label: const Text('先去搜索'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHintCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const hintItems = <String>['男频榜单', '女频榜单', '完结推荐', '分类导航', '出版阅读', '休闲人文'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '发现分类',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text('将根据书源动态生成。', style: textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hintItems
                  .map((item) => Chip(label: Text(item)))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTag extends StatelessWidget {
  const _FeatureTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colorScheme.secondaryContainer,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
