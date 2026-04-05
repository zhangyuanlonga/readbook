import 'dart:collection';
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
import '../../../../domain/entities/local_chapter.dart';
import '../../../../domain/entities/reader_document.dart';
import 'local_text_encoding_detector.dart';
import 'local_book_parser.dart';

class EpubLocalBookParser implements LocalBookParser {
  const EpubLocalBookParser({
    LocalTextEncodingDetector textEncodingDetector =
        const LocalTextEncodingDetector(),
    EpubArchiveDecoder archiveDecoder = const EpubArchiveDecoder(),
  }) : _textEncodingDetector = textEncodingDetector,
       _archiveDecoder = archiveDecoder;

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
    '.svg',
  };

  static const List<String> _htmlCharsetCandidates = <String>[
    'utf-8',
    'utf-16be',
    'utf-16le',
    'gb18030',
    'gbk',
    'big5',
    'shift_jis',
    'euc-jp',
    'euc-kr',
    'windows-1252',
    'latin1',
  ];

  final LocalTextEncodingDetector _textEncodingDetector;
  final EpubArchiveDecoder _archiveDecoder;
  static final LinkedHashMap<String, _LoadedEpubArchive> _archiveCache =
      LinkedHashMap<String, _LoadedEpubArchive>();
  static const int _maxArchiveCacheEntries = 4;

  @override
  bool supports(LocalBookFormat format) {
    return format == LocalBookFormat.epub;
  }

  @override
  Future<LocalParsedBook> parse(LocalBook book) async {
    final loadedArchive = await _loadArchive(book);
    final chapterCandidates = _resolveChapterCandidates(
      archive: loadedArchive.archive,
      archiveFileIndex: loadedArchive.archiveFileIndex,
      packageDocument: loadedArchive.packageDocument,
    );
    final assetDir = await _prepareAssetDirectory(book);
    final metadata = _extractMetadata(
      loadedArchive.archiveFileIndex,
      packageDocument: loadedArchive.packageDocument,
    );
    final coverPath = await _materializeCoverPath(
      metadata: metadata,
      archiveFileIndex: loadedArchive.archiveFileIndex,
      assetRootDir: assetDir,
    );

    final chapters = <LocalParsedChapter>[];
    var index = 0;

    for (final entry in chapterCandidates) {
      final html = _readArchiveEntryAsText(entry);
      if (html.trim().isEmpty) {
        continue;
      }

      final document = html_parser.parse(html);
      final normalizedEntryPath = _normalizeArchivePath(entry.name);
      final preview = _buildChapterCandidatePreview(
        document: document,
        entryPath: normalizedEntryPath,
        index: index + 1,
      );
      if (preview.category != _EpubDocumentCategory.body) {
        continue;
      }
      if (!preview.hasReadableSignal) {
        continue;
      }

      chapters.add(
        LocalParsedChapter(
          title: preview.title,
          content: '',
          imageUrls: const <String>[],
          sourceRef: _normalizeArchivePath(entry.name),
          document: preview.document,
        ),
      );
      index += 1;
    }

    if (chapters.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: 'EPUB 未解析出正文章节，可能是受保护或结构异常文件。',
      );
    }
    return LocalParsedBook(
      chapters: chapters,
      title: metadata.title,
      author: metadata.author,
      coverPath: coverPath,
    );
  }

  Future<LocalParsedChapter> parseChapter({
    required LocalBook book,
    required LocalChapter chapter,
  }) async {
    final sourceRef = chapter.sourceRef?.trim() ?? '';
    if (sourceRef.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: 'EPUB 章节定位信息缺失，请重新索引后重试。',
      );
    }

    final loadedArchive = await _loadArchive(book);
    final archiveEntry = _findArchiveFile(
      loadedArchive.archiveFileIndex,
      sourceRef,
    );
    if (archiveEntry == null) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '未找到 EPUB 章节资源，请重新索引后重试。',
      );
    }

    final assetDir = await _ensureAssetDirectory(book);
    final html = _readArchiveEntryAsText(archiveEntry);
    final extraction = await _extractChapterContent(
      book: book,
      documentHtml: html,
      chapterEntryName: archiveEntry.name,
      archiveFileIndex: loadedArchive.archiveFileIndex,
      assetRootDir: assetDir,
    );
    final normalized = _normalizeText(extraction.content);
    if (normalized.isEmpty && extraction.imageUrls.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: 'EPUB 章节内容为空，请重新索引后重试。',
      );
    }
    final structuredDocument = _withFallbackChapterTitle(
      extraction.document,
      chapterTitle: chapter.title,
    );
    return LocalParsedChapter(
      title: chapter.title,
      content: structuredDocument.compatibilityContent,
      imageUrls: structuredDocument.imageUrls,
      sourceRef: sourceRef,
      document: structuredDocument,
    );
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

  Future<Directory> _ensureAssetDirectory(LocalBook book) async {
    final directory = resolveAssetDirectory(book);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  _EpubMetadata _extractMetadata(
    Map<String, ArchiveFile> archiveFileIndex, {
    required _EpubPackageDocument? packageDocument,
  }) {
    if (packageDocument == null) {
      return const _EpubMetadata();
    }

    final title = _extractFirstElementText(
      packageDocument.document,
      localNames: <String>{'dc:title', 'title'},
    );
    final author = _extractFirstElementText(
      packageDocument.document,
      localNames: <String>{'dc:creator', 'creator', 'dc:author', 'author'},
    );
    final coverArchivePath = _extractCoverArchivePath(
      document: packageDocument.document,
      packagePath: packageDocument.packagePath,
      archiveFileIndex: archiveFileIndex,
    );

    return _EpubMetadata(
      title: title,
      author: author,
      coverArchivePath: coverArchivePath,
    );
  }

  Future<_LoadedEpubArchive> _loadArchive(LocalBook book) async {
    final file = File(book.storagePath);
    if (!await file.exists()) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地文件不存在：${book.storagePath}',
      );
    }

    final stat = await file.stat();
    final cacheKey =
        '${book.storagePath}::${stat.size}::${stat.modified.millisecondsSinceEpoch}';
    final cached = _archiveCache.remove(cacheKey);
    if (cached != null) {
      _archiveCache[cacheKey] = cached;
      return cached;
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
      archive = _archiveDecoder.decodeBytes(bytes);
    } catch (error) {
      throw AppException(
        code: ErrorCode.decode,
        stage: ErrorStage.content,
        briefMessage: 'EPUB 解压失败：$error',
      );
    }

    final archiveFileIndex = <String, ArchiveFile>{
      for (final entry in archive.files.where((item) => item.isFile))
        _normalizeArchivePath(entry.name): entry,
    };
    final loaded = _LoadedEpubArchive(
      archive: archive,
      archiveFileIndex: archiveFileIndex,
      packageDocument: _loadPackageDocument(archiveFileIndex),
    );
    _archiveCache[cacheKey] = loaded;
    while (_archiveCache.length > _maxArchiveCacheEntries) {
      _archiveCache.remove(_archiveCache.keys.first);
    }
    return loaded;
  }

  _EpubPackageDocument? _loadPackageDocument(
    Map<String, ArchiveFile> archiveFileIndex,
  ) {
    final packagePath = _resolvePackageDocumentPath(archiveFileIndex);
    if (packagePath == null) {
      return null;
    }

    final packageEntry = _findArchiveFile(archiveFileIndex, packagePath);
    if (packageEntry == null) {
      return null;
    }

    final packageText = _readArchiveEntryAsText(packageEntry);
    if (packageText.trim().isEmpty) {
      return null;
    }

    return _EpubPackageDocument(
      packagePath: packagePath,
      document: html_parser.parse(packageText),
    );
  }

  List<ArchiveFile> _resolveChapterCandidates({
    required Archive archive,
    required Map<String, ArchiveFile> archiveFileIndex,
    required _EpubPackageDocument? packageDocument,
  }) {
    final spineCandidates = _resolveSpineChapterCandidates(
      archiveFileIndex: archiveFileIndex,
      packageDocument: packageDocument,
    );
    if (spineCandidates.isNotEmpty) {
      return spineCandidates;
    }
    return _resolveFallbackChapterCandidates(archive);
  }

  List<ArchiveFile> _resolveSpineChapterCandidates({
    required Map<String, ArchiveFile> archiveFileIndex,
    required _EpubPackageDocument? packageDocument,
  }) {
    if (packageDocument == null) {
      return const <ArchiveFile>[];
    }

    final manifestItems = packageDocument.document
        .querySelectorAll('*')
        .where((element) => (element.localName ?? '').toLowerCase() == 'item')
        .toList(growable: false);
    if (manifestItems.isEmpty) {
      return const <ArchiveFile>[];
    }

    final chapters = <ArchiveFile>[];
    final seenPaths = <String>{};

    for (final itemRef in packageDocument.document.querySelectorAll('*')) {
      final localName = (itemRef.localName ?? '').toLowerCase();
      if (localName != 'itemref') {
        continue;
      }

      final linear =
          _readAttribute(
            itemRef,
            keys: const <String>{'linear'},
          )?.toLowerCase();
      if (linear == 'no') {
        continue;
      }

      final idRef = _readAttribute(itemRef, keys: const <String>{'idref'});
      if (idRef == null || idRef.isEmpty) {
        continue;
      }

      final manifestItem = _findManifestItemById(manifestItems, idRef);
      if (manifestItem == null) {
        continue;
      }

      final href = _readAttribute(
        manifestItem,
        keys: const <String>{'href', 'xlink:href'},
      );
      final resolvedPath = _resolveArchivePathRelativeTo(
        baseEntryPath: packageDocument.packagePath,
        rawSource: href,
      );
      if (resolvedPath == null) {
        continue;
      }

      final archiveEntry = _findArchiveFile(archiveFileIndex, resolvedPath);
      if (archiveEntry == null) {
        continue;
      }

      final properties =
          _readAttribute(
            manifestItem,
            keys: const <String>{'properties'},
          )?.toLowerCase() ??
          '';
      final mediaType =
          _readAttribute(
            manifestItem,
            keys: const <String>{'media-type'},
          )?.toLowerCase() ??
          '';
      final normalizedEntryPath = _normalizeArchivePath(archiveEntry.name);
      if (!_isSupportedChapterEntry(
            entryPath: normalizedEntryPath,
            mediaType: mediaType,
          ) ||
          _isNavigationDocument(
            entryPath: normalizedEntryPath,
            properties: properties,
          ) ||
          !seenPaths.add(normalizedEntryPath)) {
        continue;
      }

      chapters.add(archiveEntry);
    }

    return chapters;
  }

  List<ArchiveFile> _resolveFallbackChapterCandidates(Archive archive) {
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
    return chapterCandidates;
  }

  String? _resolvePackageDocumentPath(
    Map<String, ArchiveFile> archiveFileIndex,
  ) {
    final containerPath = archiveFileIndex.keys.firstWhere(
      (key) => key.toLowerCase() == 'meta-inf/container.xml',
      orElse: () => '',
    );
    if (containerPath.isEmpty) {
      return null;
    }

    final containerEntry = archiveFileIndex[containerPath];
    if (containerEntry == null) {
      return null;
    }

    final containerText = _readArchiveEntryAsText(containerEntry);
    if (containerText.trim().isEmpty) {
      return null;
    }

    final containerDocument = html_parser.parse(containerText);
    for (final element in containerDocument.querySelectorAll('*')) {
      final localName = (element.localName ?? '').toLowerCase();
      if (localName != 'rootfile') {
        continue;
      }

      final fullPath = _readAttribute(
        element,
        keys: <String>{'full-path', 'fullpath'},
      );
      if (fullPath == null || fullPath.isEmpty) {
        continue;
      }

      final normalized = _normalizeArchivePath(fullPath);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    for (final key in archiveFileIndex.keys) {
      if (key.toLowerCase().endsWith('.opf')) {
        return key;
      }
    }

    return null;
  }

  String? _extractFirstElementText(
    dom.Document document, {
    required Set<String> localNames,
  }) {
    final normalizedNames =
        localNames.map((name) => name.toLowerCase()).toSet();
    for (final element in document.querySelectorAll('*')) {
      final localName = (element.localName ?? '').toLowerCase();
      if (!normalizedNames.contains(localName)) {
        continue;
      }
      final text = _normalizeInlineText(element.text);
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _extractCoverArchivePath({
    required dom.Document document,
    required String packagePath,
    required Map<String, ArchiveFile> archiveFileIndex,
  }) {
    final manifestItems = document
        .querySelectorAll('*')
        .where((element) => (element.localName ?? '').toLowerCase() == 'item')
        .toList(growable: false);

    final metaCoverId = _extractMetaCoverId(document);
    if (metaCoverId != null) {
      final byId = _findManifestItemById(manifestItems, metaCoverId);
      final resolved = _resolveCoverPathFromManifestItem(
        item: byId,
        packagePath: packagePath,
        archiveFileIndex: archiveFileIndex,
      );
      if (resolved != null) {
        return resolved;
      }
    }

    for (final item in manifestItems) {
      final properties =
          _readAttribute(item, keys: <String>{'properties'})?.toLowerCase();
      if (properties != null && properties.contains('cover-image')) {
        final resolved = _resolveCoverPathFromManifestItem(
          item: item,
          packagePath: packagePath,
          archiveFileIndex: archiveFileIndex,
        );
        if (resolved != null) {
          return resolved;
        }
      }
    }

    for (final item in manifestItems) {
      final id =
          _readAttribute(item, keys: <String>{'id'})?.toLowerCase() ?? '';
      final mediaType =
          _readAttribute(item, keys: <String>{'media-type'})?.toLowerCase() ??
          '';
      if (!id.contains('cover') && !mediaType.startsWith('image/')) {
        continue;
      }

      final resolved = _resolveCoverPathFromManifestItem(
        item: item,
        packagePath: packagePath,
        archiveFileIndex: archiveFileIndex,
      );
      if (resolved != null) {
        return resolved;
      }
    }

    for (final reference in document.querySelectorAll('*')) {
      final localName = (reference.localName ?? '').toLowerCase();
      if (localName != 'reference') {
        continue;
      }
      final type =
          _readAttribute(reference, keys: <String>{'type'})?.toLowerCase() ??
          '';
      if (!type.contains('cover')) {
        continue;
      }
      final href = _readAttribute(
        reference,
        keys: <String>{'href', 'xlink:href'},
      );
      final resolved = _resolveArchivePathRelativeTo(
        baseEntryPath: packagePath,
        rawSource: href,
      );
      if (resolved != null && _archiveImageExists(archiveFileIndex, resolved)) {
        return resolved;
      }
    }

    for (final item in manifestItems) {
      final href =
          _readAttribute(
            item,
            keys: <String>{'href', 'xlink:href'},
          )?.toLowerCase();
      final mediaType =
          _readAttribute(item, keys: <String>{'media-type'})?.toLowerCase() ??
          '';
      if (href == null ||
          href.isEmpty ||
          (!href.contains('cover') && !mediaType.startsWith('image/'))) {
        continue;
      }
      final resolved = _resolveCoverPathFromManifestItem(
        item: item,
        packagePath: packagePath,
        archiveFileIndex: archiveFileIndex,
      );
      if (resolved != null) {
        return resolved;
      }
    }

    return null;
  }

  String? _extractMetaCoverId(dom.Document document) {
    for (final element in document.querySelectorAll('*')) {
      final localName = (element.localName ?? '').toLowerCase();
      if (localName != 'meta') {
        continue;
      }

      final name =
          _readAttribute(element, keys: <String>{'name'})?.toLowerCase();
      if (name != 'cover') {
        continue;
      }

      final content = _readAttribute(element, keys: <String>{'content'});
      if (content != null && content.trim().isNotEmpty) {
        return content.trim();
      }
    }
    return null;
  }

  dom.Element? _findManifestItemById(
    List<dom.Element> manifestItems,
    String id,
  ) {
    final target = id.trim().toLowerCase();
    if (target.isEmpty) {
      return null;
    }

    for (final item in manifestItems) {
      final itemId = _readAttribute(item, keys: <String>{'id'})?.toLowerCase();
      if (itemId == target) {
        return item;
      }
    }
    return null;
  }

  String? _resolveCoverPathFromManifestItem({
    required dom.Element? item,
    required String packagePath,
    required Map<String, ArchiveFile> archiveFileIndex,
  }) {
    if (item == null) {
      return null;
    }

    final href = _readAttribute(item, keys: <String>{'href', 'xlink:href'});
    final resolved = _resolveArchivePathRelativeTo(
      baseEntryPath: packagePath,
      rawSource: href,
    );
    if (resolved == null) {
      return null;
    }
    if (_archiveImageExists(archiveFileIndex, resolved)) {
      return resolved;
    }
    return null;
  }

  _EpubChapterCandidatePreview _buildChapterCandidatePreview({
    required dom.Document document,
    required String entryPath,
    required int index,
  }) {
    final normalizedText = _normalizeText(
      document.body?.text ??
          document.documentElement?.text ??
          document.outerHtml,
    );
    final hasInlineImages = document
        .querySelectorAll('*')
        .any(
          (element) => _isImageElement((element.localName ?? '').toLowerCase()),
        );
    final title = _resolveDocumentTitle(
      document: document,
      entryName: entryPath,
      index: index,
    );
    final category = _classifyDocumentCategory(
      document: document,
      entryPath: entryPath,
      title: title,
      normalizedText: normalizedText,
      hasInlineImages: hasInlineImages,
    );
    return _EpubChapterCandidatePreview(
      category: category,
      title: title,
      normalizedText: normalizedText,
      hasInlineImages: hasInlineImages,
      document: _buildPreviewDocument(
        title: title,
        previewText: normalizedText,
      ),
    );
  }

  ReaderDocument _buildPreviewDocument({
    required String title,
    required String previewText,
  }) {
    final normalizedTitle = _normalizeInlineText(title);
    final withoutDuplicateTitle = _stripDuplicateLeadingTitle(
      previewText,
      normalizedTitle,
    );
    final excerpt = _buildPreviewExcerpt(withoutDuplicateTitle);
    if (normalizedTitle.isEmpty && excerpt.isEmpty) {
      return ReaderDocument(blocks: const <ReaderBlock>[]);
    }
    return ReaderDocument.fromContent(
      content: excerpt,
      title: normalizedTitle.isEmpty ? null : normalizedTitle,
      includeTitleBlock: normalizedTitle.isNotEmpty,
    );
  }

  String _buildPreviewExcerpt(String value) {
    final normalized = _normalizeText(value);
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.length <= 280) {
      return normalized;
    }
    return '${normalized.substring(0, 280).trim()}...';
  }

  String _stripDuplicateLeadingTitle(String previewText, String title) {
    final normalizedPreview = _normalizeText(previewText);
    if (normalizedPreview.isEmpty || title.isEmpty) {
      return normalizedPreview;
    }
    if (normalizedPreview == title) {
      return '';
    }
    if (normalizedPreview.startsWith('$title\n')) {
      return normalizedPreview.substring(title.length).trimLeft();
    }
    if (normalizedPreview.startsWith('$title ')) {
      return normalizedPreview.substring(title.length).trimLeft();
    }
    return normalizedPreview;
  }

  _EpubDocumentCategory _classifyDocumentCategory({
    required dom.Document document,
    required String entryPath,
    required String title,
    required String normalizedText,
    required bool hasInlineImages,
  }) {
    if (_isNavigationDocument(entryPath: entryPath, properties: '')) {
      return _EpubDocumentCategory.navigation;
    }

    if (_isNavigationLikeDocument(
      document: document,
      entryPath: entryPath,
      normalizedText: normalizedText,
    )) {
      return _EpubDocumentCategory.navigation;
    }

    if (_isCoverLikeDocument(
      document: document,
      entryPath: entryPath,
      title: title,
      normalizedText: normalizedText,
      hasInlineImages: hasInlineImages,
    )) {
      return _EpubDocumentCategory.cover;
    }

    if (_isMetadataLikeDocument(
      entryPath: entryPath,
      title: title,
      normalizedText: normalizedText,
      hasInlineImages: hasInlineImages,
    )) {
      return _EpubDocumentCategory.metadata;
    }

    if (normalizedText.isEmpty && !hasInlineImages) {
      return _EpubDocumentCategory.resource;
    }

    return _EpubDocumentCategory.body;
  }

  bool _isNavigationLikeDocument({
    required dom.Document document,
    required String entryPath,
    required String normalizedText,
  }) {
    final lowerEntryPath = entryPath.toLowerCase();
    if (lowerEntryPath.contains('/toc') || lowerEntryPath.contains('/nav')) {
      return true;
    }

    final navElements = document.querySelectorAll('nav');
    if (navElements.isNotEmpty) {
      return true;
    }

    final lowerText = normalizedText.toLowerCase();
    final hasTocKeyword =
        lowerText.contains('table of contents') ||
        lowerText.contains('contents') ||
        normalizedText.contains('目录');
    if (!hasTocKeyword) {
      return false;
    }

    final anchorCount = document.querySelectorAll('a[href]').length;
    return anchorCount >= 2;
  }

  bool _isCoverLikeDocument({
    required dom.Document document,
    required String entryPath,
    required String title,
    required String normalizedText,
    required bool hasInlineImages,
  }) {
    final lowerEntryPath = entryPath.toLowerCase();
    final lowerTitle = title.toLowerCase();
    final hasCoverHint =
        lowerEntryPath.contains('cover') ||
        lowerEntryPath.contains('titlepage') ||
        lowerEntryPath.contains('title_page') ||
        entryPath.contains('封面') ||
        entryPath.contains('扉页') ||
        lowerTitle.contains('cover') ||
        title.contains('封面');
    if (!hasCoverHint) {
      return false;
    }

    final nonEmptyBodyChildren =
        (document.body ?? document.documentElement)?.children
            .where(
              (element) =>
                  _normalizeInlineText(element.text).isNotEmpty ||
                  _isImageElement((element.localName ?? '').toLowerCase()),
            )
            .length ??
        0;
    return hasInlineImages &&
        normalizedText.length <= 48 &&
        nonEmptyBodyChildren <= 3;
  }

  bool _isMetadataLikeDocument({
    required String entryPath,
    required String title,
    required String normalizedText,
    required bool hasInlineImages,
  }) {
    if (hasInlineImages) {
      return false;
    }

    final path = entryPath.toLowerCase();
    final lowerTitle = title.toLowerCase();
    final hasMetadataHint =
        path.contains('copyright') ||
        path.contains('colophon') ||
        path.contains('imprint') ||
        path.contains('license') ||
        path.contains('rights') ||
        title.contains('版权') ||
        title.contains('版权页') ||
        lowerTitle.contains('copyright') ||
        lowerTitle.contains('colophon') ||
        lowerTitle.contains('imprint');
    if (!hasMetadataHint) {
      return false;
    }

    return normalizedText.length <= 400;
  }

  String? _resolveArchivePathRelativeTo({
    required String baseEntryPath,
    required String? rawSource,
  }) {
    final source = rawSource?.trim() ?? '';
    if (source.isEmpty) {
      return null;
    }
    final normalized = _resolveArchiveImagePath(
      chapterEntryName: baseEntryPath,
      rawSource: source,
    );
    if (normalized == null ||
        normalized.startsWith('http://') ||
        normalized.startsWith('https://')) {
      return null;
    }
    return normalized;
  }

  bool _archiveImageExists(
    Map<String, ArchiveFile> archiveFileIndex,
    String archivePath,
  ) {
    final normalized = _normalizeArchivePath(archivePath);
    final entry = _findArchiveFile(archiveFileIndex, normalized);
    if (entry == null) {
      return false;
    }
    final lowerName = normalized.toLowerCase();
    final extension = p.posix.extension(lowerName);
    return _supportedImageExtensions.contains(extension);
  }

  ArchiveFile? _findArchiveFile(
    Map<String, ArchiveFile> archiveFileIndex,
    String archivePath,
  ) {
    final normalized = _normalizeArchivePath(archivePath);
    final direct = archiveFileIndex[normalized];
    if (direct != null) {
      return direct;
    }

    final lookup = normalized.toLowerCase();
    for (final entry in archiveFileIndex.entries) {
      if (entry.key.toLowerCase() == lookup) {
        return entry.value;
      }
    }
    return null;
  }

  bool _isSupportedChapterEntry({
    required String entryPath,
    required String mediaType,
  }) {
    final lowerPath = entryPath.toLowerCase();
    if (_supportedExtensions.any(lowerPath.endsWith)) {
      return true;
    }
    return mediaType == 'application/xhtml+xml' || mediaType == 'text/html';
  }

  bool _isImageElement(String tagName) {
    return tagName == 'img' || tagName == 'image';
  }

  bool _isNavigationDocument({
    required String entryPath,
    required String properties,
  }) {
    if (properties
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .contains('nav')) {
      return true;
    }

    final fileName = p.posix.basename(entryPath).toLowerCase();
    return fileName == 'nav.xhtml' ||
        fileName == 'nav.html' ||
        fileName == 'toc.xhtml' ||
        fileName == 'toc.html';
  }

  String? _readAttribute(dom.Element element, {required Set<String> keys}) {
    if (keys.isEmpty || element.attributes.isEmpty) {
      return null;
    }
    final normalizedKeys = keys.map((key) => key.toLowerCase()).toSet();
    for (final entry in element.attributes.entries) {
      final key = entry.key.toString().toLowerCase();
      if (!normalizedKeys.contains(key)) {
        continue;
      }
      final value = entry.value.toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<String?> _materializeCoverPath({
    required _EpubMetadata metadata,
    required Map<String, ArchiveFile> archiveFileIndex,
    required Directory assetRootDir,
  }) async {
    final archivePath = metadata.coverArchivePath?.trim() ?? '';
    if (archivePath.isEmpty) {
      return null;
    }

    final archiveEntry = _findArchiveFile(archiveFileIndex, archivePath);
    if (archiveEntry == null) {
      return null;
    }
    final lowerName = archivePath.toLowerCase();
    final extension = p.posix.extension(lowerName);
    if (!_supportedImageExtensions.contains(extension)) {
      return null;
    }

    final targetFile = File(
      p.join(assetRootDir.path, _safeAssetRelativePath(archivePath)),
    );
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }
    await targetFile.writeAsBytes(
      _readArchiveEntryBytes(archiveEntry),
      flush: true,
    );
    return targetFile.path;
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
      return _EpubChapterExtraction(
        content: '',
        imageUrls: const <String>[],
        document: ReaderDocument(blocks: const <ReaderBlock>[]),
      );
    }

    final imageUrls = <String>[];
    final blocks = <ReaderBlock>[];
    var buffer = StringBuffer();

    void flushBuffer() {
      final normalized = _normalizeInlineText(buffer.toString());
      if (normalized.isNotEmpty) {
        blocks.add(ReaderTextBlock(text: normalized));
      }
      buffer = StringBuffer();
    }

    Future<void> addImage(Map<String, String> attributes) async {
      final imageUrl = await _resolveMaterializedImageUrl(
        attributes: attributes,
        chapterEntryName: chapterEntryName,
        archiveFileIndex: archiveFileIndex,
        assetRootDir: assetRootDir,
      );
      if (imageUrl != null && imageUrl.isNotEmpty) {
        imageUrls.add(imageUrl);
        blocks.add(ReaderImageBlock(imageUrl: imageUrl));
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
      if (_isHeadingElement(tagName)) {
        flushBuffer();
        final headingText = _normalizeInlineText(node.text);
        if (headingText.isNotEmpty) {
          blocks.add(
            ReaderTitleBlock(text: headingText, level: _headingLevel(tagName)),
          );
        }
        return;
      }
      if (tagName == 'blockquote') {
        flushBuffer();
        final quoteText = _normalizeInlineText(node.text);
        if (quoteText.isNotEmpty) {
          blocks.add(ReaderQuoteBlock(text: quoteText));
        }
        return;
      }
      if (_isFootnoteElement(node)) {
        flushBuffer();
        final footnoteText = _normalizeInlineText(node.text);
        if (footnoteText.isNotEmpty) {
          blocks.add(ReaderFootnoteBlock(text: footnoteText));
        }
        return;
      }
      if (tagName == 'figcaption' || tagName == 'caption') {
        flushBuffer();
        final captionText = _normalizeInlineText(node.text);
        if (captionText.isNotEmpty) {
          blocks.add(ReaderCaptionBlock(text: captionText));
        }
        return;
      }
      if (tagName == 'img' || tagName == 'image') {
        flushBuffer();
        await addImage(
          node.attributes.map((key, value) => MapEntry(key.toString(), value)),
        );
        return;
      }

      if (tagName == 'br') {
        buffer.write('\n');
        return;
      }

      if (tagName == 'li') {
        flushBuffer();
        final listItemText = _normalizeInlineText(node.text);
        if (listItemText.isNotEmpty) {
          blocks.add(ReaderListItemBlock(text: listItemText));
        }
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

    final readerDocument = ReaderDocument(blocks: blocks);
    return _EpubChapterExtraction(
      content: readerDocument.compatibilityContent,
      imageUrls: readerDocument.imageUrls,
      document: readerDocument,
    );
  }

  ReaderDocument _withFallbackChapterTitle(
    ReaderDocument document, {
    required String chapterTitle,
  }) {
    if (document.blocks.any((block) => block is ReaderTitleBlock)) {
      return document;
    }
    final normalizedTitle = _normalizeInlineText(chapterTitle);
    if (normalizedTitle.isEmpty) {
      return document;
    }
    return ReaderDocument(
      blocks: <ReaderBlock>[
        ReaderTitleBlock(text: normalizedTitle),
        ...document.blocks,
      ],
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

  bool _isFootnoteElement(dom.Element element) {
    final tagName = (element.localName ?? '').toLowerCase();
    final epubType =
        _readAttribute(
          element,
          keys: const <String>{'epub:type', 'type'},
        )?.toLowerCase() ??
        '';
    final role =
        _readAttribute(element, keys: const <String>{'role'})?.toLowerCase() ??
        '';
    final className =
        _readAttribute(element, keys: const <String>{'class'})?.toLowerCase() ??
        '';
    final id =
        _readAttribute(element, keys: const <String>{'id'})?.toLowerCase() ??
        '';
    final signal = '$epubType $role $className $id';
    final hasFootnoteSignal =
        signal.contains('footnote') ||
        signal.contains('endnote') ||
        signal.contains('doc-footnote');
    if (!hasFootnoteSignal) {
      return false;
    }
    return tagName == 'aside' ||
        tagName == 'section' ||
        tagName == 'div' ||
        tagName == 'li' ||
        tagName == 'p' ||
        tagName == 'footer';
  }

  bool _isHeadingElement(String tagName) {
    return const {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}.contains(tagName);
  }

  int _headingLevel(String tagName) {
    switch (tagName) {
      case 'h1':
        return 1;
      case 'h2':
        return 2;
      case 'h3':
        return 3;
      case 'h4':
        return 4;
      case 'h5':
        return 5;
      default:
        return 6;
    }
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

    final archiveEntry = _findArchiveFile(archiveFileIndex, resolvedPath);
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

    final declaredCharset =
        LocalTextEncodingDetector.extractDeclaredCharsetFromHtml(bytes);
    final decoded = _textEncodingDetector.decodeBestEffort(
      bytes,
      hintedCharset: declaredCharset,
      candidateCharsets: _htmlCharsetCandidates,
      htmlAware: true,
    );
    return decoded.text;
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

  String _resolveDocumentTitle({
    required dom.Document document,
    required String entryName,
    required int index,
  }) {
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

class EpubArchiveDecoder {
  const EpubArchiveDecoder();

  Archive decodeBytes(List<int> bytes) {
    return ZipDecoder().decodeBytes(bytes, verify: false);
  }
}

class _LoadedEpubArchive {
  const _LoadedEpubArchive({
    required this.archive,
    required this.archiveFileIndex,
    required this.packageDocument,
  });

  final Archive archive;
  final Map<String, ArchiveFile> archiveFileIndex;
  final _EpubPackageDocument? packageDocument;
}

class _EpubChapterExtraction {
  const _EpubChapterExtraction({
    required this.content,
    required this.imageUrls,
    required this.document,
  });

  final String content;
  final List<String> imageUrls;
  final ReaderDocument document;
}

enum _EpubDocumentCategory { body, navigation, cover, metadata, resource }

class _EpubChapterCandidatePreview {
  const _EpubChapterCandidatePreview({
    required this.category,
    required this.title,
    required this.normalizedText,
    required this.hasInlineImages,
    required this.document,
  });

  final _EpubDocumentCategory category;
  final String title;
  final String normalizedText;
  final bool hasInlineImages;
  final ReaderDocument document;

  bool get hasReadableSignal =>
      title.trim().isNotEmpty ||
      normalizedText.trim().isNotEmpty ||
      hasInlineImages;
}

class _EpubMetadata {
  const _EpubMetadata({this.title, this.author, this.coverArchivePath});

  final String? title;
  final String? author;
  final String? coverArchivePath;
}

class _EpubPackageDocument {
  const _EpubPackageDocument({
    required this.packagePath,
    required this.document,
  });

  final String packagePath;
  final dom.Document document;
}
