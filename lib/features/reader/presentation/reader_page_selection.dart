part of 'reader_page.dart';

extension _ReaderPageSelectionExtension on _ReaderPageState {
  Widget _wrapSelectionArea({required Widget child}) {
    return SelectionArea(
      key: _selectionAreaKey,
      contextMenuBuilder: _buildSelectionContextMenu,
      onSelectionChanged: _handleSelectionChanged,
      child: SelectionListener(
        selectionNotifier: _selectionNotifier,
        child: child,
      ),
    );
  }

  void _routeReaderChildTap(bool handled) {
    if (!handled) {
      return;
    }
    _markReaderTapHandledByChild();
    if (_isAutoReadSessionEnabled) {
      _pauseAutoReadSession();
    }
  }

  void _clearSystemSelection() {
    final selectionAreaState = _selectionAreaKey.currentState;
    if (selectionAreaState == null) {
      return;
    }
    selectionAreaState.selectableRegion.clearSelection();
  }

  bool _handleBookmarkTap({
    required int paragraphIndex,
    required String paragraphText,
    required Offset localPosition,
    required double maxWidth,
    required TextStyle textStyle,
    required TextAlign textAlign,
  }) {
    final ranges = _bookmarkRangesByParagraph[paragraphIndex];
    if (ranges == null || ranges.isEmpty) {
      return false;
    }

    final displayText = _applyParagraphIndent(paragraphText);
    if (displayText.isEmpty) {
      return false;
    }
    final hitRange = resolveTappedAnnotationRange(
      ranges: ranges
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
      displayText: displayText,
      indentLength: displayText.length - paragraphText.length,
      rawTextLength: paragraphText.length,
      localPosition: localPosition,
      maxWidth: maxWidth,
      textStyle: textStyle,
      textDirection: Directionality.of(context),
      textAlign: textAlign,
    );
    final resolvedRange = hitRange;
    if (resolvedRange == null) {
      return false;
    }

    final snippet =
        paragraphText.substring(resolvedRange.start, resolvedRange.end).trim();
    if (snippet.isEmpty) {
      return false;
    }

    final startOffset = _resolveChapterOffsetFromParagraph(
      paragraphIndex: paragraphIndex,
      paragraphOffset: resolvedRange.start,
    );
    final endOffset = _resolveChapterOffsetFromParagraph(
      paragraphIndex: paragraphIndex,
      paragraphOffset: resolvedRange.end,
    );

    _activateSelectionFromBookmarkRange(
      startOffset: startOffset,
      endOffset: endOffset,
      snippet: snippet,
      hasHighlight: resolvedRange.hasHighlight,
      isBold: resolvedRange.isBold,
      isUnderline: resolvedRange.isUnderline,
      isWavy: resolvedRange.isWavy,
    );
    return true;
  }

