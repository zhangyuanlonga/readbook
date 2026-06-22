import 'package:flutter/material.dart';

import '../../reader_icons.dart';

import '../../../../../app/widgets/foundation/foundation.dart';

class ReaderSettingsSectionCard extends StatelessWidget {
  const ReaderSettingsSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.compactScale = 1,
    this.interactionPreviewActive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final double compactScale;
  final bool interactionPreviewActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppSurface(
      margin: EdgeInsets.only(bottom: _scale(8)),
      padding: EdgeInsets.all(_scale(10)),
      borderRadius: BorderRadius.circular(_scale(16)),
      backgroundColor: _interactiveCardColor(
        context,
        colorScheme.surfaceContainerLow,
        alpha: 0.54,
      ),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _scale(26),
                height: _scale(26),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(_scale(9)),
                ),
                child: Icon(
                  icon,
                  size: _scale(14),
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: _scale(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize:
                            (textTheme.titleSmall?.fontSize ?? 14) *
                            compactScale *
                            0.92,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      SizedBox(height: _scale(1)),
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                          fontSize:
                              (textTheme.bodySmall?.fontSize ?? 12) *
                              compactScale *
                              0.92,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: _scale(10)),
          ...children,
        ],
      ),
    );
  }

  double _scale(double value) => value * compactScale;

  Color _interactiveCardColor(
    BuildContext context,
    Color baseColor, {
    required double alpha,
  }) {
    final brightness = Theme.of(context).brightness;
    final targetAlpha =
        interactionPreviewActive
            ? (brightness == Brightness.dark ? alpha * 0.08 : alpha * 0.18)
                .clamp(0.0, 1.0)
            : alpha.clamp(0.0, 1.0);
    return baseColor.withValues(alpha: targetAlpha);
  }
}

class ReaderSettingsGroupEntryCard extends StatelessWidget {
  const ReaderSettingsGroupEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compactScale = 1,
    this.interactionPreviewActive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double compactScale;
  final bool interactionPreviewActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppSurface(
      onTap: onTap,
      padding: EdgeInsets.fromLTRB(
        _scale(12),
        _scale(10),
        _scale(12),
        _scale(10),
      ),
      borderRadius: BorderRadius.circular(_scale(16)),
      backgroundColor: _interactiveCardColor(
        context,
        colorScheme.surfaceContainerLow,
        alpha: 0.54,
      ),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.38),
      child: Row(
        children: [
          Container(
            width: _scale(28),
            height: _scale(28),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(_scale(10)),
            ),
            child: Icon(
              icon,
              size: _scale(14),
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          SizedBox(width: _scale(9)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize:
                        (textTheme.titleSmall?.fontSize ?? 14) *
                        compactScale *
                        0.92,
                  ),
                ),
                SizedBox(height: _scale(2)),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                    fontSize:
                        (textTheme.bodySmall?.fontSize ?? 12) *
                        compactScale *
                        0.92,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: _scale(6)),
          Icon(
            ReaderIcons.disclosure,
            color: colorScheme.onSurfaceVariant,
            size: _scale(18),
          ),
        ],
      ),
    );
  }

  double _scale(double value) => value * compactScale;

  Color _interactiveCardColor(
    BuildContext context,
    Color baseColor, {
    required double alpha,
  }) {
    final brightness = Theme.of(context).brightness;
    final targetAlpha =
        interactionPreviewActive
            ? (brightness == Brightness.dark ? alpha * 0.08 : alpha * 0.18)
                .clamp(0.0, 1.0)
            : alpha.clamp(0.0, 1.0);
    return baseColor.withValues(alpha: targetAlpha);
  }
}

class ReaderSettingsOwnershipHintCard extends StatelessWidget {
  const ReaderSettingsOwnershipHintCard({
    super.key,
    required this.title,
    required this.description,
    this.compactScale = 1,
  });

  final String title;
  final String description;
  final double compactScale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppSurface(
      margin: EdgeInsets.only(bottom: _scale(8)),
      padding: EdgeInsets.fromLTRB(
        _scale(12),
        _scale(10),
        _scale(12),
        _scale(10),
      ),
      borderRadius: BorderRadius.circular(_scale(16)),
      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.22),
      borderColor: colorScheme.primary.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: _scale(4)),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  double _scale(double value) => value * compactScale;
}

class ReaderSettingsToggleRow extends StatelessWidget {
  const ReaderSettingsToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isSaving = false,
    this.compactScale = 1,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isSaving;
  final double compactScale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _scale(1)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize:
                    (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) *
                    compactScale *
                    0.94,
              ),
            ),
          ),
          if (isSaving)
            Padding(
              padding: EdgeInsets.only(right: _scale(8)),
              child: AppProgressIndicator(
                size: _scale(16),
                strokeWidth: 2,
                semanticLabel: '保存设置',
              ),
            ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  double _scale(double value) => value * compactScale;
}

class ReaderSettingsDivider extends StatelessWidget {
  const ReaderSettingsDivider({super.key, this.compactScale = 1});

  final double compactScale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.5 * compactScale),
      child: Divider(
        height: 1,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }
}

class ReaderSettingsCompactTitle extends StatelessWidget {
  const ReaderSettingsCompactTitle({
    super.key,
    required this.title,
    this.trailing,
    this.compactScale = 1,
  });

  final String title;
  final Widget? trailing;
  final double compactScale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            fontSize:
                (Theme.of(context).textTheme.titleSmall?.fontSize ?? 14) *
                compactScale *
                0.9,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class ReaderSettingsCard extends StatelessWidget {
  const ReaderSettingsCard({
    super.key,
    required this.children,
    this.compactScale = 1,
    this.interactionPreviewActive = false,
  });

  final List<Widget> children;
  final double compactScale;
  final bool interactionPreviewActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppSurface(
      margin: EdgeInsets.only(bottom: 8 * compactScale),
      padding: EdgeInsets.all(12 * compactScale),
      borderRadius: BorderRadius.circular(18 * compactScale),
      backgroundColor: _interactiveCardColor(
        context,
        colorScheme.surfaceContainerLow,
        alpha: 0.54,
      ),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.32),
      child: Column(children: children),
    );
  }

  Color _interactiveCardColor(
    BuildContext context,
    Color baseColor, {
    required double alpha,
  }) {
    final brightness = Theme.of(context).brightness;
    final targetAlpha =
        interactionPreviewActive
            ? (brightness == Brightness.dark ? alpha * 0.08 : alpha * 0.18)
                .clamp(0.0, 1.0)
            : alpha.clamp(0.0, 1.0);
    return baseColor.withValues(alpha: targetAlpha);
  }
}

class ReaderSettingsLabeledRow extends StatelessWidget {
  const ReaderSettingsLabeledRow({
    super.key,
    required this.label,
    required this.child,
    this.compactScale = 1,
  });

  final String label;
  final Widget child;
  final double compactScale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10 * compactScale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 68 * compactScale,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize:
                    (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) *
                    compactScale *
                    0.92,
              ),
            ),
          ),
          SizedBox(width: 10 * compactScale),
          Expanded(child: child),
        ],
      ),
    );
  }
}
