import 'dart:convert';

import '../../core/errors/app_exception.dart';
import '../../core/errors/error_codes.dart';
import '../../core/errors/error_stage.dart';
import '../../domain/entities/source_definition.dart';
import '../models/legado_source_raw.dart';

class LegadoSourceAdapter {
  const LegadoSourceAdapter();

  List<SourceDefinition> adaptAll(Iterable<LegadoSourceRaw> raws) {
    return raws.map(adapt).toList(growable: false);
  }

  SourceDefinition adapt(LegadoSourceRaw raw) {
    final name = _requiredField(
      _normalizeText(raw.sourceName),
      'bookSourceName',
    );
    final baseUrl = _requiredField(
      _normalizeText(raw.sourceUrl),
      'bookSourceUrl',
    );

    final searchRuleMap = _extractMap(raw.rawData['ruleSearch']);
    final detailRuleMap = _extractMap(raw.rawData['ruleBookInfo']);
    final tocRuleMap = _extractMap(raw.rawData['ruleToc']);
    final contentRuleMap = _extractMap(raw.rawData['ruleContent']);

    final searchRule =
        _pickRule(raw.rawData, ['searchUrl', 'ruleSearchUrl']) ??
        _pickRuleFromMap(searchRuleMap, ['url', 'searchUrl']) ??
        (searchRuleMap == null ? _pickRule(raw.rawData, ['ruleSearch']) : null);

    final searchInitRule =
        _pickRule(raw.rawData, ['searchInitRule', 'ruleSearchInit']) ??
        _pickRuleFromMap(searchRuleMap, ['init']);

    final detailInitCandidate =
        _pickRule(raw.rawData, ['detailInitRule', 'ruleBookInfoInit']) ??
        (detailRuleMap == null
            ? null
            : _pickRuleFromMap(detailRuleMap, ['init']));
    final detailInitSplit = _splitInitRule(detailInitCandidate);

    final tocInitCandidate =
        _pickRule(raw.rawData, ['tocInitRule', 'ruleTocInit']) ??
        _pickRuleFromMap(tocRuleMap, ['init']);
    final tocInitSplit = _splitInitRule(tocInitCandidate);

    final contentInitCandidate =
        _pickRule(raw.rawData, ['contentInitRule', 'ruleContentInit']) ??
        _pickRuleFromMap(contentRuleMap, ['init']);
    final contentInitRule = _splitInitRule(contentInitCandidate).requestRule;

    return SourceDefinition(
      id: _buildId(
        name: name,
        baseUrl: baseUrl,
        group: _normalizeText(raw.sourceGroup),
      ),
      name: name,
      baseUrl: baseUrl,
      group: _emptyToNull(_normalizeText(raw.sourceGroup)),
      enabled: raw.enabled,
      comment: _emptyToNull(_normalizeText(raw.sourceComment)),
      headers: _parseHeaders(raw.rawData['header']),
      rules: SourceRuleSet(
        searchRule: searchRule,
        searchInitRule: searchInitRule,
        searchListRule:
            _pickRule(raw.rawData, ['ruleSearchList', 'searchListRule']) ??
            _pickRuleFromMap(searchRuleMap, ['bookList', 'list']),
        searchTitleRule:
            _pickRule(raw.rawData, ['ruleSearchName', 'searchTitleRule']) ??
            _pickRuleFromMap(searchRuleMap, ['name', 'title', 'bookName']),
        searchDetailUrlRule:
            _pickRule(raw.rawData, [
              'ruleSearchBookUrl',
              'ruleSearchDetailUrl',
              'searchDetailUrlRule',
            ]) ??
            _pickRuleFromMap(searchRuleMap, ['bookUrl', 'detailUrl', 'url']),
        searchAuthorRule:
            _pickRule(raw.rawData, ['ruleSearchAuthor', 'searchAuthorRule']) ??
            _pickRuleFromMap(searchRuleMap, ['author']),
        searchIntroRule:
            _pickRule(raw.rawData, ['ruleSearchIntro', 'searchIntroRule']) ??
            _pickRuleFromMap(searchRuleMap, ['intro', 'desc', 'description']),
        searchCoverUrlRule:
            _pickRule(raw.rawData, [
              'ruleSearchCoverUrl',
              'searchCoverUrlRule',
            ]) ??
            _pickRuleFromMap(searchRuleMap, [
              'coverUrl',
              'cover',
              'img',
              'bookCover',
            ]),
        searchLatestChapterRule:
            _pickRule(raw.rawData, [
              'ruleSearchLastChapter',
              'searchLatestChapterRule',
            ]) ??
            _pickRuleFromMap(searchRuleMap, ['lastChapter', 'latestChapter']),
        detailRule:
            detailRuleMap == null
                ? _pickRule(raw.rawData, ['ruleBookInfo'])
                : detailInitSplit.parseRule,
        detailInitRule: detailInitSplit.requestRule,
        detailTitleRule:
            _pickRule(raw.rawData, ['ruleBookName', 'detailTitleRule']) ??
            _pickRuleFromMap(detailRuleMap, ['name', 'title', 'bookName']),
        detailAuthorRule:
            _pickRule(raw.rawData, ['ruleBookAuthor', 'detailAuthorRule']) ??
            _pickRuleFromMap(detailRuleMap, ['author']),
        detailIntroRule:
            _pickRule(raw.rawData, ['ruleBookIntro', 'detailIntroRule']) ??
            _pickRuleFromMap(detailRuleMap, ['intro', 'description', 'desc']),
        detailCoverUrlRule:
            _pickRule(raw.rawData, ['ruleCoverUrl', 'detailCoverUrlRule']) ??
            _pickRuleFromMap(detailRuleMap, ['coverUrl', 'cover', 'bookCover']),
        detailTocUrlRule:
            _pickRule(raw.rawData, ['ruleTocUrl', 'detailTocUrlRule']) ??
            _pickRuleFromMap(detailRuleMap, [
              'tocUrl',
              'catalogUrl',
              'chapterUrl',
            ]),
        tocRule:
            tocRuleMap == null
                ? _pickRule(raw.rawData, ['ruleToc'])
                : tocInitSplit.parseRule,
        tocInitRule: tocInitSplit.requestRule,
        tocListRule:
            _pickRule(raw.rawData, ['ruleChapterList', 'tocListRule']) ??
            _pickRuleFromMap(tocRuleMap, ['chapterList', 'list']),
        tocTitleRule:
            _pickRule(raw.rawData, ['ruleChapterName', 'tocTitleRule']) ??
            _pickRuleFromMap(tocRuleMap, ['chapterName', 'title', 'name']),
        tocChapterUrlRule:
            _pickRule(raw.rawData, ['ruleChapterUrl', 'tocChapterUrlRule']) ??
            _pickRuleFromMap(tocRuleMap, ['chapterUrl', 'url', 'link']),
        tocReversed:
            _pickBool(raw.rawData, ['reverseToc', 'tocReverse']) ??
            _pickBoolFromMap(tocRuleMap, ['reverse', 'isReverse', 'isDesc']) ??
            false,
        contentRule:
            _pickRule(raw.rawData, ['ruleContent']) ??
            _pickRuleFromMap(contentRuleMap, ['content', 'text', 'body']),
        contentInitRule: contentInitRule,
      ),
    );
  }

