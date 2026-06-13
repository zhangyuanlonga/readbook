import 'dart:async';
import 'dart:convert';

import '../../../../../domain/entities/reader_settings.dart';

typedef ReaderSettingsPersistCallback =
    Future<void> Function(ReaderSettings settings);

class ReaderSettingsSheetSession {
  ReaderSettingsSheetSession({
    required ReaderSettings initialSettings,
    required ReaderSettings Function() currentDraft,
    required bool Function() isMounted,
    required ReaderSettingsPersistCallback persistSettings,
    this.persistDelay = const Duration(milliseconds: 220),
    this.sliderRestoreDelay = const Duration(milliseconds: 180),
  }) : _currentDraft = currentDraft,
       _isMounted = isMounted,
       _persistSettings = persistSettings,
       _persistedFingerprint = fingerprintFor(initialSettings);

  final ReaderSettings Function() _currentDraft;
  final bool Function() _isMounted;
  final ReaderSettingsPersistCallback _persistSettings;
  final Duration persistDelay;
  final Duration sliderRestoreDelay;

  Timer? _persistDraftTimer;
  Timer? _sliderInteractionTimer;
  bool _isPersistingDraft = false;
  bool _isSliderInteracting = false;
  String _persistedFingerprint;

  bool get isSliderInteracting => _isSliderInteracting;

  static ReaderSettings normalizedForPersistence(ReaderSettings settings) {
    return settings.copyWith(autoReadEnabled: false);
  }

  static String fingerprintFor(ReaderSettings settings) {
    return jsonEncode(normalizedForPersistence(settings).toJson());
  }

  Future<void> persistNow([ReaderSettings? settings]) async {
    final normalized = normalizedForPersistence(settings ?? _currentDraft());
    final nextFingerprint = fingerprintFor(normalized);
    if (nextFingerprint == _persistedFingerprint || _isPersistingDraft) {
      return;
    }

    _isPersistingDraft = true;
    try {
      await _persistSettings(normalized);
      _persistedFingerprint = nextFingerprint;
    } catch (_) {
      // Keep in-memory preview even when persistence fails.
    } finally {
      _isPersistingDraft = false;
    }
  }

  void schedulePersistDraft() {
    _persistDraftTimer?.cancel();
    _persistDraftTimer = Timer(persistDelay, () {
      if (!_isMounted()) {
        return;
      }
      unawaited(persistNow());
    });
  }

  void setSliderInteractionPreview(
    bool active, {
    bool delayedRestore = false,
    required bool Function() canUpdate,
    required void Function() notifyChanged,
  }) {
    _sliderInteractionTimer?.cancel();
    if (delayedRestore && !active) {
      _sliderInteractionTimer = Timer(sliderRestoreDelay, () {
        if (!canUpdate() || !_isSliderInteracting) {
          return;
        }
        _isSliderInteracting = false;
        notifyChanged();
      });
      return;
    }
    if (_isSliderInteracting == active) {
      return;
    }
    _isSliderInteracting = active;
    notifyChanged();
  }

  void cancelTimers() {
    _persistDraftTimer?.cancel();
    _persistDraftTimer = null;
    _sliderInteractionTimer?.cancel();
    _sliderInteractionTimer = null;
  }

  void dispose() {
    cancelTimers();
  }
}
