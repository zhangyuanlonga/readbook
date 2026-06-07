import 'package:epub_pro/epub_pro.dart' as epub_pro;
import 'package:path/path.dart' as p;

import 'local_book_parser.dart';

/// `epub_pro` 的项目适配层。
///
/// 第三方 EPUB 库只允许停留在 adapter 内部，向外输出项目自己的
/// `LocalParsedBook` / `LocalParsedChapter`。这样后续如果某类 EPUB 仍需走
/// 现有定制 parser，数据库、书架和阅读器都不用感知第三方模型。
class EpubProLocalBookAdapter {
  const EpubProLocalBookAdapter();

  Future<EpubProAdapterResult> parseIndex(List<int> bytes) async {
    final bookRef = await epub_pro.EpubReader.openBook(bytes);
    final chapters = _flattenChapterRefs(bookRef.getChapters())
        .where((chapter) => _isReadableChapter(chapter, bookRef))
        .map((chapter) => _toParsedChapter(chapter, bookRef))
        .toList(growable: false);
    return EpubProAdapterResult(
      parsedBook: LocalParsedBook(
        chapters: chapters,
        title: _normalizeOptional(bookRef.title),
        author: _normalizeOptional(bookRef.author),
      ),
      hasNavigation: bookRef.schema?.navigation != null,
      spineItemCount: bookRef.schema?.package?.spine?.items.length ?? 0,
      manifestItemCount: bookRef.schema?.package?.manifest?.items.length ?? 0,
    );
  }

  List<epub_pro.EpubChapterRef> _flattenChapterRefs(
    List<epub_pro.EpubChapterRef> chapters,
  ) {
    final result = <epub_pro.EpubChapterRef>[];
    for (final chapter in chapters) {
      result.add(chapter);
      result.addAll(_flattenChapterRefs(chapter.subChapters));
    }
    return result;
  }

  bool _isReadableChapter(
    epub_pro.EpubChapterRef chapter,
    epub_pro.EpubBookRef bookRef,
  ) {
    final contentFileName = _normalizeOptional(chapter.contentFileName);
    if (contentFileName == null) {
      return false;
    }
    final manifestItems = bookRef.schema?.package?.manifest?.items ?? const [];
    epub_pro.EpubManifestItem? manifestItem;
    for (final item in manifestItems) {
      if (item.href == contentFileName) {
        manifestItem = item;
        break;
      }
    }
    final properties = manifestItem?.properties?.toLowerCase() ?? '';
    if (properties.split(RegExp(r'\s+')).contains('nav')) {
      return false;
    }
    final basename =
        p.posix.basenameWithoutExtension(contentFileName).toLowerCase();
    return !const <String>{
      'nav',
      'toc',
      'navigation',
      'cover',
      'title',
      'metadata',
    }.contains(basename);
  }

  LocalParsedChapter _toParsedChapter(
    epub_pro.EpubChapterRef chapter,
    epub_pro.EpubBookRef bookRef,
  ) {
    final contentFileName = _normalizeOptional(chapter.contentFileName) ?? '';
    final title =
        _normalizeOptional(chapter.title) ??
        p.posix.basenameWithoutExtension(contentFileName).trim();
    final archivePath = _resolveArchivePath(
      contentDirectoryPath: bookRef.schema?.contentDirectoryPath,
      contentFileName: contentFileName,
    );
    return LocalParsedChapter(
      title: title.isEmpty ? '未命名章节' : title,
      content: '',
      sourceRef: _encodeSourceRef(
        path: archivePath,
        startFragmentId: _normalizeOptional(chapter.anchor),
      ),
    );
  }

  String _resolveArchivePath({
    required String? contentDirectoryPath,
    required String contentFileName,
  }) {
    final normalizedFile = _normalizeArchivePath(contentFileName);
    final normalizedDirectory = _normalizeArchivePath(
      contentDirectoryPath ?? '',
    );
    if (normalizedDirectory.isEmpty || normalizedDirectory == '.') {
      return normalizedFile;
    }
    return _normalizeArchivePath(
      p.posix.normalize(p.posix.join(normalizedDirectory, normalizedFile)),
    );
  }

  String _encodeSourceRef({required String path, String? startFragmentId}) {
    if (startFragmentId == null || startFragmentId.trim().isEmpty) {
      return _normalizeArchivePath(path);
    }
    return Uri(
      scheme: 'epub-ref',
      host: 'chapter',
      queryParameters: <String, String>{
        'path': _normalizeArchivePath(path),
        'start': startFragmentId.trim(),
      },
    ).toString();
  }

  String _normalizeArchivePath(String value) {
    return value.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
  }

  String? _normalizeOptional(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }
}

class EpubProAdapterResult {
  const EpubProAdapterResult({
    required this.parsedBook,
    required this.hasNavigation,
    required this.spineItemCount,
    required this.manifestItemCount,
  });

  final LocalParsedBook parsedBook;
  final bool hasNavigation;
  final int spineItemCount;
  final int manifestItemCount;
}
