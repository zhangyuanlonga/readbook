part of 'bookshelf_page.dart';

extension on _BookshelfPageState {
  void _updateSelectionState(_BookshelfSelectionState nextState) {
    _selectionState = nextState;
  }

  void _clearSelectionState() {
    _updateSelectionState(const _BookshelfSelectionState());
  }

  void _setSelectionEnabled(bool enabled, {Set<String>? selectedKeys}) {
    _updateSelectionState(
      _selectionState.copyWith(
        enabled: enabled,
        selectedKeys: selectedKeys,
        clearSelectedKeys: !enabled && selectedKeys == null,
        clearActiveAction: !enabled,
      ),
    );
  }

  void _setSelectionAction(_BookshelfBatchAction? action) {
    _updateSelectionState(
      _selectionState.copyWith(
        activeAction: action,
        clearActiveAction: action == null,
      ),
    );
  }

  void _ensureFilterStillValid() {
    if ((_activeView.isTag || _activeView.isCategory) &&
        !_bookshelfMetadataReady) {
      return;
    }
    var shouldReset = false;
    if (_activeView.isTag) {
      final tag = _activeView.tag;
      shouldReset = tag == null || !_userTags.contains(tag);
    } else if (_activeView.isCategory && !_activeView.isUncategorized) {
      final category = _activeView.category;
      shouldReset = category == null || !_userCategories.contains(category);
    }
    if (shouldReset) {
      _activeView = const _BookshelfViewSelection.base(_BookshelfFilter.all);
      if (_isSelectionMode) {
        _clearSelectionState();
      }
    }
  }

  void _startSelectionMode() {
    if (!_flowCoordinator.canStartSelectionMode(
      isBatchDeleting: _isBatchDeleting,
      isBatchUpdatingCovers: _isBatchUpdatingCovers,
      hasFilteredBooks: _filteredBooks.isNotEmpty,
    )) {
      return;
    }
    _updateBookshelfState(() => _setSelectionEnabled(true, selectedKeys: const <String>{}));
  }

  void _toggleBookSelection(BookshelfBook book) {
    if (!_isSelectionMode || _isBatchDeleting || _isBatchUpdatingCovers) {
      return;
    }

    final key = _bookKey(book);
    _updateBookshelfState(() {
      final nextSelectedKeys = _flowCoordinator.toggleSelectedKeys(
        _selectedBookKeys,
        key,
      );
      _setSelectionEnabled(
        nextSelectedKeys.isNotEmpty,
        selectedKeys: nextSelectedKeys,
      );
    });
  }

  void _selectAllBooks() {
    final visibleBooks = _filteredBooks;
    if (visibleBooks.isEmpty || _isBatchDeleting || _isBatchUpdatingCovers) {
      return;
    }

    _updateBookshelfState(
      () => _setSelectionEnabled(
        true,
        selectedKeys: _flowCoordinator.selectAllVisibleKeys(
          visibleBooks.map(_bookKey),
        ),
      ),
    );
  }

  void _exitSelectionMode() {
    if (_isBatchDeleting || _isBatchUpdatingCovers) {
      return;
    }
    _updateBookshelfState(_clearSelectionState);
  }

  void _syncSelectionWithBooks() {
    if (!_isSelectionMode) {
      return;
    }

    final visibleBooks = _filteredBooks;
    final nextSelected = _flowCoordinator.syncSelectedKeys(
      selectedKeys: _selectedBookKeys,
      visibleKeys: visibleBooks.map(_bookKey),
    );

    final changed =
        nextSelected.length != _selectedBookKeys.length ||
        (visibleBooks.isEmpty && _isSelectionMode);

    if (!changed || !mounted) {
      return;
    }

    _updateBookshelfState(() {
      _setSelectionEnabled(nextSelected.isNotEmpty, selectedKeys: nextSelected);
    });
  }

