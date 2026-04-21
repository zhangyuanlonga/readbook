import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/bottom_nav_icon_gallery.dart';
import '../navigation/bottom_nav_icon_resolver.dart';
import '../navigation/search_entry_transition.dart';
import '../shell_navigation_provider.dart';
import 'bottom_nav_icon_view.dart';

class DockThemePalette {
  const DockThemePalette({
    required this.containerColor,
    required this.borderColor,
    required this.selectedIconColor,
    required this.unselectedIconColor,
    required this.selectedLabelColor,
    required this.unselectedLabelColor,
  });

  final Color containerColor;
  final Color borderColor;
  final Color selectedIconColor;
  final Color unselectedIconColor;
  final Color selectedLabelColor;
  final Color unselectedLabelColor;
}

class CupertinoDockNavigationBar extends StatelessWidget {
  static const double _kDockHeightWithLabels = 78;
  static const double _kDockHeightIconOnly = 64;
  static const double _kDockGap = 10;
  static const double _kDockBottomMinimum = 10;

  const CupertinoDockNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.showLabels,
    this.activeIconGallery,
    this.themePalette,
    required this.onDestinationSelected,
    required this.onSearchPressed,
  });

  final List<AppShellDestination> destinations;
  final int selectedIndex;
  final bool showLabels;
  final BottomNavIconGallery? activeIconGallery;
  final DockThemePalette? themePalette;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSearchPressed;

  static double contentBottomInset(
    BuildContext context, {
    required bool showLabels,
  }) {
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final dockHeight =
        showLabels ? _kDockHeightWithLabels : _kDockHeightIconOnly;
    return dockHeight + math.max(bottomSafe, _kDockBottomMinimum);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _Md3DockPalette.from(context, override: themePalette);
    final dockHeight =
        showLabels ? _kDockHeightWithLabels : _kDockHeightIconOnly;
    final dockRadius = dockHeight / 2;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final searchWidth = dockHeight;
          final searchHeight = dockHeight;
          final preferredDockWidth =
              showLabels
                  ? (destinations.length * 82.0) + 28
                  : (destinations.length * 66.0) + 24;
          final maxDockWidth = constraints.maxWidth - searchWidth - _kDockGap;
          final dockWidth =
              maxDockWidth <= 180
                  ? maxDockWidth
                  : preferredDockWidth.clamp(180.0, maxDockWidth);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: dockWidth,
                child: _DockSurface(
                  radius: dockRadius,
                  palette: palette,
                  child: SizedBox(
                    height: dockHeight,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(8, showLabels ? 6 : 5, 8, 5),
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < destinations.length;
                            index++
                          )
                            Expanded(
                              child: _DockItem(
                                destination: destinations[index],
                                selected: index == selectedIndex,
                                showLabel: showLabels,
                                activeIconGallery: activeIconGallery,
                                palette: palette,
                                onTap: () => onDestinationSelected(index),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _SearchIconButton(
                width: searchWidth,
                height: searchHeight,
                showLabel: showLabels,
                palette: palette,
                onPressed: onSearchPressed,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DockSurface extends StatelessWidget {
  const _DockSurface({
    required this.radius,
    required this.palette,
    required this.child,
  });

  final double radius;
  final _Md3DockPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.containerColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.destination,
    required this.selected,
    required this.showLabel,
    required this.activeIconGallery,
    required this.palette,
    required this.onTap,
  });

  final AppShellDestination destination;
  final bool selected;
  final bool showLabel;
  final BottomNavIconGallery? activeIconGallery;
  final _Md3DockPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedIcon = resolveCupertinoBottomNavIcon(
      tab: destination.tab,
      selected: selected,
      brightness: theme.brightness,
      gallery: activeIconGallery,
    );
    final iconColor =
        selected ? palette.selectedIconColor : palette.unselectedIconColor;
    final labelColor =
        selected ? palette.selectedLabelColor : palette.unselectedLabelColor;

    return Tooltip(
      message: destination.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: showLabel ? 4 : 2,
                vertical: showLabel ? 3 : 2,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: showLabel ? 50 : 44,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        scale: selected ? 1 : 0.96,
                        child: BottomNavIconView(
                          icon: resolvedIcon,
                          size: 21,
                          fallbackColor: iconColor,
                        ),
                      ),
                    ),
                  ),
                  if (showLabel) ...[
                    const SizedBox(height: 5),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      style:
                          theme.textTheme.labelSmall?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 10,
                            height: 1,
                            letterSpacing: 0.02,
                            color: labelColor,
                          ) ??
                          TextStyle(
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 10,
                            height: 1,
                            letterSpacing: 0.02,
                            color: labelColor,
                          ),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchIconButton extends StatelessWidget {
  const _SearchIconButton({
    required this.width,
    required this.height,
    required this.showLabel,
    required this.palette,
    required this.onPressed,
  });

  final double width;
  final double height;
  final bool showLabel;
  final _Md3DockPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;

    return Hero(
      tag: kSearchEntryHeroTag,
      createRectTween:
          (begin, end) => MaterialRectCenterArcTween(begin: begin, end: end),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: '搜索',
          child: Semantics(
            button: true,
            label: '搜索',
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onPressed,
              child: Ink(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: palette.containerColor,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: palette.borderColor, width: 0.8),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.search,
                    size: 21,
                    color: palette.unselectedIconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Md3DockPalette {
  const _Md3DockPalette({
    required this.containerColor,
    required this.borderColor,
    required this.selectedIconColor,
    required this.unselectedIconColor,
    required this.selectedLabelColor,
    required this.unselectedLabelColor,
  });

  factory _Md3DockPalette.from(
    BuildContext context, {
    DockThemePalette? override,
  }) {
    if (override != null) {
      return _Md3DockPalette(
        containerColor: override.containerColor,
        borderColor: override.borderColor,
        selectedIconColor: override.selectedIconColor,
        unselectedIconColor: override.unselectedIconColor,
        selectedLabelColor: override.selectedLabelColor,
        unselectedLabelColor: override.unselectedLabelColor,
      );
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final navigationBarTheme = NavigationBarTheme.of(context);
    final isDark = colorScheme.brightness == Brightness.dark;
    final selectedState = <WidgetState>{WidgetState.selected};
    final unselectedState = <WidgetState>{};
    final selectedIconTheme = navigationBarTheme.iconTheme?.resolve(
      selectedState,
    );
    final unselectedIconTheme = navigationBarTheme.iconTheme?.resolve(
      unselectedState,
    );
    final selectedLabelStyle = navigationBarTheme.labelTextStyle?.resolve(
      selectedState,
    );
    final unselectedLabelStyle = navigationBarTheme.labelTextStyle?.resolve(
      unselectedState,
    );
    final selectedIconColor =
        selectedIconTheme?.color ?? colorScheme.onSecondaryContainer;
    final unselectedIconColor =
        unselectedIconTheme?.color ?? colorScheme.onSurfaceVariant;

    return _Md3DockPalette(
      containerColor:
          navigationBarTheme.backgroundColor ?? colorScheme.surfaceContainer,
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.92),
      selectedIconColor: selectedIconColor,
      unselectedIconColor: unselectedIconColor,
      selectedLabelColor:
          selectedLabelStyle?.color ??
          Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.18),
            selectedIconColor,
          ),
      unselectedLabelColor:
          unselectedLabelStyle?.color ??
          unselectedIconColor.withValues(alpha: isDark ? 0.88 : 0.82),
    );
  }

  final Color containerColor;
  final Color borderColor;
  final Color selectedIconColor;
  final Color unselectedIconColor;
  final Color selectedLabelColor;
  final Color unselectedLabelColor;
}