  bool _handleBookmarkTapInSlice({
    required ReaderPagedSlice slice,
    required String paragraphText,
    required Offset localPosition,
    required double maxWidth,
    required TextStyle textStyle,
    required TextAlign textAlign,
  }) {
    final ranges = _bookmarkRangesByParagraph[slice.paragraphIndex];
    if (ranges == null || ranges.isEmpty) {
      return false;
    }

    final rawText = paragraphText.substring(slice.start, slice.end);
    final displayText =
        slice.start == 0 ? _applyParagraphIndent(rawText) : rawText;
    if (displayText.isEmpty) {
      return false;
    }
    final localRange = resolveTappedAnnotationRange(
      ranges: ranges
          .map(
            (range) => ReaderTextAnnotationRange(
              range.start - slice.start,
              range.end - slice.start,
              hasHighlight: range.hasHighlight,
              isBold: range.isBold,
              isUnderline: range.isUnderline,
              isWavy: range.isWavy,
            ),
          )
          .where(
            (range) => range.end > 0 && range.start < (slice.end - slice.start),
          )
          .map(
            (range) => ReaderTextAnnotationRange(
              _clampInt(range.start, 0, slice.end - slice.start),
              _clampInt(range.end, 0, slice.end - slice.start),
              hasHighlight: range.hasHighlight,
              isBold: range.isBold,
              isUnderline: range.isUnderline,
              isWavy: range.isWavy,
            ),
          )
          .toList(growable: false),
      displayText: displayText,
      indentLength: slice.start == 0 ? displayText.length - rawText.length : 0,
      rawTextLength: slice.end - slice.start,
      localPosition: localPosition,
      maxWidth: maxWidth,
      textStyle: textStyle,
      textDirection: Directionality.of(context),
      textAlign: textAlign,
    );
    final hitRange =
        localRange == null
            ? null
            : ReaderBookmarkRange(
              localRange.start + slice.start,
              localRange.end + slice.start,
              hasHighlight: localRange.hasHighlight,
              isBold: localRange.isBold,
              isUnderline: localRange.isUnderline,
              isWavy: localRange.isWavy,
            );
    final resolvedRange = hitRange;
    if (resolvedRange == null) {
      return false;
    }

    final snippet =
        paragraphText.substring(resolvedRange.start, resolvedRange.end).trim();
    if (snippet.isEmpty) {
      return false;
    }

    final startOffset = _resolveChapterOffsetFromParagraph(
      paragraphIndex: slice.paragraphIndex,
      paragraphOffset: resolvedRange.start,
    );
    final endOffset = _resolveChapterOffsetFromParagraph(
      paragraphIndex: slice.paragraphIndex,
      paragraphOffset: resolvedRange.end,
    );

    _activateSelectionFromBookmarkRange(
      startOffset: startOffset,
      endOffset: endOffset,
      snippet: snippet,
      hasHighlight: resolvedRange.hasHighlight,
      isBold: resolvedRange.isBold,
      isUnderline: resolvedRange.isUnderline,
      isWavy: resolvedRange.isWavy,
    );
    return true;
  }

  void _activateSelectionFromBookmarkRange({
    required int startOffset,
    required int endOffset,
    required String snippet,
    required bool hasHighlight,
    required bool isBold,
    required bool isUnderline,
    required bool isWavy,
  }) {
    _updateReaderState(() {
      _selectionState = _selectionState.activate(
        startOffset: startOffset,
        endOffset: endOffset,
        snippet: snippet,
        highlight: hasHighlight,
        bold: isBold,
        underline: isUnderline && !isWavy,
        wavy: isWavy,
      );
    });
    unawaited(_syncVolumeKeyPageInterception());
    _showBookmarkToolbar();
  }

  void _handleSelectionChanged(SelectedContent? content) {
    _selectedSnippet = content?.plainText.trim() ?? '';
    _syncSelectionState();
  }

  ReaderSelectionStyle _resolveSelectionStyleByOverlap({
    required int startOffset,
    required int endOffset,
  }) {
    if (_chapterBookmarks.isEmpty) {
      return const ReaderSelectionStyle(
        highlight: false,
        bold: false,
        underline: false,
        wavy: false,
      );
    }

    var hasHighlight = false;
    var hasBold = false;
    var hasUnderline = false;
    var hasWavy = false;
    for (final bookmark in _chapterBookmarks) {
      if (!_isBookmarkInCurrentChapter(bookmark)) {
        continue;
      }
      final overlaps =
          endOffset > bookmark.startOffset && startOffset < bookmark.endOffset;
      if (!overlaps) {
        continue;
      }
      if (_bookmarkHasHighlight(bookmark)) {
        hasHighlight = true;
      }
      if (bookmark.isBold) {
        hasBold = true;
      }
      if (bookmark.isWavy) {
        hasWavy = true;
      }
      if (bookmark.isUnderline) {
        hasUnderline = true;
      }
    }

    if (hasWavy) {
      hasUnderline = false;
    }

    return ReaderSelectionStyle(
      highlight: hasHighlight,
      bold: hasBold,
      underline: hasUnderline,
      wavy: hasWavy,
    );
  }

