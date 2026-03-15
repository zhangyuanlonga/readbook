import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/announcement.dart';
import '../application/announcement_service.dart';
import '../application/announcement_read_state_service.dart';

class AnnouncementDetailPage extends ConsumerStatefulWidget {
  const AnnouncementDetailPage({super.key, required this.announcementId});

  final String announcementId;

  @override
  ConsumerState<AnnouncementDetailPage> createState() =>
      _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState
    extends ConsumerState<AnnouncementDetailPage> {
  final AnnouncementService _service = AnnouncementService();
  final AnnouncementReadStateService _readStateService =
      AnnouncementReadStateService();

  bool _isLoading = true;
  String? _errorText;
  Announcement? _announcement;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDetail());
  }

  Future<void> _loadDetail({bool forceRefresh = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    if (forceRefresh) {
      _service.clearCache();
    }

    try {
      final detail = await _service.fetchAnnouncementDetail(
        widget.announcementId,
        useCache: !forceRefresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _announcement = detail;
      });
      unawaited(_readStateService.markRead(detail.id));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = _resolveErrorText(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('公告详情')),
      body: LayoutBuilder(
        builder: (context, _) {
          final maxWidth = AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.mineContentMaxWidth,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _buildBody(
                context,
                horizontal: horizontal,
                bottomSafe: bottomSafe,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required double horizontal,
    required double bottomSafe,
  }) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomSafe),
          child: const CircularProgressIndicator(),
        ),
      );
    }

    final errorText = _errorText;
    if (errorText != null && errorText.isNotEmpty) {
      return _buildStatusBody(
        context,
        horizontal: horizontal,
        bottomSafe: bottomSafe,
        title: '加载失败',
        message: errorText,
        actionLabel: '重试',
        onAction: () => unawaited(_loadDetail(forceRefresh: true)),
      );
    }

    final announcement = _announcement;
    if (announcement == null) {
      return _buildStatusBody(
        context,
        horizontal: horizontal,
        bottomSafe: bottomSafe,
        title: '暂无内容',
        message: '公告内容为空或已下线。',
        actionLabel: '刷新',
        onAction: () => unawaited(_loadDetail(forceRefresh: true)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadDetail(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          16,
          horizontal,
          20 + bottomSafe,
        ),
        children: [
          Text(
            announcement.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildLevelChip(context, announcement.level),
              const SizedBox(width: 8),
              Text(
                _formatTime(announcement.publishFrom),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (announcement.publishTo != null) ...[
            const SizedBox(height: 6),
            Text(
              '有效期至 ${_formatTime(announcement.publishTo!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            announcement.content.trim().isEmpty
                ? '暂无公告正文。'
                : announcement.content.trim(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBody(
    BuildContext context, {
    required double horizontal,
    required double bottomSafe,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => _loadDetail(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          48,
          horizontal,
          24 + bottomSafe,
        ),
        children: [
          Icon(Icons.notifications_none, size: 48, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChip(BuildContext context, AnnouncementLevel level) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (level) {
      AnnouncementLevel.urgent => ('紧急', colorScheme.error),
      AnnouncementLevel.important => ('重要', colorScheme.tertiary),
      AnnouncementLevel.info => ('通知', colorScheme.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  String _resolveErrorText(Object error) {
    if (error is AppException) {
      return error.briefMessage;
    }
    return '公告加载失败，请稍后重试。';
  }
}
