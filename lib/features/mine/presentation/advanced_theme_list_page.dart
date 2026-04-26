import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_border_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/membership/membership_features.dart';
import '../../../core/membership/membership_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../application/advanced_theme_export_error_formatter.dart';
import '../../source/application/external_source_import_bridge.dart';
import '../../source/application/external_import_diagnostics.dart';
import '../../source/application/external_import_catalog.dart';
import '../application/advanced_theme_provider.dart';

class AdvancedThemeListPage extends ConsumerStatefulWidget {
  const AdvancedThemeListPage({super.key});

  @override
  ConsumerState<AdvancedThemeListPage> createState() =>
      _AdvancedThemeListPageState();
}

enum _AdvancedThemeAction { edit, duplicate, exportJson, exportZip, delete }

enum _ThemeImportPackageKind { official, red, rgshare }

class _AdvancedThemeListPageState extends ConsumerState<AdvancedThemeListPage> {
  final AuthSessionStore _sessionStore = AuthSessionStore();
  final MembershipService _membershipService = MembershipService();
  List<AppAdvancedTheme> _themes = const <AppAdvancedTheme>[];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isConsumingExternalImportPayloads = false;
  bool _isAccessLoading = true;
  bool _canUseAdvancedThemes = false;
  StreamSubscription<IncomingExternalImportPayload>? _incomingImportSub;
  StreamSubscription<AuthEvent>? _authEventSub;

