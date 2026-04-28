part of 'script_source_debug_page.dart';

extension on _ScriptSourceDebugPageState {
Future<void> _runInspection() async {
  if (_isRunning) {
    return;
  }
  final rawKeyword = _keywordController.text.trim();
  if (rawKeyword.isEmpty) {
    _showTransientMessage('请先填写调试关键词。');
    return;
  }

  _updateDebugPageState(() {
    _isRunning = true;
    _report = null;
  });

  try {
    final report =
        widget.useInstalledSourceFlow
            ? await _runInstalledSourceInspection(rawKeyword)
            : await _runDraftInspection(rawKeyword);
    if (!mounted) {
      return;
    }
    _updateDebugPageState(() {
      _report = report;
    });
  } finally {
    if (mounted) {
      _updateDebugPageState(() {
        _isRunning = false;
      });
    }
  }
}

  Future<_RunReport> _runInstalledSourceInspection(String rawKeyword) async {
    final sourceId = widget.sourceId!.trim();
    final registered = await _sourceRuntimeFacade
        .ensureRegisteredScriptSourceById(sourceId);
    if (registered == null) {
      return _RunReport(
        mode: _DebugMode.installedSource,
        keyword: rawKeyword,
        level: _selectedLevel,
        sourceName:
            widget.title?.trim().isNotEmpty == true ? widget.title! : sourceId,
        summary: _RunSummary(
          status: SourceCheckStatus.failed,
          stepReached: SourceCheckStep.none,
          message: '书源不存在或已禁用。',
          duration: Duration.zero,
          needsBrowser: false,
        ),
        stages: const <_StageReport>[],
      );
    }

    final effectiveKeyword = SourceCheckService.resolveCheckKeyword(
      rawKeyword,
      manifestKeyword: registered.definition.manifest.checkKeyword,
    );
    final needsBrowser = _looksLikeBrowserCapable(registered);
    final runStartedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final stages = <_StageReport>[];

    runtime_models.Book? workingBook;
    runtime_models.Chapter? workingChapter;

    final searchStage = await _runInstalledSearchStage(
      sourceId: sourceId,
      keyword: effectiveKeyword,
      runStartedAt: runStartedAt,
    );
    stages.add(searchStage);
    if (!searchStage.isSuccess) {
      stopwatch.stop();
      return _buildInstalledReport(
        sourceName: registered.runtime.name,
        keyword: effectiveKeyword,
        needsBrowser: needsBrowser,
        stages: stages,
        duration: stopwatch.elapsed,
      );
    }
    workingBook = searchStage.book;

    if (_selectedLevel == SourceCheckLevel.searchOnly) {
      stopwatch.stop();
      return _buildInstalledReport(
        sourceName: registered.runtime.name,
        keyword: effectiveKeyword,
        needsBrowser: needsBrowser,
        stages: stages,
        duration: stopwatch.elapsed,
      );
    }

    final detailStage = await _runInstalledDetailStage(
      sourceId: sourceId,
      book: workingBook!,
      runStartedAt: runStartedAt,
    );
    stages.add(detailStage);
    if (!detailStage.isSuccess) {
      stopwatch.stop();
      return _buildInstalledReport(
        sourceName: registered.runtime.name,
        keyword: effectiveKeyword,
        needsBrowser: needsBrowser,
        stages: stages,
        duration: stopwatch.elapsed,
      );
    }
    workingBook = detailStage.book;

    if (_selectedLevel == SourceCheckLevel.searchAndDetail) {
      stopwatch.stop();
      return _buildInstalledReport(
        sourceName: registered.runtime.name,
        keyword: effectiveKeyword,
        needsBrowser: needsBrowser,
        stages: stages,
        duration: stopwatch.elapsed,
      );
    }

    final chaptersStage = await _runInstalledChaptersStage(
      sourceId: sourceId,
      book: workingBook!,
      runStartedAt: runStartedAt,
    );
    stages.add(chaptersStage);
    if (!chaptersStage.isSuccess) {
      stopwatch.stop();
      return _buildInstalledReport(
        sourceName: registered.runtime.name,
        keyword: effectiveKeyword,
        needsBrowser: needsBrowser,
        stages: stages,
        duration: stopwatch.elapsed,
      );
    }
    workingChapter = chaptersStage.chapter;

    final contentStage = await _runInstalledContentStage(
      sourceId: sourceId,
      book: workingBook,
      chapter: workingChapter!,
      runStartedAt: runStartedAt,
    );
    stages.add(contentStage);

    stopwatch.stop();
    return _buildInstalledReport(
      sourceName: registered.runtime.name,
      keyword: effectiveKeyword,
      needsBrowser: needsBrowser,
      stages: stages,
      duration: stopwatch.elapsed,
    );
  }

