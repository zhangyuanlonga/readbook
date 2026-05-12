import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_border_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_task_bottom_sheet.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/import_export_task_sheet.dart';
import '../../../app/widgets/import_export_copy.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../application/advanced_theme_export_error_formatter.dart';
import '../application/advanced_theme_resource_reference_service.dart';
import '../application/advanced_theme_service.dart';
import '../../source/application/external_import_diagnostics.dart';
import '../../source/application/external_import_catalog.dart';
import '../../source/application/external_source_import_bridge.dart';
import '../application/advanced_theme_page_flow_coordinator.dart';
import '../application/advanced_theme_provider.dart';
import '../application/mine_page_session_service.dart';
import '../providers.dart';
import 'widgets/image_resource_collection_widgets.dart';

class AdvancedThemeListPage extends ConsumerStatefulWidget {
  const AdvancedThemeListPage({super.key});

  @override
  ConsumerState<AdvancedThemeListPage> createState() =>
      _AdvancedThemeListPageState();
}

enum _AdvancedThemeAction { edit, duplicate, exportJson, exportZip, delete }

enum _ThemeImportPackageKind { official, red, rgshare }

enum _AdvancedThemeListMoreAction {
  importBatch,
  sortThemes,
  floatingEdit,
  selectThemes,
}

enum _AdvancedThemeSortMode { updatedDesc, nameAsc, categoryAsc }

enum _AdvancedThemeExportDispatchStatus { completed, cancelled, failed }

class _AdvancedThemeExportDispatchResult {
  const _AdvancedThemeExportDispatchResult.completed({this.message})
    : status = _AdvancedThemeExportDispatchStatus.completed;

  const _AdvancedThemeExportDispatchResult.cancelled({this.message})
    : status = _AdvancedThemeExportDispatchStatus.cancelled;

  const _AdvancedThemeExportDispatchResult.failed({this.message})
    : status = _AdvancedThemeExportDispatchStatus.failed;

  final _AdvancedThemeExportDispatchStatus status;
  final String? message;

  bool get isCompleted =>
      status == _AdvancedThemeExportDispatchStatus.completed;
}

class _AdvancedThemeDeleteDecision {
  const _AdvancedThemeDeleteDecision({
    required this.confirmed,
    required this.deleteOptions,
  });

  final bool confirmed;
  final AdvancedThemeDeleteOptions deleteOptions;
}

class _AdvancedThemeBatchImportSummary {
  const _AdvancedThemeBatchImportSummary({
    required this.successCount,
    required this.failureCount,
    this.lastError,
  });

  final int successCount;
  final int failureCount;
  final String? lastError;

  bool get hasSuccess => successCount > 0;
}

enum _AdvancedThemeImportQueueItemStatus {
  pending,
  reading,
  parsing,
  importing,
  success,
  failure,
}

enum _AdvancedThemeSingleTaskMode { prepare, processing, completed }

extension on _AdvancedThemeImportQueueItemStatus {
  String get label => switch (this) {
    _AdvancedThemeImportQueueItemStatus.pending => '待处理',
    _AdvancedThemeImportQueueItemStatus.reading => '读取文件',
    _AdvancedThemeImportQueueItemStatus.parsing => '解析内容',
    _AdvancedThemeImportQueueItemStatus.importing => '导入主题',
    _AdvancedThemeImportQueueItemStatus.success => '导入完成',
    _AdvancedThemeImportQueueItemStatus.failure => '导入失败',
  };
}