  _InitRuleSplit _splitInitRule(String? rawRule) {
    final normalized = _emptyToNull(rawRule);
    if (normalized == null) {
      return const _InitRuleSplit();
    }

    if (_looksLikeRequestRule(normalized)) {
      return _InitRuleSplit(requestRule: normalized);
    }

    return _InitRuleSplit(parseRule: normalized);
  }

  bool _looksLikeRequestRule(String text) {
    if (text.contains(',{')) {
      return true;
    }
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return true;
    }
    if (text.startsWith('/')) {
      return true;
    }
    return false;
  }

  String? _normalizeText(String? value) {
    final normalized = _emptyToNull(value);
    if (normalized == null) {
      return null;
    }

    return _repairMojibake(normalized);
  }

  String _repairMojibake(String text) {
    if (text.isEmpty || _containsCjk(text)) {
      return text;
    }

    final looksMojibake = RegExp(
      r'(Ã|Â|â|æ|å|ç|¤|™|¢|ð|þ)',
      caseSensitive: false,
    ).hasMatch(text);
    if (!looksMojibake) {
      return text;
    }

    final bytes = _toSingleByteBytes(text);
    if (bytes == null) {
      return text;
    }

    try {
      final repaired = utf8.decode(bytes, allowMalformed: true);
      if (_containsCjk(repaired) ||
          repaired.runes.length > text.runes.length + 2) {
        return repaired;
      }
    } on FormatException {
      return text;
    }

    return text;
  }

  List<int>? _toSingleByteBytes(String text) {
    final bytes = <int>[];
    for (final rune in text.runes) {
      final byte = _toSingleByte(rune);
      if (byte == null) {
        return null;
      }
      bytes.add(byte);
    }
    return bytes;
  }

  int? _toSingleByte(int rune) {
    if (rune >= 0 && rune <= 0xFF) {
      return rune;
    }

    return switch (rune) {
      0x20AC => 0x80,
      0x201A => 0x82,
      0x0192 => 0x83,
      0x201E => 0x84,
      0x2026 => 0x85,
      0x2020 => 0x86,
      0x2021 => 0x87,
      0x02C6 => 0x88,
      0x2030 => 0x89,
      0x0160 => 0x8A,
      0x2039 => 0x8B,
      0x0152 => 0x8C,
      0x017D => 0x8E,
      0x2018 => 0x91,
      0x2019 => 0x92,
      0x201C => 0x93,
      0x201D => 0x94,
      0x2022 => 0x95,
      0x2013 => 0x96,
      0x2014 => 0x97,
      0x02DC => 0x98,
      0x2122 => 0x99,
      0x0161 => 0x9A,
      0x203A => 0x9B,
      0x0153 => 0x9C,
      0x017E => 0x9E,
      0x0178 => 0x9F,
      _ => null,
    };
  }

  bool _containsCjk(String text) {
    return RegExp(r'[㐀-鿿]').hasMatch(text);
  }

  String _requiredField(String? value, String fieldName) {
    final normalized = _emptyToNull(value);
    if (normalized == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.source,
        briefMessage: 'Required field missing: $fieldName',
      );
    }
    return normalized;
  }

  String? _pickRule(Map<String, dynamic> rawData, List<String> candidates) {
    for (final key in candidates) {
      final normalized = _normalizeRuleValue(rawData[key]);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  String? _pickRuleFromMap(Map<String, dynamic>? map, List<String> candidates) {
    if (map == null) {
      return null;
    }

    for (final key in candidates) {
      final normalized = _normalizeRuleValue(map[key]);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  bool? _pickBool(Map<String, dynamic> rawData, List<String> candidates) {
    for (final key in candidates) {
      final parsed = _parseBool(rawData[key]);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  bool? _pickBoolFromMap(Map<String, dynamic>? map, List<String> candidates) {
    if (map == null) {
      return null;
    }

    for (final key in candidates) {
      final parsed = _parseBool(map[key]);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  Map<String, dynamic>? _extractMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return null;
  }

  String? _normalizeRuleValue(Object? value) {
    if (value == null || value is Map || value is List) {
      return null;
    }

    final normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool? _parseBool(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }

    return null;
  }

  Map<String, String> _parseHeaders(Object? source) {
    if (source == null) {
      return const {};
    }

    if (source is Map) {
      return source.map(
        (key, value) =>
            MapEntry(key.toString().trim(), value.toString().trim()),
      )..removeWhere((key, value) => key.isEmpty || value.isEmpty);
    }

    if (source is! String) {
      return const {};
    }

    final text = source.trim();
    if (text.isEmpty) {
      return const {};
    }

    final decoded = _decodeHeaderJson(text);
    if (decoded != null) {
      return decoded;
    }

    final result = <String, String>{};
    final segments = text.split('&&');
    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final atIndex = trimmed.indexOf('@');
      final colonIndex = trimmed.indexOf(':');
      final separatorIndex = atIndex >= 0 ? atIndex : colonIndex;

      if (separatorIndex <= 0 || separatorIndex >= trimmed.length - 1) {
        continue;
      }

      final key = trimmed.substring(0, separatorIndex).trim();
      final value = trimmed.substring(separatorIndex + 1).trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      result[key] = value;
    }

    return result;
  }

  Map<String, String>? _decodeHeaderJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        return null;
      }
      return decoded.map(
        (key, value) =>
            MapEntry(key.toString().trim(), value.toString().trim()),
      )..removeWhere((key, value) => key.isEmpty || value.isEmpty);
    } on FormatException {
      return null;
    }
  }

  String _buildId({
    required String name,
    required String baseUrl,
    String? group,
  }) {
    final seed = '${baseUrl.trim()}|${name.trim()}|${(group ?? '').trim()}';
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    final hashText = hash.toRadixString(16).padLeft(8, '0');
    return 'src_$hashText';
  }

  String? _emptyToNull(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class _InitRuleSplit {
  const _InitRuleSplit({this.parseRule, this.requestRule});

  final String? parseRule;
  final String? requestRule;
}
