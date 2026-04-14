import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/membership/membership_device_seat.dart';
import '../../../core/membership/membership_entitlement.dart';
import '../../../core/membership/membership_seat_sync_result.dart';
import '../../../core/membership/membership_service.dart';

class MembershipCenterPage extends StatefulWidget {
  const MembershipCenterPage({super.key});

  @override
  State<MembershipCenterPage> createState() => _MembershipCenterPageState();
}

class _MembershipCenterPageState extends State<MembershipCenterPage> {
  final AuthSessionStore _sessionStore = AuthSessionStore();
  final MembershipService _membershipService = MembershipService();
  final TextEditingController _codeController = TextEditingController();

  AuthSession? _session;
  MembershipEntitlement? _entitlement;
  MembershipSeatSyncResult? _seatSyncResult;
  List<MembershipDeviceSeat> _deviceSeats = const <MembershipDeviceSeat>[];
  bool _isLoading = true;
  bool _isRedeeming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('会员中心'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go('/mine');
            },
          ),
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.mineContentMaxWidth,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: RefreshIndicator(
                  onRefresh: _refreshPage,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      12,
                      horizontal,
                      16 + bottomSafe,
                    ),
                    children: _buildContent(context),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final session = await _sessionStore.getSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _entitlement = null;
      _seatSyncResult = null;
      _deviceSeats = const <MembershipDeviceSeat>[];
    });
    if (session == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    await _loadMembershipData();
  }

  Future<void> _refreshPage() async {
    await _loadPage();
  }

  Future<void> _loadMembershipData() async {
    try {
      MembershipSeatSyncResult? seatSyncResult;
      try {
        seatSyncResult = await _membershipService.syncCurrentDeviceSeat();
      } catch (error) {
        if (error is AppException) {
          _errorMessage = error.briefMessage;
        } else {
          _errorMessage = '设备席位同步失败。';
        }
      }

      final entitlement = await _membershipService.fetchEntitlement();
      final seats = await _membershipService.fetchDeviceSeats();
      if (!mounted) {
        return;
      }
      setState(() {
        _entitlement = entitlement;
        _seatSyncResult = seatSyncResult;
        _deviceSeats = seats;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage =
            error is AppException ? error.briefMessage : '会员信息加载失败。';
      });
    }
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage('请输入许可证码。');
      return;
    }
    setState(() {
      _isRedeeming = true;
    });
    try {
      await _membershipService.redeemActivationCode(code);
      _codeController.clear();
      _showMessage('许可证兑换成功。');
      await _loadPage();
    } catch (error) {
      _showMessage(error is AppException ? error.briefMessage : '许可证兑换失败。');
    } finally {
      if (mounted) {
        setState(() {
          _isRedeeming = false;
        });
      }
    }
  }

  Future<void> _releaseSeat(MembershipDeviceSeat seat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('释放设备席位'),
          content: Text('确认释放设备 ${seat.installId} 的会员席位吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('释放'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _membershipService.releaseSeat(seat.id);
      _showMessage('设备席位已释放。');
      await _loadPage();
    } catch (error) {
      _showMessage(error is AppException ? error.briefMessage : '释放设备席位失败。');
    }
  }

  List<Widget> _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return [
        const SizedBox(height: 48),
        Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      ];
    }

    if (_session == null) {
      return [
        const SizedBox(height: 12),
        Icon(
          Icons.workspace_premium_outlined,
          size: 36,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        Text(
          '登录后查看会员权益',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '登录后可兑换许可证、查看权益和管理设备席位。',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => context.push('/auth'),
          child: const Text('去登录'),
        ),
      ];
    }

    return [
      if (_errorMessage != null && _errorMessage!.isNotEmpty)
        _buildMessageCard(context, _errorMessage!, isError: true),
      _buildEntitlementCard(context),
      const SizedBox(height: 18),
      _buildRedeemCard(context),
      const SizedBox(height: 18),
      _buildSeatCard(context),
    ];
  }

  Widget _buildEntitlementCard(BuildContext context) {
    final entitlement = _entitlement;
    final colorScheme = Theme.of(context).colorScheme;
    final hasMembership = entitlement?.isActive ?? false;
    final activeEntitlement = hasMembership ? entitlement : null;
    final toneColor = hasMembership ? colorScheme.primary : colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: toneColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasMembership ? entitlement!.displayLevel : '未开通会员',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasMembership
                  ? '已开通 ${_describePlan(activeEntitlement!.planType)}，${_formatTime(activeEntitlement.expireAt)} 到期。'
                  : '当前账号还没有有效会员，可通过许可证开通。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              context,
              '会员状态',
              _describeStatus(entitlement?.vipStatus),
            ),
            _buildInfoRow(
              context,
              '权益来源',
              _describeSource(entitlement?.source),
            ),
            _buildInfoRow(context, '设备上限', '${entitlement?.maxDevices ?? 1} 台'),
            _buildInfoRow(
              context,
              '试用状态',
              entitlement?.isTrial == true ? '试用中' : '正式权益',
            ),
            if ((entitlement?.features ?? const <String>[]).isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entitlement!.features
                    .map(
                      (feature) => Chip(
                        label: Text(feature),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '许可证兑换',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '输入许可证码',
                hintText: '例如 LIC2026-ABCDEFGH',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isRedeeming ? null : _redeemCode,
              child:
                  _isRedeeming
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text('立即使用'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatCard(BuildContext context) {
    final seatSyncResult = _seatSyncResult;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设备席位',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              seatSyncResult == null
                  ? '当前已绑定 ${_deviceSeats.where((item) => item.isActive).length} 台设备。'
                  : '当前已绑定 ${seatSyncResult.activeDeviceCount} / ${seatSyncResult.maxDevices} 台设备。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (seatSyncResult?.isOverLimit == true) ...[
              const SizedBox(height: 8),
              _buildMessageCard(context, '当前设备数已超上限，请先释放旧设备席位。', isError: true),
            ],
            const SizedBox(height: 12),
            if (_deviceSeats.isEmpty)
              Text('暂无设备席位记录。', style: Theme.of(context).textTheme.bodyMedium)
            else
              ..._deviceSeats.map((seat) => _buildSeatTile(context, seat)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatTile(BuildContext context, MembershipDeviceSeat seat) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  seat.installId.isEmpty ? seat.id : seat.installId,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                seat.isActive ? '已占用' : '已释放',
                style: theme.textTheme.labelMedium?.copyWith(
                  color:
                      seat.isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '最近活跃：${_formatTime(seat.lastSeenAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if (seat.deviceUid?.isNotEmpty ?? false)
            Text('设备 UID：${seat.deviceUid}', style: theme.textTheme.bodySmall),
          if (seat.isActive) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _releaseSeat(seat),
              icon: const Icon(Icons.link_off_outlined),
              label: const Text('释放席位'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageCard(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    final theme = Theme.of(context);
    final color =
        isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isError
            ? theme.colorScheme.onErrorContainer
            : theme.colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _describePlan(String planType) {
    switch (planType) {
      case 'quarter':
        return '季卡';
      case 'year':
        return '年卡';
      case 'lifetime':
        return '终身';
      default:
        return '月卡';
    }
  }

  String _describeStatus(String? status) {
    switch (status) {
      case 'active':
        return '生效中';
      case 'revoked':
        return '已撤销';
      default:
        return '已过期';
    }
  }

  String _describeSource(String? source) {
    switch (source) {
      case 'activation_code':
        return '许可证';
      case 'trial':
        return '试用';
      case 'manual_grant':
        return '手工赠送';
      default:
        return '-';
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) {
      return '-';
    }
    final local = time.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
