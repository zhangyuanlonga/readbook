import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../bookshelf/application/local_book_import_service.dart';
import '../application/local/local_reader_service.dart';
import '../application/reader_font_registry_service.dart';
import '../application/reader_preferences_service.dart';
import '../application/reader_typography_resolver.dart';

class LocalReaderPage extends StatefulWidget {
  const LocalReaderPage({
    super.key,
    required this.bookId,
    required this.chapterId,
  });

  final String bookId;
  final String chapterId;

  @override
  State<LocalReaderPage> createState() => _LocalReaderPageState();
}

class _LocalReaderPageState extends State<LocalReaderPage> {
  final LocalReaderService _readerService = LocalReaderService();
  final ReaderPreferencesService _readerPreferencesService =
      ReaderPreferencesService();
  final ReaderFontRegistryService _fontRegistryService =
      ReaderFontRegistryService();
  final ReaderTypographyResolver _typographyResolver =
      const ReaderTypographyResolver();
  final ScrollController _scrollController = ScrollController();

  ReaderSettings _settings = const ReaderSettings();
  bool _isLoading = true;
  String? _errorText;
  LocalReaderLoadResult? _result;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    unawaited(_persistProgress());
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentChapterTitle()),
        actions: [
          if (_result != null)
            IconButton(
              onPressed: _showChapterPicker,
              tooltip: '目录',
              icon: const Icon(Icons.list_alt_outlined),
            ),
        ],
      ),
      body: _buildBody(horizontal: horizontal, bottomSafe: bottomSafe),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody({required double horizontal, required double bottomSafe}) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_errorText != null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          16,
          horizontal,
          16 + bottomSafe,
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '加载失败',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_errorText!),
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: _load, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final chapter = result.chapters[_currentIndex];

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          unawaited(_persistProgress());
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          _settings.horizontalPadding + horizontal * 0.2,
          18,
          _settings.horizontalPadding + horizontal * 0.2,
          24 + bottomSafe,
        ),
        child: SelectableText(
          chapter.content,
          style: _typographyResolver.resolveBodyStyle(
            settings: _settings,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget? _buildBottomBar() {
    final result = _result;
    if (_isLoading || result == null || _errorText != null) {
      return null;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _currentIndex <= 0
                        ? null
                        : () => _goToIndex(_currentIndex - 1),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('上一章'),
              ),
            ),
            const SizedBox(width: 8),
            Text('${_currentIndex + 1}/${result.chapters.length}'),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _currentIndex >= result.chapters.length - 1
                        ? null
                        : () => _goToIndex(_currentIndex + 1),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('下一章'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final loadedSettings = await _readerPreferencesService.loadSettings();
      var normalizedSettings = loadedSettings;
      try {
        await _fontRegistryService.restoreRegisteredFonts();
        normalizedSettings = await _fontRegistryService
            .normalizeCustomFontSettings(loadedSettings);
      } catch (_) {
        normalizedSettings = loadedSettings.copyWith(
          fontSource: ReaderFontSource.system,
          clearFontFamilyKey: true,
          clearCustomFontPath: true,
        );
      }

      final fontSettingsChanged =
          normalizedSettings.fontSource != loadedSettings.fontSource ||
          normalizedSettings.fontFamilyKey != loadedSettings.fontFamilyKey ||
          normalizedSettings.customFontPath != loadedSettings.customFontPath;
      if (fontSettingsChanged) {
        await _readerPreferencesService.saveSettings(normalizedSettings);
      }

      final result = await _readerService.load(
        bookId: widget.bookId,
        chapterId: widget.chapterId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = normalizedSettings;
        _result = result;
        _currentIndex = result.currentIndex;
      });

      await _restoreProgressIfPossible();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreProgressIfPossible() async {
    final result = _result;
    if (result == null) {
      return;
    }

    final progress = await _readerPreferencesService.loadProgress(
      widget.bookId,
    );
    if (progress == null ||
        progress.sourceId != LocalBookImportService.localBookSourceId) {
      return;
    }

    final chapterIndex = result.chapters.indexWhere(
      (item) => item.id == progress.chapterId,
    );
    if (chapterIndex >= 0 && chapterIndex != _currentIndex) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentIndex = chapterIndex;
      });
    }

    if (progress.chapterPositionRatio <= 0 || !_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }
        _scrollController.jumpTo(0);
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(maxScroll * progress.chapterPositionRatio);
    });
  }

  Future<void> _goToIndex(int index) async {
    final result = _result;
    if (result == null || index < 0 || index >= result.chapters.length) {
      return;
    }

    await _persistProgress();

    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    await _persistProgress(forceTop: true);
  }

  Future<void> _showChapterPicker() async {
    final result = _result;
    if (result == null) {
      return;
    }

    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return ListView.builder(
          itemCount: result.chapters.length,
          itemBuilder: (context, index) {
            final chapter = result.chapters[index];
            return ListTile(
              selected: index == _currentIndex,
              title: Text(
                chapter.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('第 ${index + 1} 章'),
              onTap: () => Navigator.of(context).pop(index),
            );
          },
        );
      },
    );

    if (selectedIndex == null || selectedIndex == _currentIndex) {
      return;
    }

    await _goToIndex(selectedIndex);
  }

  Future<void> _persistProgress({bool forceTop = false}) async {
    final result = _result;
    if (result == null ||
        _currentIndex < 0 ||
        _currentIndex >= result.chapters.length) {
      return;
    }

    final chapter = result.chapters[_currentIndex];
    final ratio = forceTop ? 0.0 : _currentScrollRatio();

    await _readerPreferencesService.saveProgress(
      ReadingProgress(
        bookId: result.book.id,
        sourceId: LocalBookImportService.localBookSourceId,
        detailUrl: 'local://book/${result.book.id}',
        chapterId: chapter.id,
        chapterUrl: 'local://chapter/${chapter.id}',
        chapterTitle: chapter.title,
        chapterIndex: chapter.chapterIndex,
        updatedAt: DateTime.now(),
        chapterPositionRatio: ratio,
      ),
    );
  }

  double _currentScrollRatio() {
    if (!_scrollController.hasClients) {
      return 0;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      return 0;
    }

    final ratio = _scrollController.offset / maxScroll;
    return ratio.clamp(0.0, 1.0);
  }

  String _currentChapterTitle() {
    final result = _result;
    if (result == null || _currentIndex >= result.chapters.length) {
      return '本地阅读';
    }
    return result.chapters[_currentIndex].title;
  }
}
