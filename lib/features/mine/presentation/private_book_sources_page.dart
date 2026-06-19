import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/composition/app_providers.dart' as app_providers;
import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers.dart' as auth_providers;
import '../application/advanced_theme_provider.dart';
import '../application/private_book_source_provider.dart';
import '../application/private_book_source_service.dart';
import 'private_book_source_filter_presenter.dart';
import 'private_book_source_presentation.dart';
import 'widgets/mine_route_top_bar.dart';
import 'widgets/private_book_source_action_surfaces.dart';
import 'widgets/private_book_source_detail_sheet.dart';
import 'widgets/private_book_source_form.dart';
import 'widgets/private_book_source_group_manager_sheet.dart';
import 'widgets/private_book_source_test_sheet.dart';
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
            data: (quota) => PrivateBookSourceQuotaCard(quota: quota),
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
                      key: ValueKey<String>('private_book_source_${item.id}'),
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
                onRefresh: () async {
                  ref.read(privateBookSourceActionControllerProvider).refresh();
                },
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
      builder: (context) => const PrivateBookSourceGroupManagerSheet(),
    );
    if (!context.mounted) {
      return;
    }
    if (changed == true) {
      ref.read(privateBookSourceActionControllerProvider).refresh();
    }
  }

  static Future<void> _openCreateForm(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final method = await showAdaptiveActionSurface<BookSourceImportMethod>(
      context: context,
      maxWidth: 460,
      padding: EdgeInsets.zero,
      builder: (context) => const BookSourceImportMethodSheet(),
    );
    if (method == null || !context.mounted) {
      return;
    }
    await _openForm(context, ref, initialImportMethod: method);
  }

  static Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    PrivateBookSourceItem? item,
    BookSourceImportMethod initialImportMethod = BookSourceImportMethod.paste,
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
          (context) => PrivateBookSourceForm(
            item: formItem,
            initialImportMethod: initialImportMethod,
          ),
    );
    if (saved != null) {
      ref.read(_privateBookSourceSearchKeywordProvider.notifier).state = '';
      ref.read(selectedPrivateBookSourceGroupProvider.notifier).state = null;
      ref.read(privateBookSourceActionControllerProvider).refresh();
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
          .read(privateBookSourceActionControllerProvider)
          .loadDetailForEdit(item);
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
          (context) => ConfirmActionSurface(
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
      () => ref.read(privateBookSourceActionControllerProvider).delete(item),
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
          (context) => SubmitSourceReviewSurface(controller: noteController),
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
      () => ref
          .read(privateBookSourceActionControllerProvider)
          .submit(item, note),
      '已提交共享审核',
    );
  }

  static Future<void> _testSource(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final config = await showAdaptiveActionSurface<PrivateBookSourceTestConfig>(
      context: context,
      maxWidth: 560,
      maxHeightFactor: 0.7,
      padding: EdgeInsets.zero,
      builder: (context) => PrivateBookSourceTestConfigSheet(item: item),
    );
    if (config == null || !context.mounted) {
      return;
    }
    try {
      final result = await ref
          .read(privateBookSourceActionControllerProvider)
          .test(
            item,
            keyword: config.keyword,
            timeoutMs: config.timeoutMs,
            checkItems: config.checkItems,
          );
      if (!context.mounted) {
        return;
      }
      final report = result.report;
      if (report != null) {
        await showAdaptiveActionSurface<void>(
          context: context,
          maxWidth: 680,
          maxHeightFactor: 0.7,
          padding: EdgeInsets.zero,
          builder:
              (context) => PrivateBookSourceCheckReportSheet(report: report),
        );
        return;
      }
      AppFeedback.showSnackBar(
        context,
        message:
            '书源检测已记录：${PrivateBookSourcePresentation.testLabel(result.item.lastTestStatus)}',
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

String _messageOf(Object error) {
  if (error is ApiException) {
    return error.briefMessage;
  }
  return error.toString();
}
