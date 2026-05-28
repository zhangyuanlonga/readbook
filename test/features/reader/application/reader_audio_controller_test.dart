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

    test('setSpeed updates playback state speed', () async {
      final controller = ReaderAudioController(player: AudioPlayer());

      await controller.setSpeed(1.25);

      expect(controller.state.playbackState.speed, 1.25);
      await controller.disposeController();
    });
  });
}
