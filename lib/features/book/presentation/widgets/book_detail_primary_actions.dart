import 'package:flutter/material.dart';

class BookDetailPrimaryActions extends StatelessWidget {
  const BookDetailPrimaryActions({
    super.key,
    required this.availableWidth,
    required this.isInBookshelf,
    required this.isShelfActionLoading,
    required this.onRead,
    required this.onToggleBookshelf,
  });

  static const double actionRowCompactThreshold = 260;
  static const double shortLabelThreshold = 210;
  static const double hideIconThreshold = 186;
  static const double actionButtonHeight = 34;
  static const double actionButtonGapCompact = 8;
  static const double actionButtonGapRegular = 10;
  static const double readShortWidth = 104;
  static const double readLongWidth = 140;
  static const double shelfShortWidth = 96;
  static const double shelfLongWidth = 128;

  final double availableWidth;
  final bool isInBookshelf;
  final bool isShelfActionLoading;
  final VoidCallback? onRead;
  final VoidCallback? onToggleBookshelf;

  @override
  Widget build(BuildContext context) {
    final buttonTextStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.05);
    final compactStyle = availableWidth < actionRowCompactThreshold;
    final useShortLabels = availableWidth < shortLabelThreshold;
    final hideActionIcons = availableWidth < hideIconThreshold;

    final readLabel = useShortLabels ? '阅读' : '开始阅读';
    final shelfLabel =
        useShortLabels
            ? (isInBookshelf ? '移出' : '加入')
            : (isInBookshelf ? '移出书架' : '加入书架');

    final readButton = SizedBox(
      height: actionButtonHeight,
      child: FilledButton(
        key: const Key('book_detail_read_button'),
        style: FilledButton.styleFrom(
          textStyle: buttonTextStyle,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        onPressed: onRead,
        child: _ActionButtonContent(
          icon: Icons.chrome_reader_mode_outlined,
          label: readLabel,
          hideIcon: hideActionIcons,
        ),
      ),
    );

    final shelfButton = SizedBox(
      height: actionButtonHeight,
      child: OutlinedButton(
        key: const Key('book_detail_shelf_button'),
        style: OutlinedButton.styleFrom(
          textStyle: buttonTextStyle,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        onPressed: isShelfActionLoading ? null : onToggleBookshelf,
        child: _ActionButtonContent(
          icon:
              isInBookshelf
                  ? Icons.bookmark_remove_outlined
                  : Icons.bookmark_add_outlined,
          label: shelfLabel,
          hideIcon: hideActionIcons,
        ),
      ),
    );

    final buttonGap =
        compactStyle ? actionButtonGapCompact : actionButtonGapRegular;
    final readIdealWidth = useShortLabels ? readShortWidth : readLongWidth;
    final shelfIdealWidth = useShortLabels ? shelfShortWidth : shelfLongWidth;
    final minPairWidth = shelfShortWidth * 2 + buttonGap;
    final idealPairWidth = readIdealWidth + shelfIdealWidth + buttonGap;

    if (availableWidth < minPairWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: double.infinity, child: readButton),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, child: shelfButton),
        ],
      );
    }

    if (availableWidth >= idealPairWidth) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: readIdealWidth, child: readButton),
          SizedBox(width: buttonGap),
          SizedBox(width: shelfIdealWidth, child: shelfButton),
        ],
      );
    }

    final equalWidth = (availableWidth - buttonGap) / 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: equalWidth, child: readButton),
        SizedBox(width: buttonGap),
        SizedBox(width: equalWidth, child: shelfButton),
      ],
    );
  }
}

class _ActionButtonContent extends StatelessWidget {
  const _ActionButtonContent({
    required this.icon,
    required this.label,
    required this.hideIcon,
  });

  final IconData icon;
  final String label;
  final bool hideIcon;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hideIcon) ...[Icon(icon, size: 14), const SizedBox(width: 3)],
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ],
      ),
    );
  }
}
