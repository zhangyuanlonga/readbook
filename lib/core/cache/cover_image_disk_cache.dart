import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CoverImageDiskCache {
  CoverImageDiskCache({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
              responseType: ResponseType.bytes,
              followRedirects: true,
              validateStatus:
                  (statusCode) =>
                      statusCode != null &&
                      statusCode >= 200 &&
                      statusCode < 300,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 13; Pixel 7 Build/TQ3A.230901.001) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
              },
            ),
          );

  static final CoverImageDiskCache instance = CoverImageDiskCache();

  final Dio _dio;
  final Map<String, Future<File?>> _inflight = <String, Future<File?>>{};
  Directory? _cacheDir;

  static const Duration _stalePeriod = Duration(days: 30);

  Future<File?> resolve(String imageUrl) async {
    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      return null;
    }

    if (uri.scheme == 'file') {
      final localFile = File.fromUri(uri);
      return await _hasReadableBytes(localFile) ? localFile : null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    final cacheKey = crypto.md5.convert(utf8.encode(normalizedUrl)).toString();
    final task = _inflight.putIfAbsent(
      cacheKey,
      () => _resolveInternal(cacheKey: cacheKey, imageUrl: normalizedUrl),
    );

    try {
      return await task;
    } finally {
      _inflight.remove(cacheKey);
    }
  }

  Future<int> clearAll() async {
    final directory = await _ensureCacheDir();
    if (!await directory.exists()) {
      return 0;
    }

    var deletedCount = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      try {
        if (await entity.exists()) {
          await entity.delete();
          deletedCount++;
        }
      } catch (_) {
        // Ignore single-file cleanup failure and continue.
      }
    }

    return deletedCount;
  }

  Future<bool> clearByUrl(String imageUrl) async {
    final file = await _cacheFileForUrl(imageUrl);
    if (file == null) {
      return false;
    }

    try {
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<File?> _resolveInternal({
    required String cacheKey,
    required String imageUrl,
  }) async {
    final directory = await _ensureCacheDir();
    final file = File(p.join(directory.path, cacheKey));

    try {
      if (await _isUsable(file)) {
        return file;
      }
    } catch (_) {
      // Ignore cache read failures and retry network download.
    }

    try {
      final response = await _dio.get<List<int>>(imageUrl);
      final bytes = response.data ?? const <int>[];
      if (bytes.isEmpty) {
        return await _hasReadableBytes(file) ? file : null;
      }

      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsBytes(bytes, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
      return file;
    } catch (_) {
      return await _hasReadableBytes(file) ? file : null;
    }
  }

  Future<File?> _cacheFileForUrl(String imageUrl) async {
    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final cacheKey = crypto.md5.convert(utf8.encode(normalizedUrl)).toString();
    final directory = await _ensureCacheDir();
    return File(p.join(directory.path, cacheKey));
  }

  Future<Directory> _ensureCacheDir() async {
    final cached = _cacheDir;
    if (cached != null) {
      return cached;
    }

    final baseDir = await _resolveBaseDir();
    final directory = Directory(
      p.join(baseDir.path, 'flutter_appread', 'covers'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    _cacheDir = directory;
    return directory;
  }

  Future<Directory> _resolveBaseDir() async {
    final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (isFlutterTest) {
      return Directory.systemTemp;
    }

    try {
      return await getApplicationSupportDirectory();
    } on MissingPluginException {
      return Directory.systemTemp;
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  Future<bool> _isUsable(File file) async {
    if (!await _hasReadableBytes(file)) {
      return false;
    }

    final stat = await file.stat();
    final age = DateTime.now().difference(stat.modified);
    return age <= _stalePeriod;
  }

  Future<bool> _hasReadableBytes(File file) async {
    if (!await file.exists()) {
      return false;
    }
    return await file.length() > 0;
  }
}
