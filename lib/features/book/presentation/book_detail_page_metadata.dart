part of 'book_detail_page.dart';

extension on _BookDetailPageState {
  Future<void> _enterEditingMode() async {
    final result = _result;
    if (result == null) {
      _showMessage('当前书籍暂无可编辑项。');
      return;
    }
    final ensuredLocalBook =
        _isLocalContent ? await _ensureEditableLocalBookMeta() : _localBookMeta;
    final presentation = _resolvePresentedMetadata(result: result);
    _defaultSplitLongChapterEnabled =
        _isLocalContent
            ? await _readerSystemSettingsService
                .loadLocalTxtSplitLongChapterEnabled()
            : true;
    if (!mounted) {
      return;
    }
    _editTitleController.text = presentation.displayTitle;
    _editAuthorController.text = presentation.displayAuthor ?? '';
    _editIntroController.text = presentation.displayIntro ?? '';
    _editingCoverPath = presentation.customCoverPath;
    _editingCharset = ensuredLocalBook?.charset?.trim();
    if (_editingCharset != null && _editingCharset!.isEmpty) {
      _editingCharset = null;
    }
    _editingSplitLongChapter =
        ensuredLocalBook?.splitLongChapter ?? _defaultSplitLongChapterEnabled;
    _updateDetailPageState(() {
      _isEditingMetadata = true;
    });
  }

  void _cancelEditingMode() {
    if (!_isEditingMetadata) {
      return;
    }
    _updateDetailPageState(() {
      _isEditingMetadata = false;
      _isSavingMetadata = false;
    });
  }

  void _showMetadataInlineNotice(String message) {
    if (!mounted) {
      return;
    }
    _updateDetailPageState(() {
      _metadataInlineNotice = message;
    });
  }

  Future<void> _handleSaveMetadataEditing() async {
    final result = _result;
    final localBook =
        _isLocalContent ? await _ensureEditableLocalBookMeta() : _localBookMeta;
    if (result == null) {
      _showMessage('当前书籍暂无可编辑项。');
      return;
    }
    if (_editTitleController.text.trim().isEmpty) {
      _showMessage('书名不能为空。');
      return;
    }

    _updateDetailPageState(() {
      _isSavingMetadata = true;
    });
    try {
      final draft = BookDetailMetadataEditDraft(
        title: _editTitleController.text.trim(),
        author: _editAuthorController.text.trim(),
        intro: _editIntroController.text.trim(),
        customCoverPath: _editingCoverPath,
        charset: _editingCharset,
        splitLongChapter: _editingSplitLongChapter,
      );
      if (_isLocalContent && localBook != null) {
        await _saveLocalBookMetadata(
          result: result,
          localBook: localBook,
          draft: draft,
          defaultSplitLongChapterEnabled: _defaultSplitLongChapterEnabled,
        );
      } else {
        if (_isLocalContent) {
          _showMessage('本地图书信息尚未同步完成，请稍后重试。');
          return;
        }
        await _saveRemoteBookMetadata(result: result, draft: draft);
      }
      if (mounted) {
        _updateDetailPageState(() {
          _isEditingMetadata = false;
        });
      }
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('保存失败，请稍后重试。');
    } finally {
      if (mounted) {
        _updateDetailPageState(() {
          _isSavingMetadata = false;
        });
      }
    }
  }

  Future<void> _handleResetMetadataEditing() async {
    final result = _result;
    final localBook =
        _isLocalContent ? await _ensureEditableLocalBookMeta() : _localBookMeta;
    if (result == null) {
      return;
    }
    _updateDetailPageState(() {
      _isSavingMetadata = true;
    });
    try {
      if (_isLocalContent && localBook != null) {
        await _resetLocalBookMetadata(
          result: result,
          localBook: localBook,
          defaultSplitLongChapterEnabled: _defaultSplitLongChapterEnabled,
        );
      } else {
        if (_isLocalContent) {
          _showMessage('本地图书信息尚未同步完成，请稍后重试。');
          return;
        }
        await _resetRemoteBookMetadata(result: result);
      }
      if (mounted) {
        _updateDetailPageState(() {
          _isEditingMetadata = false;
        });
      }
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('恢复默认失败，请稍后重试。');
    } finally {
      if (mounted) {
        _updateDetailPageState(() {
          _isSavingMetadata = false;
        });
      }
    }
  }

  Future<void> _handleEditAction() async {
    await _enterEditingMode();
  }

  Future<String?> _pickEditableCoverPath(BookDetailLoadResult result) async {
    return _bookMetadataEditService.pickAndPersistCustomCover(
      detail: result.detail,
    );
  }