  Future<_StageReport> _runInstalledSearchStage({
    required String sourceId,
    required String keyword,
    required DateTime runStartedAt,
  }) async {
    try {
      final books = await _sourceRuntimeFacade.search(
        sourceId: sourceId,
        keyword: keyword,
        allowInteractiveChallenge: false,
      );
      final artifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      final payload = books.map(_bookToMap).toList(growable: false);
      if (books.isEmpty) {
        return _emptyStage(
          step: SourceCheckStep.search,
          title: '搜索',
          summary: '搜索已执行，但没有返回任何书籍。',
          payload: payload,
          runStartedAt: runStartedAt,
          logs: artifacts.logs,
          traces: artifacts.traces,
        );
      }
      final firstBook = books.first;
      return _successStage(
        step: SourceCheckStep.search,
        title: '搜索',
        summary: '搜索返回 ${books.length} 本书，已拿到首条结果。',
        highlights: <String>[
          '结果数 ${books.length}',
          '首本《${firstBook.title}》',
          if (firstBook.author.trim().isNotEmpty) '作者 ${firstBook.author}',
        ],
        payload: payload,
        runStartedAt: runStartedAt,
        logs: artifacts.logs,
        traces: artifacts.traces,
        stageSpecificEntries: <_TimelineEntry>[
          _payloadEntry(
            runStartedAt: runStartedAt,
            message: '获取书籍列表',
            detail: '列表大小 ${books.length}',
          ),
          _payloadEntry(
            runStartedAt: runStartedAt,
            message: '获取首本书名',
            detail: firstBook.title,
          ),
          if (firstBook.author.trim().isNotEmpty)
            _payloadEntry(
              runStartedAt: runStartedAt,
              message: '获取首本作者',
              detail: firstBook.author,
            ),
        ],
        book: firstBook,
      );
    } catch (error) {
      final artifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      return _failedStage(
        step: SourceCheckStep.search,
        title: '搜索',
        summary: _friendlyErrorMessage(error),
        payload: null,
        runStartedAt: runStartedAt,
        logs: artifacts.logs,
        traces: artifacts.traces,
      );
    }
  }

  Future<_StageReport> _runInstalledDetailStage({
    required String sourceId,
    required runtime_models.Book book,
    required DateTime runStartedAt,
  }) async {
    try {
      final detail = await _sourceRuntimeFacade.detail(
        sourceId: sourceId,
        book: book,
      );
      final artifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      if (detail.title.trim().isEmpty) {
        return _failedStage(
          step: SourceCheckStep.detail,
          title: '详情',
          summary: '详情结果缺少标题。',
          payload: _bookToMap(detail),
          runStartedAt: runStartedAt,
          logs: artifacts.logs,
          traces: artifacts.traces,
        );
      }
      return _successStage(
        step: SourceCheckStep.detail,
        title: '详情',
        summary: '详情页数据可用，已拿到书籍关键信息。',
        highlights: <String>[
          '书名《${detail.title}》',
          if (detail.author.trim().isNotEmpty) '作者 ${detail.author}',
          if (detail.latestChapter.trim().isNotEmpty)
            '最新章节 ${detail.latestChapter}',
          if (detail.detailUrl.trim().isNotEmpty) '详情链接已返回',
        ],
        payload: _bookToMap(detail),
        runStartedAt: runStartedAt,
        logs: artifacts.logs,
        traces: artifacts.traces,
        stageSpecificEntries: <_TimelineEntry>[
          _payloadEntry(
            runStartedAt: runStartedAt,
            message: '获取书名',
            detail: detail.title,
          ),
          if (detail.author.trim().isNotEmpty)
            _payloadEntry(
              runStartedAt: runStartedAt,
              message: '获取作者',
              detail: detail.author,
            ),
          if (detail.intro.trim().isNotEmpty)
            _payloadEntry(
              runStartedAt: runStartedAt,
              message: '获取简介',
              detail: _truncate(detail.intro, maxLength: 200),
            ),
        ],
        book: detail,
      );
    } catch (error) {
      final artifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      return _failedStage(
        step: SourceCheckStep.detail,
        title: '详情',
        summary: _friendlyErrorMessage(error),
        payload: null,
        runStartedAt: runStartedAt,
        logs: artifacts.logs,
        traces: artifacts.traces,
      );
    }
  }

