import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ReaderVolumeKeyDirection { up, down }

class ReaderVolumeKeyEvent {
  const ReaderVolumeKeyEvent({
    required this.direction,
    required this.repeatCount,
  });

  final ReaderVolumeKeyDirection direction;
  final int repeatCount;
}

class ReaderVolumeKeyPageBridge {
  ReaderVolumeKeyPageBridge._();

  static final ReaderVolumeKeyPageBridge instance =
      ReaderVolumeKeyPageBridge._();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.jiangyan.shuxiangread/reader_volume_keys',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.jiangyan.shuxiangread/reader_volume_keys/events',
  );

  Stream<ReaderVolumeKeyEvent>? _events;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<ReaderVolumeKeyEvent> get events {
    return _events ??=
        _eventChannel
            .receiveBroadcastStream()
            .map<ReaderVolumeKeyEvent?>(_parseEvent)
            .where((event) => event != null)
            .cast<ReaderVolumeKeyEvent>()
            .asBroadcastStream();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!isSupported) {
      return;
    }
    try {
      await _methodChannel.invokeMethod<void>(
        'setInterceptVolumeKeys',
        enabled,
      );
    } on MissingPluginException {
      // Ignore missing native bridge on unsupported hosts.
    } on PlatformException {
      // Ignore channel failures to avoid breaking reading.
    }
  }

  ReaderVolumeKeyEvent? _parseEvent(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      return null;
    }

    final directionRaw = raw['direction']?.toString().trim().toLowerCase();
    final direction = switch (directionRaw) {
      'up' => ReaderVolumeKeyDirection.up,
      'down' => ReaderVolumeKeyDirection.down,
      _ => null,
    };
    if (direction == null) {
      return null;
    }

    final repeatCount = switch (raw['repeatCount']) {
      final int value => value,
      final num value => value.toInt(),
      _ => 0,
    };

    return ReaderVolumeKeyEvent(direction: direction, repeatCount: repeatCount);
  }
}
