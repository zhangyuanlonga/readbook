class ReaderCacheFeedbackResolver {
  const ReaderCacheFeedbackResolver();

  String unsupportedMessage({required bool isLocalContent}) {
    return isLocalContent ? '本地图书暂不支持章节缓存。' : '当前内容暂不支持章节缓存。';
  }

  String unsupportedSubtitle({required bool isLocalContent}) {
    return isLocalContent ? '本地图书不提供章节缓存。' : '当前来源暂不支持章节缓存。';
  }

  String missingCatalogMessage() {
    return '当前目录没有可缓存的正文章节。';
  }
}
