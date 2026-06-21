import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import 'reader_content_session.dart';
import 'reader_layout_diagnostics_service.dart';
import 'reader_layout_engine_mode.dart';
import 'reader_mode_model.dart';
import 'reader_page_turn_delegate.dart';

class ReaderLayoutReleasePolicy {
  const ReaderLayoutReleasePolicy({
    this.releaseEnabled = _releaseEnabledFromEnvironment,
    this.forceLegacy = _forceLegacyFromEnvironment,
    this.strictReleaseValidation = _strictReleaseValidationFromEnvironment,
    this.showDiagnosticsOverlay = _showDiagnosticsOverlayFromEnvironment,
    this.maxContentLength = _maxContentLengthFromEnvironment,
    this.pageTurnDelegate = const ReaderPageTurnDelegate(),
  });

  static const bool _releaseEnabledFromEnvironment = bool.fromEnvironment(
    'READER_LAYOUT_ENABLE_RELEASE',
    defaultValue: true,
  );
  static const bool _forceLegacyFromEnvironment = bool.fromEnvironment(
    'READER_LAYOUT_FORCE_LEGACY',
  );
  static const bool _strictReleaseValidationFromEnvironment =
      bool.fromEnvironment('READER_LAYOUT_STRICT_RELEASE');
  static const bool _showDiagnosticsOverlayFromEnvironment =
      bool.fromEnvironment('READER_LAYOUT_SHOW_DIAGNOSTICS');
  static const int _maxContentLengthFromEnvironment = int.fromEnvironment(
    'READER_LAYOUT_MAX_CONTENT_LENGTH',
    defaultValue: 0,
  );

  final bool releaseEnabled;
  final bool forceLegacy;
  final bool strictReleaseValidation;
  final bool showDiagnosticsOverlay;
  final int maxContentLength;
  final ReaderPageTurnDelegate pageTurnDelegate;

  ReaderLayoutReleaseDecision resolve({
    required ReaderContentMode contentMode,
    required ReaderModeViewportKind viewportKind,
    required bool hasRenderableText,
    required int contentLength,
    ReaderPageAnimationStyle pageAnimationStyle = ReaderPageAnimationStyle.none,
  }) {
    final disabledReason = _resolveDisabledReason(
      contentMode: contentMode,
      viewportKind: viewportKind,
      hasRenderableText: hasRenderableText,
      contentLength: contentLength,
    );
    final pageTurnDecision =
        disabledReason == null
            ? pageTurnDelegate.resolve(
              ReaderPageTurnDelegateRequest(
                surface: ReaderPageTurnRendererSurface.layoutRelease,
                requestedStyle: pageAnimationStyle,
              ),
            )
            : null;
    final pageTurnFallbackReason =
        pageTurnDecision?.usesLegacyFallback == true
            ? pageTurnDecision!.reason
            : null;
    final enabled = disabledReason == null && pageTurnFallbackReason == null;
    return ReaderLayoutReleaseDecision(
      useReleaseRenderer: enabled,
      reason: disabledReason ?? pageTurnFallbackReason ?? 'enabled',
      mode:
          enabled
              ? ReaderLayoutEngineMode.experimental
              : ReaderLayoutEngineMode.legacy,
      diagnosticsEnabled: enabled || showDiagnosticsOverlay,
      showDiagnosticsOverlay: showDiagnosticsOverlay,
      releaseEnabled: releaseEnabled,
      forceLegacy: forceLegacy,
      strictReleaseValidation: strictReleaseValidation,
      maxContentLength: maxContentLength,
      requestedPageAnimationStyle: pageAnimationStyle,
      pageTurnDelegateReason: pageTurnDecision?.reason,
    );
  }

  String buildDocumentFingerprint({
    required String chapterId,
    required ReaderDocument document,
    required List<String> paragraphs,
    required String fallbackContent,
  }) {
    final buffer =
        StringBuffer()
          ..write('reader_layout_release_fingerprint_v1|')
          ..write(chapterId)
          ..write('|');
    if (!document.isEmpty) {
      buffer
        ..write('document:')
        ..write(document.blocks.length)
        ..write('|');
      for (final block in document.blocks) {
        buffer
          ..write(block.type)
          ..write(':')
          ..write(jsonEncode(block.toJson()))
          ..write('|');
      }
    } else {
      final effectiveParagraphs =
          paragraphs.isEmpty ? <String>[fallbackContent.trim()] : paragraphs;
      buffer
        ..write('paragraphs:')
        ..write(effectiveParagraphs.length)
        ..write('|');
      for (final paragraph in effectiveParagraphs) {
        buffer
          ..write(paragraph.length)
          ..write(':')
          ..write(paragraph)
          ..write('|');
      }
    }
    return crypto.sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  String? _resolveDisabledReason({
    required ReaderContentMode contentMode,
    required ReaderModeViewportKind viewportKind,
    required bool hasRenderableText,
    required int contentLength,
  }) {
    if (forceLegacy) {
      return 'force_legacy';
    }
    if (!releaseEnabled) {
      return 'release_disabled';
    }
    if (contentMode != ReaderContentMode.text) {
      return 'non_text_content';
    }
    if (viewportKind != ReaderModeViewportKind.textPaged) {
      return 'non_paged_viewport';
    }
    if (!hasRenderableText) {
      return 'empty_text';
    }
    if (maxContentLength > 0 && contentLength > maxContentLength) {
      return 'content_length_over_cap';
    }
    return null;
  }
}

class ReaderLayoutReleaseDecision {
  const ReaderLayoutReleaseDecision({
    required this.useReleaseRenderer,
    required this.reason,
    required this.mode,
    required this.diagnosticsEnabled,
    required this.showDiagnosticsOverlay,
    required this.releaseEnabled,
    required this.forceLegacy,
    required this.strictReleaseValidation,
    required this.maxContentLength,
    required this.requestedPageAnimationStyle,
    this.pageTurnDelegateReason,
  });

  final bool useReleaseRenderer;
  final String reason;
  final ReaderLayoutEngineMode mode;
  final bool diagnosticsEnabled;
  final bool showDiagnosticsOverlay;
  final bool releaseEnabled;
  final bool forceLegacy;
  final bool strictReleaseValidation;
  final int maxContentLength;
  final ReaderPageAnimationStyle requestedPageAnimationStyle;
  final String? pageTurnDelegateReason;

  ReaderLayoutDevOptions get options {
    return ReaderLayoutDevOptions(
      mode: mode,
      diagnosticsEnabled: diagnosticsEnabled,
      strictReleaseValidation: strictReleaseValidation,
    );
  }

  Map<String, Object?> toDiagnosticsContext() {
    return <String, Object?>{
      'readerLayoutReleaseEnabled': releaseEnabled,
      'readerLayoutReleaseActive': useReleaseRenderer,
      'readerLayoutReleaseReason': reason,
      'readerLayoutReleaseMode': mode.name,
      'readerLayoutReleaseForceLegacy': forceLegacy,
      'readerLayoutReleaseStrictValidation': strictReleaseValidation,
      'readerLayoutReleaseShowDiagnostics': showDiagnosticsOverlay,
      'readerLayoutReleaseRequestedAnimation': requestedPageAnimationStyle.name,
      if (pageTurnDelegateReason != null)
        'readerLayoutReleasePageTurnDelegate': pageTurnDelegateReason,
      if (maxContentLength > 0)
        'readerLayoutReleaseMaxContentLength': maxContentLength,
    };
  }
}
