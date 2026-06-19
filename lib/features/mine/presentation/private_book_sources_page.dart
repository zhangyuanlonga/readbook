import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/composition/app_providers.dart' as app_providers;
import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/app_task_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../../../app/platform/app_platform_capabilities.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/source_access/source_access_provider.dart';
import '../../auth/providers.dart' as auth_providers;
import '../../source/application/external_import_catalog.dart';
import '../application/advanced_theme_provider.dart';
import '../application/book_source_import_payload.dart';
import '../application/private_book_source_provider.dart';
import '../application/private_book_source_service.dart';
import 'private_book_source_filter_presenter.dart';
import 'private_book_source_presentation.dart';
import 'widgets/mine_route_top_bar.dart';
import 'widgets/private_book_source_detail_sheet.dart';
import 'widgets/private_book_source_state_cards.dart';
import 'widgets/private_book_source_tile.dart';
import 'widgets/private_book_source_toolbar.dart';

final _privateBookSourceSearchKeywordProvider =
    StateProvider.autoDispose<String>((ref) {
      return '';
    });

final _privateBookSourcesAuthSessionProvider =
    FutureProvider.autoDispose<AuthSession?>((ref) async {
      late final StreamSubscription<AuthEvent> subscription;
      subscription = ref.watch(app_providers.appAuthEventStreamProvider).listen(
        (_) {
          ref.invalidateSelf();
        },
      );
      ref.onDispose(() {
        unawaited(subscription.cancel());
      });

      final session =
          await ref.watch(auth_providers.authSessionStoreProvider).getSession();
      if (session == null || !session.isValid) {
        return null;
      }
      return session;
    });

enum _BookSourceImportMethod { url, file, paste }

const int _maxBookSourceImportBytes = 10 * 1024 * 1024;

