// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$ReaderTextBlockToJson(ReaderTextBlock instance) =>
    <String, dynamic>{'text': instance.text, 'type': instance.type};

Map<String, dynamic> _$ReaderListItemBlockToJson(
  ReaderListItemBlock instance,
) => <String, dynamic>{'text': instance.text, 'type': instance.type};

Map<String, dynamic> _$ReaderQuoteBlockToJson(ReaderQuoteBlock instance) =>
    <String, dynamic>{'text': instance.text, 'type': instance.type};

Map<String, dynamic> _$ReaderCaptionBlockToJson(ReaderCaptionBlock instance) =>
    <String, dynamic>{'text': instance.text, 'type': instance.type};

Map<String, dynamic> _$ReaderFootnoteBlockToJson(
  ReaderFootnoteBlock instance,
) => <String, dynamic>{'text': instance.text, 'type': instance.type};

Map<String, dynamic> _$ReaderImageBlockToJson(ReaderImageBlock instance) =>
    <String, dynamic>{'imageUrl': instance.imageUrl, 'type': instance.type};

Map<String, dynamic> _$ReaderTitleBlockToJson(ReaderTitleBlock instance) =>
    <String, dynamic>{
      'text': instance.text,
      'level': instance.level,
      'type': instance.type,
    };

Map<String, dynamic> _$ReaderDocumentToJson(ReaderDocument instance) =>
    <String, dynamic>{
      'blocks': instance.blocks.map((e) => e.toJson()).toList(),
    };