  Future<_StageReport> _runInstalledChaptersStage({
    required String sourceId,
    required runtime_models.Book book,
    required DateTime runStartedAt,
  }) async {
    try {
      final chapters = await _sourceRuntimeFacade.chapters(
        sourceId: sourceId,
        book: book,
      );
      final artifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      final payload = chapters.map(_chapterToMap).toList(growable: false);
      if (chapters.isEmpty) {
        return _emptyStage(
          step: SourceCheckStep.chapters,
          title: '目录',
          summary: '目录阶段返回空列表。',
          payload: payload,
          runStartedAt: runStartedAt,
          logs: artifacts.logs,
          traces: artifacts.traces,
        );
      }
      final readable = chapters.where(
        (item) => !item.isVolume && item.url.trim().isNotEmpty,
      );
      final firstReadable = readable.isNotEmpty ? readable.first : null;
      if (firstReadable == null) {
        return _emptyStage(
          step: SourceCheckStep.chapters,
          title: '目录',
          summary: '目录无可读章节。',
          payload: payload,
          runStartedAt: runStartedAt,
          logs: artifacts.logs,
          traces: artifacts.traces,
        );
      }
      return _successStage(
        step: SourceCheckStep.chapters,
        title: '目录',
        summary: '目录可用，已拿到章节列表。',
        highlights: <String>[
          '章节数 ${chapters.length}',
          '首个可读章节 ${firstReadable.title}',
          if (chapters.last.title.trim().isNotEmpty)
            '末章 ${chapters.last.title}',
        ],
        payload: payload,
        runStartedAt: runStartedAt,
        logs: artifacts.logs,
        traces: artifacts.traces,
        stageSpecificEntries: <_TimelineEntry>[
          _payloadEntry(
            runStartedAt: runStartedAt,
            message: '获取章节列表',
            detail: '章节总数 ${chapters.length}',
          ),
          _payloadEntry(
            runStartedAt: runStartedAt,
            message: '获取首个可读章节',
            detail: firstReadable.title,
          ),
        ],
        chapter: firstReadable,
      );
    } catch (error) {
      final artifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      return _failedStage(
        step: SourceCheckStep.chapters,
        title: '目录',
        summary: _friendlyErrorMessage(error),
        payload: null,
        runStartedAt: runStartedAt,
        logs: artifacts.logs,
        traces: artifacts.traces,
      );
    }
  }

  Future<_StageReport> _runInstalledContentStage({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
    required DateTime runStartedAt,
  }) async {
    try {
      final content = await _sourceRuntimeFacade.content(
        sourceId: sourceId,
        book: book,
        chapter: chapter,
      );
      final artifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      final payload = _contentToMap(content);
      if (content.content.trim().isEmpty && content.images.isEmpty) {
        return _emptyStage(
          step: SourceCheckStep.content,
          title: '正文',
          summary: '正文阶段没有返回文字，也没有返回图片。',
          payload: payload,
          runStartedAt: runStartedAt,
          logs: artifacts.logs,
          traces: artifacts.traces,
        );
      }
      return _successStage(
        step: SourceCheckStep.content,
        title: '正文',
        summary: '正文内容可读，最终链路已跑通。',
        highlights: <String>[
          if (content.title.trim().isNotEmpty) '标题 ${content.title}',
          if (content.content.trim().isNotEmpty)
            '正文 ${content.content.runes.length} 字',
          if (content.images.isNotEmpty) '图片 ${content.images.length} 张',
        ],
        payload: payload,
        runStartedAt: runStartedAt,
        logs: artifacts.logs,
        traces: artifacts.traces,
        stageSpecificEntries: <_TimelineEntry>[
          if (content.title.trim().isNotEmpty)
            _payloadEntry(
              runStartedAt: runStartedAt,
              message: '获取标题',
              detail: content.title,
            ),
          if (content.content.trim().isNotEmpty)
            _payloadEntry(
              runStartedAt: runStartedAt,
              message: '获取正文',
              detail: '${content.content.runes.length} 字',
            ),
          if (content.images.isNotEmpty)
            _payloadEntry(
              runStartedAt: runStartedAt,
              message: '获取图片',
              detail: '${content.images.length} 张',
            ),
        ],
      );
    } catch (error) {
      final artifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      return _failedStage(
        step: SourceCheckStep.content,
        title: '正文',
        summary: _friendlyErrorMessage(error),
        payload: null,
        runStartedAt: runStartedAt,
        logs: artifacts.logs,
        traces: artifacts.traces,
      );
    }
  }

