import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_source_switch_coordinator.dart';
import 'package:shuxiang_reading_next/features/reader/application/switch_source_shared.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderSourceSwitchCoordinator', () {
    const coordinator = ReaderSourceSwitchCoordinator();

    SwitchSourceCandidate buildCandidate({
      required String sourceId,
      required bool outdated,
      required int score,
    }) {
      return SwitchSourceCandidate(
        book: Book(
          id: 'book_$sourceId',
          sourceId: sourceId,
          title: '书名',
          detailUrl: 'https://example.com/$sourceId',
        ),
        sourceName: sourceId,
        healthLevel: null,
        baseScore: score,
        hitCount: 0,
        sourceScore: 0,
        bookScore: 0,
        latestChapterLabel: '第10章',
        latestChapterNumber: 10,
        isPotentiallyOutdated: outdated,
        score: score,
      );
    }

    test('resolves keyword from current title when usable', () {
      final keyword = coordinator.resolveKeywordFromKnownTitles(
        currentTitle: '三体',
        fallbackTitles: const <String?>['第12章 黑暗森林'],
      );

      expect(keyword, '三体');
    });

    test('falls back to valid title when current looks like chapter title', () {
      final keyword = coordinator.resolveKeywordFromKnownTitles(
        currentTitle: '第12章 黑暗森林',
        fallbackTitles: const <String?>[' chapter 15 ', ' 三体 '],
      );

      expect(keyword, '三体');
    });

    test('returns null when no usable title is found', () {
      final keyword = coordinator.resolveKeywordFromKnownTitles(
        currentTitle: '第9章',
        fallbackTitles: const <String?>['chapter 10', ''],
      );

      expect(keyword, isNull);
    });

    test('canAutoSwitchOnFailure validates runtime guards', () {
      final enabled = coordinator.canAutoSwitchOnFailure(
        canSwitchSource: true,
        autoSwitchSourceOnFailureEnabled: true,
        isAutoSwitchingSource: false,
        isSwitchSourceLoading: false,
        sourceId: 'source_a',
        detailUrl: 'https://example.com/detail',
      );
      final blocked = coordinator.canAutoSwitchOnFailure(
        canSwitchSource: true,
        autoSwitchSourceOnFailureEnabled: true,
        isAutoSwitchingSource: true,
        isSwitchSourceLoading: false,
        sourceId: 'source_a',
        detailUrl: 'https://example.com/detail',
      );

      expect(enabled, isTrue);
      expect(blocked, isFalse);
    });

    test('validateManualSwitchRequest blocks unsupported switch', () {
      final result = coordinator.validateManualSwitchRequest(
        isSwitchSourceLoading: false,
        canSwitchSource: false,
        sourceId: 'source_a',
        detailUrl: 'https://example.com/detail',
      );

      expect(result.canProceed, isFalse);
      expect(result.message, '当前书籍暂不支持换源。');
    });

    test('validateManualSwitchRequest returns normalized identity', () {
      final result = coordinator.validateManualSwitchRequest(
        isSwitchSourceLoading: false,
        canSwitchSource: true,
        sourceId: ' source_a ',
        detailUrl: ' https://example.com/detail ',
      );

      expect(result.canProceed, isTrue);
      expect(result.currentSourceId, 'source_a');
      expect(result.currentDetailUrl, 'https://example.com/detail');
    });

    test('prioritizeAutoSwitchCandidates prefers non-outdated candidates', () {
      final candidates = <SwitchSourceCandidate>[
        buildCandidate(sourceId: 'old_1', outdated: true, score: 90),
        buildCandidate(sourceId: 'new_1', outdated: false, score: 80),
        buildCandidate(sourceId: 'new_2', outdated: false, score: 70),
      ];
      final prioritized = coordinator.prioritizeAutoSwitchCandidates(
        candidates,
        tryLimit: 2,
      );

      expect(prioritized.length, 2);
      expect(prioritized.map((item) => item.sourceName), <String>[
        'new_1',
        'new_2',
      ]);
    });

    test('planBookshelfMigrationCheck marks immediate migration in shelf', () {
      final plan = coordinator.planBookshelfMigrationCheck(
        previousSourceId: ' source_a ',
        previousDetailUrl: ' https://example.com/detail ',
        wasInBookshelf: true,
      );

      expect(plan.previousSourceId, 'source_a');
      expect(plan.previousDetailUrl, 'https://example.com/detail');
      expect(plan.shouldMigrateImmediately, isTrue);
      expect(plan.requiresContainsCheck, isFalse);
    });

    test('resolveBookshelfMigration uses contains result when needed', () {
      final plan = coordinator.planBookshelfMigrationCheck(
        previousSourceId: 'source_a',
        previousDetailUrl: 'https://example.com/detail',
        wasInBookshelf: false,
      );
      final migrate = coordinator.resolveBookshelfMigration(
        plan: plan,
        containsResult: true,
      );
      final skip = coordinator.resolveBookshelfMigration(
        plan: plan,
        containsResult: false,
      );

      expect(migrate, isTrue);
      expect(skip, isFalse);
    });

    test('buildReplacementBookshelfBook falls back to candidate title', () {
      final replacement = coordinator.buildReplacementBookshelfBook(
        currentLogicalBookId: 'book_id',
        nextSourceId: 'source_b',
        nextDetailUrl: 'https://example.com/new',
        nextBookTitle: ' ',
        fallbackBookTitle: '候选标题',
        nextBookAuthor: '作者',
        nextBookCoverUrl: 'https://example.com/cover.jpg',
        latestReadableChapterTitle: null,
        fallbackLatestChapterTitle: '第10章',
        addedAt: DateTime(2026, 1, 1),
      );

      expect(replacement.bookId, 'book_id');
      expect(replacement.sourceId, 'source_b');
      expect(replacement.title, '候选标题');
      expect(replacement.detailUrl, 'https://example.com/new');
      expect(replacement.latestChapter, '第10章');
    });

    test('inferRuntimeMangaSource detects manga capabilities', () {
      final mangaSource = _buildRegisteredSource(
        id: 'manga',
        name: '漫画源',
        capabilities: const <String>{'Manga'},
      );
      final novelSource = _buildRegisteredSource(
        id: 'novel',
        name: '小说源',
        capabilities: const <String>{'novel'},
      );

      expect(coordinator.inferRuntimeMangaSource(mangaSource), isTrue);
      expect(coordinator.inferRuntimeMangaSource(novelSource), isFalse);
      expect(coordinator.inferRuntimeMangaSource(null), isNull);
    });

    test('buildSwitchSourceScope keeps only same content type sources', () {
      final sources = <RegisteredSource>[
        _buildRegisteredSource(
          id: 'novel_a',
          name: '小说源A',
          capabilities: const <String>{'novel'},
        ),
        _buildRegisteredSource(
          id: 'novel_b',
          name: '小说源B',
          capabilities: const <String>{'novel'},
        ),
        _buildRegisteredSource(
          id: 'manga_a',
          name: '漫画源A',
          capabilities: const <String>{'manga'},
        ),
      ];

      final scope = coordinator.buildSwitchSourceScope(
        sources: sources,
        currentSourceId: 'novel_a',
        fallbackIsMangaType: false,
      );

      expect(scope.isMangaType, isFalse);
      expect(scope.sourceIds, <String>['novel_b']);
    });
  });
}

RegisteredSource _buildRegisteredSource({
  required String id,
  required String name,
  Set<String> capabilities = const <String>{},
}) {
  return RegisteredSource(
    runtime: SourceRuntimeInfo(
      id: id,
      name: name,
      group: '测试',
      revision: 'test',
    ),
    definition: RuntimeSourceDefinition(
      manifest: SourceManifest(
        name: name,
        group: '测试',
        author: 'tester',
        description: '',
        capabilities: capabilities,
      ),
      search: (_, __) async => const <runtime_models.Book>[],
      detail: (_, book) async => book,
      chapters: (_, __) async => const <runtime_models.Chapter>[],
      content:
          (_, __, ___) async =>
              const runtime_models.Content(title: '', content: ''),
    ),
  );
}
