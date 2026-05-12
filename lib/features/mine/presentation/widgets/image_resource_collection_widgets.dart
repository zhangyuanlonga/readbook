import 'package:flutter/material.dart';

import '../../../../app/images/local_file_image.dart';
import '../../../../app/widgets/app_empty_state_card.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.15),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest.withValues(alpha: 0.92),
        hintText: hintText,
        hintStyle: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 38,
        ),
        suffixIcon:
            query.trim().isEmpty
                ? null
                : IconButton(
                  tooltip: '清空搜索',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 38,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.7),
          ),
        ),
      ),
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
    return AppEmptyStateCard(
      icon: icon,
      title: title,
      description: description,
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
