import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';

class AdaptiveListTile extends StatelessWidget {
  const AdaptiveListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.listTileMinHeight),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.symmetric(
                horizontal: metrics.cardPadding,
                vertical: metrics.isCompactDensity ? 6 : 8,
              ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: metrics.contentGap),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      subtitle!,
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: metrics.contentGap),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
