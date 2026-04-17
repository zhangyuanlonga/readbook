import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/mobile_bottom_navigation_inset.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/local_book_repository_impl.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reading_record.dart';
import '../application/bookshelf_service.dart';
import '../application/bookshelf_system_settings_service.dart';
import '../application/local_book_import_service.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../reader/application/reader_entry_route_resolver.dart';
import '../../reader/application/local/local_book_index_service.dart';
import '../../book/application/book_detail_service.dart';
import '../../book/presentation/book_detail_route.dart';
import '../../announcement/application/announcement_service.dart';
import '../../announcement/application/announcement_read_state_service.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../../source/application/external_source_import_bridge.dart';
import '../../source/application/source_runtime_facade.dart';
import '../../source/application/source_runtime_task_conflict_service.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/session/source_session.dart';
import 'widgets/bookshelf_grid_sliver.dart';
import 'widgets/bookshelf_page_sections.dart';

enum _BookshelfSheetAction {
  read,
  detail,
  repairLocal,
  select,
  category,
  tag,
  customCover,
  delete,
}

enum _BookshelfFilter { all, local, novel, manga, custom }

enum _BookshelfMoreAction { selectBooks, sortBooks, settings, importLocal }

enum _BookshelfSortMode {
  defaultOrder,
  recentRead,
  readingProgress,
  createdAt,
  author,
  title,
}

enum _BookshelfViewKind { base, tag, category }

enum _BookshelfCategorySheetAction { rename, delete }

enum _BookshelfSearchQuickFilterContent { none, tags, categories }

List<String> mergeBookshelfTaxonomyNames({
  required Map<String, int> counts,
  required List<String> order,
}) {
  final names = <String>[];
  for (final item in order) {
    final normalized = item.trim();
    if (normalized.isEmpty || names.contains(normalized)) {
      continue;
    }
    names.add(normalized);
  }

  final remaining = counts.keys
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && !names.contains(item))
      .toList(growable: false);
  remaining.sort((a, b) {
    final countCompare = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
    if (countCompare != 0) {
      return countCompare;
    }
    return a.compareTo(b);
  });

  return <String>[...names, ...remaining];
}

class _BookshelfViewSelection {
  const _BookshelfViewSelection.base(this.filter)
    : kind = _BookshelfViewKind.base,
      tag = null,
      category = null;

  const _BookshelfViewSelection.tag(this.tag)
    : kind = _BookshelfViewKind.tag,
      filter = _BookshelfFilter.custom,
      category = null;

  const _BookshelfViewSelection.category(this.category)
    : kind = _BookshelfViewKind.category,
      filter = _BookshelfFilter.custom,
      tag = null;

  final _BookshelfViewKind kind;
  final _BookshelfFilter filter;
  final String? tag;
  final String? category;

  bool get isTag => kind == _BookshelfViewKind.tag;
  bool get isCategory => kind == _BookshelfViewKind.category;
  bool get isUncategorized =>
      isCategory && (category == null || category!.isEmpty);

  @override
  bool operator ==(Object other) {
    return other is _BookshelfViewSelection &&
        other.kind == kind &&
        other.filter == filter &&
        other.tag == tag &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(kind, filter, tag, category);
}

enum _BookshelfSettingsTab { list, grid }

class _BookshelfProgressDisplay {
  const _BookshelfProgressDisplay({
    required this.progressValue,
    required this.summaryText,
    required this.trailingLabel,
    required this.hasProgress,
  });