  _RunReport _buildInstalledReport({
    required String sourceName,
    required String keyword,
    required bool needsBrowser,
    required List<_StageReport> stages,
    required Duration duration,
  }) {
    final firstFailed = stages.cast<_StageReport?>().firstWhere(
      (stage) => stage != null && !stage.isSuccess,
      orElse: () => null,
    );
    final status =
        firstFailed != null
            ? SourceCheckStatus.failed
            : (needsBrowser
                ? SourceCheckStatus.warning
                : SourceCheckStatus.healthy);
    final message =
        firstFailed != null
            ? firstFailed.summary
            : (needsBrowser ? '可用，但存在 browser/challenge 风险。' : '检测通过。');
    final stepReached =
        firstFailed != null
            ? firstFailed.step
            : (stages.isEmpty ? SourceCheckStep.none : stages.last.step);
    return _RunReport(
      mode: _DebugMode.installedSource,
      keyword: keyword,
      level: _selectedLevel,
      sourceName: sourceName,
      summary: _RunSummary(
        status: status,
        stepReached: stepReached,
        message: message,
        duration: duration,
        needsBrowser: needsBrowser,
      ),
      stages: List<_StageReport>.unmodifiable(stages),
    );
  }

  Future<_RunReport> _runDraftInspection(String rawKeyword) async {
    final runStartedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final stages = <_StageReport>[];
    _draftSession.clear();
    _draftSession.clearCookies();

    final searchStage = await _runDraftStage(
      step: SourceCheckStep.search,
      title: '搜索',
      command: _draftSearchCommand(rawKeyword),
      runStartedAt: runStartedAt,
      summaryBuilder: (payload) {
        if (payload is! List) {
          return _DraftStageSemantic.invalid('搜索结果不是列表结构。');
        }
        if (payload.isEmpty) {
          return _DraftStageSemantic.empty('搜索已执行，但没有返回任何书籍。');
        }
        final firstBook = _asMap(payload.first);
        final title = _readString(firstBook?['title']);
        if (title.isEmpty) {
          return _DraftStageSemantic.invalid('搜索结果缺少书籍标题。');
        }
        return _DraftStageSemantic.success(
          summary: '搜索返回 ${payload.length} 本书，已拿到首条结果。',
          highlights: <String>[
            '结果数 ${payload.length}',
            '首本《$title》',
            if (_readString(firstBook?['author']).isNotEmpty)
              '作者 ${_readString(firstBook?['author'])}',
          ],
          extraEntries: <_TimelineEntry>[
            _payloadEntry(
              runStartedAt: runStartedAt,
              message: '获取书籍列表',
              detail: '列表大小 ${payload.length}',
            ),
            _payloadEntry(
              runStartedAt: runStartedAt,
              message: '获取首本书名',
              detail: title,
            ),
          ],
        );
      },
    );
    stages.add(searchStage);
    if (!searchStage.isSuccess ||
        _selectedLevel == SourceCheckLevel.searchOnly) {
      stopwatch.stop();
      return _buildDraftReport(
        keyword: rawKeyword,
        stages: stages,
        duration: stopwatch.elapsed,
      );
    }

    final detailStage = await _runDraftStage(
      step: SourceCheckStep.detail,
      title: '详情',
      command: _draftDetailCommand(rawKeyword),
      runStartedAt: runStartedAt,
      summaryBuilder: (payload) {
        final detail = _asMap(payload);
        if (detail == null) {
          return _DraftStageSemantic.invalid('详情结果不是对象结构。');
        }
        final title = _readString(detail['title']);
        if (title.isEmpty) {
          return _DraftStageSemantic.invalid('详情结果缺少标题。');
        }
        return _DraftStageSemantic.success(
          summary: '详情页数据可用，已拿到书籍关键信息。',
          highlights: <String>[
            '书名《$title》',
            if (_readString(detail['author']).isNotEmpty)
              '作者 ${_readString(detail['author'])}',
          ],
          extraEntries: <_TimelineEntry>[
            _payloadEntry(
              runStartedAt: runStartedAt,
              message: '获取书名',
              detail: title,
            ),
          ],
        );
      },
    );
    stages.add(detailStage);
    if (!detailStage.isSuccess ||
        _selectedLevel == SourceCheckLevel.searchAndDetail) {
      stopwatch.stop();
      return _buildDraftReport(
        keyword: rawKeyword,
        stages: stages,
        duration: stopwatch.elapsed,
      );
    }

    final chaptersStage = await _runDraftStage(
      step: SourceCheckStep.chapters,
      title: '目录',
      command: _draftChaptersCommand(rawKeyword),
      runStartedAt: runStartedAt,
      summaryBuilder: (payload) {
        if (payload is! List) {
          return _DraftStageSemantic.invalid('目录结果不是列表结构。');
        }
        if (payload.isEmpty) {
          return _DraftStageSemantic.empty('目录阶段返回空列表。');
        }
        final first = _asMap(payload.first);
        final title = _readString(first?['title']);
        if (title.isEmpty) {
          return _DraftStageSemantic.invalid('目录项缺少标题。');
        }
        final chapter = payload
            .map(_asMap)
            .whereType<Map<String, Object?>>()
            .firstWhere(
              (item) =>
                  _readString(item['url']).isNotEmpty &&
                  item['isVolume'] != true,
              orElse: () => <String, Object?>{},
            );
        if (_readString(chapter['url']).isEmpty) {
          return _DraftStageSemantic.empty('目录无可读章节。');
        }
        return _DraftStageSemantic.success(
          summary: '目录可用，已拿到章节列表。',
          highlights: <String>[
            '章节数 ${payload.length}',
            '首个可读章节 ${_readString(chapter['title'])}',
          ],
          extraEntries: <_TimelineEntry>[
            _payloadEntry(
              runStartedAt: runStartedAt,
              message: '获取章节列表',
              detail: '章节总数 ${payload.length}',
            ),
          ],
        );
      },
    );
    stages.add(chaptersStage);
    if (!chaptersStage.isSuccess) {
      stopwatch.stop();
      return _buildDraftReport(
        keyword: rawKeyword,
        stages: stages,
        duration: stopwatch.elapsed,
      );
    }

    final contentStage = await _runDraftStage(
      step: SourceCheckStep.content,
      title: '正文',
      command: _draftContentCommand(rawKeyword),
      runStartedAt: runStartedAt,
      summaryBuilder: (payload) {
        final content = _asMap(payload);
        if (content == null) {
          return _DraftStageSemantic.invalid('正文结果不是对象结构。');
        }
        final text = _readString(content['content']);
        final images = _asList(content['images']);
        if (text.isEmpty && images.isEmpty) {
          return _DraftStageSemantic.empty('正文阶段没有返回文字，也没有返回图片。');
        }
        return _DraftStageSemantic.success(
          summary: '正文内容可读，最终链路已跑通。',
          highlights: <String>[
            if (_readString(content['title']).isNotEmpty)
              '标题 ${_readString(content['title'])}',
            if (text.isNotEmpty) '正文 ${text.runes.length} 字',
            if (images.isNotEmpty) '图片 ${images.length} 张',
          ],
          extraEntries: <_TimelineEntry>[
            if (text.isNotEmpty)
              _payloadEntry(
                runStartedAt: runStartedAt,
                message: '获取正文',
                detail: '${text.runes.length} 字',
              ),
          ],
        );
      },
    );
    stages.add(contentStage);

    stopwatch.stop();
    return _buildDraftReport(
      keyword: rawKeyword,
      stages: stages,
      duration: stopwatch.elapsed,
    );
  }

