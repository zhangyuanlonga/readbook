import 'package:flutter/material.dart';

class BookDetailStateCard extends StatelessWidget {
  const BookDetailStateCard({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class BookDetailMetaChip extends StatelessWidget {
  const BookDetailMetaChip({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class BookDetailSummaryCard extends StatelessWidget {
  const BookDetailSummaryCard({
    super.key,
    required this.title,
    required this.sourceName,
    this.author,
    this.latestChapter,
    required this.cover,
  });

  final String title;
  final String sourceName;
  final String? author;
  final String? latestChapter;
  final Widget cover;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              cover,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _BookDetailInfoLine(
                      label: '作者',
                      value:
                          author != null && author!.trim().isNotEmpty
                              ? author!.trim()
                              : '未知',
                    ),
                    const SizedBox(height: 7),
                    _BookDetailInfoLine(label: '来源', value: sourceName),
                    const SizedBox(height: 7),
                    _BookDetailInfoLine(
                      label: '最新',
                      value:
                          latestChapter != null &&
                                  latestChapter!.trim().isNotEmpty
                              ? latestChapter!.trim()
                              : '暂无',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookDetailInfoLine extends StatelessWidget {
  const _BookDetailInfoLine({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      height: 1.22,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: labelStyle),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

class BookDetailQuickActionsCard extends StatelessWidget {
  const BookDetailQuickActionsCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: child,
      ),
    );
  }
}

class BookDetailActionEntryCard extends StatelessWidget {
  const BookDetailActionEntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.enabled = true,
    this.leadingStripeColor,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? leadingStripeColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: leadingStripeColor ?? colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                onPressed: enabled ? onPressed : null,
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookDetailIntroCard extends StatelessWidget {
  const BookDetailIntroCard({super.key, required this.intro});

  final String intro;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '简介',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            intro,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class BookDetailCacheSummaryCard extends StatelessWidget {
  const BookDetailCacheSummaryCard({
    super.key,
    required this.totalChapters,
    required this.cachedChapters,
    required this.statusLabel,
    required this.percentLabel,
    required this.progress,
    required this.isAllCached,
    required this.onOpenCache,
  });

  final int totalChapters;
  final int cachedChapters;
  final String statusLabel;
  final String percentLabel;
  final double progress;
  final bool isAllCached;
  final VoidCallback? onOpenCache;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final icon =
        isAllCached ? Icons.cloud_done_rounded : Icons.cloud_download_outlined;

    return Card(
      color: colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpenCache,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '缓存章节',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '已缓存 $cachedChapters / $totalChapters 章',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonal(
                    onPressed: onOpenCache,
                    child: const Text('去缓存'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    percentLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: totalChapters <= 0 ? 0 : progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAllCached ? '当前目录已全部缓存，离线阅读会更稳定。' : '可按章节范围批量缓存，减少翻页等待。',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookDetailChapterSectionCard extends StatelessWidget {
  const BookDetailChapterSectionCard({
    super.key,
    required this.totalChapters,
    required this.tocFromCache,
    required this.reversed,
    required this.canToggleReverse,
    required this.onToggleReverse,
    this.localTxtControls,
    this.primaryActions,
    this.emptyState,
    required this.previewChildren,
    this.showAllChaptersLabel,
    this.onShowAllChapters,
  });

  final int totalChapters;
  final bool tocFromCache;
  final bool reversed;
  final bool canToggleReverse;
  final VoidCallback? onToggleReverse;
  final Widget? localTxtControls;
  final Widget? primaryActions;
  final Widget? emptyState;
  final List<Widget> previewChildren;
  final String? showAllChaptersLabel;
  final VoidCallback? onShowAllChapters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '目录（$totalChapters 章）',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (tocFromCache)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '缓存',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: canToggleReverse ? onToggleReverse : null,
                  tooltip: reversed ? '切换为正序' : '切换为倒序',
                  icon: Icon(
                    reversed
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              reversed ? '当前展示：倒序' : '当前展示：正序',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (localTxtControls != null) ...[
              const SizedBox(height: 10),
              localTxtControls!,
            ],
            if (primaryActions != null) ...[
              const SizedBox(height: 12),
              primaryActions!,
            ],
            if (emptyState != null) ...[
              const SizedBox(height: 12),
              emptyState!,
            ],
            if (previewChildren.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...previewChildren,
            ],
            if (showAllChaptersLabel != null && onShowAllChapters != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onShowAllChapters,
                icon: const Icon(Icons.unfold_more_rounded),
                label: Text(showAllChaptersLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BookDetailChapterTile extends StatelessWidget {
  const BookDetailChapterTile({
    super.key,
    this.displayIndex,
    required this.title,
    this.onTap,
    this.showDivider = true,
    this.enabled = true,
    this.isVolume = false,
  });

  final int? displayIndex;
  final String title;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool enabled;
  final bool isVolume;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color:
          enabled
              ? (isVolume ? colorScheme.primary : colorScheme.onSurface)
              : colorScheme.onSurfaceVariant,
      fontWeight: isVolume ? FontWeight.w700 : FontWeight.w400,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border:
              showDivider
                  ? Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  )
                  : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child:
                  isVolume
                      ? Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '卷',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                      : Text(
                        '${(displayIndex ?? 0) + 1}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            if (!isVolume)
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
