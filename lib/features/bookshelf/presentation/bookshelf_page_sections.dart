part of 'bookshelf_page.dart';

extension on _BookshelfPageState {
  Widget _buildAnnouncementAction() {
    final icon = IconButton(
      tooltip: '公告',
      onPressed: () {
        context.push('/announcements').then((_) {
          if (!mounted) {
            return;
          }
          unawaited(_prefetchLatestAnnouncement());
        });
      },
      icon: const Icon(Icons.notifications_none_outlined),
    );
    if (!_hasActiveAnnouncement) {
      return icon;
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        icon,
        Positioned(
          right: 10,
          top: 12,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBooksContentSliver(List<BookshelfBook> books) {
    if (_isLoading && _books.isEmpty) {
      return SliverToBoxAdapter(
        child: AppAnimatedSwitcher(
          child: const Card(
            key: ValueKey<String>('bookshelf_loading'),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('正在加载书架...')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_books.isEmpty && _loadErrorText != null) {
      return SliverToBoxAdapter(
        child: AppAnimatedSwitcher(
          child: KeyedSubtree(
            key: ValueKey<String>('bookshelf_error_$_loadErrorText'),
            child: _buildLoadErrorCard(message: _loadErrorText!),
          ),
        ),
      );
    }

    if (_books.isEmpty) {
      final emptyChild = AppAnimatedSwitcher(
        child: KeyedSubtree(
          key: const ValueKey<String>('bookshelf_empty'),
          child: _buildEmptyCard(),
        ),
      );
      if (AppAdaptiveMetrics.of(context).isMediumUpWindow) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: emptyChild),
        );
      }
      return SliverToBoxAdapter(child: emptyChild);
    }

    if (books.isEmpty) {
      return SliverToBoxAdapter(
        child: AppAnimatedSwitcher(
          child: KeyedSubtree(
            key: ValueKey<String>(
              'bookshelf_filter_empty_$_normalizedBookshelfSearchKeyword',
            ),
            child: _buildFilterEmptyCard(),
          ),
        ),
      );
    }

    if (_useGridView) {
      return _buildBookGridSliver(books);
    }

    if (AppLayout.isDesktopLike(
      context,
      platform: Theme.of(context).platform,
    )) {
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: _listCompactMode ? 8 : 10,
          crossAxisSpacing: 12,
          mainAxisExtent: _desktopListCardMainAxisExtent(),
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final book = books[index];
          return _buildModeSwitchAnimatedBookItem(
            book: book,
            index: index,
            totalCount: books.length,
            child: _buildReactiveBookCard(book),
          );
        }, childCount: books.length),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final book = books[index];
        return _buildModeSwitchAnimatedBookItem(
          book: book,
          index: index,
          totalCount: books.length,
          child: _buildReactiveBookCard(book),
        );
      }, childCount: books.length),
    );
  }

  double _desktopListCardMainAxisExtent() {
    final visibleDetailCount =
        <bool>[
          _listShowAuthor,
          _listShowLatestChapter,
          _listShowTaxonomyBadges,
          _listShowProgressBar,
          _listShowRecentReadTime,
        ].where((visible) => visible).length;
    if (_listCompactMode) {
      return visibleDetailCount >= 4 ? 138 : 124;
    }
    return visibleDetailCount >= 4 ? 176 : 160;
  }

  Widget _buildEmptyCard() {
    final metrics = AppAdaptiveMetrics.of(context);
    final card = BookshelfEmptyCard(
      onImportLocal: _showImportLocalBooksSheet,
      palette: _resolvedPalette(context),
    );
    if (!metrics.isMediumUpWindow) {
      return card;
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: card,
    );
  }

  Widget _buildFilterEmptyCard() {
    return BookshelfFilterEmptyCard(
      label: _activeFilterLabel(),
      searchKeyword: _normalizedBookshelfSearchKeyword,
      palette: _resolvedPalette(context),
    );
  }

  Widget _buildLoadErrorCard({required String message}) {
    return BookshelfLoadErrorCard(
      message: message,
      onRetry: () => unawaited(_loadBookshelf(force: true)),
      palette: _resolvedPalette(context),
    );
  }

  Widget _buildBookshelfSearchBar() {
    return BookshelfInlineSearchBar(
      palette: _resolvedPalette(context),
      controller: _bookshelfSearchController,
      focusNode: _bookshelfSearchFocusNode,
      onChanged: _updateBookshelfSearchKeyword,
      onClear: _clearBookshelfSearchKeyword,
      summaryText: _bookshelfSearchSummaryText,
    );
  }

  String get _bookshelfSearchSummaryText {
    if (_isSelectionMode) {
      return '已选 ${_selectedBookKeys.length} 本';
    }
    if (_hasBookshelfSearchKeyword) {
      return '结果 ${_filteredBooks.length} 本';
    }
    return '${_activeFilterLabel()} ${_filteredBooks.length} 本';
  }

  Widget _buildBookshelfSearchSliver({
    required double horizontal,
    required double topInset,
  }) {
    final height = _bookshelfSearchSectionHeight + topInset;
    final child = _buildBookshelfSearchSection(
      horizontal: horizontal,
      topInset: topInset,
    );
    if (_pinBookshelfSearchBar) {
      return SliverPersistentHeader(
        pinned: true,
        delegate: _BookshelfPinnedHeaderDelegate(extent: height, child: child),
      );
    }
    return SliverToBoxAdapter(child: child);
  }

  double get _bookshelfSearchSectionHeight {
    final quickFilterHeight = _shouldShowBookshelfQuickFilters ? 46.0 : 0.0;
    final searchHeight = _shouldShowExpandedBookshelfSearch ? 42.0 : 0.0;
    final gapHeight =
        _shouldShowBookshelfQuickFilters && _shouldShowExpandedBookshelfSearch
            ? 8.0
            : 0.0;
    return 12 + quickFilterHeight + gapHeight + searchHeight;
  }

  Widget _buildBookshelfSearchSection({
    required double horizontal,
    required double topInset,
  }) {
    final palette = _resolvedPalette(context);
    final backdrop = _resolvedBackdrop(context);
    final hasWallpaper =
        backdrop.wallpaperPath != null && backdrop.wallpaperPath!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: hasWallpaper ? Colors.transparent : palette.backgroundColor,
      ),
      padding: EdgeInsets.fromLTRB(horizontal, topInset, horizontal, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_shouldShowBookshelfQuickFilters) ...[
            _buildBookshelfQuickFilterBar(),
            if (_shouldShowExpandedBookshelfSearch) const SizedBox(height: 8),
          ],
          if (_shouldShowExpandedBookshelfSearch) _buildBookshelfSearchBar(),
        ],
      ),
    );
  }

  bool get _shouldShowBookshelfQuickFilters {
    return switch (_bookshelfQuickFilterContent) {
      _BookshelfSearchQuickFilterContent.none => false,
      _BookshelfSearchQuickFilterContent.tags =>
        _userTags.isNotEmpty || _books.any((book) => _tagsOfBook(book).isEmpty),
      _BookshelfSearchQuickFilterContent.categories =>
        _userCategories.isNotEmpty ||
            _books.any((book) => (_categoryOfBook(book) ?? '').isEmpty),
    };
  }

  Widget _buildBookshelfQuickFilterBar() {
    final chips = switch (_bookshelfQuickFilterContent) {
      _BookshelfSearchQuickFilterContent.tags => _buildTagQuickFilterChips(),
      _BookshelfSearchQuickFilterContent.categories =>
        _buildCategoryQuickFilterChips(),
      _BookshelfSearchQuickFilterContent.none =>
        const <BookshelfFilterChipData>[],
    };

    return BookshelfFilterBar(
      palette: _resolvedPalette(context),
      baseChips: chips,
      customChips: const <BookshelfFilterChipData>[],
      highlightFilterAction: false,
      filterActionMessage: '',
      onOpenFilterSheet: null,
      showActionButton: false,
    );
  }

  List<BookshelfFilterChipData> _buildTagQuickFilterChips() {
    final chips = <BookshelfFilterChipData>[
      BookshelfFilterChipData(
        label: '全部',
        selected: !_activeView.isTag,
        onTap:
            !_activeView.isTag
                ? null
                : () => _activateView(
                  const _BookshelfViewSelection.base(_BookshelfFilter.all),
                ),
      ),
    ];

    final hasUntagged = _books.any((book) => _tagsOfBook(book).isEmpty);
    if (hasUntagged) {
      chips.add(
        BookshelfFilterChipData(
          label: '未打标签',
          selected: _activeView.isTag && (_activeView.tag?.isEmpty ?? false),
          onTap: () => _activateView(const _BookshelfViewSelection.tag('')),
        ),
      );
    }

    for (final tag in _userTags) {
      chips.add(
        BookshelfFilterChipData(
          label: tag,
          selected: _activeView.isTag && _activeView.tag == tag,
          onTap: () => _activateView(_BookshelfViewSelection.tag(tag)),
        ),
      );
    }
    return chips;
  }

  List<BookshelfFilterChipData> _buildCategoryQuickFilterChips() {
    final chips = <BookshelfFilterChipData>[
      BookshelfFilterChipData(
        label: '全部',
        selected: !_activeView.isCategory,
        onTap:
            !_activeView.isCategory
                ? null
                : () => _activateView(
                  const _BookshelfViewSelection.base(_BookshelfFilter.all),
                ),
      ),
    ];

    final hasUncategorized = _books.any(
      (book) => (_categoryOfBook(book) ?? '').isEmpty,
    );
    if (hasUncategorized) {
      chips.add(
        BookshelfFilterChipData(
          label: '未分类',
          selected: _activeView.isUncategorized,
          onTap:
              () => _activateView(const _BookshelfViewSelection.category(null)),
        ),
      );
    }

    for (final category in _userCategories) {
      chips.add(
        BookshelfFilterChipData(
          label: category,
          selected: _activeView.isCategory && _activeView.category == category,
          onTap:
              () => _activateView(_BookshelfViewSelection.category(category)),
        ),
      );
    }
    return chips;
  }

  Widget _buildBookshelfViewTitle() {
    final title = _activeFilterLabel();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => unawaited(_showViewSwitcherSheet()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