  Future<_StageReport> _runDraftStage({
    required SourceCheckStep step,
    required String title,
    required String command,
    required DateTime runStartedAt,
    required _DraftStageSemantic Function(Object? payload) summaryBuilder,
  }) async {
    final result = await _draftDebugService.evaluate(
      sourceCode: widget.sourceCode,
      command: command,
      session: _draftSession,
    );

    final logs = result.logs
        .map(
          (entry) => <String, Object?>{
            'at': entry.timestamp.toIso8601String(),
            'level': entry.level.name,
            'message': entry.message,
          },
        )
        .toList(growable: false);

    if (result.errorText != null && result.errorText!.trim().isNotEmpty) {
      return _failedStage(
        step: step,
        title: title,
        summary: result.errorText!.trim(),
        payload: result.result,
        runStartedAt: runStartedAt,
        logs: logs,
        traces: result.debugTraces,
      );
    }

    final semantic = summaryBuilder(result.result);
    return switch (semantic.kind) {
      _StageOutcome.success => _successStage(
        step: step,
        title: title,
        summary: semantic.summary,
        highlights: semantic.highlights,
        payload: result.result,
        runStartedAt: runStartedAt,
        logs: logs,
        traces: result.debugTraces,
        stageSpecificEntries: semantic.extraEntries,
      ),
      _StageOutcome.empty => _emptyStage(
        step: step,
        title: title,
        summary: semantic.summary,
        payload: result.result,
        runStartedAt: runStartedAt,
        logs: logs,
        traces: result.debugTraces,
      ),
      _StageOutcome.invalid => _failedStage(
        step: step,
        title: title,
        summary: semantic.summary,
        payload: result.result,
        runStartedAt: runStartedAt,
        logs: logs,
        traces: result.debugTraces,
      ),
      _StageOutcome.failed => _failedStage(
        step: step,
        title: title,
        summary: semantic.summary,
        payload: result.result,
        runStartedAt: runStartedAt,
        logs: logs,
        traces: result.debugTraces,
      ),
    };
  }

