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
    required this.cover,
    this.titleHeroTag,
    this.metaHeroTag,
  });

  final String title;
  final String sourceName;
  final String? author;
  final Widget cover;
  final String? titleHeroTag;
  final String? metaHeroTag;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final expanded = metrics.isExpandedWindow;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.isCompactDensity ? 0 : 2,
        vertical: 2,
      ),
      child:
          expanded
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(alignment: Alignment.topLeft, child: cover),
                  SizedBox(height: metrics.sectionGap),
                  _BookDetailSummaryText(
                    title: title,
                    sourceName: sourceName,
                    author: author,
                    titleHeroTag: titleHeroTag,
                    metaHeroTag: metaHeroTag,
                  ),
                ],
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(alignment: Alignment.topLeft, child: cover),
                  SizedBox(width: metrics.sectionGap),
                  Expanded(
                    child: _BookDetailSummaryText(
                      title: title,
                      sourceName: sourceName,
                      author: author,
                      titleHeroTag: titleHeroTag,
                      metaHeroTag: metaHeroTag,
                    ),
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
    this.titleHeroTag,
    this.metaHeroTag,
  });

  final String title;
  final String sourceName;
  final String? author;
  final String? titleHeroTag;
  final String? metaHeroTag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final titleWidget = Text(
      title,
      maxLines: metrics.isCompactDensity ? 2 : 3,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.18,
        color: colorScheme.onSurface,
      ),
    );
    final authorText =
        author != null && author!.trim().isNotEmpty ? author!.trim() : '未知';
    final authorInfoLine = _BookDetailInfoLine(label: '作者', value: authorText);
    final sourceInfoLine = _BookDetailInfoLine(label: '来源', value: sourceName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _wrapHero(titleHeroTag, titleWidget),
        SizedBox(height: metrics.contentGap),
        _wrapHero(metaHeroTag, authorInfoLine),
        SizedBox(height: metrics.isCompactDensity ? 5 : 7),
        sourceInfoLine,
      ],
    );
  }

  Widget _wrapHero(String? tag, Widget child) {
    final normalized = tag?.trim() ?? '';
    if (normalized.isEmpty) {
      return child;
    }
    return Hero(tag: normalized, child: child);
  }
}

class _BookDetailInfoLine extends StatelessWidget {
  const _BookDetailInfoLine({required this.label, required this.value});

  final String label;
  final String value;

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
            maxLines: 1,
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

class BookDetailServerMetaLine extends StatelessWidget {
  const BookDetailServerMetaLine({
    super.key,
    this.wordCount,
    this.category,
    this.tags = const <String>[],
    this.updateTime,
  });

  final String? wordCount;
  final String? category;
  final List<String> tags;
  final String? updateTime;

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Wrap(
      spacing: metrics.isCompactDensity ? 7 : 8,
      runSpacing: metrics.isCompactDensity ? 7 : 8,
      children: [
        for (final item in items)
          _BookDetailInlinePill(
            text: item,
            backgroundColor: colorScheme.surfaceContainerHigh,
            textColor: colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }

  List<String> _buildItems() {
    final items = <String>[];
    final word = _cleanLabeledValue(wordCount, label: '字数');
    if (word != null) {
      items.add(word);
    }
    final seenTags = <String>{};
    final normalizedCategory = _cleanLabeledValue(category, label: '分类');
    if (normalizedCategory != null) {
      seenTags.add(normalizedCategory);
      items.add(normalizedCategory);
    }
    for (final tag in tags) {
      final normalized = _cleanLabeledValue(tag, label: '标签');
      if (normalized == null || seenTags.contains(normalized)) {
        continue;
      }
      seenTags.add(normalized);
      items.add(normalized);
      if (items.length >= 6) {
        break;
      }
    }
    final update = _cleanLabeledValue(updateTime, label: '更新');
    if (update != null) {
      items.add('更新: $update');
    }
    return items;
  }
}

class _BookDetailInlinePill extends StatelessWidget {
  const _BookDetailInlinePill({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      constraints: BoxConstraints(
        maxWidth: metrics.isCompactDensity ? 160 : 220,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.isCompactDensity ? 10 : 11,
        vertical: metrics.isCompactDensity ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class BookDetailChapterStatusLine extends StatelessWidget {
  const BookDetailChapterStatusLine({
    super.key,
    this.totalChapterNum,
    this.latestChapter,
  });

  final int? totalChapterNum;
  final String? latestChapter;

  @override
  Widget build(BuildContext context) {
    final total = totalChapterNum;
    final latest = _stripLeadingUpdateFromLatestChapter(latestChapter);
    final items = <String>[
      if (total != null && total > 0) '共 $total 章',
      if (latest != null && latest.isNotEmpty) '最新 · $latest',
    ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.cardPadding,
        vertical: metrics.isCompactDensity ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(metrics.cardRadius),
      ),
      child: Text(
        items.join('  ｜  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String? _cleanLabeledValue(String? value, {required String label}) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  var normalized = trimmed;
  final pattern = RegExp('^$label[：:]\\s*');
  while (pattern.hasMatch(normalized)) {
    normalized = normalized.replaceFirst(pattern, '').trim();
  }
  return normalized.isEmpty ? null : normalized;
}

String? _stripLeadingUpdateFromLatestChapter(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final normalized =
      trimmed
          .replaceFirst(
            RegExp(r'^\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}日?\s*(更新|更)?\s*'),
            '',
          )
          .trim();
  return normalized.isEmpty ? trimmed : normalized;
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
    final surfaceColor = colorScheme.surfaceContainerHigh;
    final collapsedLines =
        metrics.isCompactDensity
            ? 5
            : metrics.isMediumWindow || metrics.isExpandedWindow
            ? 10
            : 7;
    final canExpand = widget.intro.trim().length > 120;
    final showFadeMask = canExpand && !_expanded;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: surfaceColor,
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
          Stack(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Text(
                  widget.intro,
                  maxLines: _expanded ? null : collapsedLines,
                  overflow:
                      _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              if (showFadeMask)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            surfaceColor.withValues(alpha: 0),
                            surfaceColor.withValues(alpha: 0.92),
                            surfaceColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
                child: Text(_expanded ? '收起全文' : '展开全文'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
