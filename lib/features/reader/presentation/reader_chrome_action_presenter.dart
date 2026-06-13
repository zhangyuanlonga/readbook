import 'package:flutter/material.dart';

enum ReaderChromeAutoReadStatus {
  off,
  running,
  paused,
  chapterPaused,
  finished,
}

enum ReaderChromeTopMoreActionKind {
  cacheChapter,
  switchSource,
  toggleBookshelf,
}

class ReaderChromeActionData {
  const ReaderChromeActionData({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool active;
}

class ReaderChromeTopMoreActionData {
  const ReaderChromeTopMoreActionData({
    required this.kind,
    required this.icon,
    required this.title,
    this.enabled = true,
    this.loading = false,
  });

  final ReaderChromeTopMoreActionKind kind;
  final IconData icon;
  final String title;
  final bool enabled;
  final bool loading;
}

class ReaderChromeActionPresenter {
  const ReaderChromeActionPresenter();

  ReaderChromeActionData dayNightAction({required bool isDarkMode}) {
    return ReaderChromeActionData(
      icon: isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      label: isDarkMode ? '日间' : '夜间',
      tooltip: isDarkMode ? '切换日间模式' : '切换夜间模式',
      active: isDarkMode,
    );
  }

  ReaderChromeActionData autoReadAction(ReaderChromeAutoReadStatus status) {
    return ReaderChromeActionData(
      icon:
          status == ReaderChromeAutoReadStatus.running
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_outline_rounded,
      label: switch (status) {
        ReaderChromeAutoReadStatus.running => '暂停',
        ReaderChromeAutoReadStatus.paused ||
        ReaderChromeAutoReadStatus.chapterPaused => '继续',
        ReaderChromeAutoReadStatus.finished ||
        ReaderChromeAutoReadStatus.off => '自动',
      },
      tooltip: switch (status) {
        ReaderChromeAutoReadStatus.running => '暂停自动阅读',
        ReaderChromeAutoReadStatus.paused ||
        ReaderChromeAutoReadStatus.chapterPaused => '继续自动阅读',
        ReaderChromeAutoReadStatus.finished ||
        ReaderChromeAutoReadStatus.off => '自动阅读',
      },
      active: status != ReaderChromeAutoReadStatus.off,
    );
  }

  String chapterProgressLabel({
    required String bookTitle,
    required int? currentIndex,
    required int chapterCount,
  }) {
    final normalizedTitle = bookTitle.trim();
    if (currentIndex == null || chapterCount <= 0) {
      return normalizedTitle.isEmpty ? '加载章节信息中' : normalizedTitle;
    }

    final chapter = currentIndex + 1;
    if (normalizedTitle.isEmpty) {
      return '第 $chapter / $chapterCount 章';
    }

    return '$normalizedTitle · 第 $chapter / $chapterCount 章';
  }

  List<ReaderChromeTopMoreActionData> buildTopMoreActions({
    required bool canCacheChapter,
    required bool isCurrentChapterCached,
    required bool canSwitchSource,
    required bool isSwitchSourceLoading,
    required bool isShelfActionLoading,
    required bool isInBookshelf,
  }) {
    return <ReaderChromeTopMoreActionData>[
      if (canCacheChapter)
        ReaderChromeTopMoreActionData(
          kind: ReaderChromeTopMoreActionKind.cacheChapter,
          icon:
              isCurrentChapterCached
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_download_outlined,
          title: isCurrentChapterCached ? '已缓存章节' : '缓存章节',
          enabled: !isCurrentChapterCached,
        ),
      if (canSwitchSource)
        ReaderChromeTopMoreActionData(
          kind: ReaderChromeTopMoreActionKind.switchSource,
          icon: Icons.swap_horiz_rounded,
          title: isSwitchSourceLoading ? '换源中...' : '切换书源',
          enabled: !isSwitchSourceLoading,
          loading: isSwitchSourceLoading,
        ),
      ReaderChromeTopMoreActionData(
        kind: ReaderChromeTopMoreActionKind.toggleBookshelf,
        icon:
            isInBookshelf ? Icons.bookmark_added : Icons.bookmark_add_outlined,
        title: isInBookshelf ? '从书架移除' : '加入书架',
        enabled: !isShelfActionLoading,
        loading: isShelfActionLoading,
      ),
    ];
  }
}
