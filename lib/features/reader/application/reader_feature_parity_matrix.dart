enum ReaderFeatureParityStatus { available, partial, missing, notApplicable }

enum ReaderFeatureParityStage { p0, p1, p2, p3, p4, p5, p6, p7, p8 }

class ReaderFeatureParityItem {
  const ReaderFeatureParityItem({
    required this.id,
    required this.title,
    required this.stage,
    required this.baselineStatus,
    required this.releaseStatus,
    required this.notes,
  });

  final String id;
  final String title;
  final ReaderFeatureParityStage stage;
  final ReaderFeatureParityStatus baselineStatus;
  final ReaderFeatureParityStatus releaseStatus;
  final String notes;

  bool get isReleaseComplete =>
      releaseStatus == ReaderFeatureParityStatus.available ||
      releaseStatus == ReaderFeatureParityStatus.notApplicable;
}

class ReaderFeatureParityMatrix {
  const ReaderFeatureParityMatrix._();

  static const List<ReaderFeatureParityItem>
  v7CoreItems = <ReaderFeatureParityItem>[
    ReaderFeatureParityItem(
      id: 'text_paged_basic_turn',
      title: '普通分页翻页',
      stage: ReaderFeatureParityStage.p1,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.available,
      notes:
          '新previous renderer 共用 ReaderNavigationCommand 与 page index runtime。',
    ),
    ReaderFeatureParityItem(
      id: 'paper_curl_animation',
      title: '纸张卷页 paperCurl',
      stage: ReaderFeatureParityStage.p1,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.available,
      notes: 'layout release 已接入 paper curl surface，跨章失败时按新路径降级。',
    ),
    ReaderFeatureParityItem(
      id: 'curl_animation',
      title: '仿真 curl 动画',
      stage: ReaderFeatureParityStage.p1,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.available,
      notes: 'curl transition 已由 release page snapshot/animation surface 承接。',
    ),
    ReaderFeatureParityItem(
      id: 'cover_translate_fade_animation',
      title: '覆盖、滑动、淡入动画',
      stage: ReaderFeatureParityStage.p1,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.available,
      notes:
          'layout release 直接消费 ReaderPagedAnimationSurface transition stack。',
    ),
    ReaderFeatureParityItem(
      id: 'cross_chapter_snapshot_turn',
      title: '跨章节翻页动画',
      stage: ReaderFeatureParityStage.p1,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.available,
      notes: '跨章节翻页动画只消费新 renderer 截图，未准备好时新路径降级。',
    ),
    ReaderFeatureParityItem(
      id: 'tap_keyboard_volume_wheel_intent',
      title: '点击分区、键盘、音量键、滚轮输入',
      stage: ReaderFeatureParityStage.p2,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.available,
      notes:
          '输入统一落到 ReaderNavigationCommand，selection active 会统一拦截 page intent。',
    ),
    ReaderFeatureParityItem(
      id: 'layout_long_press_selection',
      title: 'layout 长按选择',
      stage: ReaderFeatureParityStage.p3,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.available,
      notes: '新 renderer 使用 layout hit-test 选择词，并桥接selection toolbar。',
    ),
    ReaderFeatureParityItem(
      id: 'layout_cross_page_drag_selection',
      title: '跨页拖拽选择',
      stage: ReaderFeatureParityStage.p3,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.partial,
      notes: '已支持拖出当前页映射相邻 layout page，复杂多页拖拽仍需继续补验证。',
    ),
    ReaderFeatureParityItem(
      id: 'annotation_style_visuals',
      title: '高亮、加粗、下划线、波浪线视觉',
      stage: ReaderFeatureParityStage.p3,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.available,
      notes: 'ReaderLayoutTextAnnotationRange 已承接bookmark style fields。',
    ),
    ReaderFeatureParityItem(
      id: 'annotation_toolbar_restore',
      title: '点击已有标注唤起工具条',
      stage: ReaderFeatureParityStage.p3,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.partial,
      notes: '长按/选择重叠可恢复工具条，直接点击现有标注仍待独立 hit-test。',
    ),
    ReaderFeatureParityItem(
      id: 'bookmark_layout_restore',
      title: '书签 layout position 恢复',
      stage: ReaderFeatureParityStage.p3,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.partial,
      notes:
          'layout anchor payload 已可保存，恢复仍保留 chapter offset/snippet fallback。',
    ),
    ReaderFeatureParityItem(
      id: 'search_highlight_jump',
      title: '搜索高亮与跳转',
      stage: ReaderFeatureParityStage.p4,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.partial,
      notes: 'layout anchor 已有 alpha，搜索命中页码和高亮仍需继续回归。',
    ),
    ReaderFeatureParityItem(
      id: 'read_aloud_progress_highlight',
      title: '朗读进度与高亮',
      stage: ReaderFeatureParityStage.p4,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.partial,
      notes: 'layout anchor 已有 alpha，朗读可见文本同步仍待专项验证。',
    ),
    ReaderFeatureParityItem(
      id: 'auto_read_paged_scroll',
      title: '自动阅读分页/滚动',
      stage: ReaderFeatureParityStage.p4,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.partial,
      notes: '自动阅读在新 renderer 下手动打断、恢复、跨章仍待补齐。',
    ),
    ReaderFeatureParityItem(
      id: 'typography_settings_signature',
      title: '字体、字号、行距、边距设置',
      stage: ReaderFeatureParityStage.p5,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.partial,
      notes: '部分已进入 layout spec/signature，完整设置矩阵仍需逐项验证。',
    ),
    ReaderFeatureParityItem(
      id: 'background_brightness_info_bar',
      title: '背景、亮度、信息栏',
      stage: ReaderFeatureParityStage.p5,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.available,
      notes: '主要复用 ReaderPage 外壳，需持续验证 release frame 不遮挡正文。',
    ),
    ReaderFeatureParityItem(
      id: 'epub_html_mixed_blocks',
      title: 'EPUB/HTML 混排语义',
      stage: ReaderFeatureParityStage.p6,
      baselineStatus: ReaderFeatureParityStatus.partial,
      releaseStatus: ReaderFeatureParityStatus.partial,
      notes: '标题、图片、caption、footnote、link 语义仍需继续增强。',
    ),
    ReaderFeatureParityItem(
      id: 'manga_surface_isolation',
      title: '漫画 surface',
      stage: ReaderFeatureParityStage.p7,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.notApplicable,
      notes: '漫画不走 text layout renderer，但必须共享 session/progress 边界。',
    ),
    ReaderFeatureParityItem(
      id: 'pdf_surface_isolation',
      title: 'PDF surface',
      stage: ReaderFeatureParityStage.p7,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.notApplicable,
      notes: 'PDF 不走 text layout renderer，但不能污染 text page progress。',
    ),
    ReaderFeatureParityItem(
      id: 'audio_surface_isolation',
      title: '音频 surface',
      stage: ReaderFeatureParityStage.p7,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.notApplicable,
      notes: '音频不走 text layout renderer，需保持播放进度字段独立。',
    ),
    ReaderFeatureParityItem(
      id: 'diagnostics_fallback',
      title: 'diagnostics/fallback',
      stage: ReaderFeatureParityStage.p7,
      baselineStatus: ReaderFeatureParityStatus.available,
      releaseStatus: ReaderFeatureParityStatus.available,
      notes:
          'release policy 输出 active/reason/mode/requested animation，不再输出previous renderer 回退项。',
    ),
  ];

  static ReaderFeatureParityItem? itemById(String id) {
    for (final item in v7CoreItems) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  static List<ReaderFeatureParityItem> itemsForStage(
    ReaderFeatureParityStage stage,
  ) {
    return v7CoreItems
        .where((item) => item.stage == stage)
        .toList(growable: false);
  }

  static List<ReaderFeatureParityItem> releaseIncompleteItems() {
    return v7CoreItems
        .where((item) => !item.isReleaseComplete)
        .toList(growable: false);
  }
}
