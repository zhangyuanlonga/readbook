import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/book_identity.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/managed_asset.dart';
import '../../../domain/entities/reading_book_status.dart';
import '../../../domain/entities/reading_record_session.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/script_source.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../../domain/repositories/script_source_repository.dart';
import '../../../features/bookshelf/application/bookshelf_service.dart';
import '../../../features/mine/application/advanced_theme_service.dart';
import '../../../features/reader/application/reader_preferences_service.dart';
import '../../../features/reader/application/reading_book_status_service.dart';
import '../../../features/reader/application/reading_record_service.dart';
import '../../../features/source/application/source_runtime_facade.dart';
import '../../../core/logging/app_logger.dart';
import '../data/local/sync_local_store.dart';
import '../data/remote/webdav_sync_remote_driver.dart';
import '../domain/sync_conflict.dart';
import '../domain/sync_job.dart';
import '../domain/sync_profile.dart';
import '../domain/sync_remote_driver.dart';
import '../domain/sync_scope.dart';
import '../domain/sync_scope_state.dart';
import 'sync_profile_service.dart';
import 'sync_remote_bootstrap_service.dart';

class SyncRunResult {
  const SyncRunResult({
    required this.job,
    required this.succeeded,
    required this.message,
  });

  final SyncJob job;
  final bool succeeded;
  final String message;
}

class SyncStage4Service {
  SyncStage4Service({
    required SyncProfileService profileService,
    required SyncLocalStore localStore,
    required SyncRemoteBootstrapService remoteBootstrapService,
    required ReaderPreferencesService readerPreferencesService,
    required BookmarkRepository bookmarkRepository,
    required BookMetadataOverrideRepository bookMetadataOverrideRepository,
    required ScriptSourceRepository scriptSourceRepository,
    required ReadingBookStatusService readingBookStatusService,
    required ReadingRecordService readingRecordService,
    required LocalBookRepository localBookRepository,
    required BookshelfService bookshelfService,
    required AdvancedThemeService advancedThemeService,
    required SourceRuntimeFacade sourceRuntimeFacade,
    AppLogger? logger,
    Uuid? uuid,
  }) : _profileService = profileService,
       _localStore = localStore,
       _remoteBootstrapService = remoteBootstrapService,
       _readerPreferencesService = readerPreferencesService,
       _bookmarkRepository = bookmarkRepository,
       _bookMetadataOverrideRepository = bookMetadataOverrideRepository,
       _scriptSourceRepository = scriptSourceRepository,
       _readingBookStatusService = readingBookStatusService,
       _readingRecordService = readingRecordService,
       _localBookRepository = localBookRepository,
       _bookshelfService = bookshelfService,
       _advancedThemeService = advancedThemeService,
       _sourceRuntimeFacade = sourceRuntimeFacade,
       _logger = logger ?? AppLogger.instance,
       _uuid = uuid ?? const Uuid();

  final SyncProfileService _profileService;
  final SyncLocalStore _localStore;
  final SyncRemoteBootstrapService _remoteBootstrapService;
  final ReaderPreferencesService _readerPreferencesService;
  final BookmarkRepository _bookmarkRepository;
  final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  final ScriptSourceRepository _scriptSourceRepository;
  final ReadingBookStatusService _readingBookStatusService;
  final ReadingRecordService _readingRecordService;
  final LocalBookRepository _localBookRepository;
  final BookshelfService _bookshelfService;
  final AdvancedThemeService _advancedThemeService;
  final SourceRuntimeFacade _sourceRuntimeFacade;
  final AppLogger _logger;
  final Uuid _uuid;

  static const List<SyncScope> _supportedScopes = <SyncScope>[
    SyncScope.readingProgress,
    SyncScope.bookmarks,
    SyncScope.scriptSources,
    SyncScope.readingBookStatuses,
    SyncScope.bookMetadataOverrides,
    SyncScope.bookMetadataAssets,
    SyncScope.advancedThemePresets,
    SyncScope.advancedThemeAssets,
    SyncScope.readingHistory,
    SyncScope.readingStats,
    SyncScope.bookshelfCollection,
    SyncScope.bookshelfTaxonomy,
  ];

  Future<SyncRunResult> run(String profileId) async {
    final profile = await _profileService.getProfileById(profileId);
    if (profile == null) {
      throw const FormatException('未找到要执行同步的配置。');
    }
    final secretRef = profile.secretRef?.trim() ?? '';
    if (secretRef.isEmpty) {
      throw const FormatException('同步配置缺少密码引用。');
    }
    final password = await _profileService.loadPassword(secretRef);
    if (password == null || password.isEmpty) {
      throw const FormatException('未找到同步密码。');
    }

    final enabledScopes = _supportedScopes
        .where((scope) => profile.enabledScopes.contains(scope))
        .toList(growable: false);
    if (enabledScopes.isEmpty) {
      throw const FormatException('当前配置未启用任何已实现的同步项。');
    }

    final runningJob = SyncJob(
      id: 'sync_job_${_uuid.v4()}',
      profileId: profile.id,
      triggerKind: SyncJobTriggerKind.manual,
      status: SyncJobStatus.running,
      startedAt: DateTime.now().toUtc(),
    );
    await _localStore.saveJob(runningJob);

    try {
      final localBookIds =
          (await _localBookRepository.getAllBooks())
              .map((item) => item.id.trim())
              .where((item) => item.isNotEmpty)
              .toSet();
      final driver = WebDavSyncRemoteDriver(
        endpointUrl: profile.endpointUrl,
        basePath: profile.basePath,
        username: profile.username,
        password: password,
      );
      await _remoteBootstrapService.ensureWebDavReady(
        profile: profile,
        driver: driver,
      );

      for (final scope in enabledScopes) {
        switch (scope) {
          case SyncScope.readingProgress:
            await _syncReadingProgress(
              profile: profile,
              driver: driver,
              localBookIds: localBookIds,
            );
          case SyncScope.bookmarks:
            await _syncBookmarks(
              profile: profile,
              driver: driver,
              localBookIds: localBookIds,
            );
          case SyncScope.scriptSources:
            await _syncScriptSources(profile: profile, driver: driver);
          case SyncScope.readingBookStatuses:
            await _syncReadingBookStatuses(
              profile: profile,
              driver: driver,
              localBookIds: localBookIds,
            );
          case SyncScope.bookMetadataOverrides:
            await _syncBookMetadataOverrides(profile: profile, driver: driver);
          case SyncScope.bookMetadataAssets:
            await _syncBookMetadataAssets(profile: profile, driver: driver);
          case SyncScope.advancedThemePresets:
            await _syncAdvancedThemePresets(profile: profile, driver: driver);
          case SyncScope.advancedThemeAssets:
            await _syncAdvancedThemeAssets(profile: profile, driver: driver);
          case SyncScope.readingHistory:
            await _syncReadingHistory(
              profile: profile,
              driver: driver,
              localBookIds: localBookIds,
            );
          case SyncScope.readingStats:
            await _syncReadingStats(profile: profile, driver: driver);
          case SyncScope.bookshelfCollection:
            await _syncBookshelfCollection(profile: profile, driver: driver);
          case SyncScope.bookshelfTaxonomy:
            await _syncBookshelfTaxonomy(profile: profile, driver: driver);
          default:
            continue;
        }
      }

      final completed = runningJob.copyWith(
        status: SyncJobStatus.success,
        endedAt: DateTime.now().toUtc(),
        summaryJson: jsonEncode(<String, Object?>{
          'scopes': enabledScopes.map((item) => item.name).toList(),
          'count': enabledScopes.length,
        }),
      );
      await _localStore.saveJob(completed);
      await _localStore.saveProfile(
        profile.copyWith(
          lastSyncAt: completed.endedAt,
          updatedAt: completed.endedAt ?? DateTime.now().toUtc(),
        ),
      );
      return SyncRunResult(
        job: completed,
        succeeded: true,
        message: '同步已完成：${enabledScopes.map((item) => item.name).join(', ')}',
      );
    } catch (error) {
      final failed = runningJob.copyWith(
        status: SyncJobStatus.failed,
        endedAt: DateTime.now().toUtc(),
        errorMessage: error.toString(),
      );
      await _localStore.saveJob(failed);
      _logger.warn(
        'Stage4 sync failed',
        context: <String, Object?>{
          'profileId': profile.id,
          'error': error.toString(),
        },
      );
      return SyncRunResult(
        job: failed,
        succeeded: false,
        message: '同步失败：$error',
      );
    }
  }

