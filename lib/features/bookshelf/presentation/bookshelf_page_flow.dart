part of 'bookshelf_page.dart';

extension on _BookshelfPageState {
  void _handleMoreAction(_BookshelfMoreAction action) {
    switch (action) {
      case _BookshelfMoreAction.selectBooks:
        _startSelectionMode();
        break;
      case _BookshelfMoreAction.sortBooks:
        unawaited(_showSortModeSheet());
        break;
      case _BookshelfMoreAction.settings:
        unawaited(_showBookshelfSettingsSheet());
        break;
      case _BookshelfMoreAction.importLocal:
        unawaited(_showImportLocalBooksSheet());
        break;
    }
  }

  void _handleBookshelfSearchFocusChanged() {
    if (!mounted ||
        !_flowCoordinator.shouldCollapseSearch(
          hasFocus: _bookshelfSearchFocusNode.hasFocus,
          hasKeyword: _hasBookshelfSearchKeyword,
          alwaysShowSearchBar: _alwaysShowBookshelfSearchBar,
          isSearchExpanded: _isBookshelfSearchExpanded,
        )) {
      return;
    }
    _updateBookshelfState(() {
      _isBookshelfSearchExpanded = false;
    });
  }

  bool get _alwaysShowBookshelfSearchBar {
    return _useGridView ? _gridAlwaysShowSearchBar : _listAlwaysShowSearchBar;
  }

  bool get _pinBookshelfSearchBar {
    return _useGridView ? _gridPinSearchBar : _listPinSearchBar;
  }

  _BookshelfSearchQuickFilterContent get _bookshelfQuickFilterContent {
    return _useGridView ? _gridQuickFilterContent : _listQuickFilterContent;
  }

  bool get _shouldShowExpandedBookshelfSearch {
    return _alwaysShowBookshelfSearchBar ||
        _hasBookshelfSearchKeyword ||
        _isBookshelfSearchExpanded;
  }

  bool get _shouldShowBookshelfSearchSliver {
    return _alwaysShowBookshelfSearchBar ||
        _hasBookshelfSearchKeyword ||
        _isBookshelfSearchExpanded ||
        _shouldShowBookshelfQuickFilters;
  }

  void _closeBookshelfSearch({bool clearKeyword = false}) {
    _isBookshelfSearchExpanded = false;
    _bookshelfSearchFocusNode.unfocus();
    if (!clearKeyword) {
      return;
    }
    _bookshelfSearchController.clear();
    _bookshelfSearchKeyword = '';
  }

