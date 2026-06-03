// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_login_state.freezed.dart';
part 'source_login_state.g.dart';

@freezed
abstract class SourceLoginState with _$SourceLoginState {
  const factory SourceLoginState({
    @JsonKey(fromJson: _requiredSourceIdFromJson) required String sourceId,
    @JsonKey(fromJson: _requiredDateTimeFromJson, toJson: _dateTimeToJson)
    required DateTime updatedAt,
    @JsonKey(fromJson: _optionalNormalizedStringFromJson)
    String? loginHeaderJson,
    @JsonKey(fromJson: _optionalNormalizedStringFromJson) String? loginInfoJson,
    @JsonKey(fromJson: _optionalNormalizedStringFromJson)
    String? sourceVariableJson,
  }) = _SourceLoginState;

  const SourceLoginState._();

  factory SourceLoginState.fromJson(Map<String, dynamic> json) =>
      _$SourceLoginStateFromJson(json);

  bool get isEmpty =>
      _normalizeString(loginHeaderJson) == null &&
      _normalizeString(loginInfoJson) == null &&
      _normalizeString(sourceVariableJson) == null;
}

String _requiredSourceIdFromJson(Object? value) {
  final normalized = _normalizeString(value?.toString());
  if (normalized == null) {
    throw FormatException('Missing required field: sourceId');
  }
  return normalized;
}

String? _optionalNormalizedStringFromJson(Object? value) {
  return _normalizeString(value?.toString());
}

String? _normalizeString(String? value) {
  final normalized = (value ?? '').trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredDateTimeFromJson(Object? value) {
  final raw = value?.toString().trim() ?? '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Missing required datetime field: updatedAt');
  }
  return parsed;
}

String _dateTimeToJson(DateTime value) => value.toIso8601String();