  Future<void> _syncReadingProgress({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
    required Set<String> localBookIds,
  }) async {
    final localItems = (await _readerPreferencesService.loadAllProgresses())
        .where(
          (item) =>
              !_looksLikeLocalScopedBook(
                bookId: item.bookId,
                sourceId: item.sourceId,
                localBookIds: localBookIds,
              ),
        )
        .toList(growable: false);

    await _syncScope<ReadingProgress>(
      profile: profile,
      scope: SyncScope.readingProgress,
      driver: driver,
      localItems: localItems,
      keyOf: _readingProgressKeyOf,
      updatedAtOf: (item) => item.updatedAt,
      toJson: (item) => item.toJson(),
      fromJson: (json) => ReadingProgress.fromJson(json),
      applyMerged: (merged) async {
        final existing = await _readerPreferencesService.loadAllProgresses();
        final managedKeys =
            existing
                .where(
                  (item) =>
                      !_looksLikeLocalScopedBook(
                        bookId: item.bookId,
                        sourceId: item.sourceId,
                        localBookIds: localBookIds,
                      ),
                )
                .map(_readingProgressKeyOf)
                .toSet();
        final mergedKeys = merged.map(_readingProgressKeyOf).toSet();
        for (final item in merged) {
          await _readerPreferencesService.saveProgress(item);
        }
        for (final existingItem in existing) {
          final key = _readingProgressKeyOf(existingItem);
          if (!managedKeys.contains(key) || mergedKeys.contains(key)) {
            continue;
          }
          await _readerPreferencesService.deleteProgress(existingItem.bookId);
        }
      },
    );
  }

  Future<void> _syncBookmarks({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
    required Set<String> localBookIds,
  }) async {
    final localItems = (await _bookmarkRepository.listAllBookmarks())
        .where((item) => !localBookIds.contains(item.bookId.trim()))
        .toList(growable: false);

    await _syncScope<Bookmark>(
      profile: profile,
      scope: SyncScope.bookmarks,
      driver: driver,
      localItems: localItems,
      keyOf: (item) => item.id,
      updatedAtOf: (item) => item.updatedAt,
      toJson: (item) => item.toJson(),
      fromJson: (json) => Bookmark.fromJson(json),
      applyMerged: (merged) async {
        final existing = await _bookmarkRepository.listAllBookmarks();
        final managedExisting = existing
            .where((item) => !localBookIds.contains(item.bookId.trim()))
            .toList(growable: false);
        final mergedIds = merged.map((item) => item.id).toSet();
        for (final item in merged) {
          await _bookmarkRepository.addBookmark(item);
        }
        for (final item in managedExisting) {
          if (mergedIds.contains(item.id)) {
            continue;
          }
          await _bookmarkRepository.removeBookmark(item.id);
        }
      },
    );
  }

  Future<void> _syncScriptSources({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
  }) async {
    final localItems = await _scriptSourceRepository.getAll();
    await _syncScope<ScriptSource>(
      profile: profile,
      scope: SyncScope.scriptSources,
      driver: driver,
      localItems: localItems,
      keyOf: (item) => item.id,
      updatedAtOf: (item) => item.updatedAt,
      toJson: (item) => item.toJson(),
      fromJson: (json) => ScriptSource.fromJson(json),
      applyMerged: (merged) async {
        final existing = await _scriptSourceRepository.getAll();
        final mergedIds = merged.map((item) => item.id).toSet();
        for (final item in merged) {
          await _scriptSourceRepository.upsert(item);
        }
        for (final item in existing) {
          if (mergedIds.contains(item.id)) {
            continue;
          }
          await _scriptSourceRepository.deleteById(item.id);
        }
        await _sourceRuntimeFacade.reloadScriptSources();
      },
    );
  }

  Future<void> _syncReadingBookStatuses({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
    required Set<String> localBookIds,
  }) async {
    final localItems = (await _readingBookStatusService.listManualStatuses())
        .where(
          (item) =>
              !_looksLikeLocalScopedBook(
                bookId: item.bookId,
                sourceId: item.sourceId,
                localBookIds: localBookIds,
              ),
        )
        .toList(growable: false);

    await _syncScope<ReadingBookStatusEntry>(
      profile: profile,
      scope: SyncScope.readingBookStatuses,
      driver: driver,
      localItems: localItems,
      keyOf: _readingStatusKeyOf,
      updatedAtOf: (item) => item.updatedAt,
      toJson: _readingBookStatusToJson,
      fromJson: _readingBookStatusFromJson,
      applyMerged: (merged) async {
        final existing = await _readingBookStatusService.listManualStatuses();
        final managedExisting = existing
            .where(
              (item) =>
                  !_looksLikeLocalScopedBook(
                    bookId: item.bookId,
                    sourceId: item.sourceId,
                    localBookIds: localBookIds,
                  ),
            )
            .toList(growable: false);
        final mergedKeys = merged.map(_readingStatusKeyOf).toSet();
        for (final item in merged) {
          await _readingBookStatusService.upsertManualStatus(item);
        }
        for (final item in managedExisting) {
          final key = _readingStatusKeyOf(item);
          if (mergedKeys.contains(key)) {
            continue;
          }
          await _readingBookStatusService.clearManualStatus(item.bookId);
        }
      },
    );
  }

