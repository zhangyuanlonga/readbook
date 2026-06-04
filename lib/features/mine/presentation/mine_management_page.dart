import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/platform/app_input_focus_behavior.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/app_status_state_card.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../application/advanced_theme_provider.dart';

enum MineManagementSection { tagManagement, categoryManagement }

class MineManagementPage extends StatelessWidget {
  const MineManagementPage({
    super.key,
    required this.section,
    this.bookshelfService,
    this.loadTimeout = const Duration(seconds: 8),
  });

  final MineManagementSection section;
  final BookshelfService? bookshelfService;
  final Duration loadTimeout;

  @override
  Widget build(BuildContext context) {
    if (section == MineManagementSection.tagManagement) {
      return _BookshelfTaxonomyManagementPage(
        kind: _BookshelfTaxonomyKind.tag,
        bookshelfService: bookshelfService,
        loadTimeout: loadTimeout,
      );
    }
    if (section == MineManagementSection.categoryManagement) {
      return _BookshelfTaxonomyManagementPage(
        kind: _BookshelfTaxonomyKind.category,
        bookshelfService: bookshelfService,
        loadTimeout: loadTimeout,
      );
    }
    return const SizedBox.shrink();
  }
}

enum _BookshelfTaxonomyKind { tag, category }

class _BookshelfTaxonomyItem {
  const _BookshelfTaxonomyItem({
    required this.name,
    required this.count,
    required this.colorValue,
  });

  final String name;
  final int count;
  final int colorValue;
}

class _BookshelfTaxonomyManagementPage extends ConsumerStatefulWidget {
  const _BookshelfTaxonomyManagementPage({
    required this.kind,
    this.bookshelfService,
    required this.loadTimeout,
  });

  final _BookshelfTaxonomyKind kind;
  final BookshelfService? bookshelfService;
  final Duration loadTimeout;

  @override
  ConsumerState<_BookshelfTaxonomyManagementPage> createState() =>
      _BookshelfTaxonomyManagementPageState();
}

