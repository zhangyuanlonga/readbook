import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/membership/membership_features.dart';
import '../../../core/membership/membership_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../application/advanced_theme_export_error_formatter.dart';
import '../application/advanced_theme_resource_reference_service.dart';
import '../application/advanced_theme_service.dart';
import '../../source/application/external_import_diagnostics.dart';
import '../../source/application/external_import_catalog.dart';
import '../../source/application/external_source_import_bridge.dart';
import '../application/advanced_theme_page_flow_coordinator.dart';
import '../application/advanced_theme_provider.dart';
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

enum _AdvancedThemeListMoreAction { importTheme, importBatch, exportBatch }

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
  late final MembershipService _membershipService;
  late final AdvancedThemePageFlowCoordinator _pageFlowCoordinator;
  final TextEditingController _searchController = TextEditingController();
  List<AdvancedThemeSummary> _themeSummaries = const <AdvancedThemeSummary>[];
  String _searchQuery = '';
  String? _selectedCategory;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isConsumingExternalImportPayloads = false;
  bool _isAccessLoading = true;
  bool _canUseAdvancedThemes = false;

  @override
  void initState() {
    super.initState();
    _sessionStore = ref.read(mineAuthSessionStoreProvider);
    _membershipService = ref.read(mineMembershipServiceProvider);
    _pageFlowCoordinator =
        ref.read(advancedThemePageFlowCoordinatorFactoryProvider)();
    _pageFlowCoordinator.initialize(
      onPendingImportAvailable: () {
        unawaited(_consumePendingExternalImportPayloads());
      },
      onAuthEvent: _handleAuthEvent,
    );
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
    _searchController.dispose();
    unawaited(_pageFlowCoordinator.dispose());
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
    final themes = await service.loadThemeSummaries();
    if (!mounted) {
      return;
    }
    final activeThemeId = ref.read(activeAdvancedThemeIdProvider);
    final sortedThemes = List<AdvancedThemeSummary>.from(themes)..sort((a, b) {
      final aIsActive = a.id == activeThemeId;
      final bIsActive = b.id == activeThemeId;
      if (aIsActive != bIsActive) {
        return aIsActive ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    setState(() {
      _themeSummaries = sortedThemes;
      if (_selectedCategory != null &&
          !_availableCategories.contains(_selectedCategory)) {
        _selectedCategory = null;
      }
      _isLoading = false;
    });
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

  Future<void> _exportThemeBundle(String themeId) async {
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
    final cached = await _pageFlowCoordinator.cacheExternalFileFromUri(payload);
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
    final file = File(path);
    final bytes = await file.readAsBytes();
    return _importThemeBytes(
      path: path,
      bytes: bytes,
      mimeType: mimeType,
      packageKind: packageKind,
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
      case _AdvancedThemeListMoreAction.importTheme:
        unawaited(_importTheme());
        break;
      case _AdvancedThemeListMoreAction.importBatch:
        unawaited(_openBatchImportSheet());
        break;
      case _AdvancedThemeListMoreAction.exportBatch:
        unawaited(_exportThemeBatch());
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
          isDismissible: false,
          enableDrag: false,
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
    onProgress?.call(_AdvancedThemeImportQueueItemStatus.reading, '正在读取文件');
    await _yieldToUi();
    final bytes = await File(path).readAsBytes();
    if (_isBatchBundleFile(path: path, mimeType: mimeType, bytes: bytes)) {
      onProgress?.call(
        _AdvancedThemeImportQueueItemStatus.parsing,
        '正在解析批量主题包',
      );
      await _yieldToUi();
      return _importThemeBatchBundleBytes(bytes, onProgress: onProgress);
    }
    onProgress?.call(_AdvancedThemeImportQueueItemStatus.importing, '正在导入主题');
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

  Future<_AdvancedThemeBatchImportSummary> _importThemeBatchBundleBytes(
    List<int> bytes, {
    _AdvancedThemeBatchImportProgressCallback? onProgress,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
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
    final importableEntries = entries.whereType<Map>().toList(growable: false);
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
      try {
        await _importThemeBytes(
          path: bundlePath,
          bytes: List<int>.from(archiveFile.content),
          mimeType: 'application/zip',
          packageKind: _ThemeImportPackageKind.official,
          reloadAfterImport: false,
          markRevision: false,
        );
        successCount += 1;
      } catch (error) {
        failureCount += 1;
        lastError = formatAdvancedThemeExportError(error);
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
    final resolvedBytes = bytes;
    if (resolvedBytes == null) {
      return false;
    }
    try {
      final archive = ZipDecoder().decodeBytes(resolvedBytes, verify: false);
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

  Future<void> _exportThemeBatch() async {
    if (_isSaving) {
      return;
    }
    if (_themeSummaries.isEmpty) {
      _showMessage('暂无可导出的主题。');
      return;
    }

    final targetThemes = await _chooseThemesForBatchExport();
    if (targetThemes == null || targetThemes.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final bundleBytes = await _buildThemeBatchBundle(summaries: targetThemes);
      final fileName =
          'advanced_themes_batch_${_formattedTimestampForFileName(DateTime.now())}.zip';
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
        await file.writeAsBytes(bundleBytes, flush: true);
        completed = true;
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bundleBytes, flush: true);
        completed = await _shareExportedThemeFile(
          file: file,
          text: '分享高级主题包，共 ${targetThemes.length} 个主题',
          subject: '高级主题批量导出',
        );
      }
      if (!completed || !mounted) {
        return;
      }
      _showMessage('已导出 ${targetThemes.length} 个主题');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('批量导出失败：${formatAdvancedThemeExportError(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<List<AdvancedThemeSummary>?> _chooseThemesForBatchExport() async {
    if (_themeSummaries.isEmpty) {
      return null;
    }
    return showModalBottomSheet<List<AdvancedThemeSummary>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final selectedIds = _themeSummaries.map((item) => item.id).toSet();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allSelected = selectedIds.length == _themeSummaries.length;
            final selectedCount = selectedIds.length;
            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '选择要导出的主题',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '先勾选主题，再确认导出。已选 $selectedCount / ${_themeSummaries.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: allSelected,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('全选主题'),
                        subtitle: const Text('勾选后会把当前全部高级主题打包导出'),
                        onChanged: (value) {
                          setSheetState(() {
                            selectedIds
                              ..clear()
                              ..addAll(
                                value == true
                                    ? _themeSummaries.map((item) => item.id)
                                    : const <String>[],
                              );
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _themeSummaries.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final theme = _themeSummaries[index];
                            final checked = selectedIds.contains(theme.id);
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setSheetState(() {
                                  if (checked) {
                                    selectedIds.remove(theme.id);
                                  } else {
                                    selectedIds.add(theme.id);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        checked
                                            ? colorScheme.primary.withValues(
                                              alpha: 0.6,
                                            )
                                            : colorScheme.outlineVariant
                                                .withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      onChanged: (value) {
                                        setSheetState(() {
                                          if (value == true) {
                                            selectedIds.add(theme.id);
                                          } else {
                                            selectedIds.remove(theme.id);
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            theme.name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if ((theme.category
                                                  ?.trim()
                                                  .isNotEmpty ??
                                              false))
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                theme.category!.trim(),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall?.copyWith(
                                                  color:
                                                      colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  selectedIds.isEmpty
                                      ? null
                                      : () {
                                        final selectedThemes = _themeSummaries
                                            .where(
                                              (item) =>
                                                  selectedIds.contains(item.id),
                                            )
                                            .toList(growable: false);
                                        Navigator.of(
                                          sheetContext,
                                        ).pop(selectedThemes);
                                      },
                              child: const Text('确定'),
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

  Future<List<int>> _buildThemeBatchBundle({
    required List<AdvancedThemeSummary> summaries,
  }) async {
    final service = ref.read(advancedThemeServiceProvider);
    final archive = Archive();
    final manifestThemes = <Map<String, Object?>>[];
    var index = 0;

    for (final summary in summaries) {
      final theme = await _loadThemeDetail(summary.id);
      if (theme == null) {
        continue;
      }
      index += 1;
      final bundleBytes = await service.encodeThemeBundleZip(theme);
      final normalizedName = _normalizedFileName(theme.name);
      final bundlePath =
          'themes/${index.toString().padLeft(3, '0')}_$normalizedName.zip';
      archive.addFile(ArchiveFile(bundlePath, bundleBytes.length, bundleBytes));
      manifestThemes.add(<String, Object?>{
        'id': theme.id,
        'name': theme.name,
        'file': bundlePath,
      });
    }

    if (manifestThemes.isEmpty) {
      throw const FormatException('没有可打包的主题内容。');
    }

    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'type': _batchBundleType,
        'version': _batchBundleVersion,
        'generatedAt': DateTime.now().toIso8601String(),
        'themes': manifestThemes,
      }),
    );
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    return ZipEncoder().encode(archive);
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
                      const SizedBox(height: 6),
                      Text(
                        preview.hasAssociatedResources
                            ? '下面列的是该主题当前绑定的实际资源。共享资源即使勾选，也只有在没有其他主题或设置引用时才会真正删除。'
                            : '该主题没有额外绑定资源，只会删除主题实体本身。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      if (preview.sections.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        for (final section in preview.sections) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CheckboxListTile(
                                    value: selections[section.kind] ?? false,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(
                                      section.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(section.helperText),
                                    onChanged: (value) {
                                      setSheetState(() {
                                        selections[section.kind] =
                                            value ?? false;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  for (final item in section.items)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 8,
                                        bottom: 6,
                                      ),
                                      child: Text(
                                        '• $item',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                ],
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
          leading: IconButton(
            tooltip: '返回',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go('/mine');
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: const Text('高级主题'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: '新建高级主题',
              onPressed: _isLoading || _isSaving ? null : () => _openEditor(),
              icon: const Icon(Icons.palette_outlined),
            ),
            PopupMenuButton<_AdvancedThemeListMoreAction>(
              enabled: !_isLoading && !_isSaving,
              tooltip: '更多',
              onSelected: _handleMoreAction,
              itemBuilder:
                  (context) =>
                      const <PopupMenuEntry<_AdvancedThemeListMoreAction>>[
                        PopupMenuItem(
                          value: _AdvancedThemeListMoreAction.importTheme,
                          child: Text('导入主题'),
                        ),
                        PopupMenuItem(
                          value: _AdvancedThemeListMoreAction.importBatch,
                          child: Text('批量导入'),
                        ),
                        PopupMenuItem(
                          value: _AdvancedThemeListMoreAction.exportBatch,
                          child: Text('批量导出'),
                        ),
                      ],
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
                          : _buildThemeListView(
                            context,
                            activeThemeAsync: activeThemeAsync,
                            activeThemeId: activeThemeId,
                            horizontal: horizontal,
                            bottomSafe: bottomSafe,
                            topInset: topInset,
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

  Widget _buildThemeListView(
    BuildContext context, {
    required AsyncValue<AppAdvancedTheme?> activeThemeAsync,
    required String? activeThemeId,
    required double horizontal,
    required double bottomSafe,
    required double topInset,
  }) {
    final visibleThemes = _visibleThemes;
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
                const SizedBox(height: 10),
                if (_availableCategories.isNotEmpty)
                  _buildCategoryChips(context),
                if (_availableCategories.isNotEmpty) const SizedBox(height: 10),
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

  Widget _buildListStatusRow(
    BuildContext context, {
    required AsyncValue<AppAdvancedTheme?> activeThemeAsync,
    required int visibleThemeCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
        activeThemeName == null ? '当前应用 未启用' : '当前应用 $activeThemeName';
    return Row(
      children: [
        Expanded(
          child: Text(
            countLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            activeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return CompactCollectionSearchField(
      controller: _searchController,
      hintText: '搜索主题名称或分类',
      query: _searchQuery,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      onClear: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
        });
      },
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: _selectedCategory == null,
            onSelected: (_) {
              setState(() {
                _selectedCategory = null;
              });
            },
          ),
          const SizedBox(width: 8),
          for (final category in _availableCategories) ...[
            ChoiceChip(
              label: Text(category),
              selected: _selectedCategory == category,
              onSelected: (_) {
                setState(() {
                  _selectedCategory =
                      _selectedCategory == category ? null : category;
                });
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
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
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isSaving ? null : () => _openEditor(theme.id),
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
                        : () => unawaited(_applyThemeById(theme.id)),
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
    AdvancedThemeSummary theme,
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[palette.backgroundColor, palette.surfaceColor],
        ),
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

  List<Widget> _buildResourceBadges(
    BuildContext context,
    AdvancedThemeSummary theme,
  ) {
    final badges = <Widget>[];
    final category = theme.category?.trim();
    if (category != null && category.isNotEmpty) {
      badges.add(_buildResourceBadge(context, label: '分类：$category'));
    }
    if (theme.lightMode.hasWallpaper || theme.darkMode.hasWallpaper) {
      badges.add(_buildResourceBadge(context, label: '壁纸'));
    }
    if (theme.lightMode.hasReaderWallpaper ||
        theme.darkMode.hasReaderWallpaper) {
      badges.add(_buildResourceBadge(context, label: '阅读器背景'));
    }
    if (theme.hasCoverGalleryBinding) {
      badges.add(_buildResourceBadge(context, label: '封面'));
    }
    if (theme.hasLaunchImageGallery) {
      badges.add(_buildResourceBadge(context, label: '启动图'));
    }
    if (theme.hasBottomNavGallery) {
      badges.add(_buildResourceBadge(context, label: '底栏'));
    }
    if (theme.hasAppInterfaceFont) {
      badges.add(_buildResourceBadge(context, label: '界面字体'));
    }
    if (theme.hasReaderFont) {
      badges.add(_buildResourceBadge(context, label: '阅读字体'));
    }
    if (theme.hasBothModesConfigured) {
      badges.add(_buildResourceBadge(context, label: '双模式完整'));
    }
    if (badges.isEmpty) {
      badges.add(_buildResourceBadge(context, label: '仅颜色'));
    }
    return badges;
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
  String _headerMessage = '添加主题文件后开始导入';

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
        detail: '正在准备 ${item.fileName}',
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
      _headerMessage = next.isEmpty ? '添加主题文件后开始导入' : '已选择 ${next.length} 个文件';
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

  void _closeSheet() {
    if (_isImporting) {
      return;
    }
    Navigator.of(context).pop(_summary);
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

    return PopScope<void>(
      canPop: !_isImporting,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomSafe),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '批量导入主题',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '导入说明',
                      onPressed:
                          _isImporting ? null : widget.onShowImportSupportHelp,
                      icon: const Icon(Icons.help_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                const SizedBox(height: 14),
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
                  const SizedBox(height: 12),
                ],
                Flexible(
                  child:
                      _items.isEmpty
                          ? _buildEmptyPicker(context)
                          : _buildImportQueue(context),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isImporting ? null : _closeSheet,
                        child: Text(summary == null ? '取消' : '完成'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _isImporting
                                ? null
                                : summary == null
                                ? (_items.isEmpty ? _pickFiles : _startImport)
                                : _resetQueue,
                        icon: Icon(
                          summary == null
                              ? (_items.isEmpty
                                  ? Icons.add_rounded
                                  : Icons.file_upload_outlined)
                              : Icons.restart_alt_rounded,
                        ),
                        label: Text(
                          summary == null
                              ? (_items.isEmpty ? '添加文件' : '开始导入')
                              : '再导入一批',
                        ),
                      ),
                    ),
                  ],
                ),
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
      _headerMessage = '添加主题文件后开始导入';
    });
  }

  Widget _buildEmptyPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _pickFiles,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '添加主题文件',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
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
            TextButton.icon(
              onPressed: _isImporting ? null : _pickFiles,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('添加'),
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
