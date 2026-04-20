import 'package:flutter/material.dart';

class BookDetailPrimaryActions extends StatelessWidget {
  const BookDetailPrimaryActions({
    super.key,
    required this.availableWidth,
    required this.isInBookshelf,
    required this.isShelfActionLoading,
    required this.onToggleBookshelf,
    required this.onOpenCatalog,
    required this.onSwitchSource,
    required this.onOpenOrganize,
    this.isCatalogEnabled = true,
    this.isSwitchSourceEnabled = true,
    this.isOrganizeEnabled = true,
  });

  static const double actionButtonHeight = 62;
  static const double actionButtonGap = 4;

  final double availableWidth;
  final bool isInBookshelf;
  final bool isShelfActionLoading;
  final VoidCallback? onToggleBookshelf;
  final VoidCallback? onOpenCatalog;
  final VoidCallback? onSwitchSource;
  final VoidCallback? onOpenOrganize;
  final bool isCatalogEnabled;
  final bool isSwitchSourceEnabled;
  final bool isOrganizeEnabled;

  @override
  Widget build(BuildContext context) {
    final buttonTextStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.0);

    Widget buildAction({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
      bool enabled = true,
    }) {
      return SizedBox(
        height: actionButtonHeight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onPressed : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: _ActionButtonContent(
                icon: icon,
                label: label,
                textStyle: buttonTextStyle,
              ),
            ),
          ),
        ),
      );
    }

    final shelfButton = buildAction(
      key: const Key('book_detail_shelf_button'),
      icon:
          isInBookshelf
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
      label: '书架',
      onPressed: isShelfActionLoading ? null : onToggleBookshelf,
    );
    final catalogButton = buildAction(
      key: const Key('book_detail_catalog_button'),
      icon: Icons.menu_book_rounded,
      label: '目录',
      onPressed: onOpenCatalog,
      enabled: isCatalogEnabled,
    );
    final sourceButton = buildAction(
      key: const Key('book_detail_source_button'),
      icon: Icons.swap_horiz_rounded,
      label: '书源',
      onPressed: onSwitchSource,
      enabled: isSwitchSourceEnabled,
    );
    final cacheButton = buildAction(
      key: const Key('book_detail_cache_button'),
      icon: Icons.category_outlined,
      label: '归类',
      onPressed: onOpenOrganize,
      enabled: isOrganizeEnabled,
    );

    if (availableWidth < 320) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: shelfButton),
              const SizedBox(width: actionButtonGap),
              Expanded(child: catalogButton),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: sourceButton),
              const SizedBox(width: actionButtonGap),
              Expanded(child: cacheButton),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: shelfButton),
        const SizedBox(width: actionButtonGap),
        Expanded(child: catalogButton),
        const SizedBox(width: actionButtonGap),
        Expanded(child: sourceButton),
        const SizedBox(width: actionButtonGap),
        Expanded(child: cacheButton),
      ],
    );
  }
}

class _ActionButtonContent extends StatelessWidget {
  const _ActionButtonContent({
    required this.icon,
    required this.label,
    this.textStyle,
  });

  final IconData icon;
  final String label;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: textStyle?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
