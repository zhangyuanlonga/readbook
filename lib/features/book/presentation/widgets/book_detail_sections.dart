import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';

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
    final metrics = AppAdaptiveMetrics.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.isCompactDensity ? 8 : 9,
        vertical: metrics.isCompactDensity ? 4 : 5,
      ),
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
    final metrics = AppAdaptiveMetrics.of(context);
    final expanded = metrics.isExpandedWindow;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.isCompactDensity ? 0 : 2,
        vertical: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flex(
            direction: expanded ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment:
                expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Align(alignment: Alignment.topLeft, child: cover),
              SizedBox(
                width: expanded ? 0 : metrics.sectionGap,
                height: expanded ? metrics.sectionGap : 0,
              ),
              Flexible(
                fit: expanded ? FlexFit.loose : FlexFit.tight,
                child: _BookDetailSummaryText(
                  title: title,
                  sourceName: sourceName,
                  author: author,
                  latestChapter: latestChapter,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookDetailSummaryText extends StatelessWidget {
  const _BookDetailSummaryText({
    required this.title,
    required this.sourceName,
    this.author,
    this.latestChapter,
  });

  final String title;
  final String sourceName;
  final String? author;
  final String? latestChapter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: metrics.isCompactDensity ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.18,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: metrics.contentGap),
        _BookDetailInfoLine(
          label: '作者',
          value:
              author != null && author!.trim().isNotEmpty
                  ? author!.trim()
                  : '未知',
        ),
        SizedBox(height: metrics.isCompactDensity ? 5 : 7),
        _BookDetailInfoLine(label: '来源', value: sourceName),
        SizedBox(height: metrics.isCompactDensity ? 5 : 7),
        _BookDetailInfoLine(
          label: '最新',
          value:
              latestChapter != null && latestChapter!.trim().isNotEmpty
                  ? latestChapter!.trim()
                  : '暂无',
          maxLines: 2,
        ),
      ],
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
    final metrics = AppAdaptiveMetrics.of(context);
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
          width: metrics.isCompactDensity ? 38 : 44,
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
  const BookDetailQuickActionsCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.isCompactDensity ? 4 : 6,
          vertical: metrics.isCompactDensity ? 4 : 6,
        ),
        child: child,
      ),
    );
  }
}

class BookDetailIntroCard extends StatefulWidget {
  const BookDetailIntroCard({super.key, required this.intro});

  final String intro;

  @override
  State<BookDetailIntroCard> createState() => _BookDetailIntroCardState();
}

class _BookDetailIntroCardState extends State<BookDetailIntroCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final collapsedLines =
        metrics.isCompactDensity
            ? 5
            : metrics.isMediumWindow || metrics.isExpandedWindow
            ? 10
            : 7;
    final canExpand = widget.intro.trim().length > 120;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(metrics.cardRadius),
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
          SizedBox(height: metrics.contentGap),
          Text(
            widget.intro,
            maxLines: _expanded ? null : collapsedLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (canExpand) ...[
            SizedBox(height: metrics.isCompactDensity ? 4 : 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                child: Text(_expanded ? '收起' : '展开'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
