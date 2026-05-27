part of 'reader_page.dart';

extension _ReaderPageSettingsPanelExtension on _ReaderPageState {
  Widget _buildFloatingReaderSettingsSheetImpl({
    required BuildContext context,
    required ThemeData readerModalTheme,
    required double keyboardInset,
    required double safeBottom,
    required double sheetHorizontal,
    required double maxWidth,
    required double heightFactor,
    Color? backgroundColor,
    required Widget child,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    final readerLayoutContext = ReaderLayoutContext.resolve(
      context,
      viewportKind: _currentViewportKind,
    );
    final floatingColor =
        backgroundColor ??
        readerModalTheme.colorScheme.surface.withValues(alpha: 0.9);
    final borderColor = readerModalTheme.colorScheme.outlineVariant.withValues(
      alpha: 0.35,
    );
    final useSidePanel =
        readerLayoutContext.settingsPanelPresentation ==
        ReaderPanelPresentation.sidePanel;
    final useEdgeToEdgeSheet = !useSidePanel;
    final radius = metrics.cardRadius + (useEdgeToEdgeSheet ? 10 : 12);
    final horizontalInset = useEdgeToEdgeSheet ? 0.0 : sheetHorizontal;
    final resolvedMaxWidth =
        useSidePanel
            ? min(maxWidth, readerLayoutContext.sidePanelMaxWidth)
            : min(maxWidth, metrics.bottomSheetMaxWidth);
    final sidePanelHeightFactor = heightFactor.clamp(0.72, 0.9).toDouble();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        left: horizontalInset,
        right: horizontalInset,
        top: useEdgeToEdgeSheet ? 0 : 48,
        bottom:
            keyboardInset +
            (useEdgeToEdgeSheet ? 0 : max(12.0, safeBottom * 0.55)),
      ),
      child: Align(
        alignment:
            useSidePanel ? Alignment.centerRight : Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: useSidePanel ? sidePanelHeightFactor : heightFactor,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: useEdgeToEdgeSheet ? double.infinity : resolvedMaxWidth,
            ),
            child: ClipRRect(
              borderRadius:
                  useEdgeToEdgeSheet
                      ? BorderRadius.vertical(top: Radius.circular(radius))
                      : BorderRadius.circular(radius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: floatingColor,
                  borderRadius:
                      useEdgeToEdgeSheet
                          ? BorderRadius.vertical(top: Radius.circular(radius))
                          : BorderRadius.circular(radius),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatLayoutMarginValueImpl(double value) {
    return _readerSettingsPresenter.layoutMarginValueLabel(value);
  }

  List<_ReaderBackgroundColorOption> _readerBackgroundColorOptionsImpl() {
    return <_ReaderBackgroundColorOption>[
      _createReaderBackgroundColorOption(
        label: '明亮',
        mode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.surface,
      ),
      _createReaderBackgroundColorOption(
        label: '护眼',
        mode: ReaderThemeMode.sepia,
        backgroundStyle: ReaderBackgroundStyle.warm,
        backgroundTone: ReaderBackgroundTone.container,
      ),
      _createReaderBackgroundColorOption(
        label: '浅灰',
        mode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.paper,
        backgroundTone: ReaderBackgroundTone.containerHigh,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeFlameOrangeOption,
        backgroundTone: ReaderBackgroundTone.flameOrangeTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemePineGreenOption,
        backgroundTone: ReaderBackgroundTone.pineGreenTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeSeaBlueOption,
        backgroundTone: ReaderBackgroundTone.seaBlueTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeNightPurpleOption,
        backgroundTone: ReaderBackgroundTone.nightPurpleTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeMistTealOption,
        backgroundTone: ReaderBackgroundTone.mistTealTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeBerryRoseOption,
        backgroundTone: ReaderBackgroundTone.berryRoseTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeAmberGoldOption,
        backgroundTone: ReaderBackgroundTone.amberGoldTint,
      ),
      _createReaderBackgroundColorOption(
        label: '夜间',
        mode: ReaderThemeMode.dark,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.pureBlack,
      ),
    ];
  }

  Widget _buildThemeColorDotImpl({
    required ReaderSettings draft,
    required Color color,
    required String label,
    required ReaderThemeMode mode,
    required ReaderBackgroundStyle backgroundStyle,
    required ReaderBackgroundTone backgroundTone,
    required ValueChanged<ReaderSettings> onChanged,
    double scale = 1.0,
  }) {
    final normalizedTone = normalizeReaderBackgroundTone(
      mode: draft.themeMode,
      tone: draft.backgroundTone,
    );
    final selected =
        draft.themeMode == mode &&
        draft.backgroundStyle == backgroundStyle &&
        normalizedTone == backgroundTone;
    final iconColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : null;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () {
          onChanged(
            draft.copyWith(
              themeMode: mode,
              backgroundStyle: backgroundStyle,
              backgroundTone: backgroundTone,
              clearBackgroundImage: true,
            ),
          );
        },
        child: Container(
          width: 30 * scale,
          height: 30 * scale,
          margin: EdgeInsets.only(right: 8 * scale),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
              width: (selected ? 2 : 1) * scale.clamp(1.0, 1.4),
            ),
          ),
          child:
              selected
                  ? Icon(
                    Icons.check_rounded,
                    size: 14 * scale,
                    color: iconColor,
                  )
                  : null,
        ),
      ),
    );
  }

  Widget _buildBackgroundTileImpl({
    required String label,
    required bool selected,
    Uint8List? previewBytes,
    VoidCallback? onTap,
    bool showLabel = true,
    IconData? icon,
    double scale = 1.0,
  }) {
    final image =
        previewBytes == null
            ? null
            : DecorationImage(
              image: MemoryImage(previewBytes),
              fit: BoxFit.cover,
            );

    final content =
        previewBytes == null
            ? (icon != null
                ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 18 * scale,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      if (showLabel) ...[
                        SizedBox(height: 2 * scale),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            fontSize:
                                (Theme.of(
                                      context,
                                    ).textTheme.labelSmall?.fontSize ??
                                    11) *
                                scale,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
                : Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize:
                        (Theme.of(context).textTheme.labelSmall?.fontSize ??
                            11) *
                        scale,
                  ),
                ))
            : (!showLabel
                ? const SizedBox.expand()
                : Container(
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6 * scale),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x7A000000)],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 2 * scale),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize:
                            (Theme.of(context).textTheme.labelSmall?.fontSize ??
                                11) *
                            scale,
                      ),
                    ),
                  ),
                ));

    final resolvedTile = Container(
      width: _ReaderPageState._kBackgroundTileWidth * scale,
      height: _ReaderPageState._kBackgroundTileHeight * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(
          color:
              selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
          width: (selected ? 2 : 1) * scale.clamp(1.0, 1.4),
        ),
        image: image,
      ),
      child: content,
    );

    if (onTap == null) {
      return resolvedTile;
    }
    return GestureDetector(onTap: onTap, child: resolvedTile);
  }
}
