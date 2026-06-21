import 'package:flutter/material.dart';

import '../../../../app/images/local_file_image.dart';
import '../../../../app/platform/app_input_focus_behavior.dart';
import '../../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../../app/widgets/adaptive_search_bar.dart';
import '../../../../app/widgets/foundation/foundation.dart';
import 'advanced_theme_resource_picker_widgets.dart';

Future<String?> showImageResourceNameSurface({
  required BuildContext context,
  required String title,
  required String initialValue,
  String labelText = '名称',
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 420,
      builder: (surfaceContext) {
        void submit() {
          Navigator.of(surfaceContext).pop(controller.text.trim());
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                surfaceContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: controller,
              autofocus: appEnableAutoFocusForTextInput,
              labelText: labelText,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(surfaceContext).pop(),
                  label: '取消',
                ),
                const SizedBox(width: 8),
                AppButton(onPressed: submit, label: '确定'),
              ],
            ),
          ],
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

Future<bool> showImageResourceConfirmSurface({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '确定',
  bool destructive = false,
}) async {
  final result = await showAdaptiveActionSurface<bool>(
    context: context,
    maxWidth: 420,
    builder: (surfaceContext) {
      final colorScheme = Theme.of(surfaceContext).colorScheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              surfaceContext,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(surfaceContext).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(surfaceContext).pop(false),
                label: '取消',
              ),
              const SizedBox(width: 8),
              AppButton(
                variant:
                    destructive
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                onPressed: () => Navigator.of(surfaceContext).pop(true),
                label: confirmLabel,
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class CompactCollectionSearchField extends StatelessWidget {
  const CompactCollectionSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AdaptiveSearchBar(
      controller: controller,
      hintText: hintText,
      height: 40,
      onChanged: onChanged,
      onClear: onClear,
    );
  }
}

class ImageResourceEmptyStateCard extends StatelessWidget {
  const ImageResourceEmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      kind: AppViewStateKind.empty,
      icon: icon,
      title: title,
      description: description,
    );
  }
}

class ImageResourceGalleryCard extends StatelessWidget {
  const ImageResourceGalleryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.preview,
    this.badges = const <Widget>[],
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.active = false,
  });

  final String title;
  final String subtitle;
  final Widget preview;
  final List<Widget> badges;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      backgroundColor:
          active
              ? colorScheme.secondaryContainer.withValues(alpha: 0.32)
              : colorScheme.surfaceContainerLow,
      borderColor:
          active
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (badges.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: Wrap(spacing: 6, runSpacing: 4, children: badges),
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          preview,
        ],
      ),
    );
  }
}

class ImageResourcePreviewSlot extends StatelessWidget {
  const ImageResourcePreviewSlot({
    super.key,
    required this.path,
    this.cacheWidth = 280,
    this.cacheHeight,
    this.borderRadius = 10,
    this.placeholderIcon = Icons.image_outlined,
    this.fit = BoxFit.cover,
  });

  final String? path;
  final int cacheWidth;
  final int? cacheHeight;
  final double borderRadius;
  final IconData placeholderIcon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AdvancedThemeVisualResourceFrame(
      width: double.infinity,
      height: double.infinity,
      dashedBorder: path == null,
      clip: true,
      radius: borderRadius,
      child:
          path == null
              ? ColoredBox(
                color: colorScheme.surfaceContainerLow,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
              : LazyFileImage(
                path: path!,
                fit: fit,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                placeholderIcon: Icons.broken_image_outlined,
              ),
    );
  }
}

class ImageResourcePill extends StatelessWidget {
  const ImageResourcePill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppSurface(
      tone: AppSurfaceTone.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      borderRadius: BorderRadius.circular(999),
      backgroundColor: colorScheme.surfaceContainerLow,
      borderColor: Colors.transparent,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class ImageResourceCornerHint extends StatelessWidget {
  const ImageResourceCornerHint({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ImageResourceUsageBadge extends StatelessWidget {
  const ImageResourceUsageBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.26)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ImageResourceSelectionBadge extends StatelessWidget {
  const ImageResourceSelectionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
    );
  }
}

class LazyFileImage extends StatelessWidget {
  const LazyFileImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.cacheWidth = 360,
    this.cacheHeight,
    this.placeholderIcon = Icons.image_outlined,
  });

  final String path;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int cacheWidth;
  final int? cacheHeight;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colorScheme.surfaceContainerLow,
      child: Center(
        child: Icon(placeholderIcon, color: colorScheme.onSurfaceVariant),
      ),
    );
    if (path.trim().startsWith('assets/')) {
      return _clipIfNeeded(
        Image.asset(
          path,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }
    return _clipIfNeeded(
      buildLocalFileImage(
        imagePath: path,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        fallback: fallback,
      ),
    );
  }

  Widget _clipIfNeeded(Widget child) {
    final radius = borderRadius;
    if (radius == null) {
      return child;
    }
    return ClipRRect(borderRadius: radius, child: child);
  }
}
