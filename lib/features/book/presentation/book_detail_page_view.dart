part of 'book_detail_page.dart';

extension on _BookDetailPageState {
  Widget _buildBookDetailPage(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final activeAdvancedTheme =
            ref.watch(activeAdvancedThemeProvider).valueOrNull;
        final colorScheme = Theme.of(context).colorScheme;
        final backdrop = resolveAdvancedThemeBackdrop(
          colorScheme,
          activeAdvancedTheme,
        );
        final horizontal = AppSpacing.pageHorizontal(context);
        final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
        final canPopRoute = context.canPop();

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
              backgroundColor: Colors.transparent,
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
            body: DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
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
                      child: AnimatedBuilder(
                        animation: _detailStateListenable,
                        builder: (context, _) {
                          final presentationState = _presentationState;
                          final auxiliaryState = _auxiliaryState;
                          final result = presentationState.result;
                          final errorText = presentationState.errorText;
                          return RefreshIndicator(
                            onRefresh: () => _load(forceRefresh: true),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                horizontal,
                                topInset + 16,
                                horizontal,
                                16 +
                                    bottomSafe +
                                    (_isEditingMetadata ? keyboardInset : 0),
                              ),
                              children: [
                                if (_metadataInlineNotice != null) ...[
                                  _buildMetadataInlineNoticeCard(
                                    _metadataInlineNotice!,
                                  ),
                                  const SizedBox(height: 12),
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
                                  _buildInitialLoadingContent(),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

}
