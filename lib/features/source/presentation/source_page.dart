import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/layout/app_adaptive.dart';
import '../../../app/platform/app_input_focus_behavior.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/app_task_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/import_export_task_sheet.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../app/widgets/adaptive_search_bar.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../domain/entities/script_source.dart';
import '../../../domain/entities/source_health.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../application/external_import_catalog.dart';
import '../application/external_import_diagnostics.dart';
import '../application/external_source_import_bridge.dart';
import '../application/source_health_action_policy_service.dart';
import '../application/source_login_entry_resolver.dart';
import '../application/source_check_service.dart';
import '../application/source_page_access_service.dart';
import '../application/source_health_service.dart';
import '../application/source_page_flow_coordinator.dart';
import '../application/source_script_import_service.dart';
import '../application/source_runtime_facade.dart';
import '../providers.dart';
import 'source_login_page.dart';
import 'source_web_login_page.dart';
import 'script_source_debug_page.dart';

part 'source_page_dialogs.dart';
part 'source_page_flow.dart';
part 'source_page_batch_check.dart';

enum _ScriptSourceSortOption { updatedDesc, nameAsc, nameDesc }

enum _SourcePageMenuAction {
  create,
  importLocal,
  importNetwork,
  importPaste,
  batchCheck,
}

enum _SourceItemMenuAction { login, debug, check, export, delete }

enum _BatchCheckScope {
  selectedSources,
  enabledSources,
  filteredEnabledSources,
  recentFailedSources,
  coolingDownSources,
}

class _BatchCheckRequest {
  const _BatchCheckRequest({
    required this.keyword,
    required this.level,
    required this.scope,
  });

  final String keyword;
  final SourceCheckLevel level;
  final _BatchCheckScope scope;
}

enum _SourceExportEntryMode { prepare, processing, completed }

class _BatchCheckProgressState {
  const _BatchCheckProgressState({
    required this.completedCount,
    required this.totalCount,
    required this.results,
    this.currentSourceName,
    this.finished = false,
  });

  final int completedCount;
  final int totalCount;
  final List<SourceCheckResult> results;
  final String? currentSourceName;
  final bool finished;

  _BatchCheckProgressState copyWith({
    int? completedCount,
    int? totalCount,
    List<SourceCheckResult>? results,
    Object? currentSourceName = _batchCheckSentinel,
    bool? finished,
  }) {
    return _BatchCheckProgressState(
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
      results: results ?? this.results,
      currentSourceName:
          identical(currentSourceName, _batchCheckSentinel)
              ? this.currentSourceName
              : currentSourceName as String?,
      finished: finished ?? this.finished,
    );
  }
}

const Object _batchCheckSentinel = Object();

class _SourceSuggestionAction {
  const _SourceSuggestionAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;
}

enum _SourceImportEntryMode { add, processing, completed }

class _SourceWebsiteClusterSummary {
  const _SourceWebsiteClusterSummary({
    required this.key,
    required this.title,
    required this.sourceCount,
    required this.healthSummary,
    required this.recommendedSourceId,
  });

  final String key;
  final String title;
  final int sourceCount;
  final String healthSummary;
  final String? recommendedSourceId;
}

class SourcePage extends ConsumerStatefulWidget {
  const SourcePage({
    super.key,
    this.sourceRuntimeFacade,
    this.sourceCheckService,
    this.sourceHealthService,
    this.bootstrapOnInit = true,
    this.enableRouterNavigation = true,
  });

  final SourceRuntimeFacade? sourceRuntimeFacade;
  final SourceCheckService? sourceCheckService;
  final SourceHealthService? sourceHealthService;
  final bool bootstrapOnInit;
  final bool enableRouterNavigation;

  @override
  ConsumerState<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends ConsumerState<SourcePage> {
  static const String _ungroupedGroupKey = '__ungrouped__';
  static const String _duplicateGroupKey = '__duplicate__';
  late final SourceRuntimeFacade _sourceRuntimeFacade;
  late final SourceCheckService _sourceCheckService;
  late final SourceHealthService _sourceHealthService;
  late final SourceHealthActionPolicyService _policyService;
  late final TextEditingController _searchController;
  late final SourceLoginEntryResolver _sourceLoginEntryResolver;
  late final SourcePageFlowCoordinator _pageFlowCoordinator;
  late final SourcePageAccessService _accessService;
  late final SourceScriptImportService _importService;
  List<ScriptSource> _lastRawSources = const <ScriptSource>[];
  List<ScriptSource> _lastVisibleSources = const <ScriptSource>[];
  List<ScriptSource> _cachedVisibleSources = const <ScriptSource>[];
  List<ScriptSource> _cachedFilteredVisibleSources = const <ScriptSource>[];
  List<String> _cachedAvailableGroups = const <String>[];
  Map<String, _SourceWebsiteClusterSummary> _cachedClusterSummaries =
      const <String, _SourceWebsiteClusterSummary>{};
  Object? _derivedSourceViewFingerprint;

  String _searchQuery = '';
  String? _selectedGroupKey;
  _ScriptSourceSortOption _sortOption = _ScriptSourceSortOption.updatedDesc;
  final Set<String> _selectedBatchSourceIds = <String>{};
  final Set<String> _changingEnabledScriptSourceIds = <String>{};
  final Set<String> _deletingScriptSourceIds = <String>{};
  final Dio _importDio = Dio();
  bool _isConsumingExternalImportPayloads = false;
  bool _isFeatureAccessLoading = true;
  bool _canAccessSourcePage = false;
  int _sourceImportLimit = 10;
  ImportExportTaskStatus? _taskStatus;

  @override
  void initState() {
    super.initState();
    _sourceRuntimeFacade =
        widget.sourceRuntimeFacade ?? ref.read(sourceRuntimeFacadeProvider);
    _sourceCheckService =
        widget.sourceCheckService ?? ref.read(sourceCheckServiceProvider);
    _sourceHealthService =
        widget.sourceHealthService ?? ref.read(sourceHealthServiceProvider);
    _policyService = const SourceHealthActionPolicyService();
    _sourceLoginEntryResolver = ref.read(sourceLoginEntryResolverProvider);
    _pageFlowCoordinator = ref.read(sourcePageFlowCoordinatorFactoryProvider)();
    _accessService = ref.read(sourcePageAccessServiceProvider);
    _importService = ref.read(sourceScriptImportServiceProvider);
    _searchController = TextEditingController();
    _pageFlowCoordinator.initialize(
      onPendingImportAvailable: () {
        unawaited(_consumePendingExternalImportPayloads());
      },
      onAuthEvent: _handleAuthEvent,
    );
    if (widget.bootstrapOnInit) {
      unawaited(_reloadScriptSourcesSilently());
    }
    unawaited(_loadFeatureAccess());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
    });
  }

  @override
  void dispose() {
    unawaited(_pageFlowCoordinator.dispose());
    _searchController.dispose();
    super.dispose();
  }

  void _updateSourcePageState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  @override
  Widget build(BuildContext context) => _buildSourcePage(context);

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