class PrivateBookSourcesPage extends ConsumerWidget {
  const PrivateBookSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSessionAsync = ref.watch(_privateBookSourcesAuthSessionProvider);
    final authenticated = authSessionAsync.maybeWhen(
      data: (session) => session?.isValid ?? false,
      orElse: () => false,
    );
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final routeTopBar = _buildRouteTopBar(
      context,
      ref,
      authenticated: authenticated,
    );
    final topInset =
        MediaQuery.paddingOf(context).top + routeTopBar.preferredSize.height;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final contentChildren = authSessionAsync.when(
      data: (session) {
        if (session == null || !session.isValid) {
          return <Widget>[
            PrivateBookSourceLoginRequiredCard(
              onLogin: () => context.push('/auth'),
            ),
          ];
        }
        final selectedGroupId = ref.watch(
          selectedPrivateBookSourceGroupProvider,
        );
        final listAsync = ref.watch(
          privateBookSourcesProvider(selectedGroupId),
        );
        final groupsAsync = ref.watch(privateBookSourceGroupsProvider);
        final quotaAsync = ref.watch(sourceQuotaProvider);
        final searchKeyword = ref.watch(
          _privateBookSourceSearchKeywordProvider,
        );
        return <Widget>[
          PrivateBookSourceToolbar(
            keyword: searchKeyword,
            selectedGroupId: selectedGroupId,
            groupsAsync: groupsAsync,
            onKeywordChanged:
                (value) =>
                    ref
                        .read(_privateBookSourceSearchKeywordProvider.notifier)
                        .state = value,
            onKeywordCleared:
                () =>
                    ref
                        .read(_privateBookSourceSearchKeywordProvider.notifier)
                        .state = '',
            onGroupSelected: (groupId) {
              ref.read(selectedPrivateBookSourceGroupProvider.notifier).state =
                  groupId;
            },
            onRetry: () => ref.invalidate(privateBookSourceGroupsProvider),
          ),
          SizedBox(height: metrics.contentGap),
          quotaAsync.when(
            data: (quota) => _QuotaCard(quota: quota),
            loading:
                () => const PrivateBookSourceLoadingCard(message: '正在读取额度'),
            error:
                (error, _) => PrivateBookSourceErrorCard(
                  title: '额度读取失败',
                  message: _messageOf(error),
                  onRetry: () => ref.invalidate(sourceQuotaProvider),
                ),
          ),
          SizedBox(height: metrics.contentGap),
          listAsync.when(
            data: (result) {
              if (result.items.isEmpty) {
                return PrivateBookSourceEmptySourcesCard(
                  onCreate: () => unawaited(_openCreateForm(context, ref)),
                );
              }
              final visibleItems = PrivateBookSourceListFilter.filter(
                result.items,
                searchKeyword,
              );
              if (visibleItems.isEmpty) {
                return PrivateBookSourceFilterEmptyCard(
                  keyword: searchKeyword,
                  onClear:
                      () =>
                          ref
                              .read(
                                _privateBookSourceSearchKeywordProvider
                                    .notifier,
                              )
                              .state = '',
                );
              }
              return Column(
                children: <Widget>[
                  for (final item in visibleItems) ...<Widget>[
                    PrivateBookSourceTile(
                      item: item,
                      onDetail:
                          () =>
                              unawaited(_openDetail(context, ref, item: item)),
                      onEdit:
                          () => unawaited(_openForm(context, ref, item: item)),
                      onDelete:
                          () => unawaited(_deleteSource(context, ref, item)),
                      onTest: () => unawaited(_testSource(context, ref, item)),
                      onSubmit:
                          () => unawaited(_submitSource(context, ref, item)),
                    ),
                    SizedBox(height: metrics.contentGap),
                  ],
                ],
              );
            },
            loading:
                () => const PrivateBookSourceLoadingCard(message: '正在加载书源'),
            error:
                (error, _) => PrivateBookSourceErrorCard(
                  title: '书源加载失败',
                  message: _messageOf(error),
                  onRetry: () => ref.invalidate(privateBookSourcesProvider),
                ),
          ),
        ];
      },
      loading:
          () => const <Widget>[
            PrivateBookSourceLoadingCard(message: '正在检查登录状态'),
          ],
      error:
          (error, _) => <Widget>[
            PrivateBookSourceLoginRequiredCard(
              onLogin: () => context.push('/auth'),
            ),
          ],
    );

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go('/mine');
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: routeTopBar,
        body: DecoratedBox(
          decoration: buildAdvancedThemeBackdropDecoration(backdrop),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: AppLayout.settingsContentMaxWidth,
                ),
              ),
              child: AppRefreshIndicator(
                semanticsLabel: '刷新私有书源',
                onRefresh: () async => _refresh(ref),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    topInset + metrics.contentGap,
                    horizontal,
                    bottomInset + metrics.sectionGap,
                  ),
                  children: contentChildren,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static PreferredSizeWidget _buildRouteTopBar(
    BuildContext context,
    WidgetRef ref, {
    required bool authenticated,
  }) {
    return buildMineRouteTopBar(
      context: context,
      title: '我的书源',
      subtitle: '私人书源与共享审核',
      actions:
          authenticated
              ? <AdaptiveOverflowToolbarItem>[
                AdaptiveOverflowToolbarItem(
                  icon: Icons.folder_copy_outlined,
                  label: '分组',
                  priority: 9,
                  onPressed: () => unawaited(_openGroupManager(context, ref)),
                ),
                AdaptiveOverflowToolbarItem(
                  icon: Icons.add_rounded,
                  label: '新增书源',
                  priority: 10,
                  onPressed: () => unawaited(_openCreateForm(context, ref)),
                ),
              ]
              : const <AdaptiveOverflowToolbarItem>[],
      mobileActions:
          authenticated
              ? <Widget>[
                IconButton(
                  tooltip: '分组',
                  onPressed: () => unawaited(_openGroupManager(context, ref)),
                  icon: const Icon(Icons.folder_copy_outlined),
                ),
                IconButton(
                  tooltip: '新增书源',
                  onPressed: () => unawaited(_openCreateForm(context, ref)),
                  icon: const Icon(Icons.add_rounded),
                ),
              ]
              : const <Widget>[],
    );
  }

  static Future<void> _openGroupManager(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final changed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 560,
      maxHeightFactor: 0.86,
      padding: EdgeInsets.zero,
      builder: (context) => const _PrivateSourceGroupManagerSheet(),
    );
    if (!context.mounted) {
      return;
    }
    if (changed == true) {
      _refresh(ref);
    }
  }

  static void _refresh(WidgetRef ref) {
    final selectedGroupId = ref.read(selectedPrivateBookSourceGroupProvider);
    ref.invalidate(privateBookSourcesProvider);
    ref.invalidate(privateBookSourcesProvider(selectedGroupId));
    ref.invalidate(privateBookSourcesProvider(null));
    ref.invalidate(privateBookSourceGroupsProvider);
    ref.invalidate(sourceQuotaProvider);
    ref.invalidate(sourceAccessScopeProvider);
  }

  static Future<void> _openCreateForm(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final method = await _selectBookSourceImportMethod(context);
    if (method == null || !context.mounted) {
      return;
    }
    await _openForm(context, ref, initialImportMethod: method);
  }

  static Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    PrivateBookSourceItem? item,
    _BookSourceImportMethod initialImportMethod = _BookSourceImportMethod.paste,
  }) async {
    var formItem = item;
    if (item != null && (item.sourceJson.isEmpty && item.sourceCode.isEmpty)) {
      formItem = await _loadSourceDetailForEdit(context, ref, item);
      if (formItem == null || !context.mounted) {
        return;
      }
    }
    final saved = await showAdaptiveActionSurface<PrivateBookSourceItem?>(
      context: context,
      maxWidth: 680,
      maxHeightFactor: 0.9,
      padding: EdgeInsets.zero,
      builder:
          (context) => _PrivateSourceForm(
            item: formItem,
            initialImportMethod: initialImportMethod,
          ),
    );
    if (saved != null) {
      ref.read(_privateBookSourceSearchKeywordProvider.notifier).state = '';
      ref.read(selectedPrivateBookSourceGroupProvider.notifier).state = null;
      _refresh(ref);
    }
  }

  static Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref, {
    required PrivateBookSourceItem item,
  }) async {
    final action =
        await showAdaptiveActionSurface<PrivateBookSourceDetailAction>(
          context: context,
          maxWidth: 560,
          maxHeightFactor: 0.86,
          padding: EdgeInsets.zero,
          builder: (context) => PrivateBookSourceDetailSheet(item: item),
        );
    if (!context.mounted) {
      return;
    }
    switch (action) {
      case PrivateBookSourceDetailAction.edit:
        await _openForm(context, ref, item: item);
        return;
      case PrivateBookSourceDetailAction.test:
        await _testSource(context, ref, item);
        return;
      case null:
        return;
    }
  }

  static Future<_BookSourceImportMethod?> _selectBookSourceImportMethod(
    BuildContext context,
  ) {
    return showAdaptiveActionSurface<_BookSourceImportMethod>(
      context: context,
      maxWidth: 460,
      padding: EdgeInsets.zero,
      builder: (context) => const _BookSourceImportMethodSheet(),
    );
  }

  static Future<_PreparedBookSourceImport> _prepareUrlImport(String url) async {
    final raw = await _loadRawImportFromUrl(url);
    return _prepareLoadedImport(method: _BookSourceImportMethod.url, raw: raw);
  }

  static Future<_PreparedBookSourceImport> _prepareLoadedImport({
    required _BookSourceImportMethod method,
    required _RawBookSourceImport raw,
  }) async {
    _ensureCreateImportSize(raw.text);
    final payload = await compute(parseBookSourceImportPayload, raw.text);
    final imported = _PreparedBookSourceImport(
      label: raw.label,
      payload: payload,
    );
    AppLogger.instance.info(
      'Book source JSON loaded',
      context: <String, Object?>{
        'method': method.name,
        'bytes': payload.sizeBytes,
        'lines': payload.lineCount,
      },
    );
    return imported;
  }

  static Future<_RawBookSourceImport> _loadRawImportFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty) {
      throw const FormatException('请输入 http/https 链接');
    }
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
      ),
    );
    final response = await dio.get<String>(
      uri.toString(),
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (_) => true,
      ),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw FormatException('链接请求失败（$statusCode）');
    }
    final text = response.data ?? '';
    if (text.trim().isEmpty) {
      throw const FormatException('链接返回内容为空');
    }
    return _RawBookSourceImport(text: text, label: uri.host);
  }

  static Future<_RawBookSourceImport?> _loadRawImportFromFile() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        ExternalImportCatalog.bookSourceJsonTypeGroup,
      ],
      confirmButtonText: '选择书源文件',
    );
    if (file == null) {
      return null;
    }
    final size = await file.length();
    if (size > _maxBookSourceImportBytes) {
      throw const FormatException('文件过大，最大支持 10 MB');
    }
    final text = await file.readAsString();
    final label = file.name.trim().isEmpty ? '本地文件' : file.name.trim();
    return _RawBookSourceImport(text: text, label: label);
  }

  static Future<_RawBookSourceImport> _loadRawImportFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      throw const FormatException('剪贴板没有 JSON 文本');
    }
    return _RawBookSourceImport(text: text, label: '剪贴板');
  }

  static void _ensureCreateImportSize(String value) {
    if (bookSourceUtf8SizeOf(value) > _maxBookSourceImportBytes) {
      throw const FormatException('文件过大，最大支持 10 MB');
    }
  }

  static void _showImportSuccess(
    BuildContext context,
    _PreparedBookSourceImport imported,
  ) {
    AppFeedback.showSnackBar(
      context,
      message: '已加载书源 JSON：${formatBookSourceSize(imported.payload.sizeBytes)}',
      tone: AppFeedbackTone.success,
      useHaptics: false,
    );
  }

  static void _showImportFailure(
    BuildContext context, {
    required _BookSourceImportMethod method,
    required String message,
  }) {
    AppLogger.instance.warn(
      'Book source JSON import failed',
      context: <String, Object?>{'method': method.name, 'message': message},
    );
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone: AppFeedbackTone.error,
      useHaptics: false,
    );
  }

  static Future<PrivateBookSourceItem?> _loadSourceDetailForEdit(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final loading = AppFeedback.showSnackBar(
      context,
      message: '正在读取书源详情',
      tone: AppFeedbackTone.loading,
      useHaptics: false,
    );
    try {
      final detail = await ref
          .read(privateBookSourceServiceProvider)
          .get(item.id);
      loading.close();
      return detail;
    } catch (error) {
      loading.close();
      if (context.mounted) {
        AppFeedback.showSnackBar(
          context,
          message: '书源详情读取失败：${_messageOf(error)}',
          tone: AppFeedbackTone.error,
          useHaptics: false,
        );
      }
      return null;
    }
  }

  static Future<void> _deleteSource(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 420,
      builder:
          (context) => _ConfirmActionSurface(
            icon: Icons.delete_outline,
            title: '删除书源',
            message: '确认删除“${item.name}”？删除后不可恢复。',
            confirmLabel: '删除',
            destructive: true,
          ),
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _runVoidAction(
      context,
      ref,
      () => ref.read(privateBookSourceServiceProvider).delete(item.id),
      '书源已删除',
    );
  }

  static Future<void> _submitSource(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final noteController = TextEditingController(text: item.description);
    final note = await showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 520,
      builder:
          (context) => _SubmitSourceReviewSurface(controller: noteController),
    );
    noteController.dispose();
    if (note == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _runVoidAction(
      context,
      ref,
      () => ref.read(privateBookSourceServiceProvider).submit(item.id, note),
      '已提交共享审核',
    );
  }

  static Future<void> _testSource(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final config = await showAdaptiveActionSurface<_SourceTestConfig>(
      context: context,
      maxWidth: 560,
      maxHeightFactor: 0.7,
      padding: EdgeInsets.zero,
      builder: (context) => _SourceTestConfigSheet(item: item),
    );
    if (config == null || !context.mounted) {
      return;
    }
    try {
      final result = await ref
          .read(privateBookSourceServiceProvider)
          .test(
            item.id,
            keyword: config.keyword,
            timeoutMs: config.timeoutMs,
            checkItems: config.checkItems,
          );
      if (!context.mounted) {
        return;
      }
      _refresh(ref);
      final report = result.report;
      if (report != null) {
        await showAdaptiveActionSurface<void>(
          context: context,
          maxWidth: 680,
          maxHeightFactor: 0.7,
          padding: EdgeInsets.zero,
          builder: (context) => _SourceCheckReportSheet(report: report),
        );
        return;
      }
      AppFeedback.showSnackBar(
        context,
        message: '书源检测已记录：${_testLabel(result.item.lastTestStatus)}',
        useHaptics: false,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppFeedback.showSnackBar(
        context,
        message: _messageOf(error),
        tone: AppFeedbackTone.error,
        useHaptics: false,
      );
    }
  }

  static Future<void> _runVoidAction(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!context.mounted) {
        return;
      }
      _refresh(ref);
      AppFeedback.showSnackBar(
        context,
        message: success,
        tone: AppFeedbackTone.success,
        useHaptics: false,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppFeedback.showSnackBar(
        context,
        message: _messageOf(error),
        tone: AppFeedbackTone.error,
        useHaptics: false,
      );
    }
  }
}

