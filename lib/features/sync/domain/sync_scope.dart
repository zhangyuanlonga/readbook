enum SyncScopeCategory {
  coreReading,
  membershipAppearance,
  appPreferences,
  resourceExtension,
  deferred,
  excluded,
}

enum SyncScope {
  bookshelfCollection,
  bookshelfTaxonomy,
  readingProgress,
  readingHistory,
  readingStats,
  bookmarks,
  readingBookStatuses,
  bookMetadataOverrides,
  bookMetadataAssets,
  advancedThemePresets,
  advancedThemeAssets,
  readerSettings,
  readerVisualOverrides,
  appThemePreferences,
  appInterfaceTypography,
  appNavigationPreferences,
  appShellNavigationPreferences,
  bookshelfPresentationPreferences,
  minePagePreferences,
  searchHistory,
  homeEngagement,
  discoverPreferences,
  txtChapterRules,
  coverGalleries,
  launchImageGalleries,
  bottomNavIconGalleries,
  readerFonts,
  announcementReadState,
  searchSystemSettings,
  bookshelfSystemSettings,
  readerSystemSettings,
  sourceSwitchScores,
  authSession,
  sourceLoginState,
  bookCustomState,
  discoverCacheSnapshots,
  searchSourceHits,
  chapterCaches,
  localBooks,
  localChapters,
  localLibraryFiles,
}

extension SyncScopeMetadata on SyncScope {
  String get productLabel => switch (this) {
    SyncScope.bookshelfCollection => '书架 - 书籍列表',
    SyncScope.bookshelfTaxonomy => '书架 - 标签 / 分类 / 顺序体系',
    SyncScope.readingProgress => '阅读 - 阅读进度',
    SyncScope.readingHistory => '阅读 - 阅读历史',
    SyncScope.readingStats => '阅读 - 阅读统计',
    SyncScope.bookmarks => '阅读 - 书签',
    SyncScope.readingBookStatuses => '阅读 - 在读 / 读完状态',
    SyncScope.bookMetadataOverrides => '书籍资料 - 自定义元数据',
    SyncScope.bookMetadataAssets => '书籍资料 - 自定义封面资源',
    SyncScope.advancedThemePresets => '高级主题 - 主题配置',
    SyncScope.advancedThemeAssets => '高级主题 - 壁纸资源',
    SyncScope.readerSettings => '阅读器 - 界面设置',
    SyncScope.readerVisualOverrides => '阅读器 - 视觉覆盖设置',
    SyncScope.appThemePreferences => '外观 - 基础主题',
    SyncScope.appInterfaceTypography => '外观 - 应用字体设置',
    SyncScope.appNavigationPreferences => '外观 - 导航栏样式',
    SyncScope.appShellNavigationPreferences => '外观 - 底部导航显示项',
    SyncScope.bookshelfPresentationPreferences => '书架 - 展示偏好',
    SyncScope.minePagePreferences => '外观 - Mine 页偏好',
    SyncScope.searchHistory => '搜索 - 搜索历史',
    SyncScope.homeEngagement => '首页 - 打卡记录 / 每日目标',
    SyncScope.discoverPreferences => '发现 - 当前选择的发现源',
    SyncScope.txtChapterRules => '阅读器 - TXT 分章规则',
    SyncScope.coverGalleries => '外观 - 封面图集',
    SyncScope.launchImageGalleries => '外观 - 启动图集',
    SyncScope.bottomNavIconGalleries => '外观 - 底栏图集',
    SyncScope.readerFonts => '外观 - 字体文件库',
    SyncScope.announcementReadState => '其他 - 公告已读状态',
    SyncScope.searchSystemSettings => '其他 - 搜索系统设置',
    SyncScope.bookshelfSystemSettings => '其他 - 书架系统设置',
    SyncScope.readerSystemSettings => '其他 - 阅读系统设置',
    SyncScope.sourceSwitchScores => '其他 - 换源评分偏好',
    SyncScope.authSession => '排除 - 账号登录态',
    SyncScope.sourceLoginState => '排除 - 书源登录态',
    SyncScope.bookCustomState => '排除 - 书源图书自定义状态',
    SyncScope.discoverCacheSnapshots => '排除 - Discover 缓存快照',
    SyncScope.searchSourceHits => '排除 - 搜索命中缓存',
    SyncScope.chapterCaches => '排除 - 章节缓存',
    SyncScope.localBooks => '排除 - 本地图书索引',
    SyncScope.localChapters => '排除 - 本地章节内容',
    SyncScope.localLibraryFiles => '排除 - 本地图书文件',
  };

