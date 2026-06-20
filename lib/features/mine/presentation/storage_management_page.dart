// UI-GOV-EXEMPT-FILE: scaffold list-children
// reason: Phase 10 reviewed this settings page shell; the short static list is intentional.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../../../core/cache/app_cache_governance_service.dart';
import '../../../core/cache/cache_result.dart';
import '../../../core/cache/cache_scope.dart';
import '../application/storage_management_service.dart';
import '../application/advanced_theme_provider.dart';
import 'widgets/mine_route_top_bar.dart';

class StorageManagementPage extends StatefulWidget {
  const StorageManagementPage({super.key, this.service});

  final StorageManagementGateway? service;

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage> {
  late final StorageManagementGateway _service;

  StorageManagementSnapshot? _snapshot;
  bool _isLoading = true;
  bool _isClearingCaches = false;
  bool _isCleaningOrphans = false;
  final Set<AppCacheScope> _clearingScopes = <AppCacheScope>{};
  final Map<AppCacheScope, String> _cacheClearErrors =
      <AppCacheScope, String>{};
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StorageManagementService();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final snapshot = await _service.loadSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '读取存储占用失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearCaches() async {
    if (_isClearingCaches) {
      return;
    }
    final confirmed = await _confirmCacheClear(
      title: '清理所有可重建缓存',
      message: '会清理章节、分页、图片、API、搜索命中和书源健康等可重新生成的缓存，不会删除本地图书和高级主题资源。',
    );
    if (!confirmed) {
      return;
    }
    setState(() {
      _isClearingCaches = true;
      _cacheClearErrors.clear();
    });
    try {
      await _service.clearRebuildableCaches();
      await _load();
      if (!mounted) {
        return;
      }
      AppFeedback.showSnackBar(
        context,
        message: '缓存已清理。',
        tone: AppFeedbackTone.success,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCaches = false;
        });
      }
    }
  }

  Future<void> _clearCacheScope(AppCacheGovernanceEntry entry) async {
    if (_clearingScopes.contains(entry.scope) || !entry.deletable) {
      return;
    }
    final confirmed = await _confirmCacheClear(
      title: '清理${entry.label}',
      message: '该缓存会在后续使用时重新生成，清理不会删除本地图书、高级主题资源或账号数据。',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _clearingScopes.add(entry.scope);
      _cacheClearErrors.remove(entry.scope);
    });
    try {
      final result = await _service.clearCacheScope(entry.scope);
      if (!mounted) {
        return;
      }
      if (result.status == AppCacheDeleteStatus.backendError) {
        setState(() {
          _cacheClearErrors[entry.scope] = '清理失败，请稍后重试。';
        });
        AppFeedback.showSnackBar(
          context,
          message: '${entry.label}清理失败，请稍后重试。',
          tone: AppFeedbackTone.error,
        );
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      AppFeedback.showSnackBar(
        context,
        message: '${entry.label}已清理。',
        tone: AppFeedbackTone.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cacheClearErrors[entry.scope] = '清理失败，请稍后重试。';
      });
      AppFeedback.showSnackBar(
        context,
        message: '${entry.label}清理失败，请稍后重试。',
        tone: AppFeedbackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _clearingScopes.remove(entry.scope);
        });
      }
    }
  }

  Future<bool> _confirmCacheClear({
    required String title,
    required String message,
  }) async {
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 420,
      builder:
          (context) => _CacheClearConfirmationSurface(
            title: Text(title),
            message: Text(message),
          ),
    );
    return confirmed ?? false;
  }

  Future<void> _cleanOrphans() async {
    if (_isCleaningOrphans) {
      return;
    }
    setState(() {
      _isCleaningOrphans = true;
    });
    try {
      final report = await _service.clearOrphanedDatabaseData();
      await _load();
      if (!mounted) {
        return;
      }
      AppFeedback.showSnackBar(
        context,
        message: '已清理 ${report.totalDeleted} 条孤立/过期数据。',
        tone: AppFeedbackTone.success,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCleaningOrphans = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final routeTopBar = buildMineRouteTopBar(
      context: context,
      title: '存储管理',
      subtitle: '缓存、数据库与本地资源占用',
    );
    final topInset =
        MediaQuery.paddingOf(context).top + routeTopBar.preferredSize.height;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/system-settings');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: routeTopBar,
        body: Consumer(
          builder: (context, ref, _) {
            final activeAdvancedTheme =
                ref.watch(activeAdvancedThemeProvider).valueOrNull;
            final backdrop = resolveAdvancedThemeBackdrop(
              Theme.of(context).colorScheme,
              activeAdvancedTheme,
            );
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
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      topInset + metrics.sectionGap,
                      horizontal,
                      metrics.sectionGap + bottomSafe,
                    ),
                    children: [
                      _buildSummaryCard(context),
                      SizedBox(height: metrics.sectionGap),
                      _buildStateContent(context),
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

  Widget _buildStateContent(BuildContext context) {
    return AppAnimatedSwitcher(
      child: KeyedSubtree(
        key: ValueKey<String>(_storageStateKey),
        child: _buildStateContentBody(context),
      ),
    );
  }

  String get _storageStateKey {
    if (_isLoading) {
      return 'loading';
    }
    if (_errorText != null) {
      return 'error';
    }
    return _snapshot == null ? 'empty' : 'content';
  }

  Widget _buildStateContentBody(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final message = _errorText;
    if (message != null) {
      return _buildErrorCard(context, message);
    }
    if (_isLoading) {
      return _buildLoadingSkeleton(context);
    }
    final snapshot = _snapshot;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        _buildFootprintCard(
          context,
          title: snapshot.database.label,
          icon: Icons.storage_rounded,
          bytes: snapshot.database.bytes,
          fileCount: snapshot.database.fileCount,
        ),
        SizedBox(height: metrics.sectionGap),
        _buildFootprintCard(
          context,
          title: snapshot.localBooks.label,
          icon: Icons.library_books_rounded,
          bytes: snapshot.localBooks.bytes,
          fileCount: snapshot.localBooks.fileCount,
        ),
        SizedBox(height: metrics.sectionGap),
        _buildFootprintCard(
          context,
          title: snapshot.userAssets.label,
          icon: Icons.photo_library_rounded,
          bytes: snapshot.userAssets.bytes,
          fileCount: snapshot.userAssets.fileCount,
        ),
        SizedBox(height: metrics.sectionGap),
        _buildCacheCard(context, snapshot.cacheSnapshot),
        SizedBox(height: metrics.sectionGap),
        _buildActionsCard(context),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final snapshot = _snapshot;
    final cacheBytes = snapshot?.cacheSnapshot.totalBytes ?? 0;
    final cacheEntries = snapshot?.cacheSnapshot.totalEntries ?? 0;
    final managedBytes = snapshot?.totalManagedAssetBytes ?? 0;
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前占用概览',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            '可重建缓存 ${_formatBytes(cacheBytes)} / $cacheEntries 项，用户资产 ${_formatBytes(managedBytes)}。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildFootprintCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int bytes,
    required int fileCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatBytes(bytes)} · $fileCount 个文件',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheCard(
    BuildContext context,
    AppCacheGovernanceSnapshot snapshot,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '缓存占用',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final entry in snapshot.entries) ...[
            _buildCacheEntryTile(context, entry),
            if (entry != snapshot.entries.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildCacheEntryTile(
    BuildContext context,
    AppCacheGovernanceEntry entry,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isClearing = _clearingScopes.contains(entry.scope);
    final errorText = _cacheClearErrors[entry.scope];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              entry.overBudget
                  ? colorScheme.error.withValues(alpha: 0.38)
                  : colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForCacheScope(entry.scope), color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatBytes(entry.currentBytes)} · ${entry.currentEntries} 项${_budgetText(entry)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: isClearing ? '清理中' : '清理',
                variant: AppButtonVariant.text,
                size: AppButtonSize.compact,
                onPressed:
                    entry.deletable && !isClearing
                        ? () => _clearCacheScope(entry)
                        : null,
                icon: const Icon(Icons.delete_sweep_outlined),
                isLoading: isClearing,
              ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            AppInlineFeedback(
              message: errorText,
              tone: AppFeedbackTone.error,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          AppButton(
            label: _isClearingCaches ? '清理中' : '清理所有缓存',
            variant: AppButtonVariant.secondary,
            onPressed: _isClearingCaches ? null : _clearCaches,
            icon: const Icon(Icons.cleaning_services_outlined),
            isLoading: _isClearingCaches,
          ),
          AppButton(
            label: _isCleaningOrphans ? '清理中' : '清理孤立数据',
            variant: AppButtonVariant.secondary,
            onPressed: _isCleaningOrphans ? null : _cleanOrphans,
            icon: const Icon(Icons.auto_fix_high_outlined),
            isLoading: _isCleaningOrphans,
          ),
          AppButton(
            label: '刷新统计',
            variant: AppButtonVariant.secondary,
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: metrics.sectionGap),
      child: AppInlineFeedback(
        title: '读取失败',
        message: message,
        tone: AppFeedbackTone.error,
        action: AppButton(
          variant: AppButtonVariant.text,
          size: AppButtonSize.compact,
          onPressed: _isLoading ? null : _load,
          label: '重试',
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return AppSkeletonList(
      itemCount: 3,
      itemHeight: 74,
      spacing: metrics.sectionGap,
      showTrailing: true,
    );
  }

  IconData _iconForCacheScope(AppCacheScope scope) {
    return switch (scope) {
      AppCacheScope.chapterContent => Icons.menu_book_rounded,
      AppCacheScope.paginationLayout => Icons.view_carousel_rounded,
      AppCacheScope.coverImage => Icons.image_rounded,
      AppCacheScope.readerImage => Icons.photo_size_select_actual_rounded,
      AppCacheScope.apiResponse => Icons.cloud_queue_rounded,
      AppCacheScope.searchHit => Icons.manage_search_rounded,
      AppCacheScope.sourceHealth => Icons.health_and_safety_rounded,
      AppCacheScope.themePreview => Icons.palette_rounded,
      AppCacheScope.localBookIndex => Icons.library_books_rounded,
      AppCacheScope.readerPreference => Icons.tune_rounded,
    };
  }

  String _budgetText(AppCacheGovernanceEntry entry) {
    final parts = <String>[];
    final maxBytes = entry.maxBytes;
    final maxEntries = entry.maxEntries;
    if (maxBytes != null) {
      parts.add('预算 ${_formatBytes(maxBytes)}');
    }
    if (maxEntries != null) {
      parts.add('上限 $maxEntries 项');
    }
    if (parts.isEmpty) {
      return '';
    }
    return ' · ${parts.join(' / ')}';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    final fractionDigits = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
  }
}

class _CacheClearConfirmationSurface extends StatelessWidget {
  const _CacheClearConfirmationSurface({
    required this.title,
    required this.message,
  });

  final Widget title;
  final Widget message;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle.merge(
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          child: title,
        ),
        SizedBox(height: metrics.contentGap),
        DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyMedium,
          child: message,
        ),
        SizedBox(height: metrics.sectionGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: '取消',
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: '确认清理',
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
  }
}
