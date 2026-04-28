import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../source/debug_service/source_debug_web_service.dart';
import '../application/advanced_theme_provider.dart';
import '../../source/providers.dart';

class SourceDebugServicePage extends ConsumerStatefulWidget {
  const SourceDebugServicePage({super.key});

  @override
  ConsumerState<SourceDebugServicePage> createState() =>
      _SourceDebugServicePageState();
}

class _SourceDebugServicePageState
    extends ConsumerState<SourceDebugServicePage> {
  late final SourceDebugWebService _service;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _service = ref.read(sourceDebugWebServiceProvider);
    _service.addListener(_handleServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_handleServiceChanged);
    super.dispose();
  }

  void _handleServiceChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _toggleService() async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      if (_service.isRunning) {
        await _service.stop();
        _showMessage('网页调试服务已关闭。');
      } else {
        await _service.start();
        _showMessage('网页调试服务已启动。');
      }
    } catch (error) {
      _showMessage('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _refreshAddresses() async {
    if (_isBusy || !_service.isRunning) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await _service.refreshAdvertisedBaseUrls();
      _showMessage('地址列表已刷新。');
    } catch (error) {
      _showMessage('刷新地址失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('$label已复制。');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final busy = _isBusy || _service.isStarting || _service.isStopping;
    final isRunning = _service.isRunning;
    final addresses = _service.advertisedBaseUrls;
    final startedAt = _service.startedAt;
    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('网页调试服务'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        body: DecoratedBox(
          decoration: buildAdvancedThemeBackdropDecoration(backdrop),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: AppLayout.settingsContentMaxWidth,
                ),
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  topInset + 12,
                  horizontal,
                  16 + bottomSafe,
                ),
                children: [
                  _buildHeroCard(context, isRunning: isRunning),
                  const SizedBox(height: 12),
                  _buildStatusCard(
                    context,
                    isRunning: isRunning,
                    busy: busy,
                    startedAt: startedAt,
                  ),
                  const SizedBox(height: 12),
                  _buildAddressCard(
                    context,
                    busy: busy,
                    isRunning: isRunning,
                    addresses: addresses,
                  ),
                  if ((_service.lastErrorText ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildErrorCard(context, _service.lastErrorText!.trim()),
                  ],
                  const SizedBox(height: 12),
                  _buildApiCard(context, isRunning: isRunning, addresses: addresses),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            onPressed: busy ? null : _toggleService,
            icon: Icon(
              isRunning ? Icons.stop_circle_outlined : Icons.play_circle_outline,
            ),
            label: Text(
              busy
                  ? '处理中...'
                  : isRunning
                  ? '关闭网页调试服务'
                  : '开启网页调试服务',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, {required bool isRunning}) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusText = isRunning ? '局域网调试已开启' : '局域网调试未开启';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colorScheme.primary.withValues(alpha: 0.18),
            colorScheme.surfaceContainerLow,
            colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lan_outlined, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '书源网页调试服务',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '用于让同网段内的网站调试台直接连接当前 App，先打通阶段 A 的服务开关、地址展示和 ping 接口。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _buildChip(context, statusText),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required bool isRunning,
    required bool busy,
    required DateTime? startedAt,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = <({String label, String value})>[
      (
        label: '运行状态',
        value: busy
            ? '处理中'
            : isRunning
            ? '运行中'
            : '未启动',
      ),
      (
        label: '默认端口',
        value: SourceDebugWebService.defaultPort.toString(),
      ),
      (
        label: '当前端口',
        value: _service.port?.toString() ?? '--',
      ),
      (
        label: '启动时间',
        value:
            startedAt == null
                ? '--'
                : startedAt
                    .toLocal()
                    .toString()
                    .replaceFirst('T', ' ')
                    .split('.')
                    .first,
      ),
    ];

    return _buildCardShell(
      context,
      title: '服务状态',
      trailing: TextButton.icon(
        onPressed: !isRunning || busy ? null : _refreshAddresses,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('刷新地址'),
      ),
      child: Column(
        children: [
          for (final row in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  row.value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (row != rows.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context, {
    required bool busy,
    required bool isRunning,
    required List<String> addresses,
  }) {
    return _buildCardShell(
      context,
      title: '可访问地址',
      subtitle: '网站调试台中填写这里的任一地址即可。局域网调试请优先使用 `192.168.x.x` 一类地址。',
      child:
          !isRunning
              ? _buildHintText(context, '服务尚未启动，开启后这里会显示当前可访问地址。')
              : addresses.isEmpty
              ? _buildHintText(context, '正在收集网络地址，请稍后刷新。')
              : Column(
                children: [
                  for (final String url in addresses) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              url,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: '复制地址',
                            onPressed: busy ? null : () => _copy(url, '地址'),
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ],
                      ),
                    ),
                    if (url != addresses.last) const SizedBox(height: 10),
                  ],
                ],
              ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String errorText) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近错误',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            errorText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onErrorContainer,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiCard(
    BuildContext context, {
    required bool isRunning,
    required List<String> addresses,
  }) {
    final sampleBase = addresses.isNotEmpty
        ? addresses.first
        : 'http://192.168.1.23:${SourceDebugWebService.defaultPort}';
    final sampleUrl = '$sampleBase/api/debug/ping';
    return _buildCardShell(
      context,
      title: '当前阶段能力',
      subtitle: '阶段 A 先只开放 `ping`，后续阶段再逐步补齐书源 CRUD 与调试接口。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHintText(
            context,
            isRunning
                ? '你现在可以在网页调试台里填写上方地址，并调用 `GET /api/debug/ping` 测试连接。'
                : '先开启服务，再用网站调试台连接当前 App。',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              sampleUrl,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'SF Mono',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _copy(sampleUrl, 'Ping 地址'),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('复制 Ping 地址'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardShell(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildHintText(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.45,
      ),
    );
  }
}
