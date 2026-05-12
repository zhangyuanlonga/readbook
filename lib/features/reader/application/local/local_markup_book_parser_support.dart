import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/reader_document.dart';
import 'local_book_parser.dart';
import 'local_text_encoding_detector.dart';

class LocalMarkupBookParserSupport {
  const LocalMarkupBookParserSupport({
    LocalTextEncodingDetector textEncodingDetector =
        const LocalTextEncodingDetector(),
  }) : _textEncodingDetector = textEncodingDetector;

  final LocalTextEncodingDetector _textEncodingDetector;

  Future<LocalParsedBook> parseHtmlBook({
    required LocalBook book,
    required String html,
    String? title,
    bool preferProvidedTitle = false,
    String? preferredAuthor,
    String? preferredDescription,
    String? preferredCoverSource,
    List<Directory> additionalBaseDirectories = const <Directory>[],
    bool resetAssetDirectory = true,
  }) async {
    final document = html_parser.parse(html);
    final assetRootDir =
        resetAssetDirectory
            ? await _prepareAssetDirectory(book)
            : await _ensureAssetDirectory(book);
    final baseDirectories = await _resolveBaseDirectories(
      book,
      additionalBaseDirectories: additionalBaseDirectories,
    );
    final structured = await _buildStructuredDocument(
      document: document,
      assetRootDir: assetRootDir,
      baseDirectories: baseDirectories,
    );

    if (structured.document.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '本地 HTML 未解析出可读内容。',
      );
    }

    final parsedTitle = _resolveBookTitle(
      document: document,
      fallback: title ?? book.title,
      preferFallback: preferProvidedTitle,
    );
    final parsedAuthor =
        _normalizeOptional(preferredAuthor) ?? _resolveBookAuthor(document);
    final parsedDescription =
        _normalizeOptional(preferredDescription) ??
        _resolveBookDescription(
          document: document,
          structuredDocument: structured.document,
        );
    final coverSelection = await _resolveCoverSelection(
      document: document,
      structured: structured,
      assetRootDir: assetRootDir,
      baseDirectories: baseDirectories,
      preferredCoverSource: preferredCoverSource,
    );
    final chapters = _splitChapters(
      document: structured.document,
      fallbackTitle: parsedTitle,
    );

