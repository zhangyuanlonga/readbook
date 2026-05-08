part of 'book_detail_page.dart';

extension on _BookDetailPageState {
  Future<void> _handleShareAction() async {
    final detail = _result?.detail;
    final presentation = _resolvePresentedMetadata();
    final title =
        (presentation.displayTitle.isNotEmpty
                ? presentation.displayTitle
                : (detail?.title ?? _displayTitle ?? '书籍详情'))
            .trim();
    final author = (presentation.displayAuthor ?? detail?.author ?? '').trim();
    final detailUrl = (detail?.detailUrl ?? _activeDetailUrl ?? '').trim();
    final lines = <String>[
      if (title.isNotEmpty) title,
      if (author.isNotEmpty) '作者：$author',
      if (detailUrl.isNotEmpty &&
          !LocalReaderIdentity.isLocalSchemeUrl(detailUrl))
        detailUrl,
    ];
    final text = lines.join('\n');
    try {
      await Share.share(
        text,
        subject: title.isEmpty ? '书籍详情' : title,
        sharePositionOrigin: _resolveSharePositionOrigin(),
      );
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) {
        return;
      }
      _showMessage('当前环境暂不支持系统分享，已复制内容。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('分享失败：$error');
    }
  }

  Rect? _resolveSharePositionOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final size = renderObject.size;
    if (size.isEmpty) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & size;
  }

  Future<void> _showMoreActionsSheet() async {
    final detailResult = _result;
    final latestChapter =
        detailResult == null ? null : _resolveLatestChapter(detailResult);
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (detailResult != null &&
                  _canOpenCatalogForResult(detailResult))
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: const Text('查看目录'),
                  onTap: () => Navigator.of(context).pop('catalog'),
                ),
              if (detailResult != null &&
                  _buildOpenCacheAction(detailResult) != null)
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('缓存章节'),
                  onTap: () => Navigator.of(context).pop('cache'),
                ),
              if (detailResult != null && _auxiliaryState.isInBookshelf)
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('自定义封面'),
                  onTap: () => Navigator.of(context).pop('custom_cover'),
                ),
              if (latestChapter != null)
                ListTile(
                  leading: const Icon(Icons.new_releases_outlined),
                  title: const Text('最新章节'),
                  onTap: () => Navigator.of(context).pop('latest'),
                ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('刷新详情'),
                onTap: () => Navigator.of(context).pop('refresh'),
              ),
              if (detailResult != null)
                ListTile(
                  leading: Icon(
                    _manualTocReversed
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                  title: Text(_manualTocReversed ? '目录正序' : '目录倒序'),
                  onTap: () => Navigator.of(context).pop('reverse'),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case 'catalog':
        await _handleOpenCatalogAction();
        return;
      case 'cache':
        final cacheAction =
            detailResult == null ? null : _buildOpenCacheAction(detailResult);
        cacheAction?.call();
        return;
      case 'custom_cover':
        if (detailResult != null) {
          await _pickAndApplyCustomCover(detailResult);
        }
        return;
      case 'latest':
        if (latestChapter != null) {
          _openChapter(latestChapter);
        }
        return;
      case 'refresh':
        await _load(
          forceRefresh: true,
          includeCatalog: _result?.catalogLoaded ?? false,
        );
        return;
      case 'reverse':
        _updateDetailPageState(() {
          _manualTocReversed = !_manualTocReversed;
        });
        return;
    }
  }

  String _buildBookCoverHeroTag({
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) {
    return 'book_cover_${sourceId.trim()}_${bookId.trim()}_${detailUrl.hashCode}';
  }

  Widget _buildCoverPreview(
    String? coverUrl, {
    String? customCoverPath,
    required String title,
    String? author,
    required String heroTag,
    String? bookId,
    String? sourceId,
    String? detailUrl,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        ref.watch(activeAdvancedThemeProvider);
        ref.watch(coverGalleriesProvider);
        final resolvedCover = resolveBookCover(
          realCoverUrl: coverUrl,
          customCoverPath: customCoverPath ?? _localBookMeta?.coverPath,
          activeTheme: ref.read(activeAdvancedThemeProvider).valueOrNull,
          galleries: ref.read(coverGalleriesProvider).valueOrNull ?? const [],
          brightness: Theme.of(context).brightness,
          bookId: bookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
        );
        return Hero(
          tag: heroTag,
          child: ResolvedBookCoverView(
            cover: resolvedCover,
            title: title,
            author: author,
            width: 104,
            height: 148,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  Chapter? _resolveLatestChapter(BookDetailLoadResult result) {
    return _readRouteService.latestReadableChapter(result.chapters);
  }

  List<Chapter> _readableChapters(List<Chapter> chapters) {
    return _readRouteService.readableChapters(chapters);
  }

  bool _canOpenCatalogForResult(BookDetailLoadResult result) {
    return result.catalogAvailable || result.catalogLoaded;
  }

  String? _buildFallbackReadRoute(BookDetailLoadResult result) {
    final sourceId = (_activeSourceId ?? '').trim();
    final detailUrl = (_activeDetailUrl ?? '').trim();
    if (sourceId.isEmpty || detailUrl.isEmpty) {
      return null;
    }
    return _readRouteService.buildFallbackRoute(
      bookId: _activeBookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      fallbackTitle: result.detail.title,
    );
  }

  void _recordDetailBodyVisible({
    required BookDetailLoadResult result,
    required String source,
  }) {
    if (_hasLoggedDetailBodyVisible) {
      return;
    }
    _hasLoggedDetailBodyVisible = true;
    _logger.info(
      'Book detail body visible',
      context: <String, Object?>{
        'chain': 'book_detail',
        'step': 'body_visible',
        'bookId': result.detail.id,
        'sourceId': result.detail.sourceId,
        'detailUrl': result.detail.detailUrl,
        'catalogLoaded': result.catalogLoaded,
        'catalogAvailable': result.catalogAvailable,
        'tocFromCache': result.tocFromCache,
        'durationMs': _detailOpenStopwatch.elapsedMilliseconds,
        'source': source,
      },
    );
  }

  String? _resolveIntro(String? rawIntro) {
    if (rawIntro == null) {
      return null;
    }

    final intro = _normalizeText(rawIntro);
    return intro.isEmpty ? null : intro;
  }

  String _normalizeSingleLineText(String text) {
    return _normalizeText(
      text,
    ).replaceAll('\n', ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  VoidCallback? _buildOpenCacheAction(BookDetailLoadResult result) {
    final readableChapters = _readableChapters(result.chapters);
    final totalChapters = readableChapters.length;

    final sourceId = _activeSourceId;
    if (sourceId == null ||
        sourceId.isEmpty ||
        !_contentCapabilities.canCacheChapter ||
        totalChapters == 0) {
      return null;
    }

    return () {
      final startIndex = 0;
      final endIndex =
          totalChapters > 0 ? (startIndex + 49).clamp(0, totalChapters - 1) : 0;

      showChapterCacheFlow(
        context: context,
        bookId: _activeBookId,
        sourceId: sourceId,
        chapters: readableChapters,
        initialStartIndex: startIndex,
        initialEndIndex: endIndex,
        entryPoint: ChapterCacheEntryPoint.detail,
        bookTitle: result.detail.title,
      );
    };
  }

  Future<void> _openOrganizeSheet() async {
    if (!_isInBookshelf || _result == null) {
      _showMessage('请先加入书架后再归类。');
      return;
    }

    final detail = _result!.detail;
    final initialTagMap = await _bookshelfService.getTagMap();
    final initialTagOrder = await _bookshelfService.getTagOrder();
    final initialCategoryMap = await _bookshelfService.getCategoryMap();
    final initialCategoryOrder = await _bookshelfService.getCategoryOrder();
    final bookKey = '${detail.sourceId}::${detail.detailUrl}';

    var selectedTags = List<String>.from(
      initialTagMap[bookKey] ?? const <String>[],
    );
    var availableTags = <String>[
        ...initialTagOrder,
        ...initialTagMap.values.expand((items) => items),
        ...selectedTags,
      ].where((item) => item.trim().isNotEmpty).toSet().toList(growable: false)
      ..sort();

    var selectedCategory = initialCategoryMap[bookKey];
    var availableCategories = <String>[
        ...initialCategoryOrder,
        ...initialCategoryMap.values,
        if (selectedCategory?.trim().isNotEmpty ?? false) selectedCategory!,
      ].where((item) => item.trim().isNotEmpty).toSet().toList(growable: false)
      ..sort();

    var createTagDraft = '';
    var createCategoryDraft = '';
    String? tagErrorText;
    String? categoryErrorText;

    if (!mounted) {
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);

            void addTagInline() {
              final value = createTagDraft.trim();
              if (value.isEmpty) {
                setSheetState(() {
                  tagErrorText = '请输入标签名称';
                });
                return;
              }
              if (availableTags.contains(value)) {
                if (!selectedTags.contains(value)) {
                  setSheetState(() {
                    selectedTags = <String>[...selectedTags, value];
                    createTagDraft = '';
                    tagErrorText = null;
                  });
                }
                return;
              }
              setSheetState(() {
                availableTags = <String>[...availableTags, value]..sort();
                selectedTags = <String>[...selectedTags, value];
                createTagDraft = '';
                tagErrorText = null;
              });
            }

            void addCategoryInline() {
              final value = createCategoryDraft.trim();
              if (value.isEmpty) {
                setSheetState(() {
                  categoryErrorText = '请输入分类名称';
                });
                return;
              }
              if (!availableCategories.contains(value)) {
                setSheetState(() {
                  availableCategories = <String>[...availableCategories, value]
                    ..sort();
                });
              }
              setSheetState(() {
                selectedCategory = value;
                createCategoryDraft = '';
                categoryErrorText = null;
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '归类',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '分类',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('未分类'),
                          selected: selectedCategory == null,
                          onSelected: (_) {
                            setSheetState(() {
                              selectedCategory = null;
                            });
                          },
                        ),
                        ...availableCategories.map(
                          (category) => ChoiceChip(
                            label: Text(category),
                            selected: selectedCategory == category,
                            onSelected: (_) {
                              setSheetState(() {
                                selectedCategory = category;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        labelText: '新增分类',
                        errorText: categoryErrorText,
                        suffixIcon: IconButton(
                          onPressed: addCategoryInline,
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ),
                      onChanged: (value) {
                        createCategoryDraft = value;
                        if (categoryErrorText != null) {
                          setSheetState(() {
                            categoryErrorText = null;
                          });
                        }
                      },
                      onSubmitted: (_) => addCategoryInline(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '标签',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableTags
                          .map(
                            (tag) => FilterChip(
                              label: Text(tag),
                              selected: selectedTags.contains(tag),
                              onSelected: (selected) {
                                setSheetState(() {
                                  if (selected) {
                                    selectedTags = <String>[
                                      ...selectedTags,
                                      tag,
                                    ];
                                  } else {
                                    selectedTags = selectedTags
                                        .where((item) => item != tag)
                                        .toList(growable: false);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        labelText: '新增标签',
                        errorText: tagErrorText,
                        suffixIcon: IconButton(
                          onPressed: addTagInline,
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ),
                      onChanged: (value) {
                        createTagDraft = value;
                        if (tagErrorText != null) {
                          setSheetState(() {
                            tagErrorText = null;
                          });
                        }
                      },
                      onSubmitted: (_) => addTagInline(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true || !mounted) {
      return;
    }

    try {
      await _actionService.saveOrganization(
        detail: detail,
        category: selectedCategory,
        tags: selectedTags,
      );
      _showMessage('归类已保存。');
    } catch (_) {
      _showMessage('归类保存失败，请重试。');
    }
  }

  Future<void> _toggleBookshelf() async {
    final result = _result;
    if (result == null) {
      return;
    }

    final wasInBookshelf = _auxiliaryState.isInBookshelf;
    _updateAuxiliaryState(
      _auxiliaryState.copyWith(
        isShelfActionLoading: true,
        isInBookshelf: !wasInBookshelf,
      ),
    );

    try {
      final actionResult = await _actionService.toggleBookshelf(
        wasInBookshelf: wasInBookshelf,
        detail: result.detail,
        presentation: _resolvePresentedMetadata(result: result),
        latestChapterTitle: _resolveLatestChapter(result)?.title,
      );
      _updateAuxiliaryState(
        _auxiliaryState.copyWith(isInBookshelf: actionResult.isInBookshelf),
      );

      if (!mounted) {
        return;
      }

      _showMessage(actionResult.message);
    } catch (_) {
      if (mounted) {
        _updateAuxiliaryState(
          _auxiliaryState.copyWith(isInBookshelf: wasInBookshelf),
        );
      }
      _showMessage('操作失败，请重试。');
    } finally {
      if (mounted) {
        _updateAuxiliaryState(
          _auxiliaryState.copyWith(isShelfActionLoading: false),
        );
      }
    }
  }
}
