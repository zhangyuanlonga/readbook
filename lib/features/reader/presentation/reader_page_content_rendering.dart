part of 'reader_page.dart';

extension _ReaderPageContentRenderingExtension on _ReaderPageState {
  Widget _buildContinuousTextChapterSection({
    required _ContinuousTextChapter chapter,
    required bool isActive,
    required _ReaderThemeColors colors,
  }) {
    final renderItems = buildReaderRenderBlockItems(chapter.document);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (renderItems.isEmpty)
          isActive
              ? _buildSelectableParagraphItem(
                paragraph: chapter.content,
                paragraphIndex: 0,
                isLast: true,
                colors: colors,
              )
              : _buildStaticParagraphItem(
                paragraph: chapter.content,
                isLast: true,
                colors: colors,
              )
        else
          for (var index = 0; index < renderItems.length; index += 1)
            isActive
                ? _buildSelectableReaderBlockItem(
                  item: renderItems[index],
                  isLast: index == renderItems.length - 1,
                  colors: colors,
                )
                : _buildStaticReaderBlockItem(
                  item: renderItems[index],
                  isLast: index == renderItems.length - 1,
                  colors: colors,
                ),
      ],
    );

    return KeyedSubtree(
      key: _continuousTextChapterKey(chapter),
      child: isActive ? _wrapSelectionArea(child: body) : body,
    );
  }

  Widget _buildStaticParagraphItem({
    required String paragraph,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    final inlineImageUrl = _tryParseInlineImageParagraph(paragraph);
    if (inlineImageUrl != null) {
      return _buildInlineImageParagraphItem(
        imageUrl: inlineImageUrl,
        isLast: isLast,
        colors: colors,
      );
    }

    final textStyle = _paragraphTextStyle(colors);
    final paddingBottom =
        isLast
            ? 0.0
            : _typographyMetricsResolver.resolveParagraphSpacingPixels(
              settings: _settings,
            );

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: paddingBottom),
        child: ReaderAnnotatedText(
          displayText: _applyParagraphIndent(paragraph),
          indentLength: _paragraphIndentLength(),
          baseStyle: textStyle,
          textAlign: _paragraphTextAlign(_settings),
          textDirection: Directionality.of(context),
          highlightColor: colors.text,
          wavyColor: colors.text.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  ReaderRenderTextItem? _readerRenderTextItemForParagraphIndex(
    int paragraphIndex,
  ) {
    return _renderTextItemsByParagraph[paragraphIndex];
  }

  AppAdvancedThemeModeConfig? _effectiveReaderBackgroundThemeConfig() {
    if (_visualOverrides.hasBackgroundImageOverride) {
      return null;
    }
    final activeTheme = _currentActiveAdvancedTheme();
    if (activeTheme != null) {
      final colorScheme = Theme.of(context).colorScheme;
      final modeConfig = activeTheme.configFor(
        colorScheme.brightness == Brightness.dark
            ? AppAdvancedThemeMode.dark
            : AppAdvancedThemeMode.light,
      );
      final themeReaderWallpaper = modeConfig.readerWallpaperPath?.trim();
      if (themeReaderWallpaper != null && themeReaderWallpaper.isNotEmpty) {
        return modeConfig;
      }
    }
    return null;
  }

  String? _effectiveReaderBackgroundPath() {
    final ownBackground = _settings.backgroundImageBase64?.trim();
    if (ownBackground == null || ownBackground.isEmpty) {
      return null;
    }
    return ownBackground;
  }

  Widget _buildStaticReaderBlockItem({
    required ReaderRenderBlockItem item,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    if (item is ReaderRenderImageItem) {
      return _buildInlineImageParagraphItem(
        imageUrl: item.imageUrl,
        isLast: isLast,
        colors: colors,
      );
    }
    if (item is! ReaderRenderTextItem) {
      return const SizedBox.shrink();
    }

    final textStyle = _readerBlockTextStyle(item, colors);
    final displayText = _displayTextForRenderItem(item);
    final indentLength = _indentLengthForRenderItem(item);

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: _readerBlockSpacing(item, isLast: isLast),
        ),
        child: ReaderAnnotatedText(
          displayText: displayText,
          indentLength: indentLength,
          baseStyle: textStyle,
          textAlign: _textAlignForRenderItem(item),
          textDirection: Directionality.of(context),
          highlightColor: colors.text,
          wavyColor: colors.text.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildSelectableReaderBlockItem({
    required ReaderRenderBlockItem item,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    if (item is ReaderRenderImageItem) {
      return _buildInlineImageParagraphItem(
        imageUrl: item.imageUrl,
        isLast: isLast,
        colors: colors,
      );
    }
    if (item is! ReaderRenderTextItem) {
      return const SizedBox.shrink();
    }
    if (item.kind == ReaderRenderTextKind.paragraph) {
      return _buildSelectableParagraphItem(
        paragraph: item.text,
        paragraphIndex: item.paragraphIndex ?? 0,
        isLast: isLast,
        colors: colors,
      );
    }

    final textStyle = _readerBlockTextStyle(item, colors);
    final displayText = _displayTextForRenderItem(item);
    final indentLength = _indentLengthForRenderItem(item);

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: _readerBlockSpacing(item, isLast: isLast),
        ),
        child: ReaderAnnotatedText(
          displayText: displayText,
          indentLength: indentLength,
          baseStyle: textStyle,
          textAlign: _textAlignForRenderItem(item),
          textDirection: Directionality.of(context),
          highlightColor: colors.text,
          wavyColor: colors.text.withValues(alpha: 0.7),
          annotationRanges: (_bookmarkRangesByParagraph[item.paragraphIndex ??
                      0] ??
                  const <_BookmarkRange>[])
              .map(
                (range) => ReaderTextAnnotationRange(
                  range.start,
                  range.end,
                  hasHighlight: range.hasHighlight,
                  isBold: range.isBold,
                  isUnderline: range.isUnderline,
                  isWavy: range.isWavy,
                ),
              )
              .toList(growable: false),
          onTapUp: (details) {
            final renderBox = context.findRenderObject();
            final maxWidth =
                renderBox is RenderBox ? renderBox.size.width : 0.0;
            _routeReaderChildTap(
              _handleBookmarkTap(
                paragraphIndex: item.paragraphIndex ?? 0,
                paragraphText: item.text,
                localPosition: details.localPosition,
                maxWidth: maxWidth,
                textStyle: textStyle,
                textAlign: _textAlignForRenderItem(item),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectableParagraphItem({
    required String paragraph,
    required int paragraphIndex,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    final inlineImageUrl = _tryParseInlineImageParagraph(paragraph);
    if (inlineImageUrl != null) {
      return _buildInlineImageParagraphItem(
        imageUrl: inlineImageUrl,
        isLast: isLast,
        colors: colors,
      );
    }

    final textStyle = _paragraphTextStyle(colors);
    final paddingBottom =
        isLast
            ? 0.0
            : _typographyMetricsResolver.resolveParagraphSpacingPixels(
              settings: _settings,
            );

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: paddingBottom),
        child: ReaderAnnotatedText(
          displayText: _applyParagraphIndent(paragraph),
          indentLength: _paragraphIndentLength(),
          baseStyle: textStyle,
          textAlign: _paragraphTextAlign(_settings),
          textDirection: Directionality.of(context),
          highlightColor: colors.text,
          wavyColor: colors.text.withValues(alpha: 0.7),
          annotationRanges: (_bookmarkRangesByParagraph[paragraphIndex] ??
                  const <_BookmarkRange>[])
              .map(
                (range) => ReaderTextAnnotationRange(
                  range.start,
                  range.end,
                  hasHighlight: range.hasHighlight,
                  isBold: range.isBold,
                  isUnderline: range.isUnderline,
                  isWavy: range.isWavy,
                ),
              )
              .toList(growable: false),
          bodyDecorationEnabled:
              _settings.bodyTextDecorationStyle !=
              ReaderBodyTextDecorationStyle.none,
          bodyDecorationColor: Color(
            _settings.bodyTextDecorationColorValue ?? colors.text.toARGB32(),
          ),
          bodyDecorationStyle: _settings.bodyTextDecorationStyle,
          bodyDecorationThickness: _settings.bodyTextUnderlineThickness,
          bodyDecorationGap: _settings.bodyTextUnderlineGap,
          bodyDecorationDashLength: _settings.bodyTextUnderlineDashLength,
          bodyDecorationDashGapRatio: _settings.bodyTextUnderlineDashGapRatio,
          onTapUp: (details) {
            final renderBox = context.findRenderObject();
            final maxWidth =
                renderBox is RenderBox ? renderBox.size.width : 0.0;
            _routeReaderChildTap(
              _handleBookmarkTap(
                paragraphIndex: paragraphIndex,
                paragraphText: paragraph,
                localPosition: details.localPosition,
                maxWidth: maxWidth,
                textStyle: textStyle,
                textAlign: _paragraphTextAlign(_settings),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAutoReadIndicator(_ReaderThemeColors colors) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            if (maxHeight <= 1) {
              return const SizedBox.shrink();
            }
            return AnimatedBuilder(
              animation: _scrollController,
              builder: (context, _) {
                if (!_hasSingleAttachedScrollPosition ||
                    !_isTextScrollViewport) {
                  return const SizedBox.shrink();
                }

                final ratio = _autoReadProgressRatio();
                final top =
                    (maxHeight * ratio).clamp(2.0, maxHeight - 2.0).toDouble();

                return Stack(
                  children: [
                    Positioned(
                      top: top - 14,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              colors.meta.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: top,
                      left: 16,
                      right: 16,
                      child: Container(
                        height: 1.8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              colors.meta.withValues(alpha: 0.28),
                              colors.text.withValues(alpha: 0.52),
                              colors.meta.withValues(alpha: 0.28),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildInlineImageParagraphItem({
    required String imageUrl,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    final paddingBottom =
        isLast
            ? 0.0
            : _typographyMetricsResolver.resolveParagraphSpacingPixels(
              settings: _settings,
            );
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: paddingBottom),
        child: _buildInlineReaderImageCard(imageUrl: imageUrl, colors: colors),
      ),
    );
  }

  Widget _buildInlineReaderImageCard({
    required String imageUrl,
    required _ReaderThemeColors colors,
  }) {
    final retryNonce = _mangaImageRetryNonce[imageUrl] ?? 0;
    final requestUrl = _buildMangaImageUrl(imageUrl, retryNonce);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_openInlineImagePreview(requestUrl, colors)),
        onLongPress:
            () => unawaited(_openInlineImagePreview(requestUrl, colors)),
        child: ColoredBox(
          color: colors.overlay,
          child: _buildReaderImageWidget(
            requestUrl: requestUrl,
            sourceUrl: imageUrl,
            colors: colors,
            retryNonce: retryNonce,
          ),
        ),
      ),
    );
  }

  Future<void> _openInlineImagePreview(
    String requestUrl,
    _ReaderThemeColors colors,
  ) async {
    if (_autoReadSessionState == ReaderAutoReadSessionState.running) {
      _pauseAutoReadSession();
    }
    await showAdaptiveFullscreenPreview<void>(
      context: context,
      title: '图片预览',
      helperText: '双指缩放，轻触关闭',
      builder: (_) {
        return Center(
          child: _buildReaderImageWidget(
            requestUrl: requestUrl,
            sourceUrl: requestUrl,
            colors: colors,
            retryNonce: _mangaImageRetryNonce[requestUrl] ?? 0,
          ),
        );
      },
    );
  }

  String? _tryParseInlineImageParagraph(String paragraph) {
    return ReaderDocument.tryParseInlineImageParagraph(paragraph);
  }

  bool _isInlineImageParagraph(String paragraph) {
    return _tryParseInlineImageParagraph(paragraph) != null;
  }

  Widget _buildReaderImageWidget({
    required String requestUrl,
    required String sourceUrl,
    required _ReaderThemeColors colors,
    required int retryNonce,
  }) {
    final mediaSize = MediaQuery.sizeOf(context);
    final decodeBudget = _readerImageDecodeBudget(
      role:
          _isMangaChapter
              ? ReaderImageDecodeRole.manga
              : ReaderImageDecodeRole.epubInline,
      logicalWidth: mediaSize.width,
    );
    final uri = Uri.tryParse(requestUrl);
    if (_isSvgImageUrl(requestUrl)) {
      return _buildSvgImageWidget(
        requestUrl: requestUrl,
        colors: colors,
        sourceUrl: sourceUrl,
        retryNonce: retryNonce,
      );
    }
    if (requestUrl.startsWith('data:image/')) {
      return _buildDataUriImage(
        dataUri: requestUrl,
        colors: colors,
        sourceUrl: sourceUrl,
        retryNonce: retryNonce,
        decodeBudget: decodeBudget,
      );
    }
    if (uri != null && uri.scheme == 'file') {
      return buildLocalFileImage(
        imagePath: localFilePathFromUri(uri),
        fit: BoxFit.fitWidth,
        fallback: _buildMangaImageError(colors, sourceUrl, retryNonce),
        gaplessPlayback: true,
        filterQuality: _resolveReaderImageFilterQuality(),
        cacheWidth: decodeBudget.cacheWidth,
        cacheHeight: decodeBudget.cacheHeight,
      );
    }

    return Image.network(
      requestUrl,
      headers: _chapterImageHeaders.isEmpty ? null : _chapterImageHeaders,
      fit: BoxFit.fitWidth,
      gaplessPlayback: true,
      filterQuality: _resolveReaderImageFilterQuality(),
      cacheWidth: decodeBudget.cacheWidth,
      cacheHeight: decodeBudget.cacheHeight,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }

        return AspectRatio(
          aspectRatio: 3 / 4,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.meta,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildMangaImageError(colors, sourceUrl, retryNonce);
      },
    );
  }

  bool _isSvgImageUrl(String imageUrl) {
    if (imageUrl.startsWith('data:image/svg+xml')) {
      return true;
    }
    final uri = Uri.tryParse(imageUrl);
    final path = uri?.path.toLowerCase() ?? imageUrl.toLowerCase();
    return path.endsWith('.svg') || path.endsWith('.svgz');
  }

  Widget _buildSvgImageWidget({
    required String requestUrl,
    required _ReaderThemeColors colors,
    required String sourceUrl,
    required int retryNonce,
  }) {
    final uri = Uri.tryParse(requestUrl);
    Widget placeholderBuilder(BuildContext context) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.meta),
        ),
      );
    }

    Widget errorBuilder(
      BuildContext context,
      Object error,
      StackTrace stackTrace,
    ) {
      return _buildMangaImageError(colors, sourceUrl, retryNonce);
    }

    try {
      if (requestUrl.startsWith('data:image/svg+xml')) {
        final decoded = _decodeDataUriImage(dataUri: requestUrl);
        if (decoded == null) {
          throw const FormatException('Invalid SVG data URI');
        }
        return SvgPicture.string(
          decoded.text,
          fit: BoxFit.fitWidth,
          placeholderBuilder: placeholderBuilder,
          errorBuilder: errorBuilder,
        );
      }
      if (uri != null && uri.scheme == 'file') {
        return FutureBuilder<String>(
          future: readLocalFileText(
            localFilePathFromUri(uri),
          ).then((value) => value ?? ''),
          builder: (context, snapshot) {
            final svgText = snapshot.data;
            if (svgText == null || svgText.trim().isEmpty) {
              return placeholderBuilder(context);
            }
            return SvgPicture.string(
              svgText,
              fit: BoxFit.fitWidth,
              placeholderBuilder: placeholderBuilder,
              errorBuilder: errorBuilder,
            );
          },
        );
      }
      return SvgPicture.network(
        requestUrl,
        headers: _chapterImageHeaders.isEmpty ? null : _chapterImageHeaders,
        fit: BoxFit.fitWidth,
        placeholderBuilder: placeholderBuilder,
        errorBuilder: errorBuilder,
      );
    } catch (_) {
      return _buildMangaImageError(colors, sourceUrl, retryNonce);
    }
  }

  Widget _buildDataUriImage({
    required String dataUri,
    required _ReaderThemeColors colors,
    required String sourceUrl,
    required int retryNonce,
    required ReaderImageDecodeBudget decodeBudget,
  }) {
    try {
      final decoded = _decodeDataUriImage(
        dataUri: dataUri,
        maxBytes: decodeBudget.maxDataUriBytes,
      );
      if (decoded == null) {
        throw const FormatException('Invalid data URI');
      }
      return Image.memory(
        decoded.bytes,
        fit: BoxFit.fitWidth,
        gaplessPlayback: true,
        filterQuality: _resolveReaderImageFilterQuality(),
        cacheWidth: decodeBudget.cacheWidth,
        cacheHeight: decodeBudget.cacheHeight,
        errorBuilder: (context, error, stackTrace) {
          return _buildMangaImageError(colors, sourceUrl, retryNonce);
        },
      );
    } catch (_) {
      return _buildMangaImageError(colors, sourceUrl, retryNonce);
    }
  }

  _DecodedDataUriImage? _decodeDataUriImage({
    required String dataUri,
    int? maxBytes,
  }) {
    final commaIndex = dataUri.indexOf(',');
    if (commaIndex <= 0) {
      return null;
    }
    final metadata = dataUri.substring(5, commaIndex);
    final encoded = dataUri.substring(commaIndex + 1);
    final isBase64 = metadata.toLowerCase().contains(';base64');
    final mediaType = metadata.split(';').first.trim().toLowerCase();
    final bytes =
        isBase64
            ? base64Decode(encoded)
            : Uint8List.fromList(utf8.encode(Uri.decodeComponent(encoded)));
    if (maxBytes != null && maxBytes >= 0 && bytes.length > maxBytes) {
      return null;
    }
    return _DecodedDataUriImage(
      mediaType: mediaType,
      bytes: bytes,
      text: utf8.decode(bytes, allowMalformed: true),
    );
  }

  Widget _buildMangaImageError(
    _ReaderThemeColors colors,
    String imageUrl,
    int retryNonce,
  ) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: InkWell(
        onTap: () {
          _updateReaderState(() {
            _mangaImageRetryNonce[imageUrl] = retryNonce + 1;
          });
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '图片加载失败，点击重试',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.meta),
            ),
          ),
        ),
      ),
    );
  }

  double _resolveMangaCacheExtent() {
    final budget = _currentResourceBudget();
    final strategyExtent = switch (_settings.mangaLoadStrategy) {
      ReaderMangaLoadStrategy.balanced => 1800,
      ReaderMangaLoadStrategy.smooth => 3200,
      ReaderMangaLoadStrategy.saveData => 900,
    };
    return min(strategyExtent, budget.mangaCacheExtent).toDouble();
  }

  FilterQuality _resolveMangaFilterQuality() {
    return switch (_settings.mangaLoadStrategy) {
      ReaderMangaLoadStrategy.balanced => FilterQuality.medium,
      ReaderMangaLoadStrategy.smooth => FilterQuality.high,
      ReaderMangaLoadStrategy.saveData => FilterQuality.low,
    };
  }

  FilterQuality _resolveReaderImageFilterQuality() {
    if (!_isMangaChapter && _document.hasImageBlocks) {
      return FilterQuality.low;
    }
    return _resolveMangaFilterQuality();
  }

  Widget _buildPagedPageContainer({
    required _ReaderThemeColors colors,
    required int pageIndex,
    required int total,
    required Size pageSize,
    required ReaderTextPagedViewModel pagedViewModel,
    bool includeBackgroundDecoration = false,
  }) {
    final pages = pagedViewModel.pagedPages;
    final blockPages = pagedViewModel.pagedBlockPages;
    final pageCount = max(pages.length, blockPages.length);
    final layoutMetrics = pagedViewModel.surfaceMetrics;
    if (pageIndex < 0 || pageIndex >= pageCount) {
      return const SizedBox.shrink();
    }

    return ReaderPagedPageFrame(
      pageSize: pageSize,
      includeBackgroundDecoration: includeBackgroundDecoration,
      backgroundDecoration: _buildReaderBackgroundDecoration(colors),
      pinnedHeader:
          _showsPagedPinnedChapterHeaderFor(_currentViewportKind)
              ? SelectionContainer.disabled(
                child: _buildPinnedChapterHeader(colors),
              )
              : null,
      header:
          layoutMetrics.pagedHeaderReserve > 0
              ? SelectionContainer.disabled(
                child: _buildPagedHeaderSection(colors, layoutMetrics),
              )
              : null,
      body: ReaderPagedPageContent(
        model: pagedViewModel,
        pageIndex: pageIndex,
        paddingResolver: (_) => layoutMetrics.effectivePagePadding,
        resolvedSliceBuilder:
            (context, slice, defaultSlice) => _buildPagedResolvedSliceContent(
              context: context,
              slice: slice,
              colors: colors,
            ),
      ),
      footer: SelectionContainer.disabled(
        child: _buildPagedFooterSection(
          colors: colors,
          index: pageIndex,
          total: total,
          layoutMetrics: layoutMetrics,
        ),
      ),
    );
  }

  Widget _buildPagedHeaderSection(
    _ReaderThemeColors colors,
    ReaderSurfaceMetrics layoutMetrics,
  ) {
    return const SizedBox.shrink();
  }

  Widget _buildPagedFooterSection({
    required _ReaderThemeColors colors,
    required int index,
    required int total,
    required ReaderSurfaceMetrics layoutMetrics,
  }) {
    if (!_settings.infoFooterEnabled || layoutMetrics.pagedFooterReserve <= 0) {
      return const SizedBox.shrink();
    }
    final overlayModel = ReaderPageIndexOverlayModel.fromSettings(
      settings: _settings,
      layoutResolver: _layoutResolver,
      index: index,
      total: total,
      bottomInset: 0,
      safeBottomInset: 0,
      fadeProgress: 0,
      rightItems: <String>[
        if (_settings.infoShowTime) _formatReaderInfoTime(_readerInfoNow),
        if (_settings.infoShowBattery) _readerBatteryLabel(),
      ],
    );
    final footerInnerHorizontalPadding =
        _settings.infoFooterPadding
            .clamp(
              ReaderSettings.minInfoBarPadding,
              ReaderSettings.maxInfoBarPadding,
            )
            .toDouble() *
        3.2;
    const footerInnerVerticalPadding = 3.0;
    final footerTopOffset = layoutMetrics.footerPadding.top;
    final footerBottomPadding =
        layoutMetrics.safeInsets.bottom +
        layoutMetrics.footerPadding.bottom +
        footerInnerVerticalPadding;
    final footer = SizedBox(
      height: layoutMetrics.pagedFooterReserve,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          overlayModel.horizontalPadding + footerInnerHorizontalPadding,
          0,
          overlayModel.horizontalPadding + footerInnerHorizontalPadding,
          footerBottomPadding,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, footerTopOffset),
            child: Opacity(
              opacity: overlayModel.opacity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (overlayModel.showProgress)
                    ReaderPageIndexBadge(
                      model: overlayModel.badge,
                      palette: _chromePalette(colors),
                    ),
                  if (overlayModel.rightLabel.isNotEmpty)
                    Expanded(
                      child: Text(
                        overlayModel.rightLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: colors.meta.withValues(alpha: 0.9),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return footer;
  }

  Widget _buildPageIndexOverlay({
    required _ReaderThemeColors colors,
    required int index,
    required int total,
    required double bottomInset,
    double? safeBottomInset,
  }) {
    return AnimatedBuilder(
      animation: _overlayControlsController,
      builder: (context, _) {
        return ReaderPageIndexOverlay(
          model: ReaderPageIndexOverlayModel.fromSettings(
            settings: _settings,
            layoutResolver: _layoutResolver,
            index: index,
            total: total,
            bottomInset: bottomInset,
            safeBottomInset:
                safeBottomInset ?? _effectiveBottomSafeInset(context),
            fadeProgress: _overlayControlsFadeProgress,
            rightItems: <String>[
              if (_settings.infoShowTime) _formatReaderInfoTime(_readerInfoNow),
              if (_settings.infoShowBattery) _readerBatteryLabel(),
            ],
          ),
          palette: _chromePalette(colors),
        );
      },
    );
  }

  Widget _buildPagedResolvedSliceContent({
    required BuildContext context,
    required ReaderPagedResolvedSlice slice,
    required _ReaderThemeColors colors,
  }) {
    final paragraphIndex = slice.paragraphIndex;
    if (paragraphIndex == null ||
        paragraphIndex < 0 ||
        paragraphIndex >= _paragraphs.length) {
      return const SizedBox.shrink();
    }

    final paragraph = _paragraphs[paragraphIndex];
    final ranges =
        _bookmarkRangesByParagraph[paragraphIndex] ?? const <_BookmarkRange>[];
    final localRanges = <_BookmarkRange>[];
    if (ranges.isNotEmpty) {
      for (final range in ranges) {
        final overlapStart = max(range.start, slice.slice.start);
        final overlapEnd = min(range.end, slice.slice.end);
        if (overlapEnd <= overlapStart) {
          continue;
        }
        localRanges.add(
          _BookmarkRange(
            overlapStart - slice.slice.start,
            overlapEnd - slice.slice.start,
            hasHighlight: range.hasHighlight,
            isBold: range.isBold,
            isUnderline: range.isUnderline,
            isWavy: range.isWavy,
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: slice.spacingAfter),
      child: SizedBox(
        height: slice.measuredHeight > 0 ? slice.measuredHeight : null,
        child: Align(
          alignment: Alignment.topLeft,
          child: ReaderAnnotatedText(
            displayText: slice.displayText,
            indentLength: slice.indentLength,
            baseStyle: slice.textStyle,
            textAlign: slice.textAlign,
            textDirection: Directionality.of(context),
            highlightColor: colors.text,
            wavyColor: colors.text.withValues(alpha: 0.7),
            annotationRanges: localRanges
                .map(
                  (range) => ReaderTextAnnotationRange(
                    range.start,
                    range.end,
                    hasHighlight: range.hasHighlight,
                    isBold: range.isBold,
                    isUnderline: range.isUnderline,
                    isWavy: range.isWavy,
                  ),
                )
                .toList(growable: false),
            bodyDecorationEnabled:
                _settings.bodyTextDecorationStyle !=
                ReaderBodyTextDecorationStyle.none,
            bodyDecorationColor: Color(
              _settings.bodyTextDecorationColorValue ?? colors.text.toARGB32(),
            ),
            bodyDecorationStyle: _settings.bodyTextDecorationStyle,
            bodyDecorationThickness: _settings.bodyTextUnderlineThickness,
            bodyDecorationGap: _settings.bodyTextUnderlineGap,
            bodyDecorationDashLength: _settings.bodyTextUnderlineDashLength,
            bodyDecorationDashGapRatio: _settings.bodyTextUnderlineDashGapRatio,
            onTapUp: (details) {
              final renderBox = context.findRenderObject();
              final maxWidth =
                  renderBox is RenderBox ? renderBox.size.width : 0.0;
              _routeReaderChildTap(
                _handleBookmarkTapInSlice(
                  slice: slice.slice,
                  paragraphText: paragraph,
                  localPosition: details.localPosition,
                  maxWidth: maxWidth,
                  textStyle: slice.textStyle,
                  textAlign: slice.textAlign,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  TextStyle _paragraphTextStyle(_ReaderThemeColors colors) {
    final customColorValue = _settings.bodyTextColorValue;
    return _typographyResolver.resolveBodyStyle(
      settings: _settings,
      color: customColorValue == null ? colors.text : Color(customColorValue),
    );
  }

  TextStyle _readerBlockTextStyle(
    ReaderRenderTextItem item,
    _ReaderThemeColors colors,
  ) {
    return resolveReaderTextBlockPresentation(
      settings: _settings,
      primaryTextColor: colors.text,
      secondaryTextColor: colors.meta,
      item: item,
      isLast: false,
    ).textStyle;
  }

  double _readerBlockSpacing(
    ReaderRenderTextItem item, {
    required bool isLast,
  }) {
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    return resolveReaderTextBlockPresentation(
      settings: _settings,
      primaryTextColor: colors.text,
      secondaryTextColor: colors.meta,
      item: item,
      isLast: isLast,
    ).spacingAfter;
  }

  TextAlign _textAlignForRenderItem(ReaderRenderTextItem item) {
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    return resolveReaderTextBlockPresentation(
      settings: _settings,
      primaryTextColor: colors.text,
      secondaryTextColor: colors.meta,
      item: item,
      isLast: false,
    ).textAlign;
  }

  String _displayTextForRenderItem(ReaderRenderTextItem item) {
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    return resolveReaderTextBlockPresentation(
      settings: _settings,
      primaryTextColor: colors.text,
      secondaryTextColor: colors.meta,
      item: item,
      isLast: false,
    ).displayText;
  }

  int _indentLengthForRenderItem(ReaderRenderTextItem item) {
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    return resolveReaderTextBlockPresentation(
      settings: _settings,
      primaryTextColor: colors.text,
      secondaryTextColor: colors.meta,
      item: item,
      isLast: false,
    ).indentLength;
  }
}
