import '../../../domain/entities/reader_settings.dart';
import 'reader_chrome_widgets.dart';
import 'reader_shell.dart';

class ReaderChromeSnapshot {
  const ReaderChromeSnapshot({
    required this.settings,
    required this.viewportKind,
    required this.now,
    required this.progressPercent,
    this.chapterTitle,
    this.bookTitle,
    this.batteryLevel,
    this.batteryReadFailed = false,
    this.pageIndex,
    this.pageCount,
  });

  final ReaderSettings settings;
  final ReaderPresentationViewportKind viewportKind;
  final DateTime now;
  final int progressPercent;
  final String? chapterTitle;
  final String? bookTitle;
  final int? batteryLevel;
  final bool batteryReadFailed;
  final int? pageIndex;
  final int? pageCount;
}

class ReaderChromeVisibility {
  const ReaderChromeVisibility({
    required this.hasReaderInfoItems,
    required this.showsOuterPinnedChapterHeader,
    required this.showsOuterInfoBars,
    required this.showsPagedHeaderInfoBar,
    required this.showsOuterFooterInfoBar,
    required this.showsAnyHeaderInfoBar,
    required this.showsAnyFooterInfoBar,
    required this.reservesPinnedHeaderSpace,
  });

  final bool hasReaderInfoItems;
  final bool showsOuterPinnedChapterHeader;
  final bool showsOuterInfoBars;
  final bool showsPagedHeaderInfoBar;
  final bool showsOuterFooterInfoBar;
  final bool showsAnyHeaderInfoBar;
  final bool showsAnyFooterInfoBar;
  final bool reservesPinnedHeaderSpace;
}

class ReaderChromeInfoBarSlots {
  const ReaderChromeInfoBarSlots({
    this.leading = const <ReaderInfoBarItemData>[],
    this.center = const <ReaderInfoBarItemData>[],
    this.trailing = const <ReaderInfoBarItemData>[],
  });

  final List<ReaderInfoBarItemData> leading;
  final List<ReaderInfoBarItemData> center;
  final List<ReaderInfoBarItemData> trailing;
}

class ReaderChromeResolver {
  const ReaderChromeResolver();

  ReaderChromeVisibility resolveVisibility(
    ReaderSettings settings,
    ReaderPresentationViewportKind viewportKind,
  ) {
    final hasReaderInfoItems =
        settings.infoShowProgress ||
        settings.infoShowTime ||
        settings.infoShowBattery ||
        settings.infoShowChapter;
    final showsOuterPinnedChapterHeader =
        viewportKind != ReaderPresentationViewportKind.textPaged;
    final showsOuterInfoBars =
        viewportKind == ReaderPresentationViewportKind.textScroll;
    final showsPagedHeaderInfoBar =
        viewportKind == ReaderPresentationViewportKind.textPaged &&
        settings.infoHeaderEnabled &&
        hasReaderInfoItems;
    final showsOuterFooterInfoBar =
        showsOuterInfoBars &&
        (settings.infoFooterEnabled ||
            (!settings.infoHeaderEnabled &&
                !settings.infoFooterEnabled &&
                hasReaderInfoItems));
    final showsAnyHeaderInfoBar =
        (showsOuterInfoBars && settings.infoHeaderEnabled) ||
        showsPagedHeaderInfoBar;
    final showsAnyFooterInfoBar =
        showsOuterFooterInfoBar ||
        (viewportKind == ReaderPresentationViewportKind.textPaged &&
            hasReaderInfoItems);
    return ReaderChromeVisibility(
      hasReaderInfoItems: hasReaderInfoItems,
      showsOuterPinnedChapterHeader: showsOuterPinnedChapterHeader,
      showsOuterInfoBars: showsOuterInfoBars,
      showsPagedHeaderInfoBar: showsPagedHeaderInfoBar,
      showsOuterFooterInfoBar: showsOuterFooterInfoBar,
      showsAnyHeaderInfoBar: showsAnyHeaderInfoBar,
      showsAnyFooterInfoBar: showsAnyFooterInfoBar,
      reservesPinnedHeaderSpace:
          viewportKind == ReaderPresentationViewportKind.textPaged ||
          showsOuterPinnedChapterHeader,
    );
  }

  ReaderChromeInfoBarSlots resolveInfoBarSlots({
    required ReaderChromeSnapshot snapshot,
    required ReaderChromeVisibility visibility,
    required bool isHeader,
  }) {
    return ReaderChromeInfoBarSlots(
      leading: _buildLeadingItems(
        snapshot: snapshot,
        visibility: visibility,
        isHeader: isHeader,
      ),
      center: _buildCenterItems(
        snapshot: snapshot,
        visibility: visibility,
        isHeader: isHeader,
      ),
      trailing: _buildTrailingItems(
        snapshot: snapshot,
        visibility: visibility,
        isHeader: isHeader,
      ),
    );
  }

