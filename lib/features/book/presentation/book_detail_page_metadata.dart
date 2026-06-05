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
    _editCoverController.text =
        presentation.customCoverPath ?? presentation.realCoverUrl ?? '';
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
        customCoverPath: _resolveEditingCoverDraftValue(result),
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
    final useDesktopEditor = AppAdaptiveMetrics.of(context).isMediumUpWindow;
    await _enterEditingMode();
    if (!mounted || !_isEditingMetadata || !useDesktopEditor) {
      return;
    }
    final result = _result;
    if (result == null) {
      _cancelEditingMode();
      return;
    }
    await _showDesktopMetadataEditorDialog(result);
  }

  /// 桌面端编辑使用弹窗承载，业务状态仍复用详情页现有控制器和保存链路。
  Future<void> _showDesktopMetadataEditorDialog(
    BookDetailLoadResult result,
  ) async {
    await showAdaptiveActionSurface<bool>(
      context: context,
      mode: AdaptiveActionSurfaceMode.desktopDialog,
      maxWidth: 920,
      maxHeightFactor: 0.9,
      padding: EdgeInsets.zero,
      builder: (surfaceContext) {
        return StatefulBuilder(
          builder: (surfaceContext, setSurfaceState) {
            Future<void> closeAfterSuccessfulAction(
              Future<void> Function() action,
            ) async {
              final actionFuture = action();
              if (!mounted || !surfaceContext.mounted) {
                return;
              }
              setSurfaceState(() {});
              await actionFuture;
              if (!mounted || !surfaceContext.mounted) {
                return;
              }
              setSurfaceState(() {});
              if (!_isEditingMetadata) {
                Navigator.of(surfaceContext).pop(true);
              }
            }

            return _buildDesktopMetadataEditorDialog(
              surfaceContext: surfaceContext,
              result: _result ?? result,
              auxiliaryState: _auxiliaryState,
              refreshSurface: () {
                if (surfaceContext.mounted) {
                  setSurfaceState(() {});
                }
              },
              onCancel: () => Navigator.of(surfaceContext).pop(false),
              onReset:
                  () => closeAfterSuccessfulAction(_handleResetMetadataEditing),
              onSave:
                  () => closeAfterSuccessfulAction(_handleSaveMetadataEditing),
            );
          },
        );
      },
    );

    if (mounted && _isEditingMetadata) {
      _cancelEditingMode();
    }
  }

  Future<String?> _pickEditableCoverPath(
    BookDetailLoadResult result, {
    ImageSelectionSource source = ImageSelectionSource.auto,
  }) async {
    return _bookMetadataEditService.pickAndPersistCustomCover(
      detail: result.detail,
      source: source,
    );
  }

  Future<void> _showEditableCoverActionSheet(
    BookDetailLoadResult result,
  ) async {
    final action = await showAdaptiveActionSurface<_EditableCoverAction>(
      context: context,
      maxWidth: 420,
      padding: EdgeInsets.zero,
      builder: (surfaceContext) {
        final colorScheme = Theme.of(surfaceContext).colorScheme;
        final bottomInset = MediaQuery.viewPaddingOf(surfaceContext).bottom;
        return SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 12 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '更换封面',
                    textAlign: TextAlign.center,
                    style: Theme.of(surfaceContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('相册'),
                  subtitle: const Text('从系统照片库选择封面图片'),
                  onTap:
                      () => Navigator.of(
                        surfaceContext,
                      ).pop(_EditableCoverAction.gallery),
                ),
                ListTile(
                  leading: Icon(
                    Icons.folder_open_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('文件'),
                  subtitle: const Text('从文件 App 或本地目录选择封面图片'),
                  onTap:
                      () => Navigator.of(
                        surfaceContext,
                      ).pop(_EditableCoverAction.files),
                ),
                ListTile(
                  leading: Icon(Icons.link_rounded, color: colorScheme.primary),
                  title: const Text('封面链接'),
                  subtitle: const Text('粘贴图片链接作为封面'),
                  onTap:
                      () => Navigator.of(
                        surfaceContext,
                      ).pop(_EditableCoverAction.focusLink),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    '清除封面',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap:
                      () => Navigator.of(
                        surfaceContext,
                      ).pop(_EditableCoverAction.clear),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) {
      return;
    }

    switch (action) {
      case _EditableCoverAction.gallery:
        await _pickAndSetEditingCoverPath(
          result,
          source: ImageSelectionSource.gallery,
        );
      case _EditableCoverAction.files:
        await _pickAndSetEditingCoverPath(
          result,
          source: ImageSelectionSource.files,
        );
      case _EditableCoverAction.focusLink:
        _editCoverFocusNode.requestFocus();
      case _EditableCoverAction.clear:
        _clearEditingCover();
    }
  }

  Future<void> _pickAndSetEditingCoverPath(
    BookDetailLoadResult result, {
    required ImageSelectionSource source,
  }) async {
    try {
      final nextPath = await _pickEditableCoverPath(result, source: source);
      if (!mounted || nextPath == null) {
        return;
      }
      _setEditingCoverPath(nextPath);
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('设置封面失败，请重试。');
    }
  }

  void _setEditingCoverPath(String? value) {
    final normalized = _normalizeOptionalEditText(value);
    _updateDetailPageState(() {
      _editingCoverPath = normalized;
    });
    final nextText = normalized ?? '';
    if (_editCoverController.text != nextText) {
      _editCoverController.text = nextText;
    }
  }

  void _clearEditingCover() {
    _setEditingCoverPath(null);
  }

  String? _resolveEditingCoverDraftValue(BookDetailLoadResult result) {
    final normalized = _normalizeOptionalEditText(_editCoverController.text);
    if (normalized == null) {
      return null;
    }
    final presentation = _resolvePresentedMetadata(result: result);
    final hasCustomCover =
        presentation.customCoverPath?.trim().isNotEmpty == true;
    if (!hasCustomCover &&
        normalized == (presentation.realCoverUrl ?? '').trim()) {
      return null;
    }
    return normalized;
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
        latestChapterTitle: result.detail.latestChapterTitle,
        totalChapterNum: result.detail.totalChapterNum,
        wordCount: result.detail.wordCount,
        category: result.detail.category,
        tags: result.detail.tags,
        updateTime: result.detail.updateTime,
      ),
    );
  }
}
