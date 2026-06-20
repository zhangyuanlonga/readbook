import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/widgets/foundation/foundation.dart';
import '../../../../core/membership/membership_access_presentation.dart';

class AdvancedThemeVipLockedState extends StatelessWidget {
  const AdvancedThemeVipLockedState({
    super.key,
    required this.topInset,
    required this.onOpenMembership,
  });

  final double topInset;
  final VoidCallback onOpenMembership;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        topInset + metrics.sectionGap,
        metrics.pagePadding,
        metrics.sectionGap + 8,
      ),
      children: [
        AppStateView(
          kind: AppViewStateKind.locked,
          icon: Icons.workspace_premium_outlined,
          title: MembershipAccessPresentation.featureTitle(
            MembershipFeatureGate.advancedTheme,
          ),
          description: MembershipAccessPresentation.featureDescription(
            MembershipFeatureGate.advancedTheme,
          ),
          primaryAction: AppStateAction(
            label: MembershipAccessPresentation.membershipButtonLabel,
            icon: const Icon(Icons.workspace_premium_rounded),
            onPressed: onOpenMembership,
          ),
          footer: Text(
            MembershipAccessPresentation.vipTag,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class AdvancedThemeSavingProgressCard extends StatelessWidget {
  const AdvancedThemeSavingProgressCard({super.key, required this.statusText});

  final String statusText;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: AppSurface(
          tone: AppSurfaceTone.elevated,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: AppInlineProgress(label: statusText),
        ),
      ),
    );
  }
}

class AdvancedThemeListStatusRow extends StatelessWidget {
  const AdvancedThemeListStatusRow({
    super.key,
    required this.countLabel,
    required this.activeLabel,
  });

  final String countLabel;
  final String activeLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AdvancedThemeStatusBubble(label: countLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: AdvancedThemeStatusBubble(label: activeLabel),
          ),
        ),
      ],
    );
  }
}

class AdvancedThemeStatusBubble extends StatelessWidget {
  const AdvancedThemeStatusBubble({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdvancedThemeListEmptyState extends StatelessWidget {
  const AdvancedThemeListEmptyState({super.key, required this.isFiltering});

  final bool isFiltering;

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      kind:
          isFiltering ? AppViewStateKind.filteredEmpty : AppViewStateKind.empty,
      icon: Icons.palette_outlined,
      title: isFiltering ? '没有匹配的主题' : '还没有高级主题',
      description: isFiltering ? '换个关键词或分类试试。' : '点击右上角新增，就可以分别配置浅色和深色主题。',
    );
  }
}
