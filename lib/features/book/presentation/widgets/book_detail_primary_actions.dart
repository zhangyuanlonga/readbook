import 'package:flutter/material.dart';

class BookDetailPrimaryActions extends StatelessWidget {
  const BookDetailPrimaryActions({
    super.key,
    required this.availableWidth,
    required this.isInBookshelf,
    required this.isShelfStateLoading,
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
  final bool isShelfStateLoading;
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
      required Widget icon,
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

    final showShelfProgress = isShelfActionLoading;
    final isShelfUnavailable = isShelfStateLoading || isShelfActionLoading;
    final shelfButton = buildAction(
      key: const Key('book_detail_shelf_button'),
      icon:
          showShelfProgress
              ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
              : Icon(
                isInBookshelf
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
      label: '书架',
      onPressed: isShelfUnavailable ? null : onToggleBookshelf,
    );
    final catalogButton = buildAction(
      key: const Key('book_detail_catalog_button'),
      icon: Icon(
        Icons.menu_book_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      label: '目录',
      onPressed: onOpenCatalog,
      enabled: isCatalogEnabled,
    );
    final sourceButton = buildAction(
      key: const Key('book_detail_source_button'),
      icon: Icon(
        Icons.swap_horiz_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      label: '书源',
      onPressed: onSwitchSource,
      enabled: isSwitchSourceEnabled,
    );
    final cacheButton = buildAction(
      key: const Key('book_detail_cache_button'),
      icon: Icon(
        Icons.category_outlined,
        size: 18,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      label: '归类',
      onPressed: onOpenOrganize,
      enabled: isOrganizeEnabled,
    );

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

  final Widget icon;
  final String label;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: textStyle?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