    return LocalParsedBook(
      chapters: chapters,
      title: parsedTitle,
      author: parsedAuthor,
      description: parsedDescription,
      coverPath: coverSelection?.path,
    );
  }

  Future<String> decodeHtmlFile(LocalBook book) async {
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
        briefMessage: '本地文件为空，无法建立章节索引。',
      );
    }
    final declaredCharset =
        LocalTextEncodingDetector.extractDeclaredCharsetFromHtml(bytes);
    final decoded = _textEncodingDetector.decodeBestEffort(
      bytes,
      preferredCharset: book.charset,
      hintedCharset: declaredCharset,
      htmlAware: true,
    );
    return decoded.text;
  }

  Future<String> decodeTextFile(LocalBook book) async {
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
        briefMessage: '本地文件为空，无法建立章节索引。',
      );
    }
    final decoded = await _textEncodingDetector.decodeBestEffortAsync(
      bytes,
      preferredCharset: book.charset,
      hintedCharset: book.charset,
      htmlAware: false,
    );
    return decoded.text;
  }

  Future<Directory> _prepareAssetDirectory(LocalBook book) async {
    final directory = resolveAssetDirectory(book);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _ensureAssetDirectory(LocalBook book) async {
    final directory = resolveAssetDirectory(book);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<List<Directory>> _resolveBaseDirectories(
    LocalBook book, {
    List<Directory> additionalBaseDirectories = const <Directory>[],
  }) async {
    final directories = <Directory>[];
    final sourcePath = book.sourcePath?.trim() ?? '';
    if (sourcePath.isNotEmpty) {
      directories.add(Directory(p.dirname(sourcePath)));
    }
    directories.add(Directory(p.dirname(book.storagePath)));
    directories.addAll(additionalBaseDirectories);
    return directories;
  }

  Future<_StructuredDocumentResult> _buildStructuredDocument({
    required dom.Document document,
    required Directory assetRootDir,
    required List<Directory> baseDirectories,
  }) async {
    final root = document.body ?? document.documentElement;
    if (root == null) {
      return _StructuredDocumentResult(
        document: ReaderDocument(blocks: const <ReaderBlock>[]),
      );
    }

    final blocks = <ReaderBlock>[];
    final imageCandidates = <_CoverCandidate>[];
    var buffer = StringBuffer();

    void flushBuffer() {
      final normalized = _normalizeInlineText(buffer.toString());
      if (normalized.isNotEmpty) {
        blocks.add(ReaderTextBlock(text: normalized));
      }
      buffer = StringBuffer();
    }

    Future<void> addImage(
      dom.Element element,
      Map<String, String> attributes,
    ) async {
      final imageUrl = await _resolveImageUrl(
        attributes: attributes,
        assetRootDir: assetRootDir,
        baseDirectories: baseDirectories,
      );
      if (imageUrl != null && imageUrl.isNotEmpty) {
        blocks.add(ReaderImageBlock(imageUrl: imageUrl));
        final candidate = _buildCoverCandidate(
          element: element,
          imageUrl: imageUrl,
          blockIndex: blocks.length - 1,
          blocks: blocks,
        );
        if (candidate != null) {
          imageCandidates.add(candidate);
        }
      }
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
      if (_ignoredTags.contains(tagName)) {
        return;
      }
      if (tagName == 'br') {
        buffer.write('\n');
        return;
      }
      if (_isImageTag(tagName)) {
        flushBuffer();
        await addImage(
          node,
          node.attributes.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
        return;
      }
      if (_isHeadingTag(tagName)) {
        flushBuffer();
        final text = _normalizeInlineText(node.text);
        if (text.isNotEmpty) {
          blocks.add(
            ReaderTitleBlock(text: text, level: _headingLevel(tagName)),
          );
        }
        return;
      }
      if (tagName == 'blockquote') {
        flushBuffer();
        final text = _normalizeInlineText(node.text);
        if (text.isNotEmpty) {
          blocks.add(ReaderQuoteBlock(text: text));
        }
        return;
      }
      if (tagName == 'li') {
        flushBuffer();
        final text = _normalizeInlineText(node.text);
        if (text.isNotEmpty) {
          blocks.add(ReaderListItemBlock(text: text));
        }
        return;
      }
      if (tagName == 'figcaption') {
        flushBuffer();
        final text = _normalizeInlineText(node.text);
        if (text.isNotEmpty) {
          blocks.add(ReaderCaptionBlock(text: text));
        }
        return;
      }
      if (_isFootnoteElement(node, tagName: tagName)) {
        flushBuffer();
        final text = _normalizeInlineText(node.text);
        if (text.isNotEmpty) {
          blocks.add(ReaderFootnoteBlock(text: text));
        }
        return;
      }

      final blockLevel = _blockLevelTags.contains(tagName);
      if (blockLevel) {
        flushBuffer();
      }
      for (final child in node.nodes) {
        await walk(child);
      }
      if (blockLevel) {
        flushBuffer();
      }
    }

    for (final child in root.nodes) {
      await walk(child);
    }
    flushBuffer();

    return _StructuredDocumentResult(
      document: ReaderDocument(blocks: blocks),
      imageCandidates: List<_CoverCandidate>.unmodifiable(imageCandidates),
    );
  }

  Future<String?> _resolveImageUrl({
    required Map<String, String> attributes,
    required Directory assetRootDir,
    required List<Directory> baseDirectories,
  }) async {
    final rawSource = _resolveImageSource(attributes);
    if (rawSource == null) {
      return null;
    }
    final normalizedSource = rawSource.trim();
    if (normalizedSource.isEmpty) {
      return null;
    }
    if (normalizedSource.startsWith('http://') ||
        normalizedSource.startsWith('https://') ||
        normalizedSource.startsWith('data:')) {
      return normalizedSource;
    }

    File? sourceFile;
    if (normalizedSource.startsWith('file://')) {
      sourceFile = File.fromUri(Uri.parse(normalizedSource));
    } else if (p.isAbsolute(normalizedSource)) {
      sourceFile = File(normalizedSource);
    } else {
      final decodedPath = Uri.decodeFull(
        normalizedSource.split('#').first.split('?').first,
      );
      for (final baseDirectory in baseDirectories) {
        final candidate = File(
          p.normalize(p.join(baseDirectory.path, decodedPath)),
        );
        if (await candidate.exists()) {
          sourceFile = candidate;
          break;
        }
      }
    }

    if (sourceFile == null || !await sourceFile.exists()) {
      return null;
    }

    final extension = p.extension(sourceFile.path).toLowerCase();
    if (!_supportedImageExtensions.contains(extension)) {
      return null;
    }

    final safeRelativePath = _safeAssetRelativePath(
      normalizedSource.isNotEmpty
          ? normalizedSource
          : p.basename(sourceFile.path),
      fallbackExtension: extension,
    );
    final targetFile = File(p.join(assetRootDir.path, safeRelativePath));
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }
    await sourceFile.copy(targetFile.path);
    return targetFile.uri.toString();
  }

  List<LocalParsedChapter> _splitChapters({
    required ReaderDocument document,
    required String fallbackTitle,
  }) {
    final topLevelTitles = document.blocks
        .whereType<ReaderTitleBlock>()
        .where((block) => block.level <= 2)
        .toList(growable: false);
    if (topLevelTitles.length < 2) {
      return <LocalParsedChapter>[
        _buildChapter(
          title: _resolveChapterTitle(document, fallbackTitle: fallbackTitle),
          document: document,
        ),
      ];
    }

    final chapters = <LocalParsedChapter>[];
    final prefaceBlocks = <ReaderBlock>[];
    String? currentTitle;
    final currentBlocks = <ReaderBlock>[];

    void pushCurrent() {
      if (currentTitle == null || currentBlocks.isEmpty) {
        return;
      }
      chapters.add(
        _buildChapter(
          title: currentTitle,
          document: ReaderDocument(
            blocks: List<ReaderBlock>.from(currentBlocks),
          ),
        ),
      );
      currentBlocks.clear();
    }

    for (final block in document.blocks) {
      if (block is ReaderTitleBlock && block.level <= 2) {
        if (currentTitle == null && prefaceBlocks.isNotEmpty) {
          chapters.add(
            _buildChapter(
              title: '前言',
              document: ReaderDocument(
                blocks: List<ReaderBlock>.from(prefaceBlocks),
              ),
            ),
          );
          prefaceBlocks.clear();
        } else {
          pushCurrent();
        }
        currentTitle = block.text;
        currentBlocks
          ..clear()
          ..add(block);
        continue;
      }

      if (currentTitle == null) {
        prefaceBlocks.add(block);
      } else {
        currentBlocks.add(block);
      }
    }

    pushCurrent();

    if (chapters.isEmpty) {
      return <LocalParsedChapter>[
        _buildChapter(
          title: _resolveChapterTitle(document, fallbackTitle: fallbackTitle),
          document: document,
        ),
      ];
    }
    return chapters;
  }

  LocalParsedChapter _buildChapter({
    required String title,
    required ReaderDocument document,
  }) {
    return LocalParsedChapter(
      title: title,
      content: document.compatibilityContent,
      imageUrls: document.imageUrls,
      document: document,
    );
  }

  String _resolveBookTitle({
    required dom.Document document,
    required String fallback,
    bool preferFallback = false,
  }) {
    if (preferFallback) {
      return fallback;
    }
    final raw =
        document.querySelector('title')?.text ??
        document.querySelector('h1')?.text ??
        document.querySelector('h2')?.text ??
        fallback;
    final normalized = _normalizeInlineText(raw);
    return normalized.isEmpty ? fallback : normalized;
  }

  String? _resolveBookAuthor(dom.Document document) {
    final metaAuthor =
        _extractMetaContent(document, keys: const <String>['author']) ??
        _extractMetaContent(document, keys: const <String>['article:author']);
    final normalizedMetaAuthor = _normalizeInlineText(metaAuthor ?? '');
    if (normalizedMetaAuthor.isNotEmpty) {
      return normalizedMetaAuthor;
    }

    for (final selector in const <String>[
      '.author',
      '.byline',
      '[rel="author"]',
      '[itemprop="author"]',
    ]) {
      final text = _normalizeInlineText(
        document.querySelector(selector)?.text ?? '',
      );
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _resolveBookDescription({
    required dom.Document document,
    required ReaderDocument structuredDocument,
  }) {
    final metaDescription =
        _extractMetaContent(
          document,
          keys: const <String>['description', 'og:description'],
        ) ??
        _extractMetaContent(
          document,
          keys: const <String>['twitter:description'],
        );
    final normalizedMetaDescription = _normalizeInlineText(
      metaDescription ?? '',
    );
    if (normalizedMetaDescription.isNotEmpty) {
      return normalizedMetaDescription;
    }

    for (final block in structuredDocument.blocks) {
      final text = switch (block) {
        ReaderTextBlock(:final text) => _normalizeInlineText(text),
        ReaderQuoteBlock(:final text) => _normalizeInlineText(text),
        ReaderCaptionBlock(:final text) => _normalizeInlineText(text),
        ReaderListItemBlock(:final text) => _normalizeInlineText(text),
        ReaderTitleBlock() => '',
        ReaderImageBlock() => '',
        ReaderFootnoteBlock() => '',
        _ => '',
      };
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  Future<_CoverSelection?> _resolveCoverSelection({
    required dom.Document document,
    required _StructuredDocumentResult structured,
    required Directory assetRootDir,
    required List<Directory> baseDirectories,
    required String? preferredCoverSource,
  }) async {
    final explicitSources = <_CoverSelection>[];

    final preferred = await _resolveExplicitCoverSelection(
      rawSource: preferredCoverSource,
      source: _CoverSource.frontMatter,
      assetRootDir: assetRootDir,
      baseDirectories: baseDirectories,
    );
    if (preferred != null) {
      explicitSources.add(preferred);
    }

    for (final rawSource in _resolveExplicitHtmlCoverSources(document)) {
      final selection = await _resolveExplicitCoverSelection(
        rawSource: rawSource,
        source: _CoverSource.meta,
        assetRootDir: assetRootDir,
        baseDirectories: baseDirectories,
      );
      if (selection != null) {
        explicitSources.add(selection);
      }
    }

    if (explicitSources.isNotEmpty) {
      explicitSources.sort((a, b) => b.confidence.compareTo(a.confidence));
      return explicitSources.first;
    }

    final candidates = structured.imageCandidates;
    if (candidates.isEmpty) {
      return null;
    }
    final ranked = List<_CoverCandidate>.from(candidates)
      ..sort((a, b) => b.score.compareTo(a.score));
    final best = ranked.first;
    if (best.score >= 70) {
      return _CoverSelection(
        path: best.path,
        confidence: best.score / 100,
        source: best.source,
      );
    }

    if (candidates.length == 1 && best.score >= 35) {
      return _CoverSelection(
        path: best.path,
        confidence: best.score / 100,
        source: _CoverSource.weakFallback,
      );
    }
    return null;
  }

  Future<_CoverSelection?> _resolveExplicitCoverSelection({
    required String? rawSource,
    required _CoverSource source,
    required Directory assetRootDir,
    required List<Directory> baseDirectories,
  }) async {
    final normalized = _normalizeOptional(rawSource);
    if (normalized == null) {
      return null;
    }
    final imageUrl = await _resolveImageUrl(
      attributes: <String, String>{'src': normalized},
      assetRootDir: assetRootDir,
      baseDirectories: baseDirectories,
    );
    final path = _filePathFromImageUrl(imageUrl);
    if (path == null) {
      return null;
    }
    return _CoverSelection(
      path: path,
      confidence: source == _CoverSource.frontMatter ? 1.0 : 0.98,
      source: source,
    );
  }

  Iterable<String> _resolveExplicitHtmlCoverSources(
    dom.Document document,
  ) sync* {
    for (final key in const <String>[
      'og:image',
      'twitter:image',
      'image',
      'thumbnail',
    ]) {
      final content = _extractMetaContent(document, keys: <String>[key]);
      if (content != null && content.isNotEmpty) {
        yield content;
      }
    }

    for (final link in document.querySelectorAll('link')) {
      final rel = (link.attributes['rel'] ?? '').trim().toLowerCase();
      if (rel == 'image_src') {
        final href = _normalizeOptional(link.attributes['href']);
        if (href != null) {
          yield href;
        }
      }
    }
  }

  String _resolveChapterTitle(
    ReaderDocument document, {
    required String fallbackTitle,
  }) {
    for (final block in document.blocks) {
      if (block is ReaderTitleBlock) {
        final normalized = _normalizeInlineText(block.text);
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }
    return fallbackTitle;
  }

  String? _extractMetaContent(
    dom.Document document, {
    required List<String> keys,
  }) {
    final normalizedKeys = keys.map((key) => key.toLowerCase()).toSet();
    for (final meta in document.querySelectorAll('meta')) {
      final name = (meta.attributes['name'] ?? '').trim().toLowerCase();
      final property = (meta.attributes['property'] ?? '').trim().toLowerCase();
      if (!normalizedKeys.contains(name) &&
          !normalizedKeys.contains(property)) {
        continue;
      }
      final content = _normalizeInlineText(meta.attributes['content'] ?? '');
      if (content.isNotEmpty) {
        return content;
      }
    }
    return null;
  }

  _CoverCandidate? _buildCoverCandidate({
    required dom.Element element,
    required String imageUrl,
    required int blockIndex,
    required List<ReaderBlock> blocks,
  }) {
    final filePath = _filePathFromImageUrl(imageUrl);
    if (filePath == null) {
      return null;
    }
    var score = 10;
    final normalizedPath = filePath.toLowerCase();
    final signals = <String>[
      normalizedPath,
      (element.id).toLowerCase(),
      (element.className).toLowerCase(),
      (element.attributes['alt'] ?? '').toLowerCase(),
      (element.attributes['title'] ?? '').toLowerCase(),
    ].join(' ');

    if (_coverKeywordPattern.hasMatch(signals)) {
      score += 70;
    }
    if (blockIndex == 0) {
      score += 25;
    } else if (blockIndex <= 2) {
      score += 10;
    }
    final hasTextBefore = blocks
        .take(blockIndex)
        .any(
          (block) =>
              block is ReaderTextBlock ||
              block is ReaderListItemBlock ||
              block is ReaderQuoteBlock ||
              block is ReaderCaptionBlock,
        );
    if (hasTextBefore) {
      score -= 20;
    }

    return _CoverCandidate(
      path: filePath,
      score: score.clamp(0, 100),
      source:
          _coverKeywordPattern.hasMatch(signals)
              ? _CoverSource.heuristicKeyword
              : _CoverSource.heuristicPosition,
    );
  }

  String? _filePathFromImageUrl(String? imageUrl) {
    final normalized = _normalizeOptional(imageUrl);
    if (normalized == null) {
      return null;
    }
    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.scheme == 'file') {
      return File.fromUri(uri).path;
    }
    return null;
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool _isImageTag(String tagName) => tagName == 'img' || tagName == 'image';

  bool _isHeadingTag(String tagName) =>
      tagName == 'h1' ||
      tagName == 'h2' ||
      tagName == 'h3' ||
      tagName == 'h4' ||
      tagName == 'h5' ||
      tagName == 'h6';

  int _headingLevel(String tagName) {
    final level = int.tryParse(tagName.replaceFirst('h', ''));
    if (level == null || level <= 0) {
      return 1;
    }
    return level;
  }

  bool _isFootnoteElement(dom.Element element, {required String tagName}) {
    final id = (element.id).toLowerCase();
    final className = (element.className).toLowerCase();
    return tagName == 'aside' &&
        (id.contains('footnote') || className.contains('footnote'));
  }

  String? _resolveImageSource(Map<String, String> attributes) {
    for (final key in const <String>['src', 'data-src', 'xlink:href', 'href']) {
      final value = attributes[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String _safeAssetRelativePath(
    String rawPath, {
    required String fallbackExtension,
  }) {
    final normalized = rawPath
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^[a-zA-Z]+://'), '')
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll('../', '')
        .replaceAll('..', '');
    final segments = p.posix
        .split(normalized)
        .where(
          (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
        )
        .toList(growable: false);
    if (segments.isEmpty) {
      return 'image_${DateTime.now().microsecondsSinceEpoch}$fallbackExtension';
    }
    return p.joinAll(segments);
  }

  String _normalizeInlineText(String text) {
    return text
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static Directory resolveAssetDirectory(LocalBook book) {
    final storageDir = Directory(p.dirname(book.storagePath));
    final folderName = '${p.basenameWithoutExtension(book.storagePath)}_assets';
    return Directory(p.join(storageDir.path, folderName));
  }

  static const Set<String> _supportedImageExtensions = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
    '.svg',
  };

  static const Set<String> _ignoredTags = <String>{
    'script',
    'style',
    'noscript',
    'meta',
    'link',
    'head',
  };

  static const Set<String> _blockLevelTags = <String>{
    'p',
    'div',
    'section',
    'article',
    'main',
    'header',
    'footer',
    'ul',
    'ol',
    'table',
    'tbody',
    'thead',
    'tr',
    'td',
    'th',
    'figure',
  };

  static final RegExp _coverKeywordPattern = RegExp(
    r'(?:^|[^a-z])(cover|poster|hero|titlepage|title_page|封面)(?:[^a-z]|$)',
    caseSensitive: false,
  );
}

class _StructuredDocumentResult {
  const _StructuredDocumentResult({
    required this.document,
    this.imageCandidates = const <_CoverCandidate>[],
  });

  final ReaderDocument document;
  final List<_CoverCandidate> imageCandidates;
}

class _CoverSelection {
  const _CoverSelection({
    required this.path,
    required this.confidence,
    required this.source,
  });

  final String path;
  final double confidence;
  final _CoverSource source;
}

class _CoverCandidate {
  const _CoverCandidate({
    required this.path,
    required this.score,
    required this.source,
  });

  final String path;
  final int score;
  final _CoverSource source;
}

enum _CoverSource {
  frontMatter,
  meta,
  heuristicKeyword,
  heuristicPosition,
  weakFallback,
}