  Future<void> _syncBookMetadataOverrides({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
  }) async {
    final localItems = (await _bookMetadataOverrideRepository.getAll())
        .where((item) => !item.isLocalScope)
        .toList(growable: false);

    await _syncScope<BookMetadataOverride>(
      profile: profile,
      scope: SyncScope.bookMetadataOverrides,
      driver: driver,
      localItems: localItems,
      keyOf: (item) => item.targetKey,
      updatedAtOf: (item) => item.updatedAt,
      toJson: _bookMetadataOverrideToJson,
      fromJson: _bookMetadataOverrideFromJson,
      applyMerged: (merged) async {
        final existing = await _bookMetadataOverrideRepository.getAll();
        final managedExisting = existing
            .where((item) => !item.isLocalScope)
            .toList(growable: false);
        final mergedKeys = merged.map((item) => item.targetKey).toSet();
        for (final item in merged) {
          await _bookMetadataOverrideRepository.upsert(item);
        }
        for (final item in managedExisting) {
          if (mergedKeys.contains(item.targetKey)) {
            continue;
          }
          await _bookMetadataOverrideRepository.deleteByTargetKey(
            item.targetKey,
          );
        }
      },
    );
  }

  Future<void> _syncAdvancedThemePresets({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
  }) async {
    final scope = SyncScope.advancedThemePresets;
    final state = await _localStore.getScopeState(
      profileId: profile.id,
      scope: scope,
    );
    final baseSnapshot = _decodeAdvancedThemePresetSnapshot(
      state?.lastBaseSnapshotJson,
    );
    final remotePath = 'datasets/${scope.datasetFileName}';
    final remoteStat = await driver.stat(remotePath);
    final remoteSnapshot = _decodeAdvancedThemePresetSnapshot(
      await driver.readText(remotePath),
    );
    final localSnapshot = _AdvancedThemePresetSnapshot(
      themes: await _advancedThemeService.loadThemes(),
      activeThemeId: await _advancedThemeService.loadActiveThemeId(),
    );
    final mergedSnapshot = _mergeAdvancedThemePresetSnapshot(
      base: baseSnapshot,
      local: localSnapshot,
      remote: remoteSnapshot,
    );

    await _advancedThemeService.saveThemes(mergedSnapshot.themes);
    await _advancedThemeService.saveActiveThemeId(mergedSnapshot.activeThemeId);

    final envelope = _encodeAdvancedThemePresetSnapshot(mergedSnapshot);
    await _persistScopeEnvelope(
      profile: profile,
      scope: scope,
      driver: driver,
      remotePath: remotePath,
      previousRemoteRevision: remoteStat?.revision,
      payload: envelope,
      previousState: state,
    );
  }

  Future<void> _syncBookMetadataAssets({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
  }) async {
    final localAssets = await _loadLocalBookMetadataAssets();
    await _syncScope<_SyncAssetItem>(
      profile: profile,
      scope: SyncScope.bookMetadataAssets,
      driver: driver,
      localItems: localAssets,
      keyOf: (item) => item.relativePath,
      updatedAtOf: (item) => item.updatedAt,
      toJson: (item) => item.toJson(),
      fromJson: (json) => _SyncAssetItem.fromJson(json),
      applyMerged: (merged) async {
        for (final item in merged) {
          await _writeAssetItem(item);
        }
      },
    );
  }

  Future<void> _syncAdvancedThemeAssets({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
  }) async {
    final localAssets = await _loadLocalAdvancedThemeAssets();
    await _syncScope<_SyncAssetItem>(
      profile: profile,
      scope: SyncScope.advancedThemeAssets,
      driver: driver,
      localItems: localAssets,
      keyOf: (item) => item.relativePath,
      updatedAtOf: (item) => item.updatedAt,
      toJson: (item) => item.toJson(),
      fromJson: (json) => _SyncAssetItem.fromJson(json),
      applyMerged: (merged) async {
        for (final item in merged) {
          await _writeAssetItem(item);
        }
      },
    );
  }

  Future<void> _syncReadingHistory({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
    required Set<String> localBookIds,
  }) async {
    final localItems = (await _readingRecordService.listAllSessions())
        .where(
          (item) =>
              !_looksLikeLocalScopedBook(
                bookId: item.bookId,
                sourceId: item.sourceId,
                localBookIds: localBookIds,
              ),
        )
        .map((item) => _SyncHistorySessionItem.fromSession(item))
        .toList(growable: false);

    await _syncScope<_SyncHistorySessionItem>(
      profile: profile,
      scope: SyncScope.readingHistory,
      driver: driver,
      localItems: localItems,
      keyOf: (item) => item.syncKey,
      updatedAtOf: (item) => item.updatedAt,
      toJson: (item) => item.toJson(),
      fromJson: (json) => _SyncHistorySessionItem.fromJson(json),
      applyMerged: (merged) async {
        await _readingRecordService.replaceRemoteScopedHistoryFromSync(
          merged.map((item) => item.toSession()).toList(growable: false),
        );
      },
    );
  }

