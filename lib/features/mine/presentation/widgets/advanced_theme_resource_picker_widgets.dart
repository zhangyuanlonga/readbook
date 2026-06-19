import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/navigation/bottom_nav_icon_gallery_tab_mapper.dart';
import '../../../../app/navigation/bottom_nav_icon_resolver.dart';
import '../../../../app/widgets/bottom_nav_icon_view.dart';
import '../../../../app/widgets/text_cover_placeholder.dart';
import '../../../../domain/entities/bottom_nav_icon_gallery.dart';

typedef AdvancedThemeResourceImageBuilder =
    Widget Function(BuildContext context, String path, BoxFit fit);

typedef AdvancedThemeImagePreviewCallback =
    void Function(String imagePath, String title);

class AdvancedThemeResourcePickerSheet extends StatelessWidget {
  const AdvancedThemeResourcePickerSheet({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    required this.heightFactor,
    this.helperText,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final double heightFactor;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * heightFactor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (helperText != null && helperText!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                helperText!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(child: content),
            const SizedBox(height: 12),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}

class AdvancedThemeEmptyResourceState extends StatelessWidget {
  const AdvancedThemeEmptyResourceState({
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class AdvancedThemeImageSelectionGrid extends StatelessWidget {
  const AdvancedThemeImageSelectionGrid({
    super.key,
    required this.imagePaths,
    required this.selectedPath,
    required this.titleBuilder,
    required this.onSelected,
    required this.imageBuilder,
    this.onPreview,
  });

  final List<String> imagePaths;
  final String? selectedPath;
  final String Function(String imagePath) titleBuilder;
  final ValueChanged<String> onSelected;
  final AdvancedThemeResourceImageBuilder imageBuilder;
  final AdvancedThemeImagePreviewCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns =
            AppLayout.optionGridColumnsForWidth(
              constraints.maxWidth,
            ).clamp(3, 5).toInt();
        return GridView.builder(
          itemCount: imagePaths.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 1 / 1.28,
          ),
          itemBuilder: (context, index) {
            final path = imagePaths[index];
            final title = titleBuilder(path);
            return _AdvancedThemeSelectableImageTile(
              imagePath: path,
              selected: path == selectedPath,
              imageBuilder: imageBuilder,
              onTap: () => onSelected(path),
              onLongPress:
                  onPreview == null ? null : () => onPreview!(path, title),
            );
          },
        );
      },
    );
  }
}

class _AdvancedThemeSelectableImageTile extends StatelessWidget {
  const _AdvancedThemeSelectableImageTile({
    required this.imagePath,
    required this.selected,
    required this.onTap,
    required this.imageBuilder,
    this.onLongPress,
  });

  final String imagePath;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final AdvancedThemeResourceImageBuilder imageBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        selected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant.withValues(
                              alpha: 0.45,
                            ),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageBuilder(context, imagePath, BoxFit.cover),
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AdvancedThemeGalleryPreviewThumb extends StatelessWidget {
  const AdvancedThemeGalleryPreviewThumb({
    super.key,
    required this.previewPath,
    required this.title,
    required this.imageBuilder,
    this.width = 34,
    this.height = 48,
    this.borderRadius = 8,
    this.useAddPlaceholder = false,
    this.onTap,
    this.onLongPress,
  });

  final String? previewPath;
  final String title;
  final AdvancedThemeResourceImageBuilder imageBuilder;
  final double width;
  final double height;
  final double borderRadius;
  final bool useAddPlaceholder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    late final Widget child;
    if (previewPath == null || previewPath!.isEmpty) {
      if (useAddPlaceholder) {
        child = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            Icons.add_rounded,
            size: width >= 40 ? 22 : 18,
            color: colorScheme.onSurfaceVariant,
          ),
        );
      } else {
        child = SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: TextCoverPlaceholder(
              title: title,
              width: width,
              height: height,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      }
    } else {
      child = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: imageBuilder(context, previewPath!, BoxFit.cover),
        ),
      );
    }

    if (onTap == null && onLongPress == null) {
      return child;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}

class AdvancedThemeBottomNavGalleryPreview extends StatelessWidget {
  const AdvancedThemeBottomNavGalleryPreview({
    super.key,
    required this.gallery,
  });

  final BottomNavIconGallery? gallery;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gallery = this.gallery;
    if (gallery == null) {
      return Container(
        width: 168,
        height: 62,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.add_rounded,
          size: 24,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Container(
      width: 190,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AdvancedThemeBottomNavGalleryPreviewRow(
            gallery: gallery,
            brightness: Brightness.light,
          ),
          const SizedBox(height: 5),
          _AdvancedThemeBottomNavGalleryPreviewRow(
            gallery: gallery,
            brightness: Brightness.dark,
          ),
        ],
      ),
    );
  }
}

class _AdvancedThemeBottomNavGalleryPreviewRow extends StatelessWidget {
  const _AdvancedThemeBottomNavGalleryPreviewRow({
    required this.gallery,
    required this.brightness,
  });

  final BottomNavIconGallery gallery;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.black.withValues(alpha: 0.78)
                : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in bottomNavIconGalleryTabs)
            for (final selected in const <bool>[false, true])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: BottomNavIconView(
                  icon: resolveCupertinoBottomNavIcon(
                    tab: appShellTabForBottomNavIconGalleryTab(tab),
                    selected: selected,
                    brightness: brightness,
                    gallery: gallery,
                  ),
                  size: 14,
                  fallbackColor:
                      selected
                          ? colorScheme.primary
                          : (isDark ? Colors.white70 : colorScheme.outline),
                ),
              ),
        ],
      ),
    );
  }
}
