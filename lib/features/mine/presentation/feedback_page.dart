import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/feedback/feedback_models.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/network/api_client.dart';
import '../application/advanced_theme_provider.dart';

enum _FeedbackStatusFilter { all, pending, resolved, rejected }

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage>
    with SingleTickerProviderStateMixin {
  final FeedbackService _feedbackService = FeedbackService();
  final TextEditingController _keywordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final TabController _tabController;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorText;
  List<FeedbackListItem> _entries = const <FeedbackListItem>[];
  FeedbackType _selectedType = FeedbackType.issue;
  _FeedbackStatusFilter _statusFilter = _FeedbackStatusFilter.all;
  int _page = 1;
  int _pageSize = 20;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_handleScroll);
    _loadEntries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keywordController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_isLoadingMore || !_hasMore || !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadEntries(loadMore: true);
    }
  }

  Future<void> _loadEntries({bool loadMore = false}) async {
    if (!mounted) {
      return;
    }

    if (loadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    final nextPage = loadMore ? _page + 1 : 1;

    try {
      final result = await _feedbackService.fetchFeedbackList(
        keyword: _keywordController.text,
        type: _selectedType.apiValue,
        status: _mapStatusFilter(_statusFilter),
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = loadMore ? [..._entries, ...result.items] : result.items;
        _page = result.page;
        _pageSize = result.pageSize;
        _hasMore = _entries.length < result.total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorText =
            error is AppException ? error.briefMessage : '反馈列表加载失败，请稍后重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        title: const Text('问题反馈'),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () async {
              final changed = await context.push<bool>('/feedback/compose');
              if (changed == true) {
                await _loadEntries();
              }
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('提交'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final activeTheme =
              ref.watch(activeAdvancedThemeProvider).valueOrNull;
          final backdrop = resolveAdvancedThemeBackdrop(
            Theme.of(context).colorScheme,
            activeTheme,
          );
          return DecoratedBox(
            decoration: buildAdvancedThemeBackdropDecoration(backdrop),
            child: LayoutBuilder(
              builder: (context, _) {
                final maxWidth = AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: AppLayout.systemSettingsContentMaxWidth,
                );

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: RefreshIndicator(
                      onRefresh: () => _loadEntries(),
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          topInset + 12,
                          horizontal,
                          20 + bottomSafe,
                        ),
                        children: [
                          _buildTypeTabs(context),
                          const SizedBox(height: 14),
                          _buildSearchAndFilterRow(context),
                          const SizedBox(height: 14),
                          Container(
                            height: 1,
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          if (_isLoading) _buildLoadingState(context),
                          if (!_isLoading && _errorText != null)
                            _buildErrorState(context, _errorText!),
                          if (!_isLoading &&
                              _errorText == null &&
                              _entries.isEmpty)
                            _buildEmptyState(context),
                          if (!_isLoading &&
                              _errorText == null &&
                              _entries.isNotEmpty)
                            ..._entries.map(
                              (entry) => _buildEntryTile(context, entry),
                            ),
                          if (_isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
          );
        },
      ),
    );
  }

  Widget _buildTypeTabs(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        onTap: (index) {
          final nextType = FeedbackType.values[index];
          if (nextType == _selectedType) {
            return;
          }
          setState(() {
            _selectedType = nextType;
          });
          _loadEntries();
        },
        tabs: FeedbackType.values
            .map((type) => Tab(text: type.label))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildSearchAndFilterRow(BuildContext context) {
    final searchField = TextField(
      controller: _keywordController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '搜索标题或内容',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: '搜索',
          onPressed: () => _loadEntries(),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
      onSubmitted: (_) => _loadEntries(),
    );
    final statusDropdown = DropdownButtonFormField<_FeedbackStatusFilter>(
      initialValue: _statusFilter,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(value: _FeedbackStatusFilter.all, child: Text('全部')),
        DropdownMenuItem(
          value: _FeedbackStatusFilter.pending,
          child: Text('未处理'),
        ),
        DropdownMenuItem(
          value: _FeedbackStatusFilter.resolved,
          child: Text('已解决'),
        ),
        DropdownMenuItem(
          value: _FeedbackStatusFilter.rejected,
          child: Text('不予处理'),
        ),
      ],
      onChanged: (value) {
        if (value == null || value == _statusFilter) {
          return;
        }
        setState(() {
          _statusFilter = value;
        });
        _loadEntries();
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = AppLayout.isPhoneSmallWidthFor(width);
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [searchField, const SizedBox(height: 8), statusDropdown],
          );
        }

        final filterWidth = (width * 0.32).clamp(108.0, 144.0).toDouble();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            SizedBox(width: filterWidth, child: statusDropdown),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('正在加载反馈列表...')),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String errorText) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: () => _loadEntries(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 34,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            '暂无匹配反馈',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '可以换个关键词试试，或点击右上角“提交”发起新的反馈。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(BuildContext context, FeedbackListItem entry) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => context.push('/feedback/${entry.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPill(
              context,
              label: entry.typeLabel,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 10),
            Text(
              entry.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              entry.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildPill(
                  context,
                  label: entry.statusLabel,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                if (entry.labels.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.labels.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(width: 8),
                Text(
                  _formatTime(entry.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(
    BuildContext context, {
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
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
}

class FeedbackComposePage extends StatefulWidget {
  const FeedbackComposePage({super.key});

  @override
  State<FeedbackComposePage> createState() => _FeedbackComposePageState();
}

class FeedbackDetailPage extends StatefulWidget {
  const FeedbackDetailPage({super.key, required this.feedbackId});

  final String feedbackId;

  @override
  State<FeedbackDetailPage> createState() => _FeedbackDetailPageState();
}

class _FeedbackDetailPageState extends State<FeedbackDetailPage> {
  final FeedbackService _feedbackService = FeedbackService();

  bool _isLoading = true;
  String? _errorText;
  FeedbackListItem? _entry;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final entry = await _feedbackService.fetchFeedbackDetail(
        widget.feedbackId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entry = entry;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorText =
            error is AppException ? error.briefMessage : '反馈详情加载失败，请稍后重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('反馈详情'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final activeTheme =
              ref.watch(activeAdvancedThemeProvider).valueOrNull;
          final backdrop = resolveAdvancedThemeBackdrop(
            Theme.of(context).colorScheme,
            activeTheme,
          );
          return DecoratedBox(
            decoration: buildAdvancedThemeBackdropDecoration(backdrop),
            child: LayoutBuilder(
              builder: (context, _) {
                final maxWidth = AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: AppLayout.systemSettingsContentMaxWidth,
                );

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: RefreshIndicator(
                      onRefresh: _loadDetail,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          topInset + 12,
                          horizontal,
                          20 + bottomSafe,
                        ),
                        children: [
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          if (!_isLoading && _errorText != null)
                            _FeedbackStateCard(
                              title: '加载失败',
                              message: _errorText!,
                              isError: true,
                              actionLabel: '重试',
                              onAction: _loadDetail,
                            ),
                          if (!_isLoading &&
                              _errorText == null &&
                              _entry != null)
                            _FeedbackDetailCard(entry: _entry!),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FeedbackDetailCard extends StatelessWidget {
  const _FeedbackDetailCard({required this.entry});

  final FeedbackListItem entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _feedbackPill(
                context,
                label: entry.typeLabel,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              _feedbackPill(
                context,
                label: entry.statusLabel,
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            entry.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _FeedbackDetailRow(
            label: '提交时间',
            value: _formatFeedbackTime(entry.createdAt),
          ),
          _FeedbackDetailRow(
            label: '更新时间',
            value: _formatFeedbackTime(entry.updatedAt),
          ),
          if (entry.labels.isNotEmpty)
            _FeedbackDetailRow(label: '标签', value: entry.labels.join('、')),
          const SizedBox(height: 14),
          Text(
            '反馈内容',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            entry.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackDetailRow extends StatelessWidget {
  const _FeedbackDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackStateCard extends StatelessWidget {
  const _FeedbackStateCard({
    required this.title,
    required this.message,
    required this.isError,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background =
        isError
            ? colorScheme.errorContainer.withValues(alpha: 0.7)
            : colorScheme.surfaceContainerLow;
    final foreground =
        isError ? colorScheme.onErrorContainer : colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: foreground),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

Widget _feedbackPill(
  BuildContext context, {
  required String label,
  required Color backgroundColor,
  required Color foregroundColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: foregroundColor,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

String _formatFeedbackTime(DateTime time) {
  final local = time.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

class _FeedbackComposePageState extends State<FeedbackComposePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FeedbackService _feedbackService = FeedbackService();

  FeedbackType _type = FeedbackType.issue;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('提交反馈'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final activeTheme =
              ref.watch(activeAdvancedThemeProvider).valueOrNull;
          final backdrop = resolveAdvancedThemeBackdrop(
            Theme.of(context).colorScheme,
            activeTheme,
          );
          return DecoratedBox(
            decoration: buildAdvancedThemeBackdropDecoration(backdrop),
            child: LayoutBuilder(
              builder: (context, _) {
                final maxWidth = AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: AppLayout.systemSettingsContentMaxWidth,
                );

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        topInset + 12,
                        horizontal,
                        20 + bottomSafe,
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '轻量提交',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '当前只支持问题和建议两类。提交前会自动查重，帮助你避免重复反馈。',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '反馈类型',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<FeedbackType>(
                          segments: [
                            ButtonSegment(
                              value: FeedbackType.issue,
                              label: Text(FeedbackType.issue.label),
                              icon: const Icon(Icons.bug_report_outlined),
                            ),
                            ButtonSegment(
                              value: FeedbackType.suggestion,
                              label: Text(FeedbackType.suggestion.label),
                              icon: const Icon(Icons.lightbulb_outline),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged:
                              _isSubmitting
                                  ? null
                                  : (value) {
                                    setState(() {
                                      _type = value.first;
                                    });
                                  },
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '标题',
                            hintText: '用一句话描述问题或建议',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contentController,
                          minLines: 6,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: '详细描述',
                            hintText: '请尽量写清楚场景、现象和复现步骤',
                            alignLabelWithHint: true,
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _submit,
                          icon:
                              _isSubmitting
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.send_rounded),
                          label: Text(_isSubmitting ? '提交中...' : '提交反馈'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      _showMessage('请先填写标题和详细描述。');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final shouldContinue = await _confirmDuplicateCheck(
        title: title,
        content: content,
      );
      if (!shouldContinue) {
        return;
      }

      await _feedbackService.submitFeedback(
        type: _type.apiValue,
        title: title,
        content: content,
      );
      if (!mounted) {
        return;
      }
      _showMessage('反馈已提交，感谢你的帮助。');
      context.pop(true);
    } on ApiException catch (error) {
      _showMessage(error.briefMessage);
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('提交失败，请稍后再试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool> _confirmDuplicateCheck({
    required String title,
    required String content,
  }) async {
    final keyword = title.isNotEmpty ? title : content;
    final result = await _feedbackService.fetchFeedbackList(
      keyword: keyword,
      type: _type.apiValue,
      page: 1,
      pageSize: 5,
    );
    if (!mounted || result.items.isEmpty) {
      return true;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          title: const Text('发现相似反馈'),
          content: SizedBox(
            width: AppLayout.dialogMaxWidth(context, maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '建议先看看是否已有相同问题，避免重复提交。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                ...result.items
                    .take(3)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              entry.statusLabel,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('仍然提交'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String? _mapStatusFilter(_FeedbackStatusFilter filter) {
  return switch (filter) {
    _FeedbackStatusFilter.all => null,
    _FeedbackStatusFilter.pending => FeedbackStatus.pending.apiValue,
    _FeedbackStatusFilter.resolved => FeedbackStatus.resolved.apiValue,
    _FeedbackStatusFilter.rejected => FeedbackStatus.rejected.apiValue,
  };
}
