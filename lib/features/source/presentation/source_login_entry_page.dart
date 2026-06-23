import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/feature_disabled_page.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../application/source_runtime_session_service.dart';
import '../routes.dart';
import 'source_login_ui_form.dart';

class SourceLoginEntryPage extends ConsumerStatefulWidget {
  const SourceLoginEntryPage({
    super.key,
    required this.sourceId,
    this.sourceName,
  });

  final String sourceId;
  final String? sourceName;

  @override
  ConsumerState<SourceLoginEntryPage> createState() =>
      _SourceLoginEntryPageState();
}

class _SourceLoginEntryPageState extends ConsumerState<SourceLoginEntryPage> {
  SourceLoginTask? _task;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTask());
  }

  Future<void> _loadTask() async {
    final sourceId = widget.sourceId.trim();
    if (sourceId.isEmpty) {
      setState(() => _error = '缺少书源标识，无法打开登录入口。');
      return;
    }
    try {
      final task = await ref
          .read(sourceRuntimeSessionServiceProvider)
          .createLoginTask(sourceId: sourceId);
      if (!mounted) return;
      setState(() => _task = task);
      if (task.hasWebViewLogin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.replace(
            sourceWebViewLoginLocation(
              sourceId: sourceId,
              sourceName:
                  task.sourceName.trim().isNotEmpty
                      ? task.sourceName
                      : widget.sourceName,
            ),
          );
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _title;
    final error = _error;
    if (error != null) {
      return FeatureDisabledPage(
        title: title,
        message: '获取书源登录任务失败：$error',
        icon: Icons.error_outline_rounded,
        actionLabel: '返回',
        onAction: () {
          if (context.canPop()) {
            context.pop(false);
          }
        },
      );
    }

    final task = _task;
    if (task == null || task.hasWebViewLogin) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(
          child: AppProgressIndicator(semanticLabel: '正在准备书源登录'),
        ),
      );
    }

    if (task.hasLoginUi) {
      return SourceLoginUiForm(sourceId: widget.sourceId, task: task);
    }

    return FeatureDisabledPage(
      title: title,
      message: '该书源暂未提供可用的 WebView 登录地址或 loginUi 表单。',
      icon: Icons.login_rounded,
      actionLabel: '返回',
      onAction: () {
        if (context.canPop()) {
          context.pop(false);
        }
      },
    );
  }

  String get _title {
    final taskName = _task?.sourceName.trim();
    if (taskName != null && taskName.isNotEmpty) {
      return '$taskName 登录';
    }
    final name = widget.sourceName?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name 登录';
    }
    return '书源登录';
  }
}
