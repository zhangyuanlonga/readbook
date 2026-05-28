import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_reading_mode.dart';
import 'reader_content_session.dart';

@immutable
class ReaderAudioControllerState {
  const ReaderAudioControllerState({
    this.session,
    this.audioUrl,
    this.isManifest = false,
    this.isReady = false,
    this.preparedUrl,
    this.playbackState = const AudioPlaybackState(
      status: AudioPlaybackStatus.idle,
    ),
  });

  final ReaderContentSession? session;
  final String? audioUrl;
  final bool isManifest;
  final bool isReady;
  final String? preparedUrl;
  final AudioPlaybackState playbackState;

  bool get hasAudioUrl => audioUrl?.trim().isNotEmpty ?? false;
  bool get hasError => playbackState.status == AudioPlaybackStatus.error;

  ReaderAudioControllerState copyWith({
    Object? session = _readerAudioControllerSentinel,
    Object? audioUrl = _readerAudioControllerSentinel,
    bool? isManifest,
    bool? isReady,
    Object? preparedUrl = _readerAudioControllerSentinel,
    AudioPlaybackState? playbackState,
  }) {
    return ReaderAudioControllerState(
      session:
          identical(session, _readerAudioControllerSentinel)
              ? this.session
              : session as ReaderContentSession?,
      audioUrl:
          identical(audioUrl, _readerAudioControllerSentinel)
              ? this.audioUrl
              : audioUrl as String?,
      isManifest: isManifest ?? this.isManifest,
      isReady: isReady ?? this.isReady,
      preparedUrl:
          identical(preparedUrl, _readerAudioControllerSentinel)
              ? this.preparedUrl
              : preparedUrl as String?,
      playbackState: playbackState ?? this.playbackState,
    );
  }
}

const Object _readerAudioControllerSentinel = Object();

