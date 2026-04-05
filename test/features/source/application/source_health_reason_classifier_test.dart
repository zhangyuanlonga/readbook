import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_reason_classifier.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';
import 'package:shuxiang_reading_next/domain/entities/source_health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceHealthReasonClassifier', () {
    const classifier = SourceHealthReasonClassifier();

    test('classifies app exception network failure', () {
      final kind = classifier.classify(
        appException: AppException(
          code: ErrorCode.network,
          stage: ErrorStage.search,
          briefMessage: 'network failed',
        ),
      );

      expect(kind, SourceHealthFailureKind.network);
    });

    test('classifies browser challenge from message', () {
      final kind = classifier.classify(message: 'browser challenge required');

      expect(kind, SourceHealthFailureKind.browserChallenge);
    });

    test('classifies cancellation exception', () {
      final kind = classifier.classify(
        error: const SessionTaskCancelledException(),
      );

      expect(kind, SourceHealthFailureKind.cancelled);
    });
  });
}
