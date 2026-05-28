enum AudioPlaybackStatus { idle, buffering, playing, paused, completed, error }

enum AudioPlayMode { sequential, singleLoop, listLoop }

class AudioChapterIdentity {
  const AudioChapterIdentity({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.chapterId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.audioUrl,
    this.audioManifestUrl,
  });

  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String chapterId;
  final int chapterIndex;
  final String chapterTitle;
  final String? audioUrl;
  final String? audioManifestUrl;
}

class AudioPlaybackState {
  const AudioPlaybackState({
    required this.status,
    this.speed = 1.0,
    this.currentPosition = Duration.zero,
    this.totalDuration,
    this.playMode = AudioPlayMode.sequential,
    this.sleepTimer,
    this.errorMessage,
  });

  final AudioPlaybackStatus status;
  final double speed;
  final Duration currentPosition;
  final Duration? totalDuration;
  final AudioPlayMode playMode;
  final Duration? sleepTimer;
  final String? errorMessage;

  bool get isPlaying => status == AudioPlaybackStatus.playing;
  bool get isBuffering => status == AudioPlaybackStatus.buffering;

  AudioPlaybackState copyWith({
    AudioPlaybackStatus? status,
    double? speed,
    Duration? currentPosition,
    Object? totalDuration = _audioPlaybackStateSentinel,
    AudioPlayMode? playMode,
    Object? sleepTimer = _audioPlaybackStateSentinel,
    Object? errorMessage = _audioPlaybackStateSentinel,
  }) {
    return AudioPlaybackState(
      status: status ?? this.status,
      speed: speed ?? this.speed,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration:
          identical(totalDuration, _audioPlaybackStateSentinel)
              ? this.totalDuration
              : totalDuration as Duration?,
      playMode: playMode ?? this.playMode,
      sleepTimer:
          identical(sleepTimer, _audioPlaybackStateSentinel)
              ? this.sleepTimer
              : sleepTimer as Duration?,
      errorMessage:
          identical(errorMessage, _audioPlaybackStateSentinel)
              ? this.errorMessage
              : errorMessage as String?,
    );
  }
}

const Object _audioPlaybackStateSentinel = Object();

abstract class AudioPlaybackController {
  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Future<void> setSpeed(double speed);

  Future<void> skipNext();

  Future<void> skipPrevious();

  Future<void> setSleepTimer(Duration? duration);
}

class AudioReadingMode {
  const AudioReadingMode({
    required this.chapterIdentity,
    required this.playbackState,
    this.supportsBackgroundPlayback = true,
    this.supportsLockScreenControls = true,
    this.minSpeed = 0.5,
    this.maxSpeed = 3.0,
    this.supportsSleepTimer = true,
  });

  final AudioChapterIdentity chapterIdentity;
  final AudioPlaybackState playbackState;
  final bool supportsBackgroundPlayback;
  final bool supportsLockScreenControls;
  final double minSpeed;
  final double maxSpeed;
  final bool supportsSleepTimer;
}
