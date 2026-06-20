// UI-GOV-EXEMPT-FILE: scaffold list-children
// reason: Phase 10 reviewed this settings/resource page shell; the short static list is intentional.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/composition/app_providers.dart' as app_providers;
import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/platform/app_capability_state.dart';
import '../../../app/platform/app_input_focus_behavior.dart';
import '../../../app/platform/app_platform_capabilities.dart';
import '../../../app/tasks/app_task_manager.dart';
import '../../../app/theme/app_interface_typography_provider.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_task_bottom_sheet.dart';
import '../../../app/widgets/app_task_status.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/app_status_state_card.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../../../app/widgets/import_export_task_sheet.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../core/storage/local_file_stat.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../source/application/external_import_catalog.dart';
import '../../source/application/external_import_diagnostics.dart';
import '../../source/application/external_source_import_bridge.dart';
import '../../reader/application/reader_font_registry_service.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../application/advanced_theme_provider.dart';
import 'widgets/mine_route_top_bar.dart';

enum _FontImportEntryMode { add, processing, completed }

class FontManagementPage extends ConsumerStatefulWidget {
  const FontManagementPage({super.key});

  @override
  ConsumerState<FontManagementPage> createState() => _FontManagementPageState();
}

class _FontManagementPageState extends ConsumerState<FontManagementPage> {
  final ReaderFontRegistryService _fontRegistryService =
      ReaderFontRegistryService();
  final ReaderPreferencesService _readerPreferencesService =
      ReaderPreferencesService();
  final ScrollController _scrollController = ScrollController();
  late final ExternalImportBridge _externalImportBridge;

