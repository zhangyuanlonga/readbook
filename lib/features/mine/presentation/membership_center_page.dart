import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static final Uri _supportUri = Uri.parse(
    'https://qun.qq.com/universal-share/share?ac=1&authKey=Tabvg05EAafVbER7E8%2BzAQ18yErg2a%2B5PoqQH41t6dbPjcZIfDSnNX%2F4KCAXhzVh&busi_data=eyJncm91cENvZGUiOiIxMDgyODI3MjI0IiwidG9rZW4iOiIzam5tVFQ0cUs1T3VlMytzVk9iOXB1Zk40Q1RaUXJiQytzd2JlZUx3NDhXQTJscy9ZZGE5WW1hQXhPdGFwMHU1IiwidWluIjoiNzgyMDQ1MDExIn0%3D&data=PHNA5IOU4A3ujR5i9rmpWqWn4Qc-L9MNr8ByREa7IfvpXTo1utwnHVIfjkB7Rlk4x3yE9dfMR5_ZjOfsQ9wYcA&svctype=4&tempid=h5_group_info',
  );

  static const List<_MembershipFeatureItem> _featureItems = [
    _MembershipFeatureItem(
      icon: Icons.verified_outlined,
      title: '许可证激活开通',
      description: '通过许可证快速开通高级会员，无需反复切换到外部页面。',
    ),
    _MembershipFeatureItem(
      icon: Icons.devices_outlined,
      title: '设备席位管理',
      description: '查看当前已绑定的设备席位，必要时可释放旧设备授权。',
    ),
    _MembershipFeatureItem(
      icon: Icons.widgets_outlined,
      title: '会员功能与配额扩展',
      description: '按账号权益解锁对应模块能力和更高的使用额度。',
    ),
    _MembershipFeatureItem(
      icon: Icons.manage_accounts_outlined,
      title: '权益状态随时查看',
      description: '集中查看会员状态、来源、有效期与当前支持的功能。',
    ),
  ];

  final AuthSessionStore _sessionStore = AuthSessionStore();
  final MembershipService _membershipService = MembershipService();
  final TextEditingController _codeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  AuthSession? _session;
  MembershipEntitlement? _entitlement;
  MembershipSeatSyncResult? _seatSyncResult;
  List<MembershipDeviceSeat> _deviceSeats = const <MembershipDeviceSeat>[];
  bool _isLoading = true;
  bool _isRedeeming = false;
  String? _errorMessage;

  bool get _hasActiveMembership => _entitlement?.isActive ?? false;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final title = _hasActiveMembership ? '会员中心' : '高级会员';

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
          title: Text(title),
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
        bottomNavigationBar:
            _isLoading ? null : _buildBottomActionBar(context, bottomSafe),
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
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      12,
                      horizontal,
                      108 + bottomSafe,
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
      String? transientError;
      try {
        seatSyncResult = await _membershipService.syncCurrentDeviceSeat();
      } catch (error) {
        transientError =
            error is AppException ? error.briefMessage : '设备席位同步失败。';
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
        _errorMessage = transientError;
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

  Future<bool> _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage('请输入许可证码。');
      return false;
    }
    if (!await _ensureSignedIn()) {
      return false;
    }
    setState(() {
      _isRedeeming = true;
    });
    try {
      await _membershipService.redeemActivationCode(code);
      _codeController.clear();
      _showMessage('许可证兑换成功。');
      await _loadPage();
      return true;
    } catch (error) {
      _showMessage(error is AppException ? error.briefMessage : '许可证兑换失败。');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isRedeeming = false;
        });
      }
    }
  }

  Future<bool> _releaseSeat(MembershipDeviceSeat seat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('释放设备席位'),
          content: Text('确认释放设备 ${_seatDisplayLabel(seat)} 的会员席位吗？'),
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
      return false;
    }
    try {
      await _membershipService.releaseSeat(seat.id);
      _showMessage('设备席位已释放。');
      await _loadPage();
      return true;
    } catch (error) {
      _showMessage(error is AppException ? error.briefMessage : '释放设备席位失败。');
      return false;
    }
  }

  Future<bool> _ensureSignedIn() async {
    if (_session != null) {
      return true;
    }
    await context.push('/auth');
    await _loadPage();
    return _session != null;
  }

  Future<void> _handleActivateAction() async {
    if (!await _ensureSignedIn()) {
      return;
    }
    if (!mounted) {
      return;
    }
    await _showRedeemSheet();
  }

  Future<void> _handleManageAction() async {
    if (!await _ensureSignedIn()) {
      return;
    }
    if (!mounted) {
      return;
    }
    await _showManageSheet();
  }

  Future<void> _openSupport() async {
    final launched = await launchUrl(
      _supportUri,
      mode: LaunchMode.externalApplication,
    );
    if (launched || !mounted) {
      return;
    }
    _showMessage('跳转失败，请稍后重试。');
  }

  List<Widget> _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return [
        const SizedBox(height: 48),
        Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      ];
    }

    final widgets = <Widget>[
      if (_errorMessage != null && _errorMessage!.isNotEmpty)
        _buildMessageCard(context, _errorMessage!, isError: true),
    ];

    if (_session == null) {
      widgets.addAll([
        _buildHeroCard(context, loggedIn: false),
        const SizedBox(height: 16),
        _buildFeatureCard(context),
      ]);
      return widgets;
    }

    if (!_hasActiveMembership) {
      widgets.addAll([
        _buildHeroCard(context, loggedIn: true),
        const SizedBox(height: 16),
        _buildFeatureCard(context),
        const SizedBox(height: 16),
      ]);
    }

    widgets.addAll([_buildEntitlementCard(context)]);
    return widgets;
  }

  Widget _buildBottomActionBar(BuildContext context, double bottomSafe) {
    final primaryLabel = _hasActiveMembership ? '查看许可证激活' : '许可证激活';
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 8 + bottomSafe),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isRedeeming ? null : _handleActivateAction,
              child: Text(primaryLabel),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _isRedeeming ? null : _handleActivateAction,
                child: const Text('许可证激活'),
              ),
              TextButton(
                onPressed: _handleManageAction,
                child: const Text('管理许可证'),
              ),
              TextButton(onPressed: _openSupport, child: const Text('联系客服')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, {required bool loggedIn}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = const Color(0xFFB68A4D);
    final accentDeepColor = const Color(0xFF8D6730);
    final titleText = 'Selune PRO';
    final statusText = _hasActiveMembership ? '已开通' : '待开通';
    final headline =
        _hasActiveMembership
            ? '高级权益已生效，继续享受更完整的阅读体验'
            : loggedIn
            ? '解锁高级阅读功能，享受更完整的阅读体验'
            : '登录后激活许可证，解锁全部高级功能';
    final subtitle =
        _hasActiveMembership
            ? '当前账号可以继续管理许可证、设备席位和已开通权益。'
            : '支持通过许可证快速开通高级会员，并在同一页面完成许可证管理与客服联系。';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                accentColor.withValues(alpha: 0.16),
                colorScheme.surface,
              ),
              Color.alphaBlend(
                accentDeepColor.withValues(alpha: 0.1),
                colorScheme.surfaceContainerLow,
              ),
            ],
          ),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titleText,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                            letterSpacing: 0.45,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.diamond_outlined,
                          size: 16,
                          color: accentColor,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '高级会员',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accentDeepColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                headline,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaChip(
                    context,
                    Icons.confirmation_number_outlined,
                    '许可证开通',
                  ),
                  _buildMetaChip(context, Icons.devices_outlined, '设备授权管理'),
                  _buildMetaChip(context, Icons.auto_awesome_outlined, '高级功能'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '高级会员权益',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '通过更完整的阅读能力和许可证管理体验，把会员功能收在一个清晰、稳定、专注内容的高级阅读工作台里。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _hasActiveMembership
                    ? '当前已开通高级会员，以下能力已纳入当前账号权益。'
                    : '开通后可通过许可证激活使用以下高级能力。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._featureItems.map((item) => _buildFeatureItem(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, _MembershipFeatureItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = const Color(0xFFB68A4D);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntitlementCard(BuildContext context) {
    final entitlement = _entitlement;
    final colorScheme = Theme.of(context).colorScheme;
    final hasMembership = entitlement?.isActive ?? false;
    final activeEntitlement = hasMembership ? entitlement : null;
    final toneColor =
        hasMembership ? const Color(0xFFB68A4D) : colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: toneColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasMembership ? entitlement!.displayLevel : '未开通高级会员',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasMembership
                            ? '已开通 ${_describePlan(activeEntitlement!.planType)}，${_formatTime(activeEntitlement.expireAt)} 到期。'
                            : '当前账号还没有有效会员，可通过底部“许可证激活”输入许可证码完成开通。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildRedeemCard(
    BuildContext context, {
    required bool isRedeeming,
    required Future<void> Function() onRedeemPressed,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              '许可证激活',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '输入许可证码后可直接开通或续期高级会员。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '输入许可证码',
                hintText: '例如 LIC2026-ABCDEFGH',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: isRedeeming ? null : onRedeemPressed,
                child:
                    isRedeeming
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('立即激活'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatCard(
    BuildContext context, {
    required MembershipSeatSyncResult? seatSyncResult,
    required MembershipEntitlement? entitlement,
    required List<MembershipDeviceSeat> deviceSeats,
    required Future<void> Function(MembershipDeviceSeat seat) onReleaseSeat,
  }) {
    final theme = Theme.of(context);
    final activeCount =
        seatSyncResult?.activeDeviceCount ??
        deviceSeats.where((item) => item.isActive).length;
    final maxDevices =
        seatSyncResult?.maxDevices ?? (entitlement?.maxDevices ?? 1);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              '管理许可证',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaChip(
                  context,
                  Icons.devices_outlined,
                  '已绑定 $activeCount / $maxDevices',
                ),
                _buildMetaChip(context, Icons.key_outlined, '设备授权'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '这里可以查看当前许可证绑定的设备席位，并在需要时释放旧设备授权。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (seatSyncResult?.isOverLimit == true) ...[
              const SizedBox(height: 8),
              _buildMessageCard(context, '当前设备数已超上限，请先释放旧设备席位。', isError: true),
            ],
            const SizedBox(height: 12),
            if (deviceSeats.isEmpty)
              Text('暂无许可证设备记录。', style: theme.textTheme.bodyMedium)
            else
              ...deviceSeats.map(
                (seat) => _buildSeatTile(
                  context,
                  seat,
                  onRelease: () => onReleaseSeat(seat),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRedeemSheet() async {
    _codeController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        var isRedeeming = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> handleRedeem() async {
              setSheetState(() {
                isRedeeming = true;
              });
              final success = await _redeemCode();
              if (!context.mounted) {
                return;
              }
              setSheetState(() {
                isRedeeming = false;
              });
              if (success) {
                Navigator.of(context).pop();
              }
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: _buildRedeemCard(
                  context,
                  isRedeeming: isRedeeming,
                  onRedeemPressed: handleRedeem,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showManageSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        var deviceSeats = List<MembershipDeviceSeat>.of(_deviceSeats);
        var seatSyncResult = _seatSyncResult;
        var entitlement = _entitlement;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> handleRelease(MembershipDeviceSeat seat) async {
              final released = await _releaseSeat(seat);
              if (!released || !context.mounted) {
                return;
              }
              setSheetState(() {
                deviceSeats = List<MembershipDeviceSeat>.of(_deviceSeats);
                seatSyncResult = _seatSyncResult;
                entitlement = _entitlement;
              });
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: _buildSeatCard(
                  context,
                  seatSyncResult: seatSyncResult,
                  entitlement: entitlement,
                  deviceSeats: deviceSeats,
                  onReleaseSeat: handleRelease,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeatTile(
    BuildContext context,
    MembershipDeviceSeat seat, {
    required Future<void> Function() onRelease,
  }) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seat.isActive ? '已授权设备' : '历史设备记录',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _seatDisplayLabel(seat),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
            '设备标识：${_seatDisplayLabel(seat)}',
            style: theme.textTheme.bodySmall,
          ),
          if (seat.boundAt != null)
            Text(
              '绑定时间：${_formatTime(seat.boundAt)}',
              style: theme.textTheme.bodySmall,
            ),
          Text(
            '最近活跃：${_formatTime(seat.lastSeenAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if (seat.deviceUid?.isNotEmpty ?? false)
            Text(
              '设备编号：${_formatSeatSecondaryId(seat.deviceUid!)}',
              style: theme.textTheme.bodySmall,
            ),
          if (!seat.isActive && seat.releasedAt != null)
            Text(
              '释放时间：${_formatTime(seat.releasedAt)}',
              style: theme.textTheme.bodySmall,
            ),
          if (!seat.isActive &&
              seat.releaseReason != null &&
              seat.releaseReason!.trim().isNotEmpty)
            Text(
              '释放原因：${seat.releaseReason!.trim()}',
              style: theme.textTheme.bodySmall,
            ),
          if (seat.isActive) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRelease,
              icon: const Icon(Icons.link_off_outlined),
              label: const Text('释放席位'),
            ),
          ],
        ],
      ),
    );
  }

  String _seatDisplayLabel(MembershipDeviceSeat seat) {
    final raw = (seat.installId.isNotEmpty ? seat.installId : seat.id).trim();
    if (raw.isEmpty) {
      return '未命名设备';
    }
    if (raw.length <= 20) {
      return raw;
    }
    return '${raw.substring(0, 8)}...${raw.substring(raw.length - 6)}';
  }

  String _formatSeatSecondaryId(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return '-';
    }
    if (normalized.length <= 20) {
      return normalized;
    }
    return '${normalized.substring(0, 8)}...${normalized.substring(normalized.length - 6)}';
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

  Widget _buildMetaChip(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
        return '未开通 / 已过期';
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

class _MembershipFeatureItem {
  const _MembershipFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
