import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/bottom_nav_icon_gallery.dart';
import '../navigation/bottom_nav_icon_resolver.dart';
import '../navigation/search_entry_transition.dart';
import '../shell_navigation_provider.dart';
import '../theme/app_component_theme_tokens.dart';
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
  static const double _kDockHeightWithLabels = 68;
  static const double _kDockHeightIconOnly = 58;
  static const double _kDockGap = 8;
  static const double _kDockBottomMinimum = 8;

  const CupertinoDockNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.showLabels,
    this.activeIconGallery,
    this.frostedEffect = false,
    this.themePalette,
    this.showSearchButton = true,
    required this.onDestinationSelected,
    required this.onSearchPressed,
  });

  final List<AppShellDestination> destinations;
  final int selectedIndex;
  final bool showLabels;
  final BottomNavIconGallery? activeIconGallery;
  final bool frostedEffect;
  final DockThemePalette? themePalette;
  final bool showSearchButton;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<BuildContext> onSearchPressed;

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
    final componentTokens = appComponentThemeTokensOf(context);
    final dockHeight =
        showLabels ? _kDockHeightWithLabels : _kDockHeightIconOnly;
    final dockRadius = dockHeight / 2;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final searchWidth = showLabels ? 68.0 : dockHeight;
          final searchHeight = dockHeight;
          final preferredDockWidth =
              showLabels
                  ? (destinations.length * 74.0) + 24
                  : (destinations.length * 62.0) + 20;
          final reservedSearchWidth =
              showSearchButton ? searchWidth + _kDockGap : 0.0;
          final maxDockWidth = constraints.maxWidth - reservedSearchWidth;
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
                  frostedEffect: frostedEffect,
                  navigationTokens: componentTokens.navigation,
                  child: SizedBox(
                    height: dockHeight,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        8,
                        showLabels ? 4 : 4,
                        8,
                        showLabels ? 3 : 4,
                      ),
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
                                itemRadius:
                                    componentTokens.navigation.dockItemRadius,
                                onTap: () => onDestinationSelected(index),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (showSearchButton) ...[
                const SizedBox(width: _kDockGap),
                _SearchIconButton(
                  width: searchWidth,
                  height: searchHeight,
                  showLabel: showLabels,
                  palette: palette,
                  frostedEffect: frostedEffect,
                  navigationTokens: componentTokens.navigation,
                  onPressed: onSearchPressed,
                ),
              ],
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
    required this.frostedEffect,
    required this.navigationTokens,
    required this.child,
  });

  final double radius;
  final _Md3DockPalette palette;
  final bool frostedEffect;
  final AppNavigationComponentTokens navigationTokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.containerColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: palette.borderColor,
          width: navigationTokens.dockSurfaceBorderWidth,
        ),
        boxShadow: [
          // UI-GOV-EXEMPT: box-shadow tokenized-component
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.028),
            blurRadius: navigationTokens.dockSurfaceShadowBlur,
            offset: Offset(0, navigationTokens.dockSurfaceShadowOffsetY),
          ),
        ],
      ),
      child: child,
    );
    if (!frostedEffect) {
      return decorated;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: navigationTokens.standardFrostedBlurSigmaFloating,
          sigmaY: navigationTokens.standardFrostedBlurSigmaFloating,
        ),
        child: decorated,
      ),
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
    required this.itemRadius,
    required this.onTap,
  });

  final AppShellDestination destination;
  final bool selected;
  final bool showLabel;
  final BottomNavIconGallery? activeIconGallery;
  final _Md3DockPalette palette;
  final double itemRadius;
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
            borderRadius: BorderRadius.circular(itemRadius),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: showLabel ? 2 : 2,
                vertical: 1,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: showLabel ? 42 : 40,
                    height: showLabel ? 27 : 31,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(itemRadius - 4),
                    ),
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        scale: selected ? 1 : 0.96,
                        child: BottomNavIconView(
                          icon: resolvedIcon,
                          size: showLabel ? 19 : 20,
                          fallbackColor: iconColor,
                        ),
                      ),
                    ),
                  ),
                  if (showLabel) ...[
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      style:
                          theme.textTheme.labelSmall?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 10.5,
                            height: 1.0,
                            letterSpacing: 0,
                            color: labelColor,
                          ) ??
                          TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 10.5,
                            height: 1.0,
                            letterSpacing: 0,
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
    required this.frostedEffect,
    required this.navigationTokens,
    required this.onPressed,
  });

  final double width;
  final double height;
  final bool showLabel;
  final _Md3DockPalette palette;
  final bool frostedEffect;
  final AppNavigationComponentTokens navigationTokens;
  final ValueChanged<BuildContext> onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    final searchSurface = Ink(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.containerColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: palette.borderColor,
          width: navigationTokens.dockSurfaceBorderWidth,
        ),
        boxShadow: [
          // UI-GOV-EXEMPT: box-shadow tokenized-component
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: navigationTokens.dockSearchShadowBlur,
            offset: Offset(0, navigationTokens.dockSearchShadowOffsetY),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.search,
          size: showLabel ? 20 : 21,
          color: palette.unselectedIconColor,
        ),
      ),
    );
    final clippedSearchSurface = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child:
          frostedEffect
              ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: navigationTokens.standardFrostedBlurSigmaFloating,
                  sigmaY: navigationTokens.standardFrostedBlurSigmaFloating,
                ),
                child: searchSurface,
              )
              : searchSurface,
    );

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
              onTap: () => onPressed(context),
              child: clippedSearchSurface,
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
