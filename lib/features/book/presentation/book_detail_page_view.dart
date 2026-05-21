part of 'book_detail_page.dart';

extension on _BookDetailPageState {
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
        final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
        final canPopRoute = context.canPop();
        final clampedOffset = _detailScrollOffset.clamp(0.0, 96.0);
        final appBarOverlayOpacity = (clampedOffset / 96.0).clamp(0.0, 1.0);

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
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(
                alpha: appBarOverlayOpacity * 0.92,
              ),
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              leading: IconButton(
                onPressed: _handleBackNavigation,
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back),
              ),
              actions: [
                if (_isEditingMetadata) ...[
                  TextButton(
                    onPressed: _isSavingMetadata ? null : _cancelEditingMode,
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed:
                        _isSavingMetadata ? null : _handleResetMetadataEditing,
                    child: const Text('恢复默认'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton(
                      onPressed:
                          _isSavingMetadata ? null : _handleSaveMetadataEditing,
                      child: Text(_isSavingMetadata ? '保存中' : '保存'),
                    ),
                  ),
                ] else ...[
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
                ],
              ],
            ),
            floatingActionButton:
                ValueListenableBuilder<_BookDetailPresentationState>(
                  valueListenable: _presentationStateNotifier,
                  builder: (context, presentationState, _) {
                    final result = presentationState.result;
                    return result == null || _isEditingMetadata
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

                return DecoratedBox(
                  decoration:
                      md3CoverBackdrop == null
                          ? buildAdvancedThemeBackdropDecoration(backdrop)
                          : buildImageBackdropDecoration(
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
                  child: LayoutBuilder(
                    builder: (context, _) {
                      final maxWidth = AppLayout.pageContentMaxWidth(
                        context,
                        maxWidth: AppLayout.bookDetailContentMaxWidth,
                      );

                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: RefreshIndicator(
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
                                    (_isEditingMetadata ? keyboardInset : 0),
                              ),
                              children: [
                                if (_metadataInlineNotice != null) ...[
                                  _buildMetadataInlineNoticeCard(
                                    _metadataInlineNotice!,
                                  ),
                                  SizedBox(height: metrics.sectionGap),
                                ],
                                if (_isMissingParams)
                                  RuntimeFeedbackCard(
                                    title: '参数不完整',
                                    message:
                                        '缺少 sourceId/detailUrl，无法加载详情。请从搜索结果进入。bookId=${widget.bookId}',
                                    tone: RuntimeFeedbackTone.warning,
                                  )
                                else if (errorText != null && result == null)
                                  RuntimeFeedbackCard(
                                    title: '加载失败',
                                    message: errorText,
                                    tone: RuntimeFeedbackTone.error,
                                    actions: [
                                      FilledButton.tonal(
                                        onPressed:
                                            () => _load(forceRefresh: true),
                                        child: const Text('重试'),
                                      ),
                                      if (_isLocalContent)
                                        OutlinedButton.icon(
                                          onPressed:
                                              _copyLocalDiagnosticsFromError,
                                          icon: const Icon(
                                            Icons.copy_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('复制诊断信息'),
                                        ),
                                    ],
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
