import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/data/adapters/legado_source_adapter.dart';
import 'package:flutter_appread/data/models/legado_source_raw.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';

const Set<String> _supportedBridgeCalls = <String>{
  'ajax',
  'ajaxall',
  'connect',
  'head',
  'post',
  'put',
  'get',
  'log',
  'toast',
  'longtoast',
  'startbrowser',
  'startbrowserawait',
  'webview',
  'setcontent',
  'getstring',
  'getstringlist',
  'getelements',
  'getelement',
  'getcookie',
  'base64decode',
  'base64encode',
  'base64decodetobytearray',
  'base64decoder',
  'md5encode',
  'md5encode16',
  'encodeuri',
  'htmlformat',
  'timeformat',
  'timeformatutc',
  'tonumchapter',
  't2s',
  's2t',
  'strtobytes',
  'bytestostring',
  'createsymmetriccrypto',
  'refreshtocurl',
  'getwebviewua',
  'randomuuid',
  'androidid',
  'deviceid',
  'hexdecodetostring',
  'hexdecodetobytearray',
  'hexencodetostring',
  'digesthex',
  'hmachex',
  'hmacbase64',
  'desencodetobase64string',
  'initurl',
  'getstrresponse',
  'tourl',
  'regetbook',
  'aesdecodeargsbase64str',
  'cachefile',
  'getverificationcode',
  'importscript',
  'removecookie',
  'aesdecodetostring',
  'aesdecodetobytearray',
  'aesbase64decodetostring',
  'aesbase64decodetobytearray',
  'aesencodetostring',
  'aesencodetobytearray',
  'aesencodetobase64string',
  'aesencodetobase64bytearray',
};

const Set<String> _unsupportedBridgeCalls = <String>{
  'readfile',
  'getfile',
  'readtxtfile',
  'deletefile',
  'downloadfile',
  'unzipfile',
  'gettxtinfolder',
  'getzipstringcontent',
  'queryttf',
  'querybase64ttf',
  'replacefont',
};

