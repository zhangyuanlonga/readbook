import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/sync_remote_driver.dart';

class WebDavSyncRemoteDriver implements SyncRemoteDriver {
  WebDavSyncRemoteDriver({
    required String endpointUrl,
    required String basePath,
    required String username,
    required String password,
    Dio? dio,
    AppLogger? logger,
  }) : _endpointUri = _normalizeEndpoint(endpointUrl),
       _endpointPathSegments = _normalizeEndpoint(endpointUrl).pathSegments
           .map((item) => item.trim())
           .where((item) => item.isNotEmpty)
           .toList(growable: false),
       _basePathSegments = _normalizeSegments(basePath),
       _username = username.trim(),
       _password = password.trim(),
       _dio = dio ?? Dio(),
       _logger = logger ?? AppLogger.instance;

  final Uri _endpointUri;
  final List<String> _endpointPathSegments;
  final List<String> _basePathSegments;
  final String _username;
  final String _password;
  final Dio _dio;
  final AppLogger _logger;

  @override
  Future<void> ensureDirectory(String path) async {
    final pathSegments = <String>[
      ..._basePathSegments,
      ..._normalizeSegments(path),
    ];
    await _ensureAbsoluteDirectory(pathSegments);
  }

  @override
  Future<void> ensureReady() async {
    if (_basePathSegments.isEmpty) {
      return;
    }
    await _ensureAbsoluteDirectory(_basePathSegments);
  }

  @override
  Future<String?> readText(String path) async {
    final response = await _request(
      method: 'GET',
      uri: _buildScopedUri(path, directory: false),
      responseType: ResponseType.plain,
      validateStatus: (code) => code != null && code < 500,
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode == 404) {
      return null;
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw StateError('WebDAV GET failed with status $statusCode');
    }
    return response.data?.toString();
  }

  @override
  Future<SyncRemoteFileStat?> stat(String path) async {
    final response = await _request(
      method: 'PROPFIND',
      uri: _buildScopedUri(path, directory: false),
      headers: const <String, String>{
        'Depth': '0',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      data: '''<?xml version="1.0" encoding="utf-8" ?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:getetag />
    <d:getcontentlength />
    <d:getlastmodified />
  </d:prop>
</d:propfind>''',
      responseType: ResponseType.plain,
      validateStatus: (code) => code != null && code < 500,
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode == 404) {
      return null;
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw StateError('WebDAV PROPFIND failed with status $statusCode');
    }

    final body = response.data?.toString().trim() ?? '';
    if (body.isEmpty) {
      return SyncRemoteFileStat(path: path);
    }

    final document = XmlDocument.parse(body);
    final responseElement =
        document.findAllElements('d:response').isNotEmpty
            ? document.findAllElements('d:response').first
            : document.rootElement;
    final revision = _readFirstText(responseElement, const <String>[
      'd:getetag',
      'getetag',
    ]);
    final contentLengthRaw = _readFirstText(responseElement, const <String>[
      'd:getcontentlength',
      'getcontentlength',
    ]);
    final updatedAtRaw = _readFirstText(responseElement, const <String>[
      'd:getlastmodified',
      'getlastmodified',
    ]);

    return SyncRemoteFileStat(
      path: path,
      revision: revision,
      contentLength: int.tryParse(contentLengthRaw ?? ''),
      updatedAt: _tryParseHttpDate(updatedAtRaw),
    );
  }

  @override
  Future<void> writeText(
    String path,
    String content, {
    String? ifMatchRevision,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      if (ifMatchRevision != null && ifMatchRevision.trim().isNotEmpty)
        'If-Match': ifMatchRevision.trim(),
    };
    final response = await _request(
      method: 'PUT',
      uri: _buildScopedUri(path, directory: false),
      headers: headers,
      data: utf8.encode(content),
      responseType: ResponseType.plain,
      validateStatus: (code) => code != null && code < 500,
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw StateError('WebDAV PUT failed with status $statusCode');
    }
  }

  Future<void> _ensureAbsoluteDirectory(List<String> scopedSegments) async {
    for (var index = 0; index < scopedSegments.length; index += 1) {
      final prefix = scopedSegments.sublist(0, index + 1);
      final response = await _request(
        method: 'MKCOL',
        uri: _buildAbsoluteUri(prefix, directory: true),
        responseType: ResponseType.plain,
        validateStatus: (code) => code != null && code < 500,
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode == 201 ||
          statusCode == 200 ||
          statusCode == 204 ||
          statusCode == 405) {
        continue;
      }
      throw StateError('WebDAV MKCOL failed with status $statusCode');
    }
  }

  Future<Response<Object?>> _request({
    required String method,
    required Uri uri,
    Map<String, String> headers = const <String, String>{},
    Object? data,
    ResponseType responseType = ResponseType.plain,
    bool Function(int? code)? validateStatus,
  }) async {
    _logger.info(
      'Sync WebDAV request',
      context: <String, Object?>{'method': method, 'uri': uri.toString()},
    );
    return _dio.request<Object?>(
      uri.toString(),
      data: data,
      options: Options(
        method: method,
        responseType: responseType,
        headers: <String, String>{
          'Authorization': _buildBasicAuthorization(),
          ...headers,
        },
        sendTimeout: const Duration(seconds: 10),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 12),
        validateStatus: validateStatus ?? (code) => code != null && code < 500,
      ),
    );
  }

  String _buildBasicAuthorization() {
    final raw = '$_username:$_password';
    final encoded = base64Encode(utf8.encode(raw));
    return 'Basic $encoded';
  }

  Uri _buildScopedUri(String relativePath, {required bool directory}) {
    return _buildAbsoluteUri(<String>[
      ..._endpointPathSegments,
      ..._basePathSegments,
      ..._normalizeSegments(relativePath),
    ], directory: directory);
  }

  Uri _buildAbsoluteUri(List<String> segments, {required bool directory}) {
    var path = '/';
    if (segments.isNotEmpty) {
      path = '/${segments.join('/')}';
    }
    if (directory && !path.endsWith('/')) {
      path = '$path/';
    }
    return _endpointUri.replace(path: path, query: null, fragment: null);
  }

  static Uri _normalizeEndpoint(String endpointUrl) {
    final raw = endpointUrl.trim();
    if (raw.isEmpty) {
      throw const FormatException('Endpoint URL is required.');
    }
    final uri = Uri.parse(raw);
    if (!uri.hasScheme || uri.host.trim().isEmpty) {
      throw const FormatException('Invalid endpoint URL.');
    }
    return uri;
  }

  static List<String> _normalizeSegments(String rawPath) {
    return rawPath
        .split('/')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String? _readFirstText(XmlElement element, List<String> names) {
    for (final name in names) {
      final matches = element.findAllElements(name);
      if (matches.isNotEmpty) {
        final text = matches.first.innerText.trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    for (final descendant in element.descendants.whereType<XmlElement>()) {
      final localName = descendant.name.local.trim();
      if (names.any((item) => item.split(':').last == localName)) {
        final text = descendant.innerText.trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  DateTime? _tryParseHttpDate(String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    try {
      return HttpDate.parse(normalized);
    } catch (_) {
      return null;
    }
  }
}