  List<String> buildPagedOverlayRightItems(ReaderChromeSnapshot snapshot) {
    final items = <String>[];
    if (snapshot.settings.infoShowTime) {
      items.add(formatTime(snapshot.now));
    }
    if (snapshot.settings.infoShowBattery) {
      items.add(batteryLabel(snapshot));
    }
    return items;
  }

  String? resolvedChapterTitle(ReaderChromeSnapshot snapshot) {
    final chapterTitle = snapshot.chapterTitle?.trim();
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      return chapterTitle;
    }
    final bookTitle = snapshot.bookTitle?.trim();
    if (bookTitle != null && bookTitle.isNotEmpty) {
      return bookTitle;
    }
    return null;
  }

  String progressLabel(ReaderChromeSnapshot snapshot) {
    if (snapshot.pageIndex != null &&
        snapshot.pageCount != null &&
        snapshot.pageCount! > 0) {
      final current = snapshot.pageIndex!.clamp(0, snapshot.pageCount! - 1) + 1;
      return '$current/${snapshot.pageCount} · ${snapshot.progressPercent}%';
    }
    return '进度 ${snapshot.progressPercent}%';
  }

  String batteryLabel(ReaderChromeSnapshot snapshot) {
    if (snapshot.batteryReadFailed) {
      return '电量 N/A';
    }
    final level = snapshot.batteryLevel;
    if (level != null) {
      return '电量 ${level.clamp(0, 100)}%';
    }
    return '电量 --';
  }

  String formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<ReaderInfoBarItemData> _buildLeadingItems({
    required ReaderChromeSnapshot snapshot,
    required ReaderChromeVisibility visibility,
    required bool isHeader,
  }) {
    final items = <ReaderInfoBarItemData>[];
    if (isHeader) {
      if (snapshot.settings.infoShowTime) {
        items.add(ReaderInfoBarItemData.text(formatTime(snapshot.now)));
      }
      return items;
    }

    if (snapshot.settings.infoShowChapter) {
      final chapterTitle = resolvedChapterTitle(snapshot);
      if (chapterTitle != null) {
        items.add(
          ReaderInfoBarItemData.text(
            chapterTitle,
            role: ReaderInfoBarTextRole.primary,
            expand: true,
          ),
        );
      }
    }

    if (!visibility.showsAnyHeaderInfoBar &&
        !visibility.showsAnyFooterInfoBar &&
        snapshot.settings.infoShowTime &&
        items.isEmpty) {
      items.add(ReaderInfoBarItemData.text(formatTime(snapshot.now)));
    }
    return items;
  }

  List<ReaderInfoBarItemData> _buildCenterItems({
    required ReaderChromeSnapshot snapshot,
    required ReaderChromeVisibility visibility,
    required bool isHeader,
  }) {
    final items = <ReaderInfoBarItemData>[];
    if (isHeader &&
        !visibility.showsAnyFooterInfoBar &&
        snapshot.settings.infoShowChapter) {
      final chapterTitle = resolvedChapterTitle(snapshot);
      if (chapterTitle != null) {
        items.add(
          ReaderInfoBarItemData.text(
            chapterTitle,
            role: ReaderInfoBarTextRole.primary,
            expand: true,
          ),
        );
      }
    }
    return items;
  }

  List<ReaderInfoBarItemData> _buildTrailingItems({
    required ReaderChromeSnapshot snapshot,
    required ReaderChromeVisibility visibility,
    required bool isHeader,
  }) {
    final items = <ReaderInfoBarItemData>[];
    if (isHeader) {
      if (snapshot.settings.infoShowBattery) {
        items.add(
          ReaderInfoBarItemData.battery(
            batteryLevel: snapshot.batteryLevel,
            batteryReadFailed: snapshot.batteryReadFailed,
          ),
        );
      }
      if (!visibility.showsAnyFooterInfoBar &&
          snapshot.settings.infoShowProgress) {
        items.add(ReaderInfoBarItemData.text(progressLabel(snapshot)));
      }
      return items;
    }

    if (!visibility.showsAnyHeaderInfoBar && snapshot.settings.infoShowTime) {
      items.add(ReaderInfoBarItemData.text(formatTime(snapshot.now)));
    }
    if (!visibility.showsAnyHeaderInfoBar &&
        snapshot.settings.infoShowBattery) {
      items.add(
        ReaderInfoBarItemData.battery(
          batteryLevel: snapshot.batteryLevel,
          batteryReadFailed: snapshot.batteryReadFailed,
        ),
      );
    }
    if (snapshot.settings.infoShowProgress) {
      items.add(
        ReaderInfoBarItemData.text(
          progressLabel(snapshot),
          role: ReaderInfoBarTextRole.primary,
        ),
      );
    }
    return items;
  }
}
