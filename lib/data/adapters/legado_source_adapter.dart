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

    var adaptedRules = SourceRuleSet(
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
      contentDecryptRule: _extractLegacyContentDecryptRule(raw.rawData),
    );

    adaptedRules = _applyInlineJsMangaFallback(
      rawData: raw.rawData,
      sourceType: raw.sourceType ?? 0,
      rules: adaptedRules,
    );

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
      sourceType: raw.sourceType ?? 0,
      comment: _emptyToNull(_normalizeText(raw.sourceComment)),
      headers: _parseHeaders(raw.rawData['header'], baseUrl: baseUrl),
      rules: adaptedRules,
    );
  }

  SourceRuleSet _applyInlineJsMangaFallback({
    required Map<String, dynamic> rawData,
    required int sourceType,
    required SourceRuleSet rules,
  }) {
    if (sourceType != 2) {
      return rules;
    }

    if (_containsReload(rawData)) {
      return rules;
    }

    var next = rules;

    final resolvedSearchRule = _resolveSearchRuleFromInlineJs(next.searchRule);
    if (resolvedSearchRule != null) {
      next = next.copyWith(searchRule: resolvedSearchRule);
    }

    if (_containsInvalidNumericClassSelector(next.searchDetailUrlRule)) {
      next = next.copyWith(searchDetailUrlRule: 'a@href');
    }

    final detailRuleMap = _extractMap(rawData['ruleBookInfo']);
    final detailInitRaw = _extractInlineJsBody(
      _pickRuleFromMap(detailRuleMap, ['init']),
    );
    final detailInitScript = _decodePackedJs(detailInitRaw) ?? detailInitRaw;

    if (detailInitScript != null &&
        (_looksLikeJavaScriptRule(next.detailRule) ||
            _isSimpleRuleToken(next.detailTitleRule, const {'name', 'title'}) ||
            _isSimpleRuleToken(next.detailAuthorRule, const {'author'}) ||
            _isSimpleRuleToken(next.detailIntroRule, const {'intro'}) ||
            _isSimpleRuleToken(next.detailCoverUrlRule, const {'cover'}) ||
            _isSimpleRuleToken(next.detailTocUrlRule, const {
              'url',
              'tocUrl',
            }))) {
      final titleSelector = _extractBookInfoSelector(detailInitScript, 'name');
      final authorSelector = _extractBookInfoSelector(
        detailInitScript,
        'author',
      );
      final introSelector = _extractBookInfoSelector(detailInitScript, 'intro');
      final coverSelector = _extractBookInfoSelector(detailInitScript, 'cover');

      next = next.copyWith(
        detailRule: '.detail-main-info-title@html',
        detailTitleRule:
            titleSelector != null
                ? '$titleSelector@text'
                : next.detailTitleRule,
        detailAuthorRule:
            authorSelector != null
                ? '$authorSelector@text'
                : next.detailAuthorRule,
        detailIntroRule:
            introSelector != null
                ? '$introSelector@text'
                : next.detailIntroRule,
        detailCoverUrlRule:
            coverSelector != null
                ? '$coverSelector@data-original'
                : next.detailCoverUrlRule,
        detailTocUrlRule:
            _isSimpleRuleToken(next.detailTocUrlRule, const {'url', 'tocUrl'})
                ? '.detail-list-1 li a@href'
                : next.detailTocUrlRule,
      );
    }

    final tocRuleMap = _extractMap(rawData['ruleToc']);
    final tocListRaw = _extractInlineJsBody(
      _pickRuleFromMap(tocRuleMap, ['chapterList']),
    );
    final tocListScript = _decodePackedJs(tocListRaw) ?? tocListRaw;
    if (tocListScript != null && _looksLikeJavaScriptRule(next.tocListRule)) {
      final selector = _extractJavaGetElementsSelector(tocListScript);
      if (selector != null) {
        final listSelector =
            selector.endsWith(' a')
                ? selector.substring(0, selector.length - 2).trim()
                : selector;
        next = next.copyWith(
          tocRule: null,
          tocListRule: '$listSelector@html',
          tocTitleRule: 'a@text',
          tocChapterUrlRule: 'a@href',
        );
      }
    }

    final contentRuleMap = _extractMap(rawData['ruleContent']);
    final contentRaw = _extractInlineJsBody(
      _pickRuleFromMap(contentRuleMap, ['content']),
    );
    final contentScript = _decodePackedJs(contentRaw) ?? contentRaw;
    if (contentScript != null && _looksLikeJavaScriptRule(next.contentRule)) {
      final selector = _extractJavaGetElementsSelector(contentScript);
      if (selector != null) {
        next = next.copyWith(contentRule: '$selector@src');
      }
    }

    return next;
  }

  bool _containsReload(Map<String, dynamic> payload) {
    final values = <String>[];
    _collectStrings(payload, values);
    return values.any(
      (value) => RegExp(r'reload\s*\(', caseSensitive: false).hasMatch(value),
    );
  }

  void _collectStrings(dynamic value, List<String> output) {
    if (value == null) {
      return;
    }

    if (value is String) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        output.add(normalized);
      }
      return;
    }

    if (value is Map) {
      for (final entry in value.entries) {
        _collectStrings(entry.key, output);
        _collectStrings(entry.value, output);
      }
      return;
    }

    if (value is Iterable) {
      for (final item in value) {
        _collectStrings(item, output);
      }
      return;
    }
  }

  bool _looksLikeJavaScriptRule(String? expression) {
    final text = expression?.trim();
    if (text == null || text.isEmpty) {
      return false;
    }

    final normalized = text.toLowerCase();
    return normalized.contains('<js>') ||
        normalized.contains('js:') ||
        normalized.contains('eval(') ||
        normalized.contains('java.');
  }

  bool _isSimpleRuleToken(String? expression, Set<String> candidates) {
    final text = expression?.trim();
    if (text == null || text.isEmpty) {
      return false;
    }

    if (text.contains('@') || text.contains('.') || text.contains('/')) {
      return false;
    }

    return candidates.contains(text);
  }

  bool _containsInvalidNumericClassSelector(String? expression) {
    final text = expression?.trim();
    if (text == null || text.isEmpty || !text.contains('@')) {
      return false;
    }

    final selector = text.split('@').first.trim();
    return RegExp(r'\.[0-9]').hasMatch(selector);
  }

  String? _resolveSearchRuleFromInlineJs(String? rawRule) {
    if (!_looksLikeJavaScriptRule(rawRule)) {
      return null;
    }

    final script = _extractInlineJsBody(rawRule);
    final decoded = _decodePackedJs(script) ?? script;
    if (decoded == null || decoded.isEmpty) {
      return null;
    }

    final match = RegExp(
      r'"((?:https?://|/)[^"\n]*\{\{key\}\}[^"\n]*)"',
    ).firstMatch(decoded);
    final matchedUrl = match?.group(1)?.trim();
    if (matchedUrl == null || matchedUrl.isEmpty) {
      return null;
    }

    return matchedUrl;
  }

  String? _extractInlineJsBody(String? expression) {
    final text = expression?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    if (text.startsWith('<js>') && text.endsWith('</js>')) {
      return text.substring(4, text.length - 5).trim();
    }

    return text;
  }

  String? _decodePackedJs(String? script) {
    final source = script?.trim();
    if (source == null || source.isEmpty) {
      return null;
    }

    final match = RegExp(
      r"eval\(function\(p,a,c,k,e,r\)\{[\s\S]*?\}\('([\s\S]*?)',\s*(\d+),\s*(\d+),\s*'([\s\S]*?)'\.split\('\|'\),\s*0,\s*\{\}\)\)",
    ).firstMatch(source);

    if (match == null) {
      return null;
    }

    final payloadLiteral = match.group(1);
    final radix = int.tryParse(match.group(2) ?? '');
    final count = int.tryParse(match.group(3) ?? '');
    final dictionaryLiteral = match.group(4);

    if (payloadLiteral == null ||
        radix == null ||
        count == null ||
        dictionaryLiteral == null) {
      return null;
    }

    final payload = _decodeSingleQuotedLiteral(payloadLiteral);
    final dictionary = _decodeSingleQuotedLiteral(dictionaryLiteral).split('|');

    final tokenTable =
        '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

    String toToken(int value) {
      if (value == 0) {
        return '0';
      }

      var current = value;
      final buffer = StringBuffer();
      while (current > 0) {
        final index = current % radix;
        final char =
            index < tokenTable.length
                ? tokenTable[index]
                : String.fromCharCode(index + 29);
        buffer.write(char);
        current = current ~/ radix;
      }

      return buffer.toString().split('').reversed.join();
    }

    var output = payload;
    for (var index = count - 1; index >= 0; index -= 1) {
      if (index >= dictionary.length) {
        continue;
      }
      final value = dictionary[index];
      if (value.isEmpty) {
        continue;
      }

      final token = toToken(index);
      output = output.replaceAllMapped(
        RegExp('\\b${RegExp.escape(token)}\\b'),
        (_) => value,
      );
    }

    return output;
  }

  String _decodeSingleQuotedLiteral(String source) {
    final escaped = source
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll(r"\'", "'");

    try {
      final decoded = jsonDecode('"$escaped"');
      if (decoded is String) {
        return decoded;
      }
    } on FormatException {
      return source;
    }

    return source;
  }

  String? _extractBookInfoSelector(String script, String field) {
    final pattern =
        '${RegExp.escape(field)}'
        r'\s*:\s*(?:"<br>"\s*\+\s*)?[\$][24]\("([^"\n]+)"\)';
    final match = RegExp(pattern).firstMatch(script);
    return match?.group(1)?.trim();
  }

  String? _extractJavaGetElementsSelector(String script) {
    final match = RegExp(
      r'java\.getElements\("([^"\n]+)"\)',
    ).firstMatch(script);
    return match?.group(1)?.trim();
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
    final normalized = text.trim();
    if (RegExp(r'^(?:https?://|/|\{\{)[^\n]*,\s*\{').hasMatch(normalized)) {
      return true;
    }
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return true;
    }
    if (normalized.startsWith('/')) {
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

  String? _extractLegacyContentDecryptRule(Map<String, dynamic> rawData) {
    final loginCheckJs = _normalizeRuleValue(rawData['loginCheckJs']);
    if (loginCheckJs == null || loginCheckJs.isEmpty) {
      return null;
    }

    final jsLib = _normalizeRuleValue(rawData['jsLib']) ?? '';

    final hasAesCipher = RegExp(
      r'AES\s*/\s*CBC\s*/\s*PKCS7Padding',
      caseSensitive: false,
    ).hasMatch(loginCheckJs);
    final hasBase64Decode = RegExp(
      r'base64DecodeToByteArray',
      caseSensitive: false,
    ).hasMatch(loginCheckJs);
    final hasLzDecode = RegExp(
      r'decompressFromBase64',
      caseSensitive: false,
    ).hasMatch(loginCheckJs);
    final hasLzHelper = RegExp(
      r'function\s+decompressFromBase64',
      caseSensitive: false,
    ).hasMatch(jsLib);

    final includeMatch = RegExp(
      r'''url\.includes\(\s*(['"])(.+?)\1\s*\)''',
      dotAll: true,
    ).firstMatch(loginCheckJs);
    final urlContains = includeMatch?.group(2)?.trim();

    if (hasAesCipher && hasBase64Decode && (hasLzDecode || hasLzHelper)) {
      final keyMatch = RegExp(
        r'''java\.strToBytes\(\s*(['"])(.+?)\1\s*\)''',
        dotAll: true,
      ).firstMatch(loginCheckJs);
      final key = keyMatch?.group(2)?.trim() ?? '';
      if (key.isEmpty) {
        return null;
      }

      return jsonEncode({
        'type': 'aes_cbc_pkcs7_iv16_base64_lzbase64',
        'key': key,
        if (urlContains != null && urlContains.isNotEmpty)
          'urlContains': urlContains,
      });
    }

    if (hasLzDecode || hasLzHelper) {
      return jsonEncode({
        'type': 'lz_base64',
        if (urlContains != null && urlContains.isNotEmpty)
          'urlContains': urlContains,
      });
    }

    if (hasBase64Decode) {
      return jsonEncode({
        'type': 'base64_utf8',
        if (urlContains != null && urlContains.isNotEmpty)
          'urlContains': urlContains,
      });
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

  Map<String, String> _parseHeaders(Object? source, {required String baseUrl}) {
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

    final jsDynamic = _parseJsHeaderExpression(text, baseUrl: baseUrl);
    if (jsDynamic != null) {
      return jsDynamic;
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

  Map<String, String>? _parseJsHeaderExpression(
    String source, {
    required String baseUrl,
  }) {
    final normalized = source.trim();
    if (!normalized.startsWith('@js:')) {
      return null;
    }

    final script = normalized.substring(4).trim();
    if (script.isEmpty) {
      return const {};
    }

    final objectMatch = RegExp(r'\{[\s\S]*\}', dotAll: true).firstMatch(script);
    if (objectMatch == null) {
      return {'Origin': baseUrl, 'Referer': '$baseUrl/'};
    }

    final objectText = objectMatch.group(0);
    if (objectText == null || objectText.trim().isEmpty) {
      return {'Origin': baseUrl, 'Referer': '$baseUrl/'};
    }

    final normalizedObjectText = objectText
        .replaceAll('source.key + "/"', '"$baseUrl/"')
        .replaceAll("source.key + '/'", '"$baseUrl/"')
        .replaceAll('source.key+"/"', '"$baseUrl/"')
        .replaceAll("source.key+'/'", '"$baseUrl/"')
        .replaceAll('source.key', '"$baseUrl"');

    final parsed = _decodeHeaderJson(normalizedObjectText);
    if (parsed != null && parsed.isNotEmpty) {
      return parsed;
    }

    return {'Origin': baseUrl, 'Referer': '$baseUrl/'};
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
      final normalized = _normalizePseudoJson(source);
      try {
        final decoded = jsonDecode(normalized);
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
  }

  String _normalizePseudoJson(String source) {
    return source.replaceAllMapped(RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'"), (
      match,
    ) {
      final inner = match.group(1) ?? '';
      final escaped = inner
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll('\n', r'\n');
      return '"$escaped"';
    });
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
