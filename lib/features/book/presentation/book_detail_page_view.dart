// UI-GOV-EXEMPT-FILE: scaffold list-children
// reason: Phase 10 reviewed book detail page shell; custom chrome and short action sections are intentional.

part of 'book_detail_page.dart';

extension on _BookDetailPageState {
  PreferredSizeWidget _buildRouteTopBar({
    required BuildContext context,
    required double backgroundOpacity,
    required bool usesInlineMetadataEditor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return AdaptiveRouteTopBar(
      title: _routeTopBarTitle,
      subtitle: _routeTopBarSubtitle,
      leading: Builder(
        builder:
            (leadingContext) => IconButton(
              onPressed: () => _handleBackNavigation(leadingContext),
              tooltip: '返回',
              icon: const Icon(Icons.arrow_back),
            ),
      ),
      actions: _buildDesktopTopBarActions(
        usesInlineMetadataEditor: usesInlineMetadataEditor,
      ),
      mobileActions: _buildMobileTopBarActions(
        usesInlineMetadataEditor: usesInlineMetadataEditor,
      ),
      backgroundColor: colorScheme.surface.withValues(
        alpha: backgroundOpacity * 0.92,
      ),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      dividerColor: Colors.transparent,
      desktopHeight: kToolbarHeight,
      titleMaxWidth: 320,
      moreTooltip: '更多',
      showDesktopTitle: false,
    );
  }

  String get _routeTopBarTitle {
    final resultTitle = _result?.detail.title.trim() ?? '';
    if (resultTitle.isNotEmpty) {
      return resultTitle;
    }
    final displayTitle = _displayTitle?.trim() ?? '';
    if (displayTitle.isNotEmpty) {
      return displayTitle;
    }
    final widgetTitle = widget.title?.trim() ?? '';
    if (widgetTitle.isNotEmpty) {
      return widgetTitle;
    }
    return '书籍详情';
  }

  String? get _routeTopBarSubtitle {
    final result = _result;
    if (result != null) {
      final author = result.detail.author?.trim() ?? '';
      final sourceName = result.sourceName.trim();
      if (author.isNotEmpty && sourceName.isNotEmpty) {
        return '$author · $sourceName';
      }
      if (author.isNotEmpty) {
        return author;
      }
      if (sourceName.isNotEmpty) {
        return sourceName;
      }
    }
    final author = widget.author?.trim() ?? '';
    return author.isEmpty ? null : author;
  }

  List<AdaptiveOverflowToolbarItem> _buildDesktopTopBarActions({
    required bool usesInlineMetadataEditor,
  }) {
    if (usesInlineMetadataEditor) {
      return <AdaptiveOverflowToolbarItem>[
        AdaptiveOverflowToolbarItem(
          icon: Icons.close_rounded,
          label: '取消',
          priority: 12,
          enabled: !_isSavingMetadata,
          onPressed: _isSavingMetadata ? null : _cancelEditingMode,
        ),
        AdaptiveOverflowToolbarItem(
          icon: Icons.restore_rounded,
          label: '恢复默认',
          priority: 10,
          enabled: !_isSavingMetadata,
          onPressed: _isSavingMetadata ? null : _handleResetMetadataEditing,
        ),
        AdaptiveOverflowToolbarItem(
          icon: Icons.save_outlined,
          label: _isSavingMetadata ? '保存中' : '保存',
          priority: 20,
          enabled: !_isSavingMetadata,
          onPressed: _isSavingMetadata ? null : _handleSaveMetadataEditing,
        ),
      ];
    }
    return <AdaptiveOverflowToolbarItem>[
      AdaptiveOverflowToolbarItem(
        icon: Icons.edit_outlined,
        label: '编辑',
        priority: 12,
        onPressed: _handleEditAction,
      ),
      AdaptiveOverflowToolbarItem(
        icon: Icons.share_outlined,
        label: '分享',
        priority: 10,
        onPressed: _handleShareAction,
      ),
      AdaptiveOverflowToolbarItem(
        icon: Icons.more_horiz_rounded,
        label: '更多',
        priority: 4,
        onPressed: _showMoreActionsSheet,
      ),
    ];
  }

  List<Widget> _buildMobileTopBarActions({
    required bool usesInlineMetadataEditor,
  }) {
    if (usesInlineMetadataEditor) {
      return <Widget>[
        TextButton(
          onPressed: _isSavingMetadata ? null : _cancelEditingMode,
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _isSavingMetadata ? null : _handleResetMetadataEditing,
          child: const Text('恢复默认'),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(
            onPressed: _isSavingMetadata ? null : _handleSaveMetadataEditing,
            child: Text(_isSavingMetadata ? '保存中' : '保存'),
          ),
        ),
      ];
    }
    return <Widget>[
      IconButton(
        onPressed: _handleEditAction,
        tooltip: '编辑',
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        onPressed: _handleShareAction,
        tooltip: '分享',
        icon: const Icon(Icons.share_outlined),
      ),
      IconButton(
        onPressed: _showMoreActionsSheet,
        tooltip: '更多',
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    ];
  }

  Widget _buildBookDetailPage(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final activeAdvancedTheme =
            ref.watch(activeAdvancedThemeProvider).valueOrNull;
        final colorScheme = Theme.of(context).colorScheme;
        final metrics = AppAdaptiveMetrics.of(context);
        final backdrop = resolveAdvancedThemeBackdrop(
          colorScheme,
          activeAdvancedTheme,
        );
        ref.watch(coverGalleriesProvider);
        final horizontal = AppSpacing.pageHorizontal(context);
        final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final canPopRoute = context.canPop();
        final clampedOffset = _detailScrollOffset.clamp(0.0, 96.0);
        final appBarOverlayOpacity = (clampedOffset / 96.0).clamp(0.0, 1.0);
        final usesInlineMetadataEditor =
            _isEditingMetadata && !metrics.isMediumUpWindow;
        final routeTopBar = _buildRouteTopBar(
          context: context,
          backgroundOpacity: appBarOverlayOpacity,
          usesInlineMetadataEditor: usesInlineMetadataEditor,
        );
        final topInset =
            MediaQuery.paddingOf(context).top +
            routeTopBar.preferredSize.height;

        return PopScope<void>(
          canPop: canPopRoute,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !mounted) {
              return;
            }
            context.go('/bookshelf');
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            extendBodyBehindAppBar: true,
            appBar: routeTopBar,
            floatingActionButton:
                ValueListenableBuilder<_BookDetailPresentationState>(
                  valueListenable: _presentationStateNotifier,
                  builder: (context, presentationState, _) {
                    final result = presentationState.result;
                    return result == null || usesInlineMetadataEditor
                        ? const SizedBox.shrink()
                        : (_buildReadFloatingActionButton(result) ??
                            const SizedBox.shrink());
                  },
                ),
            body: AnimatedBuilder(
              animation: _detailStateListenable,
              builder: (context, _) {
                final md3CoverBackdrop = _resolveDetailCoverBackdropProvider(
                  activeAdvancedTheme: activeAdvancedTheme,
                );
                final presentationState = _presentationState;
                final auxiliaryState = _auxiliaryState;
                final result = presentationState.result;
                final errorText = presentationState.errorText;
                final canSwitchFromMissingSource =
                    _canSwitchSource &&
                    presentationState.detailFailureDiagnostics?.code ==
                        ErrorCode.unknownSource.name;

                final content = LayoutBuilder(
                  builder: (context, _) {
                    final detailMaxWidth =
                        metrics.isMediumUpWindow
                            ? 960.0
                            : AppLayout.bookDetailContentMaxWidth;
                    final maxWidth = AppLayout.pageContentMaxWidth(
                      context,
                      maxWidth: detailMaxWidth,
                    );

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: AppRefreshIndicator(
                          onRefresh: () => _load(forceRefresh: true),
                          child: ListView(
                            controller: _detailScrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              topInset + metrics.sectionGap,
                              horizontal,
                              metrics.sectionGap +
                                  bottomSafe +
                                  (usesInlineMetadataEditor
                                      ? keyboardInset
                                      : 0),
                            ),
                            children: [
                              if (_metadataInlineNotice != null) ...[
                                _buildMetadataInlineNoticeCard(
                                  _metadataInlineNotice!,
                                ),
                                SizedBox(height: metrics.sectionGap),
                              ],
                              if (_isMissingParams)
                                BookDetailFeedbackCard(
                                  title: '参数不完整',
                                  message:
                                      '缺少 sourceId/detailUrl，无法加载详情。请从搜索结果进入。bookId=${widget.bookId}',
                                  tone: RuntimeFeedbackTone.warning,
                                )
                              else if (errorText != null && result == null)
                                BookDetailErrorPresenter(
                                  message: errorText,
                                  onRetry: () => _load(forceRefresh: true),
                                  onSwitchSource:
                                      canSwitchFromMissingSource
                                          ? _handleSwitchSource
                                          : null,
                                  onCopyDiagnostics:
                                      _isLocalContent
                                          ? _copyLocalDiagnosticsFromError
                                          : presentationState
                                                  .detailFailureDiagnostics ==
                                              null
                                          ? null
                                          : () => _copyOnlineDetailDiagnostics(
                                            presentationState
                                                .detailFailureDiagnostics!,
                                          ),
                                )
                              else if (result != null) ...[
                                ..._buildLoadedContentSections(
                                  presentationState: presentationState,
                                  auxiliaryState: auxiliaryState,
                                  result: result,
                                ),
                              ] else if (presentationState.isLoading) ...[
                                _buildInitialLoadingContent(
                                  auxiliaryState: auxiliaryState,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );

                if (md3CoverBackdrop == null) {
                  return DecoratedBox(
                    decoration: buildAdvancedThemeBackdropDecoration(backdrop),
                    child: content,
                  );
                }

                if (metrics.isMediumUpWindow) {
                  return DecoratedBox(
                    decoration: buildImageBackdropDecoration(
                      backgroundColor: colorScheme.surface,
                      surfaceColor: colorScheme.surfaceContainerLow,
                      imageProvider: md3CoverBackdrop,
                      imageOpacity: 0.48,
                      imageBlurSigma: 18,
                      imageFit: BoxFit.cover,
                      overlayColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.black
                              : colorScheme.surface,
                      overlayOpacity:
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.58
                              : 0.72,
                    ),
                    child: content,
                  );
                }

                final mobileBackdropHeight = math.min(
                  metrics.height * 0.52,
                  topInset + 330,
                );
                return DecoratedBox(
                  decoration: buildAdvancedThemeBackdropDecoration(backdrop),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        height: mobileBackdropHeight,
                        child: _MobileBookDetailCoverBackdrop(
                          imageProvider: md3CoverBackdrop,
                        ),
                      ),
                      content,
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _MobileBookDetailCoverBackdrop extends StatelessWidget {
  const _MobileBookDetailCoverBackdrop({required this.imageProvider});

  final ImageProvider imageProvider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = colorScheme.surface;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Transform.scale(
              scale: 1.18,
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface.withValues(alpha: isDark ? 0.48 : 0.62),
                  surface.withValues(alpha: isDark ? 0.74 : 0.78),
                  surface,
                ],
                stops: const [0, 0.58, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
