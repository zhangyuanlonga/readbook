import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/reader_content_session.dart';

class ReaderAudioViewModel {
  const ReaderAudioViewModel({
    required this.contentSession,
  });

  final ReaderContentSession contentSession;
}

class ReaderAudioView extends StatelessWidget {
  const ReaderAudioView({super.key, required this.model});

  final ReaderAudioViewModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = model.contentSession;
    final title =
        (session.chapterTitle?.trim().isNotEmpty ?? false)
            ? session.chapterTitle!.trim()
            : session.bookTitle;
    final audioUrl = session.audioUrl;
    final audioManifestUrl = session.audioManifestUrl;
    final preferredUrl = audioUrl ?? audioManifestUrl;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.72,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '听书模式',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    session.bookTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (audioUrl != null) ...[
                    const SizedBox(height: 16),
                    Text('Audio URL', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    SelectableText(audioUrl, style: theme.textTheme.bodySmall),
                  ],
                  if (audioManifestUrl != null) ...[
                    const SizedBox(height: 16),
                    Text('Manifest URL', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    SelectableText(
                      audioManifestUrl,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            preferredUrl == null
                                ? null
                                : () => _openExternal(context, preferredUrl),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('外部打开'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            preferredUrl == null
                                ? null
                                : () => _copyToClipboard(context, preferredUrl),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('复制地址'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '音频资源已识别。当前先提供外部打开和复制地址，后续再补完整站内播放控制。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openExternal(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      _showSnackBar(context, '音频地址无效');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showSnackBar(context, '外部打开失败');
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      _showSnackBar(context, '已复制音频地址');
    }
  }

  void _showSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }
}
