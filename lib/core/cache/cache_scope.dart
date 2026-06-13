enum AppCacheScope {
  chapterContent,
  paginationLayout,
  coverImage,
  readerImage,
  apiResponse,
  searchHit,
  sourceHealth,
  themePreview,
  localBookIndex,
  readerPreference,
}

extension AppCacheScopeX on AppCacheScope {
  String get label {
    return switch (this) {
      AppCacheScope.chapterContent => '章节内容缓存',
      AppCacheScope.paginationLayout => '分页布局缓存',
      AppCacheScope.coverImage => '封面图片缓存',
      AppCacheScope.readerImage => '阅读正文图片缓存',
      AppCacheScope.apiResponse => 'API 响应缓存',
      AppCacheScope.searchHit => '搜索命中缓存',
      AppCacheScope.sourceHealth => '书源健康缓存',
      AppCacheScope.themePreview => '主题预览缓存',
      AppCacheScope.localBookIndex => '本地书索引缓存',
      AppCacheScope.readerPreference => '阅读偏好缓存',
    };
  }
}