class ReaderAudioController extends ChangeNotifier
    implements AudioPlaybackController {
  ReaderAudioController({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _bindPlayerStreams();
  }

  final AudioPlayer _player;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Object>? _errorSubscription;

  ReaderAudioControllerState _state = const ReaderAudioControllerState();
  ReaderAudioControllerState get state => _state;

  String? _configurationKey;
  int _prepareToken = 0;

  Future<void> configure({
    required ReaderContentSession session,
    Duration? initialPosition,
    double initialSpeed = 1.0,
    bool autoPlay = false,
  }) async {
    final audioUrl = _normalizedAudioUrl(session);
    final configurationKey =
        '${session.chapterId}|${audioUrl ?? ''}|${session.audioHeaders.entries.map((entry) => '${entry.key}:${entry.value}').join('|')}';
    if (_configurationKey == configurationKey &&
        _state.session?.chapterId == session.chapterId) {
      if (_state.session != session) {
        _setState(
          _state.copyWith(
            session: session,
            audioUrl: audioUrl,
            isManifest: _isManifest(session, audioUrl),
          ),
        );
      }
      return;
    }
    _configurationKey = configurationKey;

    _setState(
      _state.copyWith(
        session: session,
        audioUrl: audioUrl,
        isManifest: _isManifest(session, audioUrl),
        isReady: false,
        preparedUrl: null,
        playbackState: const AudioPlaybackState(
          status: AudioPlaybackStatus.buffering,
        ),
      ),
    );

    await _player.stop();

    if (audioUrl == null) {
      _setState(
        _state.copyWith(
          playbackState: const AudioPlaybackState(
            status: AudioPlaybackStatus.error,
            errorMessage: '当前章节未提供可播放的音频地址。',
          ),
        ),
      );
      return;
    }

    final token = ++_prepareToken;
    final headers = session.audioHeaders;
    try {
      await _player.setUrl(audioUrl, headers: headers.isEmpty ? null : headers);
      if (token != _prepareToken) {
        return;
      }
      final duration = _player.duration;
      _setState(
        _state.copyWith(
          isReady: true,
          preparedUrl: audioUrl,
          playbackState: AudioPlaybackState(
            status: AudioPlaybackStatus.paused,
            speed: initialSpeed,
            currentPosition: Duration.zero,
            totalDuration: duration,
          ),
        ),
      );
      if ((_player.speed - initialSpeed).abs() >= 0.001) {
        await _player.setSpeed(initialSpeed);
      }
      if (initialPosition != null && initialPosition > Duration.zero) {
        await _player.seek(initialPosition);
      }
      if (autoPlay) {
        await _player.play();
      }
    } catch (error) {
      if (token != _prepareToken) {
        return;
      }
      _setState(
        _state.copyWith(
          isReady: false,
          playbackState: AudioPlaybackState(
            status: AudioPlaybackStatus.error,
            errorMessage: '音频加载失败: $error',
          ),
        ),
      );
    }
  }

  Future<void> reset() async {
    _configurationKey = null;
    _prepareToken += 1;
    await _player.stop();
    _setState(const ReaderAudioControllerState());
  }

  Future<void> retry() async {
    final session = _state.session;
    if (session == null) {
      return;
    }
    await configure(
      session: session,
      initialPosition: _state.playbackState.currentPosition,
    );
  }

  Future<void> togglePlayback() async {
    final status = _state.playbackState.status;
    if (_state.hasError) {
      return;
    }
    if (status == AudioPlaybackStatus.completed) {
      await restart();
      return;
    }
    if (status == AudioPlaybackStatus.playing) {
      await pause();
      return;
    }
    await play();
  }

  Future<void> restart() async {
    if (!_state.isReady && (_state.preparedUrl?.isEmpty ?? true)) {
      return;
    }
    await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> seekRelative(Duration delta) async {
    if (!_state.isReady) {
      return;
    }
    final total = _state.playbackState.totalDuration ?? Duration.zero;
    final current = _state.playbackState.currentPosition;
    final target = current + delta;
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(
        0,
        total <= Duration.zero ? target.inMilliseconds : total.inMilliseconds,
      ),
    );
    await seekTo(clamped);
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> play() async {
    if (!_state.isReady && !_state.hasAudioUrl) {
      return;
    }
    await _player.play();
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (!_state.isReady) {
      return;
    }
    await _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _setState(
      _state.copyWith(
        playbackState: _state.playbackState.copyWith(speed: speed),
      ),
    );
  }

  @override
  Future<void> setSleepTimer(Duration? duration) async {
    // Sleep timer will be introduced in a later milestone.
  }

  @override
  Future<void> skipNext() async {}

  @override
  Future<void> skipPrevious() async {}

  Future<void> disposeController() async {
    await _playerStateSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _player.dispose();
  }

  void _bindPlayerStreams() {
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      final nextStatus = switch (playerState.processingState) {
        ProcessingState.loading ||
        ProcessingState.buffering => AudioPlaybackStatus.buffering,
        ProcessingState.completed => AudioPlaybackStatus.completed,
        _ =>
          playerState.playing
              ? AudioPlaybackStatus.playing
              : AudioPlaybackStatus.paused,
      };
      _setState(
        _state.copyWith(
          playbackState: _state.playbackState.copyWith(status: nextStatus),
        ),
      );
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration == null) {
        return;
      }
      _setState(
        _state.copyWith(
          playbackState: _state.playbackState.copyWith(totalDuration: duration),
        ),
      );
    });

    _positionSubscription = _player.positionStream.listen((position) {
      _setState(
        _state.copyWith(
          playbackState: _state.playbackState.copyWith(
            currentPosition: position,
          ),
        ),
      );
    });

    _errorSubscription = _player.errorStream.listen((error) {
      _setState(
        _state.copyWith(
          isReady: false,
          playbackState: _state.playbackState.copyWith(
            status: AudioPlaybackStatus.error,
            errorMessage: '播放器初始化失败: $error',
          ),
        ),
      );
    });
  }

  String? _normalizedAudioUrl(ReaderContentSession session) {
    final preferred = session.audioUrl?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }
    final manifest = session.audioManifestUrl?.trim();
    if (manifest != null && manifest.isNotEmpty) {
      return manifest;
    }
    return null;
  }

  bool _isManifest(ReaderContentSession session, String? audioUrl) {
    return (session.audioManifestUrl?.trim().isNotEmpty ?? false) &&
        session.audioManifestUrl?.trim() == audioUrl;
  }

  void _setState(ReaderAudioControllerState nextState) {
    if (_state == nextState) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }
}
