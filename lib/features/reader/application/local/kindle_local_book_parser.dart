import 'dart:io';
import 'dart:typed_data';

import 'package:dart_mobi/dart_mobi.dart' as mobi;
import 'package:path/path.dart' as p;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../domain/entities/local_book.dart';
import 'local_book_parser.dart';
import 'local_markup_book_parser_support.dart';
import 'local_text_encoding_detector.dart';

/// MOBI / AZW / AZW3 通过 `dart_mobi` 读取容器，再复用本地 markup 解析链。
///
/// 该能力按实验能力维护：仅承诺无 DRM 的基础样例，遇到加密、异常资源或复杂
/// Kindle 变体时应给出清晰失败提示。若后续有维护更活跃、覆盖更完整的库，
/// 优先替换 `LocalKindleContainerExtractor`，不要把格式细节继续扩散到 UI。
class KindleLocalBookParser implements LocalBookParser {
  const KindleLocalBookParser({
    LocalKindleContainerExtractor extractor =
        const PackageKindleContainerExtractor(),
    LocalMarkupBookParserSupport markupSupport =
        const LocalMarkupBookParserSupport(),
  }) : _extractor = extractor,
       _markupSupport = markupSupport;

  final LocalKindleContainerExtractor _extractor;
  final LocalMarkupBookParserSupport _markupSupport;

  @override
  bool supports(LocalBookFormat format) {
    return format == LocalBookFormat.mobi ||
        format == LocalBookFormat.azw ||
        format == LocalBookFormat.azw3;
  }

  @override
  Future<LocalParsedBook> parse(LocalBook book) async {
    final file = File(book.storagePath);
    if (!await file.exists()) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地文件不存在：${book.storagePath}',
      );
    }

    final payload = await _extractPayload(book.storagePath);
    if (payload.encrypted) {
      throw AppException(
        code: ErrorCode.decode,
        stage: ErrorStage.content,
        briefMessage: 'Kindle 文件可能已加密或受 DRM 保护，当前仅支持无 DRM 文件。',
      );
    }

    final normalizedMarkup = payload.markupHtml.trim();
    if (normalizedMarkup.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: 'Kindle 文件未提取到可读正文，可能结构异常或受保护。',
      );
    }

    final assetRootDir = LocalMarkupBookParserSupport.resolveAssetDirectory(
      book,
    );
    if (await assetRootDir.exists()) {
      await assetRootDir.delete(recursive: true);
    }
    await assetRootDir.create(recursive: true);

    String? coverPath;
    for (final resource in payload.resources) {
      final targetFile = File(p.join(assetRootDir.path, resource.fileName));
      if (!await targetFile.parent.exists()) {
        await targetFile.parent.create(recursive: true);
      }
      await targetFile.writeAsBytes(resource.bytes, flush: true);
      if (payload.coverFileName == resource.fileName) {
        coverPath = targetFile.path;
      }
    }

    final parsed = await _markupSupport.parseHtmlBook(
      book: book,
      html: payload.markupHtml,
      title: payload.title ?? book.title,
      additionalBaseDirectories: <Directory>[assetRootDir],
      resetAssetDirectory: false,
    );

    return LocalParsedBook(
      chapters: parsed.chapters,
      title: _normalizeRequired(
        payload.title,
        fallback: parsed.title ?? book.title,
      ),
      author: _normalizeNullable(payload.author, fallback: parsed.author),
      description: _normalizeNullable(
        payload.description,
        fallback: parsed.description,
      ),
      coverPath: coverPath ?? parsed.coverPath,
    );
  }

  Future<LocalKindleParsePayload> _extractPayload(String path) async {
    try {
      return await _extractor.extract(path);
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('encrypt') ||
          text.contains('drm') ||
          text.contains('pid')) {
        throw AppException(
          code: ErrorCode.decode,
          stage: ErrorStage.content,
          briefMessage: 'Kindle 文件可能已加密或受 DRM 保护，当前仅支持无 DRM 文件。',
        );
      }
      throw AppException(
        code: ErrorCode.decode,
        stage: ErrorStage.content,
        briefMessage: 'Kindle 文件解析失败：$error',
      );
    }
  }

  String _normalizeRequired(String? value, {required String fallback}) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    return fallback;
  }

  String? _normalizeNullable(String? value, {required String? fallback}) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    final fallbackNormalized = fallback?.trim();
    if (fallbackNormalized == null || fallbackNormalized.isEmpty) {
      return null;
    }
    return fallbackNormalized;
  }
}

