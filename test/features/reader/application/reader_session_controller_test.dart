import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_session_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_session_state.dart';

void main() {
  group('ReaderSessionController', () {
    test('invalidates previous chapter content tokens', () {
      final controller = ReaderSessionController();

      final first = controller.nextChapterContentToken();
      final second = controller.nextChapterContentToken();

      expect(controller.isActiveChapterContentToken(first), isFalse);
      expect(controller.isActiveChapterContentToken(second), isTrue);
    });

    test('cancels task generations independently', () {
      final controller = ReaderSessionController();
      final chapter = controller.nextChapterContentToken();
      final preload = controller.nextPreloadTaskToken();
      final pagination = controller.nextPaginationTaskToken();

      controller.cancelPreloadTasks();

      expect(controller.isActiveChapterContentToken(chapter), isTrue);
      expect(controller.isActivePreloadTaskToken(preload), isFalse);
      expect(controller.isActivePaginationTaskToken(pagination), isTrue);
    });

    test('cancels all active task generations', () {
      final controller = ReaderSessionController();
      final chapter = controller.nextToken(
        ReaderSessionTaskKind.chapterContent,
      );
      final preload = controller.nextToken(ReaderSessionTaskKind.preload);
      final pagination = controller.nextToken(ReaderSessionTaskKind.pagination);

      controller.cancelAll();

      expect(controller.isActive(chapter), isFalse);
      expect(controller.isActive(preload), isFalse);
      expect(controller.isActive(pagination), isFalse);
    });

    test('chapter intents cancel background work and issue load token', () {
      final controller = ReaderSessionController();
      final preload = controller.nextPreloadTaskToken();
      final pagination = controller.nextPaginationTaskToken();

      final result = controller.beginIntent(const ReaderSessionIntent.next());

      expect(result.chapterContentToken, isNotNull);
      expect(result.preloadTaskToken, isNull);
      expect(result.paginationTaskToken, isNull);
      expect(controller.isActivePreloadTaskToken(preload), isFalse);
      expect(controller.isActivePaginationTaskToken(pagination), isFalse);
      expect(
        controller.isActiveChapterContentToken(result.chapterContentToken!),
        isTrue,
      );
    });

    test('rapid chapter switches discard stale chapter load tokens', () {
      final controller = ReaderSessionController();

      final first =
          controller
              .beginIntent(const ReaderSessionIntent.previous())
              .chapterContentToken!;
      final second =
          controller
              .beginIntent(const ReaderSessionIntent.next())
              .chapterContentToken!;

      expect(controller.isActiveChapterContentToken(first), isFalse);
      expect(controller.isActiveChapterContentToken(second), isTrue);
    });

    test('settings intents cancel preload and issue pagination token', () {
      final controller = ReaderSessionController();
      final preload = controller.nextPreloadTaskToken();
      final chapter = controller.nextChapterContentToken();

      final result = controller.beginIntent(
        const ReaderSessionIntent.changeSettings(),
      );

      expect(result.chapterContentToken, isNull);
      expect(result.paginationTaskToken, isNotNull);
      expect(controller.isActivePreloadTaskToken(preload), isFalse);
      expect(controller.isActiveChapterContentToken(chapter), isTrue);
      expect(
        controller.isActivePaginationTaskToken(result.paginationTaskToken!),
        isTrue,
      );
    });
  });

  group('readerSessionControllerProvider', () {
    test('publishes generation snapshots after task mutations', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = readerSessionControllerProvider('reader-a');
      final notifier = container.read(provider.notifier);

      final chapter = notifier.nextChapterContentToken();
      final preload = notifier.nextPreloadTaskToken();

      expect(chapter, 1);
      expect(preload, 1);
      expect(
        container.read(provider),
        const ReaderSessionGenerationState(
          chapterContentGeneration: 1,
          preloadGeneration: 1,
        ),
      );

      notifier.cancelPreloadTasks();

      expect(notifier.isActiveChapterContentToken(chapter), isTrue);
      expect(notifier.isActivePreloadTaskToken(preload), isFalse);
      expect(container.read(provider).preloadGeneration, 2);
    });

    test('keeps reader page scopes isolated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = readerSessionControllerProvider('reader-a');
      final second = readerSessionControllerProvider('reader-b');

      container.read(first.notifier).nextChapterContentToken();

      expect(container.read(first).chapterContentGeneration, 1);
      expect(container.read(second).chapterContentGeneration, 0);
    });

    test('cancels dispose tasks without publishing provider state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = readerSessionControllerProvider('reader-dispose');
      final notifier = container.read(provider.notifier);

      final chapter = notifier.nextChapterContentToken();
      final preload = notifier.nextPreloadTaskToken();
      final beforeDispose = container.read(provider);

      notifier.cancelAllForDispose();

      expect(notifier.isActiveChapterContentToken(chapter), isFalse);
      expect(notifier.isActivePreloadTaskToken(preload), isFalse);
      expect(container.read(provider), beforeDispose);
    });
  });
}