  _RunReport _buildDraftReport({
    required String keyword,
    required List<_StageReport> stages,
    required Duration duration,
  }) {
    final firstFailed = stages.cast<_StageReport?>().firstWhere(
      (stage) => stage != null && !stage.isSuccess,
      orElse: () => null,
    );
    return _RunReport(
      mode: _DebugMode.draft,
      keyword: keyword,
      level: _selectedLevel,
      sourceName:
          widget.title?.trim().isNotEmpty == true ? widget.title! : '草稿调试',
      summary: _RunSummary(
        status:
            firstFailed == null
                ? SourceCheckStatus.warning
                : SourceCheckStatus.failed,
        stepReached:
            firstFailed == null
                ? (stages.isEmpty ? SourceCheckStep.none : stages.last.step)
                : firstFailed.step,
        message:
            firstFailed == null
                ? '草稿调试链路已跑通。注意：这不是已安装书源的正式检测结果。'
                : firstFailed.summary,
        duration: duration,
        needsBrowser: false,
      ),
      stages: List<_StageReport>.unmodifiable(stages),
    );
  }

  _StageReport _successStage({
    required SourceCheckStep step,
    required String title,
    required String summary,
    required List<String> highlights,
    required Object? payload,
    required DateTime runStartedAt,
    required List<Map<String, Object?>> logs,
    required List<Map<String, Object?>> traces,
    List<_TimelineEntry> stageSpecificEntries = const <_TimelineEntry>[],
    runtime_models.Book? book,
    runtime_models.Chapter? chapter,
  }) {
    return _StageReport(
      step: step,
      title: title,
      outcome: _StageOutcome.success,
      summary: summary,
      highlights: List<String>.unmodifiable(highlights),
      payload: payload,
      entries: _buildTimelineEntries(
        runStartedAt: runStartedAt,
        logs: logs,
        traces: traces,
        stageSpecificEntries: stageSpecificEntries,
      ),
      rawLogs: List<Map<String, Object?>>.unmodifiable(logs),
      rawTraces: List<Map<String, Object?>>.unmodifiable(traces),
      book: book,
      chapter: chapter,
    );
  }

