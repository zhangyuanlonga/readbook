import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shuxiang_reading_next/features/reader/application/audio_reading_mode.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_audio_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderAudioController', () {
    test('configure without audio url enters error state', () async {
      final controller = ReaderAudioController(player: AudioPlayer());
      const session = ReaderContentSession(
        contentMode: ReaderContentMode.audio,
        bookId: 'book_1',
        sourceId: 'source_1',
        detailUrl: 'detail',
        bookTitle: 'Book',
        chapterId: 'chapter_1',
      );

      await controller.configure(session: session);

      expect(controller.state.playbackState.status, AudioPlaybackStatus.error);
      expect(controller.state.playbackState.errorMessage, contains('正文解析规则'));
      await controller.disposeController();
    });

    test('reset clears prepared state', () async {
      final controller = ReaderAudioController(player: AudioPlayer());

      await controller.reset();

      expect(controller.state.isReady, isFalse);
      expect(controller.state.audioUrl, isNull);
      expect(controller.state.playbackState.status, AudioPlaybackStatus.idle);
      await controller.disposeController();
    });

    test(
      'play pause and jump commands are safe before audio is ready',
      () async {
        final controller = ReaderAudioController(player: AudioPlayer());

        await controller.togglePlayback();
        await controller.pause();
        await controller.seekRelative(const Duration(seconds: 15));

        expect(controller.state.isReady, isFalse);
        expect(
          controller.state.playbackState.status,
          AudioPlaybackStatus.paused,
        );
        await controller.disposeController();
      },
    );

    test('setSpeed updates playback state speed', () async {
      final controller = ReaderAudioController(player: AudioPlayer());

      await controller.setSpeed(1.25);

      expect(controller.state.playbackState.speed, 1.25);
      await controller.disposeController();
    });

    test(
      'chapter switch updates session identity even when audio url is missing',
      () async {
        final controller = ReaderAudioController(player: AudioPlayer());
        const firstSession = ReaderContentSession(
          contentMode: ReaderContentMode.audio,
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'detail',
          bookTitle: 'Book',
          chapterId: 'chapter_1',
          chapterIndex: 0,
        );
        const nextSession = ReaderContentSession(
          contentMode: ReaderContentMode.audio,
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'detail',
          bookTitle: 'Book',
          chapterId: 'chapter_2',
          chapterIndex: 1,
        );

        await controller.configure(session: firstSession);
        await controller.configure(session: nextSession);

        expect(controller.state.session?.chapterId, 'chapter_2');
        expect(controller.state.session?.chapterIndex, 1);
        expect(
          controller.state.playbackState.status,
          AudioPlaybackStatus.error,
        );
        await controller.disposeController();
      },
    );
  });
}
