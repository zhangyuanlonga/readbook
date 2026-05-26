import 'error_codes.dart';
import 'error_stage.dart';
import 'gateway_failure.dart';

class AppException implements Exception {
  const AppException({
    required this.code,
    required this.briefMessage,
    this.sourceId,
    this.stage = ErrorStage.unknown,
    this.requestUrl,
    this.gatewayFailure,
    this.cause,
    this.stackTrace,
  });

  final ErrorCode code;
  final String briefMessage;
  final String? sourceId;
  final ErrorStage stage;
  final String? requestUrl;
  final GatewayFailure? gatewayFailure;
  final Object? cause;
  final StackTrace? stackTrace;

  AppException copyWith({
    ErrorCode? code,
    String? briefMessage,
    String? sourceId,
    ErrorStage? stage,
    String? requestUrl,
    GatewayFailure? gatewayFailure,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppException(
      code: code ?? this.code,
      briefMessage: briefMessage ?? this.briefMessage,
      sourceId: sourceId ?? this.sourceId,
      stage: stage ?? this.stage,
      requestUrl: requestUrl ?? this.requestUrl,
      gatewayFailure: gatewayFailure ?? this.gatewayFailure,
      cause: cause ?? this.cause,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  @override
  String toString() {
    return 'AppException('
        'code: $code, '
        'stage: $stage, '
        'sourceId: $sourceId, '
        'requestUrl: $requestUrl, '
        'gatewayFailure: $gatewayFailure, '
        'briefMessage: $briefMessage)';
  }
}

class NetworkException extends AppException {
  const NetworkException({
    required super.briefMessage,
    super.sourceId,
    super.stage,
    super.requestUrl,
    super.gatewayFailure,
    super.cause,
    super.stackTrace,
  }) : super(code: ErrorCode.network);
}

class RuleParseException extends AppException {
  const RuleParseException({
    required super.briefMessage,
    super.sourceId,
    super.stage,
    super.requestUrl,
    super.gatewayFailure,
    super.cause,
    super.stackTrace,
  }) : super(code: ErrorCode.ruleParse);
}

class RuleMatchEmptyException extends AppException {
  const RuleMatchEmptyException({
    required super.briefMessage,
    super.sourceId,
    super.stage,
    super.requestUrl,
    super.gatewayFailure,
    super.cause,
    super.stackTrace,
  }) : super(code: ErrorCode.ruleMatchEmpty);
}

class DecodeException extends AppException {
  const DecodeException({
    required super.briefMessage,
    super.sourceId,
    super.stage,
    super.requestUrl,
    super.gatewayFailure,
    super.cause,
    super.stackTrace,
  }) : super(code: ErrorCode.decode);
}

class UnknownSourceException extends AppException {
  const UnknownSourceException({
    required super.briefMessage,
    super.sourceId,
    super.stage,
    super.requestUrl,
    super.gatewayFailure,
    super.cause,
    super.stackTrace,
  }) : super(code: ErrorCode.unknownSource);
}