  Future<void> _deleteSelectedBooks() async {
    if (_selectedBookKeys.isEmpty || _isBatchDeleting) {
      return;
    }

    final selected = _books
        .where((book) => _selectedBookKeys.contains(_bookKey(book)))
        .toList(growable: false);
    if (selected.isEmpty) {
      _exitSelectionMode();
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '删除书籍',
      content: '确定删除已选 ${selected.length} 本书吗？该操作不可撤销。',
      confirmText: '删除',
    );
    if (!mounted || confirmed != true) {
      return;
    }

    _removeBooksFromLocalState(
      selected,
      clearSelection: true,
      exitSelectionMode: true,
    );
    _updateBookshelfState(() {
      _setSelectionAction(_BookshelfBatchAction.delete);
    });

    var removedCount = 0;
    var failureCount = 0;
    for (final book in selected) {
      try {
        await _removeBook(book, reload: false, showFeedback: false);
        removedCount += 1;
      } catch (_) {
        failureCount += 1;
      }
    }

    if (failureCount > 0) {
      await _loadBookshelf(force: true);
    }

    if (!mounted) {
      return;
    }

    _updateBookshelfState(() {
      _clearSelectionState();
    });

    if (failureCount > 0) {
      _showMessage('已删除 $removedCount 本书，失败 $failureCount 本。');
      return;
    }
    _showMessage('已删除 $removedCount 本书。');
  }

