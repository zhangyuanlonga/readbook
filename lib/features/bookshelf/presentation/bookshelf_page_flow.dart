part of 'bookshelf_page.dart';

extension on _BookshelfPageState {
  void _handleMoreAction(_BookshelfMoreAction action) {
    switch (action) {
      case _BookshelfMoreAction.selectBooks:
        _startSelectionMode();
        break;
      case _BookshelfMoreAction.batchEditCover:
        _startSelectionMode();
        if (_isSelectionMode) {
          _showMessage('已进入选择模式，选择书籍后点击底部“修改封面”。');
        }
        break;
      case _BookshelfMoreAction.sortBooks:
        unawaited(_showSortModeSheet());
        break;
      case _BookshelfMoreAction.settings:
        unawaited(_showBookshelfSettingsSheet());
        break;
      case _BookshelfMoreAction.importLocal:
        unawaited(_importLocalBooksFromPicker());
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
    return _books.isNotEmpty ||
        _alwaysShowBookshelfSearchBar ||
        _hasBookshelfSearchKeyword ||
        _isBookshelfSearchExpanded;
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

  void _expandBookshelfSearch() {
    if (_shouldShowExpandedBookshelfSearch) {
      _bookshelfSearchFocusNode.requestFocus();
      return;
    }
    _updateBookshelfState(() {
      _isBookshelfSearchExpanded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bookshelfSearchFocusNode.requestFocus();
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

    var draftAdaptive = _gridAdaptiveColumns;
    var draftColumns = _gridColumnCount;
    var draftCrossSpacing = _gridCrossSpacing;
    var draftMainSpacing = _gridMainSpacing;
    var draftShowTitle = _gridShowTitle;
    var draftShowAuthor = _gridShowAuthor;
    var draftShowLatestChapter = _gridShowLatestChapter;
    var draftShowProgressBar = _gridShowProgressBar;
    var draftGridAlwaysShowSearchBar = _gridAlwaysShowSearchBar;
    var draftGridPinSearchBar = _gridPinSearchBar;
    var draftGridQuickFilterContent = _gridQuickFilterContent;
    var draftListShowTitle = _listShowTitle;
    var draftListShowAuthor = _listShowAuthor;
    var draftListShowLatestChapter = _listShowLatestChapter;
    var draftListShowProgressBar = _listShowProgressBar;
    var draftListAlwaysShowSearchBar = _listAlwaysShowSearchBar;
    var draftListPinSearchBar = _listPinSearchBar;
    var draftListQuickFilterContent = _listQuickFilterContent;

    await _showBookshelfBottomSheet<void>(
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomInset = _bookshelfBottomSafeInset(sheetContext);
        return DefaultTabController(
          initialIndex: _useGridView ? 1 : 0,
          length: _BookshelfSettingsTab.values.length,
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final theme = Theme.of(sheetContext);
              final colorScheme = theme.colorScheme;
              final tabs = _BookshelfSettingsTab.values;

              Future<void> persistGridSettings() async {
                try {
                  await _bookshelfService.saveGridAdaptiveColumns(
                    draftAdaptive,
                  );
                  await _bookshelfService.saveGridColumnCount(draftColumns);
                  await _bookshelfService.saveGridCrossSpacing(
                    draftCrossSpacing,
                  );
                  await _bookshelfService.saveGridMainSpacing(draftMainSpacing);
                  await _bookshelfService.saveGridShowTitle(draftShowTitle);
                  await _bookshelfService.saveGridShowAuthor(draftShowAuthor);
                  await _bookshelfService.saveGridShowLatestChapter(
                    draftShowLatestChapter,
                  );
                  await _bookshelfService.saveGridShowProgressBar(
                    draftShowProgressBar,
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
                  await _bookshelfService.saveListShowAuthor(
                    draftListShowAuthor,
                  );
                  await _bookshelfService.saveListShowLatestChapter(
                    draftListShowLatestChapter,
                  );
                  await _bookshelfService.saveListShowProgressBar(
                    draftListShowProgressBar,
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
                if (_useGridView == useGridView) {
                  return;
                }
                _updateBookshelfState(() {
                  _useGridView = useGridView;
                });
                try {
                  await _bookshelfService.saveUseGridView(useGridView);
                } catch (_) {
                  if (!mounted) {
                    return;
                  }
                  _showMessage('书架视图保存失败，请重试。');
                }
              }

              Widget buildSectionTitle(String title, String subtitle) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
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
                  ),
                );
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
                required ValueChanged<bool> onChanged,
              }) {
                return SwitchListTile.adaptive(
                  value: value,
                  dense: false,
                  visualDensity: const VisualDensity(
                    horizontal: -1,
                    vertical: -1,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle:
                      subtitle == null
                          ? null
                          : Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12.5,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                  onChanged: onChanged,
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
                      title: '总是显示搜索框',
                      subtitle: '关闭后显示为紧凑入口，点击后再展开搜索。',
                      onChanged: onAlwaysShowChanged,
                    ),
                    buildCompactSwitchTile(
                      value: pinSearchBar,
                      title: '搜索框吸顶',
                      subtitle: '滚动时将快捷筛选和搜索入口固定在顶部。',
                      onChanged: onPinChanged,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '快捷筛选内容',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<
                              _BookshelfSearchQuickFilterContent
                            >(
                              value: quickFilterContent,
                              isDense: true,
                              borderRadius: BorderRadius.circular(14),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              onChanged:
                                  (value) =>
                                      value == null
                                          ? null
                                          : onQuickFilterChanged(value),
                              items: [
                                for (final option
                                    in _BookshelfSearchQuickFilterContent
                                        .values)
                                  DropdownMenuItem<
                                    _BookshelfSearchQuickFilterContent
                                  >(
                                    value: option,
                                    child: Text(
                                      _searchQuickFilterContentLabel(option),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              Widget buildGridSettings() {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                  children: [
                    buildSectionTitle('网格设置', '自定义网格列数与间距，自适应开启后会按屏幕宽度自动分列。'),
                    buildGroupHeader('布局设置'),
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
                      subtitle:
                          draftAdaptive ? '已启用自适应列数，固定列数暂不可用' : '手动指定固定列数。',
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
                    BookshelfStepperSettingRow(
                      title: '列间距',
                      subtitle: '控制卡片之间的左右间距。',
                      valueLabel: draftCrossSpacing.toStringAsFixed(0),
                      onDecrease:
                          draftCrossSpacing <= 4
                              ? null
                              : () {
                                final next = (draftCrossSpacing - 2).clamp(
                                  4.0,
                                  24.0,
                                );
                                setSheetState(() {
                                  draftCrossSpacing = next;
                                });
                                _updateBookshelfState(() {
                                  _gridCrossSpacing = next;
                                });
                                unawaited(persistGridSettings());
                              },
                      onIncrease:
                          draftCrossSpacing >= 24
                              ? null
                              : () {
                                final next = (draftCrossSpacing + 2).clamp(
                                  4.0,
                                  24.0,
                                );
                                setSheetState(() {
                                  draftCrossSpacing = next;
                                });
                                _updateBookshelfState(() {
                                  _gridCrossSpacing = next;
                                });
                                unawaited(persistGridSettings());
                              },
                    ),
                    BookshelfStepperSettingRow(
                      title: '行间距',
                      subtitle: '控制卡片之间的上下间距。',
                      valueLabel: draftMainSpacing.toStringAsFixed(0),
                      onDecrease:
                          draftMainSpacing <= 4
                              ? null
                              : () {
                                final next = (draftMainSpacing - 2).clamp(
                                  4.0,
                                  24.0,
                                );
                                setSheetState(() {
                                  draftMainSpacing = next;
                                });
                                _updateBookshelfState(() {
                                  _gridMainSpacing = next;
                                });
                                unawaited(persistGridSettings());
                              },
                      onIncrease:
                          draftMainSpacing >= 24
                              ? null
                              : () {
                                final next = (draftMainSpacing + 2).clamp(
                                  4.0,
                                  24.0,
                                );
                                setSheetState(() {
                                  draftMainSpacing = next;
                                });
                                _updateBookshelfState(() {
                                  _gridMainSpacing = next;
                                });
                                unawaited(persistGridSettings());
                              },
                    ),
                    buildGroupHeader('文字信息'),
                    buildCompactSwitchTile(
                      value: !draftShowTitle,
                      title: '隐藏书籍名称',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftShowTitle = next;
                        });
                        _updateBookshelfState(() {
                          _gridShowTitle = next;
                        });
                        unawaited(persistGridSettings());
                      },
                    ),
                    buildCompactSwitchTile(
                      value: !draftShowAuthor,
                      title: '隐藏作者名称',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftShowAuthor = next;
                        });
                        _updateBookshelfState(() {
                          _gridShowAuthor = next;
                        });
                        unawaited(persistGridSettings());
                      },
                    ),
                    buildCompactSwitchTile(
                      value: !draftShowLatestChapter,
                      title: '隐藏最新章节',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftShowLatestChapter = next;
                        });
                        _updateBookshelfState(() {
                          _gridShowLatestChapter = next;
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
                            if (value) {
                              _isBookshelfSearchExpanded = false;
                            }
                          });
                        });
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _resolvedPalette(sheetContext).surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _resolvedPalette(
                              sheetContext,
                            ).cardBorderColor.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          '当前暂未提供额外封面设置。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    buildGroupHeader('其他设置'),
                    buildCompactSwitchTile(
                      value: !draftShowProgressBar,
                      title: '隐藏进度条',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftShowProgressBar = next;
                        });
                        _updateBookshelfState(() {
                          _gridShowProgressBar = next;
                        });
                        unawaited(persistGridSettings());
                      },
                    ),
                  ],
                );
              }

