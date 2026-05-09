import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/layout/app_layout.dart';
import '../../../../app/widgets/app_empty_state_card.dart';
import '../../../../app/widgets/app_status_state_card.dart';
import '../../application/sync_scope_catalog_service.dart';
import '../../domain/sync_scope.dart';
import '../../domain/sync_job.dart';
import '../../domain/sync_profile.dart';
import '../../providers.dart';

enum _SyncPanel { account, content, history }

class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _endpointController;
  late final TextEditingController _basePathController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _saving = false;
  bool _testingDraft = false;
  String? _runningProfileId;
  late Set<SyncScope> _selectedScopes;
  bool _autoSyncEnabled = false;
  _SyncPanel _activePanel = _SyncPanel.account;
  late final Set<String> _expandedGroupTitles;
  late final AnimationController _syncButtonController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: '我的 WebDAV');
    _endpointController = TextEditingController();
    _basePathController = TextEditingController(text: 'selune-sync/v1');
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _selectedScopes = <SyncScope>{
      ...ref.read(syncScopeCatalogServiceProvider).firstBatchScopes,
    };
    _expandedGroupTitles = <String>{'核心阅读资产', '会员外观'};
    _syncButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _endpointController.dispose();
    _basePathController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _syncButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(syncScopeCatalogServiceProvider);
    final groups = catalog.buildGroups();
    final selectableGroups = groups
        .where((group) => group.title != '明确排除')
        .toList(growable: false);
    final metrics = AppAdaptiveMetrics.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('同步中心')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.pageContentMaxWidth(context, maxWidth: 760),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.pagePadding,
              metrics.contentGap,
              metrics.pagePadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SegmentedButton<_SyncPanel>(
                      segments: const [
                        ButtonSegment<_SyncPanel>(
                          value: _SyncPanel.account,
                          icon: Icon(Icons.cloud_outlined),
                          label: Text('连接 / 账号'),
                        ),
                        ButtonSegment<_SyncPanel>(
                          value: _SyncPanel.content,
                          icon: Icon(Icons.tune_rounded),
                          label: Text('同步内容'),
                        ),
                        ButtonSegment<_SyncPanel>(
                          value: _SyncPanel.history,
                          icon: Icon(Icons.history_rounded),
                          label: Text('同步历史'),
                        ),
                      ],
                      selected: <_SyncPanel>{_activePanel},
                      onSelectionChanged: (selection) {
                        if (selection.isEmpty) {
                          return;
                        }
                        setState(() {
                          _activePanel = selection.first;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: metrics.contentGap),
                Consumer(
                  builder: (context, ref, _) {
                    final profilesAsync = ref.watch(syncProfilesProvider);
                    final savedProfiles =
                        profilesAsync.valueOrNull ?? const <SyncProfile>[];
                    final primaryProfile =
                        savedProfiles.isEmpty ? null : savedProfiles.first;
                    return _SyncHeroButton(
                      controller: _syncButtonController,
                      profile: primaryProfile,
                      isRunning: _runningProfileId != null,
                      onPressed:
                          primaryProfile == null
                              ? null
                              : () => _handleRunStage4(primaryProfile.id),
                    );
                  },
                ),
                SizedBox(height: metrics.contentGap),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_activePanel) {
                      _SyncPanel.account => _buildAccountPanel(context),
                      _SyncPanel.content => _buildContentPanel(
                        context,
                        catalog: catalog,
                        selectableGroups: selectableGroups,
                      ),
                      _SyncPanel.history => _buildHistoryPanel(context),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountPanel(BuildContext context) {
    final profilesAsync = ref.watch(syncProfilesProvider);
    return ListView(
      key: const ValueKey<String>('account'),
      padding: EdgeInsets.only(
        bottom:
            AppAdaptiveMetrics.of(context).sectionGap +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        _SectionCard(
          title: 'WebDAV 连接',
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开启自动同步'),
                subtitle: const Text('应用尝试自动同步。'),
                value: _autoSyncEnabled,
                onChanged: (value) {
                  setState(() {
                    _autoSyncEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 420;
                  final children = [
                    FilledButton(
                      onPressed: _saving ? null : _handleSaveProfile,
                      child: Text(_saving ? '保存中…' : '保存配置'),
                    ),
                    FilledButton.tonal(
                      onPressed: _testingDraft ? null : _handleTestDraft,
                      child: Text(_testingDraft ? '测试中…' : '测试连接'),
                    ),
                  ];
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        children[0],
                        SizedBox(
                          height: AppAdaptiveMetrics.of(context).contentGap,
                        ),
                        children[1],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: children[0]),
                      SizedBox(
                        width: AppAdaptiveMetrics.of(context).contentGap,
                      ),
                      Expanded(child: children[1]),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: AppAdaptiveMetrics.of(context).contentGap),
        _SectionCard(
          title: '已保存配置',
          child: profilesAsync.when(
            data: (profiles) {
              if (profiles.isEmpty) {
                return const AppEmptyStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: '还没有已保存配置',
                  description: '完成一次配置保存后，这里会显示可直接复用的同步配置。',
                  compact: true,
                );
              }
              return Column(
                children: [
                  for (final profile in profiles)
                    _SavedProfileTile(
                      profile: profile,
                      onTest: () => _handleTestSavedProfile(profile.id),
                      onSync: () => _handleRunStage4(profile.id),
                      onDelete: () => _handleDeleteProfile(profile.id),
                      isRunning: _runningProfileId == profile.id,
                    ),
                ],
              );
            },
            error:
                (error, _) => AppStatusStateCard(
                  icon: Icons.error_outline_rounded,
                  title: '加载配置失败',
                  message: '$error',
                  tone: AppStatusStateTone.error,
                  compact: true,
                ),
            loading: () => const _LoadingLine('正在加载配置…'),
          ),
        ),
      ],
    );
  }

  Widget _buildContentPanel(
    BuildContext context, {
    required SyncScopeCatalogService catalog,
    required List<SyncScopeCatalogGroup> selectableGroups,
  }) {
    final selectedCount = _selectedScopes.length;
    return ListView(
      key: const ValueKey<String>('content'),
      padding: EdgeInsets.only(
        bottom:
            AppAdaptiveMetrics.of(context).sectionGap +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        _SectionCard(
          title: '同步内容',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '可勾选需要同步的项目进行同步操作',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '当前已选 $selectedCount 项',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
        SizedBox(height: AppAdaptiveMetrics.of(context).contentGap),
        for (final group in selectableGroups) ...[
          _ScopeGroupCard(
            title: group.title,
            scopes: group.scopes,
            expanded: _expandedGroupTitles.contains(group.title),
            selectedScopes: _selectedScopes,
            onToggleExpanded: () => _toggleGroupExpanded(group.title),
            onToggleScope: _toggleScope,
            onToggleGroup: () => _toggleScopeGroup(group.scopes),
            description: _groupDescription(group.title),
          ),
          SizedBox(height: AppAdaptiveMetrics.of(context).contentGap),
        ],
      ],
    );
  }

  String _groupDescription(String title) {
    return switch (title) {
      '核心阅读资产' => '书架、阅读记录、书签、书源和资料编辑等核心内容。',
      '会员外观' => '高级主题配置和资源类内容。',
      '应用与阅读偏好' => '阅读器设置、导航、Mine 页偏好和历史记录等。',
      '资源扩展' => '图集、字体和外观资源库。',
      '延后评估' => '当前默认不优先同步，但保留后续评估空间。',
      _ => '展开后查看具体同步项。',
    };
  }

  void _toggleGroupExpanded(String title) {
    setState(() {
      final next = <String>{..._expandedGroupTitles};
      if (next.contains(title)) {
        next.remove(title);
      } else {
        next.add(title);
      }
      _expandedGroupTitles
        ..clear()
        ..addAll(next);
    });
  }

  void _toggleScopeGroup(List<SyncScope> scopes) {
    setState(() {
      final next = <SyncScope>{..._selectedScopes};
      final allSelected = scopes.every(next.contains);
      if (allSelected) {
        for (final scope in scopes) {
          next.remove(scope);
        }
      } else {
        for (final scope in scopes) {
          next.add(scope);
          next.addAll(scope.dependencies);
          final companion = scope.suggestedCompanionScope;
          if (companion != null) {
            next.add(companion);
          }
        }
      }
      _selectedScopes = next;
    });
  }

  Widget _buildHistoryPanel(BuildContext context) {
    final jobsAsync = ref.watch(syncJobsProvider);
    return ListView(
      key: const ValueKey<String>('history'),
      padding: EdgeInsets.only(
        bottom:
            AppAdaptiveMetrics.of(context).sectionGap +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        _SectionCard(
          title: '最近同步任务',
          child: jobsAsync.when(
            data: (jobs) {
              if (jobs.isEmpty) {
                return const AppEmptyStateCard(
                  icon: Icons.history_toggle_off_rounded,
                  title: '还没有同步任务记录',
                  description: '执行过同步任务后，这里会展示最近的同步历史。',
                  compact: true,
                );
              }
              return Column(
                children: [for (final job in jobs.take(8)) _JobTile(job: job)],
              );
            },
            error:
                (error, _) => AppStatusStateCard(
                  icon: Icons.error_outline_rounded,
                  title: '加载任务失败',
                  message: '$error',
                  tone: AppStatusStateTone.error,
                  compact: true,
                ),
            loading: () => const _LoadingLine('正在加载任务…'),
          ),
        ),
        SizedBox(height: AppAdaptiveMetrics.of(context).contentGap),
        FilledButton.tonal(
          onPressed: () {
            context.push('/sync/history');
          },
          child: const Text('查看完整同步历史'),
        ),
      ],
    );
  }

  Future<void> _handleSaveProfile() async {
    setState(() {
      _saving = true;
    });
    try {
      final profile = await ref
          .read(syncProfileServiceProvider)
          .saveProfile(
            name: _nameController.text,
            endpointUrl: _endpointController.text,
            basePath: _basePathController.text,
            username: _usernameController.text,
            password: _passwordController.text,
            enabledScopes: _selectedScopes.toList(growable: false),
            isAutoSyncEnabled: _autoSyncEnabled,
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
    _syncButtonController
      ..reset()
      ..repeat();
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
      _syncButtonController
        ..stop()
        ..reset();
      if (mounted) {
        setState(() {
          _runningProfileId = null;
        });
      }
    }
  }

  Future<void> _handleDeleteProfile(String profileId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除配置'),
          content: const Text('删除后需要重新填写连接信息，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(syncProfileServiceProvider).deleteProfile(profileId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除配置')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }

  void _toggleScope(SyncScope scope) {
    setState(() {
      final next = <SyncScope>{..._selectedScopes};
      if (next.contains(scope)) {
        next.remove(scope);
        for (final item in SyncScope.values) {
          if (item.dependencies.contains(scope)) {
            next.remove(item);
          }
        }
      } else {
        next.add(scope);
        next.addAll(scope.dependencies);
        final companion = scope.suggestedCompanionScope;
        if (companion != null) {
          next.add(companion);
        }
      }
      _selectedScopes = next;
    });
  }
}

class _SyncHeroButton extends StatelessWidget {
  const _SyncHeroButton({
    required this.controller,
    required this.profile,
    required this.isRunning,
    required this.onPressed,
  });

  final AnimationController controller;
  final SyncProfile? profile;
  final bool isRunning;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final hasProfile = profile != null;
    final buttonLabel = switch ((hasProfile, isRunning)) {
      (false, _) => '先保存一个同步配置',
      (true, true) => '同步进行中',
      (true, false) => '立即同步',
    };
    final subLabel = hasProfile ? '点击后即可同步内容' : '保存配置即可使用同步功能';

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        final glowScale = 0.94 + (0.08 * (0.5 - (t - 0.5).abs()) * 2);
        final sheenOffset = (t * 1.8) - 0.9;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: isRunning ? 1.0 : glowScale,
              child: Container(
                height: metrics.isCompactDensity ? 96 : 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(metrics.cardRadius + 10),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.16),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(metrics.cardRadius + 10),
                onTap:
                    onPressed == null
                        ? null
                        : () {
                          unawaited(onPressed!());
                        },
                child: Ink(
                  height: metrics.isCompactDensity ? 96 : 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      metrics.cardRadius + 10,
                    ),
                    gradient: LinearGradient(
                      colors:
                          hasProfile
                              ? <Color>[
                                colorScheme.primary,
                                Color.lerp(
                                      colorScheme.primary,
                                      colorScheme.tertiary,
                                      0.45,
                                    ) ??
                                    colorScheme.primary,
                                colorScheme.tertiary,
                              ]
                              : <Color>[
                                colorScheme.surfaceContainerHighest,
                                colorScheme.surfaceContainer,
                              ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color:
                          hasProfile
                              ? Colors.white.withValues(alpha: 0.18)
                              : colorScheme.outlineVariant.withValues(
                                alpha: 0.45,
                              ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      metrics.cardRadius + 10,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left:
                              (MediaQuery.sizeOf(context).width * sheenOffset) -
                              90,
                          top: -20,
                          bottom: -20,
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: -0.22,
                              child: Container(
                                width: 92,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(alpha: 0.18),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: hasProfile ? 0.16 : 0.65,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child:
                                      isRunning
                                          ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                          : Icon(
                                            hasProfile
                                                ? Icons.sync_rounded
                                                : Icons.settings_rounded,
                                            size: 28,
                                            color:
                                                hasProfile
                                                    ? Colors.white
                                                    : colorScheme.onSurface,
                                          ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      buttonLabel,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(
                                        color:
                                            hasProfile
                                                ? Colors.white
                                                : colorScheme.onSurface,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subLabel,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color:
                                            hasProfile
                                                ? Colors.white.withValues(
                                                  alpha: 0.88,
                                                )
                                                : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color:
                                    hasProfile
                                        ? Colors.white
                                        : colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(metrics.cardRadius + 4),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: metrics.contentGap),
            child,
          ],
        ),
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
    required this.onDelete,
    required this.isRunning,
  });

  final SyncProfile profile;
  final Future<void> Function() onTest;
  final Future<void> Function() onSync;
  final Future<void> Function() onDelete;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(profile.name),
      subtitle: Text('${profile.endpointUrl} · ${profile.basePath}'),
      trailing: PopupMenuButton<_ProfileAction>(
        onSelected: (action) {
          switch (action) {
            case _ProfileAction.test:
              unawaited(onTest());
            case _ProfileAction.sync:
              if (!isRunning) {
                unawaited(onSync());
              }
            case _ProfileAction.delete:
              unawaited(onDelete());
          }
        },
        itemBuilder:
            (context) => [
              const PopupMenuItem(
                value: _ProfileAction.test,
                child: Text('测试连接'),
              ),
              PopupMenuItem(
                value: _ProfileAction.sync,
                enabled: !isRunning,
                child: Text(isRunning ? '同步中…' : '执行同步'),
              ),
              const PopupMenuItem(
                value: _ProfileAction.delete,
                child: Text('删除配置'),
              ),
            ],
        child: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}

class _ScopeGroupCard extends StatelessWidget {
  const _ScopeGroupCard({
    required this.title,
    required this.scopes,
    required this.expanded,
    required this.selectedScopes,
    required this.onToggleExpanded,
    required this.onToggleScope,
    required this.onToggleGroup,
    required this.description,
  });

  final String title;
  final List<SyncScope> scopes;
  final bool expanded;
  final Set<SyncScope> selectedScopes;
  final VoidCallback onToggleExpanded;
  final void Function(SyncScope scope) onToggleScope;
  final VoidCallback onToggleGroup;
  final String description;

  @override
  Widget build(BuildContext context) {
    final selectedCount = scopes.where(selectedScopes.contains).length;
    final allSelected = selectedCount == scopes.length && scopes.isNotEmpty;
    final partiallySelected =
        selectedCount > 0 && selectedCount < scopes.length;
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(metrics.cardRadius + 4),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.cardPadding,
              metrics.contentGap,
              metrics.cardPadding,
              metrics.contentGap * 0.6,
            ),
            child: Row(
              children: [
                _CategoryToggle(
                  selected: allSelected,
                  partial: partiallySelected,
                  onTap: onToggleGroup,
                ),
                SizedBox(width: metrics.contentGap),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onToggleExpanded,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: metrics.contentGap * 0.4),
                          Text(
                            '$description\n已选 $selectedCount / ${scopes.length}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    expanded
                        ? Icons.unfold_less_rounded
                        : Icons.unfold_more_rounded,
                  ),
                  tooltip: expanded ? '收起' : '展开',
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.cardPadding,
                0,
                metrics.cardPadding,
                metrics.cardPadding,
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  SizedBox(height: metrics.contentGap * 0.8),
                  for (final scope in scopes)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        checkboxShape: const StadiumBorder(),
                        value: selectedScopes.contains(scope),
                        secondary: Icon(
                          selectedScopes.contains(scope)
                              ? Icons.task_alt_rounded
                              : Icons.radio_button_unchecked_rounded,
                        ),
                        title: Text(scope.productLabel),
                        subtitle: Text(
                          scope.dependencies.isEmpty
                              ? 'dataset: ${scope.datasetFileName}'
                              : '依赖: ${scope.dependencies.map((item) => item.name).join(', ')}',
                        ),
                        onChanged: (_) => onToggleScope(scope),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProfileAction { test, sync, delete }

class _CategoryToggle extends StatelessWidget {
  const _CategoryToggle({
    required this.selected,
    required this.partial,
    required this.onTap,
  });

  final bool selected;
  final bool partial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = selected || partial;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color:
              active
                  ? colorScheme.primary.withValues(alpha: 0.14)
                  : colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                active
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.7),
            width: active ? 1.4 : 1,
          ),
        ),
        child: Center(
          child: Icon(
            selected
                ? Icons.check_rounded
                : partial
                ? Icons.remove_rounded
                : Icons.circle_outlined,
            size: selected || partial ? 16 : 12,
            color: active ? colorScheme.primary : colorScheme.outline,
          ),
        ),
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