class _BookshelfTaxonomyManagementPageState
    extends ConsumerState<_BookshelfTaxonomyManagementPage> {
  late final BookshelfService _bookshelfService;
  final TextEditingController _searchController = TextEditingController();
  List<_BookshelfTaxonomyItem> _items = const <_BookshelfTaxonomyItem>[];
  List<_BookshelfTaxonomyItem> _filteredItems =
      const <_BookshelfTaxonomyItem>[];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadErrorText;
  String _searchKeyword = '';

  bool get _isTag => widget.kind == _BookshelfTaxonomyKind.tag;

  String get _title => _isTag ? '标签管理' : '分类管理';

  IconData get _icon =>
      _isTag ? Icons.sell_outlined : Icons.folder_copy_outlined;

  String get _entityName => _isTag ? '标签' : '分类';

  @override
  void initState() {
    super.initState();
    _bookshelfService = widget.bookshelfService ?? BookshelfService();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _BookshelfTaxonomyManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _load();
    }
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadErrorText = null;
      });
    }

    try {
      final items = await _loadItems().timeout(widget.loadTimeout);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _filteredItems = _applyFilter(items);
        _isLoading = false;
        _loadErrorText = null;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorText = '$_entityName加载超时，请点击重试。';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorText = '$_entityName列表加载失败，请点击重试。';
      });
    }
  }

  List<_BookshelfTaxonomyItem> _applyFilter(
    List<_BookshelfTaxonomyItem> items,
  ) {
    if (_searchKeyword.isEmpty) {
      return items;
    }
    final keyword = _searchKeyword.toLowerCase();
    return items
        .where((item) => item.name.toLowerCase().contains(keyword))
        .toList();
  }

  Future<List<_BookshelfTaxonomyItem>> _loadItems() async {
    if (_isTag) {
      final tagMap = await _bookshelfService.getTagMap().timeout(
        widget.loadTimeout,
        onTimeout: () => const {},
      );
      final tagOrder = await _bookshelfService.getTagOrder().timeout(
        widget.loadTimeout,
        onTimeout: () => const [],
      );
      final tagItems = await _bookshelfService.getTagItems().timeout(
        widget.loadTimeout,
        onTimeout: () => const <BookshelfTaxonomyItem>[],
      );
      final counts = <String, int>{};
      for (final tags in tagMap.values) {
        for (final tag in tags) {
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }
      return _mergeOrderedItems(
        counts: counts,
        order: tagOrder,
        metadataItems: tagItems,
      );
    }

    final categoryMap = await _bookshelfService.getCategoryMap().timeout(
      widget.loadTimeout,
      onTimeout: () => const {},
    );
    final categoryOrder = await _bookshelfService.getCategoryOrder().timeout(
      widget.loadTimeout,
      onTimeout: () => const [],
    );
    final categoryItems = await _bookshelfService.getCategoryItems().timeout(
      widget.loadTimeout,
      onTimeout: () => const <BookshelfTaxonomyItem>[],
    );
    final counts = <String, int>{};
    for (final category in categoryMap.values) {
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return _mergeOrderedItems(
      counts: counts,
      order: categoryOrder,
      metadataItems: categoryItems,
    );
  }

  List<_BookshelfTaxonomyItem> _mergeOrderedItems({
    required Map<String, int> counts,
    required List<String> order,
    required List<BookshelfTaxonomyItem> metadataItems,
  }) {
    final names = <String>[];
    for (final item in metadataItems) {
      if (item.name.isNotEmpty && !names.contains(item.name)) {
        names.add(item.name);
      }
    }
    for (final item in order) {
      if (!names.contains(item)) {
        names.add(item);
      }
    }
    final remaining = counts.keys
        .where((item) => !names.contains(item))
        .toList(growable: false);
    remaining.sort((a, b) {
      final countCompare = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.compareTo(b);
    });

    final colorMap = <String, int>{
      for (final item in metadataItems) item.name: item.colorValue,
    };

    return <_BookshelfTaxonomyItem>[
      for (final name in [...names, ...remaining])
        _BookshelfTaxonomyItem(
          name: name,
          count: counts[name] ?? 0,
          colorValue:
              colorMap[name] ?? BookshelfTaxonomyItem.defaultColorForName(name),
        ),
    ];
  }

  Future<void> _persistOrder(List<String> newOrder) async {
    if (_isTag) {
      await _bookshelfService.saveTagOrder(newOrder);
    } else {
      await _bookshelfService.saveCategoryOrder(newOrder);
    }
  }

  Future<void> _renameItem(_BookshelfTaxonomyItem item) async {
    await _openTaxonomyEditor(item);
  }

  Future<void> _deleteItem(_BookshelfTaxonomyItem item) async {
    final confirmed = await _showDeleteConfirmDialog(item);
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      if (_isTag) {
        await _bookshelfService.deleteTag(item.name);
      } else {
        await _bookshelfService.deleteCategory(item.name);
      }
      await _load();
      _showMessage('已删除$_entityName ${item.name}。');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool?> _showDeleteConfirmDialog(_BookshelfTaxonomyItem item) async {
    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '删除$_entityName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.count > 0
                    ? '删除「${item.name}」会从 ${item.count} 本书中移除，确定删除吗？'
                    : '确定删除「${item.name}」吗？',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                      child: const Text('删除'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTaxonomyEditor([_BookshelfTaxonomyItem? item]) async {
    if (_isSaving) {
      return;
    }
    final isNew = item == null;
    final initialName = item?.name ?? '';
    final initialColorValue =
        item?.colorValue ??
        BookshelfTaxonomyItem.defaultColorForName('新$_entityName');
    final existingNames = _items.map((entry) => entry.name).toSet();
    final result = await showModalBottomSheet<_TaxonomyEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (surfaceContext) {
        return _TaxonomyEditorPanel(
          entityName: _entityName,
          isNew: isNew,
          initialName: initialName,
          initialColorValue: initialColorValue,
          existingNames: existingNames,
        );
      },
    );
    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      if (result.delete && item != null) {
        final confirmed = await _showDeleteConfirmDialog(item);
        if (confirmed == true) {
          if (_isTag) {
            await _bookshelfService.deleteTag(item.name);
          } else {
            await _bookshelfService.deleteCategory(item.name);
          }
          await _load();
          _showMessage('已删除$_entityName ${item.name}。');
        }
        return;
      }
      final nextName = result.name.trim();
      if (nextName.isEmpty) {
        return;
      }
      if (item != null && nextName != item.name) {
        if (_isTag) {
          await _bookshelfService.renameTag(
            fromTag: item.name,
            toTag: nextName,
          );
        } else {
          await _bookshelfService.renameCategory(
            fromCategory: item.name,
            toCategory: nextName,
          );
        }
      }
      if (_isTag) {
        await _bookshelfService.upsertTagItem(
          name: nextName,
          colorValue: result.colorValue,
        );
      } else {
        await _bookshelfService.upsertCategoryItem(
          name: nextName,
          colorValue: result.colorValue,
        );
      }
      if (isNew) {
        final newOrder = [..._items.map((entry) => entry.name), nextName];
        await _persistOrder(newOrder);
      } else {
        await _load();
      }
      await _load();
      _showMessage(isNew ? '已新增$_entityName $nextName。' : '$_entityName已保存。');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final hasItems = _filteredItems.isNotEmpty;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(_title),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          actions: [
            // 新增按钮
            IconButton(
              tooltip: '新增$_entityName',
              onPressed:
                  _isSaving ? null : () => unawaited(_openTaxonomyEditor()),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
            );

            return DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              topInset + 12,
                              horizontal,
                              16 + bottomSafe,
                            ),
                            children: [
                              //   _buildTaxonomyHeroCard(context),
                              //   const SizedBox(height: 12),
                              if (_loadErrorText != null) ...[
                                _buildErrorCard(context),
                                if (hasItems) const SizedBox(height: 12),
                              ],
                              // 搜索框
                              if (_searchKeyword.isNotEmpty || hasItems)
                                _buildSearchBar(context),
                              if (_searchKeyword.isNotEmpty || hasItems)
                                const SizedBox(height: 12),
                              if (_loadErrorText == null || hasItems)
                                if (!hasItems)
                                  _buildEmptyCard(context)
                                else
                                  _buildListCard(context),
                              // 底部统计
                              if (hasItems) ...[
                                const SizedBox(height: 12),
                                _buildFooterStats(context),
                              ],
                            ],
                          ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search_rounded,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索$_entityName',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value;
                  _filteredItems = _applyFilter(_items);
                });
              },
            ),
          ),
          if (_searchKeyword.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18),
              onPressed: () {
                setState(() {
                  _searchKeyword = '';
                  _filteredItems = _applyFilter(_items);
                });
                _searchController.clear();
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildFooterStats(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalCount = _filteredItems.length;
    final totalBooks = _filteredItems.fold<int>(
      0,
      (sum, item) => sum + item.count,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '共 $totalCount 个$_entityName',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '关联 $totalBooks 本书',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    return AppEmptyStateCard(
      icon: _icon,
      title: '还没有$_entityName',
      description: '点击右上角新增即可。',
      compact: true,
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return AppStatusStateCard(
      icon: Icons.error_outline_rounded,
      title: '加载失败',
      message: _loadErrorText ?? '',
      tone: AppStatusStateTone.error,
      actionLabel: '重试',
      onAction: _isSaving ? null : () => unawaited(_load(showLoading: true)),
      compact: true,
    );
  }

  Widget _buildListCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayItems = _filteredItems;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem:
              _isSaving
                  ? (_, __) {}
                  : (oldIndex, newIndex) => unawaited(
                    _reorderFilteredItems(
                      displayItems: displayItems,
                      oldIndex: oldIndex,
                      newIndex: newIndex,
                    ),
                  ),
          proxyDecorator: (child, _, __) {
            return Material(
              elevation: 4,
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final item = displayItems[index];
            return Container(
              key: ValueKey(item.name),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border:
                    index < displayItems.length - 1
                        ? Border(
                          bottom: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        )
                        : null,
              ),
              child: _buildItemTile(
                context,
                item: item,
                color: Color(item.colorValue),
                dragIndex: index,
              ),
            );
          },
          itemCount: displayItems.length,
        ),
      ),
    );
  }

  Future<void> _reorderFilteredItems({
    required List<_BookshelfTaxonomyItem> displayItems,
    required int oldIndex,
    required int newIndex,
  }) async {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= displayItems.length ||
        newIndex < 0 ||
        newIndex > displayItems.length) {
      return;
    }

    final visibleNames = displayItems.map((item) => item.name).toList();
    final movedName = visibleNames[oldIndex];
    final visibleAfterMove = List<String>.from(visibleNames)
      ..removeAt(oldIndex);
    final beforeName =
        newIndex < visibleAfterMove.length ? visibleAfterMove[newIndex] : null;
    final afterName =
        beforeName == null && visibleAfterMove.isNotEmpty
            ? visibleAfterMove.last
            : null;

    final fullOrder = _items.map((item) => item.name).toList();
    fullOrder.remove(movedName);
    if (beforeName != null) {
      final insertAt = fullOrder.indexOf(beforeName);
      if (insertAt >= 0) {
        fullOrder.insert(insertAt, movedName);
      } else {
        fullOrder.add(movedName);
      }
    } else if (afterName != null) {
      final insertAfter = fullOrder.indexOf(afterName);
      if (insertAfter >= 0) {
        fullOrder.insert(insertAfter + 1, movedName);
      } else {
        fullOrder.add(movedName);
      }
    } else {
      fullOrder.add(movedName);
    }

    final itemByName = <String, _BookshelfTaxonomyItem>{
      for (final item in _items) item.name: item,
    };
    final localOrdered = fullOrder
        .map((name) => itemByName[name])
        .whereType<_BookshelfTaxonomyItem>()
        .toList(growable: false);
    if (localOrdered.length == _items.length) {
      setState(() {
        _items = localOrdered;
        _filteredItems = _applyFilter(localOrdered);
      });
    }

    try {
      await _persistOrder(fullOrder);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('排序保存失败，请重试。');
      await _load();
    }
  }

  Widget _buildItemTile(
    BuildContext context, {
    required _BookshelfTaxonomyItem item,
    required Color color,
    required int dragIndex,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.count} 本书',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '重命名',
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed:
                    _isSaving ? null : () => unawaited(_renameItem(item)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
              ),
              IconButton(
                tooltip: '删除',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: colorScheme.error,
                ),
                onPressed:
                    _isSaving ? null : () => unawaited(_deleteItem(item)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
              ),
              ReorderableDragStartListener(
                index: dragIndex,
                enabled: !_isSaving,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _FourDotReorderHandle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _FourDotReorderHandle extends StatelessWidget {
  const _FourDotReorderHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget dot() {
      return Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }

    return SizedBox(
      width: 16,
      height: 16,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [dot(), dot(), dot(), dot()],
      ),
    );
  }
}

