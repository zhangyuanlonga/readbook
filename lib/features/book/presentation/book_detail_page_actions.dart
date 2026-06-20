// UI-GOV-EXEMPT-FILE: list-children list-performance
// reason: Phase 10 reviewed book detail action strip; shrinkWrap is bounded by a short action section.

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
    final action = await showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 460,
      padding: EdgeInsets.zero,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (detailResult != null && _canOpenCatalogForResult(detailResult))
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

  Widget _buildCoverPreview(
    String? coverUrl, {
    String? customCoverPath,
    required String title,
    String? author,
    required String heroTag,
    String? bookId,
    String? sourceId,
    String? detailUrl,
    double? coverWidth,
    VoidCallback? onTap,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    final resolvedCoverWidth =
        coverWidth ?? (metrics.isCompactDensity ? 92.0 : 104.0);
    final coverHeight = resolvedCoverWidth * 1.42;
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
          key: ValueKey<String>('hero_${heroTag}_${resolvedCover.cacheKey}'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap:
                onTap ??
                () => _openCoverPreview(
                  cover: resolvedCover,
                  title: title,
                  author: author,
                ),
            child: ResolvedBookCoverView(
              key: ValueKey<String>(resolvedCover.cacheKey),
              cover: resolvedCover,
              title: title,
              author: author,
              width: resolvedCoverWidth,
              height: coverHeight,
              borderRadius: BorderRadius.circular(metrics.cardRadius),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCoverPreview({
    required ResolvedBookCover cover,
    required String title,
    String? author,
  }) async {
    await showAdaptiveFullscreenPreview<void>(
      context: context,
      helperText: '双指缩放，拖动查看细节',
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final previewMaxWidth = math.max(120.0, size.width - 32);
        final previewMaxHeight = math.max(180.0, size.height - 112);
        final coverWidth = math.min(previewMaxWidth, previewMaxHeight / 1.42);
        final coverHeight = coverWidth * 1.42;

        return ResolvedBookCoverView(
          cover: cover,
          title: title,
          author: author,
          width: coverWidth,
          height: coverHeight,
          borderRadius: BorderRadius.circular(18),
          fit: BoxFit.contain,
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
      heroTag: _BookDetailPageState._heroTags.readerCover(
        bookId: _activeBookId,
        sourceId: sourceId,
        detailUrl: detailUrl,
      ),
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
    final initialTagItems = await _bookshelfService.getTagItems();
    final initialCategoryMap = await _bookshelfService.getCategoryMap();
    final initialCategoryOrder = await _bookshelfService.getCategoryOrder();
    final initialCategoryItems = await _bookshelfService.getCategoryItems();
    final initialInReadingQueue = await _bookshelfService.isInReadingQueue(
      sourceId: detail.sourceId,
      detailUrl: detail.detailUrl,
    );
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

    var createTagColor = BookshelfTaxonomyItem.defaultColorForName('新标签');
    var createCategoryColor = BookshelfTaxonomyItem.defaultColorForName('新分类');
    var inReadingQueue = initialInReadingQueue;
    final tagColorByName = <String, int>{
      for (final item in initialTagItems) item.name: item.colorValue,
    };
    final categoryColorByName = <String, int>{
      for (final item in initialCategoryItems) item.name: item.colorValue,
    };
    String? tagErrorText;
    String? categoryErrorText;
    var tagSearchDraft = '';
    final tagSearchController = TextEditingController();
    void disposeAfterSurfaceExit(TextEditingController controller) {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 450),
          controller.dispose,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    bool? result;
    try {
      result = await showAdaptiveActionSurface<bool>(
        context: context,
        maxWidth: 640,
        maxHeightFactor: 0.92,
        padding: EdgeInsets.zero,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final theme = Theme.of(context);
              final compactTheme = theme.copyWith(
                visualDensity: VisualDensity.compact,
              );

              Widget buildSectionCard({
                required IconData icon,
                required String title,
                required Widget child,
                Widget? trailing,
              }) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (trailing != null) ...[const Spacer(), trailing],
                        ],
                      ),
                      const SizedBox(height: 8),
                      child,
                    ],
                  ),
                );
              }

              String formatHex(int colorValue) {
                final normalized = colorValue & 0xFFFFFFFF;
                return '#${normalized.toRadixString(16).padLeft(8, '0').toUpperCase()}';
              }

              int? parseHexColor(String raw) {
                var value = raw.trim();
                if (value.isEmpty) {
                  return null;
                }
                if (value.startsWith('#')) {
                  value = value.substring(1);
                }
                if (value.length == 6) {
                  value = 'FF$value';
                }
                if (value.length != 8) {
                  return null;
                }
                return int.tryParse(value, radix: 16);
              }

              Future<({String name, int colorValue})?> showManageTaxonomySheet({
                required bool isTag,
              }) async {
                final title = isTag ? '管理标签' : '管理分类';
                final nameLabel = isTag ? '标签名称' : '分类名称';
                final nameController = TextEditingController();
                var draftColor = isTag ? createTagColor : createCategoryColor;
                var errorText = isTag ? tagErrorText : categoryErrorText;
                final hexController = TextEditingController(
                  text: formatHex(draftColor),
                );
                final colorScheme = theme.colorScheme;
                final desktopLike = AppLayout.isDesktopLike(
                  context,
                  platform: theme.platform,
                );
                final panelRadius = BorderRadius.vertical(
                  top: const Radius.circular(28),
                  bottom: desktopLike ? const Radius.circular(28) : Radius.zero,
                );

                final created = await showAdaptiveRawSurface<
                  ({String name, int colorValue})
                >(
                  context: context,
                  showDragHandle: false,
                  mobileBackgroundColor: Colors.transparent,
                  builder: (dialogContext) {
                    return StatefulBuilder(
                      builder: (context, setDialogState) {
                        final compactDialogTheme = theme.copyWith(
                          visualDensity: VisualDensity.compact,
                        );

                        void updateDraftColor(int value) {
                          setDialogState(() {
                            draftColor = value;
                            hexController.text = formatHex(value);
                          });
                        }

                        return Theme(
                          data: compactDialogTheme,
                          child: Material(
                            color: colorScheme.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius: panelRadius,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                14,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!desktopLike) ...[
                                    const AdaptiveSheetDragHandle(),
                                    const SizedBox(height: 8),
                                  ],
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: () {
                                          final name =
                                              nameController.text.trim();
                                          if (name.isEmpty) {
                                            setDialogState(() {
                                              errorText = '请输入$nameLabel';
                                            });
                                            return;
                                          }
                                          Navigator.of(dialogContext).pop((
                                            name: name,
                                            colorValue: draftColor,
                                          ));
                                        },
                                        icon: const Icon(Icons.check_rounded),
                                        label: const Text('完成'),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 36),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: nameController,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixIcon: Icon(
                                        isTag
                                            ? Icons.sell_rounded
                                            : Icons.folder_rounded,
                                      ),
                                      labelText: nameLabel,
                                      hintText: isTag ? '例如：热血' : '例如：科幻',
                                      errorText: errorText,
                                    ),
                                    onChanged: (value) {
                                      if (errorText != null) {
                                        setDialogState(() {
                                          errorText = null;
                                        });
                                      }
                                    },
                                    onSubmitted: (_) {
                                      final name = nameController.text.trim();
                                      if (name.isEmpty) {
                                        setDialogState(() {
                                          errorText = '请输入$nameLabel';
                                        });
                                        return;
                                      }
                                      Navigator.of(dialogContext).pop((
                                        name: name,
                                        colorValue: draftColor,
                                      ));
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: hexController,
                                    keyboardType: TextInputType.text,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[#0-9a-fA-F]'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      final parsed = parseHexColor(value);
                                      if (parsed == null) {
                                        return;
                                      }
                                      setDialogState(() {
                                        draftColor = parsed;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixIcon: const Icon(
                                        Icons.tag_rounded,
                                        size: 18,
                                      ),
                                      hintText: '#RRGGBB / #AARRGGBB',
                                      filled: true,
                                      fillColor: colorScheme.surface.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ColorPicker(
                                    pickerColor: Color(draftColor),
                                    onColorChanged:
                                        (color) =>
                                            updateDraftColor(color.toARGB32()),
                                    enableAlpha: true,
                                    displayThumbColor: true,
                                    portraitOnly: true,
                                    paletteType: PaletteType.hsvWithHue,
                                    colorPickerWidth: 320,
                                    pickerAreaHeightPercent: 0.52,
                                    pickerAreaBorderRadius:
                                        const BorderRadius.all(
                                          Radius.circular(12),
                                        ),
                                    labelTypes: const [],
                                    hexInputController: hexController,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Color(draftColor),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: colorScheme.outline
                                                .withValues(alpha: 0.38),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          formatHex(draftColor),
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () =>
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop(),
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
                          ),
                        );
                      },
                    );
                  },
                );
                disposeAfterSurfaceExit(nameController);
                disposeAfterSurfaceExit(hexController);
                return created;
              }

              Widget buildCategoryChip(String category) {
                final selected = selectedCategory == category;
                final colorValue =
                    categoryColorByName[category] ??
                    BookshelfTaxonomyItem.defaultColorForName(category);
                final color = Color(colorValue);
                return ChoiceChip(
                  avatar: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color:
                        selected ? color : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(category),
                  selected: selected,
                  selectedColor: color.withValues(alpha: 0.16),
                  side: BorderSide(color: color.withValues(alpha: 0.35)),
                  onSelected: (_) {
                    setSheetState(() {
                      selectedCategory = category;
                    });
                  },
                );
              }

              Widget buildTagChip({
                required String label,
                required bool selected,
                required int colorValue,
                required ValueChanged<bool> onSelected,
              }) {
                final color = Color(colorValue);
                return FilterChip(
                  avatar: Icon(
                    selected ? Icons.check_rounded : Icons.sell_outlined,
                    size: 16,
                    color:
                        selected ? color : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(label),
                  selected: selected,
                  selectedColor: color.withValues(alpha: 0.16),
                  checkmarkColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                  onSelected: onSelected,
                );
              }

              Future<void> openManageCategory() async {
                final created = await showManageTaxonomySheet(isTag: false);
                if (created == null) {
                  return;
                }
                setSheetState(() {
                  categoryColorByName[created.name] = created.colorValue;
                  if (!availableCategories.contains(created.name)) {
                    availableCategories = <String>[
                      ...availableCategories,
                      created.name,
                    ]..sort();
                  }
                  selectedCategory = created.name;
                  createCategoryColor =
                      BookshelfTaxonomyItem.defaultColorForName('新分类');
                  categoryErrorText = null;
                });
              }

              Future<void> openManageTag() async {
                final created = await showManageTaxonomySheet(isTag: true);
                if (created == null) {
                  return;
                }
                setSheetState(() {
                  tagColorByName[created.name] = created.colorValue;
                  if (!availableTags.contains(created.name)) {
                    availableTags = <String>[...availableTags, created.name]
                      ..sort();
                  }
                  selectedTags = <String>{
                    ...selectedTags,
                    created.name,
                  }.toList(growable: false);
                  createTagColor = BookshelfTaxonomyItem.defaultColorForName(
                    '新标签',
                  );
                  tagErrorText = null;
                  tagSearchDraft = '';
                  tagSearchController.clear();
                });
              }

              final normalizedTagSearch = tagSearchDraft.trim().toLowerCase();
              final visibleTags =
                  normalizedTagSearch.isEmpty
                      ? availableTags
                      : availableTags
                          .where(
                            (tag) =>
                                tag.toLowerCase().contains(normalizedTagSearch),
                          )
                          .toList(growable: false);

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  10,
                  12,
                  12 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Theme(
                  data: compactTheme,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '编辑书籍整理信息',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    detail.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        buildSectionCard(
                          icon: Icons.playlist_add_check_rounded,
                          title: '书籍状态',
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: inReadingQueue,
                            onChanged: (value) {
                              setSheetState(() {
                                inReadingQueue = value;
                              });
                            },
                            title: const Text('加入待读清单'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        buildSectionCard(
                          icon: Icons.folder_rounded,
                          title: '分类（单选）',
                          trailing: TextButton.icon(
                            onPressed: () => unawaited(openManageCategory()),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('管理分类'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ChoiceChip(
                                    avatar: Icon(
                                      selectedCategory == null
                                          ? Icons.radio_button_checked_rounded
                                          : Icons
                                              .radio_button_unchecked_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('未分类'),
                                    selected: selectedCategory == null,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) {
                                      setSheetState(() {
                                        selectedCategory = null;
                                      });
                                    },
                                  ),
                                  ...availableCategories.map(buildCategoryChip),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        buildSectionCard(
                          icon: Icons.sell_rounded,
                          title: '标签（多选）',
                          trailing: TextButton.icon(
                            onPressed: () => unawaited(openManageTag()),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('管理标签'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: tagSearchController,
                                decoration: InputDecoration(
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  labelText: '搜索标签',
                                  errorText: tagErrorText,
                                  suffixIcon:
                                      tagSearchDraft.trim().isEmpty
                                          ? null
                                          : IconButton(
                                            tooltip: '清除搜索',
                                            onPressed: () {
                                              setSheetState(() {
                                                tagSearchDraft = '';
                                                tagSearchController.clear();
                                                tagErrorText = null;
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.close_rounded,
                                            ),
                                          ),
                                ),
                                onChanged: (value) {
                                  setSheetState(() {
                                    tagSearchDraft = value;
                                    if (tagErrorText != null) {
                                      tagErrorText = null;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  FilterChip(
                                    avatar: Icon(
                                      selectedTags.isEmpty
                                          ? Icons.check_rounded
                                          : Icons.sell_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('未打标签'),
                                    selected: selectedTags.isEmpty,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) {
                                      setSheetState(() {
                                        selectedTags = const <String>[];
                                      });
                                    },
                                  ),
                                  ...visibleTags.map(
                                    (tag) => buildTagChip(
                                      label: tag,
                                      selected: selectedTags.contains(tag),
                                      colorValue:
                                          tagColorByName[tag] ??
                                          BookshelfTaxonomyItem.defaultColorForName(
                                            tag,
                                          ),
                                      onSelected: (selected) {
                                        setSheetState(() {
                                          if (selected) {
                                            selectedTags = <String>{
                                              ...selectedTags,
                                              tag,
                                            }.toList(growable: false);
                                          } else {
                                            selectedTags = selectedTags
                                                .where((item) => item != tag)
                                                .toList(growable: false);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (visibleTags.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  normalizedTagSearch.isEmpty
                                      ? '暂无标签，点击右上角管理标签可新建。'
                                      : '没有匹配标签，点击右上角管理标签可新建。',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 38),
                                ),
                                child: const Text('取消'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    () => Navigator.of(context).pop(true),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('保存'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 38),
                                ),
                              ),
                            ),
                          ],
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
    } finally {
      disposeAfterSurfaceExit(tagSearchController);
    }

    if (result != true || !mounted) {
      return;
    }

    try {
      await _actionService.saveOrganization(
        detail: detail,
        category: selectedCategory,
        tags: selectedTags,
        inReadingQueue: inReadingQueue,
      );
      for (final entry in tagColorByName.entries) {
        await _bookshelfService.upsertTagItem(
          name: entry.key,
          colorValue: entry.value,
        );
      }
      for (final entry in categoryColorByName.entries) {
        await _bookshelfService.upsertCategoryItem(
          name: entry.key,
          colorValue: entry.value,
        );
      }
      await _loadDetailOrganizationSnapshot(
        sourceId: detail.sourceId,
        detailUrl: detail.detailUrl,
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
