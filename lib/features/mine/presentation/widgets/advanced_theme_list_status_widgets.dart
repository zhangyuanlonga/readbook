import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/widgets/adaptive_card.dart';
import '../../../../app/widgets/app_empty_state_card.dart';
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
        AdaptiveCard(
          padding: EdgeInsets.all(metrics.cardPadding + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      MembershipAccessPresentation.vipTag,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: metrics.contentGap + 4),
              Text(
                MembershipAccessPresentation.featureTitle(
                  MembershipFeatureGate.advancedTheme,
                ),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                MembershipAccessPresentation.featureDescription(
                  MembershipFeatureGate.advancedTheme,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              SizedBox(height: metrics.sectionGap),
              AppButton(
                label: MembershipAccessPresentation.membershipButtonLabel,
                icon: const Icon(Icons.workspace_premium_rounded),
                onPressed: onOpenMembership,
              ),
            ],
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
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                statusText,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
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
    return AppEmptyStateCard(
      icon: Icons.palette_outlined,
      title: isFiltering ? '没有匹配的主题' : '还没有高级主题',
      description: isFiltering ? '换个关键词或分类试试。' : '点击右上角新增，就可以分别配置浅色和深色主题。',
    );
  }
}
