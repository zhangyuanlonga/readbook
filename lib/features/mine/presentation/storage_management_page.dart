import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../core/cache/app_cache_governance_service.dart';
import '../application/storage_management_service.dart';
import '../application/advanced_theme_provider.dart';
import 'widgets/mine_route_top_bar.dart';

class StorageManagementPage extends StatefulWidget {
  const StorageManagementPage({super.key});

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage> {
  final StorageManagementService _service = StorageManagementService();

  StorageManagementSnapshot? _snapshot;
  bool _isLoading = true;
  bool _isClearingCaches = false;
  bool _isCleaningOrphans = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
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
    setState(() {
      _isClearingCaches = true;
    });
    try {
      await _service.clearRebuildableCaches();
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缓存已清理。')));
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCaches = false;
        });
      }
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 ${report.totalDeleted} 条孤立/过期数据。')),
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
                      if (_errorText case final message?)
                        _buildErrorCard(context, message),
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_snapshot case final snapshot?) ...[
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
            Row(
              children: [
                Expanded(child: Text(entry.label)),
                Text(
                  '${_formatBytes(entry.currentBytes)} · ${entry.currentEntries} 项',
                ),
              ],
            ),
            if (entry != snapshot.entries.last) const SizedBox(height: 8),
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
          OutlinedButton.icon(
            onPressed: _isClearingCaches ? null : _clearCaches,
            icon:
                _isClearingCaches
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.cleaning_services_outlined),
            label: const Text('清理所有缓存'),
          ),
          OutlinedButton.icon(
            onPressed: _isCleaningOrphans ? null : _cleanOrphans,
            icon:
                _isCleaningOrphans
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.auto_fix_high_outlined),
            label: const Text('清理孤立数据'),
          ),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('刷新统计'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: metrics.sectionGap),
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(metrics.cardRadius),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
      ),
    );
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