  void _handleSelectionNotifierChanged() {
    if (!_selectionNotifier.registered) {
      return;
    }
    final details = _selectionNotifier.selection;
    if (details.status != SelectionStatus.uncollapsed &&
        !_isTextSelectionActive &&
        !_selectionState.hasSnippet) {
      return;
    }
    _logLongPressTrace(
      'selection_notifier_changed',
      context: <String, Object?>{
        'status': details.status.name,
        'selectionActive': _isTextSelectionActive,
        'hasSnippet': _selectionState.hasSnippet,
      },
    );
    if (details.status != SelectionStatus.none) {
      _markReaderTapHandledByChild();
    }
    _selectionStatus = details.status;
    if (_isEditingBookmarkNote &&
        _selectionStatus != SelectionStatus.uncollapsed) {
      return;
    }
    if (_selectionStatus != SelectionStatus.uncollapsed) {
      _clearSelectionState();
      return;
    }
    try {
      _selectionRange = details.range;
      _logLongPressTrace(
        'selection_range_captured',
        context: <String, Object?>{
          'startOffset': details.range?.startOffset,
          'endOffset': details.range?.endOffset,
        },
      );
    } catch (_) {
      _logLongPressTrace('selection_range_capture_failed');
      _clearSelectionState();
      return;
    }
    _syncSelectionState();
  }

  void _syncSelectionState() {
    final range = _selectionRange;
    final snippet = _selectedSnippet.trim();
    final hasRange = range != null;
    final hasSnippet = snippet.isNotEmpty;
    final isActive =
        _selectionStatus == SelectionStatus.uncollapsed &&
        hasRange &&
        hasSnippet;
    _logLongPressTrace(
      'selection_sync',
      context: <String, Object?>{
        'selectionStatus': _selectionStatus.name,
        'hasRange': hasRange,
        'hasSnippet': hasSnippet,
        'snippetLength': snippet.length,
        'isActive': isActive,
      },
    );

    if (!isActive) {
      if (_isEditingBookmarkNote) {
        return;
      }
      if (_isTextSelectionActive &&
          (_selectionStatus != SelectionStatus.uncollapsed ||
              !hasRange ||
              !hasSnippet)) {
        _clearSelectionState();
      }
      return;
    }

    _hideBookmarkToolbar();

    final startOffset = _resolveChapterOffsetFromDisplayOffset(
      range.startOffset,
    );
    final endOffset = _resolveChapterOffsetFromDisplayOffset(range.endOffset);
    var safeStart = min(startOffset, endOffset);
    var safeEnd = max(startOffset, endOffset);
    final totalLength = _chapterTextLength();
    if (safeStart == safeEnd) {
      safeEnd = min(safeStart + 1, totalLength);
    }
    if (safeEnd <= safeStart) {
      _clearSelectionState();
      return;
    }

    final overlapStyle = _resolveSelectionStyleByOverlap(
      startOffset: safeStart,
      endOffset: safeEnd,
    );
    final nextBold = overlapStyle.bold;
    final nextWavy = overlapStyle.wavy;
    final nextUnderline = overlapStyle.underline;

    final wasActive = _isTextSelectionActive;
    if (!wasActive && (_isTextPagedViewport || _isTextScrollViewport)) {
      final paragraphTarget =
          _resolveParagraphSelectionTargetForOffset(safeStart) ??
          _resolveParagraphSelectionTargetForOffset(safeEnd);
      if (paragraphTarget != null) {
        safeStart = paragraphTarget.startOffset;
        safeEnd = paragraphTarget.endOffset;
        _selectedSnippet = paragraphTarget.snippet;
      }
    }
    _updateReaderState(() {
      _selectionState = _selectionState.activate(
        startOffset: safeStart,
        endOffset: safeEnd,
        snippet: _selectedSnippet,
        highlight: overlapStyle.highlight,
        bold: nextBold,
        underline: nextUnderline,
        wavy: nextWavy,
      );
    });
    unawaited(_syncVolumeKeyPageInterception());

    if (!wasActive) {
      if (_isAutoReadSessionEnabled) {
        _pauseAutoReadSession();
      }
      _hideOverlayControls(resumeAutoRead: false);
      _logLongPressTrace(
        'selection_activated',
        context: <String, Object?>{
          'startOffset': safeStart,
          'endOffset': safeEnd,
          'snippetLength': _selectedSnippet.length,
        },
      );
    }
  }