  void _updateBookshelfLayoutPreservingScroll(VoidCallback mutation) {
    final controller = _bookshelfScrollController;
    final previousOffset = controller.hasClients ? controller.offset : null;
    mutation();
    if (previousOffset == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) {
        return;
      }
      final position = controller.position;
      final target = previousOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() < 0.5) {
        return;
      }
      controller.jumpTo(target);
    });
  }

  void _updateBookshelfSearchKeyword(String value) {
    if (_bookshelfSearchKeyword == value) {
      return;
    }
    _updateBookshelfState(() {
      _bookshelfSearchKeyword = value;
      if (value.trim().isNotEmpty) {
        _isBookshelfSearchExpanded = true;
      }
    });
    _syncSelectionWithBooks();
  }

  void _clearBookshelfSearchKeyword() {
    if (_bookshelfSearchController.text.isEmpty &&
        _bookshelfSearchKeyword.isEmpty) {
      return;
    }
    _bookshelfSearchController.clear();
    _bookshelfSearchFocusNode.unfocus();
    _updateBookshelfState(() {
      _bookshelfSearchKeyword = '';
      if (!_alwaysShowBookshelfSearchBar) {
        _isBookshelfSearchExpanded = false;
      }
    });
    _syncSelectionWithBooks();
  }

  Future<void> _showSortModeSheet() async {
    if (_books.isEmpty || !mounted) {
      return;
    }

    final selected = await _showBookshelfBottomSheet<_BookshelfSortMode>(
      builder: (sheetContext) {
        final bottomInset = _bookshelfBottomSafeInset(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomInset),
          child: RadioGroup<_BookshelfSortMode>(
            groupValue: _sortMode,
            onChanged:
                (value) =>
                    Navigator.of(sheetContext, rootNavigator: true).pop(value),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Text(
                    '书籍排序',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final mode in _BookshelfSortMode.values)
                  RadioListTile<_BookshelfSortMode>(
                    value: mode,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(_sortModeLabel(mode)),
                    subtitle: Text(_sortModeDescription(mode)),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || selected == _sortMode || !mounted) {
      return;
    }

    _updateBookshelfState(() {
      _sortMode = selected;
    });
    try {
      await _bookshelfService.saveSortMode(_sortModeStorageValue(selected));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('书籍排序保存失败，请重试。');
    }
  }

  Future<void> _showBookshelfSettingsSheet() async {
    if (!mounted) {
      return;
    }

    var draftUseGridView = _useGridView;
    var draftAdaptive = _gridAdaptiveColumns;
    var draftColumns = _gridColumnCount;
    var draftCrossSpacing = _gridCrossSpacing;
    var draftMainSpacing = _gridMainSpacing;
    var draftGridVisualStyle = _gridVisualStyle;
    var draftShowTitle = _gridShowTitle;
    var draftGridTitleCenter = _gridTitleCenter;
    var draftGridTitleMaxLines = _gridTitleMaxLines;
    var draftGridCoverShadow = _gridCoverShadow;
    var draftShowAuthor = _gridShowAuthor;
    var draftShowLatestChapter = _gridShowLatestChapter;
    var draftShowProgressBar = _gridShowProgressBar;
    var draftGridProgressInfoMode = _gridProgressInfoMode;
    var draftShowSourceBadge = _gridShowSourceBadge;
    var draftShowTaxonomyBadges = _gridShowTaxonomyBadges;
    var draftGridAlwaysShowSearchBar = _gridAlwaysShowSearchBar;
    var draftGridPinSearchBar = _gridPinSearchBar;
    var draftGridQuickFilterContent = _gridQuickFilterContent;
    var draftListShowTitle = _listShowTitle;
    var draftListShowAuthor = _listShowAuthor;
    var draftListShowLatestChapter = _listShowLatestChapter;
    var draftListShowProgressBar = _listShowProgressBar;
    var draftListProgressInfoMode = _listProgressInfoMode;
    var draftListShowSourceBadge = _listShowSourceBadge;
    var draftListShowTaxonomyBadges = _listShowTaxonomyBadges;
    var draftListShowCover = _listShowCover;
    var draftListCompactMode = _listCompactMode;
    var draftListShowRecentReadTime = _listShowRecentReadTime;
    var draftListAlwaysShowSearchBar = _listAlwaysShowSearchBar;
    var draftListPinSearchBar = _listPinSearchBar;
    var draftListQuickFilterContent = _listQuickFilterContent;

    await _showBookshelfBottomSheet<void>(
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomInset = _bookshelfBottomSafeInset(sheetContext);
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final colorScheme = theme.colorScheme;
            Future<void> persistGridSettings() async {
              try {
                await _bookshelfService.saveGridAdaptiveColumns(draftAdaptive);
                await _bookshelfService.saveGridColumnCount(draftColumns);
                await _bookshelfService.saveGridCrossSpacing(draftCrossSpacing);
                await _bookshelfService.saveGridMainSpacing(draftMainSpacing);
                await _bookshelfService.saveGridVisualStyle(
                  _gridVisualStyleStorageValue(draftGridVisualStyle),
                );
                await _bookshelfService.saveGridShowTitle(draftShowTitle);
                await _bookshelfService.saveGridTitleCenter(
                  draftGridTitleCenter,
                );
                await _bookshelfService.saveGridTitleMaxLines(
                  draftGridTitleMaxLines,
                );
                await _bookshelfService.saveGridCoverShadow(
                  draftGridCoverShadow,
                );
                await _bookshelfService.saveGridShowAuthor(draftShowAuthor);
                await _bookshelfService.saveGridShowLatestChapter(
                  draftShowLatestChapter,
                );
                await _bookshelfService.saveGridShowProgressBar(
                  draftShowProgressBar,
                );
                await _bookshelfService.saveGridProgressInfoMode(
                  _progressInfoModeStorageValue(draftGridProgressInfoMode),
                );
                await _bookshelfService.saveGridShowSourceBadge(
                  draftShowSourceBadge,
                );
                await _bookshelfService.saveGridShowTaxonomyBadges(
                  draftShowTaxonomyBadges,
                );
                await _bookshelfService.saveGridAlwaysShowSearchBar(
                  draftGridAlwaysShowSearchBar,
                );
                await _bookshelfService.saveGridPinSearchBar(
                  draftGridPinSearchBar,
                );
                await _bookshelfService.saveGridQuickFilterContent(
                  _searchQuickFilterContentStorageValue(
                    draftGridQuickFilterContent,
                  ),
                );
              } catch (_) {
                if (!mounted) {
                  return;
                }
                _showMessage('书架设置保存失败，请重试。');
              }
            }

            Future<void> persistListSettings() async {
              try {
                await _bookshelfService.saveListShowTitle(draftListShowTitle);
                await _bookshelfService.saveListShowAuthor(draftListShowAuthor);
                await _bookshelfService.saveListShowLatestChapter(
                  draftListShowLatestChapter,
                );
                await _bookshelfService.saveListShowProgressBar(
                  draftListShowProgressBar,
                );
                await _bookshelfService.saveListProgressInfoMode(
                  _progressInfoModeStorageValue(draftListProgressInfoMode),
                );
                await _bookshelfService.saveListShowSourceBadge(
                  draftListShowSourceBadge,
                );
                await _bookshelfService.saveListShowTaxonomyBadges(
                  draftListShowTaxonomyBadges,
                );
                await _bookshelfService.saveListShowCover(draftListShowCover);
                await _bookshelfService.saveListCompactMode(
                  draftListCompactMode,
                );
                await _bookshelfService.saveListShowRecentReadTime(
                  draftListShowRecentReadTime,
                );
                await _bookshelfService.saveListAlwaysShowSearchBar(
                  draftListAlwaysShowSearchBar,
                );
                await _bookshelfService.saveListPinSearchBar(
                  draftListPinSearchBar,
                );
                await _bookshelfService.saveListQuickFilterContent(
                  _searchQuickFilterContentStorageValue(
                    draftListQuickFilterContent,
                  ),
                );
              } catch (_) {
                if (!mounted) {
                  return;
                }
                _showMessage('书架设置保存失败，请重试。');
              }
            }

            Future<void> setBookshelfViewMode(bool useGridView) async {
              setSheetState(() {
                draftUseGridView = useGridView;
              });
              await _setBookshelfViewMode(useGridView);
            }

            String gridDensityValue() {
              if (draftCrossSpacing <= 6 && draftMainSpacing <= 8) {
                return 'compact';
              }
              if (draftCrossSpacing >= 12 && draftMainSpacing >= 16) {
                return 'relaxed';
              }
              if ((draftCrossSpacing - BookshelfService.defaultGridCrossSpacing)
                          .abs() <=
                      1 &&
                  (draftMainSpacing - BookshelfService.defaultGridMainSpacing)
                          .abs() <=
                      1) {
                return 'standard';
              }
              return 'custom';
            }

            String gridDensityLabel(String value) {
              return switch (value) {
                'compact' => '紧凑',
                'relaxed' => '宽松',
                'custom' => '自定义',
                _ => '标准',
              };
            }

            void applyGridDensity(String value) {
              final (nextCrossSpacing, nextMainSpacing) = switch (value) {
                'compact' => (4.0, 6.0),
                'relaxed' => (14.0, 18.0),
                _ => (
                  BookshelfService.defaultGridCrossSpacing,
                  BookshelfService.defaultGridMainSpacing,
                ),
              };
              setSheetState(() {
                draftCrossSpacing = nextCrossSpacing;
                draftMainSpacing = nextMainSpacing;
              });
              _updateBookshelfState(() {
                _gridCrossSpacing = nextCrossSpacing;
                _gridMainSpacing = nextMainSpacing;
              });
              unawaited(persistGridSettings());
            }

            Future<void> resetGridSettings() async {
              setSheetState(() {
                draftAdaptive = BookshelfService.defaultGridAdaptiveColumns;
                draftColumns = BookshelfService.defaultGridColumnCount;
                draftCrossSpacing = BookshelfService.defaultGridCrossSpacing;
                draftMainSpacing = BookshelfService.defaultGridMainSpacing;
                draftGridVisualStyle = _gridVisualStyleFromStorageValue(
                  BookshelfService.defaultGridVisualStyle,
                );
                draftShowTitle = BookshelfService.defaultGridShowTitle;
                draftGridTitleCenter = BookshelfService.defaultGridTitleCenter;
                draftGridTitleMaxLines =
                    BookshelfService.defaultGridTitleMaxLines;
                draftGridCoverShadow = BookshelfService.defaultGridCoverShadow;
                draftShowAuthor = BookshelfService.defaultGridShowAuthor;
                draftShowLatestChapter =
                    BookshelfService.defaultGridShowLatestChapter;
                draftShowProgressBar =
                    BookshelfService.defaultGridShowProgressBar;
                draftGridProgressInfoMode = _progressInfoModeFromStorageValue(
                  BookshelfService.defaultGridProgressInfoMode,
                );
                draftShowSourceBadge =
                    BookshelfService.defaultGridShowSourceBadge;
                draftShowTaxonomyBadges =
                    BookshelfService.defaultGridShowTaxonomyBadges;
                draftGridAlwaysShowSearchBar =
                    BookshelfService.defaultGridAlwaysShowSearchBar;
                draftGridPinSearchBar =
                    BookshelfService.defaultGridPinSearchBar;
                draftGridQuickFilterContent =
                    _searchQuickFilterContentFromStorageValue(
                      BookshelfService.defaultGridQuickFilterContent,
                    );
              });
              _updateBookshelfLayoutPreservingScroll(() {
                _updateBookshelfState(() {
                  _gridAdaptiveColumns = draftAdaptive;
                  _gridColumnCount = draftColumns;
                  _gridCrossSpacing = draftCrossSpacing;
                  _gridMainSpacing = draftMainSpacing;
                  _gridVisualStyle = draftGridVisualStyle;
                  _gridShowTitle = draftShowTitle;
                  _gridTitleCenter = draftGridTitleCenter;
                  _gridTitleMaxLines = draftGridTitleMaxLines;
                  _gridCoverShadow = draftGridCoverShadow;
                  _gridShowAuthor = draftShowAuthor;
                  _gridShowLatestChapter = draftShowLatestChapter;
                  _gridShowProgressBar = draftShowProgressBar;
                  _gridProgressInfoMode = draftGridProgressInfoMode;
                  _gridShowSourceBadge = draftShowSourceBadge;
                  _gridShowTaxonomyBadges = draftShowTaxonomyBadges;
                  _gridAlwaysShowSearchBar = draftGridAlwaysShowSearchBar;
                  _gridPinSearchBar = draftGridPinSearchBar;
                  _gridQuickFilterContent = draftGridQuickFilterContent;
                });
              });
              await persistGridSettings();
            }

            Future<void> resetListSettings() async {
              setSheetState(() {
                draftListShowTitle = BookshelfService.defaultListShowTitle;
                draftListShowAuthor = BookshelfService.defaultListShowAuthor;
                draftListShowLatestChapter =
                    BookshelfService.defaultListShowLatestChapter;
                draftListShowProgressBar =
                    BookshelfService.defaultListShowProgressBar;
                draftListProgressInfoMode = _progressInfoModeFromStorageValue(
                  BookshelfService.defaultListProgressInfoMode,
                );
                draftListShowSourceBadge =
                    BookshelfService.defaultListShowSourceBadge;
                draftListShowTaxonomyBadges =
                    BookshelfService.defaultListShowTaxonomyBadges;
                draftListShowCover = BookshelfService.defaultListShowCover;
                draftListCompactMode = BookshelfService.defaultListCompactMode;
                draftListShowRecentReadTime =
                    BookshelfService.defaultListShowRecentReadTime;
                draftListAlwaysShowSearchBar =
                    BookshelfService.defaultListAlwaysShowSearchBar;
                draftListPinSearchBar =
                    BookshelfService.defaultListPinSearchBar;
                draftListQuickFilterContent =
                    _searchQuickFilterContentFromStorageValue(
                      BookshelfService.defaultListQuickFilterContent,
                    );
              });
              _updateBookshelfLayoutPreservingScroll(() {
                _updateBookshelfState(() {
                  _listShowTitle = draftListShowTitle;
                  _listShowAuthor = draftListShowAuthor;
                  _listShowLatestChapter = draftListShowLatestChapter;
                  _listShowProgressBar = draftListShowProgressBar;
                  _listProgressInfoMode = draftListProgressInfoMode;
                  _listShowSourceBadge = draftListShowSourceBadge;
                  _listShowTaxonomyBadges = draftListShowTaxonomyBadges;
                  _listShowCover = draftListShowCover;
                  _listCompactMode = draftListCompactMode;
                  _listShowRecentReadTime = draftListShowRecentReadTime;
                  _listAlwaysShowSearchBar = draftListAlwaysShowSearchBar;
                  _listPinSearchBar = draftListPinSearchBar;
                  _listQuickFilterContent = draftListQuickFilterContent;
                });
              });
              await persistListSettings();
            }

            Widget buildGroupHeader(String title) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: colorScheme.onSurface,
                  ),
                ),
              );
            }

            Widget buildCompactSwitchTile({
              required bool value,
              required String title,
              String? subtitle,
              required ValueChanged<bool>? onChanged,
            }) {
              return BookshelfSettingsSwitchTile(
                value: value,
                title: title,
                subtitle: subtitle,
                onChanged: onChanged,
              );
            }

            Widget buildDropdownSettingRow<T>({
              required String title,
              String? subtitle,
              required T value,
              required List<T> values,
              required String Function(T value) labelBuilder,
              required ValueChanged<T?>? onChanged,
              double controlWidth = 132,
            }) {
              final enabled = onChanged != null;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color:
                                    enabled
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: controlWidth,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<T>(
                              value: value,
                              isDense: true,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(14),
                              alignment: AlignmentDirectional.centerEnd,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              onChanged: onChanged,
                              items: [
                                for (final option in values)
                                  DropdownMenuItem<T>(
                                    value: option,
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(
                                      labelBuilder(option),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget buildResetDefaultsButton({required VoidCallback onPressed}) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
                child: OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('恢复当前视图默认设置'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    alignment: Alignment.centerLeft,
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              );
            }

            Widget buildSearchSettings({
              required bool alwaysShowSearchBar,
              required bool pinSearchBar,
              required _BookshelfSearchQuickFilterContent quickFilterContent,
              required ValueChanged<bool> onAlwaysShowChanged,
              required ValueChanged<bool> onPinChanged,
              required ValueChanged<_BookshelfSearchQuickFilterContent>
              onQuickFilterChanged,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildGroupHeader('搜索设置'),
                  buildCompactSwitchTile(
                    value: alwaysShowSearchBar,
                    title: '显示搜索框',
                    subtitle:
                        alwaysShowSearchBar
                            ? '关闭后收起搜索框，需要从顶部入口展开。'
                            : '开启后直接显示搜索框。',
                    onChanged: onAlwaysShowChanged,
                  ),
                  buildCompactSwitchTile(
                    value: pinSearchBar,
                    title: '搜索框吸顶',
                    subtitle: '滚动时将快捷筛选和搜索入口固定在顶部。',
                    onChanged: onPinChanged,
                  ),
                  buildDropdownSettingRow<_BookshelfSearchQuickFilterContent>(
                    title: '快捷筛选内容',
                    value: quickFilterContent,
                    values: _BookshelfSearchQuickFilterContent.values,
                    labelBuilder: _searchQuickFilterContentLabel,
                    onChanged:
                        (value) =>
                            value == null ? null : onQuickFilterChanged(value),
                  ),
                ],
              );
            }

            Widget buildGridSettings() {
              return ListView(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                children: [
                  buildCompactSwitchTile(
                    value: draftAdaptive,
                    title: '自适应列数',
                    subtitle: '根据当前宽度自动决定 2-6 列。',
                    onChanged: (value) {
                      setSheetState(() {
                        draftAdaptive = value;
                      });
                      _updateBookshelfState(() {
                        _gridAdaptiveColumns = value;
                      });
                      unawaited(persistGridSettings());
                    },
                  ),
                  BookshelfStepperSettingRow(
                    title: '网格列数',
                    subtitle: draftAdaptive ? '已启用自适应列数，固定列数暂不可用' : '手动指定固定列数。',
                    valueLabel: '$draftColumns',
                    enabled: !draftAdaptive,
                    onDecrease:
                        draftAdaptive || draftColumns <= 2
                            ? null
                            : () {
                              final next = draftColumns - 1;
                              setSheetState(() {
                                draftColumns = next;
                              });
                              _updateBookshelfState(() {
                                _gridColumnCount = next;
                              });
                              unawaited(persistGridSettings());
                            },
                    onIncrease:
                        draftAdaptive || draftColumns >= 6
                            ? null
                            : () {
                              final next = draftColumns + 1;
                              setSheetState(() {
                                draftColumns = next;
                              });
                              _updateBookshelfState(() {
                                _gridColumnCount = next;
                              });
                              unawaited(persistGridSettings());
                            },
                  ),
                  buildDropdownSettingRow<String>(
                    title: '网格密度',
                    value: gridDensityValue(),
                    values: <String>[
                      'compact',
                      'standard',
                      'relaxed',
                      if (gridDensityValue() == 'custom') 'custom',
                    ],
                    labelBuilder: gridDensityLabel,
                    onChanged: (value) {
                      if (value == null || value == 'custom') {
                        return;
                      }
                      applyGridDensity(value);
                    },
                  ),
                  buildDropdownSettingRow<_BookshelfGridVisualStyle>(
                    title: '网格样式',
                    value: draftGridVisualStyle,
                    values: _BookshelfGridVisualStyle.values,
                    labelBuilder: _gridVisualStyleLabel,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setSheetState(() {
                        draftGridVisualStyle = value;
                      });
                      _updateBookshelfLayoutPreservingScroll(() {
                        _updateBookshelfState(() {
                          _gridVisualStyle = value;
                        });
                      });
                      unawaited(persistGridSettings());
                    },
                  ),
                  buildGroupHeader('文字信息'),
                  BookshelfStepperSettingRow(
                    title: '书名行数',
                    subtitle: '控制网格模式下书名最多显示几行。',
                    valueLabel: '$draftGridTitleMaxLines',
                    enabled: draftShowTitle,
                    onDecrease:
                        !draftShowTitle || draftGridTitleMaxLines <= 1
                            ? null
                            : () {
                              final next = draftGridTitleMaxLines - 1;
                              setSheetState(() {
                                draftGridTitleMaxLines = next;
                              });
                              _updateBookshelfLayoutPreservingScroll(() {
                                _updateBookshelfState(() {
                                  _gridTitleMaxLines = next;
                                });
                              });
                              unawaited(persistGridSettings());
                            },
                    onIncrease:
                        !draftShowTitle || draftGridTitleMaxLines >= 3
                            ? null
                            : () {
                              final next = draftGridTitleMaxLines + 1;
                              setSheetState(() {
                                draftGridTitleMaxLines = next;
                              });
                              _updateBookshelfLayoutPreservingScroll(() {
                                _updateBookshelfState(() {
                                  _gridTitleMaxLines = next;
                                });
                              });
                              unawaited(persistGridSettings());
                            },
                  ),
                  buildCompactSwitchTile(
                    value: draftGridTitleCenter,
                    title: '书名居中',
                    subtitle: '借鉴 MD3 的标题居中样式，只影响网格书名。',
                    onChanged:
                        !draftShowTitle
                            ? null
                            : (value) {
                              setSheetState(() {
                                draftGridTitleCenter = value;
                              });
                              _updateBookshelfState(() {
                                _gridTitleCenter = value;
                              });
                              unawaited(persistGridSettings());
                            },
                  ),
                  buildCompactSwitchTile(
                    value: draftShowTitle,
                    title: '显示书籍名称',
                    onChanged: (value) {
                      setSheetState(() {
                        draftShowTitle = value;
                      });
                      _updateBookshelfState(() {
                        _gridShowTitle = value;
                      });
                      unawaited(persistGridSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftShowAuthor,
                    title: '显示作者名称',
                    onChanged: (value) {
                      setSheetState(() {
                        draftShowAuthor = value;
                      });
                      _updateBookshelfState(() {
                        _gridShowAuthor = value;
                      });
                      unawaited(persistGridSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftShowLatestChapter,
                    title: '显示最新章节',
                    onChanged: (value) {
                      setSheetState(() {
                        draftShowLatestChapter = value;
                      });
                      _updateBookshelfState(() {
                        _gridShowLatestChapter = value;
                      });
                      unawaited(persistGridSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftShowSourceBadge,
                    title: '显示来源标识',
                    subtitle: '在封面右上角显示在线/本地标识。',
                    onChanged: (value) {
                      setSheetState(() {
                        draftShowSourceBadge = value;
                      });
                      _updateBookshelfState(() {
                        _gridShowSourceBadge = value;
                      });
                      unawaited(persistGridSettings());
                    },
                  ),
                  buildSearchSettings(
                    alwaysShowSearchBar: draftGridAlwaysShowSearchBar,
                    pinSearchBar: draftGridPinSearchBar,
                    quickFilterContent: draftGridQuickFilterContent,
                    onAlwaysShowChanged: (value) {
                      setSheetState(() {
                        draftGridAlwaysShowSearchBar = value;
                      });
                      _updateBookshelfLayoutPreservingScroll(() {
                        _updateBookshelfState(() {
                          _gridAlwaysShowSearchBar = value;
                          if (!value && _useGridView) {
                            _closeBookshelfSearch(clearKeyword: true);
                          }
                        });
                      });
                      if (!value && _useGridView) {
                        _syncSelectionWithBooks();
                      }
                      unawaited(persistGridSettings());
                    },
                    onPinChanged: (value) {
                      setSheetState(() {
                        draftGridPinSearchBar = value;
                      });
                      _updateBookshelfLayoutPreservingScroll(() {
                        _updateBookshelfState(() {
                          _gridPinSearchBar = value;
                        });
                      });
                      unawaited(persistGridSettings());
                    },
                    onQuickFilterChanged: (value) {
                      setSheetState(() {
                        draftGridQuickFilterContent = value;
                      });
                      _updateBookshelfLayoutPreservingScroll(() {
                        _updateBookshelfState(() {
                          _gridQuickFilterContent = value;
                        });
                      });
                      unawaited(persistGridSettings());
                    },
                  ),
                  buildGroupHeader('封面设置'),
                  buildCompactSwitchTile(
                    value: draftGridCoverShadow,
                    title: '封面阴影',
                    subtitle: '开启后网格封面会保留轻微投影。',
                    onChanged: (value) {
                      setSheetState(() {
                        draftGridCoverShadow = value;
                      });
                      _updateBookshelfState(() {
                        _gridCoverShadow = value;
                      });
                      unawaited(persistGridSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftShowProgressBar,
                    title: '显示阅读信息',
                    onChanged: (value) {
                      setSheetState(() {
                        draftShowProgressBar = value;
                      });
                      _updateBookshelfState(() {
                        _gridShowProgressBar = value;
                      });
                      unawaited(persistGridSettings());
                    },
                  ),
                  buildDropdownSettingRow<_BookshelfProgressInfoMode>(
                    title: '阅读信息',
                    subtitle: '控制书籍卡片显示进度条或未读章节数。',
                    value: draftGridProgressInfoMode,
                    values: _BookshelfProgressInfoMode.values,
                    labelBuilder: _progressInfoModeLabel,
                    onChanged:
                        !draftShowProgressBar
                            ? null
                            : (value) {
                              if (value == null) {
                                return;
                              }
                              setSheetState(() {
                                draftGridProgressInfoMode = value;
                              });
                              _updateBookshelfLayoutPreservingScroll(() {
                                _updateBookshelfState(() {
                                  _gridProgressInfoMode = value;
                                });
                              });
                              unawaited(persistGridSettings());
                            },
                  ),
                  buildResetDefaultsButton(
                    onPressed: () => unawaited(resetGridSettings()),
                  ),
                ],
              );
            }

            Widget buildListSettings() {
              return ListView(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                children: [
                  buildCompactSwitchTile(
                    value: draftListCompactMode,
                    title: '紧凑列表',
                    subtitle: '缩小封面和行距，提高列表信息密度。',
                    onChanged: (value) {
                      setSheetState(() {
                        draftListCompactMode = value;
                      });
                      _updateBookshelfState(() {
                        _listCompactMode = value;
                      });
                      unawaited(persistListSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftListShowCover,
                    title: '显示封面图',
                    subtitle: '关闭后列表只显示书名、作者和其他文字信息。',
                    onChanged: (value) {
                      setSheetState(() {
                        draftListShowCover = value;
                      });
                      _updateBookshelfLayoutPreservingScroll(() {
                        _updateBookshelfState(() {
                          _listShowCover = value;
                        });
                      });
                      unawaited(persistListSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftListShowTitle,
                    title: '显示书籍名称',
                    onChanged: (value) {
                      setSheetState(() {
                        draftListShowTitle = value;
                      });
                      _updateBookshelfState(() {
                        _listShowTitle = value;
                      });
                      unawaited(persistListSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftListShowAuthor,
                    title: '显示作者名称',
                    onChanged: (value) {
                      setSheetState(() {
                        draftListShowAuthor = value;
                      });
                      _updateBookshelfState(() {
                        _listShowAuthor = value;
                      });
                      unawaited(persistListSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftListShowLatestChapter,
                    title: '显示最新章节',
                    onChanged: (value) {
                      setSheetState(() {
                        draftListShowLatestChapter = value;
                      });
                      _updateBookshelfState(() {
                        _listShowLatestChapter = value;
                      });
                      unawaited(persistListSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftListShowSourceBadge,
                    title: '显示来源标识',
                    subtitle:
                        draftListShowCover
                            ? '在封面右上角显示在线/本地标识。'
                            : '封面图隐藏时不会显示来源标识。',
                    onChanged:
                        draftListShowCover
                            ? (value) {
                              setSheetState(() {
                                draftListShowSourceBadge = value;
                              });
                              _updateBookshelfState(() {
                                _listShowSourceBadge = value;
                              });
                              unawaited(persistListSettings());
                            }
                            : null,
                  ),
                  buildCompactSwitchTile(
                    value: draftListShowTaxonomyBadges,
                    title: '显示分类和标签',
                    subtitle: '在列表书籍信息中显示彩色分类和标签。',
                    onChanged: (value) {
                      setSheetState(() {
                        draftListShowTaxonomyBadges = value;
                      });
                      _updateBookshelfLayoutPreservingScroll(() {
                        _updateBookshelfState(() {
                          _listShowTaxonomyBadges = value;
                        });
                      });
                      unawaited(persistListSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftListShowRecentReadTime,
                    title: '显示最近阅读时间',
                    subtitle: '有阅读记录的书籍会在列表中显示最近阅读时间。',
                    onChanged: (value) {
                      setSheetState(() {
                        draftListShowRecentReadTime = value;
                      });
                      _updateBookshelfState(() {
                        _listShowRecentReadTime = value;
                      });
                      unawaited(persistListSettings());
                    },
                  ),
                  buildSearchSettings(
                    alwaysShowSearchBar: draftListAlwaysShowSearchBar,
                    pinSearchBar: draftListPinSearchBar,
                    quickFilterContent: draftListQuickFilterContent,
                    onAlwaysShowChanged: (value) {
                      setSheetState(() {
                        draftListAlwaysShowSearchBar = value;
                      });
                      _updateBookshelfLayoutPreservingScroll(() {
                        _updateBookshelfState(() {
                          _listAlwaysShowSearchBar = value;
                          if (!value && !_useGridView) {
                            _closeBookshelfSearch(clearKeyword: true);
                          }
                        });
                      });
                      if (!value && !_useGridView) {
                        _syncSelectionWithBooks();
                      }
                      unawaited(persistListSettings());
                    },
                    onPinChanged: (value) {
                      setSheetState(() {
                        draftListPinSearchBar = value;
                      });
                      _updateBookshelfLayoutPreservingScroll(() {
                        _updateBookshelfState(() {
                          _listPinSearchBar = value;
                        });
                      });
                      unawaited(persistListSettings());
                    },
                    onQuickFilterChanged: (value) {
                      setSheetState(() {
                        draftListQuickFilterContent = value;
                      });
                      _updateBookshelfLayoutPreservingScroll(() {
                        _updateBookshelfState(() {
                          _listQuickFilterContent = value;
                        });
                      });
                      unawaited(persistListSettings());
                    },
                  ),
                  buildCompactSwitchTile(
                    value: draftListShowProgressBar,
                    title: '显示阅读信息',
                    onChanged: (value) {
                      setSheetState(() {
                        draftListShowProgressBar = value;
                      });
                      _updateBookshelfState(() {
                        _listShowProgressBar = value;
                      });
                      unawaited(persistListSettings());
                    },
                  ),
                  buildDropdownSettingRow<_BookshelfProgressInfoMode>(
                    title: '阅读信息',
                    subtitle: '控制书籍卡片显示进度条或未读章节数。',
                    value: draftListProgressInfoMode,
                    values: _BookshelfProgressInfoMode.values,
                    labelBuilder: _progressInfoModeLabel,
                    onChanged:
                        !draftListShowProgressBar
                            ? null
                            : (value) {
                              if (value == null) {
                                return;
                              }
                              setSheetState(() {
                                draftListProgressInfoMode = value;
                              });
                              _updateBookshelfLayoutPreservingScroll(() {
                                _updateBookshelfState(() {
                                  _listProgressInfoMode = value;
                                });
                              });
                              unawaited(persistListSettings());
                            },
                  ),
                  buildResetDefaultsButton(
                    onPressed: () => unawaited(resetListSettings()),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomInset),
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 3, 4, 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '书架设置',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _resolvedPalette(sheetContext).surfaceColor,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: _resolvedPalette(
                            sheetContext,
                          ).cardBorderColor.withValues(alpha: 0.42),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _BookshelfSettingsModeButton(
                              label: '列表',
                              icon: Icons.view_list_rounded,
                              selected: !draftUseGridView,
                              onTap:
                                  () => unawaited(setBookshelfViewMode(false)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _BookshelfSettingsModeButton(
                              label: '网格',
                              icon: Icons.grid_view_rounded,
                              selected: draftUseGridView,
                              onTap:
                                  () => unawaited(setBookshelfViewMode(true)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _resolvedPalette(sheetContext).surfaceColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _resolvedPalette(
                              sheetContext,
                            ).cardBorderColor.withValues(alpha: 0.42),
                          ),
                        ),
                        child:
                            draftUseGridView
                                ? buildGridSettings()
                                : buildListSettings(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showImportLocalBooksSheet() async {
    if (_isBatchDeleting || !mounted) {
      return;
    }
    await _showBookshelfBottomSheet<void>(
      isScrollControlled: true,
      useAdaptiveSurface: false,
      builder: (sheetContext) {
        return _BookshelfImportLocalBooksSheet(
          flowCoordinator: _flowCoordinator,
          importService: _localBookImportService,
          onReload: () => _loadBookshelf(force: true),
          onOpenReader: (book, localBook) async {
            final plan = await _readerOpenService.resolve(
              book: book,
              openRequestedAtMs: DateTime.now().millisecondsSinceEpoch,
              localBookHint: localBook,
            );
            if (!mounted) {
              return;
            }
            switch (plan.action) {
              case BookshelfReaderOpenAction.openReader:
                final route = plan.readerRoute;
                if (route == null) {
                  return;
                }
                context.push(route);
              case BookshelfReaderOpenAction.openDetail:
                _openBookDetail(book);
            }
          },
          onShowMessage: _showMessage,
          onClose: () => Navigator.of(sheetContext).pop(),
        );
      },
    );
  }

  Future<void> _consumePendingExternalImportPayloads() async {
    if (_isConsumingExternalImportPayloads || !mounted) {
      return;
    }

    _isConsumingExternalImportPayloads = true;
    try {
      await _externalImportCoordinator.consumePendingPayloads(
        _importFromExternalPayload,
      );
    } finally {
      _isConsumingExternalImportPayloads = false;
    }
  }

  Future<void> _importFromExternalPayload(
    IncomingExternalImportPayload payload,
  ) async {
    if (!mounted) {
      return;
    }
    await _showBookshelfBottomSheet<void>(
      isScrollControlled: true,
      useAdaptiveSurface: false,
      builder: (sheetContext) {
        return _BookshelfExternalImportSheet(
          payload: payload,
          externalImportCoordinator: _externalImportCoordinator,
          importService: _localBookImportService,
          onReload: () => _loadBookshelf(force: true),
          onShowMessage: _showMessage,
        );
      },
    );
  }

  Future<T?> _showBookshelfBottomSheet<T>({
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    bool useAdaptiveSurface = true,
    double? maxWidth,
  }) {
    if (!useAdaptiveSurface) {
      return showAdaptiveRawSurface<T>(
        context: context,
        useRootNavigator: true,
        showDragHandle: false,
        mobileBackgroundColor: Colors.transparent,
        builder: builder,
      );
    }
    return showAdaptiveActionSurface<T>(
      context: context,
      useRootNavigator: true,
      maxWidth: maxWidth ?? 720,
      maxHeightFactor: isScrollControlled ? 0.88 : 0.72,
      padding: EdgeInsets.zero,
      builder: builder,
    );
  }

  void _dismissBookshelfBottomSheet<T>(BuildContext context, [T? result]) {
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  double _bookshelfBottomSafeInset(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context).bottom;
    return math.max(viewPadding, gestureInsets);
  }

  Future<void> _showViewSwitcherSheet() async {
    if (_isBatchDeleting || !mounted) {
      return;
    }

    final baseFilterBookCount = <_BookshelfFilter, int>{
      _BookshelfFilter.all: _books.length,
      _BookshelfFilter.local:
          _books
              .where(
                (book) =>
                    _bookMatchesStaticFilter(book, _BookshelfFilter.local),
              )
              .length,
      _BookshelfFilter.novel:
          _books
              .where(
                (book) =>
                    _bookMatchesStaticFilter(book, _BookshelfFilter.novel),
              )
              .length,
      _BookshelfFilter.manga:
          _books
              .where(
                (book) =>
                    _bookMatchesStaticFilter(book, _BookshelfFilter.manga),
              )
              .length,
    };
    final tagBookCount = _buildTagBookCount();
    final categoryBookCount = _buildCategoryBookCount();
    final customTags = _userTags;
    final customCategories = _userCategories;
    final uncategorizedCount =
        _books.where((book) => (_categoryOfBook(book) ?? '').isEmpty).length;

    final selected = await _showBookshelfBottomSheet<String>(
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
        final bottomInset = _bookshelfBottomSafeInset(sheetContext);
        var searchKeyword = '';
        var expandCategories = false;
        var expandTags = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final colorScheme = Theme.of(sheetContext).colorScheme;
            final textTheme = Theme.of(sheetContext).textTheme;
            final palette = _resolvedPalette(sheetContext);
            final compactTheme = Theme.of(
              sheetContext,
            ).copyWith(visualDensity: VisualDensity.compact);

            Widget buildSectionHeader({
              required String title,
              VoidCallback? onManage,
            }) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onManage != null)
                    TextButton.icon(
                      onPressed: onManage,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('管理'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              );
            }

            Widget buildFilterChip({
              required String value,
              required String label,
              required String countText,
              required bool selected,
              IconData? icon,
              Color? accentColor,
            }) {
              final color = accentColor ?? colorScheme.primary;
              final avatarColor =
                  selected ? color : colorScheme.onSurfaceVariant;
              return FilterChip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                avatar:
                    icon == null
                        ? null
                        : Icon(icon, size: 16, color: avatarColor),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 132),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      countText,
                      style: textTheme.labelSmall?.copyWith(
                        color:
                            selected
                                ? colorScheme.onSecondaryContainer
                                : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                selected: selected,
                selectedColor:
                    accentColor == null
                        ? palette.primaryContainerColor.withValues(alpha: 0.52)
                        : color.withValues(alpha: 0.16),
                checkmarkColor: color,
                side: BorderSide(
                  color:
                      selected
                          ? color.withValues(alpha: 0.72)
                          : colorScheme.outlineVariant.withValues(alpha: 0.72),
                ),
                onSelected:
                    (_) => _dismissBookshelfBottomSheet(sheetContext, value),
              );
            }

            Widget buildSection({
              required String title,
              required List<Widget> chips,
              VoidCallback? onManage,
              Widget? footer,
            }) {
              if (chips.isEmpty && footer == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSectionHeader(title: title, onManage: onManage),
                    const SizedBox(height: 6),
                    if (chips.isNotEmpty)
                      Wrap(spacing: 6, runSpacing: 6, children: chips),
                    if (footer != null) ...[const SizedBox(height: 4), footer],
                  ],
                ),
              );
            }

            Widget buildExpandButton({
              required bool expanded,
              required String expandLabel,
              required String collapseLabel,
              required VoidCallback onPressed,
            }) {
              return TextButton.icon(
                onPressed: onPressed,
                icon: Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(expanded ? collapseLabel : expandLabel),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            }

            Widget buildEmptyHint(String text) {
              return Text(
                text,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            }

            bool matchesKeyword(String value) {
              final keyword = searchKeyword.trim().toLowerCase();
              if (keyword.isEmpty) {
                return true;
              }
              return value.toLowerCase().contains(keyword);
            }

            final visibleCategories = customCategories
                .where(matchesKeyword)
                .toList(growable: false);
            final visibleTags = customTags
                .where(matchesKeyword)
                .toList(growable: false);
            final effectiveVisibleCategories =
                searchKeyword.trim().isNotEmpty || expandCategories
                    ? visibleCategories
                    : visibleCategories.take(10).toList(growable: false);
            final effectiveVisibleTags =
                searchKeyword.trim().isNotEmpty || expandTags
                    ? visibleTags
                    : visibleTags.take(10).toList(growable: false);
            final defaultChips = <Widget>[
              buildFilterChip(
                value: 'all',
                label: '全部',
                countText: '${baseFilterBookCount[_BookshelfFilter.all] ?? 0}',
                selected:
                    !_activeView.isTag &&
                    !_activeView.isCategory &&
                    _activeView.filter == _BookshelfFilter.all,
                icon: Icons.collections_bookmark_outlined,
              ),
              buildFilterChip(
                value: 'local',
                label: '本地',
                countText:
                    '${baseFilterBookCount[_BookshelfFilter.local] ?? 0}',
                selected:
                    !_activeView.isTag &&
                    !_activeView.isCategory &&
                    _activeView.filter == _BookshelfFilter.local,
                icon: Icons.folder_outlined,
              ),
              buildFilterChip(
                value: 'novel',
                label: '小说',
                countText:
                    '${baseFilterBookCount[_BookshelfFilter.novel] ?? 0}',
                selected:
                    !_activeView.isTag &&
                    !_activeView.isCategory &&
                    _activeView.filter == _BookshelfFilter.novel,
                icon: Icons.menu_book_outlined,
              ),
              buildFilterChip(
                value: 'manga',
                label: '漫画',
                countText:
                    '${baseFilterBookCount[_BookshelfFilter.manga] ?? 0}',
                selected:
                    !_activeView.isTag &&
                    !_activeView.isCategory &&
                    _activeView.filter == _BookshelfFilter.manga,
                icon: Icons.photo_library_outlined,
              ),
            ];
            final categoryChips = <Widget>[
              if (matchesKeyword('未分类'))
                buildFilterChip(
                  value: 'category::__uncategorized__',
                  label: '未分类',
                  countText: '$uncategorizedCount',
                  selected: _activeView.isUncategorized,
                  icon: Icons.folder_off_outlined,
                ),
              ...effectiveVisibleCategories.map((category) {
                final item = _categoryItem(category);
                return buildFilterChip(
                  value: 'category::$category',
                  label: category,
                  countText: '${categoryBookCount[category] ?? 0}',
                  selected:
                      _activeView.isCategory &&
                      _activeView.category == category,
                  icon: Icons.folder_copy_outlined,
                  accentColor: Color(item.colorValue),
                );
              }),
            ];
            final tagChips = <Widget>[
              if (matchesKeyword('未打标签'))
                buildFilterChip(
                  value: 'tag::__untagged__',
                  label: '未打标签',
                  countText:
                      '${_books.where((book) => _tagsOfBook(book).isEmpty).length}',
                  selected: _activeView.isTag && _activeView.tag == '',
                  icon: Icons.sell_outlined,
                ),
              ...effectiveVisibleTags.map((tag) {
                final item = _tagItem(tag);
                return buildFilterChip(
                  value: 'tag::$tag',
                  label: tag,
                  countText: '${tagBookCount[tag] ?? 0}',
                  selected: _activeView.isTag && _activeView.tag == tag,
                  icon: Icons.sell_outlined,
                  accentColor: Color(item.colorValue),
                );
              }),
            ];

            return Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 10 + bottomInset),
              child: Theme(
                data: compactTheme,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '搜索分类或标签',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            searchKeyword = value;
                          });
                        },
                      ),
                      buildSection(title: '快捷入口', chips: defaultChips),
                      buildSection(
                        title: '分类',
                        chips: categoryChips,
                        onManage:
                            () => _dismissBookshelfBottomSheet(
                              sheetContext,
                              'manage_category::__new__',
                            ),
                        footer:
                            searchKeyword.trim().isEmpty &&
                                    visibleCategories.length > 10
                                ? buildExpandButton(
                                  expanded: expandCategories,
                                  expandLabel: '展开全部分类',
                                  collapseLabel: '收起分类',
                                  onPressed: () {
                                    setSheetState(() {
                                      expandCategories = !expandCategories;
                                    });
                                  },
                                )
                                : categoryChips.isEmpty
                                ? buildEmptyHint('暂无分类，点击右上角管理可新建。')
                                : null,
                      ),
                      buildSection(
                        title: '标签',
                        chips: tagChips,
                        onManage:
                            () => _dismissBookshelfBottomSheet(
                              sheetContext,
                              'manage_tag::__new__',
                            ),
                        footer:
                            searchKeyword.trim().isEmpty &&
                                    visibleTags.length > 10
                                ? buildExpandButton(
                                  expanded: expandTags,
                                  expandLabel: '展开全部标签',
                                  collapseLabel: '收起标签',
                                  onPressed: () {
                                    setSheetState(() {
                                      expandTags = !expandTags;
                                    });
                                  },
                                )
                                : tagChips.isEmpty
                                ? buildEmptyHint('暂无标签，点击右上角管理可新建。')
                                : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    if (selected.startsWith('manage_tag::')) {
      if (!mounted) {
        return;
      }
      await context.push('/mine/tags');
      return;
    }
    if (selected.startsWith('manage_category::')) {
      if (!mounted) {
        return;
      }
      await context.push('/mine/categories');
      return;
    }

    if (selected == 'tag::__untagged__') {
      _activateView(const _BookshelfViewSelection.tag(''));
      return;
    }
    if (selected.startsWith('tag::')) {
      final tag = selected.substring(5).trim();
      if (tag.isNotEmpty) {
        _activateView(_BookshelfViewSelection.tag(tag));
      }
      return;
    }
    if (selected == 'category::__uncategorized__') {
      _activateView(const _BookshelfViewSelection.category(null));
      return;
    }
    if (selected.startsWith('category::')) {
      final category = selected.substring(10).trim();
      if (category.isNotEmpty) {
        _activateView(_BookshelfViewSelection.category(category));
      }
      return;
    }

    switch (selected) {
      case 'all':
        _activateView(const _BookshelfViewSelection.base(_BookshelfFilter.all));
        break;
      case 'local':
        _activateView(
          const _BookshelfViewSelection.base(_BookshelfFilter.local),
        );
        break;
      case 'novel':
        _activateView(
          const _BookshelfViewSelection.base(_BookshelfFilter.novel),
        );
        break;
      case 'manga':
        _activateView(
          const _BookshelfViewSelection.base(_BookshelfFilter.manga),
        );
        break;
      default:
        break;
    }
  }
}

class _BookshelfSettingsModeButton extends StatelessWidget {
  const _BookshelfSettingsModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color:
          selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.92)
              : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: selected ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color:
                    selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color:
                      selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookshelfTaxonomyEditorResult {
  const _BookshelfTaxonomyEditorResult.save({
    required this.name,
    required this.colorValue,
  }) : delete = false;

  const _BookshelfTaxonomyEditorResult.delete()
    : name = '',
      colorValue = 0,
      delete = true;

  final String name;
  final int colorValue;
  final bool delete;
}

class _BookshelfTaxonomyEditorDialog extends StatefulWidget {
  const _BookshelfTaxonomyEditorDialog({
    required this.kind,
    required this.isNew,
    required this.initialName,
    required this.initialColorValue,
  });

  final BookshelfTaxonomyKind kind;
  final bool isNew;
  final String initialName;
  final int initialColorValue;

  @override
  State<_BookshelfTaxonomyEditorDialog> createState() =>
      _BookshelfTaxonomyEditorDialogState();
}

class _BookshelfTaxonomyEditorDialogState
    extends State<_BookshelfTaxonomyEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _hexController;
  late Color _draftColor;
  String? _errorText;

  bool get _isTag => widget.kind == BookshelfTaxonomyKind.tag;

  @override
  void initState() {
    super.initState();
    _draftColor = Color(widget.initialColorValue);
    _nameController = TextEditingController(text: widget.initialName);
    _hexController = TextEditingController(
      text: _formatTaxonomyHex(_draftColor.toARGB32()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = _isTag ? '请输入标签名称' : '请输入分类名称';
      });
      return;
    }
    Navigator.of(context).pop(
      _BookshelfTaxonomyEditorResult.save(
        name: name,
        colorValue: _draftColor.toARGB32(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final desktopLike = AppLayout.isDesktopLike(
      context,
      platform: theme.platform,
    );
    final panelRadius = BorderRadius.vertical(
      top: const Radius.circular(28),
      bottom: desktopLike ? const Radius.circular(28) : Radius.zero,
    );
    final title =
        widget.isNew ? (_isTag ? '新增标签' : '新增分类') : '编辑${_isTag ? '标签' : '分类'}';

    return Material(
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: panelRadius),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!desktopLike) ...[
              const AdaptiveSheetDragHandle(),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!widget.isNew)
                  IconButton(
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pop(const _BookshelfTaxonomyEditorResult.delete()),
                    tooltip: '删除',
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                FilledButton.tonal(onPressed: _save, child: const Text('保存')),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _isTag ? '标签名称' : '分类名称',
                errorText: _errorText,
                filled: true,
                fillColor: colorScheme.surface.withValues(alpha: 0.72),
              ),
              onChanged: (_) {
                if (_errorText == null) {
                  return;
                }
                setState(() {
                  _errorText = null;
                });
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _hexController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
              ],
              onChanged: (value) {
                final parsed = _parseTaxonomyHexColor(value);
                if (parsed == null) {
                  return;
                }
                setState(() {
                  _draftColor = Color(parsed);
                });
              },
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                hintText: '#RRGGBB / #AARRGGBB',
                filled: true,
                fillColor: colorScheme.surface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),
            ColorPicker(
              pickerColor: _draftColor,
              onColorChanged: (color) {
                setState(() {
                  _draftColor = color;
                });
              },
              enableAlpha: true,
              displayThumbColor: true,
              portraitOnly: true,
              paletteType: PaletteType.hsvWithHue,
              colorPickerWidth: 360,
              pickerAreaHeightPercent: 0.62,
              pickerAreaBorderRadius: const BorderRadius.all(
                Radius.circular(12),
              ),
              labelTypes: const [],
              hexInputController: _hexController,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _draftColor,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.38),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _formatTaxonomyHex(_draftColor.toARGB32()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '上方色板调明度和饱和度，第一条调色相，第二条调透明度。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int? _parseTaxonomyHexColor(String raw) {
  final normalized = raw.trim().toUpperCase();
  if (normalized.isEmpty) {
    return null;
  }
  final body =
      normalized.startsWith('#') ? normalized.substring(1) : normalized;
  if (body.length == 6) {
    return int.tryParse('FF$body', radix: 16);
  }
  if (body.length == 8) {
    return int.tryParse(body, radix: 16);
  }
  return null;
}

String _formatTaxonomyHex(int? value) {
  if (value == null) {
    return '';
  }
  final hex = value.toRadixString(16).toUpperCase().padLeft(8, '0');
  if (hex.startsWith('FF')) {
    return '#${hex.substring(2)}';
  }
  return '#$hex';
}

class _BookshelfExternalImportSheet extends StatefulWidget {
  const _BookshelfExternalImportSheet({
    required this.payload,
    required this.externalImportCoordinator,
    required this.importService,
    required this.onReload,
    required this.onShowMessage,
  });

  final IncomingExternalImportPayload payload;
  final BookshelfExternalImportCoordinator externalImportCoordinator;
  final LocalBookImportService importService;
  final Future<void> Function() onReload;
  final void Function(String message) onShowMessage;

  @override
  State<_BookshelfExternalImportSheet> createState() =>
      _BookshelfExternalImportSheetState();
}

class _BookshelfExternalImportSheetState
    extends State<_BookshelfExternalImportSheet> {
  ImportExportTaskStatus _status = const ImportExportTaskStatus(
    title: '正在导入外部图书',
    message: '正在读取外部文件并准备导入…',
  );
  bool _started = false;

  List<AppTaskStep> get _steps {
    final current =
        _status.result == ImportExportTaskResult.success
            ? 2
            : (_started ? 1 : 0);
    return <AppTaskStep>[
      AppTaskStep(label: '接收文件', active: current >= 0),
      AppTaskStep(label: '解析导入', active: current >= 1),
      AppTaskStep(label: '完成', active: current >= 2),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) {
        return;
      }
      _start();
    });
  }

  Future<void> _start() async {
    setState(() {
      _started = true;
    });
    final cached = await widget.externalImportCoordinator
        .cacheExternalFileFromUri(widget.payload);
    if (!mounted) {
      return;
    }
    if (cached == null) {
      ExternalImportDiagnostics.logCacheFailed(widget.payload);
      final message = ExternalImportDiagnostics.readFailedMessage(
        widget.payload.type,
        widget.payload.label,
      );
      _updateStatus(
        ImportExportTaskStatus(
          title: '导入外部图书失败',
          message: message,
          result: ImportExportTaskResult.failure,
        ),
      );
      widget.onShowMessage(message);
      return;
    }

    final tempFile = File(cached.path);
    try {
      if (!ExternalImportCatalog.supportsFileLabel(
        ExternalImportPayloadType.localBook,
        cached.label,
      )) {
        ExternalImportDiagnostics.logImportUnsupported(
          ExternalImportPayloadType.localBook,
          cached.label,
        );
        final message = ExternalImportCatalog.unsupportedFileMessage(
          ExternalImportPayloadType.localBook,
          cached.label,
        );
        _updateStatus(
          ImportExportTaskStatus(
            title: '导入外部图书失败',
            message: message,
            result: ImportExportTaskResult.failure,
          ),
        );
        widget.onShowMessage(message);
        return;
      }

      await widget.importService.importFromFile(
        filePath: cached.path,
        displayName: cached.label,
        waitForIndexing:
            LocalBookWorkflowPolicy.externalImportShouldWaitForIndexing,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          final stageText = switch (progress.stage) {
            LocalBookImportStage.preparing => '准备文件',
            LocalBookImportStage.persisted => '写入书架',
            LocalBookImportStage.indexing => '建立目录',
            LocalBookImportStage.completed => '完成导入',
          };
          _updateStatus(
            ImportExportTaskStatus(
              title: '正在导入外部图书',
              message: '${progress.displayName} · $stageText',
              detail: progress.detail,
            ),
          );
        },
      );
      await widget.onReload();
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportSucceeded(
        ExternalImportPayloadType.localBook,
        cached.label,
      );
      _updateStatus(
        ImportExportTaskStatus(
          title: '外部图书已导入',
          message: cached.label,
          detail: '目录已建立，可直接阅读。',
          progress: 1,
          result: ImportExportTaskResult.success,
        ),
      );
      widget.onShowMessage('已导入 ${cached.label}，目录已建立，可直接阅读。');
    } on AppException catch (error) {
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.localBook,
        cached.label,
        error,
      );
      _updateStatus(
        ImportExportTaskStatus(
          title: '导入外部图书失败',
          message: error.briefMessage,
          result: ImportExportTaskResult.failure,
        ),
      );
      widget.onShowMessage(error.briefMessage);
    } catch (error) {
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.localBook,
        cached.label,
        error,
      );
      final message = ExternalImportDiagnostics.importFailedMessage(
        ExternalImportPayloadType.localBook,
        '$error',
        label: cached.label,
      );
      _updateStatus(
        ImportExportTaskStatus(
          title: '导入外部图书失败',
          message: message,
          result: ImportExportTaskResult.failure,
        ),
      );
      widget.onShowMessage(message);
    } finally {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {
        // ignore cleanup failure
      }
    }
  }

  void _updateStatus(ImportExportTaskStatus status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppTaskBottomSheet(
      title: '导入外部图书',
      maxHeightFactor: 0.42,
      fitContent: true,
      steps: _steps,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _status.isFinished
              ? ImportExportTaskSheet(status: _status)
              : ImportExportProgressCard(status: _status),
        ],
      ),
    );
  }
}

class _BookshelfImportLocalBooksSheet extends StatefulWidget {
  const _BookshelfImportLocalBooksSheet({
    required this.flowCoordinator,
    required this.importService,
    required this.onReload,
    required this.onOpenReader,
    required this.onShowMessage,
    required this.onClose,
  });

  final BookshelfFlowCoordinator flowCoordinator;
  final LocalBookImportService importService;
  final Future<void> Function() onReload;
  final Future<void> Function(BookshelfBook book, LocalBook localBook)
  onOpenReader;
  final void Function(String message) onShowMessage;
  final VoidCallback onClose;

  @override
  State<_BookshelfImportLocalBooksSheet> createState() =>
      _BookshelfImportLocalBooksSheetState();
}

class _BookshelfImportLocalBooksSheetState
    extends State<_BookshelfImportLocalBooksSheet> {
  bool _isImporting = false;
  int _total = 0;
  int _completed = 0;
  String? _currentLabel;
  String? _detail;
  String? _lastError;
  LocalBookImportStage? _stage;
  LocalBookImportResult? _lastImportedResult;

  List<AppTaskStep> get _steps {
    final current =
        !_isImporting && _lastImportedResult != null
            ? 2
            : (_isImporting ? 1 : 0);
    return <AppTaskStep>[
      AppTaskStep(label: '添加文件', active: current >= 0),
      AppTaskStep(label: '解析导入', active: current >= 1),
      AppTaskStep(label: '完成', active: current >= 2),
    ];
  }

  Future<void> _pickAndImportFiles() async {
    if (_isImporting) {
      return;
    }

    final files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[
        ExternalImportCatalog.localBookTypeGroup,
      ],
      confirmButtonText: '选择本地图书',
    );
    if (!mounted || files.isEmpty) {
      return;
    }

    setState(() {
      _isImporting = true;
      _total = files.length;
      _completed = 0;
      _currentLabel = null;
      _detail = '图文内容较多时，解析和提取资源会耗时更久。';
      _lastError = null;
      _stage = LocalBookImportStage.preparing;
      _lastImportedResult = null;
    });

    try {
      final summary = await widget.flowCoordinator.importLocalBooks(
        candidates: files.map(
          (file) => BookshelfImportCandidate(
            filePath: file.path.trim(),
            displayName:
                file.name.trim().isEmpty
                    ? p.basename(file.path.trim())
                    : file.name.trim(),
          ),
        ),
        importer: (candidate) async {
          final result = await widget.importService.importFromFile(
            filePath: candidate.filePath,
            displayName: candidate.displayName,
            waitForIndexing:
                LocalBookWorkflowPolicy.directImportShouldWaitForIndexing,
            onProgress: (progress) {
              if (!mounted) {
                return;
              }
              setState(() {
                _currentLabel = progress.displayName;
                _stage = progress.stage;
                _detail = progress.detail;
              });
            },
          );
          _lastImportedResult = result;
        },
        errorFormatter: (error) {
          return switch (error) {
            AppException() => error.briefMessage,
            _ => '导入失败：$error',
          };
        },
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _currentLabel = progress.currentFileLabel;
            _completed = progress.completedCount;
          });
        },
      );

      await widget.onReload();

      if (!mounted) {
        return;
      }
      setState(() {
        _isImporting = false;
        _completed = _total;
        _stage = LocalBookImportStage.completed;
        _detail =
            summary.hasSuccess
                ? '目录已建立，可直接阅读。'
                : (summary.lastError ?? '导入失败，请重试。');
        _lastError = summary.lastError;
      });
      widget.onShowMessage(
        summary.hasSuccess
            ? LocalBookWorkflowPolicy.importSuccessMessage(
              successCount: summary.successCount,
              failureCount: summary.failureCount,
              directoryReady: true,
            )
            : (summary.lastError ?? '导入失败，请重试。'),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isImporting = false;
        _lastError = '$error';
        _detail = '$error';
      });
      widget.onShowMessage('导入失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stageText = switch (_stage) {
      LocalBookImportStage.preparing => '准备文件',
      LocalBookImportStage.persisted => '写入书架',
      LocalBookImportStage.indexing => '建立目录',
      LocalBookImportStage.completed => '完成导入',
      null => '请选择本地图书文件',
    };

    final status =
        _isImporting || _lastImportedResult != null || _lastError != null
            ? ImportExportTaskStatus(
              title:
                  !_isImporting && _lastImportedResult != null
                      ? '本地图书已导入'
                      : '正在导入本地图书',
              message:
                  _currentLabel?.trim().isNotEmpty == true
                      ? '${_currentLabel!} · $stageText'
                      : stageText,
              detail: _detail,
              progress: _total <= 0 ? null : _completed / _total,
              progressLabel: _total <= 0 ? null : '$_completed/$_total',
              result:
                  !_isImporting && _lastImportedResult != null
                      ? ImportExportTaskResult.success
                      : (_lastError != null
                          ? ImportExportTaskResult.failure
                          : ImportExportTaskResult.running),
            )
            : null;

    return AppTaskBottomSheet(
      title: '导入本地图书',
      trailing: IconButton(
        tooltip: '导入说明',
        onPressed: () {
          showAdaptiveActionSurface<void>(
            context: context,
            maxWidth: 460,
            builder: (context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '导入说明',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '支持 TXT、EPUB、Markdown、HTML、PDF；MOBI、AZW、AZW3 为实验支持。\n\n'
                    '图文内容较多时，系统会继续解析结构和图片资源。\n\n'
                    '导入阶段：添加文件 -> 解析导入 -> 完成。',
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('知道了'),
                    ),
                  ),
                ],
              );
            },
          );
        },
        icon: const Icon(Icons.help_outline_rounded),
      ),
      maxHeightFactor: 0.46,
      fitContent: true,
      steps: _steps,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isImporting && _lastImportedResult == null)
            AppTaskActionCard(
              title: '添加图书文件',
              description: '支持一次选择多个本地图书文件。',
              icon: Icons.library_add_rounded,
              dashedBorder: true,
              onTap: _pickAndImportFiles,
            )
          else if (status != null)
            (!_isImporting && _lastImportedResult != null)
                ? ImportExportTaskSheet(status: status)
                : ImportExportProgressCard(status: status),
        ],
      ),
    );
  }
}
