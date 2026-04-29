import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/sync_scope.dart';
import '../../domain/sync_job.dart';
import '../../domain/sync_profile.dart';
import '../../providers.dart';

class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _endpointController;
  late final TextEditingController _basePathController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _saving = false;
  bool _testingDraft = false;
  String? _runningProfileId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: '我的 WebDAV');
    _endpointController = TextEditingController();
    _basePathController = TextEditingController(text: 'selune-sync/v1');
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _endpointController.dispose();
    _basePathController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(syncScopeCatalogServiceProvider);
    final groups = catalog.buildGroups();
    final profilesAsync = ref.watch(syncProfilesProvider);
    final jobsAsync = ref.watch(syncJobsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('同步')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SectionCard(
            title: 'WebDAV 配置',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '配置名称'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _endpointController,
                  decoration: const InputDecoration(
                    labelText: '地址',
                    hintText: 'https://dav.example.com/webdav',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _basePathController,
                  decoration: const InputDecoration(
                    labelText: '根目录',
                    hintText: 'selune-sync/v1',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _handleSaveProfile,
                        child: Text(_saving ? '保存中…' : '保存本地配置'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _testingDraft ? null : _handleTestDraft,
                        child: Text(_testingDraft ? '测试中…' : '测试草稿连接'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '已保存配置',
            child: profilesAsync.when(
              data: (profiles) {
                if (profiles.isEmpty) {
                  return const Text('当前还没有已保存的同步配置。');
                }
                return Column(
                  children: [
                    for (final profile in profiles)
                      _SavedProfileTile(
                        profile: profile,
                        onTest: () => _handleTestSavedProfile(profile.id),
                        onSync: () => _handleRunStage4(profile.id),
                        isRunning: _runningProfileId == profile.id,
                      ),
                  ],
                );
              },
              error: (error, _) => Text('加载配置失败：$error'),
              loading: () => const _LoadingLine('正在加载配置…'),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '阶段状态',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _StatusLine('阶段 0：scope / dataset 命名已冻结'),
                _StatusLine('阶段 1：sync feature 骨架已落地'),
                _StatusLine('阶段 4：首批轻量 scope 已接入手动同步'),
                _StatusLine('阶段 5 / 6：配置、历史、书架组织已接入手动同步'),
                _StatusLine('后续阶段仍按执行计划推进'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '首批 Scope',
            child: Column(
              children: [
                for (final scope in catalog.firstBatchScopes)
                  _ScopeTile(scope: scope),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '最近任务',
            child: jobsAsync.when(
              data: (jobs) {
                if (jobs.isEmpty) {
                  return const Text('当前还没有同步任务记录。');
                }
                return Column(
                  children: [
                    for (final job in jobs.take(5)) _JobTile(job: job),
                  ],
                );
              },
              error: (error, _) => Text('加载任务失败：$error'),
              loading: () => const _LoadingLine('正在加载任务…'),
            ),
          ),
          const SizedBox(height: 12),
          for (final group in groups) ...[
            _SectionCard(
              title: group.title,
              child: Column(
                children: [
                  for (final scope in group.scopes) _ScopeTile(scope: scope),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.tonal(
            onPressed: () {
              context.push('/sync/history');
            },
            child: const Text('查看同步历史占位页'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveProfile() async {
    setState(() {
      _saving = true;
    });
    try {
      final catalog = ref.read(syncScopeCatalogServiceProvider);
      final profile = await ref
          .read(syncProfileServiceProvider)
          .saveProfile(
            name: _nameController.text,
            endpointUrl: _endpointController.text,
            basePath: _basePathController.text,
            username: _usernameController.text,
            password: _passwordController.text,
            enabledScopes: catalog.firstBatchScopes,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已保存配置：${profile.name}')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _handleTestDraft() async {
    setState(() {
      _testingDraft = true;
    });
    try {
      final result = await ref
          .read(syncConnectionServiceProvider)
          .testDraft(
            endpointUrl: _endpointController.text,
            basePath: _basePathController.text,
            username: _usernameController.text,
            password: _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('测试失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _testingDraft = false;
        });
      }
    }
  }

  Future<void> _handleTestSavedProfile(String profileId) async {
    final result = await ref
        .read(syncConnectionServiceProvider)
        .testProfileConnection(profileId);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _handleRunStage4(String profileId) async {
    setState(() {
      _runningProfileId = profileId;
    });
    try {
      final result = await ref.read(syncStage4ServiceProvider).run(profileId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('同步失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _runningProfileId = null;
        });
      }
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _SavedProfileTile extends StatelessWidget {
  const _SavedProfileTile({
    required this.profile,
    required this.onTest,
    required this.onSync,
    required this.isRunning,
  });

  final SyncProfile profile;
  final Future<void> Function() onTest;
  final Future<void> Function() onSync;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(profile.name),
      subtitle: Text('${profile.endpointUrl} · ${profile.basePath}'),
      trailing: Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () {
              unawaited(onTest());
            },
            child: const Text('测试连接'),
          ),
          FilledButton.tonal(
            onPressed:
                isRunning
                    ? null
                    : () {
                      unawaited(onSync());
                    },
            child: Text(isRunning ? '同步中…' : '执行同步'),
          ),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job});

  final SyncJob job;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(job.profileId),
      subtitle: Text('${job.status.name} · ${job.startedAt.toLocal()}'),
      trailing:
          job.status == SyncJobStatus.success
              ? const Icon(Icons.check_circle_outline)
              : job.status == SyncJobStatus.failed
              ? const Icon(Icons.error_outline)
              : const Icon(Icons.sync),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({required this.scope});

  final SyncScope scope;

  @override
  Widget build(BuildContext context) {
    final dependencies = scope.dependencies;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(scope.productLabel),
      subtitle: Text(
        dependencies.isEmpty
            ? 'dataset: ${scope.datasetFileName}'
            : 'dataset: ${scope.datasetFileName} · 依赖: ${dependencies.map((item) => item.name).join(', ')}',
      ),
      trailing:
          scope.isFirstBatch
              ? const Icon(Icons.bolt_rounded)
              : const Icon(Icons.chevron_right_rounded),
    );
  }
}
