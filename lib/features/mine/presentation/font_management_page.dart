import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/composition/app_providers.dart' as app_providers;
import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/platform/app_capability_state.dart';
import '../../../app/platform/app_platform_capabilities.dart';
import '../../../app/tasks/app_task_manager.dart';
import '../../../app/theme/app_interface_typography_provider.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_task_bottom_sheet.dart';
import '../../../app/widgets/app_task_status.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/app_status_state_card.dart';
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
      if (!mounted) {
        return;
      }
      setState(() {
        _fonts = fonts;
        _fontFileExistsByFamilyKey = <String, bool>{
          for (final font in fonts)
            if (_fontFileExistsByFamilyKey.containsKey(font.fontFamilyKey))
              font.fontFamilyKey:
                  _fontFileExistsByFamilyKey[font.fontFamilyKey]!,
        };
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
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final interfaceFontSettings = ref.watch(appInterfaceFontSettingsProvider);
    final capabilities = ref.watch(appPlatformCapabilitiesProvider);
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );

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
          appBar: AppBar(
            title: const Text('字体管理'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go('/mine');
              },
            ),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: _isLoading ? null : () => unawaited(_reload()),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
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
                    child: RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          topInset + metrics.contentGap,
                          horizontal,
                          72 + metrics.sectionGap + bottomSafe,
                        ),
                        children: [
                          AppFadeSlideTransition(child: _buildHero(context)),
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
                                  child: CircularProgressIndicator(),
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
                            AppFadeSlideTransition(
                              delay: const Duration(milliseconds: 40),
                              child: _buildLibraryHeader(context),
                            ),
                            SizedBox(height: metrics.contentGap),
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
                            ..._fonts.map(
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
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding + 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(metrics.cardRadius + 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.font_download_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '统一管理应用与阅读器字体',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.contentGap),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip(context, '已导入 ${_fonts.length} 款'),
              _buildHeroChip(context, '支持 TTF / OTF'),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildHeroChip(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: metrics.chipHeight * 0.75),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.contentGap,
        vertical: metrics.isCompactDensity ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                        '系统默认字体',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '系统内置',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'set_reader_default') {
                      unawaited(_setReaderDefaultSystemFont());
                    }
                    if (value == 'set_interface_default') {
                      unawaited(_setInterfaceDefaultSystemFont());
                    }
                  },
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem<String>(
                          value: 'set_reader_default',
                          child: Text('设为阅读默认'),
                        ),
                        PopupMenuItem<String>(
                          value: 'set_interface_default',
                          child: Text('设为界面默认'),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '阅读预览',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '今天的阅读不只是在翻页，也是在塑造自己的语言节奏。',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isReaderDefault) const _FontMetaChip(text: '阅读默认'),
                if (isInterfaceDefault) const _FontMetaChip(text: '界面默认'),
                const _FontMetaChip(text: '系统内置'),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                        font.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exists == null
                            ? '文件状态未检查'
                            : exists
                            ? '文件可用'
                            : '文件已丢失',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              exists == null
                                  ? colorScheme.onSurfaceVariant
                                  : exists
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '检查文件状态',
                  onPressed: () => unawaited(_checkFontFile(font)),
                  icon: const Icon(Icons.fact_check_outlined),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'set_reader_default') {
                      unawaited(_setReaderDefaultCustomFont(font));
                    }
                    if (value == 'set_interface_default') {
                      unawaited(_setInterfaceDefaultCustomFont(font));
                    }
                    if (value == 'rename') {
                      unawaited(_renameFont(font));
                    }
                    if (value == 'delete') {
                      unawaited(_removeFont(font));
                    }
                  },
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem<String>(
                          value: 'set_reader_default',
                          child: Text('设为阅读默认'),
                        ),
                        PopupMenuItem<String>(
                          value: 'set_interface_default',
                          child: Text('设为界面默认'),
                        ),
                        PopupMenuItem<String>(
                          value: 'rename',
                          child: Text('重命名'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('删除字体'),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '阅读预览',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '今天的阅读不只是在翻页，也是在塑造自己的语言节奏。',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: exists == true ? font.fontFamilyKey : null,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isReaderDefault) const _FontMetaChip(text: '阅读默认'),
                if (isInterfaceDefault) const _FontMetaChip(text: '界面默认'),
                _FontMetaChip(text: _formatTime(importedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkFontFile(ReaderCustomFontEntry font) async {
    final exists = await localFileExists(font.filePath);
    if (!mounted) {
      return;
    }
    setState(() {
      _fontFileExistsByFamilyKey = <String, bool>{
        ..._fontFileExistsByFamilyKey,
        font.fontFamilyKey: exists,
      };
    });
  }

  Future<void> _importFont() async {
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
      final entry = await _fontRegistryService.pickAndImportFont();
      if (!mounted || entry == null) {
        taskManager.updateTask(
          taskId,
          initialStatus
              .toAppTaskStatusData(kind: AppTaskStatusKind.fontImport)
              .copyWith(
                message: '用户取消了字体选择。',
                result: AppTaskStatusResult.cancelled,
              ),
        );
        return;
      }
      await _reload();
      if (!mounted) {
        return;
      }
      taskManager.updateTask(
        taskId,
        ImportExportTaskStatus(
          title: '字体导入完成',
          message: entry.displayName,
          progress: 1,
          result: ImportExportTaskResult.success,
        ).toAppTaskStatusData(kind: AppTaskStatusKind.fontImport),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导入字体：${entry.displayName}')));
    } on ReaderFontRegistryException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入字体失败：$error')));
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
                        await _importFont();
                        if (!mounted) {
                          return;
                        }
                        setSheetState(() {
                          mode = _FontImportEntryMode.completed;
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
    await _fontRegistryService.removeFont(font.fontFamilyKey);
    if (!mounted) {
      return;
    }
    await _reload();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除字体：${font.displayName}')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已重命名字体：$normalized')));
    } on ReaderFontRegistryException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}

class _FontMetaChip extends StatelessWidget {
  const _FontMetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
