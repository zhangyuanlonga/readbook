import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/widgets/foundation/app_button.dart';
import '../../../../app/widgets/foundation/app_progress.dart';
import '../../../../app/widgets/runtime_feedback_card.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../reader/application/local/local_book_workflow_policy.dart';

class BookDetailFeedbackCard extends StatelessWidget {
  const BookDetailFeedbackCard({
    super.key,
    required this.title,
    required this.message,
    required this.tone,
    this.actions = const <Widget>[],
  });

  final String title;
  final String message;
  final RuntimeFeedbackTone tone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return RuntimeFeedbackCard(
      title: title,
      message: message,
      tone: tone,
      actions: actions,
    );
  }
}

class BookDetailErrorPresenter extends StatelessWidget {
  const BookDetailErrorPresenter({
    super.key,
    required this.message,
    required this.onRetry,
    this.onLogin,
    this.onSwitchSource,
    this.onCopyDiagnostics,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onLogin;
  final VoidCallback? onSwitchSource;
  final VoidCallback? onCopyDiagnostics;

  @override
  Widget build(BuildContext context) {
    return BookDetailFeedbackCard(
      title: '加载失败',
      message: message,
      tone: RuntimeFeedbackTone.error,
      actions: <Widget>[
        AppButton(
          label: onLogin == null ? '重试' : '登录后重试',
          variant: AppButtonVariant.tonal,
          onPressed: onLogin ?? onRetry,
          icon:
              onLogin == null
                  ? null
                  : const Icon(Icons.login_rounded, size: 16),
        ),
        if (onSwitchSource != null)
          AppButton(
            label: '换源',
            onPressed: onSwitchSource,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
          ),
        if (onCopyDiagnostics != null)
          AppButton(
            label: '复制诊断信息',
            variant: AppButtonVariant.secondary,
            onPressed: onCopyDiagnostics,
            icon: const Icon(Icons.copy_rounded, size: 16),
          ),
      ],
    );
  }
}

class BookDetailOverviewLayout extends StatelessWidget {
  const BookDetailOverviewLayout({
    super.key,
    required this.scrollOffset,
    required this.detailCard,
    required this.desktopCoverPane,
    required this.desktopSummaryText,
    required this.quickActionsCard,
    this.introCard,
    this.organizationCard,
    this.localIndexStatusCard,
    this.serverMetaLine,
    this.mobileLatestMetaLine,
    this.desktopLatestMetaLine,
    this.chapterStatusLine,
    this.tocWarningCard,
    this.hasOrganization = false,
    this.hasServerMeta = false,
    this.hasMobileLatestMeta = false,
    this.hasDesktopLatestMeta = false,
    this.hasChapterStatus = false,
  });

  final double scrollOffset;
  final Widget detailCard;
  final Widget desktopCoverPane;
  final Widget desktopSummaryText;
  final Widget quickActionsCard;
  final Widget? introCard;
  final Widget? organizationCard;
  final Widget? localIndexStatusCard;
  final Widget? serverMetaLine;
  final Widget? mobileLatestMetaLine;
  final Widget? desktopLatestMetaLine;
  final Widget? chapterStatusLine;
  final Widget? tocWarningCard;
  final bool hasOrganization;
  final bool hasServerMeta;
  final bool hasMobileLatestMeta;
  final bool hasDesktopLatestMeta;
  final bool hasChapterStatus;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    if (metrics.isMediumUpWindow) {
      return _buildDesktop(context, metrics);
    }
    return _buildMobile(metrics);
  }

  Widget _buildDesktop(BuildContext context, AppAdaptiveMetrics metrics) {
    final compactDesktop = metrics.isMediumWindow;
    final coverWidth = compactDesktop ? 188.0 : 240.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: coverWidth, child: desktopCoverPane),
        SizedBox(width: metrics.sectionGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              desktopSummaryText,
              if (hasDesktopLatestMeta && desktopLatestMetaLine != null) ...[
                SizedBox(height: metrics.sectionGap),
                desktopLatestMetaLine!,
              ] else if (hasChapterStatus && chapterStatusLine != null) ...[
                SizedBox(height: metrics.sectionGap),
                chapterStatusLine!,
              ],
              SizedBox(height: metrics.sectionGap),
              quickActionsCard,
              if (introCard != null) ...[
                SizedBox(height: metrics.sectionGap),
                introCard!,
              ],
              if (tocWarningCard != null) ...[
                SizedBox(height: metrics.sectionGap),
                tocWarningCard!,
              ],
              if (hasServerMeta &&
                  !hasDesktopLatestMeta &&
                  serverMetaLine != null) ...[
                SizedBox(height: metrics.sectionGap),
                serverMetaLine!,
              ],
              if (hasOrganization && organizationCard != null) ...[
                SizedBox(height: metrics.sectionGap),
                organizationCard!,
              ],
              if (localIndexStatusCard != null) ...[
                SizedBox(height: metrics.sectionGap),
                localIndexStatusCard!,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobile(AppAdaptiveMetrics metrics) {
    final mobileHeaderInset = metrics.isCompactDensity ? 4.0 : 6.0;
    final translatedDetailCard = Transform.translate(
      offset: Offset(
        0,
        (-scrollOffset.clamp(0.0, 80.0) * 0.1).clamp(-8.0, 0.0),
      ),
      child: detailCard,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: mobileHeaderInset),
          child: translatedDetailCard,
        ),
        SizedBox(height: metrics.sectionGap),
        if (hasMobileLatestMeta && mobileLatestMetaLine != null) ...[
          Padding(
            padding: EdgeInsets.only(left: mobileHeaderInset),
            child: mobileLatestMetaLine!,
          ),
          SizedBox(height: metrics.sectionGap),
        ],
        quickActionsCard,
        if (hasOrganization && organizationCard != null) ...[
          SizedBox(height: metrics.sectionGap),
          organizationCard!,
        ],
        if (introCard != null) ...[
          SizedBox(height: metrics.sectionGap),
          introCard!,
        ],
      ],
    );
  }
}