              Widget buildListSettings() {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                  children: [
                    buildSectionTitle('列表设置', '调整列表模式下展示哪些信息。'),
                    buildGroupHeader('文字信息'),
                    buildCompactSwitchTile(
                      value: !draftListShowTitle,
                      title: '隐藏书籍名称',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftListShowTitle = next;
                        });
                        _updateBookshelfState(() {
                          _listShowTitle = next;
                        });
                        unawaited(persistListSettings());
                      },
                    ),
                    buildCompactSwitchTile(
                      value: !draftListShowAuthor,
                      title: '隐藏作者名称',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftListShowAuthor = next;
                        });
                        _updateBookshelfState(() {
                          _listShowAuthor = next;
                        });
                        unawaited(persistListSettings());
                      },
                    ),
                    buildCompactSwitchTile(
                      value: !draftListShowLatestChapter,
                      title: '隐藏最新章节',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftListShowLatestChapter = next;
                        });
                        _updateBookshelfState(() {
                          _listShowLatestChapter = next;
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
                            if (value) {
                              _isBookshelfSearchExpanded = false;
                            }
                          });
                        });
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
                    buildGroupHeader('其他设置'),
                    buildCompactSwitchTile(
                      value: !draftListShowProgressBar,
                      title: '隐藏进度条',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftListShowProgressBar = next;
                        });
                        _updateBookshelfState(() {
                          _listShowProgressBar = next;
                        });
                        unawaited(persistListSettings());
                      },
                    ),
                    buildGroupHeader('封面设置'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _resolvedPalette(sheetContext).surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _resolvedPalette(
                              sheetContext,
                            ).cardBorderColor.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          '当前暂未提供额外封面设置。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomInset),
                child: SizedBox(
                  height: MediaQuery.sizeOf(sheetContext).height * 0.66,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 3, 12, 7),
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
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _resolvedPalette(sheetContext).surfaceColor,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelStyle: theme.textTheme.labelMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelStyle: theme.textTheme.labelMedium
                              ?.copyWith(fontSize: 14),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          tabAlignment: TabAlignment.fill,
                          onTap:
                              (index) =>
                                  unawaited(setBookshelfViewMode(index == 1)),
                          tabs: [
                            for (final tab in tabs)
                              Tab(text: _bookshelfSettingsTabLabel(tab)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Expanded(
                        child: TabBarView(
                          children: [buildListSettings(), buildGridSettings()],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _importLocalBooksFromPicker() async {
    if (_isImportingLocal || _isBatchDeleting) {
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

    _updateBookshelfState(() {
      _isImportingLocal = true;
      _taskStatus = ImportExportTaskStatus(
        title: '正在导入本地图书',
        message: '正在准备处理 ${files.length} 个文件…',
        progress: 0,
        progressLabel: '0/${files.length}',
      );
    });

    try {
      final summary = await _flowCoordinator.importLocalBooks(
        candidates: files.map(
          (file) => BookshelfImportCandidate(
            filePath: file.path.trim(),
            displayName:
                file.name.trim().isEmpty
                    ? p.basename(file.path.trim())
                    : file.name.trim(),
          ),
        ),
        importer: (candidate) {
          return _localBookImportService.importFromFile(
            filePath: candidate.filePath,
            displayName: candidate.displayName,
            waitForIndexing:
                LocalBookWorkflowPolicy.directImportShouldWaitForIndexing,
            onProgress: (progress) {
              if (!mounted) {
                return;
              }
              final stageText = switch (progress.stage) {
                LocalBookImportStage.preparing => '正在准备文件',
                LocalBookImportStage.persisted => '已写入书架，正在整理记录',
                LocalBookImportStage.indexing => '正在解析目录与正文',
                LocalBookImportStage.completed => '已完成导入',
              };
              _updateBookshelfState(() {
                final current = _taskStatus;
                _taskStatus = ImportExportTaskStatus(
                  title: '正在导入本地图书',
                  message: '${progress.displayName} · $stageText',
                  progress: current?.progress,
                  progressLabel: current?.progressLabel,
                );
              });
            },
          );
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
          _updateBookshelfState(() {
            _taskStatus = ImportExportTaskStatus(
              title: '正在导入本地图书',
              message: '正在处理 ${progress.currentFileLabel}',
              progress:
                  progress.totalCount <= 0
                      ? null
                      : progress.completedCount / progress.totalCount,
              progressLabel:
                  progress.totalCount <= 0
                      ? null
                      : '${progress.completedCount}/${progress.totalCount}',
            );
          });
        },
      );

      await _loadBookshelf(force: true);

      if (!mounted) {
        return;
      }

      if (summary.hasSuccess) {
        _showMessage(
          LocalBookWorkflowPolicy.importSuccessMessage(
            successCount: summary.successCount,
            failureCount: summary.failureCount,
            directoryReady:
                LocalBookWorkflowPolicy.directImportShouldWaitForIndexing,
          ),
        );
        return;
      }

      _showMessage(summary.lastError ?? '导入失败，请重试。');
    } finally {
      if (mounted) {
        _updateBookshelfState(() {
          _isImportingLocal = false;
          _taskStatus = null;
        });
      }
    }
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
    _updateBookshelfState(() {
      _taskStatus = ImportExportTaskStatus(
        title: '正在导入外部图书',
        message: '正在读取 ${payload.label} 并准备入库…',
      );
    });
    final cached = await _externalImportCoordinator.cacheExternalFileFromUri(
      payload,
    );
    if (cached == null) {
      ExternalImportDiagnostics.logCacheFailed(payload);
      _showMessage(
        ExternalImportDiagnostics.readFailedMessage(
          payload.type,
          payload.label,
        ),
      );
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
        _showMessage(
          ExternalImportCatalog.unsupportedFileMessage(
            ExternalImportPayloadType.localBook,
            cached.label,
          ),
        );
        return;
      }

      await _localBookImportService.importFromFile(
        filePath: cached.path,
        displayName: cached.label,
        waitForIndexing:
            LocalBookWorkflowPolicy.externalImportShouldWaitForIndexing,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          final stageText = switch (progress.stage) {
            LocalBookImportStage.preparing => '正在准备文件',
            LocalBookImportStage.persisted => '已写入书架，正在整理记录',
            LocalBookImportStage.indexing => '正在解析目录与正文',
            LocalBookImportStage.completed => '已完成导入',
          };
          _updateBookshelfState(() {
            _taskStatus = ImportExportTaskStatus(
              title: '正在导入外部图书',
              message: '${progress.displayName} · $stageText',
            );
          });
        },
      );
      await _loadBookshelf(force: true);
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportSucceeded(
        ExternalImportPayloadType.localBook,
        cached.label,
      );
      _showMessage('已导入 ${cached.label}');
    } on AppException catch (error) {
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.localBook,
        cached.label,
        error,
      );
      _showMessage(error.briefMessage);
    } catch (error) {
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.localBook,
        cached.label,
        error,
      );
      _showMessage(
        ExternalImportDiagnostics.importFailedMessage(
          ExternalImportPayloadType.localBook,
          '$error',
          label: cached.label,
        ),
      );
    } finally {
      if (mounted) {
        _updateBookshelfState(() {
          _taskStatus = null;
        });
      }
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {
        // ignore cleanup failure
      }
    }
  }

  Future<T?> _showBookshelfBottomSheet<T>({
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: isScrollControlled,
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

            Widget buildSectionTitle(String title) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            Widget buildOptionTile({
              required String value,
              required String label,
              required String countText,
              required bool selected,
              VoidCallback? onTap,
              IconData? icon,
              String? subtitle,
            }) {
              return Material(
                color:
                    selected
                        ? palette.primaryContainerColor.withValues(alpha: 0.42)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap:
                      onTap ??
                      () => _dismissBookshelfBottomSheet(sheetContext, value),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 18,
                            color:
                                selected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  color:
                                      selected
                                          ? palette.textPrimaryColor
                                          : colorScheme.onSurface,
                                  fontWeight:
                                      selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                              ),
                              if (subtitle != null && subtitle.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          countText,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (selected)
                          Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
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
                    : visibleCategories.take(6).toList(growable: false);
            final effectiveVisibleTags =
                searchKeyword.trim().isNotEmpty || expandTags
                    ? visibleTags
                    : visibleTags.take(6).toList(growable: false);

            return Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      child: TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '搜索分类或标签',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            searchKeyword = value;
                          });
                        },
                      ),
                    ),
                    buildSectionTitle('默认'),
                    buildOptionTile(
                      value: 'all',
                      label: '书架',
                      countText:
                          '${baseFilterBookCount[_BookshelfFilter.all] ?? 0}',
                      selected:
                          !_activeView.isTag &&
                          !_activeView.isCategory &&
                          _activeView.filter == _BookshelfFilter.all,
                      icon: Icons.collections_bookmark_outlined,
                    ),
                    buildOptionTile(
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
                    buildOptionTile(
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
                    buildOptionTile(
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
                    buildSectionTitle('分类'),
                    if (matchesKeyword('未分类'))
                      buildOptionTile(
                        value: 'category::__uncategorized__',
                        label: '未分类',
                        countText: '$uncategorizedCount',
                        selected: _activeView.isUncategorized,
                        icon: Icons.folder_off_outlined,
                      ),
                    ...effectiveVisibleCategories.map(
                      (category) => buildOptionTile(
                        value: 'category::$category',
                        label: category,
                        countText: '${categoryBookCount[category] ?? 0}',
                        selected:
                            _activeView.isCategory &&
                            _activeView.category == category,
                        icon: Icons.folder_copy_outlined,
                      ),
                    ),
                    if (searchKeyword.trim().isEmpty &&
                        visibleCategories.length > 6)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                expandCategories = !expandCategories;
                              });
                            },
                            icon: Icon(
                              expandCategories
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                            ),
                            label: Text(expandCategories ? '收起分类' : '展开全部分类'),
                          ),
                        ),
                      ),
                    if (visibleTags.isNotEmpty || matchesKeyword('未打标签')) ...[
                      buildSectionTitle('标签'),
                      if (matchesKeyword('未打标签'))
                        buildOptionTile(
                          value: 'tag::__untagged__',
                          label: '未打标签',
                          countText:
                              '${_books.where((book) => _tagsOfBook(book).isEmpty).length}',
                          selected: _activeView.isTag && _activeView.tag == '',
                          icon: Icons.sell_outlined,
                        ),
                      ...effectiveVisibleTags.map(
                        (tag) => buildOptionTile(
                          value: 'tag::$tag',
                          label: tag,
                          countText: '${tagBookCount[tag] ?? 0}',
                          selected: _activeView.isTag && _activeView.tag == tag,
                          icon: Icons.sell_outlined,
                        ),
                      ),
                      if (searchKeyword.trim().isEmpty &&
                          visibleTags.length > 6)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setSheetState(() {
                                  expandTags = !expandTags;
                                });
                              },
                              icon: Icon(
                                expandTags
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                              ),
                              label: Text(expandTags ? '收起标签' : '展开全部标签'),
                            ),
                          ),
                        ),
                    ],
                  ],
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