final RegExp _bridgeCallPattern = RegExp(
  r'java\.([a-zA-Z_][a-zA-Z0-9_]*)\s*\(',
  caseSensitive: false,
);

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/source_pack_compat_matrix.dart <source_json_path> [output_dir]',
    );
    exitCode = 64;
    return;
  }

  final inputPath = args.first;
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    exitCode = 66;
    return;
  }

  final now = DateTime.now();
  final defaultOutputDir = 'build/source_pack_compat_matrix/${_timestamp(now)}';
  final outputDirPath = args.length >= 2 ? args[1] : defaultOutputDir;
  final outputDir = Directory(outputDirPath);
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final adapter = const LegadoSourceAdapter();
  final text = await inputFile.readAsString();
  final dynamic decoded = jsonDecode(text);
  if (decoded is! List) {
    stderr.writeln('Source JSON root must be an array.');
    exitCode = 65;
    return;
  }

  final totals = <String, int>{
    'total': 0,
    'full': 0,
    'partial': 0,
    'unsupported': 0,
    'parse_failed': 0,
  };
  final sourceTypeCounts = <int, int>{};
  final webViewTrueByType = <int, int>{};
  final nonFullReasonCounts = <String, int>{};
  final bridgeCallCountsAll = <String, int>{};
  final bridgeCallCountsNonFull = <String, int>{};
  final nonFullExamples = <Map<String, Object?>>[];

  for (final item in decoded) {
    totals['total'] = (totals['total'] ?? 0) + 1;
    if (item is! Map) {
      totals['parse_failed'] = (totals['parse_failed'] ?? 0) + 1;
      continue;
    }

    final rawMap = Map<String, dynamic>.from(
      item.map((key, value) => MapEntry(key.toString(), value)),
    );

    final sourceType = _asInt(rawMap['bookSourceType']) ?? 0;
    sourceTypeCounts[sourceType] = (sourceTypeCounts[sourceType] ?? 0) + 1;
    if (_isWebViewTrue(rawMap)) {
      webViewTrueByType[sourceType] = (webViewTrueByType[sourceType] ?? 0) + 1;
    }

    final sourceSamples = _collectStringSamples(rawMap);
    final bridgeCalls = _extractBridgeCalls(sourceSamples);
    for (final call in bridgeCalls) {
      bridgeCallCountsAll[call] = (bridgeCallCountsAll[call] ?? 0) + 1;
    }

    SourceDefinition source;
    try {
      source = adapter.adapt(LegadoSourceRaw.fromJson(rawMap));
    } catch (_) {
      totals['parse_failed'] = (totals['parse_failed'] ?? 0) + 1;
      continue;
    }

    final capability = source.jsCapability;
    switch (capability) {
      case SourceJsCapability.full:
        totals['full'] = (totals['full'] ?? 0) + 1;
        break;
      case SourceJsCapability.partial:
        totals['partial'] = (totals['partial'] ?? 0) + 1;
        break;
      case SourceJsCapability.unsupported:
        totals['unsupported'] = (totals['unsupported'] ?? 0) + 1;
        break;
    }

    if (capability == SourceJsCapability.full) {
      continue;
    }

    for (final call in bridgeCalls) {
      bridgeCallCountsNonFull[call] = (bridgeCallCountsNonFull[call] ?? 0) + 1;
    }

    final reasons = _collectReasons(
      samples: sourceSamples,
      bridgeCalls: bridgeCalls,
      capability: capability,
    );

    for (final reason in reasons) {
      nonFullReasonCounts[reason] = (nonFullReasonCounts[reason] ?? 0) + 1;
    }

    if (nonFullExamples.length < 500) {
      nonFullExamples.add(<String, Object?>{
        'id': source.id,
        'name': source.name,
        'baseUrl': source.baseUrl,
        'sourceType': source.sourceType,
        'jsCapability': source.jsCapability.name,
        'reasons': reasons.toList()..sort(),
      });
    }
  }

  final capabilityStats = <String, Object?>{
    'total': totals['total'],
    'full': totals['full'],
    'partial': totals['partial'],
    'unsupported': totals['unsupported'],
    'parse_failed': totals['parse_failed'],
    'non_full': (totals['partial'] ?? 0) + (totals['unsupported'] ?? 0),
  };

  final reasonTop = _sortCountMap(nonFullReasonCounts);
  final callTopAll = _sortCountMap(bridgeCallCountsAll);
  final callTopNonFull = _sortCountMap(bridgeCallCountsNonFull);

  final summary = <String, Object?>{
    'generatedAt': now.toIso8601String(),
    'inputPath': inputFile.absolute.path,
    'outputDir': outputDir.absolute.path,
    'capability': capabilityStats,
    'sourceTypeCounts': _sortIntKeyCountMap(sourceTypeCounts),
    'webViewTrueByType': _sortIntKeyCountMap(webViewTrueByType),
    'nonFullReasonTop': reasonTop.take(50).toList(),
    'bridgeCallTopAll': callTopAll.take(50).toList(),
    'bridgeCallTopNonFull': callTopNonFull.take(50).toList(),
    'nonFullExampleCount': nonFullExamples.length,
  };

  final summaryFile = File('${outputDir.path}/summary.json');
  final reasonMatrixFile = File('${outputDir.path}/non_full_sources.json');
  final markdownFile = File('${outputDir.path}/summary.md');

  await summaryFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(summary),
  );
  await reasonMatrixFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(nonFullExamples),
  );
  await markdownFile.writeAsString(
    _toMarkdown(
      summary: summary,
      reasonTop: reasonTop,
      callTopAll: callTopAll,
      callTopNonFull: callTopNonFull,
    ),
  );

  stdout.writeln('Done.');
  stdout.writeln('Summary: ${summaryFile.absolute.path}');
  stdout.writeln('Reason matrix: ${reasonMatrixFile.absolute.path}');
  stdout.writeln('Markdown: ${markdownFile.absolute.path}');
}

List<String> _collectStringSamples(dynamic value) {
  final output = <String>[];

  void walk(dynamic node) {
    if (node == null) {
      return;
    }
    if (node is String) {
      final normalized = node.trim();
      if (normalized.isNotEmpty) {
        output.add(normalized);
      }
      return;
    }
    if (node is Map) {
      for (final entry in node.entries) {
        walk(entry.value);
      }
      return;
    }
    if (node is Iterable) {
      for (final item in node) {
        walk(item);
      }
      return;
    }
  }

  walk(value);
  return output;
}

Set<String> _extractBridgeCalls(List<String> samples) {
  final calls = <String>{};
  for (final sample in samples) {
    for (final match in _bridgeCallPattern.allMatches(sample)) {
      final call = (match.group(1) ?? '').trim().toLowerCase();
      if (call.isNotEmpty) {
        calls.add(call);
      }
    }
  }
  return calls;
}

Set<String> _collectReasons({
  required List<String> samples,
  required Set<String> bridgeCalls,
  required SourceJsCapability capability,
}) {
  final reasons = <String>{};

  for (final sample in samples) {
    final normalized = sample.toLowerCase();
    if (normalized.contains('packages.')) {
      reasons.add('packages_bridge');
    }
    if (normalized.contains('document.') || normalized.contains('window.')) {
      reasons.add('dom_runtime_dependency');
    }
  }

  for (final call in bridgeCalls) {
    if (_unsupportedBridgeCalls.contains(call)) {
      reasons.add('unsupported_bridge.$call');
      continue;
    }
    if (!_supportedBridgeCalls.contains(call)) {
      reasons.add('unknown_bridge.$call');
    }
  }

  if (reasons.isEmpty && capability != SourceJsCapability.full) {
    reasons.add('non_full_without_explicit_pattern');
  }
  return reasons;
}

