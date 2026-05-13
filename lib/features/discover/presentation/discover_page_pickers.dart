part of 'discover_page.dart';

class _SourcePickerSheet extends ConsumerStatefulWidget {
  const _SourcePickerSheet({
    required this.sources,
    required this.selectedSourceId,
    required this.healthBySourceId,
  });

  final List<DiscoverSource> sources;
  final String? selectedSourceId;
  final Map<String, SourceHealthSnapshot> healthBySourceId;

  @override
  ConsumerState<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends ConsumerState<_SourcePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  _SourceTypeFilter _sourceTypeFilter = _SourceTypeFilter.all;

  List<DiscoverSource> get _filteredSources {
    final keyword = _searchController.text.trim().toLowerCase();
    final result = widget.sources
        .where((source) {
          if (!_matchesSourceTypeFilter(source)) {
            return false;
          }
          if (keyword.isEmpty) {
            return true;
          }
          final name = source.name.toLowerCase();
          final baseUrl = source.baseUrl.toLowerCase();
          final host = _extractHost(source.baseUrl).toLowerCase();
          return name.contains(keyword) ||
              baseUrl.contains(keyword) ||
              host.contains(keyword);
        })
        .toList(growable: true);

    result.sort((left, right) {
      final leftStatus = _resolveSourceRuntimeStatus(
        snapshot: widget.healthBySourceId[left.id],
      );
      final rightStatus = _resolveSourceRuntimeStatus(
        snapshot: widget.healthBySourceId[right.id],
      );
      final statusCompare = _sourceStatusRank(
        leftStatus,
      ).compareTo(_sourceStatusRank(rightStatus));
      if (statusCompare != 0) {
        return statusCompare;
      }
      return left.name.compareTo(right.name);
    });

    return result;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSources = _filteredSources;
    final allCount = widget.sources.length;
    final novelCount = _countByType(_SourceTypeFilter.novel);
    final mangaCount = _countByType(_SourceTypeFilter.manga);
    final unknownCount = _countByType(_SourceTypeFilter.unknown);
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final heightFactor = AppLayout.sheetHeightFactor(
      context,
      compact: 0.92,
      regular: 0.9,
      large: 0.85,
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * heightFactor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          metrics.contentGap * 0.4,
          horizontal,
          metrics.sectionGap,
        ),
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '切换发现书源',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '共 ${widget.sources.length} 个发现书源',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索书源名称或域名',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _buildTypeFilterChip(
                  key: const Key('discover_source_filter_all'),
                  filter: _SourceTypeFilter.all,
                  label: '全部',
                  count: allCount,
                ),
                _buildTypeFilterChip(
                  key: const Key('discover_source_filter_novel'),
                  filter: _SourceTypeFilter.novel,
                  label: '小说',
                  count: novelCount,
                ),
                _buildTypeFilterChip(
                  key: const Key('discover_source_filter_manga'),
                  filter: _SourceTypeFilter.manga,
                  label: '漫画',
                  count: mangaCount,
                ),
                _buildTypeFilterChip(
                  key: const Key('discover_source_filter_unknown'),
                  filter: _SourceTypeFilter.unknown,
                  label: '未知',
                  count: unknownCount,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  filteredSources.isEmpty
                      ? Center(
                        child: Text(
                          '没有匹配的书源',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                      : ListView.separated(
                        itemCount: filteredSources.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final source = filteredSources[index];
                          final selected = source.id == widget.selectedSourceId;
                          final status = _resolveSourceRuntimeStatus(
                            snapshot: widget.healthBySourceId[source.id],
                          );
                          final statusColor = _sourceStatusColor(
                            context,
                            status,
                          );
                          final colorScheme = Theme.of(context).colorScheme;
                          final palette = resolveAdvancedThemePalette(
                            colorScheme,
                            ref.read(activeAdvancedThemeProvider).valueOrNull,
                          );
                          final summary = _buildSourceSummary(source);
                          final statusHint = _buildSourceStatusHint(status);

                          return Material(
                            color:
                                selected
                                    ? palette.primaryContainerColor.withValues(
                                      alpha: 0.42,
                                    )
                                    : palette.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.of(context).pop(source),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: Text(
                                                  source.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                              if (selected) ...[
                                                const SizedBox(width: 8),
                                                _DiscoverSourceTag(
                                                  label: '当前源',
                                                  background:
                                                      palette.primaryColor,
                                                  foreground:
                                                      palette.buttonTextColor,
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: <Widget>[
                                              _buildSourceTypePill(
                                                context,
                                                source,
                                              ),
                                              _DiscoverSourceStatusTag(
                                                label: _sourceStatusLabel(
                                                  status,
                                                ),
                                                color: statusColor,
                                                icon: _sourceStatusIcon(status),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            statusHint,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.copyWith(
                                              color: statusColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            summary,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.chevron_right_rounded,
                                      color:
                                          selected
                                              ? palette.primaryColor
                                              : colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilterChip({
    required Key key,
    required _SourceTypeFilter filter,
    required String label,
    required int count,
  }) {
    return ChoiceChip(
      key: key,
      label: Text('$label ($count)'),
      selected: _sourceTypeFilter == filter,
      onSelected: (_) {
        setState(() {
          _sourceTypeFilter = filter;
        });
      },
    );
  }

  Widget _buildSourceTypePill(BuildContext context, DiscoverSource source) {
    final typeColor = _sourceTypeColor(context, source);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          _sourceTypeLabel(source),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: typeColor),
        ),
      ),
    );
  }

  bool _matchesSourceTypeFilter(DiscoverSource source) {
    switch (_sourceTypeFilter) {
      case _SourceTypeFilter.all:
        return true;
      case _SourceTypeFilter.novel:
        return _isNovelSource(source);
      case _SourceTypeFilter.manga:
        return _isMangaSource(source);
      case _SourceTypeFilter.unknown:
        return _isUnknownSource(source);
    }
  }

  int _countByType(_SourceTypeFilter filter) {
    return widget.sources.where((source) {
      switch (filter) {
        case _SourceTypeFilter.all:
          return true;
        case _SourceTypeFilter.novel:
          return _isNovelSource(source);
        case _SourceTypeFilter.manga:
          return _isMangaSource(source);
        case _SourceTypeFilter.unknown:
          return _isUnknownSource(source);
      }
    }).length;
  }

  bool _isNovelSource(DiscoverSource source) {
    return source.sourceType == 0 && !source.isMangaSource;
  }

  bool _isMangaSource(DiscoverSource source) {
    return source.isMangaSource;
  }

  bool _isUnknownSource(DiscoverSource source) {
    return !_isNovelSource(source) && !_isMangaSource(source);
  }

  String _sourceTypeLabel(DiscoverSource source) {
    if (_isMangaSource(source)) {
      return '漫画';
    }
    if (_isNovelSource(source)) {
      return '小说';
    }
    return '未知';
  }

  Color _sourceTypeColor(BuildContext context, DiscoverSource source) {
    final scheme = Theme.of(context).colorScheme;
    if (_isMangaSource(source)) {
      return scheme.tertiary;
    }
    if (_isNovelSource(source)) {
      return scheme.primary;
    }
    return scheme.onSurfaceVariant;
  }

  String _buildSourceSummary(DiscoverSource source) {
    final host = _extractHost(source.baseUrl);
    final group = source.group?.trim();
    if (group == null || group.isEmpty) {
      return host;
    }
    return '$group · $host';
  }

  String _buildSourceStatusHint(_SourceRuntimeStatus status) {
    return switch (status) {
      _SourceRuntimeStatus.ready => '发现能力可用，适合直接切换',
      _SourceRuntimeStatus.checking => '正在验证分类与书籍列表',
      _SourceRuntimeStatus.requestFailed => '最近访问失败，切换后可能需要重试',
      _SourceRuntimeStatus.parseFailed => '书源结构异常，切换后可能不稳定',
      _SourceRuntimeStatus.unknown => '尚未验证，建议切换后观察',
    };
  }

  String _extractHost(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    return host.isEmpty ? url : host;
  }
}

class _DiscoverSourceTag extends StatelessWidget {
  const _DiscoverSourceTag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DiscoverSourceStatusTag extends StatelessWidget {
  const _DiscoverSourceStatusTag({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedIndex,
  });

  final List<ExploreCategoryItem> categories;
  final int selectedIndex;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchController.text.trim();
    final lowerKeyword = keyword.toLowerCase();
    final indexed = widget.categories
        .asMap()
        .entries
        .where((entry) {
          if (!entry.value.isActionable) {
            return false;
          }
          if (lowerKeyword.isEmpty) {
            return true;
          }
          return entry.value.title.toLowerCase().contains(lowerKeyword);
        })
        .toList(growable: false);

    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final heightFactor = AppLayout.sheetHeightFactor(
      context,
      compact: 0.92,
      regular: 0.9,
      large: 0.85,
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * heightFactor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          metrics.contentGap * 0.4,
          horizontal,
          metrics.sectionGap,
        ),
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '选择分类',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '共 ${indexed.length} 个可用分类',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索分类',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  indexed.isEmpty
                      ? Center(
                        child: Text(
                          '没有匹配的分类',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                      : ListView.separated(
                        itemCount: indexed.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, row) {
                          final index = indexed[row].key;
                          final item = indexed[row].value;
                          final selected = index == widget.selectedIndex;

                          return ListTile(
                            onTap: () => Navigator.of(context).pop(index),
                            selected: selected,
                            selectedTileColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.5),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  selected
                                      ? Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      )
                                      : null,
                            ),
                            trailing:
                                selected
                                    ? Icon(
                                      Icons.check_circle_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    )
                                    : null,
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
