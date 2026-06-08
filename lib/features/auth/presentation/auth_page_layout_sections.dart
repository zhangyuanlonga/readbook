part of 'auth_page.dart';

extension _AuthPageLayoutSections on _AuthPageState {
  Widget _buildDesktopAuthPage(
    BuildContext context, {
    required double keyboardInset,
    required double bottomSafe,
    required ColorScheme colorScheme,
  }) {
    final backgroundColor = colorScheme.surface;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: backgroundColor,
      body: AnimatedPadding(
        duration: _authKeyboardInsetAnimationDuration,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isTwoPane = width >= 1100;
            final horizontalPadding = width >= 1320 ? 64.0 : 32.0;
            final verticalPadding = constraints.maxHeight >= 840 ? 56.0 : 32.0;

            if (!isTwoPane) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(32, 32, 32, 32 + bottomSafe),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 520,
                      minHeight: (constraints.maxHeight - 64 - bottomSafe)
                          .clamp(0.0, double.infinity),
                    ),
                    child: AppFadeSlideTransition(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDesktopCompactHeader(context, colorScheme),
                          const SizedBox(height: 24),
                          _buildDesktopAuthSurface(context, colorScheme),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final viewportHeight = (constraints.maxHeight - bottomSafe).clamp(
              0.0,
              double.infinity,
            );
            final desktopShellMaxWidth = width >= 1440 ? 1240.0 : 1160.0;
            final availableWidth = (width - horizontalPadding * 2).clamp(
              0.0,
              double.infinity,
            );
            final shellWidth = availableWidth.clamp(0.0, desktopShellMaxWidth);
            final shellHeight = (viewportHeight - verticalPadding * 2).clamp(
              620.0,
              740.0,
            );
            final leftPaneRatio = (((shellWidth - 1040.0) / 240.0) * 0.03 +
                    0.42)
                .clamp(0.42, 0.45);
            final leftPaneWidth = shellWidth * leftPaneRatio;
            final rightPaneWidth = shellWidth - leftPaneWidth;
            final leftPaneFlex = (leftPaneRatio * 1000).round();
            final rightPaneFlex = 1000 - leftPaneFlex;
            final leftInset = (leftPaneWidth * 0.12).clamp(44.0, 64.0);
            final brandTopInset = shellHeight >= 720 ? 48.0 : 40.0;
            final formMaxWidth = (rightPaneWidth * 0.72).clamp(420.0, 500.0);
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: bottomSafe),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewportHeight),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: AppFadeSlideTransition(
                      child: SizedBox(
                        width: shellWidth,
                        height: shellHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(
                              _authDesktopPanelRadius,
                            ),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.72,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(
                                  alpha: 0.05,
                                ),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: leftPaneFlex,
                                child: _buildDesktopBrandPanel(
                                  context,
                                  colorScheme: colorScheme,
                                  contentPadding: EdgeInsets.fromLTRB(
                                    leftInset,
                                    brandTopInset,
                                    48,
                                    44,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: rightPaneFlex,
                                child: _buildDesktopAuthSurface(
                                  context,
                                  colorScheme,
                                  embedInSplitLayout: true,
                                  formMaxWidth: formMaxWidth,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileAuthPage(
    BuildContext context, {
    required double keyboardInset,
    required double bottomSafe,
    required double horizontal,
    required ColorScheme colorScheme,
  }) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colorScheme.surface,
      body: AnimatedPadding(
        duration: _authKeyboardInsetAnimationDuration,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight;
            final width = constraints.maxWidth;
            final topSafe = MediaQuery.viewPaddingOf(context).top;
            final isMediumWidth = width >= AppLayout.mediumBreakpointWidth;
            final isCompactLandscape =
                width > constraints.maxHeight && viewportHeight < 520;
            final baseBrandHeight =
                isCompactLandscape
                    ? (viewportHeight * 0.32).clamp(112.0, 142.0)
                    : isMediumWidth
                    ? 176.0
                    : (viewportHeight * 0.2).clamp(152.0, 194.0);
            final brandHeight = baseBrandHeight + topSafe.clamp(0.0, 42.0);
            final panelMinHeight = (viewportHeight - brandHeight).clamp(
              isMediumWidth ? 420.0 : 390.0,
              double.infinity,
            );
            final contentMaxWidth =
                isMediumWidth
                    ? _authMediumContentMaxWidth
                    : AppLayout.pageContentMaxWidth(
                      context,
                      maxWidth: AppLayout.settingsContentMaxWidth,
                    );
            final pageHorizontalPadding = isMediumWidth ? 24.0 : 0.0;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewportHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: pageHorizontalPadding,
                      ),
                      child: Column(
                        children: [
                          _buildMobileBrandHeader(
                            context,
                            height: brandHeight,
                            colorScheme: colorScheme,
                            mediumWidth: isMediumWidth,
                          ),
                          SizedBox(height: isMediumWidth ? 8 : 0),
                          _buildMobileAuthPanel(
                            context,
                            colorScheme: colorScheme,
                            horizontal: horizontal,
                            minHeight: panelMinHeight,
                            bottomSafe: bottomSafe,
                            mediumWidth: isMediumWidth,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _authPrimaryColor(ColorScheme colorScheme) => colorScheme.primary;

  Color _authQuietSurfaceColor(ColorScheme colorScheme) {
    return Color.lerp(
      colorScheme.surfaceContainerLow,
      colorScheme.surfaceContainerLowest,
      0.62,
    )!;
  }

  Color _authFieldSurfaceColor(ColorScheme colorScheme) {
    return Color.lerp(
      colorScheme.surfaceContainerLowest,
      colorScheme.surfaceContainerLow,
      0.28,
    )!;
  }

  Color _authDecorativeSurfaceColor(ColorScheme colorScheme) {
    return Color.lerp(
      colorScheme.surface,
      colorScheme.surfaceContainerLow,
      0.5,
    )!;
  }

  Widget _buildMobileBrandHeader(
    BuildContext context, {
    required double height,
    required ColorScheme colorScheme,
    required bool mediumWidth,
  }) {
    final topSafe = MediaQuery.viewPaddingOf(context).top;
    final textTheme = Theme.of(context).textTheme;
    final availableHeight = height - topSafe;
    final isCompactLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height &&
        height < 190;
    final isTightHeader = availableHeight < 240;
    return Container(
      key: const ValueKey<String>('auth_mobile_brand_header'),
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(color: colorScheme.surface),
      child: Stack(
        children: [
          Positioned(
            right: mediumWidth ? 18 : -26,
            top: topSafe + (isCompactLandscape ? 2 : 20),
            child: _buildReadingWatermark(
              size:
                  isCompactLandscape
                      ? 104
                      : isTightHeader
                      ? 128
                      : 154,
              opacity: 0.055,
              color: colorScheme.primary,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              mediumWidth ? 8 : 24,
              topSafe + (isCompactLandscape ? 14 : 24),
              mediumWidth ? 8 : 24,
              isCompactLandscape ? 12 : 20,
            ),
            child: Align(
              alignment: mediumWidth ? Alignment.center : Alignment.centerLeft,
              child:
                  isCompactLandscape
                      ? _buildAuthWordmark(
                        context,
                        colorScheme,
                        alignment:
                            mediumWidth
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                        compact: true,
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            mediumWidth
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                        children: [
                          _buildAuthWordmark(
                            context,
                            colorScheme,
                            alignment:
                                mediumWidth
                                    ? CrossAxisAlignment.center
                                    : CrossAxisAlignment.start,
                          ),
                          const SizedBox(height: 8),
                          AppAnimatedSwitcher(
                            child: Text(
                              _isRegister ? '注册后即可继续进入书架。' : '请登录您的账户。',
                              key: ValueKey<String>(
                                _isRegister
                                    ? 'auth_mobile_subtitle_register'
                                    : 'auth_mobile_subtitle_login',
                              ),
                              textAlign:
                                  mediumWidth
                                      ? TextAlign.center
                                      : TextAlign.start,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.38,
                              ),
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAuthPanel(
    BuildContext context, {
    required ColorScheme colorScheme,
    required double horizontal,
    required double minHeight,
    required double bottomSafe,
    required bool mediumWidth,
  }) {
    final panelRadius = BorderRadius.vertical(
      top: const Radius.circular(_authMobilePanelRadius),
      bottom: Radius.circular(mediumWidth ? _authMobilePanelRadius : 0),
    );
    return Container(
      key: const ValueKey<String>('auth_mobile_form_panel'),
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        borderRadius: panelRadius,
        boxShadow:
            mediumWidth
                ? [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
                : null,
      ),
      child: ClipRRect(
        borderRadius: panelRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _authFieldSurfaceColor(colorScheme),
            border:
                mediumWidth
                    ? Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                    )
                    : null,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              mediumWidth ? 28 : horizontal.clamp(24.0, 34.0),
              mediumWidth ? 28 : 24,
              mediumWidth ? 28 : horizontal.clamp(24.0, 34.0),
              (mediumWidth ? 24 : 16) + bottomSafe,
            ),
            child: AppFadeSlideTransition(
              child: AnimatedSize(
                duration: _authModeTransitionDuration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModeToggle(colorScheme, immersiveStyled: true),
                    const SizedBox(height: 22),
                    AppAnimatedSwitcher(
                      child:
                          _submitError == null
                              ? const SizedBox.shrink(
                                key: ValueKey('auth_no_error'),
                              )
                              : _buildInlineError(context, _submitError!),
                    ),
                    if (_submitError != null) const SizedBox(height: 16),
                    _buildAnimatedForm(context, immersiveStyled: true),
                    if (!_isRegister) ...[
                      const SizedBox(height: 12),
                      _buildDesktopLoginActionRow(context, colorScheme),
                    ],
                    const SizedBox(height: 16),
                    _buildSubmitButton(immersiveStyled: true),
                    const SizedBox(height: 10),
                    _buildModeSwitchButton(context, colorScheme),
                    const SizedBox(height: 12),
                    _buildAgreementFooter(
                      context,
                      colorScheme,
                      immersiveStyled: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthGlyph(ColorScheme colorScheme, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(size * 0.36),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Icon(
        Icons.auto_stories_rounded,
        color: colorScheme.primary,
        size: size * 0.58,
      ),
    );
  }

  Widget _buildDesktopCompactHeader(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey<String>('auth_desktop_compact_header'),
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 34),
      decoration: BoxDecoration(
        color: _authFieldSurfaceColor(colorScheme),
        borderRadius: BorderRadius.circular(_authDesktopPanelRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -16,
            child: _buildReadingWatermark(
              size: 142,
              opacity: 0.055,
              color: colorScheme.primary,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDesktopBrandMark(context, colorScheme),
              const SizedBox(height: 26),
              AppAnimatedSwitcher(
                child: Text(
                  _isRegister ? '创建账户' : '欢迎回来',
                  key: ValueKey<String>(
                    _isRegister
                        ? 'auth_desktop_title_register'
                        : 'auth_desktop_title_login',
                  ),
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AppAnimatedSwitcher(
                child: Text(
                  _isRegister ? '创建新账户，继续进入书架。' : '欢迎回来。请登录您的账户。',
                  key: ValueKey<String>(
                    _isRegister
                        ? 'auth_desktop_subtitle_register'
                        : 'auth_desktop_subtitle_login',
                  ),
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.52,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBrandMark(
    BuildContext context,
    ColorScheme colorScheme, {
    bool compact = false,
  }) {
    return _buildAuthWordmark(context, colorScheme, compact: compact);
  }

  Widget _buildAuthWordmark(
    BuildContext context,
    ColorScheme colorScheme, {
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
    bool compact = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Text(
          'Selune',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (compact ? textTheme.headlineSmall : textTheme.headlineMedium)
              ?.copyWith(
                color: colorScheme.onSurface,
                fontFamily: 'Georgia',
                fontFamilyFallback: const ['Times New Roman', 'serif'],
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                height: 0.98,
                letterSpacing: 0,
              ),
        ),
        SizedBox(height: compact ? 4 : 5),
        Text(
          'CLEAR READING',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.68),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopBrandPanel(
    BuildContext context, {
    required ColorScheme colorScheme,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(_authDesktopPanelRadius),
      ),
      child: Container(
        key: const ValueKey<String>('auth_desktop_brand_panel'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildDesktopBrandArtwork(colorScheme),
            Padding(
              padding:
                  contentPadding ?? const EdgeInsets.fromLTRB(56, 48, 48, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDesktopBrandMark(context, colorScheme),
                  const Spacer(),
                  _buildDesktopReadingPreview(context, colorScheme),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBrandArtwork(ColorScheme colorScheme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _authDecorativeSurfaceColor(colorScheme),
          ),
        ),
        Positioned(
          right: -54,
          top: 116,
          child: _buildReadingWatermark(
            size: 260,
            opacity: 0.05,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopReadingPreview(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final lineColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.2);
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAuthGlyph(colorScheme, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewLine(lineColor, widthFactor: 0.62, height: 8),
                    const SizedBox(height: 8),
                    _buildPreviewLine(lineColor, widthFactor: 0.42, height: 7),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          for (final widthFactor in const <double>[0.86, 0.74, 0.92, 0.58])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPreviewLine(
                lineColor,
                widthFactor: widthFactor,
                height: 6,
              ),
            ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: 0.58,
              backgroundColor: colorScheme.surfaceContainerHigh,
              color: colorScheme.primary.withValues(alpha: 0.66),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewLine(
    Color color, {
    required double widthFactor,
    required double height,
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildReadingWatermark({
    required double size,
    required double opacity,
    required Color color,
  }) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.auto_stories_rounded,
          color: color,
          size: size * 0.72,
        ),
      ),
    );
  }

  Widget _buildDesktopAuthSurface(
    BuildContext context,
    ColorScheme colorScheme, {
    bool embedInSplitLayout = false,
    double? formMaxWidth,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDesktopBrandMark(context, colorScheme),
        const SizedBox(height: 10),
        Text(
          _isRegister ? '创建新账户，开始同步阅读。' : '欢迎回来。请登录您的账户。',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 34),
        _buildModeToggle(colorScheme, immersiveStyled: true),
        const SizedBox(height: 28),
        AppAnimatedSwitcher(
          child:
              _submitError == null
                  ? const SizedBox.shrink(key: ValueKey('auth_no_error'))
                  : _buildInlineError(context, _submitError!),
        ),
        if (_submitError != null) const SizedBox(height: 16),
        _buildAnimatedForm(context, desktopStyled: true),
        if (!_isRegister) ...[
          const SizedBox(height: 12),
          _buildDesktopLoginActionRow(context, colorScheme),
        ],
        const SizedBox(height: 20),
        _buildSubmitButton(
          desktopStyled: true,
          label: _isRegister ? '创建账户' : '立即登录',
        ),
        const SizedBox(height: 24),
        _buildAgreementFooter(context, colorScheme),
      ],
    );

    return Container(
      key: const ValueKey<String>('auth_desktop_surface'),
      padding: EdgeInsets.fromLTRB(
        embedInSplitLayout ? 40 : 32,
        embedInSplitLayout ? 48 : 30,
        embedInSplitLayout ? 40 : 32,
        embedInSplitLayout ? 32 : 30,
      ),
      decoration:
          embedInSplitLayout
              ? null
              : BoxDecoration(
                color: _authFieldSurfaceColor(colorScheme),
                borderRadius: BorderRadius.circular(_authDesktopPanelRadius),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: formMaxWidth ?? 430),
          child: form,
        ),
      ),
    );
  }
}