List<Map<String, Object>> _sortCountMap(Map<String, int> input) {
  final entries = input.entries
      .map((entry) => <String, Object>{'key': entry.key, 'count': entry.value})
      .toList(growable: false);
  entries.sort((left, right) {
    final countCompare = (right['count'] as int).compareTo(
      left['count'] as int,
    );
    if (countCompare != 0) {
      return countCompare;
    }
    return (left['key'] as String).compareTo(right['key'] as String);
  });
  return entries;
}

Map<String, int> _sortIntKeyCountMap(Map<int, int> input) {
  final keys = input.keys.toList()..sort();
  final output = <String, int>{};
  for (final key in keys) {
    output[key.toString()] = input[key]!;
  }
  return output;
}

String _toMarkdown({
  required Map<String, Object?> summary,
  required List<Map<String, Object>> reasonTop,
  required List<Map<String, Object>> callTopAll,
  required List<Map<String, Object>> callTopNonFull,
}) {
  final capability = summary['capability'] as Map<String, Object?>;
  final typeCounts = summary['sourceTypeCounts'] as Map<String, int>;
  final webViewByType = summary['webViewTrueByType'] as Map<String, int>;
  final buffer =
      StringBuffer()
        ..writeln('# Source Pack Compatibility Matrix')
        ..writeln()
        ..writeln('- generatedAt: ${summary['generatedAt']}')
        ..writeln('- inputPath: ${summary['inputPath']}')
        ..writeln()
        ..writeln('## Capability')
        ..writeln()
        ..writeln('| metric | value |')
        ..writeln('|---|---:|');
  for (final key in <String>[
    'total',
    'full',
    'partial',
    'unsupported',
    'non_full',
    'parse_failed',
  ]) {
    buffer.writeln('| $key | ${capability[key]} |');
  }

  buffer
    ..writeln()
    ..writeln('## Source Type Distribution')
    ..writeln()
    ..writeln('| sourceType | count | webView:true |')
    ..writeln('|---:|---:|---:|');
  for (final entry in typeCounts.entries) {
    final webViewCount = webViewByType[entry.key] ?? 0;
    buffer.writeln('| ${entry.key} | ${entry.value} | $webViewCount |');
  }

  void writeTopSection(String title, List<Map<String, Object>> rows) {
    buffer
      ..writeln()
      ..writeln('## $title')
      ..writeln()
      ..writeln('| rank | key | count |')
      ..writeln('|---:|---|---:|');
    for (var i = 0; i < rows.length && i < 30; i += 1) {
      final row = rows[i];
      buffer.writeln('| ${i + 1} | ${row['key']} | ${row['count']} |');
    }
  }

  writeTopSection('Top Non-Full Reasons', reasonTop);
  writeTopSection('Top Bridge Calls (All Sources)', callTopAll);
  writeTopSection('Top Bridge Calls (Non-Full Sources)', callTopNonFull);

  return buffer.toString();
}

bool _isWebViewTrue(Map<String, dynamic> raw) {
  if (_deepContainsWebViewTrue(raw['searchUrl']) ||
      _deepContainsWebViewTrue(raw['exploreUrl'])) {
    return true;
  }
  if (_deepContainsWebViewTrue(raw['ruleSearch']) ||
      _deepContainsWebViewTrue(raw['ruleBookInfo']) ||
      _deepContainsWebViewTrue(raw['ruleToc']) ||
      _deepContainsWebViewTrue(raw['ruleContent']) ||
      _deepContainsWebViewTrue(raw['ruleExplore'])) {
    return true;
  }
  return false;
}

bool _deepContainsWebViewTrue(dynamic value) {
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value == 1;
  }
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized.contains('"webview":true') ||
        normalized.contains("'webview':true") ||
        normalized.contains('webview:true');
  }
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key.toString().toLowerCase() == 'webview') {
        if (_deepContainsWebViewTrue(entry.value)) {
          return true;
        }
      }
      if (_deepContainsWebViewTrue(entry.value)) {
        return true;
      }
    }
    return false;
  }
  if (value is Iterable) {
    for (final item in value) {
      if (_deepContainsWebViewTrue(item)) {
        return true;
      }
    }
    return false;
  }
  return false;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

String _timestamp(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}${two(value.month)}${two(value.day)}_'
      '${two(value.hour)}${two(value.minute)}${two(value.second)}';
}