  void _clearSelectionState() {
    if (!_isTextSelectionActive && !_selectionState.hasSnippet) {
      _selectionState = _selectionState.copyWith(
        range: null,
        status: SelectionStatus.none,
      );
      return;
    }
    _logLongPressTrace(
      'selection_clear',
      context: <String, Object?>{
        'selectionActive': _isTextSelectionActive,
        'hasSnippet': _selectionState.hasSnippet,
      },
    );

    _updateReaderState(() {
      _selectionState = _selectionState.clear();
    });
    unawaited(_syncVolumeKeyPageInterception());
    _hideBookmarkToolbar();
  }

  void _showBookmarkToolbar() {
    if (!mounted) {
      return;
    }
    _hideBookmarkToolbar();
    final overlayDecision = _selectionOverlayPolicy.resolveToolbarHost(
      rootOverlayIssueVerified: false,
      foregroundAnchorsValidated: false,
    );
    if (!overlayDecision.usesRootOverlay) {
      return;
    }

    final entry = OverlayEntry(
      builder: (context) {
        final fallbackAnchor = Offset(
          MediaQuery.sizeOf(context).width / 2,
          MediaQuery.sizeOf(context).height - 160,
        );
        return _buildInspirationActionPanel(
          anchors:
              _selectionAreaKey
                  .currentState
                  ?.selectableRegion
                  .contextMenuAnchors ??
              TextSelectionToolbarAnchors(
                primaryAnchor: fallbackAnchor,
                secondaryAnchor: fallbackAnchor,
              ),
          dismiss: _clearSelectionState,
          actions: _buildInspirationActionItems(clearSelectionState: null),
        );
      },
    );
    _bookmarkToolbarEntry = entry;
    final overlay = Overlay.maybeOf(
      context,
      rootOverlay: overlayDecision.usesRootOverlay,
    );
    if (overlay == null) {
      _bookmarkToolbarEntry = null;
      return;
    }
    overlay.insert(entry);
  }

  void _hideBookmarkToolbar() {
    _bookmarkToolbarEntry?.remove();
    _bookmarkToolbarEntry = null;
  }

  Widget _buildSelectionContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    if (!selectableRegionState.mounted) {
      return const SizedBox.shrink();
    }

