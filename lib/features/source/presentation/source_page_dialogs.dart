part of 'source_page.dart';

class _SingleCheckFlowSheet extends StatefulWidget {
  const _SingleCheckFlowSheet({
    required this.sourceName,
    required this.helperText,
    required this.initialKeyword,
    required this.levelLabelBuilder,
    required this.statusLabelBuilder,
    required this.stepLabelBuilder,
    required this.onRun,
    required this.onCompleted,
  });

  final String sourceName;
  final String helperText;
  final String initialKeyword;
  final String Function(SourceCheckLevel level) levelLabelBuilder;
  final String Function(SourceCheckStatus status) statusLabelBuilder;
  final String Function(SourceCheckStep step) stepLabelBuilder;
  final Future<SourceCheckResult> Function(
    String keyword,
    SourceCheckLevel level,
  )
  onRun;
  final VoidCallback onCompleted;

  @override
  State<_SingleCheckFlowSheet> createState() => _SingleCheckFlowSheetState();
}

class _SingleCheckFlowSheetState extends State<_SingleCheckFlowSheet> {
  late final TextEditingController _controller;
  SourceCheckLevel _selectedLevel = SourceCheckLevel.searchOnly;
  SourceCheckResult? _result;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKeyword);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              _result == null ? '单源检测' : '检测结果 · ${widget.sourceName}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            if (_result == null) ...[
              TextField(
                controller: _controller,
                autofocus: appEnableAutoFocusForTextInput,
                decoration: const InputDecoration(
                  labelText: '检测关键词',
                  hintText: '留空时自动使用书源默认检测词',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SourceCheckLevel>(
                initialValue: _selectedLevel,
                decoration: const InputDecoration(
                  labelText: '检测级别',
                  border: OutlineInputBorder(),
                ),
                items: SourceCheckLevel.values
                    .map(
                      (level) => DropdownMenuItem<SourceCheckLevel>(
                        value: level,
                        child: Text(widget.levelLabelBuilder(level)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedLevel = value;
                  });
                },
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('状态：${widget.statusLabelBuilder(_result!.status)}'),
                    const SizedBox(height: 8),
                    Text('关键词：${_result!.usedKeyword}'),
                    const SizedBox(height: 8),
                    Text(
                      '级别：${widget.levelLabelBuilder(_result!.checkedLevel)}',
                    ),
                    const SizedBox(height: 8),
                    Text('步骤：${widget.stepLabelBuilder(_result!.stepReached)}'),
                    const SizedBox(height: 8),
                    Text('耗时：${_result!.duration.inMilliseconds} ms'),
                    const SizedBox(height: 10),
                    Text(
                      _result!.message,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_result == null ? '取消' : '关闭'),
                ),
                const Spacer(),
                if (_result == null)
                  FilledButton(
                    onPressed:
                        _isRunning
                            ? null
                            : () async {
                              setState(() {
                                _isRunning = true;
                              });
                              final result = await widget.onRun(
                                _controller.text.trim(),
                                _selectedLevel,
                              );
                              if (!mounted) {
                                return;
                              }
                              widget.onCompleted();
                              setState(() {
                                _result = result;
                                _isRunning = false;
                              });
                            },
                    child:
                        _isRunning
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('开始检测'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRequestDialog<T> extends StatefulWidget {
  const _CheckRequestDialog({
    required this.title,
    required this.helperText,
    required this.initialKeyword,
    required this.allowEmptyKeyword,
    required this.includeScope,
    required this.levelLabelBuilder,
    required this.scopeLabelBuilder,
    required this.onSubmit,
  });

  final String title;
  final String helperText;
  final String initialKeyword;
  final bool allowEmptyKeyword;
  final bool includeScope;
  final String Function(SourceCheckLevel level) levelLabelBuilder;
  final String Function(_BatchCheckScope scope) scopeLabelBuilder;
  final T Function(
    String keyword,
    SourceCheckLevel level,
    _BatchCheckScope scope,
  )
  onSubmit;

  @override
  State<_CheckRequestDialog<T>> createState() => _CheckRequestDialogState<T>();
}

class _CheckRequestDialogState<T> extends State<_CheckRequestDialog<T>> {
  late final TextEditingController _controller;
  SourceCheckLevel _selectedLevel = SourceCheckLevel.searchOnly;
  _BatchCheckScope _selectedScope = _BatchCheckScope.enabledSources;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKeyword);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.helperText),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: appEnableAutoFocusForTextInput,
            decoration: const InputDecoration(
              labelText: '检测关键词',
              hintText: '留空时自动使用书源默认检测词',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SourceCheckLevel>(
            initialValue: _selectedLevel,
            decoration: const InputDecoration(
              labelText: '检测级别',
              border: OutlineInputBorder(),
            ),
            items: SourceCheckLevel.values
                .map(
                  (level) => DropdownMenuItem<SourceCheckLevel>(
                    value: level,
                    child: Text(widget.levelLabelBuilder(level)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedLevel = value;
              });
            },
          ),
          if (widget.includeScope) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<_BatchCheckScope>(
              initialValue: _selectedScope,
              decoration: const InputDecoration(
                labelText: '检测范围',
                border: OutlineInputBorder(),
              ),
              items: _BatchCheckScope.values
                  .map(
                    (scope) => DropdownMenuItem<_BatchCheckScope>(
                      value: scope,
                      child: Text(widget.scopeLabelBuilder(scope)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedScope = value;
                });
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final keyword = _controller.text.trim();
            if (!widget.allowEmptyKeyword && keyword.isEmpty) {
              return;
            }
            Navigator.of(
              context,
            ).pop(widget.onSubmit(keyword, _selectedLevel, _selectedScope));
          },
          child: const Text('开始'),
        ),
      ],
    );
  }
}
