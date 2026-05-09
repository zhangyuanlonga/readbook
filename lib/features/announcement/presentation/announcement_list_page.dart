import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_status_state_card.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/announcement.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../application/announcement_read_state_service.dart';
import '../application/announcement_service.dart';
import '../providers.dart';

class AnnouncementListPage extends ConsumerStatefulWidget {
  const AnnouncementListPage({super.key});

  @override
  ConsumerState<AnnouncementListPage> createState() =>
      _AnnouncementListPageState();
}

class _AnnouncementListPageState extends ConsumerState<AnnouncementListPage> {
  late final AnnouncementService _service;
  late final AnnouncementReadStateService _readStateService;
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _errorText;
  Announcement? _latest;
  List<Announcement> _items = const <Announcement>[];
  Set<String> _readIds = const <String>{};
  int _page = 1;
  int _pageSize = 20;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _service = ref.read(announcementServiceProvider);
    _readStateService = ref.read(announcementReadStateServiceProvider);
    _scrollController.addListener(_handleScroll);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      return;
    }
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadInitial({bool forceRefresh = false}) async {
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
      final pageFuture = _service.fetchAnnouncements(
        page: 1,
        pageSize: _pageSize,
        useCache: !forceRefresh,
      );
      final latestFuture = _service
          .fetchLatestAnnouncement(useCache: !forceRefresh)
          .catchError((error) {
            _showMessage(_resolveErrorText(error));
            return null;
          });
      final readIdsFuture = _readStateService.getReadIds();
      final results = await Future.wait<Object?>([
        pageFuture,
        latestFuture,
        readIdsFuture,
      ]);
      final page = results[0]! as AnnouncementPage;
      final latest = results[1] as Announcement?;
      final readIds = results[2]! as Set<String>;
      if (!mounted) {
        return;
      }
      setState(() {
        _latest = latest;
        _items = page.items;
        _readIds = readIds;
        _page = page.page;
        _pageSize = page.pageSize;
        _total = page.total;
        _hasMore = page.items.length < page.total;
      });
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

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final nextPage = _page + 1;
      final page = await _service.fetchAnnouncements(
        page: nextPage,
        pageSize: _pageSize,
        useCache: false,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = [..._items, ...page.items];
        _page = page.page;
        _total = page.total;
        _hasMore = _items.length < _total;
      });
    } catch (error) {
      _showMessage(_resolveErrorText(error));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
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
    final activeTheme = ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeTheme,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        title: const Text('公告'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => unawaited(_loadInitial()),
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: buildAdvancedThemeBackdropDecoration(backdrop),
        child: LayoutBuilder(
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
                  topInset: topInset,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required double horizontal,
    required double bottomSafe,
    required double topInset,
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
        topInset: topInset,
        title: '加载失败',
        message: errorText,
        actionLabel: '重试',
        onAction: () => unawaited(_loadInitial(forceRefresh: true)),
      );
    }

    final latest = _latest;
    final latestId = latest?.id;
    final listItems =
        latestId == null
            ? _items
            : _items.where((item) => item.id != latestId).toList();

    if (latest == null && listItems.isEmpty) {
      return _buildStatusBody(
        context,
        horizontal: horizontal,
        bottomSafe: bottomSafe,
        topInset: topInset,
        title: '暂无公告',
        message: '当前没有可用的公告内容。',
        actionLabel: '刷新',
        onAction: () => unawaited(_loadInitial(forceRefresh: true)),
      );
    }

    final children = <Widget>[];
    final metrics = AppAdaptiveMetrics.of(context);
    if (latest != null) {
      children.add(_buildLatestCard(context, latest));
      children.add(SizedBox(height: metrics.contentGap));
    }
    for (final item in listItems) {
      children.add(_buildAnnouncementCard(context, item));
      children.add(SizedBox(height: metrics.contentGap));
    }
    if (_isLoadingMore) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    } else if (!_hasMore && listItems.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '已加载全部公告',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return AppFadeSlideTransition(
      child: RefreshIndicator(
        onRefresh: () => _loadInitial(forceRefresh: true),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topInset + metrics.contentGap,
            horizontal,
            metrics.contentGap + bottomSafe,
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _buildStatusBody(
    BuildContext context, {
    required double horizontal,
    required double bottomSafe,
    required double topInset,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    return AppFadeSlideTransition(
      child: RefreshIndicator(
        onRefresh: () => _loadInitial(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topInset + metrics.sectionGap * 2,
            horizontal,
            metrics.sectionGap + bottomSafe,
          ),
          children: [
            AppStatusStateCard(
              icon: Icons.notifications_none,
              title: title,
              message: message,
              tone:
                  title == '加载失败'
                      ? AppStatusStateTone.error
                      : AppStatusStateTone.neutral,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestCard(BuildContext context, Announcement announcement) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isRead = _isRead(announcement);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAnnouncement(announcement),
        child: Padding(
          padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '最新公告',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLevelChip(context, announcement.level),
                  if (!isRead) ...[
                    const SizedBox(width: 6),
                    _buildUnreadDot(context),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                announcement.title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _summary(announcement.content),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(announcement.publishFrom),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(
    BuildContext context,
    Announcement announcement,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isRead = _isRead(announcement);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAnnouncement(announcement),
        child: Padding(
          padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      announcement.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLevelChip(context, announcement.level),
                  if (!isRead) ...[
                    const SizedBox(width: 6),
                    _buildUnreadDot(context),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _summary(announcement.content),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(announcement.publishFrom),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
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

  String _summary(String content) {
    final compact = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 140) {
      return compact;
    }
    return '${compact.substring(0, 140)}...';
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

  void _openAnnouncement(Announcement announcement) {
    context.push('/announcements/${announcement.id}').then((_) {
      if (!mounted) {
        return;
      }
      unawaited(_refreshReadState());
    });
  }

  Future<void> _refreshReadState() async {
    final readIds = await _readStateService.getReadIds();
    if (!mounted) {
      return;
    }
    setState(() {
      _readIds = readIds;
    });
  }

  bool _isRead(Announcement announcement) {
    return _readIds.contains(announcement.id);
  }

  Widget _buildUnreadDot(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        shape: BoxShape.circle,
      ),
    );
  }

  String _resolveErrorText(Object error) {
    if (error is AppException) {
      return error.briefMessage;
    }
    return '公告加载失败，请稍后重试。';
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
