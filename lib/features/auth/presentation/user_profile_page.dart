import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/user/user_profile.dart';
import '../../../core/user/user_profile_service.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final AuthSessionStore _sessionStore = AuthSessionStore();
  final AuthService _authService = AuthService();
  final UserProfileService _userProfileService = UserProfileService();

  AuthSession? _session;
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isLoadingProfile = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await _sessionStore.getSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _isLoading = false;
    });
    if (session != null) {
      await _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingProfile = true;
    });
    try {
      final profile = await _userProfileService.fetchMe();
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
      });
    } catch (_) {
      // Keep the page available with local session data.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _refreshPage() async {
    final session = await _sessionStore.getSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      if (session == null) {
        _profile = null;
      }
    });
    if (session != null) {
      await _loadProfile();
    }
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
          title: const Text('账号信息'),
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
              maxWidth: AppLayout.systemSettingsContentMaxWidth,
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
                      20 + bottomSafe,
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

  List<Widget> _buildContent(BuildContext context) {
    final session = _session;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const [
        SizedBox(height: 64),
        Center(child: CircularProgressIndicator()),
      ];
    }

    if (session == null) {
      return [
        _buildGuestHero(context),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '登录后可查看',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '账号资料、注册时间、会员状态以及后续更多个人偏好入口都会集中在这里。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => context.push('/auth'),
                  child: const Text('去登录'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final profile = _profile;
    final displayName =
        profile?.username ?? session.username ?? session.userId ?? '用户';
    final userId = profile?.userId ?? session.userId ?? '-';
    final membershipLabel = _resolveMembershipLabel(profile);
    final membershipHint = _resolveMembershipHint(profile);

    return [
      _buildProfileHero(
        context,
        displayName: displayName,
        userId: userId,
        membershipLabel: membershipLabel,
        membershipHint: membershipHint,
      ),
      if (_isLoadingProfile)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '正在同步最新账号信息...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      const SizedBox(height: 14),
      _buildInfoCard(
        context,
        title: '个人资料',
        description: '账号的基础身份信息。',
        rows: [
          _ProfileRow(
            label: '用户名',
            value: profile?.username ?? session.username ?? '-',
          ),
          _ProfileRow(label: '用户 ID', value: userId),
          _ProfileRow(label: '注册时间', value: _formatTime(profile?.createdAt)),
        ],
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        context,
        title: '账号状态',
        description: '当前登录态与会员状态。',
        rows: [
          _ProfileRow(
            label: '会员状态',
            value: _describeVipStatus(profile?.vipStatus),
          ),
          _ProfileRow(
            label: '会员等级',
            value: _describeVipLevel(profile?.vipLevel),
          ),
          _ProfileRow(label: '会员到期', value: _formatTime(profile?.vipExpireAt)),
          _ProfileRow(
            label: 'Access 有效期',
            value: _formatTime(session.accessExpiresAt),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '账号操作',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '这里保留刷新和退出登录，后续可以继续扩展安全设置、设备管理等个人中心能力。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingProfile ? null : _refreshPage,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('刷新资料'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isLoggingOut ? null : _handleLogout,
                      icon:
                          _isLoggingOut
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.logout_rounded),
                      label: Text(_isLoggingOut ? '退出中...' : '退出登录'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildGuestHero(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.surface.withValues(alpha: 0.72),
            child: Icon(Icons.person_outline, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前未登录',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '登录后这里会变成更完整的个人资料页。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHero(
    BuildContext context, {
    required String displayName,
    required String userId,
    required String membershipLabel,
    required String membershipHint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = displayName.trim().isEmpty ? 'U' : displayName.trim()[0];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.84),
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $userId',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membershipLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  membershipHint,
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

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String description,
    required List<_ProfileRow> rows,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0)
                Divider(
                  height: 16,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[index].label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      rows[index].value,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _resolveMembershipLabel(UserProfile? profile) {
    final status = _describeVipStatus(profile?.vipStatus);
    final level = _describeVipLevel(profile?.vipLevel);
    if (level == '未开通' && status == '-') {
      return '普通账号';
    }
    return '$level · $status';
  }

  String _resolveMembershipHint(UserProfile? profile) {
    final expireAt = _formatTime(profile?.vipExpireAt);
    if (expireAt == '-') {
      return '当前未返回明确的会员到期时间，后续可在这里补齐更多权益说明。';
    }
    return '会员有效期至 $expireAt。后续可以继续把权益说明、续费入口和设备管理整合进来。';
  }

  String _describeVipLevel(String? raw) {
    final normalized = _normalizeEnumValue(raw);
    switch (normalized) {
      case '':
      case 'none':
        return '未开通';
      case 'basic':
        return '基础会员';
      case 'pro':
        return '专业会员';
      case 'vip':
        return 'VIP';
      case 'svip':
        return 'SVIP';
      case 'premium':
        return '高级会员';
      default:
        return raw!.trim();
    }
  }

  String _describeVipStatus(String? raw) {
    final normalized = _normalizeEnumValue(raw);
    switch (normalized) {
      case '':
        return '-';
      case 'active':
        return '生效中';
      case 'inactive':
        return '未开通';
      case 'expired':
        return '已过期';
      case 'pending':
        return '待生效';
      case 'cancelled':
      case 'canceled':
        return '已取消';
      case 'suspended':
        return '已暂停';
      default:
        return raw!.trim();
    }
  }

  String _normalizeEnumValue(String? raw) {
    return raw?.trim().toLowerCase() ?? '';
  }

  String _formatTime(DateTime? time) {
    if (time == null) {
      return '-';
    }
    final local = time.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} ${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) {
    return value.toString().padLeft(2, '0');
  }

  Future<void> _handleLogout() async {
    if (_session == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('退出登录'),
            content: const Text('确定要退出当前账号吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('退出'),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();
      if (!mounted) {
        return;
      }
      _session = null;
      _profile = null;
      context.go('/mine');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('退出失败，请稍后再试。')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }
}

class _ProfileRow {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;
}
