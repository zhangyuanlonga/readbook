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
      // Keep the current page usable with locally cached session data.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
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
                    16 + bottomSafe,
                  ),
                  children: _buildContent(context),
                ),
              ),
            ),
          );
        },
      ),
    );
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

  List<Widget> _buildContent(BuildContext context) {
    final session = _session;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return [
        const SizedBox(height: 40),
        Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      ];
    }

    if (session == null) {
      return [
        const SizedBox(height: 12),
        Icon(
          Icons.person_off_outlined,
          size: 34,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        Text(
          '当前未登录',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '登录后可同步阅读进度，并查看账号与会员状态。',
          textAlign: TextAlign.center,
          style: _sectionDescriptionTextStyle(context),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.push('/auth'),
          child: const Text('去登录'),
        ),
      ];
    }

    final profile = _profile;
    final displayName =
        profile?.username ?? session.username ?? session.userId ?? '用户';
    final roleText = profile?.role ?? 'user';
    final featureList = profile?.features ?? const <String>[];

    return [
      _buildAccountHero(context, displayName: displayName, roleText: roleText),
      if (_isLoadingProfile) ...[
        const SizedBox(height: 10),
        Text('正在同步最新账号资料...', style: _sectionDescriptionTextStyle(context)),
      ],
      const SizedBox(height: 22),
      _buildSection(
        context,
        title: '账号资料',
        description: '当前登录账号与基础信息。',
        child: _buildListBlock(
          context,
          children: [
            _buildListRow(
              context,
              label: '用户名',
              value: profile?.username ?? session.username ?? '-',
            ),
            _buildListRow(context, label: '角色', value: roleText),
            _buildListRow(
              context,
              label: '注册时间',
              value: _formatTime(profile?.createdAt),
            ),
          ],
        ),
      ),
      if (_hasMembershipInfo(profile)) ...[
        const SizedBox(height: 22),
        _buildSection(
          context,
          title: '会员状态',
          description: '当前账号已开通的会员信息。',
          child: _buildListBlock(
            context,
            children: [
              _buildListRow(
                context,
                label: 'VIP 等级',
                value: profile?.vipLevel ?? '-',
              ),
              _buildListRow(
                context,
                label: '会员计划',
                value: profile?.planType ?? '-',
              ),
              _buildListRow(
                context,
                label: '会员状态',
                value: profile?.vipStatus ?? '-',
              ),
              _buildListRow(
                context,
                label: '会员到期',
                value: _formatTime(profile?.vipExpireAt),
              ),
            ],
          ),
        ),
      ],
      if (featureList.isNotEmpty) ...[
        const SizedBox(height: 22),
        _buildSection(
          context,
          title: '已开通功能',
          description: '当前账号可用的功能能力。',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: featureList
                .map(
                  (feature) => Chip(
                    label: Text(feature),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
      const SizedBox(height: 24),
      FilledButton.icon(
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
    ];
  }

  Widget _buildAccountHero(
    BuildContext context, {
    required String displayName,
    required String roleText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.person_outline,
            color: colorScheme.onPrimaryContainer,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '当前角色：$roleText',
                style: _sectionDescriptionTextStyle(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String description,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _sectionTitleTextStyle(context)),
        const SizedBox(height: 4),
        Text(description, style: _sectionDescriptionTextStyle(context)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildListBlock(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = colorScheme.outlineVariant.withValues(alpha: 0.55);

    return Column(
      children: [
        Container(height: 1, color: dividerColor),
        for (final child in children) ...[
          child,
          Container(height: 1, color: dividerColor),
        ],
      ],
    );
  }

  Widget _buildListRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasMembershipInfo(UserProfile? profile) {
    return profile?.vipLevel != null ||
        profile?.planType != null ||
        profile?.vipStatus != null ||
        profile?.vipExpireAt != null;
  }

  TextStyle? _sectionTitleTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall?.copyWith(
      fontSize: 14.5,
      height: 1.2,
      fontWeight: FontWeight.w700,
    );
  }

  TextStyle? _sectionDescriptionTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 12.5,
      height: 1.45,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
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
