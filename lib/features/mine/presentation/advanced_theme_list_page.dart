import 'dart:async';
import 'dart:io';

import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/tasks/app_task_manager.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_border_tokens.dart';
import '../../../app/theme/app_official_theme_presets.dart';
import '../../../app/composition/app_providers.dart' as app_providers;
import '../../../app/widgets/app_task_status.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../app/widgets/adaptive_route_top_bar.dart';
import '../../../app/widgets/app_task_bottom_sheet.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../../../app/widgets/import_export_task_sheet.dart';
import '../../../app/widgets/import_export_copy.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../application/advanced_theme_access_controller.dart';
import '../application/advanced_theme_export_error_formatter.dart';
import '../application/advanced_theme_list_page_state.dart';
import '../application/advanced_theme_list_query_controller.dart';
import '../application/advanced_theme_service.dart';
import '../../source/application/external_import_diagnostics.dart';
import '../../source/application/external_import_catalog.dart';
import '../../source/application/external_source_import_bridge.dart';
import '../application/advanced_theme_page_flow_coordinator.dart';
import '../application/advanced_theme_provider.dart';
import '../providers.dart';
import 'advanced_theme_batch_action_controller.dart';
import 'advanced_theme_batch_import_controller.dart';
import 'advanced_theme_delete_decision_surface.dart';
import 'advanced_theme_export_controller.dart';
import 'advanced_theme_import_controller.dart';
import 'advanced_theme_list_actions.dart';
import 'advanced_theme_preview_image_cache.dart';
import 'widgets/advanced_theme_list_status_widgets.dart';
import 'widgets/advanced_theme_list_toolbar.dart';
import 'widgets/advanced_theme_summary_card.dart';

class AdvancedThemeListPage extends ConsumerStatefulWidget {
  const AdvancedThemeListPage({super.key});

  @override
  ConsumerState<AdvancedThemeListPage> createState() =>
      _AdvancedThemeListPageState();
}

typedef _AdvancedThemeAction = AdvancedThemeAction;

typedef _AdvancedThemeListMoreAction = AdvancedThemeListMoreAction;

typedef _AdvancedThemeSortMode = AdvancedThemeSortMode;

typedef _AdvancedThemeExportDispatchResult = AdvancedThemeExportDispatchResult;

typedef _AdvancedThemeBatchImportSummary = AdvancedThemeBatchImportSummary;

typedef _AdvancedThemeImportQueueItemStatus =
    AdvancedThemeImportQueueItemStatus;

enum _AdvancedThemeSingleTaskMode { prepare, processing, completed }

typedef _AdvancedThemeImportQueueItem = AdvancedThemeImportQueueItem;

typedef _AdvancedThemeBatchImportProgressCallback =
    AdvancedThemeQueueImportProgressCallback;

typedef _AdvancedThemeBatchFileImportRunner =
    AdvancedThemeBatchFileImportRunner;

class _AdvancedThemeListEntry {
  const _AdvancedThemeListEntry.official(this.officialPreset, this.order)
    : customTheme = null;

  const _AdvancedThemeListEntry.custom(this.customTheme, this.order)
    : officialPreset = null;

  final AppOfficialThemePreset? officialPreset;
  final AdvancedThemeSummary? customTheme;
  final int order;

  bool get isOfficial => officialPreset != null;

  String get themeId => officialPreset?.id.themeId ?? customTheme!.id;
}

/// 高级主题列表页拆分索引：
/// actions / delete decision 在 `advanced_theme_list_actions.dart`；
/// 查询、排序、筛选和选择裁剪在 `AdvancedThemeListQueryController`；
/// 会员权限刷新在 `AdvancedThemeAccessController`；
/// 主题卡片、状态展示和搜索筛选工具条分别在 widgets 目录的 list 专用组件中。
/// 导入导出队列和单任务 surface 仍留在本文件，后续按 `U5-ATL-08+` 继续拆分。
class _AdvancedThemeListPageState extends ConsumerState<AdvancedThemeListPage> {
  late final AdvancedThemeAccessController _accessController;
  late final AdvancedThemePageFlowCoordinator _pageFlowCoordinator;
  final AdvancedThemeBatchActionController _batchActionController =
      const AdvancedThemeBatchActionController();
  final AdvancedThemeBatchImportController _batchImportController =
      const AdvancedThemeBatchImportController();
  final AdvancedThemeExportController _exportController =
      const AdvancedThemeExportController();
  final AdvancedThemeImportController _importController =
      const AdvancedThemeImportController();
  final AdvancedThemeListQueryController _queryController =
      const AdvancedThemeListQueryController();
  final TextEditingController _searchController = TextEditingController();
  final AdvancedThemePreviewImageCache _previewImageCache =
      AdvancedThemePreviewImageCache.shared;

  AdvancedThemeListPageState get _pageState =>
      ref.read(advancedThemeListPageStateProvider);

  AdvancedThemeListPageStateNotifier get _pageStateNotifier =>
      ref.read(advancedThemeListPageStateProvider.notifier);

  List<AdvancedThemeSummary> get _themeSummaries => _pageState.themeSummaries;
  set _themeSummaries(List<AdvancedThemeSummary> value) {
    _pageStateNotifier.update((state) => state.copyWith(themeSummaries: value));
  }

  String get _searchQuery => _pageState.searchQuery;
  set _searchQuery(String value) {
    _pageStateNotifier.update((state) => state.copyWith(searchQuery: value));
  }