  Future<void> _syncReadingStats({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
  }) async {
    final scope = SyncScope.readingStats;
    final state = await _localStore.getScopeState(
      profileId: profile.id,
      scope: scope,
    );
    final latestRecords = await _readingRecordService.listLatestRecords();
    final allDays = await _readingRecordService.listAllDays();
    final allSessions = await _readingRecordService.listAllSessions();
    final payload = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'scope': scope.name,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'summary': <String, Object?>{
        'latestRecordCount': latestRecords.length,
        'dayCount': allDays.length,
        'sessionCount': allSessions.length,
        'totalReadMillis': latestRecords.fold<int>(
          0,
          (sum, item) => sum + item.totalReadMillis,
        ),
        'totalReadChars': latestRecords.fold<int>(
          0,
          (sum, item) => sum + item.totalReadChars,
        ),
      },
    });
    await _persistScopeEnvelope(
      profile: profile,
      scope: scope,
      driver: driver,
      remotePath: 'datasets/${scope.datasetFileName}',
      previousRemoteRevision:
          (await driver.stat('datasets/${scope.datasetFileName}'))?.revision,
      payload: payload,
      previousState: state,
    );
  }

  Future<void> _syncBookshelfCollection({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
  }) async {
    final localItems = (await _bookshelfService.getAll())
        .where((item) => !isLocalBookSourceId(item.sourceId))
        .toList(growable: false);

    await _syncScope<BookshelfBook>(
      profile: profile,
      scope: SyncScope.bookshelfCollection,
      driver: driver,
      localItems: localItems,
      keyOf: _bookshelfBookKeyOf,
      updatedAtOf: (item) => item.addedAt,
      toJson: (item) => item.toJson(),
      fromJson: (json) => BookshelfBook.fromJson(json),
      applyMerged: (merged) async {
        final existing = await _bookshelfService.getAll();
        final localScoped = existing
            .where((item) => isLocalBookSourceId(item.sourceId))
            .toList(growable: false);
        final orderedMerged = List<BookshelfBook>.from(merged)
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
        await _bookshelfService.replaceAllForSync(<BookshelfBook>[
          ...localScoped,
          ...orderedMerged,
        ]);
      },
    );
  }

  Future<void> _syncBookshelfTaxonomy({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
  }) async {
    final scope = SyncScope.bookshelfTaxonomy;
    final state = await _localStore.getScopeState(
      profileId: profile.id,
      scope: scope,
    );
    final baseSnapshot = _decodeBookshelfTaxonomySnapshot(
      state?.lastBaseSnapshotJson,
    );
    final remotePath = 'datasets/${scope.datasetFileName}';
    final remoteStat = await driver.stat(remotePath);
    final remoteSnapshot = _decodeBookshelfTaxonomySnapshot(
      await driver.readText(remotePath),
    );
    final localSnapshot = _BookshelfTaxonomySnapshot(
      tagMap: await _bookshelfService.getTagMap(),
      tagOrder: await _bookshelfService.getTagOrder(),
      categoryOrder: await _bookshelfService.getCategoryOrder(),
      baseFilterOrder: await _bookshelfService.getBaseFilterOrder(),
    );
    final mergedSnapshot = _mergeBookshelfTaxonomySnapshot(
      base: baseSnapshot,
      local: localSnapshot,
      remote: remoteSnapshot,
    );

    await _bookshelfService.replaceTagMapForSync(mergedSnapshot.tagMap);
    await _bookshelfService.saveTagOrder(mergedSnapshot.tagOrder);
    await _bookshelfService.saveCategoryOrder(mergedSnapshot.categoryOrder);
    await _bookshelfService.saveBaseFilterOrder(mergedSnapshot.baseFilterOrder);

    final envelope = _encodeBookshelfTaxonomySnapshot(mergedSnapshot);
    await _persistScopeEnvelope(
      profile: profile,
      scope: scope,
      driver: driver,
      remotePath: remotePath,
      previousRemoteRevision: remoteStat?.revision,
      payload: envelope,
      previousState: state,
    );
  }

  Future<void> _syncScope<T>({
    required SyncProfile profile,
    required SyncScope scope,
    required SyncRemoteDriver driver,
    required List<T> localItems,
    required String Function(T item) keyOf,
    required DateTime Function(T item) updatedAtOf,
    required Map<String, dynamic> Function(T item) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
    required Future<void> Function(List<T> merged) applyMerged,
  }) async {
    final state = await _localStore.getScopeState(
      profileId: profile.id,
      scope: scope,
    );
    final baseItems = _decodeEnvelope<T>(
      raw: state?.lastBaseSnapshotJson,
      fromJson: fromJson,
    );
    final remotePath = 'datasets/${scope.datasetFileName}';
    final remoteStat = await driver.stat(remotePath);
    final remoteRaw = await driver.readText(remotePath);
    final remoteItems = _decodeEnvelope<T>(raw: remoteRaw, fromJson: fromJson);
    final merged = _mergeItems(
      scope: scope,
      baseItems: baseItems,
      localItems: localItems,
      remoteItems: remoteItems,
      keyOf: keyOf,
      updatedAtOf: updatedAtOf,
      toJson: toJson,
      profileId: profile.id,
    );

    await applyMerged(merged);
    final mergedEnvelope = _encodeEnvelope(
      scope: scope,
      items: merged.map(toJson).toList(growable: false),
    );
    await driver.writeText(
      remotePath,
      mergedEnvelope,
      ifMatchRevision: remoteStat?.revision,
    );
    final updatedRemoteStat = await driver.stat(remotePath);
    final now = DateTime.now().toUtc();
    await _localStore.saveScopeState(
      SyncScopeState(
        profileId: profile.id,
        scope: scope,
        lastBaseSnapshotJson: mergedEnvelope,
        lastRemoteRevision: updatedRemoteStat?.revision,
        lastRemoteHash: _hashContent(mergedEnvelope),
        lastLocalHash: _hashContent(mergedEnvelope),
        lastSyncedAt: now,
        createdAt: state?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    await _updateManifestDataset(
      driver: driver,
      profile: profile,
      scope: scope,
      revision: updatedRemoteStat?.revision,
      payload: mergedEnvelope,
    );
  }

  List<T> _mergeItems<T>({
    required SyncScope scope,
    required List<T> baseItems,
    required List<T> localItems,
    required List<T> remoteItems,
    required String Function(T item) keyOf,
    required DateTime Function(T item) updatedAtOf,
    required Map<String, dynamic> Function(T item) toJson,
    required String profileId,
  }) {
    final baseByKey = <String, T>{
      for (final item in baseItems) keyOf(item): item,
    };
    final localByKey = <String, T>{
      for (final item in localItems) keyOf(item): item,
    };
    final remoteByKey = <String, T>{
      for (final item in remoteItems) keyOf(item): item,
    };

    final allKeys = <String>{
      ...baseByKey.keys,
      ...localByKey.keys,
      ...remoteByKey.keys,
    };

    final merged = <T>[];
    for (final key in allKeys) {
      final base = baseByKey[key];
      final local = localByKey[key];
      final remote = remoteByKey[key];
      final resolved = _resolveItem(
        scope: scope,
        key: key,
        base: base,
        local: local,
        remote: remote,
        updatedAtOf: updatedAtOf,
        toJson: toJson,
        profileId: profileId,
      );
      if (resolved != null) {
        merged.add(resolved);
      }
    }
    merged.sort((a, b) => updatedAtOf(b).compareTo(updatedAtOf(a)));
    return List<T>.unmodifiable(merged);
  }

  T? _resolveItem<T>({
    required SyncScope scope,
    required String key,
    required T? base,
    required T? local,
    required T? remote,
    required DateTime Function(T item) updatedAtOf,
    required Map<String, dynamic> Function(T item) toJson,
    required String profileId,
  }) {
    if (local != null && remote != null) {
      final localJson = jsonEncode(toJson(local));
      final remoteJson = jsonEncode(toJson(remote));
      if (localJson == remoteJson) {
        return local;
      }
      final localChanged =
          base == null || jsonEncode(toJson(base)) != localJson;
      final remoteChanged =
          base == null || jsonEncode(toJson(base)) != remoteJson;
      if (localChanged && remoteChanged) {
        final localAt = updatedAtOf(local);
        final remoteAt = updatedAtOf(remote);
        final resolved =
            localAt.isAfter(remoteAt) || localAt == remoteAt ? local : remote;
        unawaited(
          _localStore.saveConflict(
            SyncConflict(
              id: 'sync_conflict_${_uuid.v4()}',
              profileId: profileId,
              scope: scope,
              recordKey: key,
              basePayloadJson: base == null ? null : jsonEncode(toJson(base)),
              localPayloadJson: localJson,
              remotePayloadJson: remoteJson,
              resolution:
                  resolved == local
                      ? SyncConflictResolution.localWon
                      : SyncConflictResolution.remoteWon,
              createdAt: DateTime.now().toUtc(),
              resolvedAt: DateTime.now().toUtc(),
            ),
          ),
        );
        return resolved;
      }
      return localChanged ? local : remote;
    }

    if (local != null) {
      if (base == null) {
        return local;
      }
      final baseJson = jsonEncode(toJson(base));
      final localJson = jsonEncode(toJson(local));
      final localChanged = baseJson != localJson;
      return localChanged ? local : null;
    }

    if (remote != null) {
      if (base == null) {
        return remote;
      }
      final baseJson = jsonEncode(toJson(base));
      final remoteJson = jsonEncode(toJson(remote));
      final remoteChanged = baseJson != remoteJson;
      return remoteChanged ? remote : null;
    }

    return null;
  }

  List<T> _decodeEnvelope<T>({
    required String? raw,
    required T Function(Map<String, dynamic> json) fromJson,
  }) {
    final normalized = (raw ?? '').trim();
    if (normalized.isEmpty) {
      return List<T>.empty(growable: false);
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return List<T>.empty(growable: false);
      }
      final items = decoded['items'];
      if (items is! List) {
        return List<T>.empty(growable: false);
      }
      return items
          .whereType<Map>()
          .map(
            (item) => fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return List<T>.empty(growable: false);
    }
  }

  String _encodeEnvelope({
    required SyncScope scope,
    required List<Map<String, dynamic>> items,
  }) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'scope': scope.name,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'items': items,
    });
  }

  Future<void> _updateManifestDataset({
    required SyncRemoteDriver driver,
    required SyncProfile profile,
    required SyncScope scope,
    required String? revision,
    required String payload,
  }) async {
    final existing = await driver.readText('manifest.json');
    final decoded =
        (existing ?? '').trim().isEmpty
            ? <String, Object?>{}
            : jsonDecode(existing!) as Map<String, Object?>;
    final datasets =
        (decoded['datasets'] is Map)
            ? Map<String, Object?>.from(decoded['datasets'] as Map)
            : <String, Object?>{};
    datasets[scope.name] = <String, Object?>{
      'path': 'datasets/${scope.datasetFileName}',
      'hash': _hashContent(payload),
      'revision': revision,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final updatedManifest = jsonEncode(<String, Object?>{
      'schemaVersion': decoded['schemaVersion'] ?? 1,
      'app': decoded['app'] ?? 'selune',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': <String, Object?>{
        'id': profile.id,
        'name': profile.name,
        'driverType': profile.driverType.name,
      },
      'updatedBy': decoded['updatedBy'] ?? <String, Object?>{},
      'datasets': datasets,
    });
    await driver.writeText('manifest.json', updatedManifest);
  }

  Future<void> _persistScopeEnvelope({
    required SyncProfile profile,
    required SyncScope scope,
    required SyncRemoteDriver driver,
    required String remotePath,
    required String? previousRemoteRevision,
    required String payload,
    required SyncScopeState? previousState,
  }) async {
    await driver.writeText(
      remotePath,
      payload,
      ifMatchRevision: previousRemoteRevision,
    );
    final updatedRemoteStat = await driver.stat(remotePath);
    final now = DateTime.now().toUtc();
    await _localStore.saveScopeState(
      SyncScopeState(
        profileId: profile.id,
        scope: scope,
        lastBaseSnapshotJson: payload,
        lastRemoteRevision: updatedRemoteStat?.revision,
        lastRemoteHash: _hashContent(payload),
        lastLocalHash: _hashContent(payload),
        lastSyncedAt: now,
        createdAt: previousState?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    await _updateManifestDataset(
      driver: driver,
      profile: profile,
      scope: scope,
      revision: updatedRemoteStat?.revision,
      payload: payload,
    );
  }

  Future<List<_SyncAssetItem>> _loadLocalBookMetadataAssets() async {
    final overrides = await _bookMetadataOverrideRepository.getAll();
    final results = <_SyncAssetItem>[];
    for (final item in overrides) {
      if (item.isLocalScope) {
        continue;
      }
      final relativePath = item.coverPath?.trim() ?? '';
      if (relativePath.isEmpty) {
        continue;
      }
      final asset = await _readAssetItem(
        relativePath: relativePath,
        root: ManagedAssetRoot.support,
        type: ManagedAssetType.customBookCover,
        scope: ManagedAssetScope.bookshelfBook,
      );
      if (asset != null) {
        results.add(asset);
      }
    }
    return List<_SyncAssetItem>.unmodifiable(results);
  }

  Future<List<_SyncAssetItem>> _loadLocalAdvancedThemeAssets() async {
    final themes = await _advancedThemeService.loadThemes();
    final results = <_SyncAssetItem>[];
    final seen = <String>{};
    for (final theme in themes) {
      for (final ref in <ManagedAssetRef?>[
        theme.lightConfig.wallpaperAsset,
        theme.lightConfig.readerWallpaperAsset,
        theme.darkConfig.wallpaperAsset,
        theme.darkConfig.readerWallpaperAsset,
      ]) {
        if (ref == null) {
          continue;
        }
        final relativePath = ref.relativePath.trim();
        if (relativePath.isEmpty || seen.contains(relativePath)) {
          continue;
        }
        final asset = await _readAssetItem(
          relativePath: relativePath,
          root: ref.root,
          type: ref.type,
          scope: ref.scope,
          collectionId: ref.collectionId,
          assetId: ref.assetId,
          displayName: ref.displayName,
        );
        if (asset != null) {
          results.add(asset);
          seen.add(relativePath);
        }
      }
    }
    return List<_SyncAssetItem>.unmodifiable(results);
  }

  Future<_SyncAssetItem?> _readAssetItem({
    required String relativePath,
    required ManagedAssetRoot root,
    required ManagedAssetType type,
    required ManagedAssetScope scope,
    String? collectionId,
    String? assetId,
    String? displayName,
  }) async {
    final absolutePath = await _resolveAbsolutePath(
      root: root,
      relativePath: relativePath,
    );
    final file = File(absolutePath);
    if (!await file.exists()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    final stat = await file.stat();
    return _SyncAssetItem(
      relativePath: relativePath,
      root: root,
      type: type,
      scope: scope,
      collectionId: collectionId,
      assetId: assetId,
      displayName: displayName,
      fileName: p.basename(relativePath),
      bytesBase64: base64Encode(bytes),
      updatedAt: stat.modified.toUtc(),
    );
  }

  Future<void> _writeAssetItem(_SyncAssetItem item) async {
    final absolutePath = await _resolveAbsolutePath(
      root: item.root,
      relativePath: item.relativePath,
    );
    final file = File(absolutePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(base64Decode(item.bytesBase64), flush: true);
  }

  Future<String> _resolveAbsolutePath({
    required ManagedAssetRoot root,
    required String relativePath,
  }) async {
    final baseDirectory = switch (root) {
      ManagedAssetRoot.documents => await getApplicationDocumentsDirectory(),
      ManagedAssetRoot.support => await getApplicationSupportDirectory(),
      ManagedAssetRoot.bundled => await getApplicationSupportDirectory(),
    };
    return p.normalize(p.join(baseDirectory.path, relativePath));
  }

  bool _looksLikeLocalScopedBook({
    required String bookId,
    required String sourceId,
    required Set<String> localBookIds,
  }) {
    if (sourceId.trim() == '__local_book__') {
      return true;
    }
    return localBookIds.contains(bookId.trim());
  }

  String _bookshelfBookKeyOf(BookshelfBook item) {
    return '${item.sourceId.trim()}::${item.detailUrl.trim()}';
  }

  String _readingProgressKeyOf(ReadingProgress item) {
    final sourceId = item.sourceId.trim();
    final detailUrl = item.detailUrl.trim();
    if (sourceId.isNotEmpty && detailUrl.isNotEmpty) {
      return 'remote::$sourceId::$detailUrl';
    }
    return item.bookId.trim();
  }

  Map<String, dynamic> _bookMetadataOverrideToJson(BookMetadataOverride item) {
    return <String, dynamic>{
      'targetKey': item.targetKey,
      'bookId': item.bookId,
      'sourceId': item.sourceId,
      'detailUrl': item.detailUrl,
      'title': item.title,
      'author': item.author,
      'intro': item.intro,
      'coverPath': item.coverPath,
      'createdAt': item.createdAt.toIso8601String(),
      'updatedAt': item.updatedAt.toIso8601String(),
    };
  }

  BookMetadataOverride _bookMetadataOverrideFromJson(
    Map<String, dynamic> json,
  ) {
    return BookMetadataOverride(
      targetKey: (json['targetKey'] ?? '').toString().trim(),
      bookId: _nullableJsonString(json['bookId']),
      sourceId: _nullableJsonString(json['sourceId']),
      detailUrl: _nullableJsonString(json['detailUrl']),
      title: _nullableJsonString(json['title']),
      author: _nullableJsonString(json['author']),
      intro: _nullableJsonString(json['intro']),
      coverPath: _nullableJsonString(json['coverPath']),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString().trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString().trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String _readingStatusKeyOf(ReadingBookStatusEntry item) {
    final sourceId = item.sourceId.trim();
    final detailUrl = item.detailUrl.trim();
    if (sourceId.isNotEmpty && detailUrl.isNotEmpty) {
      return 'remote::$sourceId::$detailUrl';
    }
    return item.bookId.trim();
  }

  Map<String, dynamic> _readingBookStatusToJson(ReadingBookStatusEntry item) {
    return <String, dynamic>{
      'bookId': item.bookId,
      'sourceId': item.sourceId,
      'detailUrl': item.detailUrl,
      'bookTitle': item.bookTitle,
      'override': item.override.name,
      'updatedAt': item.updatedAt.toIso8601String(),
    };
  }

  ReadingBookStatusEntry _readingBookStatusFromJson(Map<String, dynamic> json) {
    return ReadingBookStatusEntry(
      bookId: (json['bookId'] ?? '').toString().trim(),
      sourceId: (json['sourceId'] ?? '').toString().trim(),
      detailUrl: (json['detailUrl'] ?? '').toString().trim(),
      bookTitle: (json['bookTitle'] ?? '').toString().trim(),
      override: ReadingBookStatusOverride.values.firstWhere(
        (item) => item.name == (json['override'] ?? '').toString().trim(),
        orElse: () => ReadingBookStatusOverride.reading,
      ),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString().trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String _hashContent(String text) {
    return 'sha256:${sha256.convert(utf8.encode(text))}';
  }

  String? _nullableJsonString(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  _AdvancedThemePresetSnapshot _decodeAdvancedThemePresetSnapshot(String? raw) {
    final normalized = (raw ?? '').trim();
    if (normalized.isEmpty) {
      return const _AdvancedThemePresetSnapshot(
        themes: <AppAdvancedTheme>[],
        activeThemeId: null,
      );
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return const _AdvancedThemePresetSnapshot(
          themes: <AppAdvancedTheme>[],
          activeThemeId: null,
        );
      }
      final themes = (decoded['themes'] as List? ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) => AppAdvancedTheme.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
      return _AdvancedThemePresetSnapshot(
        themes: themes,
        activeThemeId: _nullableJsonString(decoded['activeThemeId']),
      );
    } catch (_) {
      return const _AdvancedThemePresetSnapshot(
        themes: <AppAdvancedTheme>[],
        activeThemeId: null,
      );
    }
  }

  _AdvancedThemePresetSnapshot _mergeAdvancedThemePresetSnapshot({
    required _AdvancedThemePresetSnapshot base,
    required _AdvancedThemePresetSnapshot local,
    required _AdvancedThemePresetSnapshot remote,
  }) {
    final baseById = <String, AppAdvancedTheme>{
      for (final item in base.themes) item.id: item,
    };
    final localById = <String, AppAdvancedTheme>{
      for (final item in local.themes) item.id: item,
    };
    final remoteById = <String, AppAdvancedTheme>{
      for (final item in remote.themes) item.id: item,
    };
    final allIds = <String>{
      ...baseById.keys,
      ...localById.keys,
      ...remoteById.keys,
    };
    final themes = <AppAdvancedTheme>[];
    for (final id in allIds) {
      final baseTheme = baseById[id];
      final localTheme = localById[id];
      final remoteTheme = remoteById[id];
      if (localTheme != null && remoteTheme != null) {
        themes.add(
          localTheme.updatedAt.isAfter(remoteTheme.updatedAt) ||
                  localTheme.updatedAt == remoteTheme.updatedAt
              ? localTheme
              : remoteTheme,
        );
        continue;
      }
      if (localTheme != null) {
        if (baseTheme == null ||
            jsonEncode(baseTheme.toJson()) != jsonEncode(localTheme.toJson())) {
          themes.add(localTheme);
        }
        continue;
      }
      if (remoteTheme != null) {
        if (baseTheme == null ||
            jsonEncode(baseTheme.toJson()) !=
                jsonEncode(remoteTheme.toJson())) {
          themes.add(remoteTheme);
        }
      }
    }
    themes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final mergedActiveThemeId =
        _resolveScalarChange(
          baseValue: base.activeThemeId,
          localValue: local.activeThemeId,
          remoteValue: remote.activeThemeId,
        ) ??
        (themes.isEmpty ? null : themes.first.id);
    return _AdvancedThemePresetSnapshot(
      themes: List<AppAdvancedTheme>.unmodifiable(themes),
      activeThemeId: mergedActiveThemeId,
    );
  }

  String _encodeAdvancedThemePresetSnapshot(
    _AdvancedThemePresetSnapshot snapshot,
  ) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'scope': SyncScope.advancedThemePresets.name,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'themes': snapshot.themes.map((item) => item.toJson()).toList(),
      'activeThemeId': snapshot.activeThemeId,
    });
  }

  _BookshelfTaxonomySnapshot _decodeBookshelfTaxonomySnapshot(String? raw) {
    final normalized = (raw ?? '').trim();
    if (normalized.isEmpty) {
      return const _BookshelfTaxonomySnapshot(
        tagMap: <String, List<String>>{},
        tagOrder: <String>[],
        categoryOrder: <String>[],
        baseFilterOrder: <String>[],
      );
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        throw const FormatException('invalid bookshelf taxonomy payload');
      }
      final rawTagMap = decoded['tagMap'];
      final tagMap = <String, List<String>>{};
      if (rawTagMap is Map) {
        for (final entry in rawTagMap.entries) {
          final key = entry.key.toString().trim();
          if (key.isEmpty) {
            continue;
          }
          final value = entry.value;
          if (value is! List) {
            continue;
          }
          tagMap[key] = value
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
        }
      }
      return _BookshelfTaxonomySnapshot(
        tagMap: tagMap,
        tagOrder: _decodeStringList(decoded['tagOrder']),
        categoryOrder: _decodeStringList(decoded['categoryOrder']),
        baseFilterOrder: _decodeStringList(decoded['baseFilterOrder']),
      );
    } catch (_) {
      return const _BookshelfTaxonomySnapshot(
        tagMap: <String, List<String>>{},
        tagOrder: <String>[],
        categoryOrder: <String>[],
        baseFilterOrder: <String>[],
      );
    }
  }

  _BookshelfTaxonomySnapshot _mergeBookshelfTaxonomySnapshot({
    required _BookshelfTaxonomySnapshot base,
    required _BookshelfTaxonomySnapshot local,
    required _BookshelfTaxonomySnapshot remote,
  }) {
    final allKeys = <String>{
      ...base.tagMap.keys,
      ...local.tagMap.keys,
      ...remote.tagMap.keys,
    };
    final mergedTagMap = <String, List<String>>{};
    for (final key in allKeys) {
      final baseValue = base.tagMap[key] ?? const <String>[];
      final localValue = local.tagMap[key] ?? const <String>[];
      final remoteValue = remote.tagMap[key] ?? const <String>[];
      final localChanged = !listEquals(localValue, baseValue);
      final remoteChanged = !listEquals(remoteValue, baseValue);
      List<String> resolved;
      if (localChanged && remoteChanged) {
        resolved = _mergeStringLists(localValue, remoteValue);
      } else if (localChanged) {
        resolved = List<String>.from(localValue);
      } else if (remoteChanged) {
        resolved = List<String>.from(remoteValue);
      } else {
        resolved = List<String>.from(
          localValue.isNotEmpty ? localValue : remoteValue,
        );
      }
      if (resolved.isNotEmpty) {
        mergedTagMap[key] = resolved;
      }
    }

    return _BookshelfTaxonomySnapshot(
      tagMap: mergedTagMap,
      tagOrder: _mergeOrderedLists(
        base: base.tagOrder,
        local: local.tagOrder,
        remote: remote.tagOrder,
      ),
      categoryOrder: _mergeOrderedLists(
        base: base.categoryOrder,
        local: local.categoryOrder,
        remote: remote.categoryOrder,
      ),
      baseFilterOrder: _mergeOrderedLists(
        base: base.baseFilterOrder,
        local: local.baseFilterOrder,
        remote: remote.baseFilterOrder,
      ),
    );
  }

  String _encodeBookshelfTaxonomySnapshot(_BookshelfTaxonomySnapshot snapshot) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'scope': SyncScope.bookshelfTaxonomy.name,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'tagMap': snapshot.tagMap,
      'tagOrder': snapshot.tagOrder,
      'categoryOrder': snapshot.categoryOrder,
      'baseFilterOrder': snapshot.baseFilterOrder,
    });
  }

  String? _resolveScalarChange({
    required String? baseValue,
    required String? localValue,
    required String? remoteValue,
  }) {
    final base = baseValue?.trim();
    final local = localValue?.trim();
    final remote = remoteValue?.trim();
    final localChanged = local != base;
    final remoteChanged = remote != base;
    if (localChanged && remoteChanged) {
      return (local?.isNotEmpty ?? false) ? local : remote;
    }
    if (localChanged) {
      return local;
    }
    if (remoteChanged) {
      return remote;
    }
    return local;
  }

  List<String> _mergeOrderedLists({
    required List<String> base,
    required List<String> local,
    required List<String> remote,
  }) {
    final result = <String>[];
    for (final item in <String>[...local, ...remote, ...base]) {
      final normalized = item.trim();
      if (normalized.isEmpty || result.contains(normalized)) {
        continue;
      }
      result.add(normalized);
    }
    return List<String>.unmodifiable(result);
  }

  List<String> _mergeStringLists(List<String> left, List<String> right) {
    final result = <String>[];
    for (final item in <String>[...left, ...right]) {
      final normalized = item.trim();
      if (normalized.isEmpty || result.contains(normalized)) {
        continue;
      }
      result.add(normalized);
    }
    return List<String>.unmodifiable(result);
  }

  List<String> _decodeStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    final result = <String>[];
    for (final item in value) {
      final normalized = item.toString().trim();
      if (normalized.isEmpty || result.contains(normalized)) {
        continue;
      }
      result.add(normalized);
    }
    return List<String>.unmodifiable(result);
  }
}

