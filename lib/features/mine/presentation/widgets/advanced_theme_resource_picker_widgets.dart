import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/navigation/bottom_nav_icon_gallery_tab_mapper.dart';
import '../../../../app/navigation/bottom_nav_icon_resolver.dart';
import '../../../../app/theme/app_component_theme_tokens.dart';
import '../../../../app/widgets/bottom_nav_icon_view.dart';
import '../../../../app/widgets/foundation/foundation.dart';
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
    return AppStateView(
      kind: AppViewStateKind.empty,
      icon: icon,
      title: title,
      description: description,
      compact: true,
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
    final componentTokens = appComponentThemeTokensOf(context);
    final tileRadius = BorderRadius.all(
      Radius.circular(componentTokens.card.radius),
    );
    return AppSurface(
      padding: EdgeInsets.zero,
      borderRadius: tileRadius,
      clipBehavior: Clip.antiAlias,
      backgroundColor: colorScheme.surface,
      borderColor:
          selected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Positioned.fill(
            child: imageBuilder(context, imagePath, BoxFit.cover),
          ),
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: colorScheme.primary,
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
        ],
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
    final componentTokens = appComponentThemeTokensOf(context);
    final previewRadius = BorderRadius.all(
      Radius.circular(
        borderRadius == 8 ? componentTokens.button.radius : borderRadius,
      ),
    );
    final previewBorderColor = colorScheme.outlineVariant.withValues(
      alpha: 0.4,
    );
    late final Widget child;
    if (previewPath == null || previewPath!.isEmpty) {
      if (useAddPlaceholder) {
        child = SizedBox(
          width: width,
          height: height,
          child: AppSurface(
            padding: EdgeInsets.zero,
            borderRadius: previewRadius,
            backgroundColor: colorScheme.surface,
            borderColor: previewBorderColor,
            child: Icon(
              Icons.add_rounded,
              size: width >= 40 ? 22 : 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
      } else {
        child = SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: previewRadius,
            child: TextCoverPlaceholder(
              title: title,
              width: width,
              height: height,
              borderRadius: previewRadius,
            ),
          ),
        );
      }
    } else {
      child = SizedBox(
        width: width,
        height: height,
        child: AppSurface(
          padding: EdgeInsets.zero,
          borderRadius: previewRadius,
          backgroundColor: colorScheme.surface,
          borderColor: previewBorderColor,
          clipBehavior: Clip.antiAlias,
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
        borderRadius: previewRadius,
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
    final componentTokens = appComponentThemeTokensOf(context);
    final previewRadius = BorderRadius.all(
      Radius.circular(componentTokens.card.radius),
    );
    final previewBorderColor = colorScheme.outlineVariant.withValues(
      alpha: 0.4,
    );
    final gallery = this.gallery;
    if (gallery == null) {
      return SizedBox(
        width: 168,
        height: 62,
        child: AppSurface(
          padding: EdgeInsets.zero,
          borderRadius: previewRadius,
          backgroundColor: colorScheme.surface,
          borderColor: previewBorderColor,
          child: Center(
            child: Icon(
              Icons.add_rounded,
              size: 24,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 190,
      child: AppSurface(
        padding: const EdgeInsets.all(6),
        borderRadius: previewRadius,
        backgroundColor: colorScheme.surface,
        borderColor: previewBorderColor,
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
    final componentTokens = appComponentThemeTokensOf(context);
    final isDark = brightness == Brightness.dark;
    final rowRadius = BorderRadius.all(
      Radius.circular(componentTokens.button.radius),
    );
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      borderRadius: rowRadius,
      backgroundColor:
          isDark ? colorScheme.inverseSurface : colorScheme.surfaceContainerLow,
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
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
                          : (isDark
                              ? colorScheme.onInverseSurface
                              : colorScheme.outline),
                ),
              ),
        ],
      ),
    );
  }
}