    return _buildInspirationActionPanel(
      anchors: selectableRegionState.contextMenuAnchors,
      dismiss: () {
        selectableRegionState.hideToolbar();
        selectableRegionState.clearSelection();
        _clearSelectionState();
      },
      actions: _buildInspirationActionItems(
        clearSelectionState: selectableRegionState,
        hideToolbar: selectableRegionState.hideToolbar,
      ),
    );
  }

  List<ReaderInspirationActionItem> _buildInspirationActionItems({
    required SelectableRegionState? clearSelectionState,
    VoidCallback? hideToolbar,
  }) {
    final presenterState = _annotationPresenter.resolveState(
      selectionState: _selectionState,
      existingBookmark: _currentSelectionBookmark(),
    );
    if (presenterState.actions.isEmpty) {
      return const <ReaderInspirationActionItem>[];
    }

    void closeMenus() {
      hideToolbar?.call();
      _hideBookmarkToolbar();
    }

    return _selectionToolbarPresenter.buildItems(
      actions: presenterState.actions,
      onAction:
          (action) => switch (action.kind) {
            ReaderAnnotationToolbarActionKind.copy => () {
              closeMenus();
              unawaited(
                _copySelectedSnippet(clearSelectionState: clearSelectionState),
              );
            },
            ReaderAnnotationToolbarActionKind.saveOrRemoveBookmark => () {
              closeMenus();
              if (presenterState.toolbarState.existingBookmark
                  case final bookmark?) {
                unawaited(
                  _onRemoveBookmarkPressed(
                    bookmark,
                    clearSelectionState: clearSelectionState,
                  ),
                );
                return;
              }
              unawaited(
                _onSaveBookmarkPressed(
                  clearSelectionState: clearSelectionState,
                ),
              );
            },
            ReaderAnnotationToolbarActionKind.editNote => () {
              _isEditingBookmarkNote = true;
              hideToolbar?.call();
              _hideBookmarkToolbar();
              unawaited(
                _onEditBookmarkNotePressed(
                  clearSelectionState: clearSelectionState,
                ),
              );
            },
            ReaderAnnotationToolbarActionKind.toggleHighlight =>
              () => unawaited(_toggleSelectionHighlight()),
            ReaderAnnotationToolbarActionKind.toggleBold =>
              () => unawaited(_toggleSelectionBold()),
            ReaderAnnotationToolbarActionKind.toggleUnderline =>
              () => unawaited(_toggleSelectionUnderline()),
            ReaderAnnotationToolbarActionKind.toggleWavy =>
              () => unawaited(_toggleSelectionWavy()),
            ReaderAnnotationToolbarActionKind.clearSelection => () {
              closeMenus();
              clearSelectionState?.clearSelection();
              _clearSelectionState();
            },
          },
    );
  }

  Widget _buildInspirationActionPanel({
    required TextSelectionToolbarAnchors anchors,
    required VoidCallback dismiss,
    required List<ReaderInspirationActionItem> actions,
  }) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preview = _selectedSnippet.trim();
    final screenSize = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final anchorTop = anchors.primaryAnchor.dy;
    final anchorBottom = anchors.secondaryAnchor?.dy ?? anchorTop;
    final panelWidth = min(screenSize.width - 24, 520.0).toDouble();
    final secondaryAnchorX =
        anchors.secondaryAnchor?.dx ?? anchors.primaryAnchor.dx;
    final anchorCenterX = (anchors.primaryAnchor.dx + secondaryAnchorX) / 2;
    final maxLeft = max(12.0, screenSize.width - panelWidth - 12);
    final left = (anchorCenterX - panelWidth / 2).clamp(12.0, maxLeft);
    final estimatedPanelHeight = preview.isNotEmpty ? 212.0 : 148.0;
    final gap = 12.0;
    final spaceBelow = screenSize.height - anchorBottom - bottomInset - gap;
    final spaceAbove = anchorTop - safePadding.top - gap;
    final showBelow =
        spaceBelow >= estimatedPanelHeight ||
        (anchorTop < screenSize.height * 0.45 && spaceBelow >= 120);
    final topPosition =
        showBelow
            ? (anchorBottom + gap)
                .clamp(12.0, screenSize.height - 80)
                .toDouble()
            : null;
    final bottomPosition =
        showBelow
            ? null
            : (screenSize.height - anchorTop + gap)
                .clamp(12.0, max(12.0, screenSize.height - 80))
                .toDouble();
    final maxPanelHeight = max(
      140.0,
      min(screenSize.height * 0.42, (showBelow ? spaceBelow : spaceAbove) - 8),
    );

    return Stack(
      children: [
        ReaderFullScreenHitTestLayer(
          strategy: ReaderFullScreenHitTestStrategy.interceptWhenVisible,
          behavior: HitTestBehavior.translucent,
          onTap: dismiss,
          child: const SizedBox.shrink(),
        ),
        Positioned(
          left: left,
          top: topPosition,
          bottom: bottomPosition,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: panelWidth,
              maxHeight: maxPanelHeight,
            ),
            child: Material(
              color: colorScheme.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (preview.isNotEmpty) ...[
                        Text(
                          '所选内容',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          for (final action in actions)
                            ReaderInspirationActionChip(
                              action: action,
                              colorScheme: colorScheme,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleSelectionBold() async {
    if (!_isTextSelectionActive) {
      return;
    }
    _updateReaderState(() {
      _selectionBold = !_selectionBold;
    });
    await _persistSelectionStyleForSelection(
      createdMessage: _selectionBold ? '已保存灵感并加粗重点' : '已保存灵感',
    );
  }

  Future<void> _toggleSelectionHighlight() async {
    if (!_isTextSelectionActive) {
      return;
    }
    _updateReaderState(() {
      _selectionHighlight = !_selectionHighlight;
    });
    await _persistSelectionStyleForSelection(
      createdMessage: _selectionHighlight ? '已保存灵感并高亮' : '已保存灵感',
    );
  }

  Future<void> _toggleSelectionUnderline() async {
    if (!_isTextSelectionActive) {
      return;
    }
    _updateReaderState(() {
      _selectionUnderline = !_selectionUnderline;
      if (_selectionUnderline) {
        _selectionWavy = false;
      }
    });
    await _persistSelectionStyleForSelection(
      createdMessage: _selectionUnderline ? '已保存灵感并添加划线' : '已保存灵感',
    );
  }

  Future<void> _copySelectedSnippet({
    SelectableRegionState? clearSelectionState,
  }) async {
    final snippet = _selectedSnippet.trim();
    final decision = _selectionController.resolveAction(
      action: ReaderSelectionAction.copy,
      textSelectionActive: _isTextSelectionActive,
      hasSnippet: snippet.isNotEmpty,
      hasExistingBookmark: false,
    );
    if (!decision.canExecute) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: snippet));
    if (!mounted) {
      return;
    }
    _showMessage('已复制所选内容');
    _clearSelectionState();
    clearSelectionState?.clearSelection();
  }

  Future<void> _toggleSelectionWavy() async {
    if (!_isTextSelectionActive) {
      return;
    }
    _updateReaderState(() {
      _selectionWavy = !_selectionWavy;
      if (_selectionWavy) {
        _selectionUnderline = false;
      }
    });
    await _persistSelectionStyleForSelection(
      createdMessage: _selectionWavy ? '已保存灵感并添加波浪线' : '已保存灵感',
    );
  }

  Future<void> _onSaveBookmarkPressed({
    SelectableRegionState? clearSelectionState,
  }) async {
    final existing = _currentSelectionBookmark();
    final decision = _selectionController.resolveAction(
      action: ReaderSelectionAction.saveBookmark,
      textSelectionActive: _isTextSelectionActive,
      hasSnippet: _selectedSnippet.isNotEmpty,
      hasExistingBookmark: existing != null,
    );
    if (!decision.canExecute) {
      final message = decision.message;
      if (message != null) {
        _showMessage(message);
        _clearSelectionState();
        clearSelectionState?.clearSelection();
      }
      return;
    }

    await _saveSelectionBookmark(
      clearSelectionState: clearSelectionState,
      forceHighlight: false,
    );
    _showMessage('已保存灵感');
    _clearSelectionState();
  }

  Future<void> _onRemoveBookmarkPressed(
    Bookmark bookmark, {
    SelectableRegionState? clearSelectionState,
  }) async {
    await _bookmarkRepository.removeBookmark(bookmark.id);
    _showMessage('已删除灵感');
    unawaited(_refreshChapterBookmarks());
    _clearSelectionState();
    clearSelectionState?.clearSelection();
  }

  Future<void> _onEditBookmarkNotePressed({
    SelectableRegionState? clearSelectionState,
  }) async {
    if (!_isTextSelectionActive || _selectedSnippet.isEmpty || !mounted) {
      _isEditingBookmarkNote = false;
      return;
    }
    final snapshot = _captureSelectionSnapshot();
    if (snapshot == null) {
      _isEditingBookmarkNote = false;
      return;
    }
    final existing = _currentSelectionBookmark();
    try {
      final note = await _showBookmarkNoteEditor(initialNote: existing?.note);
      _restoreSelectionSnapshot(snapshot);
      if (note == null) {
        return;
      }
      await _saveSelectionBookmark(
        existing: existing,
        clearSelectionState: clearSelectionState,
        note: note,
        selectionSnapshot: snapshot,
        clearSystemSelection: false,
      );
      if (!mounted) {
        return;
      }
      _showMessage(note.isEmpty ? '已保存灵感' : '已保存笔记');
      _restoreSelectionSnapshot(snapshot, showToolbar: true);
    } finally {
      _isEditingBookmarkNote = false;
    }
  }

  Future<void> _persistSelectionStyleForSelection({
    required String createdMessage,
  }) async {
    if (!_isTextSelectionActive || _selectedSnippet.isEmpty) {
      return;
    }
    final existing = _currentSelectionBookmark();
    await _saveSelectionBookmark(existing: existing, clearSelectionState: null);
    _bookmarkToolbarEntry?.markNeedsBuild();
    if (existing == null) {
      _showMessage(createdMessage);
    }
  }

  Future<void> _saveSelectionBookmark({
    Bookmark? existing,
    SelectableRegionState? clearSelectionState,
    bool? forceHighlight,
    String? note,
    ReaderSelectionSnapshot? selectionSnapshot,
    bool clearSystemSelection = true,
  }) async {
    final selection = selectionSnapshot ?? _captureSelectionSnapshot();
    if (selection == null) {
      return;
    }
    final now = DateTime.now();
    final startOffset = selection.startOffset;
    final endOffset = selection.endOffset;
    if (startOffset == endOffset) {
      return;
    }

    final isWavy = selection.isWavy;
    final isUnderline = isWavy ? false : selection.isUnderline;
    final hasHighlight = forceHighlight ?? selection.hasHighlight;
    final effectiveNote = note ?? existing?.note;
    final bookmark = Bookmark(
      id: existing?.id ?? _uuid.v4().replaceAll('-', ''),
      bookId: _currentBookId,
      chapterId: _chapterId,
      chapterIndex: _currentIndex ?? 0,
      startOffset: startOffset,
      endOffset: endOffset,
      snippet: selection.snippet,
      note: effectiveNote,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      isBold: selection.isBold,
      isUnderline: isUnderline,
      isWavy: isWavy,
      color:
          hasHighlight
              ? _ReaderPageState._kBookmarkDefaultHighlightToken
              : _ReaderPageState._kBookmarkNoHighlightToken,
    );

    await _bookmarkRepository.addBookmark(bookmark);
    unawaited(_refreshChapterBookmarks());
    if (clearSystemSelection) {
      clearSelectionState?.clearSelection();
    }
  }

  ReaderSelectionSnapshot? _captureSelectionSnapshot() {
    return _selectionState.snapshot();
  }

  void _restoreSelectionSnapshot(
    ReaderSelectionSnapshot snapshot, {
    bool showToolbar = false,
  }) {
    if (!mounted) {
      return;
    }
    _updateReaderState(() {
      _selectionState = _selectionState.restore(snapshot);
    });
    if (showToolbar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isTextSelectionActive) {
          return;
        }
        _showBookmarkToolbar();
      });
    }
  }

  Future<String?> _showBookmarkNoteEditor({String? initialNote}) {
    final controller = TextEditingController(text: initialNote ?? '');
    return showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 520,
      maxHeightFactor: 0.72,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '记笔记',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '会和当前灵感一起保存，后续可在灵感列表和书内灵感里查看。',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: '写下此刻想到的内容',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  AppButton(
                    variant: AppButtonVariant.text,
                    onPressed: () => Navigator.of(sheetContext).pop(''),
                    label: '清空笔记',
                  ),
                  const Spacer(),
                  AppButton(
                    variant: AppButtonVariant.text,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    label: '取消',
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    onPressed:
                        () => Navigator.of(
                          sheetContext,
                        ).pop(controller.text.trim()),
                    label: '保存',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