class _SyncAssetItem {
  const _SyncAssetItem({
    required this.relativePath,
    required this.root,
    required this.type,
    required this.scope,
    required this.fileName,
    required this.bytesBase64,
    required this.updatedAt,
    this.collectionId,
    this.assetId,
    this.displayName,
  });

  final String relativePath;
  final ManagedAssetRoot root;
  final ManagedAssetType type;
  final ManagedAssetScope scope;
  final String fileName;
  final String bytesBase64;
  final DateTime updatedAt;
  final String? collectionId;
  final String? assetId;
  final String? displayName;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'relativePath': relativePath,
      'root': root.name,
      'type': type.name,
      'scope': scope.name,
      'fileName': fileName,
      'bytesBase64': bytesBase64,
      'updatedAt': updatedAt.toIso8601String(),
      'collectionId': collectionId,
      'assetId': assetId,
      'displayName': displayName,
    };
  }

  factory _SyncAssetItem.fromJson(Map<String, dynamic> json) {
    return _SyncAssetItem(
      relativePath: (json['relativePath'] ?? '').toString().trim(),
      root: ManagedAssetRoot.values.firstWhere(
        (item) => item.name == (json['root'] ?? '').toString().trim(),
        orElse: () => ManagedAssetRoot.support,
      ),
      type: ManagedAssetType.values.firstWhere(
        (item) => item.name == (json['type'] ?? '').toString().trim(),
        orElse: () => ManagedAssetType.customBookCover,
      ),
      scope: ManagedAssetScope.values.firstWhere(
        (item) => item.name == (json['scope'] ?? '').toString().trim(),
        orElse: () => ManagedAssetScope.bookshelfBook,
      ),
      fileName: (json['fileName'] ?? '').toString().trim(),
      bytesBase64: (json['bytesBase64'] ?? '').toString().trim(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString().trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      collectionId: _SyncHistorySessionItem._jsonString(json['collectionId']),
      assetId: _SyncHistorySessionItem._jsonString(json['assetId']),
      displayName: _SyncHistorySessionItem._jsonString(json['displayName']),
    );
  }
}