  _StageReport _emptyStage({
    required SourceCheckStep step,
    required String title,
    required String summary,
    required Object? payload,
    required DateTime runStartedAt,
    required List<Map<String, Object?>> logs,
    required List<Map<String, Object?>> traces,
  }) {
    return _StageReport(
      step: step,
      title: title,
      outcome: _StageOutcome.empty,
      summary: summary,
      highlights: const <String>[],
      payload: payload,
      entries: _buildTimelineEntries(
        runStartedAt: runStartedAt,
        logs: logs,
        traces: traces,
      ),
      rawLogs: List<Map<String, Object?>>.unmodifiable(logs),
      rawTraces: List<Map<String, Object?>>.unmodifiable(traces),
    );
  }

  _StageReport _failedStage({
    required SourceCheckStep step,
    required String title,
    required String summary,
    required Object? payload,
    required DateTime runStartedAt,
    required List<Map<String, Object?>> logs,
    required List<Map<String, Object?>> traces,
  }) {
    return _StageReport(
      step: step,
      title: title,
      outcome: _StageOutcome.failed,
      summary: summary,
      highlights: const <String>[],
      payload: payload,
      entries: _buildTimelineEntries(
        runStartedAt: runStartedAt,
        logs: logs,
        traces: traces,
        stageSpecificEntries: <_TimelineEntry>[
          _payloadEntry(
            runStartedAt: runStartedAt,
            message: '阶段失败',
            detail: summary,
            isError: true,
          ),
        ],
      ),
      rawLogs: List<Map<String, Object?>>.unmodifiable(logs),
      rawTraces: List<Map<String, Object?>>.unmodifiable(traces),
    );
  }

  List<_TimelineEntry> _buildTimelineEntries({
    required DateTime runStartedAt,
    required List<Map<String, Object?>> logs,
    required List<Map<String, Object?>> traces,
    List<_TimelineEntry> stageSpecificEntries = const <_TimelineEntry>[],
  }) {
    final entries = <_TimelineEntry>[
      ...traces.map((trace) => _traceEntry(trace, runStartedAt)),
      ...logs.map((log) => _logEntry(log, runStartedAt)),
      ...stageSpecificEntries,
    ]..sort((left, right) => left.offset.compareTo(right.offset));
    return List<_TimelineEntry>.unmodifiable(entries);
  }

  _TimelineEntry _traceEntry(
    Map<String, Object?> trace,
    DateTime runStartedAt,
  ) {
    final offset = _readOffset(
      _readString(trace['startedAt']),
      runStartedAt: runStartedAt,
    );
    final error = _readString(trace['error']);
    final kind = _readString(trace['kind']);
    if (kind == 'http') {
      final method = _readString(trace['method']);
      final status = _readString(trace['status']);
      final url = _readString(trace['url']);
      return _TimelineEntry(
        offset: offset,
        message:
            error.isNotEmpty
                ? 'HTTP ${method.isEmpty ? 'REQUEST' : method} 请求失败'
                : 'HTTP ${method.isEmpty ? 'REQUEST' : method} ${status.isEmpty ? '' : status}'
                    .trim(),
        detail: error.isNotEmpty ? '$url\n$error' : url,
        isError: error.isNotEmpty,
      );
    }
    if (kind == 'browser') {
      final action = _readString(trace['action']);
      final url = _readString(trace['url']);
      return _TimelineEntry(
        offset: offset,
        message: error.isNotEmpty ? '浏览器动作失败：$action' : '浏览器动作：$action',
        detail: error.isNotEmpty ? '$url\n$error' : url,
        isError: error.isNotEmpty,
      );
    }
    return _TimelineEntry(
      offset: offset,
      message: error.isNotEmpty ? '运行轨迹异常' : '运行轨迹',
      detail:
          error.isNotEmpty
              ? error
              : _truncate(_formatJson(trace), maxLength: 220),
      isError: error.isNotEmpty,
    );
  }

  _TimelineEntry _logEntry(Map<String, Object?> log, DateTime runStartedAt) {
    final offset = _readOffset(
      _readString(log['at']),
      runStartedAt: runStartedAt,
    );
    final level = _readString(log['level']).toLowerCase();
    final message = _readString(log['message']);
    return _TimelineEntry(
      offset: offset,
      message: level.isEmpty ? '日志' : '日志[$level]',
      detail: message,
      isError: level == 'error',
    );
  }