  Future<void> _saveRemoteBookMetadata({
    required BookDetailLoadResult result,
    required BookDetailMetadataEditDraft draft,
  }) async {
    _metadataMutationEpoch += 1;
    final flowResult = await _metadataFlowService.saveRemoteMetadata(
      result: result,
      draft: draft,
      isInBookshelf: _auxiliaryState.isInBookshelf,
      latestChapterTitle: _resolveLatestChapter(result)?.title,
    );
    _metadataOverride = flowResult.metadataOverride;
    _displayTitle = flowResult.presentation.displayTitle;
    _updatePresentationState(
      _presentationState.copyWith(
        result: _resultWithPresentation(result, flowResult.presentation),
      ),
    );
    _showMetadataInlineNotice(flowResult.successMessage);
    _showMessage(flowResult.successMessage);
  }

  Future<void> _saveLocalBookMetadata({
    required BookDetailLoadResult result,
    required LocalBook localBook,
    required BookDetailMetadataEditDraft draft,
    required bool defaultSplitLongChapterEnabled,
  }) async {
    _metadataMutationEpoch += 1;
    final flowResult = await _metadataFlowService.saveLocalMetadata(
      result: result,
      localBook: localBook,
      draft: draft,
      isInBookshelf: _auxiliaryState.isInBookshelf,
      latestChapterTitle: _resolveLatestChapter(result)?.title,
    );
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(localBookMeta: flowResult.localBook),
    );
    _displayTitle = flowResult.presentation.displayTitle;
    _updatePresentationState(
      _presentationState.copyWith(
        result: _resultWithPresentation(result, flowResult.presentation),
      ),
    );
    _showMetadataInlineNotice(flowResult.successMessage);
    _showMessage(flowResult.successMessage);

    if (flowResult.needsReindex && mounted) {
      final confirmed = await showAdaptiveActionSurface<bool>(
        context: context,
        maxWidth: 460,
        builder: (dialogContext) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '需要重新索引',
                style: Theme.of(
                  dialogContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                '编码或长章节拆分已修改，是否立即重新索引以使正文生效？',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('稍后'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('立即重建'),
                  ),
                ],
              ),
            ],
          );
        },
      );
      if (confirmed == true) {
        await _localBookIndexService.ensureIndexed(
          bookId: localBook.id,
          force: true,
        );
        if (mounted) {
          _showMessage('已开始重新索引。');
        }
      } else if (mounted && !defaultSplitLongChapterEnabled) {
        _showMessage('设置已保存，稍后重新索引后正文才会完全生效。');
      }
    }
  }

  Future<void> _resetRemoteBookMetadata({
    required BookDetailLoadResult result,
  }) async {
    final flowResult = await _metadataFlowService.resetRemoteMetadata(
      result: result,
      isInBookshelf: _auxiliaryState.isInBookshelf,
      latestChapterTitle: _resolveLatestChapter(result)?.title,
    );
    _metadataOverride = null;
    _displayTitle = flowResult.presentation.displayTitle;
    _updatePresentationState(
      _presentationState.copyWith(
        result: _resultWithPresentation(result, flowResult.presentation),
      ),
    );
    _showMetadataInlineNotice(flowResult.successMessage);
    _showMessage(flowResult.successMessage);
  }

  Future<void> _resetLocalBookMetadata({
    required BookDetailLoadResult result,
    required LocalBook localBook,
    required bool defaultSplitLongChapterEnabled,
  }) async {
    final flowResult = await _metadataFlowService.resetLocalMetadata(
      result: result,
      localBook: localBook,
      defaultSplitLongChapterEnabled: defaultSplitLongChapterEnabled,
      isInBookshelf: _auxiliaryState.isInBookshelf,
      latestChapterTitle: _resolveLatestChapter(result)?.title,
    );
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(localBookMeta: flowResult.localBook),
    );
    _displayTitle = flowResult.presentation.displayTitle;
    _updatePresentationState(
      _presentationState.copyWith(
        result: _resultWithPresentation(result, flowResult.presentation),
      ),
    );
    _showMetadataInlineNotice(flowResult.successMessage);
    _showMessage(flowResult.successMessage);
  }

  BookDetailLoadResult _resultWithPresentation(
    BookDetailLoadResult result,
    BookDisplayState presentation,
  ) {
    return result.copyWith(
      detail: BookDetail(
        id: result.detail.id,
        sourceId: result.detail.sourceId,
        title: presentation.displayTitle,
        detailUrl: result.detail.detailUrl,
        author: presentation.displayAuthor,
        intro: presentation.displayIntro,
        coverUrl: presentation.displayCover ?? result.detail.coverUrl,
        tocUrl: result.detail.tocUrl,
      ),
    );
  }
}