class _BookSourceImportMethodSheet extends StatelessWidget {
  const _BookSourceImportMethodSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '选择导入方式',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _BookSourceImportMethodTile(
              icon: Icons.link_rounded,
              title: '通过链接导入',
              subtitle: '适合分享链接和大 JSON',
              onTap:
                  () => Navigator.of(context).pop(_BookSourceImportMethod.url),
            ),
            const Divider(height: 1, indent: 56),
            _BookSourceImportMethodTile(
              icon: Icons.folder_open_rounded,
              title: '从文件选择',
              subtitle: '读取本地 .json 或 .txt',
              onTap:
                  () => Navigator.of(context).pop(_BookSourceImportMethod.file),
            ),
            const Divider(height: 1, indent: 56),
            _BookSourceImportMethodTile(
              icon: Icons.copy_rounded,
              title: '粘贴 JSON',
              subtitle: '从剪贴板读取并预览',
              onTap:
                  () =>
                      Navigator.of(context).pop(_BookSourceImportMethod.paste),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookSourceImportMethodTile extends StatelessWidget {
  const _BookSourceImportMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _ConfirmActionSurface extends StatelessWidget {
  const _ConfirmActionSurface({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = destructive ? colorScheme.error : colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style:
                  destructive
                      ? FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      )
                      : null,
              child: Text(confirmLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class _RenameGroupSurface extends StatelessWidget {
  const _RenameGroupSurface({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '重命名分组',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分组名称'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubmitSourceReviewSurface extends StatelessWidget {
  const _SubmitSourceReviewSurface({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '提交共享审核',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '提交说明',
            hintText: '说明这个书源适合共享的原因',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('提交'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota});

  final SourceQuotaSnapshot quota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _QuotaPill(
              label:
                  '总书源 ${quota.privateSourceCount}/${_limitText(quota.maxPrivateSources)}',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _QuotaPill(
              label:
                  '检测 ${quota.dailyTestUsed}/${_limitText(quota.dailyTestLimit)}',
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuotaPill extends StatelessWidget {
  const _QuotaPill({required this.label, this.foregroundColor});

  final String label;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = foregroundColor ?? colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.52),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateSourceGroupManagerSheet extends ConsumerStatefulWidget {
  const _PrivateSourceGroupManagerSheet();

  @override
  ConsumerState<_PrivateSourceGroupManagerSheet> createState() =>
      _PrivateSourceGroupManagerSheetState();
}

class _PrivateSourceGroupManagerSheetState
    extends ConsumerState<_PrivateSourceGroupManagerSheet> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final groupsAsync = ref.watch(privateBookSourceGroupsProvider);
    final metrics = AppAdaptiveMetrics.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        metrics.contentGap,
        16,
        bottomInset + metrics.sectionGap,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _nameController,
                      enabled: !_saving,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.15),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLowest
                            .withValues(alpha: 0.94),
                        hintText: '新增分组，例如：常用、漫画、备用',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.48,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.48,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.78),
                            width: 1.4,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => unawaited(_createGroup()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: _saving ? '保存中' : '新增分组',
                  child: SizedBox.square(
                    dimension: 48,
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => unawaited(_createGroup()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        backgroundColor: Colors.transparent,
                        fixedSize: const Size.square(48),
                        minimumSize: const Size.square(48),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.62,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child:
                          _saving
                              ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              )
                              : const Icon(Icons.add_rounded, size: 26),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const AppEmptyStateCard(
                      icon: Icons.folder_off_outlined,
                      title: '暂无私人分组',
                      description: '新增分组后，可以在书源编辑里选择或填写对应分组名。',
                      compact: true,
                    );
                  }
                  return ListView.separated(
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final isDefault = _isDefaultGroup(group);
                      return Material(
                        color: Theme.of(context).colorScheme.surfaceContainerLow
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color:
                                        isDefault
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer
                                            : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isDefault
                                        ? Icons.folder_special_outlined
                                        : Icons.folder_outlined,
                                    size: 20,
                                    color:
                                        isDefault
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer
                                            : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        group.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isDefault ? '默认书源分组' : '私人书源分组',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: '重命名',
                                  onPressed:
                                      () => unawaited(_renameGroup(group)),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '删除',
                                  onPressed:
                                      isDefault
                                          ? null
                                          : () =>
                                              unawaited(_deleteGroup(group)),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
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
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                error:
                    (error, _) => AppEmptyStateCard(
                      icon: Icons.error_outline_rounded,
                      title: '分组读取失败',
                      description: _messageOf(error),
                      actionLabel: '重试',
                      onAction:
                          () => ref.invalidate(privateBookSourceGroupsProvider),
                      compact: true,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('请填写分组名称');
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await ref.read(privateBookSourceServiceProvider).createGroup(name);
      _nameController.clear();
      _markChanged();
      _showMessage('分组已新增');
    } catch (error) {
      _showMessage(_messageOf(error));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _renameGroup(PrivateBookSourceGroup group) async {
    final controller = TextEditingController(text: group.displayName);
    final name = await showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 440,
      builder: (context) => _RenameGroupSurface(controller: controller),
    );
    controller.dispose();
    if (!mounted) {
      return;
    }
    if (name == null || name.isEmpty || name == group.displayName) {
      return;
    }
    try {
      final updated = await ref
          .read(privateBookSourceServiceProvider)
          .updateGroup(group.id, name);
      if (!mounted) {
        return;
      }
      ref.read(selectedPrivateBookSourceGroupProvider.notifier).state =
          updated.id;
      _markChanged();
      await ref
          .refresh(privateBookSourceGroupsProvider.future)
          .then<void>((_) {});
      if (!mounted) {
        return;
      }
      _showMessage('分组已重命名');
    } catch (error) {
      _showMessage(_messageOf(error));
    }
  }

  Future<void> _deleteGroup(PrivateBookSourceGroup group) async {
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 440,
      builder:
          (context) => _ConfirmActionSurface(
            icon: Icons.folder_delete_outlined,
            title: '删除分组',
            message: '确认删除“${group.displayName}”？分组内书源会移到未分组。',
            confirmLabel: '删除',
            destructive: true,
          ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(privateBookSourceServiceProvider).deleteGroup(group.id);
      if (ref.read(selectedPrivateBookSourceGroupProvider) == group.id) {
        ref.read(selectedPrivateBookSourceGroupProvider.notifier).state = null;
      }
      _markChanged();
      await ref
          .refresh(privateBookSourceGroupsProvider.future)
          .then<void>((_) {});
      _showMessage('分组已删除');
    } catch (error) {
      _showMessage(_messageOf(error));
    }
  }

  void _markChanged() {
    ref.invalidate(privateBookSourceGroupsProvider);
    ref.invalidate(privateBookSourcesProvider);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone:
          message.contains('失败') ? AppFeedbackTone.error : AppFeedbackTone.info,
      useHaptics: false,
    );
  }
}

enum _SourceTestMode {
  main('主链路', <String>['domain', 'search', 'info', 'toc', 'content']),
  discovery('发现', <String>['domain', 'discovery', 'info', 'toc', 'content']),
  custom('自定义', <String>['domain', 'search']);

  const _SourceTestMode(this.label, this.items);

  final String label;
  final List<String> items;
}

class _SourceTestConfig {
  const _SourceTestConfig({
    required this.keyword,
    required this.timeoutMs,
    required this.checkItems,
  });

  final String keyword;
  final int timeoutMs;
  final List<String> checkItems;
}

class _SourceTestConfigSheet extends StatefulWidget {
  const _SourceTestConfigSheet({required this.item});

  final PrivateBookSourceItem item;

  @override
  State<_SourceTestConfigSheet> createState() => _SourceTestConfigSheetState();
}

class _SourceTestConfigSheetState extends State<_SourceTestConfigSheet> {
  final TextEditingController _keywordController = TextEditingController();
  _SourceTestMode _mode = _SourceTestMode.main;
  int _timeoutMs = 30000;
  late Set<String> _checkItems = _SourceTestMode.main.items.toSet();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        bottomInset + metrics.sectionGap,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('检测书源', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              SegmentedButton<_SourceTestMode>(
                segments: const <ButtonSegment<_SourceTestMode>>[
                  ButtonSegment(
                    value: _SourceTestMode.main,
                    label: Text('主链路'),
                    icon: Icon(Icons.route_outlined),
                  ),
                  ButtonSegment(
                    value: _SourceTestMode.discovery,
                    label: Text('发现'),
                    icon: Icon(Icons.explore_outlined),
                  ),
                  ButtonSegment(
                    value: _SourceTestMode.custom,
                    label: Text('自定义'),
                    icon: Icon(Icons.tune_rounded),
                  ),
                ],
                selected: <_SourceTestMode>{_mode},
                onSelectionChanged: (values) {
                  final value = values.first;
                  setState(() {
                    _mode = value;
                    if (value != _SourceTestMode.custom) {
                      _checkItems = value.items.toSet();
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: '检测关键字',
                  hintText: '为空时使用书源内置关键字',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              AppDropdownField<int>(
                value: _timeoutMs,
                labelText: '超时',
                leadingIcon: const Icon(Icons.timer_outlined),
                options: const [
                  AppDropdownOption(value: 12000, label: '12 秒'),
                  AppDropdownOption(value: 30000, label: '30 秒'),
                  AppDropdownOption(value: 60000, label: '60 秒'),
                  AppDropdownOption(value: 90000, label: '90 秒'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    setState(() => _timeoutMs = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('检测过程', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final item in const <String>[
                    'domain',
                    'search',
                    'discovery',
                    'info',
                    'toc',
                    'content',
                  ])
                    FilterChip(
                      label: Text(_checkItemLabel(item)),
                      selected: _checkItems.contains(item),
                      onSelected:
                          _mode == _SourceTestMode.custom
                              ? (selected) {
                                setState(() {
                                  if (selected) {
                                    _checkItems.add(item);
                                  } else {
                                    _checkItems.remove(item);
                                  }
                                });
                              }
                              : null,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        _checkItems.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(
                              _SourceTestConfig(
                                keyword: _keywordController.text.trim(),
                                timeoutMs: _timeoutMs,
                                checkItems: _orderedCheckItems(_checkItems),
                              ),
                            ),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('开始检测'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceCheckReportSheet extends StatelessWidget {
  const _SourceCheckReportSheet({required this.report});

  final SourceCheckReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final summary = report.summary;
    final title = summary.valid ? '检测通过' : '检测失败';
    final summaryMessage = summary.message.trim();
    final showSummaryMessage =
        summaryMessage.isNotEmpty && summaryMessage != title;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        metrics.sectionGap,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  summary.valid
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color:
                      summary.valid ? colorScheme.primary : colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (summary.sourceName.isNotEmpty) summary.sourceName,
                if (summary.mode.isNotEmpty) summary.mode,
                if (summary.keyword.isNotEmpty) '关键字 ${summary.keyword}',
                if (summary.elapsedMs > 0) _formatDurationMs(summary.elapsedMs),
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (showSummaryMessage) ...<Widget>[
              const SizedBox(height: 10),
              Text(summaryMessage, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child:
                    report.logs.isEmpty
                        ? _SourceCheckEmptyLogSummary(
                          message:
                              summaryMessage.isNotEmpty
                                  ? summaryMessage
                                  : '检测报告日志为空，请复制原始结果继续定位。',
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: report.logs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return _SourceCheckLogRow(
                              entry: report.logs[index],
                            );
                          },
                        ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed:
                      report.copyText.trim().isEmpty
                          ? null
                          : () {
                            Clipboard.setData(
                              ClipboardData(text: report.copyText),
                            );
                            AppFeedback.showSnackBar(
                              context,
                              message: '检测日志已复制',
                              tone: AppFeedbackTone.success,
                              useHaptics: false,
                            );
                          },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('复制日志'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCheckLogRow extends StatelessWidget {
  const _SourceCheckLogRow({required this.entry});

  final SourceCheckLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = switch (entry.level) {
      'success' => colorScheme.primary,
      'error' => colorScheme.error,
      'muted' => colorScheme.onSurfaceVariant,
      _ => colorScheme.onSurface,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          entry.direction == 'in' ? '<-' : '->',
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry.details.isNotEmpty)
                _SourceCheckLogDetails(details: entry.details),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '[${_formatLogTime(entry.timeMs)}]',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SourceCheckEmptyLogSummary extends StatelessWidget {
  const _SourceCheckEmptyLogSummary({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = colorScheme.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, color: color, size: 34),
            const SizedBox(height: 10),
            Text(
              '检测报告日志为空',
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCheckLogDetails extends StatelessWidget {
  const _SourceCheckLogDetails({required this.details});

  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final pendingCompact = <_SourceCheckDetail>[];
    void flushCompact() {
      if (pendingCompact.isEmpty) {
        return;
      }
      children.add(_SourceCheckCompactDetails(items: List.of(pendingCompact)));
      pendingCompact.clear();
    }

    for (final raw in details) {
      final detail = _SourceCheckDetail.parse(raw);
      if (detail.isCompact) {
        pendingCompact.add(detail);
      } else {
        flushCompact();
        children.add(_SourceCheckLongDetail(detail: detail));
      }
    }
    flushCompact();

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .expand((child) => <Widget>[child, const SizedBox(height: 5)])
            .take(children.length * 2 - 1)
            .toList(growable: false),
      ),
    );
  }
}

class _SourceCheckCompactDetails extends StatelessWidget {
  const _SourceCheckCompactDetails({required this.items});

  final List<_SourceCheckDetail> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth >= 280 ? 14.0 : 8.0;
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 4,
          children: <Widget>[
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _SourceCheckInfoText(item: item, maxLines: 1),
              ),
          ],
        );
      },
    );
  }
}

class _SourceCheckLongDetail extends StatelessWidget {
  const _SourceCheckLongDetail({required this.detail});

  final _SourceCheckDetail detail;

  @override
  Widget build(BuildContext context) {
    return _SourceCheckInfoText(item: detail, maxLines: 4);
  }
}

class _SourceCheckInfoText extends StatelessWidget {
  const _SourceCheckInfoText({required this.item, required this.maxLines});

  final _SourceCheckDetail item;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    if (item.label.isEmpty) {
      return Text(
        item.value,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: labelStyle,
      );
    }
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: labelStyle,
        children: <InlineSpan>[
          TextSpan(text: '${item.label}：'),
          TextSpan(text: item.value, style: valueStyle),
        ],
      ),
    );
  }
}

class _SourceCheckDetail {
  const _SourceCheckDetail({
    required this.label,
    required this.value,
    required this.isCompact,
  });

  final String label;
  final String value;
  final bool isCompact;

  factory _SourceCheckDetail.parse(String raw) {
    final text = raw.trim();
    final separator = _firstDetailSeparator(text);
    if (separator <= 0) {
      return _SourceCheckDetail(
        label: '',
        value: text,
        isCompact: _isCompactDetail('', text),
      );
    }
    final label = text.substring(0, separator).trim();
    final value = text.substring(separator + 1).trim();
    return _SourceCheckDetail(
      label: label,
      value: value,
      isCompact: _isCompactDetail(label, value),
    );
  }
}

int _firstDetailSeparator(String value) {
  final chinese = value.indexOf('：');
  final ascii = value.indexOf(':');
  if (chinese < 0) {
    return ascii;
  }
  if (ascii < 0) {
    return chinese;
  }
  return chinese < ascii ? chinese : ascii;
}

bool _isCompactDetail(String label, String value) {
  final lowerValue = value.toLowerCase();
  final lowerLabel = label.toLowerCase();
  if (value.contains('\n') ||
      lowerValue.contains('http://') ||
      lowerValue.contains('https://') ||
      lowerValue.startsWith('{') ||
      lowerValue.startsWith('[') ||
      lowerLabel.contains('url') ||
      label.contains('地址') ||
      label.contains('请求体') ||
      lowerLabel == 'body') {
    return false;
  }
  return value.runes.length <= 18;
}

class _PrivateSourceForm extends ConsumerStatefulWidget {
  const _PrivateSourceForm({
    this.item,
    this.initialImportMethod = _BookSourceImportMethod.paste,
  });

  final PrivateBookSourceItem? item;
  final _BookSourceImportMethod initialImportMethod;

  @override
  ConsumerState<_PrivateSourceForm> createState() => _PrivateSourceFormState();
}

class _PrivateSourceFormState extends ConsumerState<_PrivateSourceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _groupController;
  late final TextEditingController _sourceController;
  late final TextEditingController _urlController;
  late final TextEditingController _previewController;
  late _BookSourceImportMethod _selectedImportMethod;
  String _type = 'novel';
  bool _saving = false;
  bool _loadingSource = false;
  bool _groupEdited = false;
  bool _previewExpanded = false;
  String? _loadedUrl;
  String? _sourceLabel;
  String? _loadError;
  int _sourceLineCount = 0;
  int _sourceSizeBytes = 0;

  bool get _isEditing => widget.item != null;
  bool get _hasLoadedSource => _sourceController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _groupController = TextEditingController(text: item?.groupName ?? '');
    _sourceController = TextEditingController(
      text:
          item?.sourceJson.isNotEmpty == true
              ? item!.sourceJson
              : item?.sourceCode ?? '',
    );
    _urlController = TextEditingController();
    _previewController = TextEditingController();
    _selectedImportMethod = widget.initialImportMethod;
    _type =
        item?.supportedTypes.isNotEmpty == true
            ? item!.supportedTypes.first
            : 'novel';
    _loadInitialPreview();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _groupController.dispose();
    _sourceController.dispose();
    _urlController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final groupsAsync = ref.watch(privateBookSourceGroupsProvider);
    final metrics = AppAdaptiveMetrics.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        bottomInset + metrics.sectionGap,
      ),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _isEditing ? '编辑书源' : '新增书源',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _saving ? '保存中' : '保存',
                      onPressed: (_saving || _loadingSource) ? null : _save,
                      color: colorScheme.primary,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                      ),
                      icon:
                          _saving
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _PrivateSourceSectionHeader(title: '基础信息'),
                const SizedBox(height: 12),
                _PrivateSourceField(
                  label: '名称',
                  child: TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: _privateSourceInputDecoration(
                      hintText: '请输入书源名称',
                    ),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? '请填写名称'
                                : null,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final typeField = _PrivateSourceField(
                      label: '类型',
                      child: AppDropdownField<String>(
                        value: _type,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        options: const [
                          AppDropdownOption(value: 'novel', label: '小说'),
                          AppDropdownOption(value: 'comic', label: '漫画'),
                          AppDropdownOption(value: 'audio', label: '音频'),
                          AppDropdownOption(value: 'video', label: '视频'),
                        ],
                        onSelected: (value) {
                          if (value != null) {
                            setState(() {
                              _type = value;
                            });
                          }
                        },
                      ),
                    );
                    final groupField = _PrivateSourceField(
                      label: '分组',
                      child: _PrivateGroupAutocompleteField(
                        controller: _groupController,
                        groupsAsync: groupsAsync,
                        decoration: _privateSourceInputDecoration(
                          hintText: '选择已有分组，或输入新分组名',
                        ),
                        onChanged: () {
                          _groupEdited = true;
                        },
                      ),
                    );
                    if (constraints.maxWidth >= 560) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: typeField),
                          const SizedBox(width: 12),
                          Expanded(child: groupField),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        typeField,
                        const SizedBox(height: 12),
                        groupField,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _PrivateSourceField(
                  label: '描述',
                  child: TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: _privateSourceInputDecoration(
                      hintText: '可填写用途、来源或备注',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildImportSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PrivateSourceSectionHeader(
          title: '书源 JSON',
          trailing: TextButton.icon(
            onPressed: _saving || _loadingSource ? null : _changeImportMethod,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text(_importMethodLabel(_selectedImportMethod)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildJsonMethodInput(context),
        if (_loadingSource) ...<Widget>[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            minHeight: 3,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
          Text(
            '正在读取书源 JSON',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_loadError != null) ...<Widget>[
          const SizedBox(height: 12),
          _ImportErrorBanner(message: _loadError!),
        ],
        if (_hasLoadedSource) ...<Widget>[
          const SizedBox(height: 12),
          _BookSourcePreviewCard(
            label: _sourceLabel ?? '已加载 JSON',
            previewController: _previewController,
            lineCount: _sourceLineCount,
            sizeBytes: _sourceSizeBytes,
            expanded: _previewExpanded,
            onToggleExpanded: () {
              setState(() {
                _previewExpanded = !_previewExpanded;
              });
            },
            onClear: _clearLoadedSource,
          ),
        ],
      ],
    );
  }

  Widget _buildJsonMethodInput(BuildContext context) {
    switch (_selectedImportMethod) {
      case _BookSourceImportMethod.url:
        return _UrlJsonSourceInput(
          controller: _urlController,
          enabled: !_saving && !_loadingSource,
          hasLoadedSource: _hasLoadedSource,
        );
      case _BookSourceImportMethod.file:
        return AppTaskActionCard(
          title: _hasLoadedSource ? '重新选择书源文件' : '添加书源文件',
          description: '支持选择 .json 或 .txt 文件。',
          icon: Icons.folder_open_rounded,
          dashedBorder: !_hasLoadedSource,
          onTap:
              _saving || _loadingSource
                  ? null
                  : () => unawaited(_loadFileSource()),
        );
      case _BookSourceImportMethod.paste:
        return AppTaskActionCard(
          title: _hasLoadedSource ? '重新读取剪贴板' : '粘贴 JSON',
          description: '从系统剪贴板读取书源 JSON 文本。',
          icon: Icons.copy_rounded,
          dashedBorder: !_hasLoadedSource,
          onTap:
              _saving || _loadingSource
                  ? null
                  : () => unawaited(_loadClipboardSource()),
        );
    }
  }

  Future<void> _changeImportMethod() async {
    final method = await PrivateBookSourcesPage._selectBookSourceImportMethod(
      context,
    );
    if (method == null || !mounted) {
      return;
    }
    setState(() {
      _selectedImportMethod = method;
      _loadedUrl = null;
      _clearLoadedSourceValues();
    });
  }

  Future<void> _loadFileSource() {
    final localFileImport =
        ref.read(appPlatformCapabilitiesProvider).localFileImport;
    if (!localFileImport.isSupported) {
      _setLoadError(localFileImport.reason ?? '当前平台暂不支持从本地文件选择器导入。');
      return Future<void>.value();
    }
    return _loadActionSource(
      method: _BookSourceImportMethod.file,
      loader: PrivateBookSourcesPage._loadRawImportFromFile,
    );
  }

  Future<void> _loadClipboardSource() {
    return _loadActionSource(
      method: _BookSourceImportMethod.paste,
      loader: PrivateBookSourcesPage._loadRawImportFromClipboard,
    );
  }

  Future<void> _loadActionSource({
    required _BookSourceImportMethod method,
    required Future<_RawBookSourceImport?> Function() loader,
  }) async {
    if (_loadingSource) {
      return;
    }
    setState(() {
      _loadingSource = true;
      _loadError = null;
    });
    try {
      final raw = await loader();
      if (raw == null) {
        return;
      }
      final imported = await PrivateBookSourcesPage._prepareLoadedImport(
        method: method,
        raw: raw,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyPreparedImport(imported);
      });
      PrivateBookSourcesPage._showImportSuccess(context, imported);
    } on FormatException catch (error) {
      _handleImportFailure(method, error.message);
    } catch (error) {
      _handleImportFailure(method, '书源 JSON 读取失败：${_messageOf(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _loadingSource = false;
        });
      }
    }
  }

  void _handleImportFailure(_BookSourceImportMethod method, String message) {
    setState(() {
      _loadError = message;
    });
    PrivateBookSourcesPage._showImportFailure(
      context,
      method: method,
      message: message,
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      final sourceReady = await _ensureSourceReadyForSave();
      if (!sourceReady) {
        return;
      }
      if (!_formKey.currentState!.validate()) {
        return;
      }
      final input = PrivateBookSourceInput(
        name: _nameController.text.trim(),
        supportedTypes: <String>[_type],
        sourceCode: _sourceController.text.trim(),
        description: _descriptionController.text.trim(),
        groupName: _groupController.text.trim(),
      );
      late final PrivateBookSourceItem saved;
      if (_isEditing) {
        saved = await ref
            .read(privateBookSourceServiceProvider)
            .update(widget.item!.id, input);
      } else {
        saved = await ref.read(privateBookSourceServiceProvider).create(input);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.showSnackBar(
        context,
        message: _messageOf(error),
        tone: AppFeedbackTone.error,
        useHaptics: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<bool> _ensureSourceReadyForSave() async {
    if (_selectedImportMethod == _BookSourceImportMethod.url) {
      return _loadUrlSourceForSave();
    }
    return _validateLoadedSource();
  }

  Future<bool> _loadUrlSourceForSave() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _setLoadError('请输入书源链接');
      return false;
    }
    if (_sourceController.text.trim().isNotEmpty && _loadedUrl == url) {
      return _validateLoadedSource();
    }
    setState(() {
      _loadingSource = true;
      _loadError = null;
    });
    try {
      final imported = await PrivateBookSourcesPage._prepareUrlImport(url);
      if (!mounted) {
        return false;
      }
      setState(() {
        _loadedUrl = url;
        _applyPreparedImport(imported);
      });
      PrivateBookSourcesPage._showImportSuccess(context, imported);
      return true;
    } on FormatException catch (error) {
      setState(() {
        _loadError = error.message;
      });
      PrivateBookSourcesPage._showImportFailure(
        context,
        method: _BookSourceImportMethod.url,
        message: error.message,
      );
      return false;
    } catch (error) {
      final message = '书源 JSON 读取失败：${_messageOf(error)}';
      setState(() {
        _loadError = message;
      });
      PrivateBookSourcesPage._showImportFailure(
        context,
        method: _BookSourceImportMethod.url,
        message: message,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _loadingSource = false;
        });
      }
    }
  }

  bool _validateLoadedSource() {
    final raw = _sourceController.text.trim();
    if (raw.isEmpty) {
      _setLoadError('请先导入书源 JSON');
      return false;
    }
    if (!PrivateBookSourceInput.isValidJson(raw)) {
      _setLoadError('JSON 格式不正确');
      return false;
    }
    return true;
  }

  void _loadInitialPreview() {
    final raw = _sourceController.text.trim();
    if (raw.isEmpty) {
      return;
    }
    try {
      final payload = BookSourceImportPayload.fromJsonText(raw);
      _applyLoadedPayload(payload, label: '已保存 JSON', fillMetadata: false);
    } catch (_) {
      _previewController.text = buildBookSourcePreview(raw);
      _sourceLabel = '已保存 JSON';
      _sourceLineCount = countBookSourceLines(raw);
      _sourceSizeBytes = bookSourceUtf8SizeOf(raw);
      _loadError = '已保存 JSON 格式异常，请重新导入';
    }
  }

  void _applyPreparedImport(_PreparedBookSourceImport imported) {
    _applyLoadedPayload(imported.payload, label: imported.label);
  }

  void _applyLoadedPayload(
    BookSourceImportPayload payload, {
    required String label,
    bool fillMetadata = true,
  }) {
    _sourceController.text = payload.sourceJson;
    _previewController.text = payload.previewText;
    _sourceLabel = label;
    _sourceLineCount = payload.lineCount;
    _sourceSizeBytes = payload.sizeBytes;
    _previewExpanded = false;
    _loadError = null;
    if (fillMetadata) {
      _fillMetadataFromPayload(payload);
    }
  }

  void _fillMetadataFromPayload(BookSourceImportPayload payload) {
    if (_nameController.text.trim().isEmpty &&
        payload.suggestedName.isNotEmpty) {
      _nameController.text = payload.suggestedName;
    }
    if (_descriptionController.text.trim().isEmpty &&
        payload.suggestedDescription.isNotEmpty) {
      _descriptionController.text = payload.suggestedDescription;
    }
    if (_isEditing || _groupEdited || _groupController.text.trim().isNotEmpty) {
      return;
    }
    if (payload.suggestedGroupName.isEmpty) {
      return;
    }
    _groupController.text = payload.suggestedGroupName;
  }

  void _clearLoadedSource() {
    setState(() {
      _clearLoadedSourceValues();
    });
  }

  void _clearLoadedSourceValues() {
    _sourceController.clear();
    _previewController.clear();
    _sourceLabel = null;
    _sourceLineCount = 0;
    _sourceSizeBytes = 0;
    _previewExpanded = false;
    _loadError = null;
  }

  void _setLoadError(String message) {
    setState(() {
      _loadError = message;
    });
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone: AppFeedbackTone.error,
      useHaptics: false,
    );
  }
}

class _PreparedBookSourceImport {
  const _PreparedBookSourceImport({required this.label, required this.payload});

  final String label;
  final BookSourceImportPayload payload;
}

class _RawBookSourceImport {
  const _RawBookSourceImport({required this.text, required this.label});

  final String text;
  final String label;
}

InputDecoration _privateSourceInputDecoration({
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? helperText,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    helperText: helperText,
    alignLabelWithHint: alignLabelWithHint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );
}

class _PrivateSourceSectionHeader extends StatelessWidget {
  const _PrivateSourceSectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PrivateSourceField extends StatelessWidget {
  const _PrivateSourceField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

String _importMethodLabel(_BookSourceImportMethod method) {
  return switch (method) {
    _BookSourceImportMethod.url => '链接',
    _BookSourceImportMethod.file => '文件',
    _BookSourceImportMethod.paste => '粘贴',
  };
}

class _UrlJsonSourceInput extends StatelessWidget {
  const _UrlJsonSourceInput({
    required this.controller,
    required this.enabled,
    required this.hasLoadedSource,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool hasLoadedSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PrivateSourceField(
          label: '链接',
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: _privateSourceInputDecoration(
              hintText: 'https://example.com/source.json',
              prefixIcon: const Icon(Icons.link_rounded),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasLoadedSource
              ? '当前链接已解析；修改链接后保存会重新解析。'
              : '填写链接后点击保存，系统会下载并解析 JSON。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ImportErrorBanner extends StatelessWidget {
  const _ImportErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.onErrorContainer,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookSourcePreviewCard extends StatelessWidget {
  const _BookSourcePreviewCard({
    required this.label,
    required this.previewController,
    required this.lineCount,
    required this.sizeBytes,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onClear,
  });

  final String label;
  final TextEditingController previewController;
  final int lineCount;
  final int sizeBytes;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.code_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$lineCount 行 · ${formatBookSourceSize(sizeBytes)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: expanded ? '收起预览' : '查看预览',
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.visibility_outlined,
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    tooltip: '清除',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            if (expanded) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                controller: previewController,
                readOnly: true,
                minLines: 6,
                maxLines: 12,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
                decoration: _privateSourceInputDecoration(
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrivateGroupAutocompleteField extends StatefulWidget {
  const _PrivateGroupAutocompleteField({
    required this.controller,
    required this.groupsAsync,
    required this.onChanged,
    this.decoration = const InputDecoration(),
  });

  final TextEditingController controller;
  final AsyncValue<List<PrivateBookSourceGroup>> groupsAsync;
  final VoidCallback onChanged;
  final InputDecoration decoration;

  @override
  State<_PrivateGroupAutocompleteField> createState() =>
      _PrivateGroupAutocompleteFieldState();
}

class _PrivateGroupAutocompleteFieldState
    extends State<_PrivateGroupAutocompleteField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups =
        widget.groupsAsync.valueOrNull ?? const <PrivateBookSourceGroup>[];
    final groupNames = _uniqueGroupNames(groups);
    final loading = widget.groupsAsync.isLoading && groups.isEmpty;
    final hasError = widget.groupsAsync.hasError && groups.isEmpty;
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final rawKeyword = value.text.trim();
        final keyword = rawKeyword.toLowerCase();
        if (keyword.isEmpty) {
          return groupNames.take(12);
        }
        final matches =
            groupNames
                .where((name) => name.toLowerCase().contains(keyword))
                .take(12)
                .toList();
        final exists = groupNames.any((name) => name.toLowerCase() == keyword);
        if (!exists) {
          matches.add(rawKeyword);
        }
        return matches;
      },
      onSelected: (_) => widget.onChanged(),
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: widget.decoration.copyWith(
            hintText: widget.decoration.hintText ?? '选择已有分组，或输入新分组名',
            helperText:
                widget.decoration.helperText ??
                (loading
                    ? '正在读取分组'
                    : hasError
                    ? '分组读取失败，可直接输入新分组名'
                    : null),
            suffixIcon:
                widget.decoration.suffixIcon ??
                IconButton(
                  tooltip: '查看已有分组',
                  onPressed:
                      groupNames.isEmpty
                          ? null
                          : () {
                            focusNode.requestFocus();
                            textController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: textController.text.length,
                            );
                          },
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                ),
          ),
          onChanged: (_) => widget.onChanged(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final items = options.toList(growable: false);
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final maxWidth = MediaQuery.sizeOf(context).width - 32;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            elevation: 2,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: maxWidth.clamp(260.0, 420.0),
              constraints: const BoxConstraints(maxHeight: 248),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder:
                    (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.28,
                        ),
                      ),
                    ),
                itemBuilder: (context, index) {
                  final name = items[index];
                  final exists = groupNames.any(
                    (groupName) =>
                        groupName.toLowerCase() == name.toLowerCase(),
                  );
                  return _PrivateGroupOptionRow(
                    name: name,
                    exists: exists,
                    onTap: () => onSelected(name),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrivateGroupOptionRow extends StatelessWidget {
  const _PrivateGroupOptionRow({
    required this.name,
    required this.exists,
    required this.onTap,
  });

  final String name;
  final bool exists;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color:
                    exists
                        ? colorScheme.primaryContainer.withValues(alpha: 0.48)
                        : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.82,
                        ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                exists
                    ? Icons.folder_outlined
                    : Icons.create_new_folder_outlined,
                size: 19,
                color:
                    exists ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exists ? '已有私人分组' : '保存时创建',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _uniqueGroupNames(List<PrivateBookSourceGroup> groups) {
  final seen = <String>{};
  final names = <String>[];
  for (final group in groups) {
    final name = group.displayName.trim();
    if (name.isEmpty || !seen.add(name)) {
      continue;
    }
    names.add(name);
  }
  names.sort();
  return names;
}

String _limitText(int value) => value < 0 ? '不限' : '$value';

bool _isDefaultGroup(PrivateBookSourceGroup group) {
  return group.displayName == '未分组';
}

String _testLabel(String value) {
  return PrivateBookSourcePresentation.testLabel(value);
}

String _checkItemLabel(String value) {
  return switch (value) {
    'domain' => '域名',
    'search' => '搜索',
    'discovery' => '发现',
    'info' => '详情',
    'toc' => '目录',
    'content' => '正文',
    _ => value,
  };
}

List<String> _orderedCheckItems(Set<String> values) {
  return const <String>[
    'domain',
    'search',
    'discovery',
    'info',
    'toc',
    'content',
  ].where(values.contains).toList(growable: false);
}

String _formatDurationMs(int value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)} 秒';
  }
  return '$value ms';
}

String _formatLogTime(int value) {
  final minutes = value ~/ 60000;
  final seconds = (value % 60000) ~/ 1000;
  final millis = value % 1000;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
}

String _messageOf(Object error) {
  if (error is ApiException) {
    return error.briefMessage;
  }
  return error.toString();
}
