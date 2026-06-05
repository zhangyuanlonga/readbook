part of 'reader_page.dart';

/// 阅读器页面的路由入口 widget。
///
/// 这里只保留 route 传入的章节身份参数，真实运行态继续由
/// [_ReaderPageState] 和各个 part 承接；后续拆分 ReaderPage 时，不能在
/// 入口 widget 里新增加载、缓存、平台桥或进度保存逻辑。
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    required this.chapterId,
    this.chapterUrl,
    this.chapterTitle,
    this.sourceId,
    this.detailUrl,
    this.chapterIndex,
    this.bookmarkId,
    this.openRequestedAtMs,
    this.openRouteKind,
    this.heroTag,
  });

  final String bookId;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final String? sourceId;
  final String? detailUrl;
  final int? chapterIndex;
  final String? bookmarkId;
  final int? openRequestedAtMs;
  final String? openRouteKind;
  final String? heroTag;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}