class _AdvancedThemeImportQueueItem {
  const _AdvancedThemeImportQueueItem({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    this.mimeType,
    this.status = _AdvancedThemeImportQueueItemStatus.pending,
    this.detail,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final String? mimeType;
  final _AdvancedThemeImportQueueItemStatus status;
  final String? detail;

  _AdvancedThemeImportQueueItem copyWith({
    _AdvancedThemeImportQueueItemStatus? status,
    String? detail,
    bool clearDetail = false,
  }) {
    return _AdvancedThemeImportQueueItem(
      path: path,
      fileName: fileName,
      sizeBytes: sizeBytes,
      mimeType: mimeType,
      status: status ?? this.status,
      detail: clearDetail ? null : (detail ?? this.detail),
    );
  }
}

typedef _AdvancedThemeBatchImportProgressCallback =
    void Function(_AdvancedThemeImportQueueItemStatus status, String message);

typedef _AdvancedThemeBatchFileImportRunner =
    Future<_AdvancedThemeBatchImportSummary> Function({
      required String path,
      String? mimeType,
      _AdvancedThemeBatchImportProgressCallback? onProgress,
    });

class _AdvancedThemeListPageState extends ConsumerState<AdvancedThemeListPage> {
  static const String _batchBundleType = 'advanced_theme_batch_bundle';
  static const int _batchBundleVersion = 1;

  late final AuthSessionStore _sessionStore;
  late final MinePageSessionService _sessionService;
  late final AdvancedThemePageFlowCoordinator _pageFlowCoordinator;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, ImageProvider<Object>> _previewWallpaperImageProviders =
      <String, ImageProvider<Object>>{};
  List<AdvancedThemeSummary> _themeSummaries = const <AdvancedThemeSummary>[];
  String _searchQuery = '';
  String? _selectedCategory;
  Set<String> _selectedThemeIds = <String>{};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isConsumingExternalImportPayloads = false;
  bool _isAccessLoading = true;
  bool _canUseAdvancedThemes = false;
  bool _isSelectionMode = false;
  bool _floatingEditEnabled = false;
  _AdvancedThemeSortMode _themeSortMode = _AdvancedThemeSortMode.updatedDesc;
  String? _savingStatusText;
  int _summaryLoadToken = 0;

  @override
  void initState() {
    super.initState();
    _sessionStore = ref.read(mineAuthSessionStoreProvider);
    _sessionService = ref.read(minePageSessionServiceProvider);
    _pageFlowCoordinator =
        ref.read(advancedThemePageFlowCoordinatorFactoryProvider)();
    _pageFlowCoordinator.initialize(
      onPendingImportAvailable: () {
        unawaited(_consumePendingExternalImportPayloads());
      },
      onAuthEvent: _handleAuthEvent,
    );
    _loadAccess(refreshRemote: false);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumePendingExternalImportPayloads());
    });
  }

  Future<void> _loadAccess({required bool refreshRemote}) async {
    final session = await _sessionStore.getSession();
    if (!mounted) {
      return;
    }
    if (session == null) {
      setState(() {
        _canUseAdvancedThemes = false;
        _isAccessLoading = false;
      });
      return;
    }

    final snapshot = await _sessionService.loadSession(
      refreshRemote: refreshRemote,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _canUseAdvancedThemes = snapshot.hasThemeCustom;
      _isAccessLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    unawaited(_pageFlowCoordinator.dispose());
    super.dispose();
  }

  void _handleAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.loggedIn:
        unawaited(_loadAccess(refreshRemote: true));
        break;
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        unawaited(_loadAccess(refreshRemote: false));
        break;
    }
  }

  Future<void> _load() async {
    final service = ref.read(advancedThemeServiceProvider);
    final loadToken = ++_summaryLoadToken;
    final themes = await service.loadThemeSummaries();
    if (!mounted) {
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
  }

  Future<void> _hydrateThemePreviewSummaries(
    int loadToken,
    List<AdvancedThemeSummary> currentSummaries,
  ) async {
    final service = ref.read(advancedThemeServiceProvider);
    final hydrated = await service.hydrateThemeSummaryPreviewPaths(
      currentSummaries,
    );
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
    return List<AdvancedThemeSummary>.from(themes)..sort((a, b) {
      final aIsActive = a.id == activeThemeId;
      final bIsActive = b.id == activeThemeId;
      if (aIsActive != bIsActive) {
        return aIsActive ? -1 : 1;
      }
      return switch (_themeSortMode) {
        _AdvancedThemeSortMode.updatedDesc => b.updatedAt.compareTo(
          a.updatedAt,
        ),
        _AdvancedThemeSortMode.nameAsc => a.name.compareTo(b.name),
        _AdvancedThemeSortMode.categoryAsc => _compareThemeCategory(a, b),
      };
    });
  }

  int _compareThemeCategory(AdvancedThemeSummary a, AdvancedThemeSummary b) {
    final categoryA = a.category?.trim() ?? '';
    final categoryB = b.category?.trim() ?? '';
    if (categoryA.isNotEmpty && categoryB.isNotEmpty) {
      final compare = categoryA.compareTo(categoryB);
      if (compare != 0) {
        return compare;
      }
    } else if (categoryA.isNotEmpty) {
      return -1;
    } else if (categoryB.isNotEmpty) {
      return 1;
    }
    return a.name.compareTo(b.name);
  }

  bool _hasSamePreviewContent(
    List<AdvancedThemeSummary> previous,
    List<AdvancedThemeSummary> next,
  ) {
    for (var index = 0; index < previous.length; index += 1) {
      final previousItem = previous[index];
      final nextItem = next[index];
      if (previousItem.id != nextItem.id) {
        return false;
      }
      if (previousItem.lightMode.wallpaperPath !=
              nextItem.lightMode.wallpaperPath ||
          previousItem.darkMode.wallpaperPath !=
              nextItem.darkMode.wallpaperPath) {
        return false;
      }
    }
    return true;
  }

  List<String> get _availableCategories {
    final categories = _themeSummaries
      .map((theme) => theme.category?.trim() ?? '')
      .where((category) => category.isNotEmpty)
      .toSet()
      .toList(growable: false)..sort();
    return categories;
  }

  List<AdvancedThemeSummary> get _visibleThemes {
    final keyword = _searchQuery.trim().toLowerCase();
    final selectedCategory = _selectedCategory?.trim() ?? '';
    return _themeSummaries
        .where((theme) {
          if (selectedCategory.isNotEmpty &&
              (theme.category?.trim() ?? '') != selectedCategory) {
            return false;
          }
          if (keyword.isEmpty) {
            return true;
          }
          final haystacks = <String>[
            theme.name,
            theme.category ?? '',
          ].map((item) => item.toLowerCase());
          return haystacks.any((item) => item.contains(keyword));
        })
        .toList(growable: false);
  }

  List<AdvancedThemeSummary> get _selectedVisibleThemes {
    return _visibleThemes
        .where((theme) => _selectedThemeIds.contains(theme.id))
        .toList(growable: false);
  }

  bool get _allVisibleThemesSelected {
    final visibleThemes = _visibleThemes;
    return visibleThemes.isNotEmpty &&
        visibleThemes.every((theme) => _selectedThemeIds.contains(theme.id));
  }

  void _pruneSelectionForVisibleThemes() {
    if (!_isSelectionMode) {
      return;
    }
    final visibleIds = _visibleThemes.map((theme) => theme.id).toSet();
    _selectedThemeIds =
        _selectedThemeIds.where((id) => visibleIds.contains(id)).toSet();
    if (_selectedThemeIds.isEmpty) {
      _isSelectionMode = false;
    }
  }

  void _enterSelectionMode() {
    if (_isSaving || _visibleThemes.isEmpty) {
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

  Future<void> _openEditor([String? themeId]) async {
    final result = await context.push<String>(
      themeId == null || themeId.trim().isEmpty
          ? '/appearance/advanced-themes/editor'
          : '/appearance/advanced-themes/editor?id=$themeId',
    );
    await _load();
    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }
    _showMessage(result);
  }

  Future<void> _openEditorDialog(String themeId) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('编辑主题'),
          content: const Text('将打开主题编辑器。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_openEditor(themeId));
              },
              child: const Text('编辑'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showThemeSortDialog() async {
    final selected = await showDialog<_AdvancedThemeSortMode>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('排序主题'),
          content: RadioGroup<_AdvancedThemeSortMode>(
            groupValue: _themeSortMode,
            onChanged: (value) => Navigator.of(dialogContext).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                RadioListTile<_AdvancedThemeSortMode>(
                  value: _AdvancedThemeSortMode.updatedDesc,
                  title: Text('最近更新'),
                ),
                RadioListTile<_AdvancedThemeSortMode>(
                  value: _AdvancedThemeSortMode.nameAsc,
                  title: Text('名称 A-Z'),
                ),
                RadioListTile<_AdvancedThemeSortMode>(
                  value: _AdvancedThemeSortMode.categoryAsc,
                  title: Text('分类优先'),
                ),
              ],
            ),
          ),
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

  Future<void> _duplicateTheme(String themeId) async {
    if (_isSaving) {
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

  Future<void> _exportTheme(String themeId) async {
    final theme = await _loadThemeDetail(themeId);
    if (theme == null || !mounted) {
      if (mounted) {
        _showMessage('主题不存在或已被删除');
      }
      return;
    }
    await _showAdvancedThemeSingleTaskSheet(
      title: '导出颜色配置',
      description: '导出当前主题的颜色 JSON 配置。',
      icon: Icons.palette_outlined,
      processingMessage: theme.name,
      processingDetail: '准备导出颜色配置',
      runTask: (onProgress) => _runExportTheme(theme, onProgress),
    );
  }

  Future<void> _exportThemeBundle(String themeId) async {
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

  bool get _shouldUseSaveLocationPicker {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
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
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
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

  Future<bool> _runExportTheme(
    AppAdvancedTheme theme, [
    ValueChanged<String>? onProgress,
  ]) async {
    setState(() {
      _isSaving = true;
    });
    try {
      onProgress?.call('正在准备导出颜色配置…');
      final service = ref.read(advancedThemeServiceProvider);
      final fileName = '${_normalizedFileName(theme.name)}.json';
      final content = service.encodeThemeColorJson(theme);
      String? successMessage;
      if (_shouldUseSaveLocationPicker) {
        final location = await getSaveLocation(
          acceptedTypeGroups: const <XTypeGroup>[
            ExternalImportCatalog.advancedThemeJsonTypeGroup,
          ],
          suggestedName: fileName,
          confirmButtonText: '导出',
        );
        if (location == null) {
          _showMessage('已取消导出颜色配置');
          return false;
        }
        final file = File(location.path);
        await file.writeAsString(content, flush: true);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(content, flush: true);
        final shareResult = await _shareExportedThemeFile(
          file: file,
          text: '分享颜色主题：${theme.name}',
          subject: theme.name,
          clipboardText: content,
          onProgress: onProgress,
        );
        if (!mounted) {
          return false;
        }
        if (!shareResult.isCompleted) {
          _showMessage(shareResult.message ?? '已取消导出颜色配置');
          return false;
        }
        successMessage = shareResult.message;
      }
      if (!mounted) {
        return false;
      }
      _showMessage(successMessage ?? '已导出颜色配置「${theme.name}」');
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      _showMessage('导出失败：${formatAdvancedThemeExportError(error)}');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _runExportThemeBundle(
    AppAdvancedTheme theme, [
    ValueChanged<String>? onProgress,
  ]) async {
    setState(() {
      _isSaving = true;
    });
    try {
      onProgress?.call('正在准备导出主题包…');
      final service = ref.read(advancedThemeServiceProvider);
      final fileName = '${_normalizedFileName(theme.name)}.zip';
      final bytes = await service.encodeThemeBundleZip(theme);
      String? successMessage;
      if (_shouldUseSaveLocationPicker) {
        final location = await getSaveLocation(
          acceptedTypeGroups: const <XTypeGroup>[
            ExternalImportCatalog.advancedThemeZipTypeGroup,
          ],
          suggestedName: fileName,
          confirmButtonText: '导出',
        );
        if (location == null) {
          _showMessage('已取消导出主题包');
          return false;
        }
        final file = File(location.path);
        await file.writeAsBytes(bytes, flush: true);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        final shareResult = await _shareExportedThemeFile(
          file: file,
          text: '分享主题包：${theme.name}',
          subject: theme.name,
          onProgress: onProgress,
        );
        if (!mounted) {
          return false;
        }
        if (!shareResult.isCompleted) {
          _showMessage(shareResult.message ?? '已取消导出主题包');
          return false;
        }
        successMessage = shareResult.message;
      }
      if (!mounted) {
        return false;
      }
      _showMessage(successMessage ?? '已导出主题包「${theme.name}」');
      return true;
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
    if (_isConsumingExternalImportPayloads || !mounted) {
      return;
    }

    _isConsumingExternalImportPayloads = true;
    try {
      await _pageFlowCoordinator.consumePendingPayloads(
        _importFromExternalPayload,
      );
    } finally {
      _isConsumingExternalImportPayloads = false;
    }
  }

  Future<void> _importFromExternalPayload(
    IncomingExternalImportPayload payload,
  ) async {
    setState(() {
      _isSaving = true;
      _savingStatusText = '正在读取外部主题文件并准备导入…';
    });

    CachedExternalImportFile? cached;
    try {
      cached = await _pageFlowCoordinator.cacheExternalFileFromUri(payload);
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
      if (!ExternalImportCatalog.supportsFileLabel(
        ExternalImportPayloadType.advancedTheme,
        cached.label,
      )) {
        ExternalImportDiagnostics.logImportUnsupported(
          ExternalImportPayloadType.advancedTheme,
          cached.label,
        );
        _showMessage(
          ExternalImportCatalog.unsupportedFileMessage(
            ExternalImportPayloadType.advancedTheme,
            cached.label,
          ),
        );
        return;
      }
      final mimeType = cached.mimeType ?? payload.mimeType;
      if (_isBatchBundleFile(path: cached.path, mimeType: mimeType)) {
        final summary = await _importThemeBatchFile(
          path: cached.path,
          mimeType: mimeType,
          onProgress: (_, message) => _updateSavingStatus(message),
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
        _showBatchImportSummary(summary);
        return;
      }
      final importedTheme = await _importThemeFromPath(
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
      _showMessage(
        ExternalImportDiagnostics.importFailedMessage(
          ExternalImportPayloadType.advancedTheme,
          '$error',
          label: cached?.label ?? payload.label,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingStatusText = null;
        });
      }
    }
  }

  Future<AppAdvancedTheme> _importThemeFromPath({
    required String path,
    String? mimeType,
    _ThemeImportPackageKind? packageKind,
    bool reloadAfterImport = true,
    bool markRevision = true,
  }) async {
    final service = ref.read(advancedThemeServiceProvider);
    final effectiveKind =
        packageKind ?? await _detectPackageKind(path: path, mimeType: mimeType);
    if (effectiveKind == _ThemeImportPackageKind.official &&
        _isZipThemeFile(path: path, mimeType: mimeType)) {
      final importedTheme = await service.importThemeBundleZipFile(path);
      if (markRevision) {
        ref.read(advancedThemeRevisionProvider.notifier).markChanged();
      }
      if (reloadAfterImport) {
        await _load();
      }
      return importedTheme;
    }
    final bytes = await File(path).readAsBytes();
    return _importThemeBytes(
      path: path,
      bytes: bytes,
      mimeType: mimeType,
      packageKind: effectiveKind,
      reloadAfterImport: reloadAfterImport,
      markRevision: markRevision,
    );
  }

  Future<AppAdvancedTheme> _importThemeBytes({
    required String path,
    required List<int> bytes,
    String? mimeType,
    _ThemeImportPackageKind? packageKind,
    bool reloadAfterImport = true,
    bool markRevision = true,
  }) async {
    final service = ref.read(advancedThemeServiceProvider);
    final effectiveKind =
        packageKind ??
        await _detectPackageKind(path: path, mimeType: mimeType, bytes: bytes);
    final importedTheme = switch (effectiveKind) {
      _ThemeImportPackageKind.red => await service.importRedThemePackageBytes(
        bytes,
      ),
      _ThemeImportPackageKind.rgshare => await service
          .importRgShareThemePackageBytes(bytes),
      _ThemeImportPackageKind.official =>
        _isZipThemeFile(path: path, mimeType: mimeType, bytes: bytes)
            ? await service.importThemeBundleZipBytes(bytes)
            : await service.importThemeColorJson(utf8.decode(bytes)),
    };
    if (markRevision) {
      ref.read(advancedThemeRevisionProvider.notifier).markChanged();
    }
    if (reloadAfterImport) {
      await _load();
    }
    return importedTheme;
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
    final summary =
        await showModalBottomSheet<_AdvancedThemeBatchImportSummary>(
          context: context,
          isScrollControlled: true,
          isDismissible: true,
          enableDrag: true,
          useSafeArea: true,
          builder: (sheetContext) {
            return _AdvancedThemeBatchImportSheet(
              importFile: _importThemeBatchFile,
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
    onProgress?.call(
      _AdvancedThemeImportQueueItemStatus.reading,
      ImportExportCopy.importPreparing,
    );
    await _yieldToUi();
    if (_isBatchBundleFile(path: path, mimeType: mimeType)) {
      onProgress?.call(
        _AdvancedThemeImportQueueItemStatus.parsing,
        '正在解析批量主题包',
      );
      await _yieldToUi();
      return _importThemeBatchBundleFile(path, onProgress: onProgress);
    }
    final bytes = await File(path).readAsBytes();
    onProgress?.call(_AdvancedThemeImportQueueItemStatus.importing, '正在导入主题资源');
    await _yieldToUi();
    await _importThemeBytes(
      path: path,
      bytes: bytes,
      mimeType: mimeType,
      reloadAfterImport: false,
      markRevision: false,
    );
    return const _AdvancedThemeBatchImportSummary(
      successCount: 1,
      failureCount: 0,
    );
  }

  Future<_AdvancedThemeBatchImportSummary> _importThemeBatchBundleFile(
    String path, {
    _AdvancedThemeBatchImportProgressCallback? onProgress,
  }) async {
    final input = InputFileStream(path);
    final archive = ZipDecoder().decodeStream(input, verify: false);
    input.close();
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const FormatException('批量主题包缺少 manifest.json。');
    }
    final decoded = jsonDecode(
      utf8.decode(List<int>.from(manifestFile.content), allowMalformed: true),
    );
    if (decoded is! Map) {
      throw const FormatException('批量主题包配置无效。');
    }
    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final type = manifest['type']?.toString().trim() ?? '';
    if (type != _batchBundleType) {
      throw const FormatException('不支持的批量主题包类型。');
    }
    final version = manifest['version'];
    final normalizedVersion =
        version is num ? version.toInt() : int.tryParse('$version');
    if (normalizedVersion != _batchBundleVersion) {
      throw const FormatException('不支持的批量主题包版本。');
    }

    final entries = manifest['themes'];
    if (entries is! List || entries.isEmpty) {
      throw const FormatException('批量主题包中没有可导入的主题。');
    }

    var successCount = 0;
    var failureCount = 0;
    String? lastError;
    final tempDir = await getTemporaryDirectory();
    final workingDirectory = Directory(
      '${tempDir.path}/advanced_theme_batch_import_${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!await workingDirectory.exists()) {
      await workingDirectory.create(recursive: true);
    }
    final importableEntries = entries.whereType<Map>().toList(growable: false);
    try {
      for (var index = 0; index < importableEntries.length; index += 1) {
        final item = importableEntries[index];
        final entry = item.map((key, value) => MapEntry(key.toString(), value));
        final bundlePath = entry['file']?.toString().trim() ?? '';
        if (bundlePath.isEmpty) {
          failureCount += 1;
          lastError = '批量主题包条目缺少文件路径。';
          continue;
        }
        final themeName = entry['name']?.toString().trim() ?? '';
        onProgress?.call(
          _AdvancedThemeImportQueueItemStatus.importing,
          themeName.isEmpty
              ? '正在导入主题 ${index + 1}/${importableEntries.length}'
              : '正在导入 $themeName ${index + 1}/${importableEntries.length}',
        );
        await _yieldToUi();
        final archiveFile = archive.findFile(bundlePath);
        if (archiveFile == null) {
          failureCount += 1;
          lastError = '批量主题包缺少主题文件：$bundlePath';
          continue;
        }
        final tempThemeFile = File(
          '${workingDirectory.path}/${index.toString().padLeft(3, '0')}.zip',
        );
        try {
          final output = OutputFileStream(tempThemeFile.path);
          archiveFile.writeContent(output);
          output.close();
          await _importThemeFromPath(
            path: tempThemeFile.path,
            mimeType: 'application/zip',
            packageKind: _ThemeImportPackageKind.official,
            reloadAfterImport: false,
            markRevision: false,
          );
          successCount += 1;
        } catch (error) {
          failureCount += 1;
          lastError = formatAdvancedThemeExportError(error);
        } finally {
          if (await tempThemeFile.exists()) {
            await tempThemeFile.delete();
          }
        }
      }
    } finally {
      if (await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }
    }

    if (successCount == 0) {
      throw FormatException(lastError ?? '批量主题包中没有成功导入的主题。');
    }
    return _AdvancedThemeBatchImportSummary(
      successCount: successCount,
      failureCount: failureCount,
      lastError: lastError,
    );
  }

  bool _isBatchBundleFile({
    required String path,
    String? mimeType,
    List<int>? bytes,
  }) {
    if (!_isZipThemeFile(path: path, mimeType: mimeType, bytes: bytes)) {
      return false;
    }
    try {
      Archive archive;
      if (bytes == null) {
        final input = InputFileStream(path);
        try {
          archive = ZipDecoder().decodeStream(input, verify: false);
        } finally {
          input.close();
        }
      } else {
        archive = ZipDecoder().decodeBytes(bytes, verify: false);
      }
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        return false;
      }
      final decoded = jsonDecode(
        utf8.decode(List<int>.from(manifestFile.content), allowMalformed: true),
      );
      if (decoded is! Map) {
        return false;
      }
      final manifest = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return manifest['type']?.toString().trim() == _batchBundleType;
    } catch (_) {
      return false;
    }
  }

  Future<void> _exportSelectedThemes() async {
    if (_isSaving) {
      return;
    }
    final targetThemes = _selectedVisibleThemes;
    if (targetThemes.isEmpty) {
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
      final fileName =
          'advanced_themes_batch_${_formattedTimestampForFileName(DateTime.now())}.zip';
      File? outputFile;
      String? successMessage;
      if (_shouldUseSaveLocationPicker) {
        final location = await getSaveLocation(
          acceptedTypeGroups: const <XTypeGroup>[
            ExternalImportCatalog.advancedThemeZipTypeGroup,
          ],
          suggestedName: fileName,
          confirmButtonText: '导出',
        );
        if (location == null) {
          if (mounted) {
            _showMessage('已取消批量导出');
          }
          return;
        }
        outputFile = File(location.path);
        await _buildThemeBatchBundleFile(
          summaries: targetThemes,
          outputFile: outputFile,
          onProgress: _updateSavingStatus,
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        outputFile = File('${tempDir.path}/$fileName');
        await _buildThemeBatchBundleFile(
          summaries: targetThemes,
          outputFile: outputFile,
          onProgress: _updateSavingStatus,
        );
        _updateSavingStatus('正在打开系统分享...');
        final shareResult = await _shareExportedThemeFile(
          file: outputFile,
          text: '分享高级主题包，共 ${targetThemes.length} 个主题',
          subject: '高级主题批量导出',
        );
        if (!mounted) {
          return;
        }
        if (!shareResult.isCompleted) {
          _showMessage(shareResult.message ?? '已取消批量导出');
          return;
        }
        successMessage = shareResult.message;
      }
      if (!mounted) {
        return;
      }
      _showMessage(successMessage ?? '已导出 ${targetThemes.length} 个主题');
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

  Future<void> _buildThemeBatchBundleFile({
    required List<AdvancedThemeSummary> summaries,
    required File outputFile,
    ValueChanged<String>? onProgress,
  }) async {
    final service = ref.read(advancedThemeServiceProvider);
    final manifestThemes = <Map<String, Object?>>[];
    final tempDir = await getTemporaryDirectory();
    final workingDirectory = Directory(
      '${tempDir.path}/advanced_theme_batch_work_${DateTime.now().microsecondsSinceEpoch}',
    );
    var index = 0;

    if (!await workingDirectory.exists()) {
      await workingDirectory.create(recursive: true);
    }

    final encoder = ZipFileEncoder();
    var encoderCreated = false;
    try {
      encoder.create(outputFile.path, level: ZipFileEncoder.gzip);
      encoderCreated = true;
      for (final summary in summaries) {
        final theme = await _loadThemeDetail(summary.id);
        if (theme == null) {
          continue;
        }
        // Keep export strictly sequential so dozens of themes won't amplify
        // memory usage by building multiple theme bundles at the same time.
        index += 1;
        onProgress?.call('正在打包 ${theme.name} ($index/${summaries.length})');
        final normalizedName = _normalizedFileName(theme.name);
        final innerZipName =
            '${index.toString().padLeft(3, '0')}_$normalizedName.zip';
        final tempThemeFile = File('${workingDirectory.path}/$innerZipName');
        final bundleBytes = await service.encodeThemeBundleZip(theme);
        await tempThemeFile.writeAsBytes(bundleBytes, flush: true);
        final bundlePath = 'themes/$innerZipName';
        await encoder.addFile(tempThemeFile, bundlePath);
        manifestThemes.add(<String, Object?>{
          'id': theme.id,
          'name': theme.name,
          'file': bundlePath,
        });
        if (await tempThemeFile.exists()) {
          await tempThemeFile.delete();
        }
        await _yieldToUi();
      }

      if (manifestThemes.isEmpty) {
        throw const FormatException('没有可打包的主题内容。');
      }

      onProgress?.call('正在写入批量导出清单...');
      final manifestBytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'type': _batchBundleType,
          'version': _batchBundleVersion,
          'generatedAt': DateTime.now().toIso8601String(),
          'themes': manifestThemes,
        }),
      );
      encoder.addArchiveFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      );
    } finally {
      if (encoderCreated) {
        await encoder.close();
      }
      if (await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _deleteSelectedThemes() async {
    if (_isSaving) {
      return;
    }
    final selectedThemes = _selectedVisibleThemes;
    if (selectedThemes.isEmpty) {
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
      if (successCount == 0) {
        _showMessage('批量删除失败，请稍后重试。');
        return;
      }
      if (failureCount > 0) {
        _showMessage('已删除 $successCount 个主题，失败 $failureCount 个。');
      } else {
        _showMessage('已删除 $successCount 个主题。');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool?> _showBatchDeleteDialog(int count) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('批量删除主题'),
          content: Text(
            '确定删除已选 $count 个主题吗？\n\n会按默认策略一并处理主题绑定的壁纸、图集等资源；仍被其他主题引用的共享资源会自动保留。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
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
    final selectedThemes = _selectedVisibleThemes;
    if (selectedThemes.isEmpty) {
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
      final selectedIds = selectedThemes.map((theme) => theme.id).toSet();
      final updatedThemes = (await service.loadThemes())
          .map((theme) {
            if (!selectedIds.contains(theme.id)) {
              return theme;
            }
            return nextCategory == null
                ? theme.copyWith(clearCategory: true)
                : theme.copyWith(category: nextCategory);
          })
          .toList(growable: false);
      await service.saveThemes(updatedThemes);
      ref.read(advancedThemeRevisionProvider.notifier).markChanged();
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage(
        nextCategory == null
            ? '已清空 ${selectedThemes.length} 个主题的分类'
            : '已将 ${selectedThemes.length} 个主题归类到「$nextCategory」',
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
    return showDialog<String>(
      context: context,
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

            return AlertDialog(
              title: const Text('批量分类'),
              content: Column(
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
              actions: [
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
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('兼容导入说明'),
          content: const Text(
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
            '两种兼容导入都不支持完整还原原应用的阅读器排版、字体、页眉页脚模板和交互行为。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  Future<_ThemeImportPackageKind> _detectPackageKind({
    required String path,
    String? mimeType,
    List<int>? bytes,
  }) async {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    final normalizedExtension = p.extension(path).trim().toLowerCase();
    if (normalizedExtension == '.rgshare') {
      return _ThemeImportPackageKind.rgshare;
    }
    if (normalizedMime.contains('octet-stream') &&
        normalizedExtension == '.red') {
      return _ThemeImportPackageKind.red;
    }
    if (normalizedExtension == '.red') {
      return _ThemeImportPackageKind.red;
    }
    final resolvedBytes = bytes ?? await File(path).readAsBytes();
    final sniffedKind = _detectPackageKindFromBytes(resolvedBytes);
    if (sniffedKind != null) {
      return sniffedKind;
    }
    if (normalizedExtension == '.zip') {
      return _ThemeImportPackageKind.official;
    }
    if (normalizedExtension == '.json') {
      return _ThemeImportPackageKind.official;
    }
    try {
      if (_looksLikeThemeColorJson(
        utf8.decode(resolvedBytes, allowMalformed: true),
      )) {
        return _ThemeImportPackageKind.official;
      }
    } catch (_) {
      // Fall through to the default package kind.
    }
    return _ThemeImportPackageKind.official;
  }

  _ThemeImportPackageKind? _detectPackageKindFromBytes(List<int> bytes) {
    if (_hasRedHeader(bytes)) {
      return _ThemeImportPackageKind.red;
    }
    if (!_looksLikeZip(bytes)) {
      return null;
    }

    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      if (archive.findFile('manifest.json') != null) {
        return _ThemeImportPackageKind.official;
      }
      final themeFile = archive.findFile('theme.json');
      if (themeFile == null) {
        return _ThemeImportPackageKind.official;
      }
      final decoded = jsonDecode(
        utf8.decode(List<int>.from(themeFile.content), allowMalformed: true),
      );
      if (decoded is! Map) {
        return _ThemeImportPackageKind.official;
      }
      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (_looksLikeRgShareTheme(payload)) {
        return _ThemeImportPackageKind.rgshare;
      }
      if (_looksLikeRedTheme(payload)) {
        return _ThemeImportPackageKind.red;
      }
    } catch (_) {
      return null;
    }
    return _ThemeImportPackageKind.official;
  }

  bool _looksLikeRgShareTheme(Map<String, dynamic> payload) {
    return payload.containsKey('1') &&
        payload.containsKey('2') &&
        payload.containsKey('4');
  }

  bool _looksLikeRedTheme(Map<String, dynamic> payload) {
    return payload['light'] is Map && payload['dark'] is Map;
  }

  bool _looksLikeThemeColorJson(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        return false;
      }
      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return payload['type']?.toString().trim() == 'advanced_theme_colors';
    } catch (_) {
      return false;
    }
  }

  bool _hasRedHeader(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x44;
  }

  bool _looksLikeZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  bool _isZipThemeFile({
    required String path,
    String? mimeType,
    List<int>? bytes,
  }) {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    if (normalizedMime.contains('zip')) {
      return true;
    }
    if (p.extension(path).trim().toLowerCase() == '.zip') {
      return true;
    }
    return bytes != null && _looksLikeZip(bytes);
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
    final decision = await _showDeleteThemeSheet(
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
    final theme = await _loadThemeDetail(themeId);
    if (theme == null) {
      if (mounted) {
        _showMessage('主题不存在或已被删除');
      }
      return;
    }
    await _deleteTheme(theme);
  }

  Future<_AdvancedThemeDeleteDecision?> _showDeleteThemeSheet({
    required AppAdvancedTheme theme,
    required AdvancedThemeDeletePreview preview,
  }) {
    return showModalBottomSheet<_AdvancedThemeDeleteDecision>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final selections = <AdvancedThemeDeleteOptionKind, bool>{
          for (final section in preview.sections)
            section.kind: section.defaultSelected,
        };
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '删除高级主题',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '即将删除「${theme.name}」。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (preview.sections.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (final section in preview.sections) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: CheckboxListTile(
                                value: selections[section.kind] ?? false,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  section.title,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                onChanged: (value) {
                                  setSheetState(() {
                                    selections[section.kind] = value ?? false;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  () => Navigator.of(sheetContext).pop(
                                    const _AdvancedThemeDeleteDecision(
                                      confirmed: false,
                                      deleteOptions:
                                          AdvancedThemeDeleteOptions.none(),
                                    ),
                                  ),
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop(
                                  _AdvancedThemeDeleteDecision(
                                    confirmed: true,
                                    deleteOptions: AdvancedThemeDeleteOptions(
                                      deleteAppearanceWallpapers:
                                          selections[AdvancedThemeDeleteOptionKind
                                              .appearanceWallpapers] ??
                                          false,
                                      deleteReaderWallpapers:
                                          selections[AdvancedThemeDeleteOptionKind
                                              .readerWallpapers] ??
                                          false,
                                      deleteCoverGalleries:
                                          selections[AdvancedThemeDeleteOptionKind
                                              .coverGalleries] ??
                                          false,
                                      deleteLaunchImageGallery:
                                          selections[AdvancedThemeDeleteOptionKind
                                              .launchImageGallery] ??
                                          false,
                                      deleteBottomNavGallery:
                                          selections[AdvancedThemeDeleteOptionKind
                                              .bottomNavGallery] ??
                                          false,
                                      deleteFonts:
                                          selections[AdvancedThemeDeleteOptionKind
                                              .fonts] ??
                                          false,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('删除'),
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
  }

  Future<void> _applyTheme(AppAdvancedTheme theme) async {
    if (_isSaving) {
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _normalizedFileName(String name) {
    final normalized = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    return normalized.isEmpty ? 'advanced_theme_colors' : normalized;
  }

  String _formattedTimestampForFileName(DateTime value) {
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}_${twoDigits(value.hour)}${twoDigits(value.minute)}${twoDigits(value.second)}';
  }

  Future<void> _yieldToUi() {
    return Future<void>.delayed(const Duration(milliseconds: 16));
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
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
        appBar: AppBar(
          leading: IconButton(
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
          ),
          title: Text(
            _isSelectionMode
                ? _selectedThemeIds.isEmpty
                    ? '选择主题'
                    : '已选 ${_selectedThemeIds.length} 个主题'
                : '高级主题',
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          actions: [
            if (!_isSelectionMode) ...[
              IconButton(
                tooltip: '新建高级主题',
                onPressed: _isLoading || _isSaving ? null : () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
              ),
              PopupMenuButton<_AdvancedThemeListMoreAction>(
                enabled: !_isLoading && !_isSaving,
                tooltip: '更多',
                onSelected: _handleMoreAction,
                itemBuilder:
                    (context) => <PopupMenuEntry<_AdvancedThemeListMoreAction>>[
                      const PopupMenuItem(
                        value: _AdvancedThemeListMoreAction.importBatch,
                        child: Text('批量导入'),
                      ),
                      const PopupMenuItem(
                        value: _AdvancedThemeListMoreAction.sortThemes,
                        child: Text('排序主题'),
                      ),
                      PopupMenuItem(
                        value: _AdvancedThemeListMoreAction.floatingEdit,
                        child: Row(
                          children: [
                            Icon(
                              _floatingEditEnabled
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Text('悬浮编辑按钮'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: _AdvancedThemeListMoreAction.selectThemes,
                        child: Text('选择主题'),
                      ),
                    ],
              ),
            ],
          ],
        ),
        floatingActionButton:
            !_isSelectionMode &&
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
                final metrics = AppAdaptiveMetrics.of(context);
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
                        : !_canUseAdvancedThemes
                        ? _buildVipLockedState(context, topInset: topInset)
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

  Widget _buildVipLockedState(
    BuildContext context, {
    required double topInset,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, topInset + 18, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'VIP',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '高级主题为会员专属功能',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '开通会员后可创建、导入、导出并管理高级主题，打造更完整的阅读界面风格。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.push('/membership'),
                child: const Text('前往会员页'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavingProgressCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _savingStatusText ?? '处理中...',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
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
    final metrics = AppAdaptiveMetrics.of(context);
    if (metrics.isExpandedWindow) {
      return _buildDesktopThemeWorkspace(
        context,
        activeThemeAsync: activeThemeAsync,
        activeThemeId: activeThemeId,
        visibleThemes: visibleThemes,
        horizontal: horizontal,
        bottomSafe: bottomSafe,
        topInset: topInset,
      );
    }
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
                _buildSearchBar(context),
                const SizedBox(height: 10),
                _buildListStatusRow(
                  context,
                  activeThemeAsync: activeThemeAsync,
                  visibleThemeCount: visibleThemes.length,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (visibleThemes.isEmpty)
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
            padding: EdgeInsets.fromLTRB(
              horizontal,
              0,
              horizontal,
              16 + bottomSafe,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final theme = visibleThemes[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == visibleThemes.length - 1 ? 0 : 10,
                  ),
                  child: _buildThemeCard(
                    context,
                    theme,
                    isActive: activeThemeId == theme.id,
                  ),
                );
              }, childCount: visibleThemes.length),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopThemeWorkspace(
    BuildContext context, {
    required AsyncValue<AppAdvancedTheme?> activeThemeAsync,
    required String? activeThemeId,
    required List<AdvancedThemeSummary> visibleThemes,
    required double horizontal,
    required double bottomSafe,
    required double topInset,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    final selectedTheme =
        activeThemeId == null
            ? (visibleThemes.isEmpty ? null : visibleThemes.first)
            : visibleThemes.cast<AdvancedThemeSummary?>().firstWhere(
              (theme) => theme?.id == activeThemeId,
              orElse: () => visibleThemes.isEmpty ? null : visibleThemes.first,
            );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        topInset + 12,
        horizontal,
        16 + bottomSafe,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 380,
            child: Column(
              children: [
                _buildSearchBar(context),
                const SizedBox(height: 10),
                _buildListStatusRow(
                  context,
                  activeThemeAsync: activeThemeAsync,
                  visibleThemeCount: visibleThemes.length,
                ),
                SizedBox(height: metrics.contentGap),
                Expanded(
                  child:
                      visibleThemes.isEmpty
                          ? SingleChildScrollView(
                            child: _buildEmptyState(context),
                          )
                          : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: visibleThemes.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final theme = visibleThemes[index];
                              return _buildThemeCard(
                                context,
                                theme,
                                isActive: activeThemeId == theme.id,
                                compact: true,
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
          SizedBox(width: metrics.contentGap),
          Expanded(
            child: _buildDesktopThemePreviewPanel(
              context,
              theme: selectedTheme,
              activeThemeId: activeThemeId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopThemePreviewPanel(
    BuildContext context, {
    required AdvancedThemeSummary? theme,
    required String? activeThemeId,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (theme == null) {
      return AppEmptyStateCard(
        icon: Icons.palette_outlined,
        title: '选择一个主题',
        description: '左侧列表会展示可管理的高级主题。',
      );
    }
    final isActive = activeThemeId == theme.id;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (theme.category?.trim().isNotEmpty ?? false)
                          ? theme.category!.trim()
                          : '未分类',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                _buildStatusBubble(context, '当前启用')
              else
                OutlinedButton(
                  onPressed:
                      _isSaving
                          ? null
                          : () => unawaited(_applyThemeById(theme.id)),
                  child: const Text('应用'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _buildDualModePreviewStrip(context, theme),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _isSaving ? null : () => _openEditor(theme.id),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('编辑主题'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _isSaving
                        ? null
                        : () => unawaited(_duplicateTheme(theme.id)),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('复制'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _isSaving
                        ? null
                        : () => unawaited(_exportThemeBundle(theme.id)),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('导出'),
              ),
              if (isActive)
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _disableActiveTheme,
                  icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                  label: const Text('停用'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '浅色与深色配置会共同决定应用和阅读界面的实际表现。桌面端可以在这里预览、编辑和导出主题。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListStatusRow(
    BuildContext context, {
    required AsyncValue<AppAdvancedTheme?> activeThemeAsync,
    required int visibleThemeCount,
  }) {
    final activeThemeName = switch (activeThemeAsync) {
      AsyncData(:final value) when value != null => value.name,
      _ => null,
    };
    final countLabel =
        _searchQuery.trim().isEmpty &&
                (_selectedCategory?.trim().isEmpty ?? true)
            ? '主题数量 $visibleThemeCount'
            : '筛选结果 $visibleThemeCount';
    final activeLabel =
        activeThemeName == null ? '当前启用: 未启用' : '当前启用: $activeThemeName';
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildStatusBubble(context, countLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildStatusBubble(context, activeLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBubble(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedCategory = _selectedCategory?.trim();
    final categoryLabel =
        selectedCategory == null || selectedCategory.isEmpty
            ? '全部分类'
            : selectedCategory;
    return Row(
      children: [
        Flexible(
          flex: 5,
          child: CompactCollectionSearchField(
            controller: _searchController,
            hintText: '搜索主题名称或分类',
            query: _searchQuery,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _pruneSelectionForVisibleThemes();
              });
            },
            onClear: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _pruneSelectionForVisibleThemes();
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: PopupMenuButton<String?>(
            tooltip: '分类筛选',
            initialValue: _selectedCategory,
            onSelected: (value) {
              setState(() {
                _selectedCategory =
                    value?.trim().isEmpty ?? true ? null : value;
                _pruneSelectionForVisibleThemes();
              });
            },
            itemBuilder:
                (context) => <PopupMenuEntry<String?>>[
                  const PopupMenuItem<String?>(
                    value: null,
                    child: Center(child: Text('全部分类')),
                  ),
                  ..._availableCategories.map(
                    (category) => PopupMenuItem<String?>(
                      value: category,
                      child: Center(child: Text(category)),
                    ),
                  ),
                ],
            child: Container(
              height: 40,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest.withValues(
                  alpha: 0.92,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.28),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      categoryLabel,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isFiltering =
        _searchQuery.trim().isNotEmpty ||
        (_selectedCategory?.trim().isNotEmpty ?? false);
    return AppEmptyStateCard(
      icon: Icons.palette_outlined,
      title: isFiltering ? '没有匹配的主题' : '还没有高级主题',
      description: isFiltering ? '换个关键词或分类试试。' : '点击右上角新增，就可以分别配置浅色和深色主题。',
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    AdvancedThemeSummary theme, {
    required bool isActive,
    bool compact = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedThemeIds.contains(theme.id);
    final showSelectedState = _isSelectionMode && isSelected;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap:
          _isSaving
              ? null
              : _isSelectionMode
              ? () => _toggleThemeSelection(theme.id)
              : _floatingEditEnabled
              ? () => _openEditorDialog(theme.id)
              : () => _openEditor(theme.id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color:
              showSelectedState
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : isActive
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                showSelectedState
                    ? colorScheme.primary.withValues(alpha: 0.72)
                    : isActive
                    ? colorScheme.primary.withValues(alpha: 0.55)
                    : colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged:
                        _isSaving
                            ? null
                            : (_) => _toggleThemeSelection(theme.id),
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              theme.name,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '当前生效',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if ((theme.category?.trim().isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            theme.category!.trim(),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!_isSelectionMode)
                  PopupMenuButton<_AdvancedThemeAction>(
                    enabled: !_isSaving,
                    onSelected: (action) {
                      switch (action) {
                        case _AdvancedThemeAction.edit:
                          _openEditor(theme.id);
                        case _AdvancedThemeAction.duplicate:
                          unawaited(_duplicateTheme(theme.id));
                        case _AdvancedThemeAction.exportJson:
                          unawaited(_exportTheme(theme.id));
                        case _AdvancedThemeAction.exportZip:
                          unawaited(_exportThemeBundle(theme.id));
                        case _AdvancedThemeAction.delete:
                          unawaited(_handleDeleteThemeById(theme.id));
                      }
                    },
                    itemBuilder:
                        (context) => const [
                          PopupMenuItem(
                            value: _AdvancedThemeAction.edit,
                            child: Text('编辑'),
                          ),
                          PopupMenuItem(
                            value: _AdvancedThemeAction.duplicate,
                            child: Text('复制'),
                          ),
                          PopupMenuItem(
                            value: _AdvancedThemeAction.exportJson,
                            child: Text('导出颜色 JSON'),
                          ),
                          PopupMenuItem(
                            value: _AdvancedThemeAction.exportZip,
                            child: Text('导出 ZIP'),
                          ),
                          PopupMenuItem(
                            value: _AdvancedThemeAction.delete,
                            child: Text('删除'),
                          ),
                        ],
                  ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              _buildDualModePreviewStrip(context, theme),
            ],
            if (!_isSelectionMode && !compact) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _isSaving
                          ? null
                          : isActive
                          ? _disableActiveTheme
                          : () => unawaited(_applyThemeById(theme.id)),
                  child: Text(isActive ? '停用主题' : '应用主题'),
                ),
              ),
            ],
          ],
        ),
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
    return _previewWallpaperImageProviders.putIfAbsent(
      wallpaperPath,
      () => ResizeImage(FileImage(File(wallpaperPath)), width: 640),
    );
  }

  AppAdvancedThemeModeConfig _summaryToPreviewModeConfig(
    AdvancedThemeModeSummary summary,
  ) {
    return AppAdvancedThemeModeConfig(
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
  });

  final _AdvancedThemeBatchFileImportRunner importFile;
  final Future<void> Function() onShowImportSupportHelp;

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final summary = _summary;
    final isEmptyState = _items.isEmpty && summary == null && !_isImporting;
    final maxHeightFactor = isEmptyState ? 0.36 : 0.56;

    return PopScope<void>(
      canPop: !_isImporting,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 8 + bottomSafe),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        '批量导入主题',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        tooltip: '导入说明',
                        onPressed:
                            _isImporting
                                ? null
                                : widget.onShowImportSupportHelp,
                        icon: const Icon(Icons.help_outline_rounded),
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_headerMessage.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
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
                ],
                SizedBox(height: isEmptyState ? 14 : 8),
                if (_isImporting || summary != null) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.45,
                        ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
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
                  Flexible(child: _buildImportQueue(context)),
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
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: _pickFiles,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '添加主题文件',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '支持一次选择多个 JSON / ZIP / RED / RGSHARE 主题文件，也支持导入批量主题包。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
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
          showDialog<void>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('导出说明'),
                content: const Text('导出统一分为：准备导出 -> 处理中 -> 完成。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('知道了'),
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
