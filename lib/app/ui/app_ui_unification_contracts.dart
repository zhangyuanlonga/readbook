import 'package:flutter/material.dart';

enum AppPageSkeletonKind { shell, independentRoute, immersiveReader }

enum AppOperationSurfaceKind {
  adaptiveActionSurface,
  adaptiveRawSurface,
  adaptiveOverflowToolbar,
  contextMenu,
}

enum AppStateComponentKind {
  loading,
  empty,
  error,
  permissionDenied,
  platformUnavailable,
}

enum AppToolbarCapability {
  search,
  sort,
  filter,
  viewMode,
  importExport,
  overflow,
}

enum AppTokenDomain { color, radius, spacing, shadow, typography, divider }

enum AppDesktopInteractionState {
  hover,
  focus,
  selected,
  disabled,
  loading,
  shortcut,
  contextMenu,
}

enum AppMobileAdaptiveRule {
  touchTarget,
  safeArea,
  textScale,
  bottomSheetHeight,
  smallScreenOverflow,
}

class AppUiUnificationContract {
  const AppUiUnificationContract({
    required this.pageSkeletons,
    required this.operationSurfaces,
    required this.stateComponents,
    required this.toolbarCapabilities,
    required this.tokenDomains,
    required this.desktopInteractionStates,
    required this.mobileAdaptiveRules,
  });

  final Set<AppPageSkeletonKind> pageSkeletons;
  final Set<AppOperationSurfaceKind> operationSurfaces;
  final Set<AppStateComponentKind> stateComponents;
  final Set<AppToolbarCapability> toolbarCapabilities;
  final Set<AppTokenDomain> tokenDomains;
  final Set<AppDesktopInteractionState> desktopInteractionStates;
  final Set<AppMobileAdaptiveRule> mobileAdaptiveRules;

  static const baseline = AppUiUnificationContract(
    pageSkeletons: <AppPageSkeletonKind>{
      AppPageSkeletonKind.shell,
      AppPageSkeletonKind.independentRoute,
      AppPageSkeletonKind.immersiveReader,
    },
    operationSurfaces: <AppOperationSurfaceKind>{
      AppOperationSurfaceKind.adaptiveActionSurface,
      AppOperationSurfaceKind.adaptiveRawSurface,
      AppOperationSurfaceKind.adaptiveOverflowToolbar,
      AppOperationSurfaceKind.contextMenu,
    },
    stateComponents: <AppStateComponentKind>{
      AppStateComponentKind.loading,
      AppStateComponentKind.empty,
      AppStateComponentKind.error,
      AppStateComponentKind.permissionDenied,
      AppStateComponentKind.platformUnavailable,
    },
    toolbarCapabilities: <AppToolbarCapability>{
      AppToolbarCapability.search,
      AppToolbarCapability.sort,
      AppToolbarCapability.filter,
      AppToolbarCapability.viewMode,
      AppToolbarCapability.importExport,
      AppToolbarCapability.overflow,
    },
    tokenDomains: <AppTokenDomain>{
      AppTokenDomain.color,
      AppTokenDomain.radius,
      AppTokenDomain.spacing,
      AppTokenDomain.shadow,
      AppTokenDomain.typography,
      AppTokenDomain.divider,
    },
    desktopInteractionStates: <AppDesktopInteractionState>{
      AppDesktopInteractionState.hover,
      AppDesktopInteractionState.focus,
      AppDesktopInteractionState.selected,
      AppDesktopInteractionState.disabled,
      AppDesktopInteractionState.loading,
      AppDesktopInteractionState.shortcut,
      AppDesktopInteractionState.contextMenu,
    },
    mobileAdaptiveRules: <AppMobileAdaptiveRule>{
      AppMobileAdaptiveRule.touchTarget,
      AppMobileAdaptiveRule.safeArea,
      AppMobileAdaptiveRule.textScale,
      AppMobileAdaptiveRule.bottomSheetHeight,
      AppMobileAdaptiveRule.smallScreenOverflow,
    },
  );

  bool get coversBl06 {
    return pageSkeletons.length == AppPageSkeletonKind.values.length &&
        operationSurfaces.length == AppOperationSurfaceKind.values.length &&
        stateComponents.length == AppStateComponentKind.values.length &&
        toolbarCapabilities.length == AppToolbarCapability.values.length &&
        tokenDomains.length == AppTokenDomain.values.length &&
        desktopInteractionStates.length ==
            AppDesktopInteractionState.values.length &&
        mobileAdaptiveRules.length == AppMobileAdaptiveRule.values.length;
  }
}

class AppMobileInteractionPolicy {
  const AppMobileInteractionPolicy({
    this.minTouchTarget = 44,
    this.maxBottomSheetHeightFactor = 0.92,
    this.maxCompactTextScale = 1.35,
    this.smallScreenOverflowWidth = 390,
  });

  final double minTouchTarget;
  final double maxBottomSheetHeightFactor;
  final double maxCompactTextScale;
  final double smallScreenOverflowWidth;

  EdgeInsets safeAreaPaddingFor(EdgeInsets viewPadding) {
    return EdgeInsets.only(
      left: viewPadding.left,
      right: viewPadding.right,
      bottom: viewPadding.bottom,
    );
  }

  bool shouldPreferOverflow(double width) {
    return width <= smallScreenOverflowWidth;
  }
}

class AppDesktopInteractionPolicy {
  const AppDesktopInteractionPolicy({
    this.hoverAlpha = 0.08,
    this.focusAlpha = 0.14,
    this.selectedAlpha = 0.16,
    this.disabledAlpha = 0.38,
    this.loadingAlpha = 0.62,
  });

  final double hoverAlpha;
  final double focusAlpha;
  final double selectedAlpha;
  final double disabledAlpha;
  final double loadingAlpha;

  Color overlayColor({
    required Color baseColor,
    required AppDesktopInteractionState state,
  }) {
    final alpha = switch (state) {
      AppDesktopInteractionState.hover => hoverAlpha,
      AppDesktopInteractionState.focus => focusAlpha,
      AppDesktopInteractionState.selected => selectedAlpha,
      AppDesktopInteractionState.disabled => disabledAlpha,
      AppDesktopInteractionState.loading => loadingAlpha,
      AppDesktopInteractionState.shortcut => focusAlpha,
      AppDesktopInteractionState.contextMenu => hoverAlpha,
    };
    return baseColor.withValues(alpha: alpha);
  }
}