class BookDetailLoadingSkeleton extends StatelessWidget {
  const BookDetailLoadingSkeleton({
    super.key,
    this.title,
    this.author,
    this.cover,
  });

  final String? title;
  final String? author;
  final Widget? cover;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedTitle = (title ?? '').trim();
    final normalizedAuthor = (author ?? '').trim();

    Widget block({
      required double height,
      double? width,
      BorderRadius? borderRadius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: borderRadius ?? BorderRadius.circular(10),
        ),
      );
    }

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover ??
                    block(
                      width: 104,
                      height: 148,
                      borderRadius: BorderRadius.circular(16),
                    ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (normalizedTitle.isNotEmpty)
                        Text(
                          normalizedTitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        )
                      else
                        block(height: 22, width: double.infinity),
                      const SizedBox(height: 12),
                      if (normalizedAuthor.isNotEmpty)
                        Text(
                          normalizedAuthor,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        )
                      else
                        block(height: 16, width: 160),
                      const SizedBox(height: 8),
                      block(height: 16, width: 130),
                      const SizedBox(height: 8),
                      block(height: 16, width: 200),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              block(height: 18, width: 48),
              const SizedBox(height: 10),
              block(height: 14, width: double.infinity),
              const SizedBox(height: 8),
              block(height: 14, width: double.infinity),
              const SizedBox(height: 8),
              block(height: 14, width: 220),
            ],
          ),
        ),
      ],
    );
  }
}

class BookDetailInlineRefreshNotice extends StatelessWidget {
  const BookDetailInlineRefreshNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          AppProgressIndicator(
            size: 16,
            strokeWidth: 2,
            color: colorScheme.primary,
            semanticLabel: '解析本地图书',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '正在刷新最新详情…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookDetailMetadataNoticeCard extends StatelessWidget {
  const BookDetailMetadataNoticeCard({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class BookDetailLocalIndexStatusCard extends StatelessWidget {
  const BookDetailLocalIndexStatusCard({
    super.key,
    required this.localBook,
    required this.isLoading,
    required this.onRebuild,
  });

  final LocalBook localBook;
  final bool isLoading;
  final VoidCallback onRebuild;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (title, message, background, foreground, icon) = switch (localBook
        .indexStatus) {
      LocalBookIndexStatus.pending => (
        LocalBookWorkflowPolicy.statusHeadline(localBook),
        LocalBookWorkflowPolicy.statusDescription(localBook),
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.schedule_rounded,
      ),
      LocalBookIndexStatus.indexing => (
        LocalBookWorkflowPolicy.statusHeadline(localBook),
        LocalBookWorkflowPolicy.statusDescription(localBook),
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        Icons.autorenew_rounded,
      ),
      LocalBookIndexStatus.stale => (
        LocalBookWorkflowPolicy.statusHeadline(localBook),
        LocalBookWorkflowPolicy.statusDescription(localBook),
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.refresh_rounded,
      ),
      LocalBookIndexStatus.failed => (
        LocalBookWorkflowPolicy.statusHeadline(localBook),
        LocalBookWorkflowPolicy.statusDescription(localBook),
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      _ => (
        LocalBookWorkflowPolicy.statusHeadline(localBook),
        LocalBookWorkflowPolicy.statusDescription(localBook),
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.check_circle_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (localBook.indexStatus == LocalBookIndexStatus.failed ||
              localBook.indexStatus == LocalBookIndexStatus.stale)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: AppButton(
                label: '重建',
                variant: AppButtonVariant.text,
                size: AppButtonSize.compact,
                onPressed: isLoading ? null : onRebuild,
                icon: Icon(Icons.refresh_rounded, color: foreground, size: 16),
                style: ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(foreground),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BookDetailTocWarningCard extends StatelessWidget {
  const BookDetailTocWarningCard({
    super.key,
    required this.message,
    this.actions = const <Widget>[],
  });

  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class BookDetailTocWarningPresenter extends StatelessWidget {
  const BookDetailTocWarningPresenter({
    super.key,
    required this.message,
    this.onLogin,
    this.onCopyDiagnostics,
  });

  final String message;
  final VoidCallback? onLogin;
  final VoidCallback? onCopyDiagnostics;

  @override
  Widget build(BuildContext context) {
    return BookDetailTocWarningCard(
      message: message,
      actions: <Widget>[
        if (onLogin != null)
          AppButton(
            label: '登录后重试',
            variant: AppButtonVariant.tonal,
            onPressed: onLogin,
            icon: const Icon(Icons.login_rounded, size: 16),
          ),
        if (onCopyDiagnostics != null)
          AppButton(
            label: '复制诊断信息',
            variant: AppButtonVariant.secondary,
            onPressed: onCopyDiagnostics,
            icon: const Icon(Icons.copy_rounded, size: 16),
          ),
      ],
    );
  }
}

class BookDetailMobileTocWarningPlacement extends StatelessWidget {
  const BookDetailMobileTocWarningPlacement({
    super.key,
    required this.warningCard,
  });

  final Widget warningCard;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    if (metrics.isMediumUpWindow) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SizedBox(height: metrics.sectionGap), warningCard],
    );
  }
}