class _AdvancedThemePresetSnapshot {
  const _AdvancedThemePresetSnapshot({
    required this.themes,
    required this.activeThemeId,
  });

  final List<AppAdvancedTheme> themes;
  final String? activeThemeId;
}

class _BookshelfTaxonomySnapshot {
  const _BookshelfTaxonomySnapshot({
    required this.tagMap,
    required this.tagOrder,
    required this.categoryOrder,
    required this.baseFilterOrder,
  });

  final Map<String, List<String>> tagMap;
  final List<String> tagOrder;
  final List<String> categoryOrder;
  final List<String> baseFilterOrder;
}

class _SyncHistorySessionItem {
  const _SyncHistorySessionItem({required this.syncKey, required this.session});

  final String syncKey;
  final ReadingRecordSession session;

  DateTime get updatedAt => session.endAt;

  ReadingRecordSession toSession() => session;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'syncKey': syncKey,
      'bookId': session.bookId,
      'sourceId': session.sourceId,
      'detailUrl': session.detailUrl,
      'bookTitle': session.bookTitle,
      'bookAuthor': session.bookAuthor,
      'coverUrl': session.coverUrl,
      'chapterId': session.chapterId,
      'chapterTitle': session.chapterTitle,
      'chapterIndex': session.chapterIndex,
      'chapterUrl': session.chapterUrl,
      'startAt': session.startAt.toIso8601String(),
      'endAt': session.endAt.toIso8601String(),
      'durationMillis': session.durationMillis,
      'readChars': session.readChars,
      'startPositionRatio': session.startPositionRatio,
      'endPositionRatio': session.endPositionRatio,
    };
  }

  factory _SyncHistorySessionItem.fromSession(ReadingRecordSession session) {
    final keySource = <Object?>[
      session.bookId,
      session.sourceId,
      session.detailUrl,
      session.chapterIndex,
      session.chapterTitle,
      session.startAt.toIso8601String(),
      session.endAt.toIso8601String(),
      session.durationMillis,
      session.readChars,
    ].join('|');
    return _SyncHistorySessionItem(
      syncKey: 'session:${sha1.convert(utf8.encode(keySource))}',
      session: session,
    );
  }

  factory _SyncHistorySessionItem.fromJson(Map<String, dynamic> json) {
    final session = ReadingRecordSession(
      id: 0,
      bookId: (json['bookId'] ?? '').toString().trim(),
      sourceId: (json['sourceId'] ?? '').toString().trim(),
      detailUrl: (json['detailUrl'] ?? '').toString().trim(),
      bookTitle: (json['bookTitle'] ?? '').toString().trim(),
      bookAuthor: _jsonString(json['bookAuthor']),
      coverUrl: _jsonString(json['coverUrl']),
      chapterId: _jsonString(json['chapterId']),
      chapterTitle: _jsonString(json['chapterTitle']),
      chapterIndex: _jsonInt(json['chapterIndex']),
      chapterUrl: _jsonString(json['chapterUrl']),
      startAt:
          DateTime.tryParse((json['startAt'] ?? '').toString().trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endAt:
          DateTime.tryParse((json['endAt'] ?? '').toString().trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      durationMillis: _jsonInt(json['durationMillis']) ?? 0,
      readChars: _jsonInt(json['readChars']) ?? 0,
      startPositionRatio: _jsonDouble(json['startPositionRatio']) ?? 0,
      endPositionRatio: _jsonDouble(json['endPositionRatio']) ?? 0,
    );
    final syncKey =
        (json['syncKey'] ?? '').toString().trim().isNotEmpty
            ? (json['syncKey'] ?? '').toString().trim()
            : _SyncHistorySessionItem.fromSession(session).syncKey;
    return _SyncHistorySessionItem(syncKey: syncKey, session: session);
  }

  static String? _jsonString(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static int? _jsonInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _jsonDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}