  String? get _selectedCategory => _pageState.selectedCategory;
  set _selectedCategory(String? value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(selectedCategory: value),
    );
  }

  Set<String> get _selectedThemeIds => _pageState.selectedThemeIds;
  set _selectedThemeIds(Set<String> value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(selectedThemeIds: value),
    );
  }

  bool get _isLoading => _pageState.isLoading;
  set _isLoading(bool value) {
    _pageStateNotifier.update((state) => state.copyWith(isLoading: value));
  }

  bool get _isSaving => _pageState.isSaving;
  set _isSaving(bool value) {
    _pageStateNotifier.update((state) => state.copyWith(isSaving: value));
  }

  bool get _isConsumingExternalImportPayloads =>
      _pageState.isConsumingExternalImportPayloads;
  set _isConsumingExternalImportPayloads(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(isConsumingExternalImportPayloads: value),
    );
  }

  bool get _isAccessLoading => _pageState.isAccessLoading;
  set _isAccessLoading(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(isAccessLoading: value),
    );
  }

  bool get _canUseAdvancedThemes => _pageState.canUseAdvancedThemes;
  set _canUseAdvancedThemes(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(canUseAdvancedThemes: value),
    );
  }

  bool get _isSelectionMode => _pageState.isSelectionMode;
  set _isSelectionMode(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(isSelectionMode: value),
    );
  }

  bool get _floatingEditEnabled => _pageState.floatingEditEnabled;
  set _floatingEditEnabled(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(floatingEditEnabled: value),
    );
  }

  _AdvancedThemeSortMode get _themeSortMode => _pageState.themeSortMode;
  set _themeSortMode(_AdvancedThemeSortMode value) {
    _pageStateNotifier.update((state) => state.copyWith(themeSortMode: value));
  }

  String? get _savingStatusText => _pageState.savingStatusText;
  set _savingStatusText(String? value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(savingStatusText: value),
    );
  }

  int get _summaryLoadToken => _pageState.summaryLoadToken;
  set _summaryLoadToken(int value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(summaryLoadToken: value),
    );
  }

  @override
  void initState() {
    super.initState();
    _accessController = AdvancedThemeAccessController(
      membershipAccessService: ref.read(
        app_providers.appMembershipAccessServiceProvider,
      ),
    );
    _pageFlowCoordinator =
        ref.read(advancedThemePageFlowCoordinatorFactoryProvider)();
    _pageFlowCoordinator.initialize(
      onPendingImportAvailable: () {
        unawaited(_consumePendingExternalImportPayloads());
      },
      onAuthEvent: _handleAuthEvent,
    );
    _loadAccess(refreshRemote: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_load());
      unawaited(_consumePendingExternalImportPayloads());
    });
  }

  Future<void> _loadAccess({required bool refreshRemote}) async {
    final result = await _accessController.load(refreshRemote: refreshRemote);
    if (!mounted) {
      return;
    }
    if (result.shouldRefreshRemote) {
      setState(() {
        _isAccessLoading = true;
      });
      unawaited(_loadAccess(refreshRemote: true));
      return;
    }
    final currentActiveThemeId = ref.read(activeAdvancedThemeIdProvider);
    final shouldClearActiveTheme =
        result.shouldClearActiveTheme &&
        (currentActiveThemeId?.trim().isNotEmpty ?? false) &&
        !isOfficialThemeId(currentActiveThemeId);
    if (shouldClearActiveTheme) {
      await ref.read(activeAdvancedThemeIdProvider.notifier).disable();
      if (!mounted) {
        return;
      }
    }
    setState(() {
      _canUseAdvancedThemes = result.canUseAdvancedThemes;
      _isAccessLoading = result.isAccessLoading;
    });
    if (shouldClearActiveTheme) {
      _showMessage('会员权益已失效，已恢复默认主题');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _previewImageCache.clear();
    unawaited(_pageFlowCoordinator.dispose());
    super.dispose();
  }

  void _handleAuthEvent(AuthEvent event) {
    final refreshRemote = _accessController.shouldRefreshForAuthEvent(event);
    unawaited(_loadAccess(refreshRemote: refreshRemote));
  }

  Future<void> _load() async {
    final service = ref.read(advancedThemeServiceProvider);
    final loadToken = ++_summaryLoadToken;
    try {
      final themes = await service.loadThemeSummaries();
      if (!mounted || loadToken != _summaryLoadToken) {
        return;
      }
      final sortedThemes = _sortThemeSummaries(themes);
      setState(() {
        _themeSummaries = sortedThemes;
        if (_selectedCategory != null &&
            !_availableCategories.contains(_selectedCategory)) {
          _selectedCategory = null;
        }
        _pruneSelectionForVisibleThemes();
        _isLoading = false;
      });
      unawaited(_hydrateThemePreviewSummaries(loadToken, sortedThemes));
    } catch (_) {
      if (!mounted || loadToken != _summaryLoadToken) {
        return;
      }
      setState(() {
        _themeSummaries = const <AdvancedThemeSummary>[];
        _selectedCategory = null;
        _pruneSelectionForVisibleThemes();
        _isLoading = false;
      });
      _showMessage('高级主题加载失败，请稍后重试。');
    }
  }

  Future<void> _hydrateThemePreviewSummaries(
    int loadToken,
    List<AdvancedThemeSummary> currentSummaries,
  ) async {
    final service = ref.read(advancedThemeServiceProvider);
    final List<AdvancedThemeSummary> hydrated;
    try {
      hydrated = await service.hydrateThemeSummaryPreviewPaths(
        currentSummaries,
      );
    } catch (_) {
      return;
    }
    if (!mounted || loadToken != _summaryLoadToken) {
      return;
    }
    final sortedHydrated = _sortThemeSummaries(hydrated);
    final changed =
        sortedHydrated.length != _themeSummaries.length ||
        !_hasSamePreviewContent(_themeSummaries, sortedHydrated);
    if (!changed) {
      return;
    }
    setState(() {
      _themeSummaries = sortedHydrated;
      _pruneSelectionForVisibleThemes();
    });
  }

  List<AdvancedThemeSummary> _sortThemeSummaries(
    List<AdvancedThemeSummary> themes,
  ) {
    final activeThemeId = ref.read(activeAdvancedThemeIdProvider);
    return _queryController.sortThemeSummaries(
      themes: themes,
      activeThemeId: activeThemeId,
      sortMode: _themeSortMode,
    );
  }

  bool _hasSamePreviewContent(
    List<AdvancedThemeSummary> previous,
    List<AdvancedThemeSummary> next,
  ) {
    return _queryController.hasSamePreviewContent(
      previous: previous,
      next: next,
    );
  }

  List<String> get _availableCategories {
    return _queryController.availableCategories(_themeSummaries);
  }

  List<AdvancedThemeSummary> get _visibleThemes {
    return _queryController.visibleThemes(
      summaries: _themeSummaries,
      searchQuery: _searchQuery,
      selectedCategory: _selectedCategory,
    );
  }

  List<_AdvancedThemeListEntry> get _visibleThemeEntries {
    final entries = <_AdvancedThemeListEntry>[
      for (var index = 0; index < appOfficialThemePresets.length; index += 1)
        if (_officialPresetMatchesFilters(appOfficialThemePresets[index]))
          _AdvancedThemeListEntry.official(
            appOfficialThemePresets[index],
            index,
          ),
    ];
    final customOrderStart = appOfficialThemePresets.length;
    final visibleThemes = _visibleThemes;
    for (var index = 0; index < visibleThemes.length; index += 1) {
      entries.add(
        _AdvancedThemeListEntry.custom(
          visibleThemes[index],
          customOrderStart + index,
        ),
      );
    }
    final activeThemeId = ref.read(activeAdvancedThemeIdProvider);
    entries.sort((a, b) {
      final aIsActive = a.themeId == activeThemeId;
      final bIsActive = b.themeId == activeThemeId;
      if (aIsActive != bIsActive) {
        return aIsActive ? -1 : 1;
      }
      return a.order.compareTo(b.order);
    });
    return entries;
  }

  bool _officialPresetMatchesFilters(AppOfficialThemePreset preset) {
    final categoryFilter = _selectedCategory?.trim() ?? '';
    if (categoryFilter.isNotEmpty) {
      return false;
    }
    final keyword = _searchQuery.trim().toLowerCase();
    if (keyword.isEmpty) {
      return true;
    }
    final haystacks = <String>[
      preset.id.label,
      preset.id.id,
      preset.description,
      '官方主题',
    ].map((item) => item.toLowerCase());
    return haystacks.any((item) => item.contains(keyword));
  }

  List<AdvancedThemeSummary> get _selectedVisibleThemes {
    return _visibleThemes
        .where((theme) => _selectedThemeIds.contains(theme.id))
        .toList(growable: false);
  }

  bool get _allVisibleThemesSelected {
    return _queryController.areAllVisibleThemesSelected(
      visibleThemes: _visibleThemes,
      selectedThemeIds: _selectedThemeIds,
    );
  }

  void _pruneSelectionForVisibleThemes() {
    if (!_isSelectionMode) {
      return;
    }
    _selectedThemeIds = _queryController.pruneSelectedThemeIds(
      visibleThemes: _visibleThemes,
      selectedThemeIds: _selectedThemeIds,
    );
    if (_selectedThemeIds.isEmpty) {
      _isSelectionMode = false;
    }
  }

  void _enterSelectionMode() {
    if (_isSaving || _visibleThemes.isEmpty) {
      return;
    }
    if (!_guardCustomThemeAction('批量管理自定义主题需要会员。')) {
      return;
    }
    setState(() {
      _isSelectionMode = true;
      _selectedThemeIds = <String>{};
    });
  }

  void _exitSelectionMode() {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSelectionMode = false;
      _selectedThemeIds = <String>{};
    });
  }

  void _toggleThemeSelection(String themeId) {
    if (!_isSelectionMode || _isSaving) {
      return;
    }
    setState(() {
      final nextSelectedIds = Set<String>.from(_selectedThemeIds);
      if (!nextSelectedIds.add(themeId)) {
        nextSelectedIds.remove(themeId);
      }
      _selectedThemeIds = nextSelectedIds;
      if (_selectedThemeIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _toggleSelectAllVisibleThemes() {
    if (!_isSelectionMode || _isSaving) {
      return;
    }
    final visibleIds = _visibleThemes.map((theme) => theme.id).toSet();
    if (visibleIds.isEmpty) {
      return;
    }
    setState(() {
      _selectedThemeIds = _allVisibleThemesSelected ? <String>{} : visibleIds;
      if (_selectedThemeIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  Future<AppAdvancedTheme?> _loadThemeDetail(String themeId) {
    return ref.read(advancedThemeServiceProvider).loadThemeById(themeId);
  }

  String _editorRoute([String? themeId]) {
    return themeId == null || themeId.trim().isEmpty
        ? '/appearance/advanced-themes/editor'
        : '/appearance/advanced-themes/editor?id=$themeId';
  }

  Future<void> _openEditor([String? themeId]) async {
    if (!_guardCustomThemeAction(
      themeId == null ? '创建自定义主题需要会员。' : '编辑自定义主题需要会员。',
    )) {
      return;
    }
    final result = await context.push<String>(_editorRoute(themeId));
    await _load();
    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }
    _showMessage(result);
  }

  Future<void> _openEditorWithReveal(
    BuildContext sourceContext, [
    String? themeId,
  ]) async {
    if (!_guardCustomThemeAction('编辑自定义主题需要会员。')) {
      return;
    }
    final overlay = CircularThemeRevealOverlay.of(sourceContext);
    final center = CircularThemeRevealOverlay.getCenterFromContext(
      sourceContext,
    );
    Future<String?>? navigationFuture;

    if (overlay == null) {
      await _openEditor(themeId);
      return;
    }

    await overlay.startTransition(
      center: center,
      reverse: false,
      onThemeChange: () {
        navigationFuture = context.push<String>(_editorRoute(themeId));
      },
    );

    final result = await navigationFuture;
    await _load();
    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }
    _showMessage(result);
  }

  Future<void> _openEditorDialog(String themeId) async {
    if (!_guardCustomThemeAction('编辑自定义主题需要会员。')) {
      return;
    }
    await showAdaptiveActionSurface<void>(
      context: context,
      maxWidth: 420,
      builder: (dialogContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '编辑主题',
              style: Theme.of(
                dialogContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              '将打开主题编辑器。',
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    unawaited(_openEditor(themeId));
                  },
                  child: const Text('编辑'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showThemeSortDialog() async {
    final selected = await showAdaptiveActionSurface<_AdvancedThemeSortMode>(
      context: context,
      maxWidth: 420,
      builder: (dialogContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '排序主题',
              style: Theme.of(
                dialogContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final mode in _AdvancedThemeSortMode.values)
              _buildThemeSortOption(dialogContext, mode),
          ],
        );
      },
    );
    if (selected == null || selected == _themeSortMode || !mounted) {
      return;
    }
    setState(() {
      _themeSortMode = selected;
      _themeSummaries = _sortThemeSummaries(_themeSummaries);
      _pruneSelectionForVisibleThemes();
    });
  }

  Widget _buildThemeSortOption(
    BuildContext context,
    _AdvancedThemeSortMode mode,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = _themeSortMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(mode),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.32)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _themeSortModeLabel(mode),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AppSelectionIndicator(
                selected: selected,
                semanticLabel: selected ? '当前排序方式' : '可选排序方式',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _themeSortModeLabel(_AdvancedThemeSortMode mode) {
    return switch (mode) {
      _AdvancedThemeSortMode.updatedDesc => '最近更新',
      _AdvancedThemeSortMode.nameAsc => '名称 A-Z',
      _AdvancedThemeSortMode.categoryAsc => '分类优先',
    };
  }

  Future<void> _duplicateTheme(String themeId) async {
    if (_isSaving) {
      return;
    }
    if (!_guardCustomThemeAction('复制自定义主题需要会员。')) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final service = ref.read(advancedThemeServiceProvider);
      final theme = await _loadThemeDetail(themeId);
      if (theme == null) {
        if (mounted) {
          _showMessage('主题不存在或已被删除');
        }
        return;
      }
      final duplicated = await service.duplicateTheme(theme);
      ref.read(advancedThemeRevisionProvider.notifier).markChanged();
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage('已复制主题「${duplicated.name}」');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _exportThemeBundle(String themeId) async {
    if (!_guardCustomThemeAction('导出自定义主题需要会员。')) {
      return;
    }
    final theme = await _loadThemeDetail(themeId);
    if (theme == null || !mounted) {
      if (mounted) {
        _showMessage('主题不存在或已被删除');
      }
      return;
    }
    await _showAdvancedThemeSingleTaskSheet(
      title: '导出主题包',
      description: '导出当前主题的 ZIP 主题包。',
      icon: Icons.archive_outlined,
      processingMessage: theme.name,
      processingDetail: '准备导出主题包',
      runTask: (onProgress) => _runExportThemeBundle(theme, onProgress),
    );
  }

  Future<_AdvancedThemeExportDispatchResult> _shareExportedThemeFile({
    required File file,
    required String text,
    required String subject,
    String? clipboardText,
    ValueChanged<String>? onProgress,
  }) async {
    try {
      if (onProgress == null) {
        _updateSavingStatus(ImportExportCopy.shareLaunching);
      } else {
        onProgress(ImportExportCopy.shareLaunching);
      }
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        subject: subject,
        sharePositionOrigin: _resolveSharePositionOrigin(),
      );
      switch (result.status) {
        case ShareResultStatus.success:
          return const _AdvancedThemeExportDispatchResult.completed();
        case ShareResultStatus.dismissed:
          return const _AdvancedThemeExportDispatchResult.cancelled(
            message: '已取消导出',
          );
        case ShareResultStatus.unavailable:
          return const _AdvancedThemeExportDispatchResult.completed(
            message: '已发起系统分享，请检查目标应用。',
          );
      }
    } on MissingPluginException {
      final fallbackText = clipboardText;
      if (fallbackText != null && fallbackText.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: fallbackText));
      }
      return _AdvancedThemeExportDispatchResult.failed(
        message:
            fallbackText == null || fallbackText.isEmpty
                ? '当前安装包暂不支持系统分享，请完整重启 App 后重试。'
                : '当前安装包暂不支持系统分享，已复制主题内容，请完整重启 App 后重试。',
      );
    }
  }

  Future<void> _showAdvancedThemeSingleTaskSheet({
    required String title,
    required String description,
    required IconData icon,
    required String processingMessage,
    required String processingDetail,
    required Future<bool> Function(ValueChanged<String> onProgress) runTask,
  }) async {
    await showAdaptiveRawSurface<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: false,
      mobileBackgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _AdvancedThemeSingleTaskSheet(
          title: title,
          description: description,
          icon: icon,
          processingMessage: processingMessage,
          processingDetail: processingDetail,
          runTask: runTask,
        );
      },
    );
  }

  Future<bool> _runExportThemeBundle(
    AppAdvancedTheme theme, [
    ValueChanged<String>? onProgress,
  ]) async {
    setState(() {
      _isSaving = true;
    });
    try {
      final service = ref.read(advancedThemeServiceProvider);
      final result = await _exportController.exportThemeBundle(
        service: service,
        theme: theme,
        shareExportedThemeFile: _shareExportedThemeFile,
        onProgress: onProgress,
      );
      if (!mounted) {
        return false;
      }
      _showMessage(result.message);
      return result.isCompleted;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      _showMessage('导出主题包失败：${formatAdvancedThemeExportError(error)}');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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

  Future<void> _consumePendingExternalImportPayloads() async {
    await _importController.consumePendingExternalImportPayloads(
      isConsuming: _isConsumingExternalImportPayloads,
      mounted: mounted,
      setConsuming: (value) {
        _isConsumingExternalImportPayloads = value;
      },
      flowCoordinator: _pageFlowCoordinator,
      importPayload: _importFromExternalPayload,
    );
  }

  Future<void> _importFromExternalPayload(
    IncomingExternalImportPayload payload,
  ) async {
    final taskId =
        'external-theme-import:${DateTime.now().microsecondsSinceEpoch}';
    final taskManager = ref.read(appTaskManagerProvider);
    taskManager.startTask(
      id: taskId,
      status: AppTaskStatusData(
        title: '正在导入主题',
        message: '正在读取 ${payload.label} 并准备导入…',
        kind: AppTaskStatusKind.themeImport,
      ),
      channel: AppTaskChannel.resourceImport,
      priority: AppTaskPriority.userInitiated,
      recoveryKey: 'external-theme-import:${payload.uri}',
    );
    setState(() {
      _isSaving = true;
      _savingStatusText = '正在读取外部主题文件并准备导入…';
    });

    CachedExternalImportFile? cached;
    try {
      cached = await _pageFlowCoordinator.cacheExternalFileFromUri(payload);
      if (cached == null) {
        ExternalImportDiagnostics.logCacheFailed(payload);
        final message = ExternalImportDiagnostics.readFailedMessage(
          payload.type,
          payload.label,
        );
        taskManager.updateTask(
          taskId,
          AppTaskStatusData(
            title: '主题导入失败',
            message: message,
            kind: AppTaskStatusKind.themeImport,
            result: AppTaskStatusResult.failure,
          ),
        );
        _showMessage(message);
        return;
      }
      if (!ExternalImportCatalog.supportsFileLabel(
        ExternalImportPayloadType.advancedTheme,
        cached.label,
      )) {
        ExternalImportDiagnostics.logImportUnsupported(
          ExternalImportPayloadType.advancedTheme,
          cached.label,
        );
        final message = ExternalImportCatalog.unsupportedFileMessage(
          ExternalImportPayloadType.advancedTheme,
          cached.label,
        );
        taskManager.updateTask(
          taskId,
          AppTaskStatusData(
            title: '主题导入失败',
            message: message,
            kind: AppTaskStatusKind.themeImport,
            result: AppTaskStatusResult.failure,
          ),
        );
        _showMessage(message);
        return;
      }
      final mimeType = cached.mimeType ?? payload.mimeType;
      final service = ref.read(advancedThemeServiceProvider);
      if (service.isBatchThemeBundleFile(
        path: cached.path,
        mimeType: mimeType,
      )) {
        final summary = await _importThemeBatchFile(
          path: cached.path,
          mimeType: mimeType,
          onProgress: (_, message) {
            _updateSavingStatus(message);
            taskManager.updateTask(
              taskId,
              AppTaskStatusData(
                title: '正在导入主题',
                message: message,
                kind: AppTaskStatusKind.themeImport,
              ),
            );
          },
        );
        if (!mounted) {
          return;
        }
        ref.read(advancedThemeRevisionProvider.notifier).markChanged();
        await _load();
        if (!mounted) {
          return;
        }
        ExternalImportDiagnostics.logImportSucceeded(
          ExternalImportPayloadType.advancedTheme,
          cached.label,
        );
        taskManager.updateTask(
          taskId,
          AppTaskStatusData(
            title: '主题批量导入完成',
            message:
                '成功 ${summary.successCount} 个，失败 ${summary.failureCount} 个',
            kind: AppTaskStatusKind.themeImport,
            progress: 1,
            result:
                summary.failureCount == 0
                    ? AppTaskStatusResult.success
                    : AppTaskStatusResult.failure,
          ),
        );
        _showBatchImportSummary(summary);
        return;
      }
      taskManager.updateTask(
        taskId,
        const AppTaskStatusData(
          title: '正在导入主题',
          message: '正在解析并写入主题资源…',
          kind: AppTaskStatusKind.themeImport,
        ),
      );
      final importedTheme = await service.importThemeFile(
        path: cached.path,
        mimeType: mimeType,
      );
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportSucceeded(
        ExternalImportPayloadType.advancedTheme,
        importedTheme.name,
      );
      taskManager.updateTask(
        taskId,
        AppTaskStatusData(
          title: '主题导入完成',
          message: importedTheme.name,
          kind: AppTaskStatusKind.themeImport,
          progress: 1,
          result: AppTaskStatusResult.success,
        ),
      );
      _showMessage('已导入主题「${importedTheme.name}」');
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.advancedTheme,
        cached?.label ?? payload.label,
        error,
      );
      taskManager.updateTask(
        taskId,
        AppTaskStatusData(
          title: '主题导入失败',
          message: error.message,
          kind: AppTaskStatusKind.themeImport,
          result: AppTaskStatusResult.failure,
        ),
      );
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.advancedTheme,
        cached?.label ?? payload.label,
        error,
      );
      final message = ExternalImportDiagnostics.importFailedMessage(
        ExternalImportPayloadType.advancedTheme,
        '$error',
        label: cached?.label ?? payload.label,
      );
      taskManager.updateTask(
        taskId,
        AppTaskStatusData(
          title: '主题导入失败',
          message: message,
          kind: AppTaskStatusKind.themeImport,
          result: AppTaskStatusResult.failure,
        ),
      );
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingStatusText = null;
        });
      }
    }
  }

  void _handleMoreAction(_AdvancedThemeListMoreAction action) {
    switch (action) {
      case _AdvancedThemeListMoreAction.importBatch:
        unawaited(_openBatchImportSheet());
        break;
      case _AdvancedThemeListMoreAction.sortThemes:
        unawaited(_showThemeSortDialog());
        break;
      case _AdvancedThemeListMoreAction.floatingEdit:
        setState(() {
          _floatingEditEnabled = !_floatingEditEnabled;
        });
        break;
      case _AdvancedThemeListMoreAction.selectThemes:
        _enterSelectionMode();
        break;
    }
  }

  Future<void> _openBatchImportSheet() async {
    if (_isSaving || !mounted) {
      return;
    }
    if (!_guardCustomThemeAction('导入自定义主题需要会员。')) {
      return;
    }
    final summary =
        await showAdaptiveRawSurface<_AdvancedThemeBatchImportSummary>(
          context: context,
          useRootNavigator: true,
          showDragHandle: false,
          mobileBackgroundColor: Colors.transparent,
          builder: (sheetContext) {
            return _AdvancedThemeBatchImportSheet(
              importFile: _importThemeBatchFile,
              onImportCompleted: () {
                if (!mounted) {
                  return;
                }
                ref.read(advancedThemeRevisionProvider.notifier).markChanged();
                unawaited(_load());
              },
              onShowImportSupportHelp: () {
                return _showThemeImportSupportHelp(sheetContext);
              },
            );
          },
        );
    if (summary == null || !summary.hasSuccess) {
      if (summary != null && mounted) {
        _showBatchImportSummary(summary);
      }
      return;
    }

    ref.read(advancedThemeRevisionProvider.notifier).markChanged();
    await _load();
    if (!mounted) {
      return;
    }
    _showBatchImportSummary(summary);
  }

  Future<_AdvancedThemeBatchImportSummary> _importThemeBatchFile({
    required String path,
    String? mimeType,
    _AdvancedThemeBatchImportProgressCallback? onProgress,
  }) async {
    final service = ref.read(advancedThemeServiceProvider);
    return _batchImportController.importThemeBatchFile(
      service: service,
      path: path,
      mimeType: mimeType,
      onProgress: onProgress,
      normalizeProgressMessage:
          (message) =>
              message == '正在准备导入...'
                  ? ImportExportCopy.importPreparing
                  : message,
    );
  }

  Future<void> _exportSelectedThemes() async {
    if (_isSaving) {
      return;
    }
    if (!_guardCustomThemeAction('批量导出自定义主题需要会员。')) {
      return;
    }
    final targetThemes = _selectedVisibleThemes;
    if (!_batchActionController.hasSelection(targetThemes)) {
      _showMessage('请先选择要导出的主题。');
      return;
    }
    await _exportThemeSummaries(targetThemes);
  }

  Future<void> _exportThemeSummaries(
    List<AdvancedThemeSummary> targetThemes,
  ) async {
    if (_isSaving || targetThemes.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
      _savingStatusText = '正在准备导出 ${targetThemes.length} 个主题...';
    });
    try {
      final service = ref.read(advancedThemeServiceProvider);
      final result = await _exportController.exportThemeSummaries(
        service: service,
        summaries: targetThemes,
        shareExportedThemeFile: _shareExportedThemeFile,
        onProgress: _updateSavingStatus,
      );
      if (!mounted) {
        return;
      }
      _showMessage(result.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('批量导出失败：${formatAdvancedThemeExportError(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingStatusText = null;
        });
      }
    }
  }

  void _updateSavingStatus(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _savingStatusText = message;
    });
  }

  Future<void> _deleteSelectedThemes() async {
    if (_isSaving) {
      return;
    }
    if (!_guardCustomThemeAction('批量删除自定义主题需要会员。')) {
      return;
    }
    final selectedThemes = _selectedVisibleThemes;
    if (!_batchActionController.hasSelection(selectedThemes)) {
      _showMessage('请先选择要删除的主题。');
      return;
    }
    final confirmed = await _showBatchDeleteDialog(selectedThemes.length);
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    var successCount = 0;
    var failureCount = 0;
    final deletedIds = <String>{};
    final service = ref.read(advancedThemeServiceProvider);
    final activeThemeId = ref.read(activeAdvancedThemeIdProvider);

    try {
      for (final theme in selectedThemes) {
        try {
          await service.deleteTheme(
            theme.id,
            deleteOptions: const AdvancedThemeDeleteOptions(),
          );
          deletedIds.add(theme.id);
          successCount += 1;
        } catch (_) {
          failureCount += 1;
        }
      }

      if (successCount > 0) {
        ref.read(advancedThemeRevisionProvider.notifier).markChanged();
        if (activeThemeId != null && deletedIds.contains(activeThemeId)) {
          await ref.read(activeAdvancedThemeIdProvider.notifier).disable();
        }
      }
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage(
        _batchActionController.deleteCompletedMessage(
          successCount: successCount,
          failureCount: failureCount,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool?> _showBatchDeleteDialog(int count) {
    return showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 460,
      builder: (dialogContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '批量删除主题',
              style: Theme.of(
                dialogContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              '确定删除已选 $count 个主题吗？\n\n'
              '会按默认策略一并处理主题绑定的壁纸、图集等资源；'
              '仍被其他主题引用的共享资源会自动保留。',
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateSelectedThemesCategory() async {
    if (_isSaving) {
      return;
    }
    if (!_guardCustomThemeAction('批量分类自定义主题需要会员。')) {
      return;
    }
    final selectedThemes = _selectedVisibleThemes;
    if (!_batchActionController.hasSelection(selectedThemes)) {
      _showMessage('请先选择要分类的主题。');
      return;
    }
    final category = await _showBatchCategoryDialog(selectedThemes.length);
    if (category == null || !mounted) {
      return;
    }
    final normalizedCategory = category.trim();
    final nextCategory = normalizedCategory.isEmpty ? null : normalizedCategory;

    setState(() {
      _isSaving = true;
    });

    try {
      final service = ref.read(advancedThemeServiceProvider);
      final updatedThemes = _batchActionController.applyCategory(
        themes: await service.loadThemes(),
        selectedIds: _batchActionController.selectedIds(selectedThemes),
        category: nextCategory,
      );
      await service.saveThemes(updatedThemes);
      ref.read(advancedThemeRevisionProvider.notifier).markChanged();
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage(
        _batchActionController.categoryUpdatedMessage(
          count: selectedThemes.length,
          category: nextCategory,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<String?> _showBatchCategoryDialog(int count) {
    final controller = TextEditingController();
    String? errorText;
    return showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 460,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final value = controller.text.trim();
              if (value.isEmpty) {
                setDialogState(() {
                  errorText = '请输入分类名称，或使用“清空分类”。';
                });
                return;
              }
              Navigator.of(dialogContext).pop(value);
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '批量分类',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('已选 $count 个主题'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '主题分类',
                        hintText: '例如：护眼 / 极简 / 漫画',
                        errorText: errorText,
                      ),
                      onChanged: (_) {
                        if (errorText == null) {
                          return;
                        }
                        setDialogState(() {
                          errorText = null;
                        });
                      },
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(''),
                      child: const Text('清空分类'),
                    ),
                    FilledButton(onPressed: submit, child: const Text('确定')),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBatchImportSummary(_AdvancedThemeBatchImportSummary summary) {
    if (summary.hasSuccess) {
      if (summary.failureCount > 0) {
        _showMessage(
          '已导入 ${summary.successCount} 个主题，失败 ${summary.failureCount} 个。',
        );
      } else {
        _showMessage('已导入 ${summary.successCount} 个主题。');
      }
      return;
    }
    _showMessage(summary.lastError ?? '批量导入失败，请确认主题文件格式正确。');
  }

  Future<void> _showThemeImportSupportHelp(BuildContext context) {
    return showAdaptiveActionSurface<void>(
      context: context,
      maxWidth: 560,
      builder: (dialogContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '兼容导入说明',
              style: Theme.of(
                dialogContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              '当前 Red 兼容导入支持：\n'
              '1. 主题名称\n'
              '2. 浅色 / 深色颜色\n'
              '3. 页面壁纸\n'
              '4. 封面图集\n'
              '5. 底栏图标包\n'
              '6. 阅读器背景图\n'
              '7. 阅读器背景不透明度与图片适配\n\n'
              '当前 RGShare 兼容导入支持：\n'
              '1. 主题名称\n'
              '2. 浅色 / 深色壁纸\n'
              '3. 部分颜色映射\n\n'
              '旧 JSON 主题兼容导入支持颜色配置和部分透明度参数，导出会统一使用新的 ZIP 主题包。\n\n'
              '兼容导入不支持完整还原原应用的阅读器排版、字体、页眉页脚模板和交互行为。',
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('知道了'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTheme(AppAdvancedTheme theme) async {
    final themeService = ref.read(advancedThemeServiceProvider);
    final remainingThemes = (await themeService.loadThemes())
        .where((item) => item.id != theme.id)
        .toList(growable: false);
    final preview = await ref
        .read(advancedThemeResourceReferenceServiceProvider)
        .buildDeletePreview(theme: theme, remainingThemes: remainingThemes);
    if (!mounted) {
      return;
    }
    final decision = await showAdvancedThemeDeleteDecisionSurface(
      context: context,
      theme: theme,
      preview: preview,
    );
    if (decision == null || !decision.confirmed || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final wasActive = ref.read(activeAdvancedThemeIdProvider) == theme.id;
      final service = ref.read(advancedThemeServiceProvider);
      await service.deleteTheme(
        theme.id,
        deleteOptions: decision.deleteOptions,
      );
      ref.read(advancedThemeRevisionProvider.notifier).markChanged();
      if (wasActive) {
        await ref.read(activeAdvancedThemeIdProvider.notifier).disable();
      }
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage(
        decision.deleteOptions.deleteAnyAssociatedResources
            ? '已删除主题「${theme.name}」及所选资源'
            : '已删除主题「${theme.name}」',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleDeleteThemeById(String themeId) async {
    if (!_guardCustomThemeAction('删除自定义主题需要会员。')) {
      return;
    }
    final theme = await _loadThemeDetail(themeId);
    if (theme == null) {
      if (mounted) {
        _showMessage('主题不存在或已被删除');
      }
      return;
    }
    await _deleteTheme(theme);
  }

  Future<void> _applyTheme(AppAdvancedTheme theme) async {
    if (_isSaving) {
      return;
    }
    if (!_guardCustomThemeAction('启用自定义主题需要会员。')) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await ref
          .read(activeAdvancedThemeIdProvider.notifier)
          .setActiveThemeId(theme.id);
      if (!mounted) {
        return;
      }
      _showMessage('已应用主题「${theme.name}」');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool _guardCustomThemeAction(String message) {
    if (_canUseAdvancedThemes) {
      return true;
    }
    _showMembershipGate(message);
    return false;
  }

  void _showMembershipGate(String message) {
    _showMessage(message);
    if (mounted) {
      unawaited(context.push('/membership'));
    }
  }

  Future<void> _applyOfficialTheme(AppOfficialThemePreset preset) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await ref
          .read(activeAdvancedThemeIdProvider.notifier)
          .setActiveThemeId(preset.id.themeId);
      ref.read(advancedThemeRevisionProvider.notifier).markChanged();
      if (!mounted) {
        return;
      }
      _showMessage('已应用官方主题「${preset.id.label}」');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _applyThemeById(String themeId) async {
    final theme = await _loadThemeDetail(themeId);
    if (theme == null) {
      if (mounted) {
        _showMessage('主题不存在或已被删除');
      }
      return;
    }
    await _applyTheme(theme);
  }

  Future<void> _disableActiveTheme() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await ref.read(activeAdvancedThemeIdProvider.notifier).disable();
      if (!mounted) {
        return;
      }
      _showMessage('已停用高级主题');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone:
          message.contains('失败') ? AppFeedbackTone.error : AppFeedbackTone.info,
      useHaptics: false,
    );
  }

  PreferredSizeWidget _buildRouteTopBar(BuildContext context) {
    final title =
        _isSelectionMode
            ? _selectedThemeIds.isEmpty
                ? '选择主题'
                : '已选 ${_selectedThemeIds.length} 个主题'
            : '高级主题';
    final subtitle =
        _isSelectionMode
            ? '批量操作'
            : _canUseAdvancedThemes
            ? '搜索、导入、排序和管理主题'
            : null;
    return AdaptiveRouteTopBar(
      title: title,
      subtitle: subtitle,
      leading: _buildRouteLeading(context),
      middle:
          !_isSelectionMode && _canUseAdvancedThemes
              ? _buildSearchBar(context)
              : null,
      actions: _buildDesktopTopBarActions(),
      mobileActions: _buildMobileTopBarActions(),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      dividerColor: Colors.transparent,
    );
  }

  Widget _buildRouteLeading(BuildContext context) {
    return IconButton(
      tooltip: _isSelectionMode ? '取消选择' : '返回',
      onPressed: () {
        if (_isSelectionMode) {
          _exitSelectionMode();
          return;
        }
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go('/mine');
      },
      icon: Icon(
        _isSelectionMode
            ? Icons.close_rounded
            : Icons.arrow_back_ios_new_rounded,
      ),
    );
  }

  List<Widget> _buildMobileTopBarActions() {
    if (_isSelectionMode) {
      return const <Widget>[];
    }
    return <Widget>[
      IconButton(
        tooltip: '新建高级主题',
        onPressed: _isLoading || _isSaving ? null : () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
      ),
      AppMenuButton<_AdvancedThemeListMoreAction>(
        enabled: !_isLoading && !_isSaving,
        tooltip: '更多',
        onSelected: _handleMoreAction,
        actions: [
          const AppMenuAction(
            value: _AdvancedThemeListMoreAction.importBatch,
            label: '批量导入',
            icon: Icons.upload_file_outlined,
          ),
          const AppMenuAction(
            value: _AdvancedThemeListMoreAction.sortThemes,
            label: '排序主题',
            icon: Icons.sort_rounded,
          ),
          AppMenuAction(
            value: _AdvancedThemeListMoreAction.floatingEdit,
            label: '悬浮编辑按钮',
            icon:
                _floatingEditEnabled
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
          ),
          const AppMenuAction(
            value: _AdvancedThemeListMoreAction.selectThemes,
            label: '选择主题',
            icon: Icons.checklist_rounded,
          ),
        ],
      ),
    ];
  }

  List<AdaptiveOverflowToolbarItem> _buildDesktopTopBarActions() {
    if (_isSelectionMode) {
      final hasSelection = _selectedThemeIds.isNotEmpty;
      return <AdaptiveOverflowToolbarItem>[
        AdaptiveOverflowToolbarItem(
          icon:
              _allVisibleThemesSelected
                  ? Icons.deselect_outlined
                  : Icons.select_all_rounded,
          label: _allVisibleThemesSelected ? '取消全选' : '全选',
          enabled: !_isSaving && _visibleThemes.isNotEmpty,
          priority: 6,
          onPressed: _toggleSelectAllVisibleThemes,
        ),
        AdaptiveOverflowToolbarItem(
          icon: Icons.ios_share_outlined,
          label: '导出',
          enabled: !_isSaving && hasSelection,
          priority: 5,
          onPressed: () => unawaited(_exportSelectedThemes()),
        ),
        AdaptiveOverflowToolbarItem(
          icon: Icons.category_outlined,
          label: '分类',
          enabled: !_isSaving && hasSelection,
          priority: 4,
          onPressed: () => unawaited(_updateSelectedThemesCategory()),
        ),
        AdaptiveOverflowToolbarItem(
          icon: Icons.delete_outline_rounded,
          label: '删除',
          enabled: !_isSaving && hasSelection,
          priority: 3,
          onPressed: () => unawaited(_deleteSelectedThemes()),
        ),
      ];
    }
    return <AdaptiveOverflowToolbarItem>[
      AdaptiveOverflowToolbarItem(
        icon: Icons.add_rounded,
        label: '新建',
        enabled: !_isLoading && !_isSaving,
        priority: 8,
        onPressed: () => _openEditor(),
      ),
      AdaptiveOverflowToolbarItem(
        icon: Icons.upload_file_rounded,
        label: '批量导入',
        enabled: !_isLoading && !_isSaving,
        priority: 7,
        onPressed: () => unawaited(_openBatchImportSheet()),
      ),
      AdaptiveOverflowToolbarItem(
        icon: Icons.sort_rounded,
        label: '排序',
        enabled: !_isLoading && !_isSaving,
        priority: 6,
        onPressed: () => unawaited(_showThemeSortDialog()),
      ),
      AdaptiveOverflowToolbarItem(
        icon:
            _floatingEditEnabled
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
        label: '悬浮编辑',
        enabled: !_isLoading && !_isSaving,
        priority: 2,
        onPressed: () {
          setState(() {
            _floatingEditEnabled = !_floatingEditEnabled;
          });
        },
      ),
      AdaptiveOverflowToolbarItem(
        icon: Icons.checklist_rtl_rounded,
        label: '选择主题',
        enabled: !_isLoading && !_isSaving,
        priority: 1,
        onPressed: _enterSelectionMode,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(advancedThemeListPageStateProvider);
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topBarHeight = metrics.isMediumUpWindow ? 64.0 : kToolbarHeight;
    final topInset = MediaQuery.paddingOf(context).top + topBarHeight;
    final activeThemeId = ref.watch(activeAdvancedThemeIdProvider);
    final activeThemeAsync = ref.watch(activeAdvancedThemeProvider);
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeThemeAsync.valueOrNull,
    );

    return PopScope<void>(
      canPop: !_isSelectionMode && context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        if (_isSelectionMode) {
          _exitSelectionMode();
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildRouteTopBar(context),
        floatingActionButton:
            !_isSelectionMode &&
                    _canUseAdvancedThemes &&
                    _floatingEditEnabled &&
                    !_isLoading &&
                    !_isSaving &&
                    _visibleThemes.isNotEmpty
                ? FloatingActionButton(
                  tooltip: '编辑当前列表首个主题',
                  onPressed: () => _openEditorDialog(_visibleThemes.first.id),
                  child: const Icon(Icons.edit_rounded),
                )
                : null,
        bottomNavigationBar:
            !metrics.isMediumUpWindow &&
                    _isSelectionMode &&
                    !_isAccessLoading &&
                    !_isLoading &&
                    _canUseAdvancedThemes
                ? _buildSelectionActionBar(context)
                : null,
        body: Stack(
          children: [
            LayoutBuilder(
              builder: (context, _) {
                final maxWidth = AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth:
                      metrics.isExpandedWindow
                          ? 1120
                          : AppLayout.settingsContentMaxWidth,
                );
                final content =
                    _isAccessLoading || _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildThemeListView(
                          context,
                          activeThemeAsync: activeThemeAsync,
                          activeThemeId: activeThemeId,
                          horizontal: horizontal,
                          bottomSafe: bottomSafe,
                          topInset: topInset,
                        );
                return DecoratedBox(
                  decoration: buildAdvancedThemeBackdropDecoration(backdrop),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: content,
                    ),
                  ),
                );
              },
            ),
            if (_isSaving && (_savingStatusText?.trim().isNotEmpty ?? false))
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: Center(child: _buildSavingProgressCard(context)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingProgressCard(BuildContext context) {
    return AdvancedThemeSavingProgressCard(
      statusText: _savingStatusText ?? '处理中...',
    );
  }

  Widget _buildThemeListView(
    BuildContext context, {
    required AsyncValue<AppAdvancedTheme?> activeThemeAsync,
    required String? activeThemeId,
    required double horizontal,
    required double bottomSafe,
    required double topInset,
  }) {
    final visibleThemes = _visibleThemes;
    final visibleEntries = _visibleThemeEntries;
    final isFiltering =
        _searchQuery.trim().isNotEmpty ||
        (_selectedCategory?.trim().isNotEmpty ?? false);
    final showInlineToolbar = !AppAdaptiveMetrics.of(context).isMediumUpWindow;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topInset + 12,
            horizontal,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (showInlineToolbar) ...[
                  _buildSearchBar(context),
                  const SizedBox(height: 10),
                ],
                _buildListStatusRow(
                  context,
                  activeThemeAsync: activeThemeAsync,
                  activeThemeId: activeThemeId,
                  visibleThemeCount: visibleEntries.length,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (visibleEntries.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              0,
              horizontal,
              16 + bottomSafe,
            ),
            sliver: SliverToBoxAdapter(child: _buildEmptyState(context)),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 14),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final entry = visibleEntries[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == visibleEntries.length - 1 ? 0 : 10,
                  ),
                  child: _buildThemeEntryCard(
                    context,
                    entry: entry,
                    activeThemeId: activeThemeId,
                  ),
                );
              }, childCount: visibleEntries.length),
            ),
          ),
        if (!_canUseAdvancedThemes)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              visibleEntries.isEmpty ? 0 : 2,
              horizontal,
              16 + bottomSafe,
            ),
            sliver: SliverToBoxAdapter(child: _buildCustomThemeLockedState()),
          )
        else if (visibleThemes.isEmpty && !isFiltering)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              visibleEntries.isEmpty ? 0 : 2,
              horizontal,
              16 + bottomSafe,
            ),
            sliver: SliverToBoxAdapter(child: _buildEmptyState(context)),
          ),
      ],
    );
  }

  Widget _buildThemeEntryCard(
    BuildContext context, {
    required _AdvancedThemeListEntry entry,
    required String? activeThemeId,
  }) {
    final preset = entry.officialPreset;
    if (preset != null) {
      return _buildOfficialThemeCard(
        context,
        preset,
        isActive: activeThemeId == preset.id.themeId,
      );
    }
    final theme = entry.customTheme!;
    return _buildThemeCard(context, theme, isActive: activeThemeId == theme.id);
  }

  Widget _buildOfficialThemeCard(
    BuildContext context,
    AppOfficialThemePreset preset, {
    required bool isActive,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = _officialThemeSummary(preset);
    return InkWell(
      key: ValueKey('official-theme-${preset.id.id}'),
      borderRadius: BorderRadius.circular(18),
      onTap: _isSaving ? null : () => _applyOfficialTheme(preset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color:
              isActive
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isActive
                    ? colorScheme.primary.withValues(alpha: 0.55)
                    : colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              preset.id.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (isActive) const _OfficialActiveBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.verified_outlined,
                  size: 20,
                  color: colorScheme.primary.withValues(alpha: 0.78),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDualModePreviewStrip(context, summary),
          ],
        ),
      ),
    );
  }

  AdvancedThemeSummary _officialThemeSummary(AppOfficialThemePreset preset) {
    return AdvancedThemeSummary(
      id: preset.id.themeId,
      name: preset.id.label,
      category: '官方主题',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        preset.id.index,
        isUtc: true,
      ),
      lightMode: AdvancedThemeModeSummary.fromConfig(
        preset.lightConfig,
      ).copyWith(clearWallpaperPath: true),
      darkMode: AdvancedThemeModeSummary.fromConfig(
        preset.darkConfig,
      ).copyWith(clearWallpaperPath: true),
      hasCoverGalleryBinding: false,
      hasLaunchImageGallery: false,
      hasBottomNavGallery: false,
      hasAppInterfaceFont: false,
      hasReaderFont: false,
    );
  }

  Widget _buildCustomThemeLockedState() {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 480;
        final message = Text(
          '官方主题可直接使用；创建、编辑、复制、导入导出自定义主题需要会员。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        );
        final button = FilledButton(
          onPressed: () => context.push('/membership'),
          child: const Text('开通会员'),
        );
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child:
              compact
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_outlined,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: message),
                        ],
                      ),
                      const SizedBox(height: 12),
                      button,
                    ],
                  )
                  : Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: message),
                      const SizedBox(width: 12),
                      button,
                    ],
                  ),
        );
      },
    );
  }

  Widget _buildListStatusRow(
    BuildContext context, {
    required AsyncValue<AppAdvancedTheme?> activeThemeAsync,
    required String? activeThemeId,
    required int visibleThemeCount,
  }) {
    final officialPresetId = appOfficialThemePresetIdFromThemeId(activeThemeId);
    final activeThemeName =
        officialPresetId == null
            ? switch (activeThemeAsync) {
              AsyncData(:final value) when value != null => value.name,
              _ => null,
            }
            : appOfficialThemePresetById(officialPresetId).id.label;
    final countLabel =
        _searchQuery.trim().isEmpty &&
                (_selectedCategory?.trim().isEmpty ?? true)
            ? '主题 $visibleThemeCount'
            : '筛选结果 $visibleThemeCount';
    final activeLabel =
        activeThemeName == null ? '当前启用: 未启用' : '当前启用: $activeThemeName';
    return AdvancedThemeListStatusRow(
      countLabel: countLabel,
      activeLabel: activeLabel,
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return AdvancedThemeListToolbar(
      searchController: _searchController,
      searchQuery: _searchQuery,
      selectedCategory: _selectedCategory,
      availableCategories: _availableCategories,
      onSearchChanged: (value) {
        setState(() {
          _searchQuery = value;
          _pruneSelectionForVisibleThemes();
        });
      },
      onSearchCleared: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _pruneSelectionForVisibleThemes();
        });
      },
      onCategorySelected: (value) {
        setState(() {
          _selectedCategory = value?.trim().isEmpty ?? true ? null : value;
          _pruneSelectionForVisibleThemes();
        });
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isFiltering =
        _searchQuery.trim().isNotEmpty ||
        (_selectedCategory?.trim().isNotEmpty ?? false);
    return AdvancedThemeListEmptyState(isFiltering: isFiltering);
  }

  Widget _buildThemeCard(
    BuildContext context,
    AdvancedThemeSummary theme, {
    required bool isActive,
    bool compact = false,
  }) {
    final isSelected = _selectedThemeIds.contains(theme.id);
    return Builder(
      builder:
          (cardContext) => AdvancedThemeSummaryCard(
            theme: theme,
            isActive: isActive,
            isSelected: isSelected,
            isSelectionMode: _isSelectionMode,
            isSaving: _isSaving,
            compact: compact,
            previewStrip: _buildDualModePreviewStrip(context, theme),
            onTap:
                _isSelectionMode
                    ? () => _toggleThemeSelection(theme.id)
                    : () => unawaited(_applyThemeById(theme.id)),
            onLongPress:
                _isSelectionMode
                    ? null
                    : () =>
                        unawaited(_openEditorWithReveal(cardContext, theme.id)),
            onSelectionChanged: (_) => _toggleThemeSelection(theme.id),
            onActionSelected: (action) {
              switch (action) {
                case _AdvancedThemeAction.edit:
                  _openEditor(theme.id);
                case _AdvancedThemeAction.duplicate:
                  unawaited(_duplicateTheme(theme.id));
                case _AdvancedThemeAction.exportZip:
                  unawaited(_exportThemeBundle(theme.id));
                case _AdvancedThemeAction.delete:
                  unawaited(_handleDeleteThemeById(theme.id));
              }
            },
            onApplyPressed: () => unawaited(_applyThemeById(theme.id)),
            onDisablePressed: _disableActiveTheme,
          ),
    );
  }

  Widget _buildSelectionActionBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = _selectedThemeIds.isNotEmpty;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSelectionActionButton(
                context,
                icon:
                    _allVisibleThemesSelected
                        ? Icons.deselect_outlined
                        : Icons.select_all_rounded,
                label: _allVisibleThemesSelected ? '取消全选' : '全选',
                enabled: !_isSaving && _visibleThemes.isNotEmpty,
                onTap: _toggleSelectAllVisibleThemes,
              ),
            ),
            Expanded(
              child: _buildSelectionActionButton(
                context,
                icon: Icons.delete_outline_rounded,
                label: '删除',
                enabled: !_isSaving && hasSelection,
                color: colorScheme.error,
                onTap: () => unawaited(_deleteSelectedThemes()),
              ),
            ),
            Expanded(
              child: _buildSelectionActionButton(
                context,
                icon: Icons.ios_share_outlined,
                label: '导出',
                enabled: !_isSaving && hasSelection,
                onTap: () => unawaited(_exportSelectedThemes()),
              ),
            ),
            Expanded(
              child: _buildSelectionActionButton(
                context,
                icon: Icons.category_outlined,
                label: '分类',
                enabled: !_isSaving && hasSelection,
                onTap: () => unawaited(_updateSelectedThemesCategory()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedColor =
        enabled
            ? (color ?? colorScheme.onSurface)
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: resolvedColor),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: resolvedColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDualModePreviewStrip(
    BuildContext context,
    AdvancedThemeSummary theme,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    const borderRadius = BorderRadius.all(Radius.circular(16));
    return SizedBox(
      height: 112,
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreviewSegment(
                    context,
                    mode: AppAdvancedThemeMode.light,
                    config: theme.lightMode,
                    isLeft: true,
                  ),
                  ClipPath(
                    clipper: _DiagonalSplitClipper(),
                    child: _buildPreviewSegment(
                      context,
                      mode: AppAdvancedThemeMode.dark,
                      config: theme.darkMode,
                      isLeft: false,
                    ),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _DiagonalSplitLinePainter(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSegment(
    BuildContext context, {
    required AppAdvancedThemeMode mode,
    required AdvancedThemeModeSummary config,
    required bool isLeft,
  }) {
    final defaultScheme = _defaultSchemeFor(context, mode);
    final previewConfig = _summaryToPreviewModeConfig(config);
    final palette = resolveAdvancedThemePaletteFromModeConfig(
      defaultScheme,
      previewConfig,
    );
    final label = mode == AppAdvancedThemeMode.light ? '浅色' : '深色';
    final wallpaperPath = config.wallpaperPath?.trim();
    final hasPreviewWallpaper =
        wallpaperPath != null && wallpaperPath.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[palette.backgroundColor, palette.surfaceColor],
        ),
        image:
            hasPreviewWallpaper
                ? DecorationImage(
                  image: _previewWallpaperImageProvider(wallpaperPath),
                  fit: BoxFit.cover,
                  opacity: 0.88,
                )
                : null,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                mode == AppAdvancedThemeMode.light
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 14,
                color: palette.textSecondaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.textSecondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.elevatedSurfaceColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _componentStyleTag(config.componentStyle),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.textSecondaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (config.hasWallpaper)
                Icon(
                  Icons.wallpaper_outlined,
                  size: 14,
                  color: palette.textSecondaryColor,
                ),
              if (config.hasWallpaper && config.hasReaderWallpaper)
                const SizedBox(width: 4),
              if (config.hasReaderWallpaper)
                Icon(
                  Icons.chrome_reader_mode_outlined,
                  size: 14,
                  color: palette.textSecondaryColor,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 8,
            decoration: BoxDecoration(
              color: palette.primaryColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              decoration: BoxDecoration(
                color: palette.cardColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: resolveAppBorderColor(
                    defaultScheme,
                    baseColor: palette.cardBorderColor,
                    containerColor: palette.cardColor,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: isLeft ? 48 : 54,
                    height: 7,
                    decoration: BoxDecoration(
                      color: palette.cardTextColor.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Container(
                    width: isLeft ? 76 : 84,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.textSecondaryColor.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 34,
                      height: 18,
                      decoration: BoxDecoration(
                        color: palette.primaryColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider<Object> _previewWallpaperImageProvider(String wallpaperPath) {
    return _previewImageCache.providerFor(wallpaperPath);
  }

  AppAdvancedThemeModeConfig _summaryToPreviewModeConfig(
    AdvancedThemeModeSummary summary,
  ) {
    return AppAdvancedThemeModeConfig(
      componentStyle: summary.componentStyle,
      colors: AppAdvancedThemeColors(
        primaryColorValue: summary.primaryColorValue,
        backgroundColorValue: summary.backgroundColorValue,
        surfaceColorValue: summary.surfaceColorValue,
        cardColorValue: summary.cardColorValue,
        cardTextColorValue: summary.cardTextColorValue,
        textSecondaryColorValue: summary.textSecondaryColorValue,
      ),
    );
  }

  String _componentStyleTag(AppAdvancedThemeComponentStyle style) {
    final card = switch (style.cardStyle) {
      AppAdvancedThemeCardStyle.soft => '柔和',
      AppAdvancedThemeCardStyle.outlined => '描边',
      AppAdvancedThemeCardStyle.elevated => '抬升',
    };
    final button = switch (style.buttonStyle) {
      AppAdvancedThemeButtonStyle.stadium => '胶囊',
      AppAdvancedThemeButtonStyle.rounded => '圆角',
      AppAdvancedThemeButtonStyle.sharp => '利落',
    };
    return '$card/$button';
  }

  ColorScheme _defaultSchemeFor(
    BuildContext context,
    AppAdvancedThemeMode mode,
  ) {
    final theme = Theme.of(context);
    if (mode == AppAdvancedThemeMode.dark) {
      return theme.brightness == Brightness.dark
          ? theme.colorScheme
          : theme.colorScheme.copyWith(
            surface: const Color(0xFF181D24),
            onSurface: const Color(0xFFE8ECF6),
            onSurfaceVariant: const Color(0xFFB3BDCB),
            primary: const Color(0xFF8EB8FF),
            outlineVariant: const Color(0xFF313844),
          );
    }
    return theme.colorScheme.copyWith(
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF111827),
      onSurfaceVariant: const Color(0xFF667085),
      primary: const Color(0xFF1677FF),
      outlineVariant: const Color(0xFFE5EAF2),
    );
  }
}

class _OfficialActiveBadge extends StatelessWidget {
  const _OfficialActiveBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '当前生效',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DiagonalSplitClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final cutTop = size.width * 0.62;
    final cutBottom = size.width * 0.38;
    return Path()
      ..moveTo(cutTop, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(cutBottom, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DiagonalSplitLinePainter extends CustomPainter {
  const _DiagonalSplitLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.62, 0),
      Offset(size.width * 0.38, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalSplitLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _AdvancedThemeBatchImportSheet extends StatefulWidget {
  const _AdvancedThemeBatchImportSheet({
    required this.importFile,
    required this.onShowImportSupportHelp,
    required this.onImportCompleted,
  });

  final _AdvancedThemeBatchFileImportRunner importFile;
  final Future<void> Function() onShowImportSupportHelp;
  final VoidCallback onImportCompleted;

  @override
  State<_AdvancedThemeBatchImportSheet> createState() =>
      _AdvancedThemeBatchImportSheetState();
}

class _AdvancedThemeBatchImportSheetState
    extends State<_AdvancedThemeBatchImportSheet> {
  List<_AdvancedThemeImportQueueItem> _items =
      const <_AdvancedThemeImportQueueItem>[];
  bool _isImporting = false;
  _AdvancedThemeBatchImportSummary? _summary;
  String _headerMessage = '';

  int get _completedCount {
    return _items
        .where(
          (item) =>
              item.status == _AdvancedThemeImportQueueItemStatus.success ||
              item.status == _AdvancedThemeImportQueueItemStatus.failure,
        )
        .length;
  }

  double? get _progressValue {
    if (_items.isEmpty) {
      return null;
    }
    return _completedCount / _items.length;
  }

  Future<void> _pickFiles() async {
    if (_isImporting) {
      return;
    }
    final picked = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[
        ExternalImportCatalog.advancedThemeImportTypeGroup,
        ExternalImportCatalog.advancedThemeRedTypeGroup,
        ExternalImportCatalog.advancedThemeRgShareTypeGroup,
      ],
      confirmButtonText: '选择主题文件',
    );
    if (!mounted || picked.isEmpty) {
      return;
    }

    final baseItems =
        _summary == null ? _items : const <_AdvancedThemeImportQueueItem>[];
    final existingPaths = baseItems.map((item) => item.path).toSet();
    final additions = <_AdvancedThemeImportQueueItem>[];
    for (final file in picked) {
      if (existingPaths.contains(file.path)) {
        continue;
      }
      additions.add(
        _AdvancedThemeImportQueueItem(
          path: file.path,
          fileName:
              file.name.trim().isEmpty ? p.basename(file.path) : file.name,
          sizeBytes: await _resolveFileLength(file),
          mimeType: file.mimeType,
        ),
      );
      existingPaths.add(file.path);
    }

    if (additions.isEmpty) {
      _showMessage('所选文件已在导入队列中。');
      return;
    }

    setState(() {
      _summary = null;
      _headerMessage = '已加入 ${additions.length} 个文件';
      _items = <_AdvancedThemeImportQueueItem>[...baseItems, ...additions];
    });
  }

  Future<void> _startImport() async {
    if (_isImporting || _items.isEmpty) {
      return;
    }
    setState(() {
      _isImporting = true;
      _summary = null;
      _headerMessage = '准备导入 ${_items.length} 个文件';
      _items = _items
          .map(
            (item) => item.copyWith(
              status: _AdvancedThemeImportQueueItemStatus.pending,
              clearDetail: true,
            ),
          )
          .toList(growable: false);
    });

    var successCount = 0;
    var failureCount = 0;
    String? lastError;

    for (var index = 0; index < _items.length; index += 1) {
      final item = _items[index];
      _updateItem(
        index,
        status: _AdvancedThemeImportQueueItemStatus.reading,
        detail: '准备处理 ${item.fileName}',
      );
      _updateHeaderMessage('正在处理 ${index + 1}/${_items.length}');
      await Future<void>.delayed(const Duration(milliseconds: 16));

      try {
        final summary = await widget.importFile(
          path: item.path,
          mimeType: item.mimeType,
          onProgress: (status, message) {
            _updateItem(index, status: status, detail: message);
            _updateHeaderMessage(message);
          },
        );
        successCount += summary.successCount;
        failureCount += summary.failureCount;
        lastError = summary.lastError ?? lastError;
        _updateItem(
          index,
          status:
              summary.hasSuccess
                  ? _AdvancedThemeImportQueueItemStatus.success
                  : _AdvancedThemeImportQueueItemStatus.failure,
          detail:
              summary.hasSuccess
                  ? '已导入 ${summary.successCount} 个主题'
                  : (summary.lastError ?? '导入失败'),
        );
      } catch (error) {
        final message = formatAdvancedThemeExportError(error);
        failureCount += 1;
        lastError = message;
        _updateItem(
          index,
          status: _AdvancedThemeImportQueueItemStatus.failure,
          detail: message,
        );
      }
    }

    if (!mounted) {
      return;
    }
    if (successCount > 0) {
      widget.onImportCompleted();
    }
    setState(() {
      _isImporting = false;
      _summary = _AdvancedThemeBatchImportSummary(
        successCount: successCount,
        failureCount: failureCount,
        lastError: lastError,
      );
      _headerMessage =
          successCount > 0
              ? '导入完成，成功 $successCount 个主题'
              : (lastError ?? '导入失败');
    });
  }

  Future<int> _resolveFileLength(XFile file) async {
    try {
      final length = await file.length();
      return length < 0 ? 0 : length;
    } catch (_) {
      return 0;
    }
  }

  void _removeItemAt(int index) {
    if (_isImporting) {
      return;
    }
    setState(() {
      _summary = null;
      final next = [..._items]..removeAt(index);
      _items = next;
      _headerMessage = next.isEmpty ? '' : '已选择 ${next.length} 个文件';
    });
  }

  void _updateItem(
    int index, {
    required _AdvancedThemeImportQueueItemStatus status,
    required String detail,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      final next = [..._items];
      next[index] = next[index].copyWith(status: status, detail: detail);
      _items = next;
    });
  }

  void _updateHeaderMessage(String text) {
    if (!mounted) {
      return;
    }
    setState(() {
      _headerMessage = text;
    });
  }

  void _showMessage(String message) {
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone:
          message.contains('失败') ? AppFeedbackTone.error : AppFeedbackTone.info,
      useHaptics: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = _summary;
    final isEmptyState = _items.isEmpty && summary == null && !_isImporting;
    final maxHeightFactor = isEmptyState ? 0.46 : 0.56;
    final currentStep =
        summary != null
            ? 2
            : _isImporting || _items.isNotEmpty
            ? 1
            : 0;
    final steps = <AppTaskStep>[
      AppTaskStep(label: '添加文件', active: currentStep >= 0),
      AppTaskStep(label: '解析导入', active: currentStep >= 1),
      AppTaskStep(label: '完成', active: currentStep >= 2),
    ];

    return PopScope<void>(
      canPop: !_isImporting,
      child: AppTaskBottomSheet(
        title: '批量导入主题',
        maxHeightFactor: maxHeightFactor,
        fitContent: isEmptyState,
        steps: steps,
        trailing: IconButton(
          tooltip: '导入说明',
          onPressed: _isImporting ? null : widget.onShowImportSupportHelp,
          icon: const Icon(Icons.help_outline_rounded),
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_headerMessage.trim().isNotEmpty) ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _headerMessage,
                  key: ValueKey<String>(_headerMessage),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: isEmptyState ? 14 : 8),
            ],
            if (_isImporting || summary != null) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isImporting
                                ? '导入进度 $_completedCount/${_items.length}'
                                : '导入结果',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_isImporting)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: _progressValue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      summary == null
                          ? '正在本地解析、解压并导入主题资源，请保持当前页面。'
                          : summary.hasSuccess
                          ? '成功 ${summary.successCount} 个，失败 ${summary.failureCount} 个。'
                          : (summary.lastError ?? '没有成功导入的主题。'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildEmptyPicker(context),
              )
            else
              Expanded(child: _buildImportQueue(context)),
            if (_items.isNotEmpty && !_isImporting) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: summary == null ? _startImport : _resetQueue,
                  icon: Icon(
                    summary == null
                        ? Icons.file_upload_outlined
                        : Icons.restart_alt_rounded,
                  ),
                  label: Text(summary == null ? '开始导入' : '再导入一批'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _resetQueue() {
    if (_isImporting) {
      return;
    }
    setState(() {
      _items = const <_AdvancedThemeImportQueueItem>[];
      _summary = null;
      _headerMessage = '';
    });
  }

  Widget _buildEmptyPicker(BuildContext context) {
    return AppTaskActionCard(
      title: '添加主题文件',
      description: '支持一次选择多个 ZIP / JSON / RED / RGSHARE 主题文件，也支持导入批量主题包。',
      icon: Icons.add_photo_alternate_outlined,
      dashedBorder: true,
      onTap: _pickFiles,
    );
  }

  Widget _buildImportQueue(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '待导入文件 ${_items.length}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _items[index];
              final statusColor = _statusColor(context, item.status);
              return Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _statusIcon(item.status),
                        color: statusColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.fileName,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatFileSize(item.sizeBytes),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          if (item.detail != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.status.label,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.detail!,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color:
                                    item.status ==
                                            _AdvancedThemeImportQueueItemStatus
                                                .failure
                                        ? colorScheme.error
                                        : colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '移除',
                      onPressed:
                          _isImporting ? null : () => _removeItemAt(index),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _statusIcon(_AdvancedThemeImportQueueItemStatus status) {
    return switch (status) {
      _AdvancedThemeImportQueueItemStatus.pending => Icons.schedule_rounded,
      _AdvancedThemeImportQueueItemStatus.reading => Icons.folder_open_rounded,
      _AdvancedThemeImportQueueItemStatus.parsing => Icons.inventory_2_outlined,
      _AdvancedThemeImportQueueItemStatus.importing => Icons.sync_rounded,
      _AdvancedThemeImportQueueItemStatus.success => Icons.check_circle_rounded,
      _AdvancedThemeImportQueueItemStatus.failure => Icons.error_rounded,
    };
  }

  Color _statusColor(
    BuildContext context,
    _AdvancedThemeImportQueueItemStatus status,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      _AdvancedThemeImportQueueItemStatus.pending =>
        colorScheme.onSurfaceVariant,
      _AdvancedThemeImportQueueItemStatus.reading => colorScheme.primary,
      _AdvancedThemeImportQueueItemStatus.parsing => colorScheme.primary,
      _AdvancedThemeImportQueueItemStatus.importing => colorScheme.primary,
      _AdvancedThemeImportQueueItemStatus.success => Colors.green,
      _AdvancedThemeImportQueueItemStatus.failure => colorScheme.error,
    };
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '大小未知';
    }
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _AdvancedThemeSingleTaskSheet extends StatefulWidget {
  const _AdvancedThemeSingleTaskSheet({
    required this.title,
    required this.description,
    required this.icon,
    required this.processingMessage,
    required this.processingDetail,
    required this.runTask,
  });

  final String title;
  final String description;
  final IconData icon;
  final String processingMessage;
  final String processingDetail;
  final Future<bool> Function(ValueChanged<String> onProgress) runTask;

  @override
  State<_AdvancedThemeSingleTaskSheet> createState() =>
      _AdvancedThemeSingleTaskSheetState();
}

class _AdvancedThemeSingleTaskSheetState
    extends State<_AdvancedThemeSingleTaskSheet> {
  _AdvancedThemeSingleTaskMode _mode = _AdvancedThemeSingleTaskMode.prepare;
  late String _processingDetail = widget.processingDetail;

  List<AppTaskStep> get _steps {
    final current = switch (_mode) {
      _AdvancedThemeSingleTaskMode.prepare => 0,
      _AdvancedThemeSingleTaskMode.processing => 1,
      _AdvancedThemeSingleTaskMode.completed => 2,
    };
    return <AppTaskStep>[
      AppTaskStep(label: '准备导出', active: current >= 0),
      AppTaskStep(label: '处理中', active: current >= 1),
      AppTaskStep(label: '完成', active: current >= 2),
    ];
  }

  Future<void> _start() async {
    setState(() {
      _mode = _AdvancedThemeSingleTaskMode.processing;
    });
    final completed = await widget.runTask(_updateProcessingDetail);
    if (!mounted) {
      return;
    }
    if (!completed) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _mode = _AdvancedThemeSingleTaskMode.completed;
    });
  }

  void _updateProcessingDetail(String detail) {
    if (!mounted) {
      return;
    }
    setState(() {
      _processingDetail = detail;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppTaskBottomSheet(
      title: widget.title,
      trailing: IconButton(
        tooltip: '导出说明',
        onPressed: () {
          showAdaptiveActionSurface<void>(
            context: context,
            maxWidth: 420,
            builder: (context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '导出说明',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('导出统一分为：准备导出 -> 处理中 -> 完成。'),
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
      maxHeightFactor: 0.38,
      fitContent: true,
      steps: _steps,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mode == _AdvancedThemeSingleTaskMode.prepare)
            AppTaskActionCard(
              title: widget.title,
              description: widget.description,
              icon: widget.icon,
              dashedBorder: true,
              onTap: _start,
            )
          else if (_mode == _AdvancedThemeSingleTaskMode.processing)
            ImportExportProgressCard(
              status: ImportExportTaskStatus(
                title: widget.title,
                message: widget.processingMessage,
                detail: _processingDetail,
              ),
            )
          else
            const ImportExportTaskSheet(
              status: ImportExportTaskStatus(
                title: '导出完成',
                message: '已完成',
                result: ImportExportTaskResult.success,
              ),
            ),
        ],
      ),
    );
  }
}
