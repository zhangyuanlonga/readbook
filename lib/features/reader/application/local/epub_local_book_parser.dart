import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../domain/entities/local_book.dart';
import 'local_book_parser.dart';

class EpubLocalBookParser implements LocalBookParser {
  const EpubLocalBookParser();

  static const List<String> _supportedExtensions = <String>[
    '.xhtml',
    '.html',
    '.htm',
  ];

  static const Set<String> _supportedImageExtensions = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
  };

  static const String _inlineImageMarkerPrefix = '[[appread-image:';
  static const String _inlineImageMarkerSuffix = ']]';

  @override
  bool supports(LocalBookFormat format) {
    return format == LocalBookFormat.epub;
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

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: 'EPUB 文件为空，无法建立章节索引。',
      );
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (error) {
      throw AppException(
        code: ErrorCode.decode,
        stage: ErrorStage.content,
        briefMessage: 'EPUB 解压失败：$error',
      );
    }

    final chapterCandidates = archive.files
        .where((entry) {
          if (!entry.isFile) {
            return false;
          }
          final lowerName = entry.name.toLowerCase();
          if (lowerName.contains('meta-inf/')) {
            return false;
          }
          return _supportedExtensions.any(lowerName.endsWith);
        })
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));

    final assetDir = await _prepareAssetDirectory(book);
    final archiveFileIndex = <String, ArchiveFile>{
      for (final entry in archive.files.where((item) => item.isFile))
        _normalizeArchivePath(entry.name): entry,
    };

    final chapters = <LocalParsedChapter>[];
    var offset = 0;
    var index = 0;

    for (final entry in chapterCandidates) {
      final html = _readArchiveEntryAsText(entry);
      if (html.trim().isEmpty) {
        continue;
      }

      final document = html_parser.parse(html);
      final extraction = await _extractChapterContent(
        book: book,
        documentHtml: document.outerHtml,
        chapterEntryName: entry.name,
        archiveFileIndex: archiveFileIndex,
        assetRootDir: assetDir,
      );

      final normalized = _normalizeText(extraction.content);
      if (normalized.length < 20 && extraction.imageUrls.isEmpty) {
        continue;
      }

      final title = _resolveTitle(document.outerHtml, entry.name, index + 1);
      final start = offset;
      offset += normalized.length;

      chapters.add(
        LocalParsedChapter(
          title: title,
          content: normalized,
          imageUrls: extraction.imageUrls,
          startOffset: start,
          endOffset: offset,
        ),
      );
      offset += 1;
      index += 1;
    }

    if (chapters.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: 'EPUB 未解析出正文章节，可能是受保护或结构异常文件。',
      );
    }

    return LocalParsedBook(chapters: chapters);
  }

  static Directory resolveAssetDirectory(LocalBook book) {
    final storageDir = Directory(p.dirname(book.storagePath));
    final folderName = '${p.basenameWithoutExtension(book.storagePath)}_assets';
    return Directory(p.join(storageDir.path, folderName));
  }

  Future<Directory> _prepareAssetDirectory(LocalBook book) async {
    final directory = resolveAssetDirectory(book);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    return directory;
  }

  Future<_EpubChapterExtraction> _extractChapterContent({
    required LocalBook book,
    required String documentHtml,
    required String chapterEntryName,
    required Map<String, ArchiveFile> archiveFileIndex,
    required Directory assetRootDir,
  }) async {
    final document = html_parser.parse(documentHtml);
    final root = document.body ?? document.documentElement;
    if (root == null) {
      return const _EpubChapterExtraction(content: '', imageUrls: <String>[]);
    }

    final output = <String>[];
    final seen = <String>{};
    final blocks = <String>[];
    var buffer = StringBuffer();

    void flushBuffer() {
      final normalized = _normalizeInlineText(buffer.toString());
      if (normalized.isNotEmpty) {
        blocks.add(normalized);
      }
      buffer = StringBuffer();
    }

    Future<void> walk(dom.Node node) async {
      if (node is dom.Text) {
        buffer.write(node.text);
        return;
      }
      if (node is! dom.Element) {
        return;
      }

      final tagName = (node.localName ?? '').toLowerCase();
      if (tagName == 'img' || tagName == 'image') {
        flushBuffer();
        final imageUrl = await _resolveMaterializedImageUrl(
          attributes: node.attributes.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
          chapterEntryName: chapterEntryName,
          archiveFileIndex: archiveFileIndex,
          assetRootDir: assetRootDir,
        );
        if (imageUrl != null && imageUrl.isNotEmpty) {
          if (seen.add(imageUrl)) {
            output.add(imageUrl);
          }
          blocks.add(
            '$_inlineImageMarkerPrefix$imageUrl$_inlineImageMarkerSuffix',
          );
        }
        return;
      }

      if (tagName == 'br') {
        buffer.write('\n');
        return;
      }

      final isBlock = _isBlockElement(tagName);
      if (isBlock) {
        flushBuffer();
      }
      for (final child in node.nodes) {
        await walk(child);
      }
      if (isBlock) {
        flushBuffer();
      }
    }

    for (final child in root.nodes) {
      await walk(child);
    }
    flushBuffer();

    return _EpubChapterExtraction(
      content: blocks.join('\n\n'),
      imageUrls: output,
    );
  }

  bool _isBlockElement(String tagName) {
    return const <String>{
      'address',
      'article',
      'aside',
      'blockquote',
      'div',
      'dl',
      'fieldset',
      'figcaption',
      'figure',
      'footer',
      'form',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'header',
      'hr',
      'li',
      'main',
      'nav',
      'ol',
      'p',
      'pre',
      'section',
      'table',
      'tr',
      'td',
      'th',
      'ul',
    }.contains(tagName);
  }

  Future<String?> _resolveMaterializedImageUrl({
    required Map<String, String> attributes,
    required String chapterEntryName,
    required Map<String, ArchiveFile> archiveFileIndex,
    required Directory assetRootDir,
  }) async {
    final rawSrc = _resolveImageSource(attributes);
    if (rawSrc == null || rawSrc.isEmpty) {
      return null;
    }
    if (rawSrc.startsWith('data:image/')) {
      return rawSrc;
    }

    final resolvedPath = _resolveArchiveImagePath(
      chapterEntryName: chapterEntryName,
      rawSource: rawSrc,
    );
    if (resolvedPath == null) {
      return null;
    }
    if (resolvedPath.startsWith('http://') ||
        resolvedPath.startsWith('https://')) {
      return resolvedPath;
    }

    final archiveEntry = archiveFileIndex[resolvedPath];
    if (archiveEntry == null) {
      return null;
    }
    final lowerName = resolvedPath.toLowerCase();
    final extension = p.posix.extension(lowerName);
    if (!_supportedImageExtensions.contains(extension)) {
      return null;
    }

    final targetFile = File(
      p.join(assetRootDir.path, _safeAssetRelativePath(resolvedPath)),
    );
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }
    await targetFile.writeAsBytes(
      _readArchiveEntryBytes(archiveEntry),
      flush: true,
    );
    return targetFile.uri.toString();
  }

  String? _resolveImageSource(Map<String, String> attributes) {
    for (final key in const <String>['src', 'xlink:href', 'href', 'data-src']) {
      final value = attributes[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _resolveArchiveImagePath({
    required String chapterEntryName,
    required String rawSource,
  }) {
    final normalizedSource = rawSource.trim();
    if (normalizedSource.isEmpty) {
      return null;
    }
    if (normalizedSource.startsWith('http://') ||
        normalizedSource.startsWith('https://')) {
      return normalizedSource;
    }

    final noFragment =
        normalizedSource.split('#').first.split('?').first.trim();
    if (noFragment.isEmpty) {
      return null;
    }

    final decoded = Uri.decodeFull(noFragment).replaceAll('\\', '/');
    if (decoded.startsWith('/')) {
      return _normalizeArchivePath(decoded.substring(1));
    }

    final baseDir = p.posix.dirname(chapterEntryName);
    return _normalizeArchivePath(
      p.posix.normalize(p.posix.join(baseDir, decoded)),
    );
  }

  String _normalizeArchivePath(String value) {
    return value.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
  }

  String _safeAssetRelativePath(String archivePath) {
    final normalized = archivePath
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll('../', '')
        .replaceAll('..', '');
    final segments = p.posix
        .split(normalized)
        .where((item) => item.isNotEmpty && item != '.' && item != '..')
        .toList(growable: false);
    if (segments.isEmpty) {
      return 'image_${DateTime.now().microsecondsSinceEpoch}.bin';
    }
    return p.joinAll(segments);
  }

  String _readArchiveEntryAsText(ArchiveFile entry) {
    final bytes = _readArchiveEntryBytes(entry);
    if (bytes.isEmpty) {
      return '';
    }

    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  List<int> _readArchiveEntryBytes(ArchiveFile entry) {
    final content = entry.content;
    if (content is List<int>) {
      return content;
    }
    if (content is String) {
      return utf8.encode(content);
    }
    try {
      final dynamicContent = entry.content;
      if (dynamicContent is List<int>) {
        return dynamicContent;
      }
      if (dynamicContent is String) {
        return utf8.encode(dynamicContent);
      }
    } catch (_) {
      return const <int>[];
    }
    return const <int>[];
  }

  String _resolveTitle(String html, String entryName, int index) {
    final document = html_parser.parse(html);
    final titleCandidate =
        document.querySelector('h1')?.text ??
        document.querySelector('h2')?.text ??
        document.querySelector('h3')?.text ??
        document.querySelector('title')?.text;

    final normalized = _normalizeInlineText(titleCandidate ?? '');
    if (normalized.isNotEmpty) {
      return normalized;
    }

    final fileName = entryName.split('/').last;
    final dot = fileName.lastIndexOf('.');
    final fallback = dot > 0 ? fileName.substring(0, dot) : fileName;
    final fallbackNormalized = _normalizeInlineText(fallback);
    if (fallbackNormalized.isNotEmpty) {
      return fallbackNormalized;
    }

    return '第 $index 章';
  }

  String _normalizeText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t\u00A0]+'), ' ')
        .trim();
  }

  String _normalizeInlineText(String text) {
    return text
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}

class _EpubChapterExtraction {
  const _EpubChapterExtraction({
    required this.content,
    required this.imageUrls,
  });

  final String content;
  final List<String> imageUrls;
}