  String get datasetFileName => switch (this) {
    SyncScope.bookshelfCollection => 'bookshelf_collection.json',
    SyncScope.bookshelfTaxonomy => 'bookshelf_taxonomy.json',
    SyncScope.readingProgress => 'reading_progress.json',
    SyncScope.readingHistory => 'reading_history.json',
    SyncScope.readingStats => 'reading_stats_snapshot.json',
    SyncScope.bookmarks => 'bookmarks.json',
    SyncScope.readingBookStatuses => 'reading_book_statuses.json',
    SyncScope.bookMetadataOverrides => 'book_metadata_overrides.json',
    SyncScope.bookMetadataAssets => 'book_metadata_assets.json',
    SyncScope.advancedThemePresets => 'advanced_theme_presets.json',
    SyncScope.advancedThemeAssets => 'advanced_theme_assets.json',
    SyncScope.readerSettings => 'reader_settings.json',
    SyncScope.readerVisualOverrides => 'reader_visual_overrides.json',
    SyncScope.appThemePreferences => 'app_theme_preferences.json',
    SyncScope.appInterfaceTypography => 'app_interface_typography.json',
    SyncScope.appNavigationPreferences => 'app_navigation_preferences.json',
    SyncScope.appShellNavigationPreferences =>
      'app_shell_navigation_preferences.json',
    SyncScope.bookshelfPresentationPreferences =>
      'bookshelf_presentation_preferences.json',
    SyncScope.minePagePreferences => 'mine_page_preferences.json',
    SyncScope.searchHistory => 'search_history.json',
    SyncScope.homeEngagement => 'home_engagement.json',
    SyncScope.discoverPreferences => 'discover_preferences.json',
    SyncScope.txtChapterRules => 'txt_chapter_rules.json',
    SyncScope.coverGalleries => 'cover_galleries.json',
    SyncScope.launchImageGalleries => 'launch_image_galleries.json',
    SyncScope.bottomNavIconGalleries => 'bottom_nav_icon_galleries.json',
    SyncScope.readerFonts => 'reader_fonts.json',
    SyncScope.announcementReadState => 'announcement_read_state.json',
    SyncScope.searchSystemSettings => 'search_system_settings.json',
    SyncScope.bookshelfSystemSettings => 'bookshelf_system_settings.json',
    SyncScope.readerSystemSettings => 'reader_system_settings.json',
    SyncScope.sourceSwitchScores => 'source_switch_scores.json',
    SyncScope.authSession => 'auth_session.json',
    SyncScope.sourceLoginState => 'source_login_state.json',
    SyncScope.bookCustomState => 'book_custom_state.json',
    SyncScope.discoverCacheSnapshots => 'discover_cache_snapshots.json',
    SyncScope.searchSourceHits => 'search_source_hits.json',
    SyncScope.chapterCaches => 'chapter_caches.json',
    SyncScope.localBooks => 'local_books.json',
    SyncScope.localChapters => 'local_chapters.json',
    SyncScope.localLibraryFiles => 'local_library_files.json',
  };

  SyncScopeCategory get category => switch (this) {
    SyncScope.bookshelfCollection ||
    SyncScope.bookshelfTaxonomy ||
    SyncScope.readingProgress ||
    SyncScope.readingHistory ||
    SyncScope.readingStats ||
    SyncScope.bookmarks ||
    SyncScope.readingBookStatuses ||
    SyncScope.bookMetadataOverrides ||
    SyncScope.bookMetadataAssets => SyncScopeCategory.coreReading,
    SyncScope.advancedThemePresets ||
    SyncScope.advancedThemeAssets => SyncScopeCategory.membershipAppearance,
    SyncScope.readerSettings ||
    SyncScope.readerVisualOverrides ||
    SyncScope.appThemePreferences ||
    SyncScope.appInterfaceTypography ||
    SyncScope.appNavigationPreferences ||
    SyncScope.appShellNavigationPreferences ||
    SyncScope.bookshelfPresentationPreferences ||
    SyncScope.minePagePreferences ||
    SyncScope.searchHistory ||
    SyncScope.homeEngagement ||
    SyncScope.discoverPreferences ||
    SyncScope.txtChapterRules => SyncScopeCategory.appPreferences,
    SyncScope.coverGalleries ||
    SyncScope.launchImageGalleries ||
    SyncScope.bottomNavIconGalleries ||
    SyncScope.readerFonts => SyncScopeCategory.resourceExtension,
    SyncScope.announcementReadState ||
    SyncScope.searchSystemSettings ||
    SyncScope.bookshelfSystemSettings ||
    SyncScope.readerSystemSettings ||
    SyncScope.sourceSwitchScores => SyncScopeCategory.deferred,
    SyncScope.authSession ||
    SyncScope.sourceLoginState ||
    SyncScope.bookCustomState ||
    SyncScope.discoverCacheSnapshots ||
    SyncScope.searchSourceHits ||
    SyncScope.chapterCaches ||
    SyncScope.localBooks ||
    SyncScope.localChapters ||
    SyncScope.localLibraryFiles => SyncScopeCategory.excluded,
  };

  List<SyncScope> get dependencies => switch (this) {
    SyncScope.readingStats => const <SyncScope>[SyncScope.readingHistory],
    SyncScope.bookMetadataAssets => const <SyncScope>[
      SyncScope.bookMetadataOverrides,
    ],
    SyncScope.advancedThemeAssets => const <SyncScope>[
      SyncScope.advancedThemePresets,
    ],
    _ => const <SyncScope>[],
  };

  bool get shouldSuggestCompanionScope => switch (this) {
    SyncScope.bookshelfTaxonomy => true,
    _ => false,
  };

  SyncScope? get suggestedCompanionScope => switch (this) {
    SyncScope.bookshelfTaxonomy => SyncScope.bookshelfCollection,
    _ => null,
  };

  bool get isFirstBatch => switch (this) {
    SyncScope.bookshelfCollection ||
    SyncScope.bookshelfTaxonomy ||
    SyncScope.readingProgress ||
    SyncScope.readingHistory ||
    SyncScope.readingStats ||
    SyncScope.bookmarks ||
    SyncScope.readingBookStatuses ||
    SyncScope.bookMetadataOverrides ||
    SyncScope.bookMetadataAssets ||
    SyncScope.advancedThemePresets ||
    SyncScope.advancedThemeAssets => true,
    _ => false,
  };

  bool get isDefaultEnabledInUi => switch (this) {
    SyncScope.bookMetadataAssets => false,
    SyncScope.advancedThemeAssets => false,
    _ => category != SyncScopeCategory.excluded,
  };
}