  _TimelineEntry _payloadEntry({
    required DateTime runStartedAt,
    required String message,
    required String detail,
    bool isError = false,
  }) {
    return _TimelineEntry(
      offset: DateTime.now().difference(runStartedAt),
      message: message,
      detail: detail,
      isError: isError,
    );
  }

  String _draftSearchCommand(String keyword) {
    final encodedKeyword = jsonEncode(keyword);
    return '''
const keyword = $encodedKeyword;
const books = await source.search(ctx, keyword);
console.log('search result', books);
return books;
''';
  }

  String _draftDetailCommand(String keyword) {
    final encodedKeyword = jsonEncode(keyword);
    return '''
const keyword = $encodedKeyword;
const books = await source.search(ctx, keyword);
const first = books?.[0];
if (!first) return null;
const detail = await source.detail(ctx, first);
console.log('detail result', detail);
return detail;
''';
  }

  String _draftChaptersCommand(String keyword) {
    final encodedKeyword = jsonEncode(keyword);
    return '''
const keyword = $encodedKeyword;
const books = await source.search(ctx, keyword);
const first = books?.[0];
if (!first) return null;
const detail = await source.detail(ctx, first);
const chapters = await source.chapters(ctx, detail);
console.log('chapters result', chapters);
return chapters;
''';
  }

  String _draftContentCommand(String keyword) {
    final encodedKeyword = jsonEncode(keyword);
    return '''
const keyword = $encodedKeyword;
const books = await source.search(ctx, keyword);
const first = books?.[0];
if (!first) return null;
const detail = await source.detail(ctx, first);
const chapters = await source.chapters(ctx, detail);
const chapter = chapters?.find((item) => item && !item.isVolume && item.url);
if (!chapter) return null;
const content = await source.content(ctx, detail, chapter);
console.log('content result', content);
return content;
''';
  }

  bool _looksLikeBrowserCapable(RegisteredSource registeredSource) {
    final manifest = registeredSource.definition.manifest;
    return manifest.supportsCapability('browser') ||
        manifest.supportsCapability('webview') ||
        manifest.supportsCapability('challenge');
  }

  String _friendlyErrorMessage(Object error) {
    if (error is AppException) {
      return error.briefMessage;
    }
    return error.toString();
  }

  Map<String, Object?> _bookToMap(runtime_models.Book book) {
    return <String, Object?>{
      'title': book.title,
      'author': book.author,
      'type': book.type,
      'cover': book.cover,
      'intro': book.intro,
      'status': book.status,
      'category': book.category,
      'score': book.score,
      'wordCount': book.wordCount,
      'updateTime': book.updateTime,
      'tags': book.tags,
      'latestChapter': book.latestChapter,
      'detailUrl': book.detailUrl,
      'tocUrl': book.tocUrl,
      'sourceId': book.sourceId,
      'extra': book.extra,
      'debug': book.debug,
    };
  }

  Map<String, Object?> _chapterToMap(runtime_models.Chapter chapter) {
    return <String, Object?>{
      'title': chapter.title,
      'url': chapter.url,
      'index': chapter.index,
      'isVolume': chapter.isVolume,
      'isVip': chapter.vip,
      'isPay': chapter.isPay,
      'updateTime': chapter.updateTime,
      'sourceId': chapter.sourceId,
      'extra': chapter.extra,
      'debug': chapter.debug,
    };
  }

  Map<String, Object?> _contentToMap(runtime_models.Content content) {
    return <String, Object?>{
      'title': content.title,
      'content': content.content,
      'nextUrl': content.nextUrl,
      'images': content.images,
      'sourceId': content.sourceId,
      'extra': content.extra,
      'debug': content.debug,
    };
  }

  Map<String, Object?>? _asMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return null;
  }

  List<Object?> _asList(Object? value) {
    if (value is List) {
      return value.cast<Object?>();
    }
    return const <Object?>[];
  }

  String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  Duration _readOffset(String rawTime, {required DateTime runStartedAt}) {
    final parsed = DateTime.tryParse(rawTime);
    if (parsed == null) {
      return Duration.zero;
    }
    final difference = parsed.difference(runStartedAt);
    return difference.isNegative ? Duration.zero : difference;
  }

  String _truncate(String value, {int maxLength = 120}) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }

  String _formatJson(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value?.toString() ?? 'null';
    }
  }

  void _showTransientMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

}