  final double progressValue;
  final String summaryText;
  final String trailingLabel;
  final bool hasProgress;
}

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key, this.prefetchAnnouncementOnInit = false});

  final bool prefetchAnnouncementOnInit;

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage>
    with AutomaticKeepAliveClientMixin<BookshelfPage> {
  static const List<_BookshelfFilter> _kDefaultBaseFilters = <_BookshelfFilter>[
    _BookshelfFilter.all,
    _BookshelfFilter.local,
    _BookshelfFilter.novel,
    _BookshelfFilter.manga,
  ];

  final BookshelfService _bookshelfService = BookshelfService();
  final BookshelfSystemSettingsService _bookshelfSystemSettingsService =
      BookshelfSystemSettingsService();
  final ReaderPreferencesService _readerPreferencesService =
      ReaderPreferencesService();
  final ReaderEntryRouteResolver _readerEntryRouteResolver =
      const ReaderEntryRouteResolver();
  final LocalBookIndexService _localBookIndexService = LocalBookIndexService();
  final BookDetailService _bookDetailService = BookDetailService();
  final ImageSelectionService _imageSelectionService = ImageSelectionService();
  final TextEditingController _bookshelfSearchController =
      TextEditingController();
  final FocusNode _bookshelfSearchFocusNode = FocusNode();
  final LocalBookImportService _localBookImportService =
      LocalBookImportService();
  final LocalBookRepositoryImpl _localBookRepository = LocalBookRepositoryImpl(
    AppDatabase.instance,
  );
  final AnnouncementService _announcementService = AnnouncementService();
  final AnnouncementReadStateService _announcementReadStateService =
      AnnouncementReadStateService();
  final SourceRuntimeTaskConflictService _taskConflictService =
      SourceRuntimeTaskConflictService.instance;
  StreamSubscription<IncomingExternalImportPayload>? _incomingImportSub;
  StreamSubscription<BookshelfTaxonomyChange>? _taxonomyChangeSub;

  bool _isLoading = true;
  List<BookshelfBook> _books = const <BookshelfBook>[];
  Map<String, ReadingProgress> _progressByBookKey =
      const <String, ReadingProgress>{};
  Map<String, String> _latestCachedChapterByBookKey = const <String, String>{};
  Map<String, int> _cachedChapterCountByBookKey = const <String, int>{};
  Map<String, int> _sourceTypeBySourceId = const <String, int>{};
  Map<String, LocalBook> _localBooksById = const <String, LocalBook>{};
  Map<String, List<String>> _bookTagsByKey = const <String, List<String>>{};
  List<String> _tagOrder = const <String>[];
  Map<String, String> _bookCategoriesByKey = const <String, String>{};
  List<String> _categoryOrder = const <String>[];
  List<_BookshelfFilter> _baseFilterOrder = _kDefaultBaseFilters;
  bool _bookshelfMetadataReady = false;
  Object? _derivedBookshelfFingerprint;
  List<BookshelfBook> _filteredBooksCache = const <BookshelfBook>[];
  Map<String, int> _tagBookCountCache = const <String, int>{};
  Map<String, int> _categoryBookCountCache = const <String, int>{};
  List<String> _userTagsCache = const <String>[];
  List<String> _userCategoriesCache = const <String>[];
  bool _useGridView = false;
  _BookshelfSortMode _sortMode = _BookshelfSortMode.defaultOrder;
  bool _gridAdaptiveColumns = BookshelfService.defaultGridAdaptiveColumns;
  int _gridColumnCount = BookshelfService.defaultGridColumnCount;
  double _gridCrossSpacing = BookshelfService.defaultGridCrossSpacing;
  double _gridMainSpacing = BookshelfService.defaultGridMainSpacing;
  bool _gridShowTitle = BookshelfService.defaultGridShowTitle;
  bool _gridShowAuthor = BookshelfService.defaultGridShowAuthor;
  bool _gridShowLatestChapter = BookshelfService.defaultGridShowLatestChapter;
  bool _gridShowProgressBar = BookshelfService.defaultGridShowProgressBar;
  bool _gridAlwaysShowSearchBar =
      BookshelfService.defaultGridAlwaysShowSearchBar;
  bool _gridPinSearchBar = BookshelfService.defaultGridPinSearchBar;
  _BookshelfSearchQuickFilterContent _gridQuickFilterContent =
      _BookshelfSearchQuickFilterContent.none;
  bool _listShowTitle = BookshelfService.defaultListShowTitle;
  bool _listShowAuthor = BookshelfService.defaultListShowAuthor;
  bool _listShowLatestChapter = BookshelfService.defaultListShowLatestChapter;
  bool _listShowProgressBar = BookshelfService.defaultListShowProgressBar;
  bool _listAlwaysShowSearchBar =
      BookshelfService.defaultListAlwaysShowSearchBar;
  bool _listPinSearchBar = BookshelfService.defaultListPinSearchBar;
  _BookshelfSearchQuickFilterContent _listQuickFilterContent =
      _BookshelfSearchQuickFilterContent.none;
  _BookshelfViewSelection _activeView = const _BookshelfViewSelection.base(
    _BookshelfFilter.all,
  );
  String _bookshelfSearchKeyword = '';
  bool _isBookshelfSearchExpanded = false;
  String? _openingBookId;
  String? _loadErrorText;
  bool _isConsumingExternalImportPayloads = false;
  bool _isSelectionMode = false;
  bool _isBatchDeleting = false;
  bool _isImportingLocal = false;
  final Set<String> _repairingLocalBookIds = <String>{};
  final Set<String> _selectedBookKeys = <String>{};
  int _loadTicket = 0;
  bool _hasActiveAnnouncement = false;
  RouteInformationProvider? _routeInformationProvider;
  String _lastKnownRouteLocation = '';
  DateTime? _lastAutoRefreshAt;
  DateTime? _lastBookshelfLoadRequestedAt;
  Future<void>? _activeBookshelfLoad;
  bool _reloadAfterActiveLoad = false;
  bool? _lastKnownAutoRefreshOnTabActiveEnabled;
  bool _hasShownContinueReadingPrompt = false;
  ReadingRecord? _continueReadingRecord;
  int _latestInfoRefreshEpoch = 0;
  bool _skipNextBackgroundLatestInfoRefresh = false;

  static const String _kLocalBookSourceId =
      LocalBookImportService.localBookSourceId;
  static const Duration _kBookshelfLoadTimeout = Duration(seconds: 8);
  static const Duration _kProgressLoadTimeout = Duration(seconds: 2);
  static const Duration _kSourceMapLoadTimeout = Duration(seconds: 2);
  static const Duration _kBooksModeSwitchItemDuration = Duration(
    milliseconds: 320,
  );
  static const int _kProgressBatchSize = 24;
  static const int _kProgressUiUpdateBatchInterval = 3;
  static const int _kBooksModeSwitchStaggerGroup = 8;
  static const int _kBooksModeSwitchAnimatedItemLimit = 24;
  static const int _kBooksModeSwitchDisableThreshold = 72;
  static const double _kBooksModeSwitchStaggerStep = 0.07;
  static const double _kBooksModeSwitchCurveSpan = 0.42;
  static const Duration _kAutoRefreshDebounce = Duration(milliseconds: 800);
  static const Duration _kDuplicateLoadCooldown = Duration(milliseconds: 700);
  static const Duration _kContinueReadingPromptDuration = Duration(seconds: 6);
  static const double _kContinueReadingCardHeight = 84;
  static const double _kContinueReadingDockGap = 12;
  static const double _kContinueReadingStandardGap = 0;
  static const Set<String> _kMangaCapabilityKeywords = <String>{
    'manga',
    'comic',
    'manhua',
    'manhwa',
  };

  @override
  void initState() {
    super.initState();
    _bookshelfSearchFocusNode.addListener(_handleBookshelfSearchFocusChanged);
    _incomingImportSub = ExternalImportBridge.instance.payloadStream.listen((
      payload,
    ) {
      if (payload.type != ExternalImportPayloadType.localBook) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
    });
    _taxonomyChangeSub = BookshelfService.watchTaxonomyChanges.listen(
      _handleTaxonomyChange,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
      unawaited(_restoreViewModePreference());
      unawaited(_restoreListPreferences());
      unawaited(_restoreSortModePreference());
      unawaited(_restoreGridPreferences());
      unawaited(_restoreViewSelection());
      unawaited(_loadBookshelf());
      if (widget.prefetchAnnouncementOnInit) {
        unawaited(_prefetchLatestAnnouncement());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextProvider = GoRouter.of(context).routeInformationProvider;
    if (identical(_routeInformationProvider, nextProvider)) {
      return;
    }

    _routeInformationProvider?.removeListener(_handleRouteLocationChanged);
    _routeInformationProvider = nextProvider;
    _lastKnownRouteLocation = _routeLocationFrom(nextProvider.value);
    _routeInformationProvider?.addListener(_handleRouteLocationChanged);
  }

  @override
  void dispose() {
    _cancelBackgroundLatestInfoRefresh();
    _loadTicket += 1;
    _routeInformationProvider?.removeListener(_handleRouteLocationChanged);
    _routeInformationProvider = null;
    _incomingImportSub?.cancel();
    _taxonomyChangeSub?.cancel();
    _bookshelfSearchFocusNode.removeListener(
      _handleBookshelfSearchFocusChanged,
    );
    _bookshelfSearchFocusNode.dispose();
    _bookshelfSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(activeAdvancedThemeProvider);
    ref.watch(coverGalleriesProvider);
    final palette = _resolvedPalette(context);
    final horizontal = AppSpacing.pageHorizontal(context);
    final platform = Theme.of(context).platform;
    final effectiveNavigationStyle = resolveAppNavigationStyle(
      ref.watch(appNavigationStylePreferenceProvider),
      isWeb: false,
      platform: platform,
    );
    final showNavigationLabels = ref.watch(
      appNavigationLabelVisibilityProvider,
    );
    final navigationBottomInset = mobileBottomNavigationContentInset(
      context,
      style: effectiveNavigationStyle,
      showNavigationLabels: showNavigationLabels,
    );
    final showTopSearchAction =
        effectiveNavigationStyle != AppNavigationStyle.cupertinoDock;
    final filteredBooks = _filteredBooks;
    final continueReadingVisible =
        _continueReadingRecord != null && !_isSelectionMode;
    final continueReadingBottomGap = _continueReadingBottomGap(
      effectiveNavigationStyle,
    );
    final continueReadingOverlayInset = _continueReadingOverlayInset(
      effectiveNavigationStyle,
      navigationBottomInset: navigationBottomInset,
    );
    final continueReadingReservedSpace =
        continueReadingVisible
            ? _kContinueReadingCardHeight +
                continueReadingBottomGap +
                continueReadingOverlayInset
            : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading:
            _isSelectionMode
                ? IconButton(
                  onPressed: _exitSelectionMode,
                  tooltip: '取消选择',
                  icon: const Icon(Icons.close),
                )
                : null,
        title:
            _isSelectionMode
                ? Text('已选择 ${_selectedBookKeys.length} 项')
                : _buildBookshelfViewTitle(),
        actions: [
          if (_isSelectionMode)
            if (_isBatchDeleting)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              const SizedBox.shrink()
          else if (_isImportingLocal)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            _buildAnnouncementAction(),
            if (showTopSearchAction)
              IconButton(
                tooltip: '搜索书籍',
                onPressed: () => context.go('/search'),
                icon: const Icon(Icons.search_rounded),
              ),
            PopupMenuButton<_BookshelfMoreAction>(
              tooltip: '更多功能',
              onSelected: _handleMoreAction,
              itemBuilder:
                  (context) => [
                    PopupMenuItem<_BookshelfMoreAction>(
                      value: _BookshelfMoreAction.selectBooks,
                      enabled: !_isLoading && _filteredBooks.isNotEmpty,
                      child: const Row(
                        children: [
                          Icon(Icons.checklist_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('选择书籍'),
                        ],
                      ),
                    ),
                    PopupMenuItem<_BookshelfMoreAction>(
                      value: _BookshelfMoreAction.sortBooks,
                      enabled: !_isLoading && _books.isNotEmpty,
                      child: const Row(
                        children: [
                          Icon(Icons.sort_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('书籍排序'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<_BookshelfMoreAction>(
                      value: _BookshelfMoreAction.settings,
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('书架设置'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<_BookshelfMoreAction>(
                      value: _BookshelfMoreAction.importLocal,
                      child: Row(
                        children: [
                          Icon(Icons.library_add_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('导入图书'),
                        ],
                      ),
                    ),
                  ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ],
      ),
      bottomNavigationBar:
          _isSelectionMode
              ? _buildSelectionActionBar(filteredBooks: filteredBooks)
              : null,
      body: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.backgroundColor, palette.surfaceColor],
              ),
            ),
            child: RefreshIndicator(
              onRefresh: () => _loadBookshelf(force: true),
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_books.isNotEmpty)
                    _buildBookshelfSearchSliver(horizontal: horizontal),
                  if (_books.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        12,
                        horizontal,
                        16 +
                            navigationBottomInset +
                            continueReadingReservedSpace,
                      ),
                      sliver: _buildBooksContentSliver(filteredBooks),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        12,
                        horizontal,
                        16 +
                            navigationBottomInset +
                            continueReadingReservedSpace,
                      ),
                      sliver: _buildBooksContentSliver(filteredBooks),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: horizontal,
            right: horizontal,
            bottom: continueReadingBottomGap + continueReadingOverlayInset,
            child: _buildContinueReadingPromptCard(),
          ),
        ],
      ),
    );
  }

  double _continueReadingBottomGap(AppNavigationStyle style) {
    return switch (style) {
      AppNavigationStyle.standard => _kContinueReadingStandardGap,
      AppNavigationStyle.cupertinoDock => _kContinueReadingDockGap,
    };
  }

  double _continueReadingOverlayInset(
    AppNavigationStyle style, {
    required double navigationBottomInset,
  }) {
    return switch (style) {
      // Standard NavigationBar already sits outside the scaffold body.
      AppNavigationStyle.standard => 0,
      AppNavigationStyle.cupertinoDock => navigationBottomInset,
    };
  }

  @override
  bool get wantKeepAlive => true;

  ResolvedAdvancedThemePalette _resolvedPalette(BuildContext context) {
    return resolveAdvancedThemePalette(
      Theme.of(context).colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
  }

  void _handleRouteLocationChanged() {
    final provider = _routeInformationProvider;
    if (provider == null) {
      return;
    }

    final nextLocation = _routeLocationFrom(provider.value);
    final wasOnBookshelf = _isBookshelfRoute(_lastKnownRouteLocation);
    final isOnBookshelf = _isBookshelfRoute(nextLocation);
    _lastKnownRouteLocation = nextLocation;

    if (wasOnBookshelf && !isOnBookshelf) {
      _cancelBackgroundLatestInfoRefresh();
    }

    if (!wasOnBookshelf && isOnBookshelf) {
      unawaited(_maybeAutoRefreshOnTabActivated());
    }
  }

  String _routeLocationFrom(RouteInformation routeInformation) {
    return routeInformation.uri.toString();
  }

  bool _isBookshelfRoute(String location) {
    return location.startsWith('/bookshelf');
  }

  void _handleTaxonomyChange(BookshelfTaxonomyChange change) {
    if (!mounted) {
      return;
    }

    setState(() {
      switch (change.kind) {
        case BookshelfTaxonomyKind.tag:
          if (_activeView.isTag && _activeView.tag == change.previousName) {
            switch (change.action) {
              case BookshelfTaxonomyAction.rename:
                final nextName = change.currentName?.trim();
                if (nextName != null && nextName.isNotEmpty) {
                  _activeView = _BookshelfViewSelection.tag(nextName);
                }
              case BookshelfTaxonomyAction.delete:
                _activeView = const _BookshelfViewSelection.base(
                  _BookshelfFilter.all,
                );
              case BookshelfTaxonomyAction.create ||
                  BookshelfTaxonomyAction.orderChanged ||
                  BookshelfTaxonomyAction.assignmentChanged:
                break;
            }
          }
        case BookshelfTaxonomyKind.category:
          if (_activeView.isCategory &&
              _activeView.category == change.previousName) {
            switch (change.action) {
              case BookshelfTaxonomyAction.rename:
                final nextName = change.currentName?.trim();
                if (nextName != null && nextName.isNotEmpty) {
                  _activeView = _BookshelfViewSelection.category(nextName);
                }
              case BookshelfTaxonomyAction.delete:
                _activeView = const _BookshelfViewSelection.base(
                  _BookshelfFilter.all,
                );
              case BookshelfTaxonomyAction.create ||
                  BookshelfTaxonomyAction.orderChanged ||
                  BookshelfTaxonomyAction.assignmentChanged:
                break;
            }
          }
      }
    });

    unawaited(_loadBookshelfMetadata(_books, ticket: _loadTicket));
  }

  Future<void> _maybeAutoRefreshOnTabActivated() async {
    if (!mounted) {
      return;
    }
    final now = DateTime.now();
    final lastRun = _lastAutoRefreshAt;
    if (lastRun != null && now.difference(lastRun) < _kAutoRefreshDebounce) {
      return;
    }

    final enabled = await _isAutoRefreshOnTabActiveEnabled();
    if (!mounted || !enabled || !_isBookshelfRoute(_lastKnownRouteLocation)) {
      return;
    }

    _lastAutoRefreshAt = now;
    await _loadBookshelf(force: true);
  }

  Future<void> _restoreViewSelection() async {
    final stored = await _bookshelfService.loadViewSelection();
    if (!mounted || stored == null) {
      return;
    }

    final kind = (stored['kind'] ?? '').trim();
    final value = (stored['value'] ?? '').trim();
    final next = switch (kind) {
      'tag' when value.isNotEmpty => _BookshelfViewSelection.tag(value),
      'category' =>
        value.isEmpty
            ? const _BookshelfViewSelection.category(null)
            : _BookshelfViewSelection.category(value),
      'local' => const _BookshelfViewSelection.base(_BookshelfFilter.local),
      'novel' => const _BookshelfViewSelection.base(_BookshelfFilter.novel),
      'manga' => const _BookshelfViewSelection.base(_BookshelfFilter.manga),
      _ => const _BookshelfViewSelection.base(_BookshelfFilter.all),
    };

    if (next == _activeView) {
      return;
    }
    setState(() {
      _activeView = next;
    });
  }

  Future<bool> _isAutoRefreshOnTabActiveEnabled() async {
    try {
      final enabled =
          await _bookshelfSystemSettingsService
              .loadAutoRefreshOnTabActiveEnabled();
      _lastKnownAutoRefreshOnTabActiveEnabled = enabled;
      return enabled;
    } catch (_) {
      return _lastKnownAutoRefreshOnTabActiveEnabled ?? false;
    }
  }

  Future<void> _prefetchLatestAnnouncement() async {
    try {
      final latest = await _announcementService.fetchLatestAnnouncement();
      if (latest == null) {
        return;
      }
      final isRead = await _announcementReadStateService.isRead(latest.id);
      if (!mounted) {
        return;
      }
      final active = latest.isActiveAt(DateTime.now().toUtc());
      final shouldShow = active && !isRead;
      if (shouldShow != _hasActiveAnnouncement) {
        setState(() {
          _hasActiveAnnouncement = shouldShow;
        });
      }
    } catch (_) {
      // ignore announcement prefetch failures to avoid blocking bookshelf
    }
  }

  Widget _buildAnnouncementAction() {
    final icon = IconButton(
      tooltip: '公告',
      onPressed: () {
        context.push('/announcements').then((_) {
          if (!mounted) {
            return;
          }
          unawaited(_prefetchLatestAnnouncement());
        });
      },
      icon: const Icon(Icons.notifications_none_outlined),
    );
    if (!_hasActiveAnnouncement) {
      return icon;
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        icon,
        Positioned(
          right: 10,
          top: 12,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBooksContentSliver(List<BookshelfBook> books) {
    if (_isLoading && _books.isEmpty) {
      return const SliverToBoxAdapter(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('正在加载书架...')),
              ],
            ),
          ),
        ),
      );
    }

    if (_books.isEmpty && _loadErrorText != null) {
      return SliverToBoxAdapter(
        child: _buildLoadErrorCard(message: _loadErrorText!),
      );
    }

    if (_books.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyCard());
    }

    if (books.isEmpty) {
      return SliverToBoxAdapter(child: _buildFilterEmptyCard());
    }

    if (_useGridView) {
      return _buildBookGridSliver(books);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final book = books[index];
        return _buildModeSwitchAnimatedBookItem(
          book: book,
          index: index,
          totalCount: books.length,
          child: _buildBookCard(book),
        );
      }, childCount: books.length),
    );
  }

  Widget _buildEmptyCard() {
    return BookshelfEmptyCard(
      onImportLocal: _importLocalBooksFromPicker,
      palette: _resolvedPalette(context),
    );
  }

  void _handleMoreAction(_BookshelfMoreAction action) {
    switch (action) {
      case _BookshelfMoreAction.selectBooks:
        _startSelectionMode();
        break;
      case _BookshelfMoreAction.sortBooks:
        unawaited(_showSortModeSheet());
        break;
      case _BookshelfMoreAction.settings:
        unawaited(_showBookshelfSettingsSheet());
        break;
      case _BookshelfMoreAction.importLocal:
        unawaited(_importLocalBooksFromPicker());
        break;
    }
  }

  void _handleBookshelfSearchFocusChanged() {
    if (!mounted ||
        _bookshelfSearchFocusNode.hasFocus ||
        _hasBookshelfSearchKeyword ||
        _alwaysShowBookshelfSearchBar ||
        !_isBookshelfSearchExpanded) {
      return;
    }
    setState(() {
      _isBookshelfSearchExpanded = false;
    });
  }

  bool get _alwaysShowBookshelfSearchBar {
    return _useGridView ? _gridAlwaysShowSearchBar : _listAlwaysShowSearchBar;
  }

  bool get _pinBookshelfSearchBar {
    return _useGridView ? _gridPinSearchBar : _listPinSearchBar;
  }

  _BookshelfSearchQuickFilterContent get _bookshelfQuickFilterContent {
    return _useGridView ? _gridQuickFilterContent : _listQuickFilterContent;
  }

  bool get _shouldShowExpandedBookshelfSearch {
    return _alwaysShowBookshelfSearchBar ||
        _hasBookshelfSearchKeyword ||
        _isBookshelfSearchExpanded;
  }

  void _expandBookshelfSearch() {
    if (_shouldShowExpandedBookshelfSearch) {
      _bookshelfSearchFocusNode.requestFocus();
      return;
    }
    setState(() {
      _isBookshelfSearchExpanded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bookshelfSearchFocusNode.requestFocus();
    });
  }

  void _updateBookshelfSearchKeyword(String value) {
    if (_bookshelfSearchKeyword == value) {
      return;
    }
    setState(() {
      _bookshelfSearchKeyword = value;
      if (value.trim().isNotEmpty) {
        _isBookshelfSearchExpanded = true;
      }
    });
    _syncSelectionWithBooks();
  }

  void _clearBookshelfSearchKeyword() {
    if (_bookshelfSearchController.text.isEmpty &&
        _bookshelfSearchKeyword.isEmpty) {
      return;
    }
    _bookshelfSearchController.clear();
    _bookshelfSearchFocusNode.unfocus();
    setState(() {
      _bookshelfSearchKeyword = '';
      if (!_alwaysShowBookshelfSearchBar) {
        _isBookshelfSearchExpanded = false;
      }
    });
    _syncSelectionWithBooks();
  }

  Future<void> _showSortModeSheet() async {
    if (_books.isEmpty || !mounted) {
      return;
    }

    final selected = await _showBookshelfBottomSheet<_BookshelfSortMode>(
      builder: (sheetContext) {
        final bottomInset = _bookshelfBottomSafeInset(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomInset),
          child: RadioGroup<_BookshelfSortMode>(
            groupValue: _sortMode,
            onChanged:
                (value) =>
                    Navigator.of(sheetContext, rootNavigator: true).pop(value),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Text(
                    '书籍排序',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final mode in _BookshelfSortMode.values)
                  RadioListTile<_BookshelfSortMode>(
                    value: mode,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(_sortModeLabel(mode)),
                    subtitle: Text(_sortModeDescription(mode)),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || selected == _sortMode || !mounted) {
      return;
    }

    setState(() {
      _sortMode = selected;
    });
    try {
      await _bookshelfService.saveSortMode(_sortModeStorageValue(selected));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('书籍排序保存失败，请重试。');
    }
  }

  Future<void> _showBookshelfSettingsSheet() async {
    if (!mounted) {
      return;
    }

    var draftAdaptive = _gridAdaptiveColumns;
    var draftColumns = _gridColumnCount;
    var draftCrossSpacing = _gridCrossSpacing;
    var draftMainSpacing = _gridMainSpacing;
    var draftShowTitle = _gridShowTitle;
    var draftShowAuthor = _gridShowAuthor;
    var draftShowLatestChapter = _gridShowLatestChapter;
    var draftShowProgressBar = _gridShowProgressBar;
    var draftGridAlwaysShowSearchBar = _gridAlwaysShowSearchBar;
    var draftGridPinSearchBar = _gridPinSearchBar;
    var draftGridQuickFilterContent = _gridQuickFilterContent;
    var draftListShowTitle = _listShowTitle;
    var draftListShowAuthor = _listShowAuthor;
    var draftListShowLatestChapter = _listShowLatestChapter;
    var draftListShowProgressBar = _listShowProgressBar;
    var draftListAlwaysShowSearchBar = _listAlwaysShowSearchBar;
    var draftListPinSearchBar = _listPinSearchBar;
    var draftListQuickFilterContent = _listQuickFilterContent;

    await _showBookshelfBottomSheet<void>(
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomInset = _bookshelfBottomSafeInset(sheetContext);
        return DefaultTabController(
          initialIndex: _useGridView ? 1 : 0,
          length: _BookshelfSettingsTab.values.length,
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final theme = Theme.of(sheetContext);
              final colorScheme = theme.colorScheme;
              final tabs = _BookshelfSettingsTab.values;

              Future<void> persistGridSettings() async {
                try {
                  await _bookshelfService.saveGridAdaptiveColumns(
                    draftAdaptive,
                  );
                  await _bookshelfService.saveGridColumnCount(draftColumns);
                  await _bookshelfService.saveGridCrossSpacing(
                    draftCrossSpacing,
                  );
                  await _bookshelfService.saveGridMainSpacing(draftMainSpacing);
                  await _bookshelfService.saveGridShowTitle(draftShowTitle);
                  await _bookshelfService.saveGridShowAuthor(draftShowAuthor);
                  await _bookshelfService.saveGridShowLatestChapter(
                    draftShowLatestChapter,
                  );
                  await _bookshelfService.saveGridShowProgressBar(
                    draftShowProgressBar,
                  );
                  await _bookshelfService.saveGridAlwaysShowSearchBar(
                    draftGridAlwaysShowSearchBar,
                  );
                  await _bookshelfService.saveGridPinSearchBar(
                    draftGridPinSearchBar,
                  );
                  await _bookshelfService.saveGridQuickFilterContent(
                    _searchQuickFilterContentStorageValue(
                      draftGridQuickFilterContent,
                    ),
                  );
                } catch (_) {
                  if (!mounted) {
                    return;
                  }
                  _showMessage('书架设置保存失败，请重试。');
                }
              }

              Future<void> persistListSettings() async {
                try {
                  await _bookshelfService.saveListShowTitle(draftListShowTitle);
                  await _bookshelfService.saveListShowAuthor(
                    draftListShowAuthor,
                  );
                  await _bookshelfService.saveListShowLatestChapter(
                    draftListShowLatestChapter,
                  );
                  await _bookshelfService.saveListShowProgressBar(
                    draftListShowProgressBar,
                  );
                  await _bookshelfService.saveListAlwaysShowSearchBar(
                    draftListAlwaysShowSearchBar,
                  );
                  await _bookshelfService.saveListPinSearchBar(
                    draftListPinSearchBar,
                  );
                  await _bookshelfService.saveListQuickFilterContent(
                    _searchQuickFilterContentStorageValue(
                      draftListQuickFilterContent,
                    ),
                  );
                } catch (_) {
                  if (!mounted) {
                    return;
                  }
                  _showMessage('书架设置保存失败，请重试。');
                }
              }

              Future<void> setBookshelfViewMode(bool useGridView) async {
                if (_useGridView == useGridView) {
                  return;
                }
                setState(() {
                  _useGridView = useGridView;
                });
                try {
                  await _bookshelfService.saveUseGridView(useGridView);
                } catch (_) {
                  if (!mounted) {
                    return;
                  }
                  _showMessage('书架视图保存失败，请重试。');
                }
              }

              Widget buildSectionTitle(String title, String subtitle) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                );
              }

              Widget buildGroupHeader(String title) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                      color: colorScheme.onSurface,
                    ),
                  ),
                );
              }

              Widget buildCompactSwitchTile({
                required bool value,
                required String title,
                String? subtitle,
                required ValueChanged<bool> onChanged,
              }) {
                return SwitchListTile.adaptive(
                  value: value,
                  dense: false,
                  visualDensity: const VisualDensity(
                    horizontal: -1,
                    vertical: -1,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle:
                      subtitle == null
                          ? null
                          : Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12.5,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                  onChanged: onChanged,
                );
              }

              Widget buildSearchSettings({
                required bool alwaysShowSearchBar,
                required bool pinSearchBar,
                required _BookshelfSearchQuickFilterContent quickFilterContent,
                required ValueChanged<bool> onAlwaysShowChanged,
                required ValueChanged<bool> onPinChanged,
                required ValueChanged<_BookshelfSearchQuickFilterContent>
                onQuickFilterChanged,
              }) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildGroupHeader('搜索设置'),
                    buildCompactSwitchTile(
                      value: alwaysShowSearchBar,
                      title: '总是显示搜索框',
                      subtitle: '关闭后显示为紧凑入口，点击后再展开搜索。',
                      onChanged: onAlwaysShowChanged,
                    ),
                    buildCompactSwitchTile(
                      value: pinSearchBar,
                      title: '搜索框吸顶',
                      subtitle: '滚动时将快捷筛选和搜索入口固定在顶部。',
                      onChanged: onPinChanged,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '快捷筛选内容',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<
                              _BookshelfSearchQuickFilterContent
                            >(
                              value: quickFilterContent,
                              isDense: true,
                              borderRadius: BorderRadius.circular(14),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              onChanged:
                                  (value) =>
                                      value == null
                                          ? null
                                          : onQuickFilterChanged(value),
                              items: [
                                for (final option
                                    in _BookshelfSearchQuickFilterContent
                                        .values)
                                  DropdownMenuItem<
                                    _BookshelfSearchQuickFilterContent
                                  >(
                                    value: option,
                                    child: Text(
                                      _searchQuickFilterContentLabel(option),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              Widget buildGridSettings() {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                  children: [
                    buildSectionTitle('网格设置', '自定义网格列数与间距，自适应开启后会按屏幕宽度自动分列。'),
                    buildGroupHeader('布局设置'),
                    buildCompactSwitchTile(
                      value: draftAdaptive,
                      title: '自适应列数',
                      subtitle: '根据当前宽度自动决定 2-6 列。',
                      onChanged: (value) {
                        setSheetState(() {
                          draftAdaptive = value;
                        });
                        setState(() {
                          _gridAdaptiveColumns = value;
                        });
                        unawaited(persistGridSettings());
                      },
                    ),
                    BookshelfStepperSettingRow(
                      title: '网格列数',
                      subtitle:
                          draftAdaptive ? '已启用自适应列数，固定列数暂不可用' : '手动指定固定列数。',
                      valueLabel: '$draftColumns',
                      enabled: !draftAdaptive,
                      onDecrease:
                          draftAdaptive || draftColumns <= 2
                              ? null
                              : () {
                                final next = draftColumns - 1;
                                setSheetState(() {
                                  draftColumns = next;
                                });
                                setState(() {
                                  _gridColumnCount = next;
                                });
                                unawaited(persistGridSettings());
                              },
                      onIncrease:
                          draftAdaptive || draftColumns >= 6
                              ? null
                              : () {
                                final next = draftColumns + 1;
                                setSheetState(() {
                                  draftColumns = next;
                                });
                                setState(() {
                                  _gridColumnCount = next;
                                });
                                unawaited(persistGridSettings());
                              },
                    ),
                    BookshelfStepperSettingRow(
                      title: '列间距',
                      subtitle: '控制卡片之间的左右间距。',
                      valueLabel: draftCrossSpacing.toStringAsFixed(0),
                      onDecrease:
                          draftCrossSpacing <= 4
                              ? null
                              : () {
                                final next = (draftCrossSpacing - 2).clamp(
                                  4.0,
                                  24.0,
                                );
                                setSheetState(() {
                                  draftCrossSpacing = next;
                                });
                                setState(() {
                                  _gridCrossSpacing = next;
                                });
                                unawaited(persistGridSettings());
                              },
                      onIncrease:
                          draftCrossSpacing >= 24
                              ? null
                              : () {
                                final next = (draftCrossSpacing + 2).clamp(
                                  4.0,
                                  24.0,
                                );
                                setSheetState(() {
                                  draftCrossSpacing = next;
                                });
                                setState(() {
                                  _gridCrossSpacing = next;
                                });
                                unawaited(persistGridSettings());
                              },
                    ),
                    BookshelfStepperSettingRow(
                      title: '行间距',
                      subtitle: '控制卡片之间的上下间距。',
                      valueLabel: draftMainSpacing.toStringAsFixed(0),
                      onDecrease:
                          draftMainSpacing <= 4
                              ? null
                              : () {
                                final next = (draftMainSpacing - 2).clamp(
                                  4.0,
                                  24.0,
                                );
                                setSheetState(() {
                                  draftMainSpacing = next;
                                });
                                setState(() {
                                  _gridMainSpacing = next;
                                });
                                unawaited(persistGridSettings());
                              },
                      onIncrease:
                          draftMainSpacing >= 24
                              ? null
                              : () {
                                final next = (draftMainSpacing + 2).clamp(
                                  4.0,
                                  24.0,
                                );
                                setSheetState(() {
                                  draftMainSpacing = next;
                                });
                                setState(() {
                                  _gridMainSpacing = next;
                                });
                                unawaited(persistGridSettings());
                              },
                    ),
                    buildGroupHeader('文字信息'),
                    buildCompactSwitchTile(
                      value: !draftShowTitle,
                      title: '隐藏书籍名称',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftShowTitle = next;
                        });
                        setState(() {
                          _gridShowTitle = next;
                        });
                        unawaited(persistGridSettings());
                      },
                    ),
                    buildCompactSwitchTile(
                      value: !draftShowAuthor,
                      title: '隐藏作者名称',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftShowAuthor = next;
                        });
                        setState(() {
                          _gridShowAuthor = next;
                        });
                        unawaited(persistGridSettings());
                      },
                    ),
                    buildCompactSwitchTile(
                      value: !draftShowLatestChapter,
                      title: '隐藏最新章节',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftShowLatestChapter = next;
                        });
                        setState(() {
                          _gridShowLatestChapter = next;
                        });
                        unawaited(persistGridSettings());
                      },
                    ),
                    buildSearchSettings(
                      alwaysShowSearchBar: draftGridAlwaysShowSearchBar,
                      pinSearchBar: draftGridPinSearchBar,
                      quickFilterContent: draftGridQuickFilterContent,
                      onAlwaysShowChanged: (value) {
                        setSheetState(() {
                          draftGridAlwaysShowSearchBar = value;
                        });
                        setState(() {
                          _gridAlwaysShowSearchBar = value;
                          if (value) {
                            _isBookshelfSearchExpanded = false;
                          }
                        });
                        unawaited(persistGridSettings());
                      },
                      onPinChanged: (value) {
                        setSheetState(() {
                          draftGridPinSearchBar = value;
                        });
                        setState(() {
                          _gridPinSearchBar = value;
                        });
                        unawaited(persistGridSettings());
                      },
                      onQuickFilterChanged: (value) {
                        setSheetState(() {
                          draftGridQuickFilterContent = value;
                        });
                        setState(() {
                          _gridQuickFilterContent = value;
                        });
                        unawaited(persistGridSettings());
                      },
                    ),
                    buildGroupHeader('封面设置'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        child: Text(
                          '当前暂未提供额外封面设置。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    buildGroupHeader('其他设置'),
                    buildCompactSwitchTile(
                      value: !draftShowProgressBar,
                      title: '隐藏进度条',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftShowProgressBar = next;
                        });
                        setState(() {
                          _gridShowProgressBar = next;
                        });
                        unawaited(persistGridSettings());
                      },
                    ),
                  ],
                );
              }

              Widget buildListSettings() {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                  children: [
                    buildSectionTitle('列表设置', '调整列表模式下展示哪些信息。'),
                    buildGroupHeader('文字信息'),
                    buildCompactSwitchTile(
                      value: !draftListShowTitle,
                      title: '隐藏书籍名称',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftListShowTitle = next;
                        });
                        setState(() {
                          _listShowTitle = next;
                        });
                        unawaited(persistListSettings());
                      },
                    ),
                    buildCompactSwitchTile(
                      value: !draftListShowAuthor,
                      title: '隐藏作者名称',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftListShowAuthor = next;
                        });
                        setState(() {
                          _listShowAuthor = next;
                        });
                        unawaited(persistListSettings());
                      },
                    ),
                    buildCompactSwitchTile(
                      value: !draftListShowLatestChapter,
                      title: '隐藏最新章节',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftListShowLatestChapter = next;
                        });
                        setState(() {
                          _listShowLatestChapter = next;
                        });
                        unawaited(persistListSettings());
                      },
                    ),
                    buildSearchSettings(
                      alwaysShowSearchBar: draftListAlwaysShowSearchBar,
                      pinSearchBar: draftListPinSearchBar,
                      quickFilterContent: draftListQuickFilterContent,
                      onAlwaysShowChanged: (value) {
                        setSheetState(() {
                          draftListAlwaysShowSearchBar = value;
                        });
                        setState(() {
                          _listAlwaysShowSearchBar = value;
                          if (value) {
                            _isBookshelfSearchExpanded = false;
                          }
                        });
                        unawaited(persistListSettings());
                      },
                      onPinChanged: (value) {
                        setSheetState(() {
                          draftListPinSearchBar = value;
                        });
                        setState(() {
                          _listPinSearchBar = value;
                        });
                        unawaited(persistListSettings());
                      },
                      onQuickFilterChanged: (value) {
                        setSheetState(() {
                          draftListQuickFilterContent = value;
                        });
                        setState(() {
                          _listQuickFilterContent = value;
                        });
                        unawaited(persistListSettings());
                      },
                    ),
                    buildGroupHeader('其他设置'),
                    buildCompactSwitchTile(
                      value: !draftListShowProgressBar,
                      title: '隐藏进度条',
                      onChanged: (value) {
                        final next = !value;
                        setSheetState(() {
                          draftListShowProgressBar = next;
                        });
                        setState(() {
                          _listShowProgressBar = next;
                        });
                        unawaited(persistListSettings());
                      },
                    ),
                    buildGroupHeader('封面设置'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        child: Text(
                          '当前暂未提供额外封面设置。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomInset),
                child: SizedBox(
                  height: MediaQuery.sizeOf(sheetContext).height * 0.66,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 3, 12, 7),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '书架设置',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelStyle: theme.textTheme.labelMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelStyle: theme.textTheme.labelMedium
                              ?.copyWith(fontSize: 14),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          tabAlignment: TabAlignment.fill,
                          onTap:
                              (index) =>
                                  unawaited(setBookshelfViewMode(index == 1)),
                          tabs: [
                            for (final tab in tabs)
                              Tab(text: _bookshelfSettingsTabLabel(tab)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Expanded(
                        child: TabBarView(
                          children: [buildListSettings(), buildGridSettings()],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _importLocalBooksFromPicker() async {
    if (_isImportingLocal || _isBatchDeleting) {
      return;
    }

    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Book Files',
          extensions: [
            'txt',
            'epub',
            'md',
            'markdown',
            'html',
            'htm',
            'pdf',
            'mobi',
            'azw',
            'azw3',
          ],
          uniformTypeIdentifiers: [
            'public.plain-text',
            'org.idpf.epub-container',
            'public.html',
            'com.adobe.pdf',
          ],
        ),
      ],
      confirmButtonText: '选择本地图书',
    );

    if (!mounted || files.isEmpty) {
      return;
    }

    setState(() {
      _isImportingLocal = true;
    });

    var successCount = 0;
    var failureCount = 0;
    String? lastError;

    try {
      for (final file in files) {
        final filePath = file.path.trim();
        if (filePath.isEmpty) {
          continue;
        }

        try {
          final displayName =
              file.name.trim().isEmpty
                  ? p.basename(filePath)
                  : file.name.trim();
          await _localBookImportService.importFromFile(
            filePath: filePath,
            displayName: displayName,
            waitForIndexing: false,
          );
          successCount += 1;
        } on AppException catch (error) {
          failureCount += 1;
          lastError = error.briefMessage;
        } catch (error) {
          failureCount += 1;
          lastError = '导入失败：$error';
        }
      }

      await _loadBookshelf(force: true);

      if (!mounted) {
        return;
      }

      if (successCount > 0) {
        if (failureCount > 0) {
          _showMessage(
            '已导入 $successCount 本书并加入书架，失败 $failureCount 本。后台会继续解析成功导入的图书。',
          );
        } else {
          _showMessage('已导入 $successCount 本书并加入书架。后台会继续解析。');
        }
        return;
      }

      _showMessage(lastError ?? '导入失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isImportingLocal = false;
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
          type: ExternalImportPayloadType.localBook,
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
      _showMessage('读取外部图书失败：${payload.label}');
      return;
    }

    final tempFile = File(cached.path);
    try {
      final extension = p.extension(cached.label).toLowerCase();
      if (extension != '.txt' &&
          extension != '.epub' &&
          extension != '.md' &&
          extension != '.markdown' &&
          extension != '.html' &&
          extension != '.htm' &&
          extension != '.pdf' &&
          extension != '.mobi' &&
          extension != '.azw' &&
          extension != '.azw3') {
        _showMessage('暂不支持导入该文件：${cached.label}');
        return;
      }

      await _localBookImportService.importFromFile(
        filePath: cached.path,
        displayName: cached.label,
        waitForIndexing: true,
      );
      await _loadBookshelf(force: true);
      if (!mounted) {
        return;
      }
      _showMessage('已导入 ${cached.label}');
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (error) {
      _showMessage('导入失败：$error');
    } finally {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {
        // ignore cleanup failure
      }
    }
  }

  Widget _buildFilterEmptyCard() {
    return BookshelfFilterEmptyCard(
      label: _activeFilterLabel(),
      searchKeyword: _normalizedBookshelfSearchKeyword,
      palette: _resolvedPalette(context),
    );
  }

  Widget _buildLoadErrorCard({required String message}) {
    return BookshelfLoadErrorCard(
      message: message,
      onRetry: () => unawaited(_loadBookshelf(force: true)),
      palette: _resolvedPalette(context),
    );
  }

  Widget _buildBookshelfSearchBar() {
    return BookshelfInlineSearchBar(
      palette: _resolvedPalette(context),
      controller: _bookshelfSearchController,
      focusNode: _bookshelfSearchFocusNode,
      onChanged: _updateBookshelfSearchKeyword,
      onClear: _clearBookshelfSearchKeyword,
      summaryText: _bookshelfSearchSummaryText,
    );
  }

  String get _bookshelfSearchSummaryText {
    if (_isSelectionMode) {
      return '已选 ${_selectedBookKeys.length} 本';
    }
    if (_hasBookshelfSearchKeyword) {
      return '结果 ${_filteredBooks.length} 本';
    }
    return '${_activeFilterLabel()} ${_filteredBooks.length} 本';
  }

  Widget _buildBookshelfSearchSliver({required double horizontal}) {
    final height = _bookshelfSearchSectionHeight;
    final child = _buildBookshelfSearchSection(horizontal: horizontal);
    if (_pinBookshelfSearchBar) {
      return SliverPersistentHeader(
        pinned: true,
        delegate: _BookshelfPinnedHeaderDelegate(extent: height, child: child),
      );
    }
    return SliverToBoxAdapter(child: child);
  }

  double get _bookshelfSearchSectionHeight {
    final quickFilterHeight = _shouldShowBookshelfQuickFilters ? 46.0 : 0.0;
    final searchHeight = _shouldShowExpandedBookshelfSearch ? 42.0 : 40.0;
    return 12 + quickFilterHeight + searchHeight;
  }

  Widget _buildBookshelfSearchSection({required double horizontal}) {
    final palette = _resolvedPalette(context);
    return Container(
      color: palette.backgroundColor,
      padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_shouldShowBookshelfQuickFilters) ...[
            _buildBookshelfQuickFilterBar(),
            const SizedBox(height: 8),
          ],
          _shouldShowExpandedBookshelfSearch
              ? _buildBookshelfSearchBar()
              : _buildBookshelfSearchTrigger(),
        ],
      ),
    );
  }

  Widget _buildBookshelfSearchTrigger() {
    return BookshelfInlineSearchTrigger(
      palette: _resolvedPalette(context),
      summaryText: _bookshelfSearchSummaryText,
      onTap: _expandBookshelfSearch,
    );
  }

  bool get _shouldShowBookshelfQuickFilters {
    return switch (_bookshelfQuickFilterContent) {
      _BookshelfSearchQuickFilterContent.none => false,
      _BookshelfSearchQuickFilterContent.tags =>
        _userTags.isNotEmpty || _books.any((book) => _tagsOfBook(book).isEmpty),
      _BookshelfSearchQuickFilterContent.categories =>
        _userCategories.isNotEmpty ||
            _books.any((book) => (_categoryOfBook(book) ?? '').isEmpty),
    };
  }

  Widget _buildBookshelfQuickFilterBar() {
    final chips = switch (_bookshelfQuickFilterContent) {
      _BookshelfSearchQuickFilterContent.tags => _buildTagQuickFilterChips(),
      _BookshelfSearchQuickFilterContent.categories =>
        _buildCategoryQuickFilterChips(),
      _BookshelfSearchQuickFilterContent.none =>
        const <BookshelfFilterChipData>[],
    };

    return BookshelfFilterBar(
      palette: _resolvedPalette(context),
      baseChips: chips,
      customChips: const <BookshelfFilterChipData>[],
      highlightFilterAction: false,
      filterActionMessage: '',
      onOpenFilterSheet: null,
      showActionButton: false,
    );
  }

  List<BookshelfFilterChipData> _buildTagQuickFilterChips() {
    final chips = <BookshelfFilterChipData>[
      BookshelfFilterChipData(
        label: '全部',
        selected: !_activeView.isTag,
        onTap:
            !_activeView.isTag
                ? null
                : () => _activateView(
                  const _BookshelfViewSelection.base(_BookshelfFilter.all),
                ),
      ),
    ];

    final hasUntagged = _books.any((book) => _tagsOfBook(book).isEmpty);
    if (hasUntagged) {
      chips.add(
        BookshelfFilterChipData(
          label: '未打标签',
          selected: _activeView.isTag && (_activeView.tag?.isEmpty ?? false),
          onTap: () => _activateView(const _BookshelfViewSelection.tag('')),
        ),
      );
    }

    for (final tag in _userTags) {
      chips.add(
        BookshelfFilterChipData(
          label: tag,
          selected: _activeView.isTag && _activeView.tag == tag,
          onTap: () => _activateView(_BookshelfViewSelection.tag(tag)),
        ),
      );
    }
    return chips;
  }

  List<BookshelfFilterChipData> _buildCategoryQuickFilterChips() {
    final chips = <BookshelfFilterChipData>[
      BookshelfFilterChipData(
        label: '全部',
        selected: !_activeView.isCategory,
        onTap:
            !_activeView.isCategory
                ? null
                : () => _activateView(
                  const _BookshelfViewSelection.base(_BookshelfFilter.all),
                ),
      ),
    ];

    final hasUncategorized = _books.any(
      (book) => (_categoryOfBook(book) ?? '').isEmpty,
    );
    if (hasUncategorized) {
      chips.add(
        BookshelfFilterChipData(
          label: '未分类',
          selected: _activeView.isUncategorized,
          onTap:
              () => _activateView(const _BookshelfViewSelection.category(null)),
        ),
      );
    }

    for (final category in _userCategories) {
      chips.add(
        BookshelfFilterChipData(
          label: category,
          selected: _activeView.isCategory && _activeView.category == category,
          onTap:
              () => _activateView(_BookshelfViewSelection.category(category)),
        ),
      );
    }
    return chips;
  }

  Widget _buildBookshelfViewTitle() {
    final title = _activeFilterLabel();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => unawaited(_showViewSwitcherSheet()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<T?> _showBookshelfBottomSheet<T>({
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: isScrollControlled,
      builder: builder,
    );
  }

  void _dismissBookshelfBottomSheet<T>(BuildContext context, [T? result]) {
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  double _bookshelfBottomSafeInset(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context).bottom;
    return math.max(viewPadding, gestureInsets);
  }

  Future<void> _showViewSwitcherSheet() async {
    if (_isBatchDeleting || !mounted) {
      return;
    }

    final baseFilterBookCount = <_BookshelfFilter, int>{
      _BookshelfFilter.all: _books.length,
      _BookshelfFilter.local:
          _books
              .where(
                (book) =>
                    _bookMatchesStaticFilter(book, _BookshelfFilter.local),
              )
              .length,
      _BookshelfFilter.novel:
          _books
              .where(
                (book) =>
                    _bookMatchesStaticFilter(book, _BookshelfFilter.novel),
              )
              .length,
      _BookshelfFilter.manga:
          _books
              .where(
                (book) =>
                    _bookMatchesStaticFilter(book, _BookshelfFilter.manga),
              )
              .length,
    };
    final tagBookCount = _buildTagBookCount();
    final categoryBookCount = _buildCategoryBookCount();
    final customTags = _userTags;
    final customCategories = _userCategories;
    final uncategorizedCount =
        _books.where((book) => (_categoryOfBook(book) ?? '').isEmpty).length;

    final selected = await _showBookshelfBottomSheet<String>(
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
        final bottomInset = _bookshelfBottomSafeInset(sheetContext);
        var searchKeyword = '';
        var expandCategories = false;
        var expandTags = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final colorScheme = Theme.of(sheetContext).colorScheme;
            final textTheme = Theme.of(sheetContext).textTheme;

            Widget buildSectionTitle(String title) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            Widget buildOptionTile({
              required String value,
              required String label,
              required String countText,
              required bool selected,
              VoidCallback? onTap,
              IconData? icon,
              String? subtitle,
            }) {
              return Material(
                color:
                    selected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.36)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap:
                      onTap ??
                      () => _dismissBookshelfBottomSheet(sheetContext, value),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 18,
                            color:
                                selected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  color:
                                      selected
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurface,
                                  fontWeight:
                                      selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                              ),
                              if (subtitle != null && subtitle.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          countText,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (selected)
                          Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            bool matchesKeyword(String value) {
              final keyword = searchKeyword.trim().toLowerCase();
              if (keyword.isEmpty) {
                return true;
              }
              return value.toLowerCase().contains(keyword);
            }

            final visibleCategories = customCategories
                .where(matchesKeyword)
                .toList(growable: false);
            final visibleTags = customTags
                .where(matchesKeyword)
                .toList(growable: false);
            final effectiveVisibleCategories =
                searchKeyword.trim().isNotEmpty || expandCategories
                    ? visibleCategories
                    : visibleCategories.take(6).toList(growable: false);
            final effectiveVisibleTags =
                searchKeyword.trim().isNotEmpty || expandTags
                    ? visibleTags
                    : visibleTags.take(6).toList(growable: false);

            return Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      child: TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '搜索分类或标签',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            searchKeyword = value;
                          });
                        },
                      ),
                    ),
                    buildSectionTitle('默认'),
                    buildOptionTile(
                      value: 'all',
                      label: '书架',
                      countText:
                          '${baseFilterBookCount[_BookshelfFilter.all] ?? 0}',
                      selected:
                          !_activeView.isTag &&
                          !_activeView.isCategory &&
                          _activeView.filter == _BookshelfFilter.all,
                      icon: Icons.collections_bookmark_outlined,
                    ),
                    buildOptionTile(
                      value: 'local',
                      label: '本地',
                      countText:
                          '${baseFilterBookCount[_BookshelfFilter.local] ?? 0}',
                      selected:
                          !_activeView.isTag &&
                          !_activeView.isCategory &&
                          _activeView.filter == _BookshelfFilter.local,
                      icon: Icons.folder_outlined,
                    ),
                    buildOptionTile(
                      value: 'novel',
                      label: '小说',
                      countText:
                          '${baseFilterBookCount[_BookshelfFilter.novel] ?? 0}',
                      selected:
                          !_activeView.isTag &&
                          !_activeView.isCategory &&
                          _activeView.filter == _BookshelfFilter.novel,
                      icon: Icons.menu_book_outlined,
                    ),
                    buildOptionTile(
                      value: 'manga',
                      label: '漫画',
                      countText:
                          '${baseFilterBookCount[_BookshelfFilter.manga] ?? 0}',
                      selected:
                          !_activeView.isTag &&
                          !_activeView.isCategory &&
                          _activeView.filter == _BookshelfFilter.manga,
                      icon: Icons.photo_library_outlined,
                    ),
                    buildSectionTitle('分类'),
                    if (matchesKeyword('未分类'))
                      buildOptionTile(
                        value: 'category::__uncategorized__',
                        label: '未分类',
                        countText: '$uncategorizedCount',
                        selected: _activeView.isUncategorized,
                        icon: Icons.folder_off_outlined,
                      ),
                    ...effectiveVisibleCategories.map(
                      (category) => buildOptionTile(
                        value: 'category::$category',
                        label: category,
                        countText: '${categoryBookCount[category] ?? 0}',
                        selected:
                            _activeView.isCategory &&
                            _activeView.category == category,
                        icon: Icons.folder_copy_outlined,
                      ),
                    ),
                    if (searchKeyword.trim().isEmpty &&
                        visibleCategories.length > 6)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                expandCategories = !expandCategories;
                              });
                            },
                            icon: Icon(
                              expandCategories
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                            ),
                            label: Text(expandCategories ? '收起分类' : '展开全部分类'),
                          ),
                        ),
                      ),
                    if (visibleTags.isNotEmpty || matchesKeyword('未打标签')) ...[
                      buildSectionTitle('标签'),
                      if (matchesKeyword('未打标签'))
                        buildOptionTile(
                          value: 'tag::__untagged__',
                          label: '未打标签',
                          countText:
                              '${_books.where((book) => _tagsOfBook(book).isEmpty).length}',
                          selected: _activeView.isTag && _activeView.tag == '',
                          icon: Icons.sell_outlined,
                        ),
                      ...effectiveVisibleTags.map(
                        (tag) => buildOptionTile(
                          value: 'tag::$tag',
                          label: tag,
                          countText: '${tagBookCount[tag] ?? 0}',
                          selected: _activeView.isTag && _activeView.tag == tag,
                          icon: Icons.sell_outlined,
                        ),
                      ),
                      if (searchKeyword.trim().isEmpty &&
                          visibleTags.length > 6)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setSheetState(() {
                                  expandTags = !expandTags;
                                });
                              },
                              icon: Icon(
                                expandTags
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                              ),
                              label: Text(expandTags ? '收起标签' : '展开全部标签'),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    if (selected.startsWith('tag::')) {
      final tag = selected.substring(5).trim();
      if (tag.isNotEmpty) {
        _activateView(_BookshelfViewSelection.tag(tag));
      }
      return;
    }
    if (selected == 'category::__uncategorized__') {
      _activateView(const _BookshelfViewSelection.category(null));
      return;
    }
    if (selected.startsWith('category::')) {
      final category = selected.substring(10).trim();
      if (category.isNotEmpty) {
        _activateView(_BookshelfViewSelection.category(category));
      }
      return;
    }

    switch (selected) {
      case 'all':
        _activateView(const _BookshelfViewSelection.base(_BookshelfFilter.all));
        break;
      case 'local':
        _activateView(
          const _BookshelfViewSelection.base(_BookshelfFilter.local),
        );
        break;
      case 'novel':
        _activateView(
          const _BookshelfViewSelection.base(_BookshelfFilter.novel),
        );
        break;
      case 'manga':
        _activateView(
          const _BookshelfViewSelection.base(_BookshelfFilter.manga),
        );
        break;
      default:
        break;
    }
  }

  Widget _buildSelectionActionBar({
    required List<BookshelfBook> filteredBooks,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedCount = _selectedBookKeys.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '已选 $selectedCount / ${filteredBooks.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isBatchDeleting || filteredBooks.isEmpty
                                ? null
                                : _selectAllBooks,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.select_all_rounded),
                        label: const Text('全选'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _isBatchDeleting || _selectedBookKeys.isEmpty
                                ? null
                                : _deleteSelectedBooks,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('删除'),
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

  Widget _buildBookGridSliver(List<BookshelfBook> books) {
    return BookshelfGridSliver(
      itemCount: books.length,
      fixedCrossAxisCount: _gridAdaptiveColumns ? null : _gridColumnCount,
      crossSpacing: _gridCrossSpacing,
      mainSpacing: _gridMainSpacing,
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildModeSwitchAnimatedBookItem(
          book: book,
          index: index,
          totalCount: books.length,
          child: _buildGridCard(book),
        );
      },
    );
  }

  Widget _buildModeSwitchAnimatedBookItem({
    required BookshelfBook book,
    required int index,
    required int totalCount,
    required Widget child,
  }) {
    if (totalCount > _kBooksModeSwitchDisableThreshold ||
        index >= _kBooksModeSwitchAnimatedItemLimit) {
      return RepaintBoundary(
        key: ValueKey<String>(
          'bookshelf_static_${_useGridView ? 'grid' : 'list'}_${book.bookId}',
        ),
        child: child,
      );
    }

    final delay =
        (index % _kBooksModeSwitchStaggerGroup) * _kBooksModeSwitchStaggerStep;
    final begin = delay.clamp(0.0, 1 - _kBooksModeSwitchCurveSpan);
    final end = begin + _kBooksModeSwitchCurveSpan;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>(
          'bookshelf_mode_${_useGridView ? 'grid' : 'list'}_${book.bookId}',
        ),
        tween: Tween<double>(begin: 0, end: 1),
        duration: _kBooksModeSwitchItemDuration,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
        child: child,
        builder: (context, value, builtChild) {
          final translateY = (1 - value) * 16;
          final scale = 0.986 + (0.014 * value);
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                alignment: Alignment.topCenter,
                scale: scale,
                child: builtChild,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridCard(BookshelfBook book) {
    final bookKey = _bookKey(book);
    final progress = _progressByBookKey[bookKey];
    final localBook = _bookshelfLocalBook(book);
    final progressDisplay = _resolveBookshelfProgressDisplay(
      book,
      progress: progress,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final palette = _resolvedPalette(context);
    final isOpening = _openingBookId == book.bookId;
    final isSelected = _isBookSelected(book);
    final displayTitle = _displayBookTitle(book, localBook: localBook);
    final displayAuthor = _displayBookAuthor(book, localBook: localBook);
    final titleText = _toSingleLineText(displayTitle);
    final authorText = _toSingleLineText(displayAuthor ?? '');
    final latestChapterText = _toSingleLineText(
      _latestCachedChapterByBookKey[bookKey] ?? book.latestChapter ?? '',
    );
    final authorLine = authorText.isNotEmpty ? '作者: $authorText' : '作者: 未知';
    final latestLine =
        latestChapterText.isNotEmpty ? '最新: $latestChapterText' : '最新: 暂无缓存章节';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress:
            _isBatchDeleting
                ? null
                : () {
                  if (_isSelectionMode) {
                    _toggleBookSelection(book);
                    return;
                  }
                  unawaited(_showBookActionSheet(book));
                },
        onTap:
            _isSelectionMode
                ? () => _toggleBookSelection(book)
                : isOpening || _isBatchDeleting
                ? null
                : () async {
                  await _openFromBookshelf(book, progress: progress);
                },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _buildCover(
                            realCoverUrl: book.coverUrl,
                            customCoverPath: localBook?.coverPath,
                            title: displayTitle,
                            author: displayAuthor,
                            bookId: book.bookId,
                            sourceId: book.sourceId,
                            detailUrl: book.detailUrl,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                          );
                        },
                      ),
                    ),
                    if (!_isSelectionMode)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _buildSourceBadge(book, compact: true),
                      ),
                    if (isOpening)
                      Positioned(
                        left: 6,
                        right: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.scrim.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '打开中',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_isSelectionMode)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _toggleBookSelection(book),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? colorScheme.primary
                                      : palette.cardColor.withValues(
                                        alpha: 0.9,
                                      ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    isSelected
                                        ? colorScheme.primary
                                        : palette.cardBorderColor.withValues(
                                          alpha: 0.7,
                                        ),
                              ),
                            ),
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color:
                                  isSelected
                                      ? colorScheme.onPrimary
                                      : palette.textSecondaryColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_gridShowTitle ||
                  _gridShowAuthor ||
                  _gridShowLatestChapter ||
                  _gridShowProgressBar)
                const SizedBox(height: 6),
              if (_gridShowTitle) ...[
                Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_gridShowAuthor) ...[
                SizedBox(height: _gridShowTitle ? 2 : 0),
                Text(
                  authorLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (_gridShowLatestChapter) ...[
                SizedBox(height: (_gridShowTitle || _gridShowAuthor) ? 1 : 0),
                Text(
                  latestLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.textSecondaryColor,
                  ),
                ),
              ],
              if (_gridShowProgressBar) ...[
                SizedBox(
                  height:
                      (_gridShowTitle ||
                              _gridShowAuthor ||
                              _gridShowLatestChapter)
                          ? 4
                          : 0,
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progressDisplay.progressValue,
                    minHeight: 3,
                    backgroundColor: palette.elevatedSurfaceColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookCard(BookshelfBook book) {
    final bookKey = _bookKey(book);
    final progress = _progressByBookKey[bookKey];
    final localBook = _bookshelfLocalBook(book);
    final progressDisplay = _resolveBookshelfProgressDisplay(
      book,
      progress: progress,
    );
    final palette = _resolvedPalette(context);
    final isOpening = _openingBookId == book.bookId;
    final isSelected = _isBookSelected(book);
    final displayTitle = _displayBookTitle(book, localBook: localBook);
    final displayAuthor = _displayBookAuthor(book, localBook: localBook);
    final titleText = _toSingleLineText(displayTitle);
    final authorText = _toSingleLineText(displayAuthor ?? '');
    final latestChapterText = _toSingleLineText(
      _latestCachedChapterByBookKey[bookKey] ?? book.latestChapter ?? '',
    );
    final authorLine = authorText.isNotEmpty ? '作者: $authorText' : '作者: 未知';
    final latestLine =
        latestChapterText.isNotEmpty ? '最新: $latestChapterText' : '最新: 暂无章节';
    final progressLine = progressDisplay.summaryText;
    final isEditingSelected = _isSelectionMode && isSelected;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color:
          isEditingSelected
              ? palette.noticeSurfaceColor.withValues(alpha: 0.34)
              : palette.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color:
              isEditingSelected
                  ? palette.noticeAccentColor.withValues(alpha: 0.38)
                  : palette.cardBorderColor.withValues(alpha: 0.56),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            _isSelectionMode
                ? () => _toggleBookSelection(book)
                : isOpening || _isBatchDeleting
                ? null
                : () async {
                  await _openFromBookshelf(book, progress: progress);
                },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: _buildListSelectionIndicator(
                    selected: isSelected,
                    onTap: () => _toggleBookSelection(book),
                  ),
                ),
              InkResponse(
                onLongPress:
                    _isBatchDeleting
                        ? null
                        : () {
                          if (_isSelectionMode) {
                            _toggleBookSelection(book);
                            return;
                          }
                          unawaited(_showBookActionSheet(book));
                        },
                containedInkWell: true,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 68,
                  height: 96,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildCover(
                          realCoverUrl: book.coverUrl,
                          customCoverPath: localBook?.coverPath,
                          title: displayTitle,
                          author: displayAuthor,
                          bookId: book.bookId,
                          sourceId: book.sourceId,
                          detailUrl: book.detailUrl,
                          width: 68,
                          height: 96,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _buildSourceBadge(book, compact: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress:
                      _isBatchDeleting
                          ? null
                          : () {
                            if (_isSelectionMode) {
                              _toggleBookSelection(book);
                              return;
                            }
                            unawaited(_showBookActionSheet(book));
                          },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_listShowTitle)
                            Expanded(
                              child: Text(
                                titleText,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else
                            const Spacer(),
                          if (!_isSelectionMode) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  isOpening
                                      ? const CircularProgressIndicator(
                                        strokeWidth: 1.9,
                                      )
                                      : Container(
                                        decoration: BoxDecoration(
                                          color: palette.elevatedSurfaceColor,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: palette.textSecondaryColor,
                                        ),
                                      ),
                            ),
                          ],
                        ],
                      ),
                      if (_listShowAuthor) ...[
                        const SizedBox(height: 6),
                        Text(
                          authorLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: palette.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (_listShowLatestChapter) ...[
                        SizedBox(height: _listShowAuthor ? 4 : 6),
                        Text(
                          latestLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: palette.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        progressLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              progressDisplay.hasProgress
                                  ? palette.primaryColor
                                  : palette.textSecondaryColor,
                          fontWeight:
                              progressDisplay.hasProgress
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                        ),
                      ),
                      if (_listShowProgressBar) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progressDisplay.progressValue,
                            minHeight: 3,
                            backgroundColor: palette.elevatedSurfaceColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListSelectionIndicator({
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color:
                  selected
                      ? colorScheme.primary
                      : colorScheme.surface.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    selected
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.68),
              ),
            ),
            child: Icon(
              Icons.check,
              size: 14,
              color:
                  selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  String _bookKey(BookshelfBook book) {
    return '${book.sourceId}::${book.detailUrl}';
  }

  bool _isBookSelected(BookshelfBook book) {
    return _selectedBookKeys.contains(_bookKey(book));
  }

  List<BookshelfBook> get _filteredBooks {
    _ensureDerivedBookshelfState();
    return _filteredBooksCache;
  }

  bool _bookMatchesView(BookshelfBook book, _BookshelfViewSelection view) {
    switch (view.kind) {
      case _BookshelfViewKind.base:
        return _bookMatchesStaticFilter(book, view.filter);
      case _BookshelfViewKind.tag:
        final tag = view.tag;
        if (tag == null) {
          return true;
        }
        if (tag.isEmpty) {
          return _tagsOfBook(book).isEmpty;
        }
        return _tagsOfBook(book).contains(tag);
      case _BookshelfViewKind.category:
        final category = view.category;
        if (category == null || category.isEmpty) {
          return _categoryOfBook(book) == null;
        }
        return _categoryOfBook(book) == category;
    }
  }

  bool _bookMatchesSearchKeyword(BookshelfBook book, String keyword) {
    if (keyword.isEmpty) {
      return true;
    }

    final localBook = _bookshelfLocalBook(book);
    final bookKey = _bookKey(book);
    final candidates = <String>[
      _displayBookTitle(book, localBook: localBook),
      _displayBookAuthor(book, localBook: localBook) ?? '',
      _categoryOfBook(book) ?? book.category ?? '',
      _latestCachedChapterByBookKey[bookKey] ?? book.latestChapter ?? '',
      ..._tagsOfBook(book),
    ];

    return candidates.any(
      (candidate) => _normalizeBookshelfSearchText(candidate).contains(keyword),
    );
  }

  bool _bookMatchesStaticFilter(BookshelfBook book, _BookshelfFilter filter) {
    switch (filter) {
      case _BookshelfFilter.all:
        return true;
      case _BookshelfFilter.local:
        return book.sourceId == _kLocalBookSourceId;
      case _BookshelfFilter.manga:
        return book.sourceId != _kLocalBookSourceId &&
            (_sourceTypeBySourceId[book.sourceId] ?? 0) == 2;
      case _BookshelfFilter.novel:
        return book.sourceId != _kLocalBookSourceId &&
            (_sourceTypeBySourceId[book.sourceId] ?? 0) != 2;
      case _BookshelfFilter.custom:
        return false;
    }
  }

  List<String> get _userTags {
    _ensureDerivedBookshelfState();
    return _userTagsCache;
  }

  Map<String, int> _buildTagBookCount() {
    _ensureDerivedBookshelfState();
    return _tagBookCountCache;
  }

  Map<String, int> _buildCategoryBookCount() {
    _ensureDerivedBookshelfState();
    return _categoryBookCountCache;
  }

  List<String> get _userCategories {
    _ensureDerivedBookshelfState();
    return _userCategoriesCache;
  }

  void _ensureDerivedBookshelfState() {
    final searchKeyword = _normalizedBookshelfSearchKeyword;
    final fingerprint = Object.hash(
      _activeView,
      _sortMode,
      searchKeyword,
      identityHashCode(_books),
      identityHashCode(_progressByBookKey),
      identityHashCode(_latestCachedChapterByBookKey),
      identityHashCode(_cachedChapterCountByBookKey),
      identityHashCode(_sourceTypeBySourceId),
      identityHashCode(_localBooksById),
      identityHashCode(_bookTagsByKey),
      identityHashCode(_tagOrder),
      identityHashCode(_bookCategoriesByKey),
      identityHashCode(_categoryOrder),
      identityHashCode(_baseFilterOrder),
    );
    if (_derivedBookshelfFingerprint == fingerprint) {
      return;
    }

    final counts = <String, int>{};
    final categoryCounts = <String, int>{};
    for (final book in _books) {
      for (final tag in _tagsOfBook(book)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
      final category = _categoryOfBook(book);
      if (category != null && category.isNotEmpty) {
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
    }

    final tags = mergeBookshelfTaxonomyNames(counts: counts, order: _tagOrder);
    final categories = mergeBookshelfTaxonomyNames(
      counts: categoryCounts,
      order: _categoryOrder,
    );

    _tagBookCountCache = Map<String, int>.unmodifiable(counts);
    _categoryBookCountCache = Map<String, int>.unmodifiable(categoryCounts);
    _userTagsCache = List<String>.unmodifiable(tags);
    _userCategoriesCache = List<String>.unmodifiable(categories);
    final filteredBooks = _books
      .where(
        (book) =>
            _bookMatchesView(book, _activeView) &&
            _bookMatchesSearchKeyword(book, searchKeyword),
      )
      .toList(growable: true)..sort(_compareBookshelfBooks);
    _filteredBooksCache = List<BookshelfBook>.unmodifiable(filteredBooks);
    _derivedBookshelfFingerprint = fingerprint;
  }

  int _compareBookshelfBooks(BookshelfBook a, BookshelfBook b) {
    return switch (_sortMode) {
      _BookshelfSortMode.defaultOrder => _compareBookshelfBooksDefault(a, b),
      _BookshelfSortMode.recentRead => _compareBookshelfBooksByRecentRead(a, b),
      _BookshelfSortMode.readingProgress => _compareBookshelfBooksByProgress(
        a,
        b,
      ),
      _BookshelfSortMode.createdAt => _compareBookshelfBooksByCreatedAt(a, b),
      _BookshelfSortMode.author => _compareBookshelfBooksByAuthor(a, b),
      _BookshelfSortMode.title => _compareBookshelfBooksByTitle(a, b),
    };
  }

  int _compareBookshelfBooksDefault(BookshelfBook a, BookshelfBook b) {
    final progressA = _progressByBookKey[_bookKey(a)];
    final progressB = _progressByBookKey[_bookKey(b)];
    if (progressA != null && progressB != null) {
      final compare = progressB.updatedAt.compareTo(progressA.updatedAt);
      if (compare != 0) {
        return compare;
      }
    } else if (progressA != null) {
      return -1;
    } else if (progressB != null) {
      return 1;
    }

    final addedCompare = b.addedAt.compareTo(a.addedAt);
    if (addedCompare != 0) {
      return addedCompare;
    }
    return _displayBookTitle(a).compareTo(_displayBookTitle(b));
  }

  int _compareBookshelfBooksByRecentRead(BookshelfBook a, BookshelfBook b) {
    final progressA = _progressByBookKey[_bookKey(a)];
    final progressB = _progressByBookKey[_bookKey(b)];
    if (progressA != null && progressB != null) {
      final compare = progressB.updatedAt.compareTo(progressA.updatedAt);
      if (compare != 0) {
        return compare;
      }
    } else if (progressA != null) {
      return -1;
    } else if (progressB != null) {
      return 1;
    }
    return _compareBookshelfBooksDefault(a, b);
  }

  int _compareBookshelfBooksByProgress(BookshelfBook a, BookshelfBook b) {
    final progressA =
        _progressByBookKey[_bookKey(a)]?.chapterPositionRatio ?? 0;
    final progressB =
        _progressByBookKey[_bookKey(b)]?.chapterPositionRatio ?? 0;
    final compare = progressB.compareTo(progressA);
    if (compare != 0) {
      return compare;
    }
    return _compareBookshelfBooksByRecentRead(a, b);
  }

  int _compareBookshelfBooksByCreatedAt(BookshelfBook a, BookshelfBook b) {
    final createdCompare = b.addedAt.compareTo(a.addedAt);
    if (createdCompare != 0) {
      return createdCompare;
    }
    return _displayBookTitle(a).compareTo(_displayBookTitle(b));
  }

  int _compareBookshelfBooksByAuthor(BookshelfBook a, BookshelfBook b) {
    final authorA = (_displayBookAuthor(a) ?? '').trim();
    final authorB = (_displayBookAuthor(b) ?? '').trim();
    if (authorA.isNotEmpty && authorB.isNotEmpty) {
      final compare = authorA.compareTo(authorB);
      if (compare != 0) {
        return compare;
      }
    } else if (authorA.isNotEmpty) {
      return -1;
    } else if (authorB.isNotEmpty) {
      return 1;
    }
    return _compareBookshelfBooksByTitle(a, b);
  }

  int _compareBookshelfBooksByTitle(BookshelfBook a, BookshelfBook b) {
    final compare = _displayBookTitle(a).compareTo(_displayBookTitle(b));
    if (compare != 0) {
      return compare;
    }
    return _compareBookshelfBooksByCreatedAt(a, b);
  }

  List<String> _tagsOfBook(BookshelfBook book) {
    return _bookTagsByKey[_bookKey(book)] ?? const <String>[];
  }

  String? _categoryOfBook(BookshelfBook book) {
    return _bookCategoriesByKey[_bookKey(book)];
  }

  String _filterLabel(_BookshelfFilter filter) {
    switch (filter) {
      case _BookshelfFilter.all:
        return '全部';
      case _BookshelfFilter.local:
        return '本地';
      case _BookshelfFilter.novel:
        return '小说';
      case _BookshelfFilter.manga:
        return '漫画';
      case _BookshelfFilter.custom:
        return _activeView.tag ?? '标签';
    }
  }

  String _activeFilterLabel() {
    if (_activeView.isTag) {
      final tag = _activeView.tag;
      if (tag == null || tag.isEmpty) {
        return '未打标签';
      }
      return tag;
    }
    if (_activeView.isCategory) {
      final category = _activeView.category;
      if (category == null || category.isEmpty) {
        return '未分类';
      }
      return category;
    }
    return _filterLabel(_activeView.filter);
  }

  void _activateView(_BookshelfViewSelection view) {
    setState(() {
      _activeView = view;
      if (_isSelectionMode) {
        _isSelectionMode = false;
        _selectedBookKeys.clear();
      }
    });
    unawaited(_persistViewSelection(view));
  }

  Future<void> _persistViewSelection(_BookshelfViewSelection view) async {
    switch (view.kind) {
      case _BookshelfViewKind.base:
        final kind = switch (view.filter) {
          _BookshelfFilter.local => 'local',
          _BookshelfFilter.novel => 'novel',
          _BookshelfFilter.manga => 'manga',
          _BookshelfFilter.all || _BookshelfFilter.custom => 'all',
        };
        await _bookshelfService.saveViewSelection(kind: kind);
      case _BookshelfViewKind.tag:
        await _bookshelfService.saveViewSelection(kind: 'tag', value: view.tag);
      case _BookshelfViewKind.category:
        await _bookshelfService.saveViewSelection(
          kind: 'category',
          value: view.category,
        );
    }
  }

  List<String> _normalizeTags(Iterable<String> values) {
    final result = <String>[];
    for (final raw in values) {
      var value = _toSingleLineText(raw);
      if (value.startsWith('#')) {
        value = value.substring(1).trim();
      }
      if (value.isEmpty) {
        continue;
      }
      if (value.length > 12) {
        value = value.substring(0, 12).trim();
      }
      if (value.isEmpty) {
        continue;
      }
      if (!result.contains(value)) {
        result.add(value);
      }
    }
    return result;
  }

  String? _coverUrlCompareKey(String? url) {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return normalized;
    }

    final query = Map<String, String>.from(uri.queryParameters);
    if (!query.containsKey('x-signature') && !query.containsKey('x-expires')) {
      return normalized;
    }

    query.remove('x-signature');
    query.remove('x-expires');
    return uri
        .replace(queryParameters: query.isEmpty ? null : query)
        .toString();
  }

  void _ensureFilterStillValid() {
    if ((_activeView.isTag || _activeView.isCategory) &&
        !_bookshelfMetadataReady) {
      return;
    }
    var shouldReset = false;
    if (_activeView.isTag) {
      final tag = _activeView.tag;
      shouldReset = tag == null || !_userTags.contains(tag);
    } else if (_activeView.isCategory && !_activeView.isUncategorized) {
      final category = _activeView.category;
      shouldReset = category == null || !_userCategories.contains(category);
    }
    if (shouldReset) {
      _activeView = const _BookshelfViewSelection.base(_BookshelfFilter.all);
      if (_isSelectionMode) {
        _isSelectionMode = false;
        _selectedBookKeys.clear();
      }
    }
  }

  void _startSelectionMode() {
    if (_isBatchDeleting || _filteredBooks.isEmpty) {
      return;
    }
    setState(() {
      _isSelectionMode = true;
      _selectedBookKeys.clear();
    });
  }

  void _enterSelectionMode(BookshelfBook book) {
    if (_isBatchDeleting) {
      return;
    }

    if (_isSelectionMode) {
      _toggleBookSelection(book);
      return;
    }

    final key = _bookKey(book);
    setState(() {
      _isSelectionMode = true;
      _selectedBookKeys
        ..clear()
        ..add(key);
    });
  }

  void _toggleBookSelection(BookshelfBook book) {
    if (!_isSelectionMode || _isBatchDeleting) {
      return;
    }

    final key = _bookKey(book);
    setState(() {
      if (_selectedBookKeys.contains(key)) {
        _selectedBookKeys.remove(key);
      } else {
        _selectedBookKeys.add(key);
      }

      if (_selectedBookKeys.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  Future<void> _showBookActionSheet(BookshelfBook book) async {
    if (_isBatchDeleting || !mounted) {
      return;
    }
    final bookKey = _bookKey(book);
    final progress = _progressByBookKey[bookKey];
    final localBook = _bookshelfLocalBook(book);
    final displayTitle = _displayBookTitle(book, localBook: localBook);
    final displayAuthor = _displayBookAuthor(book, localBook: localBook);
    final localStatusText =
        localBook == null ? null : _localBookStatusActionText(localBook);
    final canRepairLocalBook =
        localBook != null && _canRepairLocalBookFromShelf(localBook);
    final latestChapter = _toSingleLineText(
      _latestCachedChapterByBookKey[bookKey] ?? book.latestChapter ?? '',
    );
    final author = _toSingleLineText(displayAuthor ?? '');
    final authorLine = author.isNotEmpty ? '作者: $author' : '作者: 未知';
    final latestLine =
        latestChapter.isNotEmpty ? '最新: $latestChapter' : '最新: 暂无缓存章节';
    final selected = await _showBookshelfBottomSheet<_BookshelfSheetAction>(
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final horizontal = AppSpacing.pageHorizontal(sheetContext);
        final bottomInset = _bookshelfBottomSafeInset(sheetContext);
        final progressDisplay = _resolveBookshelfProgressDisplay(
          book,
          progress: progress,
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            4,
            horizontal,
            10 + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 88),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCover(
                        realCoverUrl: book.coverUrl,
                        customCoverPath: localBook?.coverPath,
                        title: displayTitle,
                        author: displayAuthor,
                        bookId: book.bookId,
                        sourceId: book.sourceId,
                        detailUrl: book.detailUrl,
                        width: 56,
                        height: 82,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _toSingleLineText(displayTitle),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                authorLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                latestLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (localStatusText != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  localStatusText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    sheetContext,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: _localStatusTextColor(
                                      colorScheme,
                                      localBook,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (progress != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: progressDisplay.progressValue,
                                          minHeight: 4,
                                          backgroundColor:
                                              colorScheme
                                                  .surfaceContainerHighest,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      progressDisplay.trailingLabel,
                                      style: Theme.of(
                                        sheetContext,
                                      ).textTheme.labelSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap:
                            () => Navigator.of(
                              sheetContext,
                              rootNavigator: true,
                            ).pop(_BookshelfSheetAction.detail),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '书籍详情',
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (canRepairLocalBook)
                    SizedBox(
                      width: 84,
                      child: _BookSheetActionButton(
                        icon: Icons.refresh_rounded,
                        label: '重建目录',
                        onTap:
                            () => Navigator.of(
                              sheetContext,
                              rootNavigator: true,
                            ).pop(_BookshelfSheetAction.repairLocal),
                      ),
                    ),
                  SizedBox(
                    width: 84,
                    child: _BookSheetActionButton(
                      icon: Icons.folder_copy_outlined,
                      label: '管理分类',
                      onTap:
                          () => Navigator.of(
                            sheetContext,
                            rootNavigator: true,
                          ).pop(_BookshelfSheetAction.category),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: _BookSheetActionButton(
                      icon: Icons.label_rounded,
                      label: '管理标签',
                      onTap:
                          () => Navigator.of(
                            sheetContext,
                            rootNavigator: true,
                          ).pop(_BookshelfSheetAction.tag),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: _BookSheetActionButton(
                      icon: Icons.image_outlined,
                      label: '自定义封面',
                      onTap:
                          () => Navigator.of(
                            sheetContext,
                            rootNavigator: true,
                          ).pop(_BookshelfSheetAction.customCover),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: _BookSheetActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: '删除',
                      onTap:
                          () => Navigator.of(
                            sheetContext,
                            rootNavigator: true,
                          ).pop(_BookshelfSheetAction.delete),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed:
                      () => _dismissBookshelfBottomSheet<void>(sheetContext),
                  child: const Text('取消'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    switch (selected) {
      case _BookshelfSheetAction.read:
        await _openFromBookshelf(book, progress: progress);
        break;
      case _BookshelfSheetAction.detail:
        _openBookDetail(book);
        break;
      case _BookshelfSheetAction.repairLocal:
        if (localBook != null) {
          await _repairLocalBookFromShelf(book, localBook);
        }
        break;
      case _BookshelfSheetAction.select:
        _enterSelectionMode(book);
        break;
      case _BookshelfSheetAction.category:
        await _showBookCategorySheet(book);
        break;
      case _BookshelfSheetAction.tag:
        await _showBookTagSheet(book);
        break;
      case _BookshelfSheetAction.customCover:
        await _pickAndApplyCustomCover(book);
        break;
      case _BookshelfSheetAction.delete:
        await _confirmAndRemoveBook(book);
        break;
    }
  }

  bool _canRepairLocalBookFromShelf(LocalBook localBook) {
    return localBook.indexStatus == LocalBookIndexStatus.pending ||
        localBook.indexStatus == LocalBookIndexStatus.indexing ||
        localBook.indexStatus == LocalBookIndexStatus.stale ||
        localBook.indexStatus == LocalBookIndexStatus.failed;
  }

  String? _localBookStatusActionText(LocalBook localBook) {
    return switch (localBook.indexStatus) {
      LocalBookIndexStatus.pending => '状态: 待建立目录，可在此直接触发解析',
      LocalBookIndexStatus.indexing => '状态: 正在解析，可继续等待或重新打开详情查看进度',
      LocalBookIndexStatus.stale => '状态: 目录需重建，建议先重建再阅读',
      LocalBookIndexStatus.failed =>
        localBook.lastError?.trim().isNotEmpty == true
            ? '状态: 解析失败，${_toSingleLineText(localBook.lastError!)}'
            : '状态: 解析失败，建议先重建目录',
      _ => null,
    };
  }

  Color _localStatusTextColor(ColorScheme colorScheme, LocalBook? localBook) {
    return switch (localBook?.indexStatus) {
      LocalBookIndexStatus.failed => colorScheme.error,
      LocalBookIndexStatus.stale => colorScheme.primary,
      LocalBookIndexStatus.pending => colorScheme.primary,
      LocalBookIndexStatus.indexing => colorScheme.tertiary,
      _ => colorScheme.onSurfaceVariant,
    };
  }

  Future<void> _showBookTagSheet(BookshelfBook book) async {
    await _showBookTagEditorSheet(book);
  }

  Future<void> _showBookCategorySheet(BookshelfBook book) async {
    await _showBookCategoryEditorSheet(book);
  }

  Future<void> _showBookCategoryEditorSheet(BookshelfBook book) async {
    final bookKey = _bookKey(book);
    var selectedCategory = _bookCategoriesByKey[bookKey];
    var availableCategories = _normalizeTags(<String>[
      ..._userCategories,
      if (selectedCategory != null && selectedCategory.trim().isNotEmpty)
        selectedCategory,
    ]);
    var createCategoryDraft = '';
    var createCategoryFieldVersion = 0;
    String? createCategoryErrorText;
    var showCreateCategoryInput = false;

    await _showBookshelfBottomSheet<void>(
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
        final bottomInset = _bookshelfBottomSafeInset(sheetContext);

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final colorScheme = Theme.of(sheetContext).colorScheme;
            final textTheme = Theme.of(sheetContext).textTheme;

            Future<void> saveSelectedCategory() async {
              final normalized = _normalizeTags([
                selectedCategory?.trim() ?? '',
              ]);
              final category = normalized.isEmpty ? null : normalized.first;
              try {
                await _bookshelfService.setBookCategory(
                  sourceId: book.sourceId,
                  detailUrl: book.detailUrl,
                  category: category,
                );
                if (category != null && !_userCategories.contains(category)) {
                  final nextOrder = _normalizeTags([
                    ..._categoryOrder,
                    category,
                  ]);
                  await _bookshelfService.saveCategoryOrder(nextOrder);
                }
                if (!mounted) {
                  return;
                }
                setState(() {
                  final nextCategories = Map<String, String>.from(
                    _bookCategoriesByKey,
                  );
                  if (category == null) {
                    nextCategories.remove(bookKey);
                  } else {
                    nextCategories[bookKey] = category;
                  }
                  _bookCategoriesByKey = nextCategories;
                  if (category != null && !_categoryOrder.contains(category)) {
                    _categoryOrder = _normalizeTags([
                      ..._categoryOrder,
                      category,
                    ]);
                  }
                  _ensureFilterStillValid();
                });
                if (!sheetContext.mounted) {
                  return;
                }
                Navigator.of(sheetContext, rootNavigator: true).pop();
                _showMessage(category == null ? '已清除分类。' : '分类已保存。');
              } catch (_) {
                if (!mounted) {
                  return;
                }
                _showMessage('分类保存失败，请重试。');
              }
            }

            Future<void> createCategoryInline() async {
              final normalized = _normalizeTags([createCategoryDraft]);
              if (normalized.isEmpty) {
                setSheetState(() {
                  createCategoryErrorText = '请输入分类名称';
                });
                return;
              }
              final nextCategory = normalized.first;
              if (availableCategories.contains(nextCategory)) {
                setSheetState(() {
                  createCategoryErrorText = '该分类已存在';
                });
                return;
              }
              setSheetState(() {
                availableCategories = _normalizeTags([
                  ...availableCategories,
                  nextCategory,
                ]);
                selectedCategory = nextCategory;
                createCategoryDraft = '';
                createCategoryErrorText = null;
                createCategoryFieldVersion += 1;
                showCreateCategoryInput = false;
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: Text(
                        '管理分类',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Material(
                      color:
                          selectedCategory == null
                              ? colorScheme.primaryContainer.withValues(
                                alpha: 0.36,
                              )
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setSheetState(() {
                            selectedCategory = null;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              const Expanded(child: Text('未分类')),
                              if (selectedCategory == null)
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (availableCategories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...availableCategories.map((category) {
                        final isSelected = selectedCategory == category;
                        return Material(
                          color:
                              isSelected
                                  ? colorScheme.secondaryContainer.withValues(
                                    alpha: 0.42,
                                  )
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setSheetState(() {
                                selectedCategory = category;
                              });
                            },
                            onLongPress:
                                () => unawaited(
                                  _showCategoryManageSheet(category),
                                ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: colorScheme.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ] else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Text(
                          '还没有分类，直接在下面新增一个即可。',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton.icon(
                        onPressed: () {
                          setSheetState(() {
                            showCreateCategoryInput = !showCreateCategoryInput;
                            createCategoryErrorText = null;
                            if (showCreateCategoryInput) {
                              createCategoryFieldVersion += 1;
                            }
                          });
                        },
                        icon: Icon(
                          showCreateCategoryInput
                              ? Icons.expand_less_rounded
                              : Icons.add_rounded,
                        ),
                        label: Text(
                          showCreateCategoryInput ? '收起新增分类' : '新增分类',
                        ),
                      ),
                    ),
                    if (showCreateCategoryInput) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: TextFormField(
                          key: ValueKey<String>(
                            'create_category_field_$createCategoryFieldVersion',
                          ),
                          initialValue: createCategoryDraft,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: '分类名称',
                            errorText: createCategoryErrorText,
                            suffixIcon: IconButton(
                              tooltip: '添加分类',
                              onPressed: createCategoryInline,
                              icon: const Icon(Icons.check_rounded),
                            ),
                          ),
                          onChanged: (value) {
                            createCategoryDraft = value;
                            if (createCategoryErrorText == null) {
                              return;
                            }
                            setSheetState(() {
                              createCategoryErrorText = null;
                            });
                          },
                          onFieldSubmitted: (_) => createCategoryInline(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: FilledButton(
                        onPressed: saveSelectedCategory,
                        child: const Text('保存分类'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCategoryManageSheet(String category) async {
    if (!mounted) {
      return;
    }
    final selected =
        await _showBookshelfBottomSheet<_BookshelfCategorySheetAction>(
          builder: (sheetContext) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                0,
                8,
                10 + _bookshelfBottomSafeInset(sheetContext),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('重命名分类'),
                    subtitle: Text(category),
                    onTap:
                        () => Navigator.of(
                          sheetContext,
                          rootNavigator: true,
                        ).pop(_BookshelfCategorySheetAction.rename),
                  ),
                  ListTile(
                    title: Text(
                      '删除分类',
                      style: TextStyle(
                        color: Theme.of(sheetContext).colorScheme.error,
                      ),
                    ),
                    subtitle: Text(category),
                    onTap:
                        () => Navigator.of(
                          sheetContext,
                          rootNavigator: true,
                        ).pop(_BookshelfCategorySheetAction.delete),
                  ),
                ],
              ),
            );
          },
        );
    if (!mounted || selected == null) {
      return;
    }
    switch (selected) {
      case _BookshelfCategorySheetAction.rename:
        await _renameCategory(category);
      case _BookshelfCategorySheetAction.delete:
        await _deleteCategory(category);
    }
  }

  Future<void> _renameCategory(String category) async {
    final nextCategory = await _showTagNameDialog(
      context,
      title: '重命名分类',
      confirmText: '保存',
      hintText: '输入新的分类名称',
      existingTags: _userCategories.toSet(),
      initialValue: category,
      originalTag: category,
    );
    if (!mounted || nextCategory == null || nextCategory == category) {
      return;
    }

    try {
      final affectedCount = await _bookshelfService.renameCategory(
        fromCategory: category,
        toCategory: nextCategory,
      );
      if (!mounted) {
        return;
      }
      if (affectedCount <= 0) {
        _showMessage('未找到可重命名的分类。');
        return;
      }
      setState(() {
        final nextMap = <String, String>{};
        for (final entry in _bookCategoriesByKey.entries) {
          final value = entry.value == category ? nextCategory : entry.value;
          if (value.isNotEmpty) {
            nextMap[entry.key] = value;
          }
        }
        _bookCategoriesByKey = nextMap;
        _categoryOrder = _normalizeTags(
          _categoryOrder.map(
            (value) => value == category ? nextCategory : value,
          ),
        );
        if (_activeView.isCategory && _activeView.category == category) {
          _activeView = _BookshelfViewSelection.category(nextCategory);
        }
        _ensureFilterStillValid();
      });
      _showMessage('分类已重命名为 $nextCategory。');
    } catch (_) {
      _showMessage('重命名失败，请重试。');
    }
  }

  Future<void> _deleteCategory(String category) async {
    final bindCount =
        _bookCategoriesByKey.values.where((value) => value == category).length;
    final confirmed = await _showConfirmDialog(
      title: '删除分类',
      content:
          bindCount > 0
              ? '确定删除分类 $category 吗？会从 $bindCount 本书中移除。'
              : '确定删除分类 $category 吗？',
      confirmText: '删除',
    );
    if (!mounted || confirmed != true) {
      return;
    }

    try {
      final affectedCount = await _bookshelfService.deleteCategory(category);
      if (!mounted) {
        return;
      }
      if (affectedCount <= 0) {
        _showMessage('分类已不存在。');
        return;
      }
      setState(() {
        final nextMap = <String, String>{};
        for (final entry in _bookCategoriesByKey.entries) {
          if (entry.value != category) {
            nextMap[entry.key] = entry.value;
          }
        }
        _bookCategoriesByKey = nextMap;
        _categoryOrder =
            _categoryOrder.where((value) => value != category).toList();
        _ensureFilterStillValid();
      });
      _showMessage('已删除分类 $category。');
    } catch (_) {
      _showMessage('删除分类失败，请重试。');
    }
  }

  Future<void> _showBookTagEditorSheet(BookshelfBook book) async {
    final bookKey = _bookKey(book);
    var selectedTags = List<String>.from(
      _bookTagsByKey[bookKey] ?? const <String>[],
    );
    var availableTags = _normalizeTags(<String>[..._userTags, ...selectedTags]);
    var createTagDraft = '';
    var createTagFieldVersion = 0;
    String? createTagErrorText;
    var showCreateTagInput = availableTags.isEmpty;

    final selected = await _showBookshelfBottomSheet<List<String>>(
      isScrollControlled: true,
      builder: (sheetContext) {
        final horizontal = AppSpacing.pageHorizontal(sheetContext);
        final bottomInset = math.max(
          MediaQuery.viewInsetsOf(sheetContext).bottom,
          _bookshelfBottomSafeInset(sheetContext),
        );
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.76;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void toggleCreateTagInput() {
              setSheetState(() {
                showCreateTagInput = !showCreateTagInput;
                createTagErrorText = null;
                if (!showCreateTagInput) {
                  createTagDraft = '';
                  createTagFieldVersion += 1;
                }
              });
            }

            bool commitPendingTagDraft() {
              final normalized = _normalizeTags([createTagDraft]);
              if (normalized.isEmpty) {
                return true;
              }

              final created = normalized.first;
              if (availableTags.contains(created)) {
                setSheetState(() {
                  createTagErrorText = '该标签已存在';
                  showCreateTagInput = true;
                });
                return false;
              }

              setSheetState(() {
                availableTags = _normalizeTags(<String>[
                  ...availableTags,
                  created,
                ]);
                selectedTags = _normalizeTags(<String>[
                  ...selectedTags,
                  created,
                ]);
                createTagDraft = '';
                createTagFieldVersion += 1;
                createTagErrorText = null;
                showCreateTagInput = false;
              });
              return true;
            }

            void createTagInline() {
              final hasDraft = _normalizeTags([createTagDraft]).isNotEmpty;
              if (!hasDraft) {
                setSheetState(() {
                  createTagErrorText = '请输入标签名称';
                  showCreateTagInput = true;
                });
                return;
              }
              final ok = commitPendingTagDraft();
              if (!ok) {
                return;
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                4,
                horizontal,
                12 + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '管理标签',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _toSingleLineText(_displayBookTitle(book)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        sheetContext,
                      ).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Text(
                            '标签',
                            style: Theme.of(sheetContext).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (availableTags.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(
                                      sheetContext,
                                    ).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '还没有标签，直接在下面新增一个即可。',
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        sheetContext,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: availableTags
                                  .map((tag) {
                                    final selected = selectedTags.contains(tag);
                                    return FilterChip(
                                      label: Text(tag),
                                      selected: selected,
                                      onSelected: (enabled) {
                                        setSheetState(() {
                                          if (enabled) {
                                            if (!selectedTags.contains(tag)) {
                                              selectedTags = _normalizeTags(
                                                <String>[...selectedTags, tag],
                                              );
                                            }
                                          } else {
                                            selectedTags = selectedTags
                                                .where((value) => value != tag)
                                                .toList(growable: false);
                                          }
                                        });
                                      },
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: toggleCreateTagInput,
                              icon: Icon(
                                showCreateTagInput
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.add_rounded,
                              ),
                              label: Text(
                                showCreateTagInput ? '收起新增标签' : '新增标签',
                              ),
                            ),
                          ),
                          if (showCreateTagInput) ...[
                            const SizedBox(height: 6),
                            TextFormField(
                              key: ValueKey<String>(
                                'create_tag_field_$createTagFieldVersion',
                              ),
                              initialValue: createTagDraft,
                              autofocus: true,
                              maxLength: 12,
                              decoration: InputDecoration(
                                labelText: '标签名称',
                                hintText: '例如：在读 / 已完结',
                                errorText: createTagErrorText,
                                suffixIcon: IconButton(
                                  tooltip: '添加标签',
                                  onPressed: createTagInline,
                                  icon: const Icon(Icons.check_rounded),
                                ),
                              ),
                              onChanged: (value) {
                                createTagDraft = value;
                                if (createTagErrorText == null) {
                                  return;
                                }
                                setSheetState(() {
                                  createTagErrorText = null;
                                });
                              },
                              onFieldSubmitted: (_) => createTagInline(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                () => _dismissBookshelfBottomSheet<void>(
                                  sheetContext,
                                ),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final canSave =
                                  !showCreateTagInput ||
                                  commitPendingTagDraft();
                              if (!canSave) {
                                return;
                              }
                              _dismissBookshelfBottomSheet(
                                sheetContext,
                                _normalizeTags(selectedTags),
                              );
                            },
                            child: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    final normalizedTags = _normalizeTags(selected);
    final previous = _bookTagsByKey[bookKey] ?? const <String>[];
    final unchanged =
        previous.length == normalizedTags.length &&
        previous.every((tag) => normalizedTags.contains(tag));
    if (unchanged) {
      return;
    }

    try {
      await _bookshelfService.setBookTags(
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
        tags: normalizedTags,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final next = Map<String, List<String>>.from(_bookTagsByKey);
        if (normalizedTags.isEmpty) {
          next.remove(bookKey);
        } else {
          next[bookKey] = normalizedTags;
        }
        _bookTagsByKey = next;
        _ensureFilterStillValid();
      });
      _showMessage(normalizedTags.isEmpty ? '已清除标签。' : '标签已保存。');
    } catch (_) {
      _showMessage('标签保存失败，请重试。');
    }
  }

  Future<void> _pickAndApplyCustomCover(BookshelfBook book) async {
    try {
      final picked = await _imageSelectionService.pickImage(
        confirmButtonText: '选择封面',
        allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp', 'gif'},
      );
      if (!mounted || picked == null) {
        return;
      }

      final storedCoverUri = await _persistCustomCover(book, picked);
      if (storedCoverUri == null) {
        _showMessage('封面保存失败，请重试。');
        return;
      }

      await _bookshelfService.upsert(
        book.copyWith(coverUrl: storedCoverUri.toString()),
      );
      await _loadBookshelf(force: true);
      _showMessage('已更新自定义封面。');
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('设置自定义封面失败，请重试。');
    }
  }

  Future<Uri?> _persistCustomCover(
    BookshelfBook book,
    PickedImageData picked,
  ) async {
    final bytes = picked.bytes;
    if (bytes.isEmpty) {
      return null;
    }

    final baseDir = await getApplicationSupportDirectory();
    final coverDir = Directory(
      p.join(baseDir.path, 'shuxiang_reading_next', 'custom_covers'),
    );
    if (!await coverDir.exists()) {
      await coverDir.create(recursive: true);
    }

    final key = _bookKey(book).replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final sourceExtension = p.extension(picked.name).toLowerCase();
    final extension =
        const [
              '.jpg',
              '.jpeg',
              '.png',
              '.webp',
              '.gif',
            ].contains(sourceExtension)
            ? sourceExtension
            : '.jpg';

    await for (final entity in coverDir.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = p.basename(entity.path);
      if (!name.startsWith('${key}_')) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {
        // Ignore stale cleanup failure.
      }
    }

    final targetFile = File(
      p.join(
        coverDir.path,
        '${key}_${DateTime.now().millisecondsSinceEpoch}$extension',
      ),
    );
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.uri;
  }

  Future<String?> _showTagNameDialog(
    BuildContext dialogContext, {
    required String title,
    required String confirmText,
    required String hintText,
    required Set<String> existingTags,
    String initialValue = '',
    String? originalTag,
  }) async {
    var draftValue = initialValue;
    String? errorText;

    final result = await showDialog<String>(
      context: dialogContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? validate() {
              final value = _normalizeTags([draftValue]);
              if (value.isEmpty) {
                return '请输入标签名称';
              }
              final tag = value.first;
              if (originalTag != null && tag == originalTag) {
                return null;
              }
              if (originalTag == null && existingTags.contains(tag)) {
                return '该标签已存在';
              }
              return null;
            }

            void submit() {
              final validation = validate();
              if (validation != null) {
                setDialogState(() {
                  errorText = validation;
                });
                return;
              }
              final tag = _normalizeTags([draftValue]).first;
              Navigator.of(context).pop(tag);
            }

            return AlertDialog(
              title: Text(title),
              content: TextFormField(
                initialValue: initialValue,
                autofocus: true,
                maxLength: 12,
                decoration: InputDecoration(
                  hintText: hintText,
                  errorText: errorText,
                ),
                onChanged: (value) {
                  draftValue = value;
                  if (errorText != null) {
                    setDialogState(() {
                      errorText = null;
                    });
                  }
                },
                onFieldSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(onPressed: submit, child: Text(confirmText)),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  Future<void> _confirmAndRemoveBook(BookshelfBook book) async {
    final confirmed = await _showConfirmDialog(
      title: '删除书籍',
      content:
          '确定从书架删除《${_toSingleLineText(_displayBookTitle(book))}》吗？该操作不可撤销。',
      confirmText: '删除',
    );
    if (!mounted || confirmed != true) {
      return;
    }
    try {
      await _removeBook(book);
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('删除失败，请稍后重试。');
    }
  }

  void _selectAllBooks() {
    final visibleBooks = _filteredBooks;
    if (visibleBooks.isEmpty || _isBatchDeleting) {
      return;
    }

    setState(() {
      _isSelectionMode = true;
      _selectedBookKeys
        ..clear()
        ..addAll(visibleBooks.map(_bookKey));
    });
  }

  void _exitSelectionMode() {
    if (_isBatchDeleting) {
      return;
    }

    setState(() {
      _isSelectionMode = false;
      _selectedBookKeys.clear();
    });
  }

  void _syncSelectionWithBooks() {
    if (!_isSelectionMode) {
      return;
    }

    final visibleBooks = _filteredBooks;
    final validKeys = visibleBooks.map(_bookKey).toSet();
    final nextSelected =
        _selectedBookKeys.where((key) => validKeys.contains(key)).toSet();

    final changed =
        nextSelected.length != _selectedBookKeys.length ||
        (visibleBooks.isEmpty && _isSelectionMode);

    if (!changed || !mounted) {
      return;
    }

    setState(() {
      _selectedBookKeys
        ..clear()
        ..addAll(nextSelected);
      if (_selectedBookKeys.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  Future<void> _deleteSelectedBooks() async {
    if (_selectedBookKeys.isEmpty || _isBatchDeleting) {
      return;
    }

    final selected = _books
        .where((book) => _selectedBookKeys.contains(_bookKey(book)))
        .toList(growable: false);
    if (selected.isEmpty) {
      _exitSelectionMode();
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '删除书籍',
      content: '确定删除已选 ${selected.length} 本书吗？该操作不可撤销。',
      confirmText: '删除',
    );
    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isBatchDeleting = true;
    });

    var removedCount = 0;
    for (final book in selected) {
      try {
        await _removeBook(book, reload: false, showFeedback: false);
        removedCount += 1;
      } catch (_) {
        // Continue deleting remaining selected books.
      }
    }

    await _loadBookshelf(force: true);

    if (!mounted) {
      return;
    }

    setState(() {
      _isBatchDeleting = false;
      _isSelectionMode = false;
      _selectedBookKeys.clear();
    });

    _showMessage('已删除 $removedCount 本书。');
  }

  String _toSingleLineText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeBookshelfSearchText(String text) {
    return _toSingleLineText(text).toLowerCase();
  }

  String get _normalizedBookshelfSearchKeyword {
    return _normalizeBookshelfSearchText(_bookshelfSearchKeyword);
  }

  bool get _hasBookshelfSearchKeyword {
    return _normalizedBookshelfSearchKeyword.isNotEmpty;
  }

  Widget _buildCover({
    String? realCoverUrl,
    String? customCoverPath,
    String? title,
    String? author,
    String? bookId,
    String? sourceId,
    String? detailUrl,
    double width = 78,
    double height = 108,
  }) {
    final resolvedCover = resolveBookCover(
      realCoverUrl: realCoverUrl,
      customCoverPath: customCoverPath,
      activeTheme: ref.read(activeAdvancedThemeProvider).valueOrNull,
      galleries: ref.read(coverGalleriesProvider).valueOrNull ?? const [],
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
    return ResolvedBookCoverView(
      cover: resolvedCover,
      title: title ?? '',
      author: author,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(12),
    );
  }

  LocalBook? _bookshelfLocalBook(BookshelfBook book) {
    if (book.sourceId != _kLocalBookSourceId) {
      return null;
    }
    return _localBooksById[book.bookId.trim()];
  }

  String _displayBookTitle(BookshelfBook book, {LocalBook? localBook}) {
    final resolvedLocalBook = localBook ?? _bookshelfLocalBook(book);
    final localTitle = resolvedLocalBook?.title.trim() ?? '';
    if (localTitle.isNotEmpty) {
      return localTitle;
    }
    return book.title;
  }

  String? _displayBookAuthor(BookshelfBook book, {LocalBook? localBook}) {
    final resolvedLocalBook = localBook ?? _bookshelfLocalBook(book);
    final localAuthor = resolvedLocalBook?.author?.trim() ?? '';
    if (localAuthor.isNotEmpty) {
      return localAuthor;
    }
    return book.author;
  }

  Widget _buildSourceBadge(BookshelfBook book, {bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLocal = book.sourceId == _kLocalBookSourceId;
    final localBook = isLocal ? _localBooksById[book.bookId.trim()] : null;
    final (label, background, foreground) =
        isLocal
            ? _localSourceBadgePresentation(colorScheme, localBook)
            : (
              '在线',
              colorScheme.primaryContainer.withValues(alpha: 0.94),
              colorScheme.onPrimaryContainer,
            );
    final borderRadius = compact ? 6.0 : 7.0;
    final horizontalPadding = compact ? 8.0 : 10.0;
    final minWidth = compact ? 30.0 : 36.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: compact ? 1.5 : 2,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 9.5 : 10.5,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  (String, Color, Color) _localSourceBadgePresentation(
    ColorScheme colorScheme,
    LocalBook? localBook,
  ) {
    final status = localBook?.indexStatus;
    return switch (status) {
      LocalBookIndexStatus.pending => (
        '待建立',
        colorScheme.secondaryContainer.withValues(alpha: 0.94),
        colorScheme.onSecondaryContainer,
      ),
      LocalBookIndexStatus.indexing => (
        '解析中',
        colorScheme.tertiaryContainer.withValues(alpha: 0.94),
        colorScheme.onTertiaryContainer,
      ),
      LocalBookIndexStatus.stale => (
        '需重建',
        colorScheme.secondaryContainer.withValues(alpha: 0.94),
        colorScheme.onSecondaryContainer,
      ),
      LocalBookIndexStatus.failed => (
        '失败',
        colorScheme.errorContainer.withValues(alpha: 0.94),
        colorScheme.onErrorContainer,
      ),
      _ => (
        '本地',
        colorScheme.secondaryContainer.withValues(alpha: 0.94),
        colorScheme.onSecondaryContainer,
      ),
    };
  }

  Future<void> _loadBookshelf({bool force = false}) {
    final inFlight = _activeBookshelfLoad;
    if (inFlight != null) {
      if (!force) {
        return inFlight;
      }
      _reloadAfterActiveLoad = true;
      return inFlight.whenComplete(() async {
        if (!_reloadAfterActiveLoad) {
          return;
        }
        _reloadAfterActiveLoad = false;
        if (!mounted) {
          return;
        }
        await _loadBookshelf(force: true);
      });
    }

    if (!mounted) {
      return Future<void>.value();
    }

    final now = DateTime.now();
    if (!force) {
      final lastRequestAt = _lastBookshelfLoadRequestedAt;
      if (lastRequestAt != null &&
          now.difference(lastRequestAt) < _kDuplicateLoadCooldown) {
        return Future<void>.value();
      }
    }
    _lastBookshelfLoadRequestedAt = now;

    final task = _loadBookshelfCore();
    _activeBookshelfLoad = task;
    return task.whenComplete(() {
      if (identical(_activeBookshelfLoad, task)) {
        _activeBookshelfLoad = null;
      }
    });
  }

  Future<void> _loadBookshelfCore() async {
    final ticket = ++_loadTicket;
    _cancelBackgroundLatestInfoRefresh();

    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadErrorText = null;
      });
    }

    try {
      final books = await _bookshelfService.getAll().timeout(
        _kBookshelfLoadTimeout,
      );
      final retainedProgress = _retainProgressForBooks(
        source: _progressByBookKey,
        books: books,
      );
      final retainedCachedChapterTitles = _retainCachedChapterTitlesForBooks(
        source: _latestCachedChapterByBookKey,
        books: books,
      );

      if (!mounted || ticket != _loadTicket) {
        return;
      }

      setState(() {
        _books = books;
        _progressByBookKey = retainedProgress;
        _latestCachedChapterByBookKey = retainedCachedChapterTitles;
        _cachedChapterCountByBookKey = _retainCachedChapterCountsForBooks(
          source: _cachedChapterCountByBookKey,
          books: books,
        );
        _bookshelfMetadataReady = false;
        _isLoading = false;
        _ensureFilterStillValid();
      });
      _syncSelectionWithBooks();
      unawaited(_maybeShowContinueReadingPrompt(ticket: ticket));

      await _loadBookshelfMetadata(books, ticket: ticket);

      if (books.isEmpty) {
        return;
      }

      await _loadLatestCachedChapterMap(books, ticket: ticket);
      await _loadCachedChapterCountMap(books, ticket: ticket);
      await _loadProgressMapInBatches(books, ticket: ticket);
      if (_skipNextBackgroundLatestInfoRefresh) {
        _skipNextBackgroundLatestInfoRefresh = false;
      } else {
        final refreshEpoch = ++_latestInfoRefreshEpoch;
        unawaited(
          _refreshOnlineBookshelfLatestInfo(
            books,
            ticket: ticket,
            refreshEpoch: refreshEpoch,
          ),
        );
      }
    } on TimeoutException {
      if (!mounted || ticket != _loadTicket) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorText = '加载书架超时，请稍后重试。';
      });
    } catch (error) {
      if (!mounted || ticket != _loadTicket) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorText = '加载书架失败：$error';
      });
    }
  }

  Future<void> _loadBookshelfMetadata(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final sourceTypeFuture = _loadSourceTypeMap();
    final localBooksFuture = _loadLocalBookMap(books);
    final rawTagMapFuture = _bookshelfService.getTagMap();
    final tagOrderFuture = _bookshelfService.getTagOrder();
    final rawCategoryMapFuture = _bookshelfService.getCategoryMap();
    final categoryOrderFuture = _bookshelfService.getCategoryOrder();
    final baseFilterOrderNamesFuture = _bookshelfService.getBaseFilterOrder();

    try {
      await Future.wait<dynamic>([
        sourceTypeFuture,
        localBooksFuture,
        rawTagMapFuture,
        tagOrderFuture,
        rawCategoryMapFuture,
        categoryOrderFuture,
        baseFilterOrderNamesFuture,
      ]);
    } catch (_) {
      return;
    }

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    final sourceTypeMap = await sourceTypeFuture;
    final localBooksById = await localBooksFuture;
    final rawTagMap = await rawTagMapFuture;
    final tagOrder = await tagOrderFuture;
    final rawCategoryMap = await rawCategoryMapFuture;
    final categoryOrder = await categoryOrderFuture;
    final baseFilterOrderNames = await baseFilterOrderNamesFuture;

    final validBookKeys = books.map(_bookKey).toSet();
    final tagMap = <String, List<String>>{};
    final categoryMap = <String, String>{};
    for (final entry in rawTagMap.entries) {
      if (!validBookKeys.contains(entry.key)) {
        continue;
      }
      final tags = _normalizeTags(entry.value);
      if (tags.isEmpty) {
        continue;
      }
      tagMap[entry.key] = tags;
    }
    for (final entry in rawCategoryMap.entries) {
      if (!validBookKeys.contains(entry.key)) {
        continue;
      }
      final normalizedCategories = _normalizeTags([entry.value]);
      if (normalizedCategories.isEmpty) {
        continue;
      }
      categoryMap[entry.key] = normalizedCategories.first;
    }

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    setState(() {
      _sourceTypeBySourceId = sourceTypeMap;
      _localBooksById = localBooksById;
      _bookTagsByKey = tagMap;
      _tagOrder = _normalizeTags(tagOrder);
      _bookCategoriesByKey = categoryMap;
      _categoryOrder = _normalizeTags(categoryOrder);
      _baseFilterOrder = baseFilterOrderNames
          .map((name) {
            for (final filter in _kDefaultBaseFilters) {
              if (filter.name == name) {
                return filter;
              }
            }
            return null;
          })
          .whereType<_BookshelfFilter>()
          .toList(growable: false);
      _bookshelfMetadataReady = true;
      _ensureFilterStillValid();
    });
    _syncSelectionWithBooks();
  }

  Future<Map<String, LocalBook>> _loadLocalBookMap(
    List<BookshelfBook> books,
  ) async {
    final localBookIds =
        books
            .where((book) => book.sourceId == _kLocalBookSourceId)
            .map((book) => book.bookId.trim())
            .where((bookId) => bookId.isNotEmpty)
            .toSet();
    if (localBookIds.isEmpty) {
      return const <String, LocalBook>{};
    }

    try {
      final localBooks = await _localBookRepository.getAllBooks();
      return <String, LocalBook>{
        for (final book in localBooks)
          if (localBookIds.contains(book.id)) book.id: book,
      };
    } catch (_) {
      return const <String, LocalBook>{};
    }
  }

  Future<void> _loadLatestCachedChapterMap(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final pairs = books
        .map((book) => MapEntry(book.bookId.trim(), book.sourceId.trim()))
        .where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (pairs.isEmpty) {
      return;
    }

    final latestByBookSource = await AppDatabase.instance
        .getLatestCachedChapterTitlesByBookSource(pairs);

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    final latestByBookKey = <String, String>{};
    for (final book in books) {
      final bookKey = _bookKey(book);
      if (bookKey.isEmpty) {
        continue;
      }
      final pairKey = _cachedChapterBookSourceKey(
        bookId: book.bookId,
        sourceId: book.sourceId,
      );
      final title = latestByBookSource[pairKey]?.trim() ?? '';
      if (title.isEmpty) {
        continue;
      }
      latestByBookKey[bookKey] = title;
    }

    setState(() {
      _latestCachedChapterByBookKey = latestByBookKey;
    });
  }

  Future<void> _loadCachedChapterCountMap(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final pairs = books
        .map((book) => MapEntry(book.bookId.trim(), book.sourceId.trim()))
        .where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (pairs.isEmpty) {
      return;
    }

    final countByBookSource = await AppDatabase.instance
        .getCachedChapterCountsByBookSource(pairs);

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    final countByBookKey = <String, int>{};
    for (final book in books) {
      final bookKey = _bookKey(book);
      if (bookKey.isEmpty) {
        continue;
      }
      final pairKey = _cachedChapterBookSourceKey(
        bookId: book.bookId,
        sourceId: book.sourceId,
      );
      final count = countByBookSource[pairKey] ?? 0;
      if (count <= 0) {
        continue;
      }
      countByBookKey[bookKey] = count;
    }

    setState(() {
      _cachedChapterCountByBookKey = countByBookKey;
    });
  }

  Future<void> _refreshOnlineBookshelfLatestInfo(
    List<BookshelfBook> books, {
    required int ticket,
    required int refreshEpoch,
  }) async {
    final onlineBooks = books
        .where((book) => book.sourceId.trim() != _kLocalBookSourceId)
        .toList(growable: false);
    if (onlineBooks.isEmpty) {
      return;
    }

    var changed = false;
    for (final book in onlineBooks) {
      if (_isLatestInfoRefreshCancelled(
        ticket: ticket,
        refreshEpoch: refreshEpoch,
      )) {
        return;
      }

      try {
        final conflictKey = _bookConflictKey(
          sourceId: book.sourceId,
          detailUrl: book.detailUrl,
          bookId: book.bookId,
        );
        final sourceConflictKey = _taskConflictService.conflictKeyForSource(
          book.sourceId,
        );
        final capturedBookEpoch = _taskConflictService.captureBackgroundEpoch(
          conflictKey,
        );
        final capturedSourceEpoch = _taskConflictService.captureBackgroundEpoch(
          sourceConflictKey,
        );
        final detailResult = await _bookDetailService
            .loadForBackgroundRefresh(
              sourceId: book.sourceId,
              bookId: book.bookId,
              detailUrl: book.detailUrl,
              fallbackTitle: book.title,
              fallbackAuthor: book.author,
              cancellationHandle: SessionCancellationHandle(
                isCancelled:
                    () =>
                        _isLatestInfoRefreshCancelled(
                          ticket: ticket,
                          refreshEpoch: refreshEpoch,
                        ) ||
                        _taskConflictService.hasBackgroundConflictAdvanced(
                          conflictKey: conflictKey,
                          capturedEpoch: capturedBookEpoch,
                        ) ||
                        _taskConflictService.hasBackgroundConflictAdvanced(
                          conflictKey: sourceConflictKey,
                          capturedEpoch: capturedSourceEpoch,
                        ),
              ),
            )
            .timeout(const Duration(seconds: 8));
        if (detailResult == null) {
          continue;
        }

        final latestChapterTitle =
            detailResult.chapters
                .where(
                  (chapter) =>
                      !chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty,
                )
                .map((chapter) => chapter.title.trim())
                .where((title) => title.isNotEmpty)
                .lastOrNull;
        final normalizedLatestChapter =
            latestChapterTitle == null || latestChapterTitle.isEmpty
                ? null
                : latestChapterTitle;
        final detailAuthor = detailResult.detail.author?.trim();
        final normalizedAuthor =
            detailAuthor == null || detailAuthor.isEmpty ? null : detailAuthor;
        final detailCoverUrl = detailResult.detail.coverUrl?.trim();
        final normalizedCoverUrl =
            detailCoverUrl == null || detailCoverUrl.isEmpty
                ? null
                : detailCoverUrl;
        final currentLatestChapter = book.latestChapter?.trim();
        final currentAuthor = book.author?.trim();
        final currentCoverUrl = book.coverUrl?.trim();
        final normalizedCoverCompareKey = _coverUrlCompareKey(
          normalizedCoverUrl,
        );
        final currentCoverCompareKey = _coverUrlCompareKey(currentCoverUrl);

        final needsUpdate =
            normalizedLatestChapter != currentLatestChapter ||
            normalizedAuthor != currentAuthor ||
            normalizedCoverCompareKey != currentCoverCompareKey;
        if (!needsUpdate) {
          continue;
        }

        await _bookshelfService.upsert(
          book.copyWith(
            latestChapter: normalizedLatestChapter,
            clearLatestChapter: normalizedLatestChapter == null,
            author: normalizedAuthor,
            clearAuthor: normalizedAuthor == null,
            coverUrl: normalizedCoverUrl,
            clearCoverUrl:
                normalizedCoverUrl == null || normalizedCoverUrl.isEmpty,
          ),
        );
        changed = true;
      } catch (_) {
        // Ignore per-book refresh failures to keep pull-to-refresh lightweight.
      }
    }

    if (!changed ||
        _isLatestInfoRefreshCancelled(
          ticket: ticket,
          refreshEpoch: refreshEpoch,
        )) {
      return;
    }
    _skipNextBackgroundLatestInfoRefresh = true;
    await _loadBookshelf(force: true);
  }

  void _cancelBackgroundLatestInfoRefresh() {
    _latestInfoRefreshEpoch += 1;
  }

  bool _isLatestInfoRefreshCancelled({
    required int ticket,
    required int refreshEpoch,
  }) {
    return !mounted ||
        ticket != _loadTicket ||
        refreshEpoch != _latestInfoRefreshEpoch ||
        !_isBookshelfRoute(_lastKnownRouteLocation);
  }

  String _bookConflictKey({
    required String sourceId,
    required String detailUrl,
    required String bookId,
  }) {
    return _taskConflictService.conflictKeyForBook(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
    );
  }

  void _cancelBackgroundRefreshForBook({
    required String sourceId,
    required String detailUrl,
    required String bookId,
    required SourceRuntimeConflictScene byScene,
  }) {
    final conflictKey = _bookConflictKey(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
    );
    if (conflictKey.isEmpty) {
      return;
    }
    _taskConflictService.cancelBackgroundWorkFor(
      conflictKey: conflictKey,
      byScene: byScene,
    );
  }

  Future<void> _restoreViewModePreference() async {
    final useGrid = await _bookshelfService.loadUseGridView();
    if (!mounted || _useGridView == useGrid) {
      return;
    }
    setState(() {
      _useGridView = useGrid;
    });
  }

  Future<void> _restoreListPreferences() async {
    final showTitle = await _bookshelfService.loadListShowTitle();
    final showAuthor = await _bookshelfService.loadListShowAuthor();
    final showLatestChapter =
        await _bookshelfService.loadListShowLatestChapter();
    final showProgressBar = await _bookshelfService.loadListShowProgressBar();
    final alwaysShowSearchBar =
        await _bookshelfService.loadListAlwaysShowSearchBar();
    final pinSearchBar = await _bookshelfService.loadListPinSearchBar();
    final quickFilterContent = _searchQuickFilterContentFromStorageValue(
      await _bookshelfService.loadListQuickFilterContent(),
    );
    if (!mounted) {
      return;
    }
    if (_listShowTitle == showTitle &&
        _listShowAuthor == showAuthor &&
        _listShowLatestChapter == showLatestChapter &&
        _listShowProgressBar == showProgressBar &&
        _listAlwaysShowSearchBar == alwaysShowSearchBar &&
        _listPinSearchBar == pinSearchBar &&
        _listQuickFilterContent == quickFilterContent) {
      return;
    }
    setState(() {
      _listShowTitle = showTitle;
      _listShowAuthor = showAuthor;
      _listShowLatestChapter = showLatestChapter;
      _listShowProgressBar = showProgressBar;
      _listAlwaysShowSearchBar = alwaysShowSearchBar;
      _listPinSearchBar = pinSearchBar;
      _listQuickFilterContent = quickFilterContent;
    });
  }

  Future<void> _restoreSortModePreference() async {
    final loaded = _sortModeFromStorageValue(
      await _bookshelfService.loadSortMode(),
    );
    if (!mounted || _sortMode == loaded) {
      return;
    }
    setState(() {
      _sortMode = loaded;
    });
  }

  Future<void> _restoreGridPreferences() async {
    final adaptive = await _bookshelfService.loadGridAdaptiveColumns();
    final columns = await _bookshelfService.loadGridColumnCount();
    final crossSpacing = await _bookshelfService.loadGridCrossSpacing();
    final mainSpacing = await _bookshelfService.loadGridMainSpacing();
    final showTitle = await _bookshelfService.loadGridShowTitle();
    final showAuthor = await _bookshelfService.loadGridShowAuthor();
    final showLatestChapter =
        await _bookshelfService.loadGridShowLatestChapter();
    final showProgressBar = await _bookshelfService.loadGridShowProgressBar();
    final alwaysShowSearchBar =
        await _bookshelfService.loadGridAlwaysShowSearchBar();
    final pinSearchBar = await _bookshelfService.loadGridPinSearchBar();
    final quickFilterContent = _searchQuickFilterContentFromStorageValue(
      await _bookshelfService.loadGridQuickFilterContent(),
    );
    if (!mounted) {
      return;
    }
    if (_gridAdaptiveColumns == adaptive &&
        _gridColumnCount == columns &&
        _gridCrossSpacing == crossSpacing &&
        _gridMainSpacing == mainSpacing &&
        _gridShowTitle == showTitle &&
        _gridShowAuthor == showAuthor &&
        _gridShowLatestChapter == showLatestChapter &&
        _gridShowProgressBar == showProgressBar &&
        _gridAlwaysShowSearchBar == alwaysShowSearchBar &&
        _gridPinSearchBar == pinSearchBar &&
        _gridQuickFilterContent == quickFilterContent) {
      return;
    }
    setState(() {
      _gridAdaptiveColumns = adaptive;
      _gridColumnCount = columns;
      _gridCrossSpacing = crossSpacing;
      _gridMainSpacing = mainSpacing;
      _gridShowTitle = showTitle;
      _gridShowAuthor = showAuthor;
      _gridShowLatestChapter = showLatestChapter;
      _gridShowProgressBar = showProgressBar;
      _gridAlwaysShowSearchBar = alwaysShowSearchBar;
      _gridPinSearchBar = pinSearchBar;
      _gridQuickFilterContent = quickFilterContent;
    });
  }

  _BookshelfSortMode _sortModeFromStorageValue(String value) {
    return switch (value) {
      BookshelfService.recentReadSortMode => _BookshelfSortMode.recentRead,
      BookshelfService.readingProgressSortMode =>
        _BookshelfSortMode.readingProgress,
      BookshelfService.createdAtSortMode => _BookshelfSortMode.createdAt,
      BookshelfService.authorSortMode => _BookshelfSortMode.author,
      BookshelfService.titleSortMode => _BookshelfSortMode.title,
      _ => _BookshelfSortMode.defaultOrder,
    };
  }

  String _sortModeStorageValue(_BookshelfSortMode mode) {
    return switch (mode) {
      _BookshelfSortMode.defaultOrder => BookshelfService.defaultSortMode,
      _BookshelfSortMode.recentRead => BookshelfService.recentReadSortMode,
      _BookshelfSortMode.readingProgress =>
        BookshelfService.readingProgressSortMode,
      _BookshelfSortMode.createdAt => BookshelfService.createdAtSortMode,
      _BookshelfSortMode.author => BookshelfService.authorSortMode,
      _BookshelfSortMode.title => BookshelfService.titleSortMode,
    };
  }

  String _sortModeLabel(_BookshelfSortMode mode) {
    return switch (mode) {
      _BookshelfSortMode.defaultOrder => '默认排序',
      _BookshelfSortMode.recentRead => '最近阅读',
      _BookshelfSortMode.readingProgress => '阅读进度',
      _BookshelfSortMode.createdAt => '创建时间',
      _BookshelfSortMode.author => '作者',
      _BookshelfSortMode.title => '书名',
    };
  }

  String _sortModeDescription(_BookshelfSortMode mode) {
    return switch (mode) {
      _BookshelfSortMode.defaultOrder => '优先按最近阅读，其次按加入书架时间。',
      _BookshelfSortMode.recentRead => '最近打开或更新阅读位置的书籍排在前面。',
      _BookshelfSortMode.readingProgress => '按当前阅读进度从高到低排序。',
      _BookshelfSortMode.createdAt => '按加入书架时间从新到旧排序。',
      _BookshelfSortMode.author => '按作者名称排序，缺少作者信息的书排在后面。',
      _BookshelfSortMode.title => '按书名排序，相同书名再按加入时间兜底。',
    };
  }

  String _bookshelfSettingsTabLabel(_BookshelfSettingsTab tab) {
    return switch (tab) {
      _BookshelfSettingsTab.list => '列表',
      _BookshelfSettingsTab.grid => '网格',
    };
  }

  _BookshelfSearchQuickFilterContent _searchQuickFilterContentFromStorageValue(
    String value,
  ) {
    return switch (value) {
      'tags' => _BookshelfSearchQuickFilterContent.tags,
      'categories' => _BookshelfSearchQuickFilterContent.categories,
      _ => _BookshelfSearchQuickFilterContent.none,
    };
  }

  String _searchQuickFilterContentStorageValue(
    _BookshelfSearchQuickFilterContent value,
  ) {
    return switch (value) {
      _BookshelfSearchQuickFilterContent.tags => 'tags',
      _BookshelfSearchQuickFilterContent.categories => 'categories',
      _BookshelfSearchQuickFilterContent.none => 'none',
    };
  }

  String _searchQuickFilterContentLabel(
    _BookshelfSearchQuickFilterContent value,
  ) {
    return switch (value) {
      _BookshelfSearchQuickFilterContent.tags => '标签',
      _BookshelfSearchQuickFilterContent.categories => '分类',
      _BookshelfSearchQuickFilterContent.none => '不显示',
    };
  }

  Future<Map<String, int>> _loadSourceTypeMap() async {
    final sourceTypeBySourceId = <String, int>{};

    // Prefer in-memory runtime metadata when available to avoid extra I/O.
    final runtimeSources = SourceRuntimeFacade.instance.registeredScriptSources(
      enabledOnly: false,
    );
    for (final source in runtimeSources) {
      sourceTypeBySourceId[source.runtime.id] = _inferScriptSourceType(source);
    }

    // Avoid triggering heavy runtime reload/compile during bookshelf startup.
    // Read persisted script sources directly and classify by capabilities.
    try {
      final persistedSources = await SourceRuntimeFacade.instance
          .listScriptSources()
          .timeout(_kSourceMapLoadTimeout);
      for (final source in persistedSources) {
        sourceTypeBySourceId[source.id] = _inferScriptSourceTypeFromCode(
          source.sourceCode,
        );
      }
    } catch (_) {
      // Keep whatever runtime-derived results we already have.
    }

    return sourceTypeBySourceId;
  }

  int _inferScriptSourceType(RegisteredSource source) {
    final capabilities =
        source.definition.manifest.capabilities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();
    return _isMangaCapabilities(capabilities) ? 2 : 0;
  }

  int _inferScriptSourceTypeFromCode(String sourceCode) {
    final capabilities = _extractCapabilitiesFromSourceCode(sourceCode);
    return _isMangaCapabilities(capabilities) ? 2 : 0;
  }

  bool _isMangaCapabilities(Set<String> capabilities) {
    return capabilities.any(_kMangaCapabilityKeywords.contains);
  }

  Set<String> _extractCapabilitiesFromSourceCode(String sourceCode) {
    final capabilitiesMatch = RegExp(
      r'\bcapabilities\s*:\s*\[([\s\S]*?)\]',
      caseSensitive: false,
    ).firstMatch(sourceCode);
    final rawCapabilities = capabilitiesMatch?.group(1);
    if (rawCapabilities == null || rawCapabilities.trim().isEmpty) {
      return const <String>{};
    }

    return RegExp(r'''['"]([^'"]+)['"]''')
        .allMatches(rawCapabilities)
        .map((match) => (match.group(1) ?? '').trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  Future<void> _loadProgressMapInBatches(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final validBookKeys =
        books.map(_bookKey).where((key) => key.isNotEmpty).toSet();
    final progressMap = <String, ReadingProgress>{
      for (final entry in _progressByBookKey.entries)
        if (validBookKeys.contains(entry.key)) entry.key: entry.value,
    };
    var batchesSinceUiUpdate = 0;
    var hasPendingUiUpdate = false;

    for (var start = 0; start < books.length; start += _kProgressBatchSize) {
      if (!mounted || ticket != _loadTicket) {
        return;
      }

      final end =
          (start + _kProgressBatchSize > books.length)
              ? books.length
              : start + _kProgressBatchSize;
      final batch = books.sublist(start, end);

      final entries = await Future.wait(
        batch.map((book) async {
          final bookKey = _bookKey(book);
          try {
            final progress = await _readerPreferencesService
                .loadProgress(book.bookId)
                .timeout(_kProgressLoadTimeout);
            return (
              book: book,
              bookKey: bookKey,
              progress: progress,
              failed: false,
            );
          } catch (_) {
            return (book: book, bookKey: bookKey, progress: null, failed: true);
          }
        }),
      );

      if (!mounted || ticket != _loadTicket) {
        return;
      }

      for (final entry in entries) {
        if (entry.failed) {
          // Keep previous progress on transient read failures to avoid flicker.
          continue;
        }
        final value = entry.progress;
        if (value != null && _isProgressMatchingBook(value, entry.book)) {
          if (progressMap[entry.bookKey] != value) {
            progressMap[entry.bookKey] = value;
            hasPendingUiUpdate = true;
          }
        } else {
          if (progressMap.remove(entry.bookKey) != null) {
            hasPendingUiUpdate = true;
          }
        }
      }

      batchesSinceUiUpdate += 1;
      final isLastBatch = end >= books.length;
      final shouldUpdateUi =
          hasPendingUiUpdate &&
          (batchesSinceUiUpdate >= _kProgressUiUpdateBatchInterval ||
              isLastBatch);
      if (shouldUpdateUi) {
        setState(() {
          _progressByBookKey = Map<String, ReadingProgress>.from(progressMap);
        });
        hasPendingUiUpdate = false;
        batchesSinceUiUpdate = 0;
      }

      if (end < books.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  Map<String, ReadingProgress> _retainProgressForBooks({
    required Map<String, ReadingProgress> source,
    required List<BookshelfBook> books,
  }) {
    if (source.isEmpty || books.isEmpty) {
      return const <String, ReadingProgress>{};
    }
    final validBookKeys =
        books.map(_bookKey).where((key) => key.isNotEmpty).toSet();
    final retained = <String, ReadingProgress>{};
    for (final entry in source.entries) {
      if (validBookKeys.contains(entry.key)) {
        retained[entry.key] = entry.value;
      }
    }
    return retained;
  }

  Map<String, String> _retainCachedChapterTitlesForBooks({
    required Map<String, String> source,
    required List<BookshelfBook> books,
  }) {
    if (source.isEmpty || books.isEmpty) {
      return const <String, String>{};
    }
    final validBookKeys =
        books.map(_bookKey).where((key) => key.isNotEmpty).toSet();
    final retained = <String, String>{};
    for (final entry in source.entries) {
      if (validBookKeys.contains(entry.key)) {
        retained[entry.key] = entry.value;
      }
    }
    return retained;
  }

  Map<String, int> _retainCachedChapterCountsForBooks({
    required Map<String, int> source,
    required List<BookshelfBook> books,
  }) {
    if (source.isEmpty || books.isEmpty) {
      return const <String, int>{};
    }
    final validBookKeys =
        books.map(_bookKey).where((key) => key.isNotEmpty).toSet();
    final retained = <String, int>{};
    for (final entry in source.entries) {
      if (validBookKeys.contains(entry.key)) {
        retained[entry.key] = entry.value;
      }
    }
    return retained;
  }

  String _cachedChapterBookSourceKey({
    required String bookId,
    required String sourceId,
  }) {
    return '${sourceId.trim()}\u0000${bookId.trim()}';
  }

  bool _isProgressMatchingBook(ReadingProgress progress, BookshelfBook book) {
    return progress.sourceId.trim() == book.sourceId.trim() &&
        progress.detailUrl.trim() == book.detailUrl.trim();
  }

  _BookshelfProgressDisplay _resolveBookshelfProgressDisplay(
    BookshelfBook book, {
    required ReadingProgress? progress,
  }) {
    if (progress == null) {
      return const _BookshelfProgressDisplay(
        progressValue: 0,
        summaryText: '阅读进度: 未开始',
        trailingLabel: '未开始',
        hasProgress: false,
      );
    }

    final totalChapters = _resolveApproximateChapterCount(book);
    final currentChapterNo = (progress.chapterIndex + 1).clamp(1, 999999);
    if (totalChapters != null && totalChapters > 0) {
      final normalizedTotal = totalChapters.clamp(1, 999999);
      final normalizedIndex = progress.chapterIndex.clamp(
        0,
        normalizedTotal - 1,
      );
      final overallProgress =
          (normalizedIndex + progress.chapterPositionRatio.clamp(0.0, 1.0)) /
          normalizedTotal;
      final percentage = (overallProgress.clamp(0.0, 1.0) * 100).round();
      return _BookshelfProgressDisplay(
        progressValue: overallProgress.clamp(0.0, 1.0),
        summaryText: '阅读进度: 第 $currentChapterNo / $normalizedTotal 章',
        trailingLabel: '$percentage%',
        hasProgress: true,
      );
    }

    return _BookshelfProgressDisplay(
      progressValue: progress.chapterPositionRatio.clamp(0.0, 1.0),
      summaryText: '阅读进度: 读到第 $currentChapterNo 章',
      trailingLabel: '第$currentChapterNo章',
      hasProgress: true,
    );
  }

  int? _resolveApproximateChapterCount(BookshelfBook book) {
    if (book.sourceId == _kLocalBookSourceId) {
      final localCount = _localBooksById[book.bookId.trim()]?.chapterCount ?? 0;
      return localCount > 0 ? localCount : null;
    }

    final cachedCount = _cachedChapterCountByBookKey[_bookKey(book)] ?? 0;
    return cachedCount > 0 ? cachedCount : null;
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _maybeShowContinueReadingPrompt({required int ticket}) async {
    if (_hasShownContinueReadingPrompt || !mounted || ticket != _loadTicket) {
      return;
    }
    if (!_isBookshelfRoute(_lastKnownRouteLocation)) {
      return;
    }

    _hasShownContinueReadingPrompt = true;

    List<ReadingRecord> records;
    try {
      records = await AppDatabase.instance.listLatestReadingRecords();
    } catch (_) {
      return;
    }

    if (!mounted || ticket != _loadTicket || records.isEmpty) {
      return;
    }

    final latest = records.first;
    final title = latest.bookTitle.trim();
    if (title.isEmpty) {
      return;
    }

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    setState(() {
      _continueReadingRecord = latest;
    });
    Future<void>.delayed(_kContinueReadingPromptDuration, () {
      if (!mounted || ticket != _loadTicket) {
        return;
      }
      if (_continueReadingRecord?.bookId != latest.bookId) {
        return;
      }
      _dismissContinueReadingPrompt();
    });
  }

  Future<void> _openLatestReadingRecord(ReadingRecord record) async {
    _dismissContinueReadingPrompt();
    final progress = await _readerPreferencesService.loadProgress(
      record.bookId,
    );
    if (!mounted) {
      return;
    }

    final hasMatchedProgress =
        progress != null &&
        progress.sourceId.trim() == record.sourceId.trim() &&
        progress.detailUrl.trim() == record.detailUrl.trim();
    if (hasMatchedProgress) {
      _continueReading(progress);
      return;
    }

    final chapterId =
        record.lastChapterId?.trim().isNotEmpty == true
            ? record.lastChapterId!.trim()
            : '';
    final chapterUrl =
        record.lastChapterUrl?.trim().isNotEmpty == true
            ? record.lastChapterUrl!.trim()
            : '';
    final chapterTitle =
        record.lastChapterTitle?.trim().isNotEmpty == true
            ? record.lastChapterTitle!.trim()
            : record.bookTitle.trim();

    if (chapterId.isNotEmpty && chapterUrl.isNotEmpty) {
      final route = _readerEntryRouteResolver.buildChapterRoute(
        bookId: record.bookId,
        chapterId: chapterId,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        chapterIndex: record.lastChapterIndex,
      );
      context.push(route);
      return;
    }

    context.push(
      buildBookDetailRoute(
        bookId: record.bookId,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        title: record.bookTitle,
      ),
    );
  }

  void _dismissContinueReadingPrompt() {
    if (!mounted || _continueReadingRecord == null) {
      return;
    }
    setState(() {
      _continueReadingRecord = null;
    });
  }

  Widget _buildContinueReadingPromptCard() {
    final record = _continueReadingRecord;
    final visible = record != null && !_isSelectionMode;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 1.15),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child:
              record == null
                  ? const SizedBox.shrink()
                  : _buildContinueReadingCard(record),
        ),
      ),
    );
  }

  Widget _buildContinueReadingCard(ReadingRecord record) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = _resolvedPalette(context);
    final textTheme = Theme.of(context).textTheme;
    final cardBackground = Color.alphaBlend(
      palette.surfaceColor.withValues(alpha: 0.94),
      palette.cardColor,
    );
    final badgeBackground = Color.alphaBlend(
      palette.elevatedSurfaceColor.withValues(alpha: 0.96),
      palette.cardColor,
    );
    final title = _toSingleLineText(record.bookTitle);
    final author = _toSingleLineText(record.bookAuthor?.trim() ?? '');
    final chapterTitle = _toSingleLineText(
      record.lastChapterTitle?.trim() ?? '',
    );
    final relativeReadTime = _formatRelativeReadTime(record.lastReadAt);
    final chapterLabel = _buildContinueReadingChapterLabel(
      chapterIndex: record.lastChapterIndex,
      chapterTitle: chapterTitle,
    );
    final progressLabel = _buildContinueReadingProgressLabel(
      record.lastPositionRatio,
    );
    final secondaryText =
        chapterLabel ?? (author.isNotEmpty ? author : '回到上次阅读位置');

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: palette.cardBorderColor.withValues(alpha: 0.42),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => unawaited(_openLatestReadingRecord(record)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildCover(
                    realCoverUrl: record.coverUrl,
                    title: record.bookTitle,
                    author: record.bookAuthor,
                    bookId: record.bookId,
                    sourceId: record.sourceId,
                    detailUrl: record.detailUrl,
                    width: 44,
                    height: 62,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title.isEmpty ? '继续阅读' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '最近阅读',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: palette.textPrimaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.cardColor.withValues(
                                  alpha: 0.72,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                relativeReadTime,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelSmall?.copyWith(
                                  color: palette.textSecondaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            chapterLabel != null
                                ? Icons.auto_stories_outlined
                                : Icons.person_outline_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              secondaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: palette.textSecondaryColor,
                                height: 1.35,
                              ),
                            ),
                          ),
                          if (progressLabel != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.noticeSurfaceColor.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                progressLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: palette.noticeAccentColor,
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
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: palette.cardColor.withValues(alpha: 0.76),
                        border: Border.all(
                          color: palette.cardBorderColor.withValues(
                            alpha: 0.38,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
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

  String? _buildContinueReadingChapterLabel({
    required int? chapterIndex,
    required String chapterTitle,
  }) {
    final hasChapterIndex = chapterIndex != null && chapterIndex >= 0;
    if (hasChapterIndex && chapterTitle.isNotEmpty) {
      return '第 ${chapterIndex + 1} 章 · $chapterTitle';
    }
    if (hasChapterIndex) {
      return '第 ${chapterIndex + 1} 章';
    }
    if (chapterTitle.isNotEmpty) {
      return chapterTitle;
    }
    return null;
  }

  String? _buildContinueReadingProgressLabel(double ratio) {
    final normalized = ratio.clamp(0.0, 1.0);
    if (normalized <= 0) {
      return null;
    }
    return '${(normalized * 100).round()}%';
  }

  String _formatRelativeReadTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) {
      return '刚刚阅读';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} 小时前';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    }
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  Future<void> _openFromBookshelf(
    BookshelfBook book, {
    ReadingProgress? progress,
  }) async {
    _cancelBackgroundLatestInfoRefresh();
    _cancelBackgroundRefreshForBook(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      bookId: book.bookId,
      byScene: SourceRuntimeConflictScene.reader,
    );
    if (_openingBookId != null) {
      return;
    }

    setState(() {
      _openingBookId = book.bookId;
    });

    try {
      final localBook =
          book.sourceId == _kLocalBookSourceId
              ? (_localBooksById[book.bookId.trim()] ??
                  await _localBookRepository.getBookById(book.bookId.trim()))
              : null;
      if (localBook != null &&
          localBook.format == LocalBookFormat.txt &&
          localBook.indexStatus != LocalBookIndexStatus.ready) {
        unawaited(() async {
          try {
            await _localBookIndexService.ensureIndexed(bookId: localBook.id);
          } catch (_) {
            // Keep reading available even if background indexing fails.
          }
        }());
        _openReaderFallbackForSourceSwitch(book);
        _showMessage('正文已打开，目录会在后台继续解析。');
        return;
      }
      if (localBook != null &&
          localBook.indexStatus != LocalBookIndexStatus.ready) {
        _handleNonReadyLocalBookOpen(book, localBook);
        return;
      }

      ReadingProgress? latestProgress;
      final bookKey = _bookKey(book);
      try {
        final loadedProgress = await _readerPreferencesService
            .loadProgress(book.bookId)
            .timeout(_kProgressLoadTimeout);
        if (loadedProgress != null &&
            _isProgressMatchingBook(loadedProgress, book)) {
          latestProgress = loadedProgress;
        } else {
          latestProgress = null;
        }
      } catch (_) {
        latestProgress = null;
      }

      final effectiveProgress = latestProgress ?? progress;
      if (effectiveProgress != null) {
        if (mounted &&
            latestProgress != null &&
            _progressByBookKey[bookKey] != latestProgress) {
          setState(() {
            _progressByBookKey = Map<String, ReadingProgress>.from(
              _progressByBookKey,
            )..[bookKey] = latestProgress!;
          });
        }
        _continueReading(effectiveProgress);
        return;
      }

      if (book.sourceId == _kLocalBookSourceId) {
        if (localBook == null) {
          _openBookDetail(book);
          _showMessage('未找到本地图书记录，请检查导入是否完成。');
          return;
        }

        final chapters = await _localBookRepository.getChapters(book.bookId);
        if (chapters.isEmpty) {
          _openBookDetail(book);
          _showMessage('本地图书目录尚未建立完成，请先在详情页重建目录。');
          return;
        }

        final firstChapter = Chapter(
          id: chapters.first.id,
          bookId: chapters.first.bookId,
          title: chapters.first.title,
          chapterUrl: 'local://chapter/${chapters.first.id}',
          index: chapters.first.chapterIndex,
        );
        final route = _readerEntryRouteResolver.buildRouteFromChapter(
          bookId: firstChapter.bookId,
          sourceId: book.sourceId,
          detailUrl: book.detailUrl,
          chapter: firstChapter,
        );
        if (!mounted) {
          return;
        }
        context.push(route);
        return;
      }

      final detailResult = await _bookDetailService.load(
        sourceId: book.sourceId,
        bookId: book.bookId,
        detailUrl: book.detailUrl,
        fallbackTitle: book.title,
      );

      if (!mounted) {
        return;
      }

      final chapter = detailResult.chapters.first;
      final route = _readerEntryRouteResolver.buildRouteFromChapter(
        bookId: chapter.bookId,
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
        chapter: chapter,
      );

      context.push(route);
    } on AppException {
      if (!mounted) {
        return;
      }
      _openReaderFallbackForSourceSwitch(book);
      _showMessage('当前书源可能不可用，可在阅读页直接换源。');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _openReaderFallbackForSourceSwitch(book);
      _showMessage('打开详情失败，已进入阅读页，可尝试换源。');
    } finally {
      if (mounted) {
        setState(() {
          _openingBookId = null;
        });
      }
    }
  }

  void _handleNonReadyLocalBookOpen(BookshelfBook book, LocalBook localBook) {
    switch (localBook.indexStatus) {
      case LocalBookIndexStatus.pending:
        _openBookDetail(book);
        _showMessage('这本本地图书正在等待建立目录，请稍后再试或在详情页重建。');
        return;
      case LocalBookIndexStatus.indexing:
        _openBookDetail(book);
        _showMessage('这本本地图书正在解析中，详情页会自动刷新。');
        return;
      case LocalBookIndexStatus.stale:
        _openBookDetail(book);
        _showMessage('检测到本地图书目录已过期，请先重建目录再阅读。');
        return;
      case LocalBookIndexStatus.failed:
        _openBookDetail(book);
        _showMessage('本地图书目录解析失败，请先重建目录再阅读。');
        return;
      case LocalBookIndexStatus.ready:
        return;
    }
  }

  Future<void> _repairLocalBookFromShelf(
    BookshelfBook book,
    LocalBook localBook,
  ) async {
    final normalizedBookId = book.bookId.trim();
    if (normalizedBookId.isEmpty ||
        _repairingLocalBookIds.contains(normalizedBookId)) {
      return;
    }

    setState(() {
      _repairingLocalBookIds.add(normalizedBookId);
    });

    try {
      await _localBookIndexService.ensureIndexed(
        bookId: normalizedBookId,
        force:
            localBook.indexStatus == LocalBookIndexStatus.stale ||
            localBook.indexStatus == LocalBookIndexStatus.failed,
      );
      await _loadBookshelf(force: true);
      if (!mounted) {
        return;
      }
      _showMessage(
        '《${_toSingleLineText(_displayBookTitle(book))}》目录已更新，可以继续阅读了。',
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.briefMessage);
      _openBookDetail(book);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('重建目录失败，请稍后重试。');
      _openBookDetail(book);
    } finally {
      if (mounted) {
        setState(() {
          _repairingLocalBookIds.remove(normalizedBookId);
        });
      }
    }
  }

  void _openReaderFallbackForSourceSwitch(BookshelfBook book) {
    _cancelBackgroundLatestInfoRefresh();
    _cancelBackgroundRefreshForBook(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      bookId: book.bookId,
      byScene: SourceRuntimeConflictScene.reader,
    );
    final route = _readerEntryRouteResolver.buildRouteFromBookshelfFallback(
      book,
    );
    context.push(route);
  }

  void _continueReading(ReadingProgress progress) {
    _cancelBackgroundLatestInfoRefresh();
    _cancelBackgroundRefreshForBook(
      sourceId: progress.sourceId,
      detailUrl: progress.detailUrl,
      bookId: progress.bookId,
      byScene: SourceRuntimeConflictScene.reader,
    );
    final route = _readerEntryRouteResolver.buildRouteFromProgress(progress);

    context.push(route);
  }

  void _openBookDetail(BookshelfBook book) {
    _cancelBackgroundLatestInfoRefresh();
    _cancelBackgroundRefreshForBook(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      bookId: book.bookId,
      byScene: SourceRuntimeConflictScene.detail,
    );
    if (_isBatchDeleting) {
      return;
    }

    final route = buildBookDetailRoute(
      bookId: book.bookId,
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      title: book.title,
    );
    context.push(route);
  }

  Future<void> _removeBook(
    BookshelfBook book, {
    bool reload = true,
    bool showFeedback = true,
  }) async {
    if (book.sourceId == _kLocalBookSourceId) {
      await _localBookImportService.removeLocalBook(
        bookId: book.bookId,
        detailUrl: book.detailUrl,
      );
    } else {
      await _bookshelfService.remove(
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
      );
    }

    if (reload) {
      await _loadBookshelf(force: true);
    }

    if (!mounted || !showFeedback) {
      return;
    }

    _showMessage('已从书架移除。');
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    String confirmText = '确认',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }
}

class _BookshelfPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _BookshelfPinnedHeaderDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _BookshelfPinnedHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}

class _BookSheetActionButton extends StatelessWidget {
  const _BookSheetActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: fg),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