  @override
  void initState() {
    super.initState();
    _incomingImportSub = ExternalImportBridge.instance.payloadStream.listen((
      payload,
    ) {
      if (payload.type != ExternalImportPayloadType.advancedTheme) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
    });
    _authEventSub = AuthEventBus.instance.stream.listen(_handleAuthEvent);
    _loadAccess();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumePendingExternalImportPayloads());
    });
  }

  Future<void> _loadAccess() async {
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

    try {
      final entitlement = await _membershipService.fetchEntitlement();
      if (!mounted) {
        return;
      }
      setState(() {
        _canUseAdvancedThemes = MembershipFeatures.hasFeature(
          entitlement,
          MembershipFeatures.themeCustom,
        );
        _isAccessLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _canUseAdvancedThemes = false;
        _isAccessLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _incomingImportSub?.cancel();
    _authEventSub?.cancel();
    super.dispose();
  }

  void _handleAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.loggedIn:
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        unawaited(_loadAccess());
        break;
    }
  }

  Future<void> _load() async {
    final service = ref.read(advancedThemeServiceProvider);
    final themes = await service.loadThemes();
    if (!mounted) {
      return;
    }
    final activeThemeId = ref.read(activeAdvancedThemeIdProvider);
    final sortedThemes = List<AppAdvancedTheme>.from(themes)..sort((a, b) {
      final aIsActive = a.id == activeThemeId;
      final bIsActive = b.id == activeThemeId;
      if (aIsActive != bIsActive) {
        return aIsActive ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    setState(() {
      _themes = sortedThemes;
      _isLoading = false;
    });
  }

  Future<void> _openEditor([AppAdvancedTheme? theme]) async {
    final result = await context.push<String>(
      theme == null
          ? '/appearance/advanced-themes/editor'
          : '/appearance/advanced-themes/editor?id=${theme.id}',
    );
    await _load();
    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }
    _showMessage(result);
  }

  Future<void> _duplicateTheme(AppAdvancedTheme theme) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final service = ref.read(advancedThemeServiceProvider);
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

  Future<void> _exportTheme(AppAdvancedTheme theme) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final service = ref.read(advancedThemeServiceProvider);
      final fileName = '${_normalizedFileName(theme.name)}.json';
      final content = service.encodeThemeColorJson(theme);
      var completed = false;
      if (_shouldUseSaveLocationPicker) {
        final location = await getSaveLocation(
          acceptedTypeGroups: const <XTypeGroup>[
            ExternalImportCatalog.advancedThemeJsonTypeGroup,
          ],
          suggestedName: fileName,
          confirmButtonText: '导出',
        );
        if (location == null) {
          return;
        }
        final file = File(location.path);
        await file.writeAsString(content, flush: true);
        completed = true;
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(content, flush: true);
        completed = await _shareExportedThemeFile(
          file: file,
          text: '分享颜色主题：${theme.name}',
          subject: theme.name,
          clipboardText: content,
        );
      }
      if (!completed || !mounted) {
        return;
      }
      _showMessage('已导出颜色配置「${theme.name}」');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('导出失败：${formatAdvancedThemeExportError(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _exportThemeBundle(AppAdvancedTheme theme) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final service = ref.read(advancedThemeServiceProvider);
      final fileName = '${_normalizedFileName(theme.name)}.zip';
      final bytes = await service.encodeThemeBundleZip(theme);
      var completed = false;
      if (_shouldUseSaveLocationPicker) {
        final location = await getSaveLocation(
          acceptedTypeGroups: const <XTypeGroup>[
            ExternalImportCatalog.advancedThemeZipTypeGroup,
          ],
          suggestedName: fileName,
          confirmButtonText: '导出',
        );
        if (location == null) {
          return;
        }
        final file = File(location.path);
        await file.writeAsBytes(bytes, flush: true);
        completed = true;
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        completed = await _shareExportedThemeFile(
          file: file,
          text: '分享主题包：${theme.name}',
          subject: theme.name,
        );
      }
      if (!completed || !mounted) {
        return;
      }
      _showMessage('已导出主题包「${theme.name}」');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('导出主题包失败：${formatAdvancedThemeExportError(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool get _shouldUseSaveLocationPicker {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  Future<bool> _shareExportedThemeFile({
    required File file,
    required String text,
    required String subject,
    String? clipboardText,
  }) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        subject: subject,
        sharePositionOrigin: _resolveSharePositionOrigin(),
      );
      return result.status != ShareResultStatus.dismissed;
    } on MissingPluginException {
      final fallbackText = clipboardText;
      if (fallbackText != null && fallbackText.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: fallbackText));
      }
      if (!mounted) {
        return false;
      }
      _showMessage(
        fallbackText == null || fallbackText.isEmpty
            ? '当前安装包暂不支持系统分享，请完整重启 App 后重试。'
            : '当前安装包暂不支持系统分享，已复制主题内容，请完整重启 App 后重试。',
      );
      return false;
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

  Future<void> _importTheme() async {
    if (_isSaving) {
      return;
    }
    final packageKind = await _chooseImportPackageKind();
    if (packageKind == null) {
      return;
    }
    final picked = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        switch (packageKind) {
          _ThemeImportPackageKind.red =>
            ExternalImportCatalog.advancedThemeRedTypeGroup,
          _ThemeImportPackageKind.rgshare =>
            ExternalImportCatalog.advancedThemeRgShareTypeGroup,
          _ThemeImportPackageKind.official =>
            ExternalImportCatalog.advancedThemeImportTypeGroup,
        },
      ],
      confirmButtonText: '导入主题',
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final importedTheme = await _importThemeFromPath(
        path: picked.path,
        packageKind: packageKind,
      );
      if (!mounted) {
        return;
      }
      _showMessage('已导入主题「${importedTheme.name}」');
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('导入失败，请确认主题文件格式正确。');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
        final payload = ExternalImportBridge.instance.consumePendingPayload(
          type: ExternalImportPayloadType.advancedTheme,
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
    final cached = await ExternalImportBridge.instance.cacheExternalFileFromUri(
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

    try {
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
      final importedTheme = await _importThemeFromPath(
        path: cached.path,
        mimeType: cached.mimeType ?? payload.mimeType,
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
        cached.label,
        error,
      );
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.advancedTheme,
        cached.label,
        error,
      );
      _showMessage(
        ExternalImportDiagnostics.importFailedMessage(
          ExternalImportPayloadType.advancedTheme,
          '$error',
          label: cached.label,
        ),
      );
    }
  }

  Future<AppAdvancedTheme> _importThemeFromPath({
    required String path,
    String? mimeType,
    _ThemeImportPackageKind? packageKind,
  }) async {
    final service = ref.read(advancedThemeServiceProvider);
    final file = File(path);
    final effectiveKind =
        packageKind ?? await _detectPackageKind(path: path, mimeType: mimeType);
    final importedTheme = switch (effectiveKind) {
      _ThemeImportPackageKind.red => await service.importRedThemePackageBytes(
        await file.readAsBytes(),
      ),
      _ThemeImportPackageKind.rgshare => await service
          .importRgShareThemePackageBytes(await file.readAsBytes()),
      _ThemeImportPackageKind.official =>
        _isZipThemeFile(path: path, mimeType: mimeType)
            ? await service.importThemeBundleZipBytes(await file.readAsBytes())
            : await service.importThemeColorJson(await file.readAsString()),
    };
    ref.read(advancedThemeRevisionProvider.notifier).markChanged();
    await _load();
    return importedTheme;
  }

  Future<_ThemeImportPackageKind?> _chooseImportPackageKind() {
    return showModalBottomSheet<_ThemeImportPackageKind>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '选择导入类型',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: '导入说明',
                    onPressed: () => _showThemeImportSupportHelp(sheetContext),
                    icon: Icon(
                      Icons.help_outline_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Text(
                '请选择要导入的主题包类型。',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('官方主题包'),
                subtitle: const Text('导入应用当前支持的 JSON / ZIP 主题包'),
                onTap:
                    () => Navigator.of(
                      sheetContext,
                    ).pop(_ThemeImportPackageKind.official),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.auto_awesome_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('Red 主题包'),
                subtitle: const Text('导入Reeden 主题包并按兼容规则转换'),
                onTap:
                    () => Navigator.of(
                      sheetContext,
                    ).pop(_ThemeImportPackageKind.red),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.layers_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('RGShare 主题包'),
                subtitle: const Text('导入 .rgshare 轻量主题包并按兼容规则转换'),
                onTap:
                    () => Navigator.of(
                      sheetContext,
                    ).pop(_ThemeImportPackageKind.rgshare),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
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
  }) async {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    if (p.extension(path).trim().toLowerCase() == '.rgshare') {
      return _ThemeImportPackageKind.rgshare;
    }
    if (normalizedMime.contains('octet-stream') &&
        p.extension(path).trim().toLowerCase() == '.red') {
      return _ThemeImportPackageKind.red;
    }
    if (p.extension(path).trim().toLowerCase() == '.red') {
      return _ThemeImportPackageKind.red;
    }
    try {
      final file = File(path);
      final bytes = await file.openRead(0, 8).fold<List<int>>(<int>[], (
        previous,
        element,
      ) {
        return <int>[...previous, ...element];
      });
      if (_hasRedHeader(bytes)) {
        return _ThemeImportPackageKind.red;
      }
    } catch (_) {
      // Fall through to official package detection.
    }
    return _ThemeImportPackageKind.official;
  }

  bool _hasRedHeader(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x44;
  }

  bool _isZipThemeFile({required String path, String? mimeType}) {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    if (normalizedMime.contains('zip')) {
      return true;
    }
    return p.extension(path).trim().toLowerCase() == '.zip';
  }

  Future<void> _deleteTheme(AppAdvancedTheme theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除高级主题'),
          content: Text('确定删除「${theme.name}」吗？浅色和深色壁纸都会一并移除。'),
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
    if (confirmed != true || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final wasActive = ref.read(activeAdvancedThemeIdProvider) == theme.id;
      final service = ref.read(advancedThemeServiceProvider);
      await service.deleteTheme(theme.id);
      ref.read(advancedThemeRevisionProvider.notifier).markChanged();
      if (wasActive) {
        await ref.read(activeAdvancedThemeIdProvider.notifier).disable();
      }
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage('已删除主题「${theme.name}」');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/appearance?section=appearance');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('高级主题'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: '导入主题',
              onPressed: _isLoading || _isSaving ? null : _importTheme,
              icon: const Icon(Icons.file_upload_outlined),
            ),
            IconButton(
              tooltip: '新建高级主题',
              onPressed: _isLoading || _isSaving ? null : () => _openEditor(),
              icon: const Icon(Icons.palette_outlined),
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
                      _isAccessLoading || _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : !_canUseAdvancedThemes
                          ? _buildVipLockedState(context, topInset: topInset)
                          : ListView(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              topInset + 12,
                              horizontal,
                              16 + bottomSafe,
                            ),
                            children: [
                              _buildIntroCard(context, activeThemeAsync),
                              const SizedBox(height: 10),
                              if (_themes.isEmpty)
                                _buildEmptyState(context)
                              else
                                ..._themes.map(
                                  (theme) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildThemeCard(
                                      context,
                                      theme,
                                      isActive: activeThemeId == theme.id,
                                    ),
                                  ),
                                ),
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

  Widget _buildIntroCard(
    BuildContext context,
    AsyncValue<AppAdvancedTheme?> activeThemeAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeThemeName = switch (activeThemeAsync) {
      AsyncData(:final value) when value != null => value.name,
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.palette_rounded,
              color: colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '双模式自定义主题',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  activeThemeName == null
                      ? '当前未启用高级主题，应用后会覆盖基础主题中的已配置项。'
                      : '当前生效：$activeThemeName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.palette_outlined, size: 34, color: colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            '还没有高级主题',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '点击右上角新增，就可以分别配置浅色和深色主题。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    AppAdvancedTheme theme, {
    required bool isActive,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isSaving ? null : () => _openEditor(theme),
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
              children: [
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
                    ],
                  ),
                ),
                PopupMenuButton<_AdvancedThemeAction>(
                  enabled: !_isSaving,
                  onSelected: (action) {
                    switch (action) {
                      case _AdvancedThemeAction.edit:
                        _openEditor(theme);
                      case _AdvancedThemeAction.duplicate:
                        _duplicateTheme(theme);
                      case _AdvancedThemeAction.exportJson:
                        _exportTheme(theme);
                      case _AdvancedThemeAction.exportZip:
                        _exportThemeBundle(theme);
                      case _AdvancedThemeAction.delete:
                        _deleteTheme(theme);
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
            const SizedBox(height: 10),
            _buildDualModePreviewStrip(context, theme),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildResourceBadges(context, theme),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _isSaving
                        ? null
                        : isActive
                        ? _disableActiveTheme
                        : () => _applyTheme(theme),
                child: Text(isActive ? '停用主题' : '应用主题'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDualModePreviewStrip(
    BuildContext context,
    AppAdvancedTheme theme,
  ) {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildPreviewSegment(
                context,
                mode: AppAdvancedThemeMode.light,
                config: theme.lightConfig,
                isLeft: true,
              ),
              ClipPath(
                clipper: _DiagonalSplitClipper(),
                child: _buildPreviewSegment(
                  context,
                  mode: AppAdvancedThemeMode.dark,
                  config: theme.darkConfig,
                  isLeft: false,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _DiagonalSplitLinePainter(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreviewSegment(
    BuildContext context, {
    required AppAdvancedThemeMode mode,
    required AppAdvancedThemeModeConfig config,
    required bool isLeft,
  }) {
    final defaultScheme = _defaultSchemeFor(context, mode);
    final palette = resolveAdvancedThemePaletteFromModeConfig(
      defaultScheme,
      config,
    );
    final backdrop = resolveAdvancedThemeBackdropFromModeConfig(
      defaultScheme,
      config,
    );
    final label = mode == AppAdvancedThemeMode.light ? '浅色' : '深色';

    return Container(
      decoration: buildAdvancedThemeBackdropDecoration(backdrop),
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

  List<Widget> _buildResourceBadges(
    BuildContext context,
    AppAdvancedTheme theme,
  ) {
    final badges = <Widget>[];
    if (theme.lightConfig.hasWallpaper || theme.darkConfig.hasWallpaper) {
      badges.add(_buildResourceBadge(context, label: '壁纸'));
    }
    if (theme.lightConfig.hasReaderWallpaper ||
        theme.darkConfig.hasReaderWallpaper) {
      badges.add(_buildResourceBadge(context, label: '阅读器背景'));
    }
    if ((theme.coverGalleryId?.trim().isNotEmpty ?? false)) {
      badges.add(_buildResourceBadge(context, label: '封面'));
    }
    if ((theme.launchImageGalleryId?.trim().isNotEmpty ?? false)) {
      badges.add(_buildResourceBadge(context, label: '启动图'));
    }
    if ((theme.bottomNavGalleryId?.trim().isNotEmpty ?? false)) {
      badges.add(_buildResourceBadge(context, label: '底栏'));
    }
    if (badges.isEmpty) {
      badges.add(_buildResourceBadge(context, label: '仅颜色'));
    }
    return badges;
  }

  Widget _buildResourceBadge(BuildContext context, {required String label}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
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