abstract class LocalKindleContainerExtractor {
  const LocalKindleContainerExtractor();

  Future<LocalKindleParsePayload> extract(String path);
}

class LocalKindleParsePayload {
  const LocalKindleParsePayload({
    required this.markupHtml,
    this.title,
    this.author,
    this.description,
    this.resources = const <LocalKindleResource>[],
    this.coverFileName,
    this.encrypted = false,
  });

  final String markupHtml;
  final String? title;
  final String? author;
  final String? description;
  final List<LocalKindleResource> resources;
  final String? coverFileName;
  final bool encrypted;
}

class LocalKindleResource {
  const LocalKindleResource({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class PackageKindleContainerExtractor implements LocalKindleContainerExtractor {
  const PackageKindleContainerExtractor({
    LocalTextEncodingDetector textEncodingDetector =
        const LocalTextEncodingDetector(),
  }) : _textEncodingDetector = textEncodingDetector;

  final LocalTextEncodingDetector _textEncodingDetector;

  @override
  Future<LocalKindleParsePayload> extract(String path) async {
    final bytes = await File(path).readAsBytes();
    final mobiData = await mobi.DartMobiReader.read(bytes);
    final encrypted =
        (mobiData.record0header?.encryptionType ?? 0) != 0 ||
        ((mobiData.mobiHeader?.drmFlags ?? 0) != 0);
    final rawml = mobiData.parseOpt(true, true, false);
    final markupBytes = rawml.markup?.data;
    final markupHtml =
        markupBytes == null || markupBytes.isEmpty
            ? ''
            : _textEncodingDetector
                .decodeBestEffort(markupBytes, htmlAware: true)
                .text;

    final resources = <LocalKindleResource>[];
    mobi.MobiPart? resource = rawml.resources;
    while (resource != null) {
      final data = resource.data;
      if (data != null &&
          data.isNotEmpty &&
          _resourceExtension(resource.fileType) != null) {
        final extension = _resourceExtension(resource.fileType)!;
        resources.add(
          LocalKindleResource(
            fileName:
                'resource${resource.uid.toString().padLeft(5, '0')}.$extension',
            bytes: data,
          ),
        );
      }
      resource = resource.next;
    }

    final coverUid = _extractCoverUid(mobiData);
    String? coverFileName;
    if (coverUid != null) {
      final prefix = 'resource${coverUid.toString().padLeft(5, '0')}.';
      for (final resource in resources) {
        if (resource.fileName.startsWith(prefix)) {
          coverFileName = resource.fileName;
          break;
        }
      }
    }

    return LocalKindleParsePayload(
      markupHtml: markupHtml,
      title:
          _extractTextExth(mobiData, mobi.MobiExthTag.title) ??
          mobiData.pdbHeader?.name,
      author: _extractTextExth(mobiData, mobi.MobiExthTag.author),
      description:
          _extractTextExth(mobiData, mobi.MobiExthTag.description) ??
          _extractTextExth(mobiData, mobi.MobiExthTag.subject),
      resources: resources,
      coverFileName: coverFileName,
      encrypted: encrypted,
    );
  }

  String? _extractTextExth(mobi.MobiData data, mobi.MobiExthTag tag) {
    final record = _findExthRecord(data, tag);
    final bytes = record?.data;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final normalized =
        _textEncodingDetector.decodeBestEffort(bytes).text.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  int? _extractCoverUid(mobi.MobiData data) {
    final record = _findExthRecord(data, mobi.MobiExthTag.coverOffset);
    final bytes = record?.data;
    final size = record?.size;
    if (bytes == null || bytes.isEmpty || size == null) {
      return null;
    }
    return mobi.DartMobiReader.decodeExthValue(bytes, size);
  }

  mobi.MobiExthHeader? _findExthRecord(
    mobi.MobiData data,
    mobi.MobiExthTag tag,
  ) {
    var current = data.mobiExthHeader;
    while (current != null) {
      if (current.tag == tag.value) {
        return current;
      }
      current = current.next;
    }
    return null;
  }

  String? _resourceExtension(mobi.MobiFileType type) {
    return switch (type) {
      mobi.MobiFileType.jpg => 'jpg',
      mobi.MobiFileType.gif => 'gif',
      mobi.MobiFileType.png => 'png',
      mobi.MobiFileType.bmp => 'bmp',
      mobi.MobiFileType.svg => 'svg',
      _ => null,
    };
  }
}
