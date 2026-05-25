import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/audio_reading_mode.dart';

void main() {
  group('AudioReadingMode', () {
    test('exposes audio chapter identity and playback state', () {
      const chapter = AudioChapterIdentity(
        bookId: 'book_1',
        sourceId: 'source_1',
        detailUrl: 'https://example.com/detail/1',
        chapterId: 'chapter_1',
        chapterIndex: 0,
        chapterTitle: '第一章',
        audioUrl: 'https://example.com/audio/1.mp3',
      );
      const state = AudioPlaybackState(
        status: AudioPlaybackStatus.playing,
        speed: 1.25,
        currentPosition: Duration(seconds: 12),
        totalDuration: Duration(minutes: 5),
        playMode: AudioPlayMode.listLoop,
        sleepTimer: Duration(minutes: 20),
      );
      const mode = AudioReadingMode(
        chapterIdentity: chapter,
        playbackState: state,
      );

      expect(mode.chapterIdentity.chapterTitle, '第一章');
      expect(mode.playbackState.isPlaying, isTrue);
      expect(mode.playbackState.isBuffering, isFalse);
      expect(mode.supportsBackgroundPlayback, isTrue);
      expect(mode.supportsLockScreenControls, isTrue);
      expect(mode.supportsSleepTimer, isTrue);
    });

    test('playback state flags reflect status', () {
      const buffering = AudioPlaybackState(
        status: AudioPlaybackStatus.buffering,
      );
      const paused = AudioPlaybackState(status: AudioPlaybackStatus.paused);

      expect(buffering.isBuffering, isTrue);
      expect(buffering.isPlaying, isFalse);
      expect(paused.isPlaying, isFalse);
      expect(paused.isBuffering, isFalse);
    });

    test('supports persisted audio progress semantics', () {
      const state = AudioPlaybackState(
        status: AudioPlaybackStatus.paused,
        speed: 1.5,
        currentPosition: Duration(minutes: 3, seconds: 12),
        totalDuration: Duration(minutes: 24),
      );

      expect(state.currentPosition.inMilliseconds, 192000);
      expect(state.totalDuration?.inMilliseconds, 1440000);
      expect(state.speed, 1.5);
    });
  });
}