  bool _isLoading = true;
  bool _isImporting = false;
  bool _isConsumingExternalImportPayloads = false;
  ImportExportTaskStatus? _taskStatus;
  String? _errorText;
  List<ReaderCustomFontEntry> _fonts = const [];
  Map<String, bool> _fontFileExistsByFamilyKey = const <String, bool>{};
  ReaderSettings _readerSettings = const ReaderSettings();
  StreamSubscription<IncomingExternalImportPayload>? _importSubscription;
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _externalImportBridge = ref.read(
      app_providers.appExternalImportBridgeProvider,
    );
    unawaited(_reload());
    unawaited(_externalImportBridge.initialize());
    _importSubscription = _externalImportBridge.payloadStream.listen((payload) {
      if (payload.type != ExternalImportPayloadType.font) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumePendingExternalImportPayloads());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    unawaited(_importSubscription?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final fonts = await _fontRegistryService.listRegisteredFonts();
      final readerSettings = await _readerPreferencesService.loadSettings();
      final nextExistsByFamilyKey = <String, bool>{};
      for (final font in fonts) {
        final known = _fontFileExistsByFamilyKey[font.fontFamilyKey];
        nextExistsByFamilyKey[font.fontFamilyKey] =
            known ?? await localFileExists(font.filePath);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _fonts = fonts;
        _fontFileExistsByFamilyKey = nextExistsByFamilyKey;
        _readerSettings = readerSettings;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '字体列表加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<ReaderCustomFontEntry> get _filteredFonts {
    if (_searchKeyword.isEmpty) {
      return _fonts;
    }
    return _fonts.where((font) {
      return font.displayName.toLowerCase().contains(
        _searchKeyword.toLowerCase(),
      );
    }).toList();
  }

  int get _validFontCount {
    return _fonts
        .where((font) => _fontFileExistsByFamilyKey[font.fontFamilyKey] == true)
        .length;
  }

  Future<void> _consumePendingExternalImportPayloads() async {
    if (_isConsumingExternalImportPayloads || !mounted) {
      return;
    }

    _isConsumingExternalImportPayloads = true;
    try {
      while (mounted) {
        final payload = _externalImportBridge.consumePendingPayload(
          type: ExternalImportPayloadType.font,
        );
        if (payload == null) {
          break;
        }
        await _importFromExternalPayload(payload);
      }
    } finally {
      _isConsumingExternalImportPayloads = false;
    }
  }

  Future<void> _importFromExternalPayload(
    IncomingExternalImportPayload payload,
  ) async {
    final taskId =
        'external-font-import:${DateTime.now().microsecondsSinceEpoch}';
    final taskManager = ref.read(appTaskManagerProvider);
    final initialStatus = ImportExportTaskStatus(
      title: '正在导入字体',
      message: '正在读取 ${payload.label} 并准备注册到字体库…',
    );
    taskManager.startTask(
      id: taskId,
      status: initialStatus.toAppTaskStatusData(
        kind: AppTaskStatusKind.fontImport,
      ),
      channel: AppTaskChannel.resourceImport,
      priority: AppTaskPriority.userInitiated,
      recoveryKey: 'external-font-import:${payload.uri}',
    );
    setState(() {
      _taskStatus = initialStatus;
    });
    final cached = await _externalImportBridge.cacheExternalFileFromUri(
      payload,
    );
    if (cached == null) {
      ExternalImportDiagnostics.logCacheFailed(payload);
      final message = ExternalImportDiagnostics.readFailedMessage(
        payload.type,
        payload.label,
      );
      taskManager.updateTask(
        taskId,
        initialStatus
            .toAppTaskStatusData(kind: AppTaskStatusKind.fontImport)
            .copyWith(message: message, result: AppTaskStatusResult.failure),
      );
      _showSnackBar(message);
      if (mounted) {
        setState(() {
          _taskStatus = null;
        });
      }
      return;
    }

    try {
      if (!ExternalImportCatalog.supportsFileLabel(
        ExternalImportPayloadType.font,
        cached.label,
      )) {
        ExternalImportDiagnostics.logImportUnsupported(
          ExternalImportPayloadType.font,
          cached.label,
        );
        final message = ExternalImportCatalog.unsupportedFileMessage(
          ExternalImportPayloadType.font,
          cached.label,
        );
        taskManager.updateTask(
          taskId,
          initialStatus
              .toAppTaskStatusData(kind: AppTaskStatusKind.fontImport)
              .copyWith(message: message, result: AppTaskStatusResult.failure),
        );
        _showSnackBar(message);
        return;
      }
      final registeringStatus = ImportExportTaskStatus(
        title: '正在导入字体',
        message: '正在注册 ${cached.label}…',
        detail: '注册字体',
      );
      taskManager.updateTask(
        taskId,
        registeringStatus.toAppTaskStatusData(
          kind: AppTaskStatusKind.fontImport,
        ),
      );
      if (mounted) {
        setState(() {
          _taskStatus = registeringStatus;
        });
      }
      final entry = await _fontRegistryService.importFontFile(
        filePath: cached.path,
        displayName: cached.label.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      );
      await _reload();
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportSucceeded(
        ExternalImportPayloadType.font,
        entry.displayName,
      );
      taskManager.updateTask(
        taskId,
        ImportExportTaskStatus(
          title: '字体导入完成',
          message: entry.displayName,
          progress: 1,
          result: ImportExportTaskResult.success,
        ).toAppTaskStatusData(kind: AppTaskStatusKind.fontImport),
      );
      _showSnackBar('已导入字体：${entry.displayName}');
    } on ReaderFontRegistryException catch (error) {
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.font,
        cached.label,
        error,
      );
      taskManager.updateTask(
        taskId,
        initialStatus
            .toAppTaskStatusData(kind: AppTaskStatusKind.fontImport)
            .copyWith(
              message: error.message,
              result: AppTaskStatusResult.failure,
            ),
      );
      _showSnackBar(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.font,
        cached.label,
        error,
      );
      final message = ExternalImportDiagnostics.importFailedMessage(
        ExternalImportPayloadType.font,
        '$error',
        label: cached.label,
      );
      taskManager.updateTask(
        taskId,
        initialStatus
            .toAppTaskStatusData(kind: AppTaskStatusKind.fontImport)
            .copyWith(message: message, result: AppTaskStatusResult.failure),
      );
      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() {
          _taskStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final routeTopBar = _buildRouteTopBar(context);
    final topInset =
        MediaQuery.paddingOf(context).top + routeTopBar.preferredSize.height;
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final interfaceFontSettings = ref.watch(appInterfaceFontSettingsProvider);
    final capabilities = ref.watch(appPlatformCapabilitiesProvider);
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );
    final hasFonts = _filteredFonts.isNotEmpty;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: ImportExportTaskOverlay(
        status: _taskStatus,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: routeTopBar,
          body: LayoutBuilder(
            builder: (context, _) {
              final maxWidth = AppLayout.pageContentMaxWidth(
                context,
                maxWidth: AppLayout.systemSettingsContentMaxWidth,
              );
              return DecoratedBox(
                decoration: buildAdvancedThemeBackdropDecoration(backdrop),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: AppRefreshIndicator(
                      semanticsLabel: '刷新字体管理',
                      onRefresh: _reload,
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          topInset + metrics.contentGap,
                          horizontal,
                          72 + metrics.sectionGap + bottomSafe,
                        ),
                        children: [
                          // 统计行（替代 Hero）
                          if (!_isLoading && _errorText == null)
                            _buildStatsRow(context),
                          if (!_isLoading && _errorText == null)
                            SizedBox(height: metrics.contentGap),
                          if (!capabilities.supportsManagedFileStorage ||
                              !capabilities.supportsLocalFileImport) ...[
                            _buildFontCapabilityNotice(context),
                            SizedBox(height: metrics.contentGap),
                          ],
                          if (_isLoading)
                            const AppAnimatedSwitcher(
                              child: Padding(
                                key: ValueKey('font_loading'),
                                padding: EdgeInsets.only(top: 32),
                                child: Center(
                                  child: AppProgressIndicator(
                                    semanticLabel: '加载字体',
                                  ),
                                ),
                              ),
                            )
                          else if (_errorText != null)
                            AppAnimatedSwitcher(
                              child: KeyedSubtree(
                                key: const ValueKey('font_error'),
                                child: _buildErrorCard(context),
                              ),
                            )
                          else ...[
                            // 搜索框
                            if (hasFonts || _searchKeyword.isNotEmpty)
                              _buildSearchBar(context),
                            if (hasFonts || _searchKeyword.isNotEmpty)
                              SizedBox(height: metrics.contentGap),
                            AppFadeSlideTransition(
                              delay: const Duration(milliseconds: 40),
                              child: _buildLibraryHeader(context),
                            ),
                            SizedBox(height: metrics.contentGap),
                            // 系统默认字体
                            AppFadeSlideTransition(
                              delay: const Duration(milliseconds: 64),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: metrics.contentGap,
                                ),
                                child: _buildSystemDefaultFontCard(
                                  context,
                                  interfaceFontSettings: interfaceFontSettings,
                                ),
                              ),
                            ),
                            // 自定义字体列表
                            ..._filteredFonts.map(
                              (font) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: metrics.contentGap,
                                ),
                                child: _buildFontCard(
                                  context,
                                  font,
                                  interfaceFontSettings: interfaceFontSettings,
                                ),
                              ),
                            ),
                            if (_filteredFonts.isEmpty && _fonts.isNotEmpty)
                              _buildEmptySearchResultCard(context),
                            if (_fonts.isEmpty) _buildEmptyLibraryCard(context),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed:
                _isImporting
                    ? null
                    : () => _showImportFontSheet(
                      localFileImport: capabilities.localFileImport,
                      managedFileStorage: capabilities.managedFileStorage,
                    ),
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('导入字体'),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildRouteTopBar(BuildContext context) {
    final searchIcon =
        _searchKeyword.isNotEmpty
            ? Icons.search_off_rounded
            : Icons.search_rounded;
    return buildMineRouteTopBar(
      context: context,
      title: '字体管理',
      subtitle: '${_fonts.length} 个字体，$_validFontCount 个可用',
      actions: <AdaptiveOverflowToolbarItem>[
        AdaptiveOverflowToolbarItem(
          icon: searchIcon,
          label: _searchKeyword.isNotEmpty ? '清空搜索' : '搜索',
          priority: 10,
          onPressed: () => unawaited(_showSearchDialog()),
        ),
        AdaptiveOverflowToolbarItem(
          icon: Icons.refresh_rounded,
          label: '刷新',
          priority: 8,
          enabled: !_isLoading,
          onPressed: _isLoading ? null : () => unawaited(_reload()),
        ),
      ],
      mobileActions: <Widget>[
        IconButton(
          tooltip: _searchKeyword.isNotEmpty ? '清空搜索' : '搜索',
          onPressed: () => unawaited(_showSearchDialog()),
          icon: Icon(searchIcon),
        ),
        IconButton(
          tooltip: '刷新',
          onPressed: _isLoading ? null : () => unawaited(_reload()),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Future<void> _showSearchDialog() async {
    if (_searchKeyword.isNotEmpty) {
      setState(() {
        _searchKeyword = '';
      });
      return;
    }
    final controller = TextEditingController();
    final keyword = await showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 420,
      builder: (surfaceContext) {
        void submit() {
          Navigator.of(surfaceContext).pop(controller.text.trim());
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '搜索字体',
              style: Theme.of(
                surfaceContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: appEnableAutoFocusForTextInput,
              decoration: const InputDecoration(
                hintText: '输入字体名称',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: submit, child: const Text('搜索')),
              ],
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (keyword == null || !mounted) {
      return;
    }
    setState(() {
      _searchKeyword = keyword.trim();
    });
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
              autofocus: false,
              decoration: const InputDecoration(
                hintText: '搜索字体',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value;
                });
              },
              controller: TextEditingController(text: _searchKeyword),
            ),
          ),
          if (_searchKeyword.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18),
              onPressed: () {
                setState(() {
                  _searchKeyword = '';
                });
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultCount = _getDefaultCount();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            icon: Icons.font_download_outlined,
            value: '${_fonts.length}',
            label: '已导入',
            color: colorScheme.primary,
          ),
          Container(
            width: 1,
            height: 30,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          _StatItem(
            icon: Icons.check_circle_outline,
            value: '$_validFontCount',
            label: '可用',
            color: Colors.green,
          ),
          Container(
            width: 1,
            height: 30,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          _StatItem(
            icon: Icons.star_outline,
            value: '$defaultCount',
            label: '已设为默认',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  int _getDefaultCount() {
    int count = 0;
    final isReaderCustom =
        _readerSettings.fontSource == ReaderFontSource.custom;
    final isInterfaceCustom =
        ref.read(appInterfaceFontSettingsProvider).fontSource ==
        AppInterfaceFontSource.custom;
    if (isReaderCustom) count++;
    if (isInterfaceCustom) count++;
    return count;
  }

  Widget _buildFontCapabilityNotice(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.secondary),
          SizedBox(width: metrics.contentGap),
          Expanded(
            child: Text(
              '当前平台不暴露可管理文件路径，字体导入会保持禁用；已注册字体仍会按可用状态展示。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我的字体库',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return AppStatusStateCard(
      icon: Icons.error_outline_rounded,
      title: '加载失败',
      message: _errorText ?? '',
      tone: AppStatusStateTone.error,
      actionLabel: '重试',
      onAction: () => unawaited(_reload()),
    );
  }

  Widget _buildEmptyLibraryCard(BuildContext context) {
    return const AppEmptyStateCard(
      icon: Icons.font_download_outlined,
      title: '还没有导入字体',
      description: '导入 `.ttf` 或 `.otf` 后会在这里显示。',
    );
  }

  Widget _buildEmptySearchResultCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            '没有找到 "$_searchKeyword"',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemDefaultFontCard(
    BuildContext context, {
    required AppInterfaceFontSettings interfaceFontSettings,
  }) {
    final isReaderDefault =
        _readerSettings.fontSource == ReaderFontSource.system &&
        _readerSettings.systemFontPreset == ReaderSystemFontPreset.defaultSans;
    final isInterfaceDefault =
        interfaceFontSettings.fontSource == AppInterfaceFontSource.system &&
        interfaceFontSettings.systemFontPreset ==
            AppInterfaceSystemFontPreset.defaultSans;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.android_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '系统默认字体',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (isReaderDefault)
                        _buildMetaChip(
                          context,
                          '阅读默认',
                          color: colorScheme.primary,
                        ),
                      if (isInterfaceDefault)
                        _buildMetaChip(
                          context,
                          '界面默认',
                          color: colorScheme.primary,
                        ),
                      _buildMetaChip(
                        context,
                        '系统内置',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppMenuButton<String>(
              onSelected: (value) {
                if (value == 'set_reader_default') {
                  unawaited(_setReaderDefaultSystemFont());
                }
                if (value == 'set_interface_default') {
                  unawaited(_setInterfaceDefaultSystemFont());
                }
              },
              actions: const [
                AppMenuAction(value: 'set_reader_default', label: '设为阅读默认'),
                AppMenuAction(value: 'set_interface_default', label: '设为界面默认'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontCard(
    BuildContext context,
    ReaderCustomFontEntry font, {
    required AppInterfaceFontSettings interfaceFontSettings,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final exists = _fontFileExistsByFamilyKey[font.fontFamilyKey];
    final importedAt = DateTime.fromMillisecondsSinceEpoch(
      font.importedAtEpochMs,
    );
    final isReaderDefault =
        _readerSettings.fontSource == ReaderFontSource.custom &&
        _readerSettings.fontFamilyKey == font.fontFamilyKey;
    final isInterfaceDefault =
        interfaceFontSettings.fontSource == AppInterfaceFontSource.custom &&
        interfaceFontSettings.fontFamilyKey == font.fontFamilyKey;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.text_fields_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          font.displayName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isReaderDefault && !isInterfaceDefault)
                        TextButton(
                          onPressed: () => _setReaderDefaultCustomFont(font),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('设为阅读默认'),
                        ),
                      AppMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'set_interface_default') {
                            unawaited(_setInterfaceDefaultCustomFont(font));
                          } else if (value == 'rename') {
                            unawaited(_renameFont(font));
                          } else if (value == 'delete') {
                            unawaited(_removeFont(font));
                          }
                        },
                        actions: const [
                          AppMenuAction(
                            value: 'set_interface_default',
                            label: '设为界面默认',
                          ),
                          AppMenuAction(value: 'rename', label: '重命名'),
                          AppMenuAction(
                            value: 'delete',
                            label: '删除字体',
                            icon: Icons.delete_outline,
                            destructive: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 文件状态
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: exists == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        exists == true
                            ? '可用'
                            : (exists == false ? '文件丢失' : '状态未知'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: exists == true ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatTimeShort(importedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 预览行
                  Text(
                    '预览：今天的阅读不只是翻页，也是在塑造自己的语言节奏。',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: exists == true ? font.fontFamilyKey : null,
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 标签
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (isReaderDefault)
                        _buildMetaChip(
                          context,
                          '阅读默认',
                          color: colorScheme.primary,
                        ),
                      if (isInterfaceDefault)
                        _buildMetaChip(
                          context,
                          '界面默认',
                          color: colorScheme.primary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(BuildContext context, String text, {Color? color}) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipColor = color ?? colorScheme.surfaceContainerLow;
    final textColor = color ?? colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<List<ReaderCustomFontEntry>> _importFont() async {
    final taskId = 'font-import:${DateTime.now().microsecondsSinceEpoch}';
    final taskManager = ref.read(appTaskManagerProvider);
    const initialStatus = ImportExportTaskStatus(
      title: '正在导入字体',
      message: '正在打开文件选择器并准备注册字体…',
    );
    taskManager.startTask(
      id: taskId,
      status: initialStatus.toAppTaskStatusData(
        kind: AppTaskStatusKind.fontImport,
      ),
      channel: AppTaskChannel.resourceImport,
      priority: AppTaskPriority.userInitiated,
    );
    setState(() {
      _isImporting = true;
      _taskStatus = initialStatus;
    });
    try {
      final importedFonts = await _fontRegistryService.pickAndImportFonts();
      if (!mounted || importedFonts.isEmpty) {
        taskManager.updateTask(
          taskId,
          initialStatus
              .toAppTaskStatusData(kind: AppTaskStatusKind.fontImport)
              .copyWith(
                message: '用户取消了字体选择。',
                result: AppTaskStatusResult.cancelled,
              ),
        );
        return const <ReaderCustomFontEntry>[];
      }
      await _reload();
      if (!mounted) {
        return importedFonts;
      }
      final primaryEntry = importedFonts.first;
      final message =
          importedFonts.length == 1
              ? primaryEntry.displayName
              : '已导入 ${importedFonts.length} 个字体';
      taskManager.updateTask(
        taskId,
        ImportExportTaskStatus(
          title: '字体导入完成',
          message: message,
          progress: 1,
          result: ImportExportTaskResult.success,
        ).toAppTaskStatusData(kind: AppTaskStatusKind.fontImport),
      );
      _showSnackBar(message, tone: AppFeedbackTone.success);
      return importedFonts;
    } on ReaderFontRegistryException catch (error) {
      if (!mounted) {
        return const <ReaderCustomFontEntry>[];
      }
      _showSnackBar(error.message, tone: AppFeedbackTone.error);
      taskManager.updateTask(
        taskId,
        initialStatus
            .toAppTaskStatusData(kind: AppTaskStatusKind.fontImport)
            .copyWith(
              message: error.message,
              result: AppTaskStatusResult.failure,
            ),
      );
    } catch (error) {
      if (!mounted) {
        return const <ReaderCustomFontEntry>[];
      }
      _showSnackBar('导入字体失败：$error', tone: AppFeedbackTone.error);
      taskManager.updateTask(
        taskId,
        initialStatus
            .toAppTaskStatusData(kind: AppTaskStatusKind.fontImport)
            .copyWith(
              message: '导入字体失败：$error',
              result: AppTaskStatusResult.failure,
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _taskStatus = null;
        });
      }
    }
    return const <ReaderCustomFontEntry>[];
  }

  Future<void> _showImportFontSheet({
    required AppCapabilityState localFileImport,
    required AppCapabilityState managedFileStorage,
  }) async {
    if (_isImporting || !mounted) {
      return;
    }
    if (!localFileImport.isSupported || !managedFileStorage.isSupported) {
      _showSnackBar(
        localFileImport.reason ??
            managedFileStorage.reason ??
            '当前平台暂不支持导入字体文件。',
      );
      return;
    }
    await showAdaptiveRawSurface<void>(
      context: context,
      showDragHandle: false,
      mobileBackgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var mode = _FontImportEntryMode.add;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final steps = <AppTaskStep>[
              AppTaskStep(label: '添加文件', active: true),
              AppTaskStep(
                label: '注册字体',
                active: mode != _FontImportEntryMode.add,
              ),
              AppTaskStep(
                label: '完成',
                active: mode == _FontImportEntryMode.completed,
              ),
            ];
            return AppTaskBottomSheet(
              title: '导入字体',
              trailing: IconButton(
                tooltip: '导入说明',
                onPressed: () {
                  showAdaptiveActionSurface<void>(
                    context: sheetContext,
                    maxWidth: 420,
                    builder: (surfaceContext) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '导入说明',
                            style: Theme.of(surfaceContext)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Text('字体导入统一分为：添加文件 -> 注册字体 -> 完成。导入后可用于界面和阅读器设置。'),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed:
                                  () => Navigator.of(surfaceContext).pop(),
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
              steps: steps,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mode == _FontImportEntryMode.add)
                    AppTaskActionCard(
                      title: '添加字体文件',
                      description: '支持导入 TTF 和 OTF 字体文件。',
                      icon: Icons.font_download_outlined,
                      dashedBorder: true,
                      onTap: () async {
                        setSheetState(() {
                          mode = _FontImportEntryMode.processing;
                        });
                        final importedFonts = await _importFont();
                        if (!mounted) {
                          return;
                        }
                        if (importedFonts.isNotEmpty) {
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                          return;
                        }
                        setSheetState(() {
                          mode = _FontImportEntryMode.add;
                        });
                      },
                    )
                  else if (mode == _FontImportEntryMode.processing)
                    const ImportExportProgressCard(
                      status: ImportExportTaskStatus(
                        title: '正在导入字体',
                        message: '正在注册字体文件…',
                        detail: '注册字体',
                      ),
                    )
                  else
                    const ImportExportTaskSheet(
                      status: ImportExportTaskStatus(
                        title: '字体导入完成',
                        message: '已完成',
                        result: ImportExportTaskResult.success,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _removeFont(ReaderCustomFontEntry font) async {
    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    await _fontRegistryService.removeFont(font.fontFamilyKey);
    if (!mounted) {
      return;
    }
    await _reload();
    if (!mounted) {
      return;
    }
    if (_scrollController.hasClients) {
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(offset.clamp(0.0, maxScrollExtent));
    }
    _showSnackBar('已删除字体：${font.displayName}');
  }

  Future<void> _setReaderDefaultSystemFont() async {
    final next = _readerSettings.copyWith(
      fontSource: ReaderFontSource.system,
      systemFontPreset: ReaderSystemFontPreset.defaultSans,
      clearFontFamilyKey: true,
      clearCustomFontPath: true,
    );
    await _readerPreferencesService.saveSettings(next);
    await _reload();
    _showSnackBar('已设为阅读默认：系统默认字体');
  }

  Future<void> _setInterfaceDefaultSystemFont() async {
    await ref
        .read(appInterfaceFontSettingsProvider.notifier)
        .setSystemFont(AppInterfaceSystemFontPreset.defaultSans);
    await _reload();
    _showSnackBar('已设为界面默认：系统默认字体');
  }

  Future<void> _setReaderDefaultCustomFont(ReaderCustomFontEntry font) async {
    final next = _readerSettings.copyWith(
      fontSource: ReaderFontSource.custom,
      fontFamilyKey: font.fontFamilyKey,
      customFontPath: font.filePath,
    );
    await _readerPreferencesService.saveSettings(next);
    await _reload();
    _showSnackBar('已设为阅读默认：${font.displayName}');
  }

  Future<void> _setInterfaceDefaultCustomFont(
    ReaderCustomFontEntry font,
  ) async {
    await ref
        .read(appInterfaceFontSettingsProvider.notifier)
        .setCustomFont(font);
    await _reload();
    _showSnackBar('已设为界面默认：${font.displayName}');
  }

  Future<void> _renameFont(ReaderCustomFontEntry font) async {
    final controller = TextEditingController(text: font.displayName);
    final nextName = await showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 420,
      builder: (surfaceContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '重命名字体',
              style: Theme.of(
                surfaceContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '显示名称',
                hintText: '输入新的字体名称',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                Navigator.of(surfaceContext).pop(controller.text.trim());
              },
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed:
                      () => Navigator.of(
                        surfaceContext,
                      ).pop(controller.text.trim()),
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || nextName == null) {
      return;
    }
    final normalized = nextName.trim();
    if (normalized.isEmpty || normalized == font.displayName) {
      return;
    }
    try {
      await _fontRegistryService.renameFontDisplayName(
        familyKey: font.fontFamilyKey,
        displayName: normalized,
      );
      await _reload();
      if (!mounted) {
        return;
      }
      _showSnackBar('已重命名字体：$normalized');
    } on ReaderFontRegistryException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.message, tone: AppFeedbackTone.error);
    }
  }

  void _showSnackBar(
    String message, {
    AppFeedbackTone tone = AppFeedbackTone.info,
  }) {
    if (!mounted) {
      return;
    }
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone: message.contains('失败') ? AppFeedbackTone.error : tone,
      useHaptics: false,
    );
  }

  String _formatTimeShort(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);

    if (date == today) {
      return '今天';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == yesterday) {
      return '昨天';
    }
    final daysDiff = today.difference(date).inDays;
    if (daysDiff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    }
    return '${time.month}月${time.day}日';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
