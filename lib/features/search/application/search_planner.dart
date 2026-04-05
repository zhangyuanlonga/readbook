part of 'search_service.dart';

class _SearchPlanner {
  const _SearchPlanner({
    required SourceRuntimeFacade? sourceRuntimeFacade,
    required _SearchRuntimeProfileService profileService,
  }) : _sourceRuntimeFacade = sourceRuntimeFacade,
       _profileService = profileService;

  final SourceRuntimeFacade? _sourceRuntimeFacade;
  final _SearchRuntimeProfileService _profileService;

  Future<_SearchPlan> buildPlan({
    required SearchContentMode contentMode,
    required SearchPlanScenario scenario,
    required Set<String>? sourceIds,
  }) async {
    final sources = await _loadAvailableScriptSources(contentMode: contentMode);
    var filteredSources =
        sourceIds == null || sourceIds.isEmpty
            ? sources
            : sources
                .where((source) => sourceIds.contains(source.runtime.id))
                .toList(growable: false);
    final skippedSourceIds = filteredSources
        .where(
          (source) =>
              _profileService.isCoolingDown(source.runtime.id) ||
              _profileService.isUnavailable(source.runtime.id),
        )
        .map((source) => source.runtime.id)
        .toList(growable: false);
    filteredSources = filteredSources
        .where(
          (source) =>
              !_profileService.isCoolingDown(source.runtime.id) &&
              !_profileService.isUnavailable(source.runtime.id),
        )
        .toList(growable: false);
    final allowInteractiveChallenge =
        scenario != SearchPlanScenario.autoSwitchSource;
    if (scenario == SearchPlanScenario.autoSwitchSource &&
        filteredSources.length > 8) {
      filteredSources = filteredSources.take(8).toList(growable: false);
    }
    final targets = filteredSources
        .map(
          (source) => _SearchTarget.script(
            source,
            profile: _profileService.resolveProfile(
              source: source,
              scenario: scenario,
              allowInteractiveChallenge: allowInteractiveChallenge,
            ),
          ),
        )
        .toList(growable: false);
    targets.sort((a, b) {
      final healthDiff =
          _profileService.healthPriority(a.sourceId)
              .compareTo(_profileService.healthPriority(b.sourceId));
      if (healthDiff != 0) {
        return healthDiff;
      }
      return a.sourceName.compareTo(b.sourceName);
    });
    final profileSummary = <SearchExecutionProfile, int>{};
    for (final target in targets) {
      profileSummary[target.profile] = (profileSummary[target.profile] ?? 0) + 1;
    }
    return _SearchPlan(
      sources: filteredSources,
      targets: targets,
      allowInteractiveChallenge: allowInteractiveChallenge,
      sourceNames: <String, String>{
        for (final source in filteredSources)
          source.runtime.id: source.runtime.name,
      },
      sourceOrderById: <String, int>{
        for (var index = 0; index < filteredSources.length; index++)
          filteredSources[index].runtime.id: index,
      },
      skippedSourceIds: List<String>.unmodifiable(skippedSourceIds),
      profileSummary: Map<SearchExecutionProfile, int>.unmodifiable(
        profileSummary,
      ),
    );
  }

  Future<List<RegisteredSource>> _loadAvailableScriptSources({
    required SearchContentMode contentMode,
  }) async {
    final facade = _sourceRuntimeFacade;
    if (facade == null) {
      return const <RegisteredSource>[];
    }

    var sources = facade.registeredScriptSources(enabledOnly: true);
    if (sources.isEmpty) {
      final report = await facade.reloadScriptSources();
      sources = report.loaded;
    }
    return _filterScriptSourcesByContentMode(
      sources: sources,
      contentMode: contentMode,
    );
  }

  List<RegisteredSource> _filterScriptSourcesByContentMode({
    required List<RegisteredSource> sources,
    required SearchContentMode contentMode,
  }) {
    return sources
        .where(
          (source) =>
              _matchesScriptSourceContentMode(source, contentMode: contentMode),
        )
        .toList(growable: false);
  }

  bool _matchesScriptSourceContentMode(
    RegisteredSource source, {
    required SearchContentMode contentMode,
  }) {
    final manifest = source.definition.manifest;
    final capabilities =
        manifest.capabilities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();
    final declaresManga =
        capabilities.contains('manga') ||
        capabilities.contains('comic') ||
        capabilities.contains('manhua') ||
        capabilities.contains('manhwa');
    final declaresNovel =
        capabilities.contains('novel') ||
        capabilities.contains('book') ||
        capabilities.contains('text');

    if (contentMode == SearchContentMode.manga) {
      return declaresManga;
    }

    if (declaresManga && !declaresNovel) {
      return false;
    }
    return true;
  }
}

class _SearchPlan {
  const _SearchPlan({
    required this.sources,
    required this.targets,
    required this.allowInteractiveChallenge,
    required this.sourceNames,
    required this.sourceOrderById,
    required this.skippedSourceIds,
    required this.profileSummary,
  });

  final List<RegisteredSource> sources;
  final List<_SearchTarget> targets;
  final bool allowInteractiveChallenge;
  final Map<String, String> sourceNames;
  final Map<String, int> sourceOrderById;
  final List<String> skippedSourceIds;
  final Map<SearchExecutionProfile, int> profileSummary;
}

class _SearchTarget {
  const _SearchTarget.script(
    this.scriptSource, {
    required this.profile,
  });

  final RegisteredSource scriptSource;
  final SearchExecutionProfile profile;

  String get sourceId => scriptSource.runtime.id;

  String get sourceName => scriptSource.runtime.name;
}
