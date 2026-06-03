// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_login_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SourceLoginState _$SourceLoginStateFromJson(Map<String, dynamic> json) =>
    _SourceLoginState(
      sourceId: _requiredSourceIdFromJson(json['sourceId']),
      updatedAt: _requiredDateTimeFromJson(json['updatedAt']),
      loginHeaderJson: _optionalNormalizedStringFromJson(
        json['loginHeaderJson'],
      ),
      loginInfoJson: _optionalNormalizedStringFromJson(json['loginInfoJson']),
      sourceVariableJson: _optionalNormalizedStringFromJson(
        json['sourceVariableJson'],
      ),
    );

Map<String, dynamic> _$SourceLoginStateToJson(_SourceLoginState instance) =>
    <String, dynamic>{
      'sourceId': instance.sourceId,
      'updatedAt': _dateTimeToJson(instance.updatedAt),
      'loginHeaderJson': instance.loginHeaderJson,
      'loginInfoJson': instance.loginInfoJson,
      'sourceVariableJson': instance.sourceVariableJson,
    };