class _TaxonomyEditResult {
  const _TaxonomyEditResult.save({required this.name, required this.colorValue})
    : delete = false;
  const _TaxonomyEditResult.delete() : name = '', colorValue = 0, delete = true;

  final String name;
  final int colorValue;
  final bool delete;
}

class _TaxonomyEditorPanel extends StatefulWidget {
  const _TaxonomyEditorPanel({
    required this.entityName,
    required this.isNew,
    required this.initialName,
    required this.initialColorValue,
    required this.existingNames,
  });

  final String entityName;
  final bool isNew;
  final String initialName;
  final int initialColorValue;
  final Set<String> existingNames;

  @override
  State<_TaxonomyEditorPanel> createState() => _TaxonomyEditorPanelState();
}

class _TaxonomyEditorPanelState extends State<_TaxonomyEditorPanel> {
  late final TextEditingController _nameController;
  late final TextEditingController _hexController;
  late Color _draftColor;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _draftColor = Color(widget.initialColorValue);
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
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      setState(() {
        _errorText = '请输入${widget.entityName}名称';
      });
      return;
    }
    if (value.length > 12) {
      setState(() {
        _errorText = '${widget.entityName}最多 12 个字';
      });
      return;
    }
    if (widget.existingNames.contains(value) && value != widget.initialName) {
      setState(() {
        _errorText = '该${widget.entityName}已存在';
      });
      return;
    }
    Navigator.of(context).pop(
      _TaxonomyEditResult.save(name: value, colorValue: _draftColor.toARGB32()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title =
        widget.isNew ? '新增${widget.entityName}' : '编辑${widget.entityName}';
    final insetBottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 16 + insetBottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
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
                    tooltip: '删除',
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop(const _TaxonomyEditResult.delete());
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                FilledButton.tonal(onPressed: _save, child: const Text('保存')),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              autofocus: appEnableAutoFocusForTextInput,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: '${widget.entityName}名称',
                errorText: _errorText,
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
            const SizedBox(height: 12),
            TextField(
              controller: _hexController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.palette_outlined, size: 18),
                hintText: '#RRGGBB / #AARRGGBB',
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                final parsed = _parseTaxonomyHexColor(value);
                if (parsed == null) {
                  return;
                }
                setState(() {
                  _draftColor = Color(parsed);
                });
              },
            ),
            const SizedBox(height: 12),
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
              colorPickerWidth: 340,
              pickerAreaHeightPercent: 0.58,
              pickerAreaBorderRadius: const BorderRadius.all(
                Radius.circular(12),
              ),
              labelTypes: const [],
              hexInputController: _hexController,
            ),
            const SizedBox(height: 8),
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
          ],
        ),
      ),
    );
  }
}

int? _parseTaxonomyHexColor(String value) {
  var normalized = value.trim().toUpperCase();
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized.startsWith('#')) {
    normalized = normalized.substring(1);
  }
  if (normalized.length == 6) {
    normalized = 'FF$normalized';
  }
  if (normalized.length != 8) {
    return null;
  }
  return int.tryParse(normalized, radix: 16);
}

String _formatTaxonomyHex(int colorValue) {
  final value = colorValue.toUnsigned(32).toRadixString(16).toUpperCase();
  return '#${value.padLeft(8, '0')}';
}