  Future<void> _editSelectedBooksCover() async {
    if (_selectedBookKeys.isEmpty ||
        _isBatchDeleting ||
        _isBatchUpdatingCovers) {
      return;
    }

    final selected = _books
        .where((book) => _selectedBookKeys.contains(_bookKey(book)))
        .toList(growable: false);
    if (selected.isEmpty) {
      _exitSelectionMode();
      return;
    }

    try {
      final pickedImages = await _imageSelectionService.pickImages(
        confirmButtonText: '选择封面',
        allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp', 'gif'},
      );
      if (!mounted || pickedImages.isEmpty) {
        return;
      }
      if (pickedImages.length != 1 && pickedImages.length != selected.length) {
        _showMessage('请选择 1 张封面，或选择与书籍数量一致的封面。');
        return;
      }

      _updateBookshelfState(() {
        _setSelectionAction(_BookshelfBatchAction.updateCover);
      });

      var successCount = 0;
      var failureCount = 0;
      for (var index = 0; index < selected.length; index += 1) {
        final book = selected[index];
        final picked =
            pickedImages.length == 1 ? pickedImages.first : pickedImages[index];
        try {
          await _applyCustomCoverToBook(book: book, picked: picked);
          successCount += 1;
        } catch (_) {
          failureCount += 1;
        }
      }

      if (!mounted) {
        return;
      }
      _updateBookshelfState(() {
        _clearSelectionState();
      });
      if (failureCount > 0) {
        _showMessage('已更新 $successCount 本封面，失败 $failureCount 本。');
        return;
      }
      _showMessage('已更新 $successCount 本书的封面。');
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted && _isBatchUpdatingCovers) {
        _updateBookshelfState(() => _setSelectionAction(null));
      }
    }
  }

  Future<void> _applyCustomCoverToBook({
    required BookshelfBook book,
    required PickedImageData picked,
  }) async {
    final storedCoverUri = await _customCoverStorageService.persistForBook(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      picked: picked,
    );
    if (storedCoverUri == null) {
      throw StateError('custom cover persist failed');
    }
    final coverPath = storedCoverUri.toFilePath();

    if (book.sourceId == _BookshelfPageState._kLocalBookSourceId) {
      final existingLocalBook =
          _localBooksById[book.bookId.trim()] ??
          await _localBookRepository.getBookById(book.bookId.trim());
      if (existingLocalBook == null) {
        throw StateError('local book not found');
      }
      final updatedLocalBook = existingLocalBook.copyWith(
        coverPath: coverPath,
        clearCoverPath: false,
        updatedAt: DateTime.now(),
      );
      await _localBookRepository.upsertBook(updatedLocalBook);
      if (!mounted) {
        return;
      }
      _updateBookshelfState(() {
        _localBooksById = Map<String, LocalBook>.from(_localBooksById)
          ..[updatedLocalBook.id.trim()] = updatedLocalBook;
      });
      return;
    }

    final targetKey = BookMetadataOverride.remoteTargetKey(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
    );
    final existingOverride =
        _metadataOverridesByTargetKey[targetKey] ??
        await _bookMetadataOverrideRepository.getByRemoteBook(
          sourceId: book.sourceId,
          detailUrl: book.detailUrl,
        );
    final updatedOverride =
        existingOverride?.copyWith(
          coverPath: coverPath,
          clearCoverPath: false,
          updatedAt: DateTime.now(),
        ) ??
        BookMetadataOverride.forRemote(
          sourceId: book.sourceId,
          detailUrl: book.detailUrl,
          coverPath: coverPath,
        );
    await _bookMetadataOverrideRepository.upsert(updatedOverride);
    if (!mounted) {
      return;
    }
    _updateBookshelfState(() {
      _metadataOverridesByTargetKey = Map<String, BookMetadataOverride>.from(
        _metadataOverridesByTargetKey,
      )..[updatedOverride.targetKey] = updatedOverride;
    });
  }

  void _removeBooksFromLocalState(
    Iterable<BookshelfBook> books, {
    bool clearSelection = false,
    bool exitSelectionMode = false,
  }) {
    final removalList = books.toList(growable: false);
    if (removalList.isEmpty || !mounted) {
      return;
    }
    final removedKeys = removalList.map(_bookKey).toSet();
    final removedRecordKeys =
        removalList
            .map(
              (book) =>
                  '${book.bookId.trim()}::${book.sourceId.trim()}::${book.detailUrl.trim()}',
            )
            .toSet();
    final removedLocalIds =
        removalList
            .where(
              (book) =>
                  book.sourceId == _BookshelfPageState._kLocalBookSourceId,
            )
            .map((book) => book.bookId.trim())
            .where((id) => id.isNotEmpty)
            .toSet();

    _updateBookshelfState(() {
      _books = _books
          .where((book) => !removedKeys.contains(_bookKey(book)))
          .toList(growable: false);
      _progressByBookKey = Map<String, ReadingProgress>.fromEntries(
        _progressByBookKey.entries.where(
          (entry) => !removedKeys.contains(entry.key),
        ),
      );
      _latestCachedChapterByBookKey = Map<String, String>.fromEntries(
        _latestCachedChapterByBookKey.entries.where(
          (entry) => !removedKeys.contains(entry.key),
        ),
      );
      _cachedChapterCountByBookKey = Map<String, int>.fromEntries(
        _cachedChapterCountByBookKey.entries.where(
          (entry) => !removedKeys.contains(entry.key),
        ),
      );
      _bookTagsByKey = Map<String, List<String>>.fromEntries(
        _bookTagsByKey.entries.where(
          (entry) => !removedKeys.contains(entry.key),
        ),
      );
      _bookCategoriesByKey = Map<String, String>.fromEntries(
        _bookCategoriesByKey.entries.where(
          (entry) => !removedKeys.contains(entry.key),
        ),
      );
      _localBooksById = Map<String, LocalBook>.fromEntries(
        _localBooksById.entries.where(
          (entry) => !removedLocalIds.contains(entry.key),
        ),
      );
      final nextSelectedKeys = Set<String>.from(_selectedBookKeys);
      if (clearSelection) {
        nextSelectedKeys.clear();
      } else {
        nextSelectedKeys.removeWhere(removedKeys.contains);
      }
      _setSelectionEnabled(
        !(exitSelectionMode || nextSelectedKeys.isEmpty),
        selectedKeys: nextSelectedKeys,
      );
      if (_continueReadingRecord != null &&
          removedRecordKeys.contains(
            '${_continueReadingRecord!.bookId.trim()}::${_continueReadingRecord!.sourceId.trim()}::${_continueReadingRecord!.detailUrl.trim()}',
          )) {
        _continueReadingRecord = null;
      }
      _derivedBookshelfFingerprint = null;
    });
    _syncBookCardStateNotifiers(_books);
  }
}
