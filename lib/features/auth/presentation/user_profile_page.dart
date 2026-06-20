// UI-GOV-EXEMPT-FILE: scaffold list-children layout-builder
// reason: Phase 10 reviewed this profile page shell; the short static list and pure layout builder are intentional.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/images/local_file_image.dart';
import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/foundation/app_button.dart';
import '../../../app/widgets/foundation/app_feedback.dart';
import '../../../app/widgets/foundation/app_progress.dart';
import '../../../app/widgets/foundation/app_refresh_indicator.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/membership/membership_access_resolver.dart';
import '../../../core/user/user_profile.dart';
import '../../../core/user/user_profile_service.dart';
import '../../mine/application/mine_page_session_service.dart';
import '../../mine/providers.dart';
import '../application/auth_form_validation_service.dart';
import '../providers.dart';

class UserProfilePage extends ConsumerStatefulWidget {
  const UserProfilePage({super.key});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  late final AuthSessionStore _sessionStore;
  late final AuthService _authService;
  late final UserProfileService _userProfileService;
  late final MinePageSessionService _minePageSessionService;
  StreamSubscription<AuthEvent>? _authEventSubscription;

  AuthSession? _session;
  UserProfile? _profile;
  String? _localAvatarPath;
  bool _isLoading = true;
  bool _isLoadingProfile = false;
  bool _isLoggingOut = false;
  bool _isSavingProfile = false;
  bool _isClearingCache = false;
  int _sessionLoadVersion = 0;

  @override
  void initState() {
    super.initState();
    _sessionStore = ref.read(authSessionStoreProvider);
    _authService = ref.read(authServiceProvider);
    _userProfileService = ref.read(userProfileServiceProvider);
    _minePageSessionService = ref.read(minePageSessionServiceProvider);
    _authEventSubscription = AuthEventBus.instance.stream.listen(
      _handleAuthEvent,
    );
    _loadSession();
  }

  @override
  void dispose() {
    _authEventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    await _reloadSessionFromStore(showLoading: true);
  }

  Future<void> _reloadSessionFromStore({required bool showLoading}) async {
    final loadVersion = ++_sessionLoadVersion;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    final session = await _sessionStore.getSession();
    final localAvatarPath = await _minePageSessionService.loadLocalAvatarPath(
      session?.userId,
    );
    if (!mounted || loadVersion != _sessionLoadVersion) {
      return;
    }
    final sessionChanged = !_isSameSessionIdentity(_session, session);
    setState(() {
      _session = session;
      if (session == null || sessionChanged) {
        _profile = null;
      }
      _localAvatarPath = localAvatarPath;
      _isLoading = false;
    });
    if (session != null) {
      await _loadProfile(session, loadVersion);
    }
  }

  Future<void> _loadProfile(AuthSession session, int loadVersion) async {
    if (!mounted || loadVersion != _sessionLoadVersion) {
      return;
    }
    setState(() {
      _isLoadingProfile = true;
    });
    try {
      // 不要使用 session.accessToken，因为它可能是旧的缓存值
      // 让系统自动从 AuthSessionStore.getAccessToken() 获取最新 token
      final profile = await _userProfileService.fetchMe();
      if (!mounted ||
          loadVersion != _sessionLoadVersion ||
          !_isSameSessionIdentity(_session, session) ||
          !_profileBelongsToSession(profile, session)) {
        return;
      }
      final nextSession = await _syncSessionWithProfile(session, profile);
      if (!mounted ||
          loadVersion != _sessionLoadVersion ||
          !_isSameSessionIdentity(_session, session)) {
        return;
      }
      setState(() {
        _session = nextSession;
        _profile = profile;
      });
    } catch (_) {
      // Keep the page available with local session data.
    } finally {
      if (mounted &&
          loadVersion == _sessionLoadVersion &&
          _isSameSessionIdentity(_session, session)) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _refreshPage() async {
    await _reloadSessionFromStore(showLoading: false);
  }

  Future<AuthSession> _syncSessionWithProfile(
    AuthSession session,
    UserProfile profile,
  ) async {
    final currentSession = await _sessionStore.getSession();
    if (!_isSameSessionIdentity(currentSession, session)) {
      return session;
    }
    final baseSession = currentSession ?? session;
    final nextSession = _mergeProfileIntoSession(baseSession, profile);
    if (!_isSameSessionValue(baseSession, nextSession)) {
      await _sessionStore.saveSession(nextSession);
      ref.read(mineRemoteAccessSnapshotRevisionProvider.notifier).state++;
    }
    return nextSession;
  }

  void _handleAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.loggedIn:
        ++_sessionLoadVersion;
        if (mounted) {
          setState(() {
            _session = event.session;
            _profile = null;
            _localAvatarPath = null;
            _isLoading = false;
            _isLoadingProfile = event.session != null;
          });
        }
        unawaited(_reloadSessionFromStore(showLoading: false));
        break;
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        ++_sessionLoadVersion;
        if (mounted) {
          setState(() {
            _session = null;
            _profile = null;
            _localAvatarPath = null;
            _isLoading = false;
            _isLoadingProfile = false;
          });
        }
        break;
    }
  }

  bool _isSameSessionIdentity(AuthSession? left, AuthSession? right) {
    return _sessionIdentityKey(left) == _sessionIdentityKey(right);
  }

  bool _profileBelongsToSession(UserProfile profile, AuthSession session) {
    final sessionUserId = session.userId?.trim() ?? '';
    final profileUserId = profile.userId.trim();
    if (sessionUserId.isNotEmpty && profileUserId.isNotEmpty) {
      return sessionUserId == profileUserId;
    }
    final sessionIdentity = session.loginIdentity?.trim().toLowerCase() ?? '';
    final profileIdentity = profile.loginIdentity.trim().toLowerCase();
    if (sessionIdentity.isNotEmpty && profileIdentity.isNotEmpty) {
      return sessionIdentity == profileIdentity;
    }
    return true;
  }

  String? _sessionIdentityKey(AuthSession? session) {
    final userId = session?.userId?.trim() ?? '';
    if (userId.isNotEmpty) {
      return 'id:$userId';
    }
    final identity = session?.loginIdentity?.trim().toLowerCase() ?? '';
    if (identity.isNotEmpty) {
      return 'identity:$identity';
    }
    return null;
  }

  AuthSession _mergeProfileIntoSession(
    AuthSession session,
    UserProfile profile,
  ) {
    final hasProfileMembershipState =
        profile.membershipActive != null ||
        _hasText(profile.vipLevel) ||
        _hasText(profile.vipStatus);

    return AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      accessExpiresAt: session.accessExpiresAt,
      refreshExpiresAt: session.refreshExpiresAt,
      userId: _nonEmpty(profile.userId) ?? session.userId,
      username: _nonEmpty(profile.username) ?? session.username,
      account: _nonEmpty(profile.account) ?? session.account,
      displayName:
          _nonEmpty(profile.displayName) ??
          _nonEmpty(profile.username) ??
          session.displayName,
      membershipActive:
          hasProfileMembershipState
              ? profile.membershipActive
              : session.membershipActive,
      vipLevel: hasProfileMembershipState ? profile.vipLevel : session.vipLevel,
      planType:
          hasProfileMembershipState
              ? profile.planType ?? session.planType
              : session.planType,
      vipStatus:
          hasProfileMembershipState ? profile.vipStatus : session.vipStatus,
      vipExpireAt:
          hasProfileMembershipState ? profile.vipExpireAt : session.vipExpireAt,
    );
  }

  bool _isSameSessionValue(AuthSession left, AuthSession right) {
    return left.accessToken == right.accessToken &&
        (left.refreshToken ?? '') == (right.refreshToken ?? '') &&
        left.accessExpiresAt == right.accessExpiresAt &&
        left.refreshExpiresAt == right.refreshExpiresAt &&
        (left.userId ?? '') == (right.userId ?? '') &&
        (left.username ?? '') == (right.username ?? '') &&
        (left.account ?? '') == (right.account ?? '') &&
        (left.displayName ?? '') == (right.displayName ?? '') &&
        left.membershipActive == right.membershipActive &&
        (left.vipLevel ?? '') == (right.vipLevel ?? '') &&
        (left.planType ?? '') == (right.planType ?? '') &&
        (left.vipStatus ?? '') == (right.vipStatus ?? '') &&
        left.vipExpireAt == right.vipExpireAt;
  }

  String? _nonEmpty(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  bool _hasText(String? value) => _nonEmpty(value) != null;

  UserProfile? _membershipProfileFor(
    AuthSession session,
    UserProfile? profile,
  ) {
    final profileAccess = MembershipAccessResolver.fromProfile(profile);
    if (profileAccess.hasExplicitMembershipState ||
        profileAccess.hasMembership) {
      return profile;
    }
    final sessionAccess = MembershipAccessResolver.fromSession(session);
    if (!sessionAccess.hasExplicitMembershipState &&
        !sessionAccess.hasMembership) {
      return profile;
    }
    return UserProfile(
      userId: session.userId ?? '',
      username: session.username ?? session.account ?? '',
      account: session.account ?? session.username ?? '',
      displayName: session.displayName,
      phone: profile?.phone,
      email: profile?.email,
      role: profile?.role,
      createdAt: profile?.createdAt,
      membershipActive: session.membershipActive,
      vipLevel: session.vipLevel,
      planType: session.planType,
      vipStatus: session.vipStatus,
      vipExpireAt: session.vipExpireAt,
      features: profile?.features ?? const <String>[],
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
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
          actions: [
            if (_session != null)
              IconButton(
                tooltip: '编辑资料',
                onPressed: _isSavingProfile ? null : _showEditProfileSheet,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
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
                child: AppRefreshIndicator(
                  semanticsLabel: '刷新账号资料',
                  onRefresh: _refreshPage,
                  child: AppAnimatedSwitcher(
                    child: ListView(
                      key: ValueKey<bool>(_isLoading),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        metrics.contentGap,
                        horizontal,
                        metrics.sectionGap + bottomSafe,
                      ),
                      children: _buildContent(context),
                    ),
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
    final metrics = AppAdaptiveMetrics.of(context);

    if (_isLoading) {
      return [
        SizedBox(height: metrics.sectionGap * 3),
        AppFadeSlideTransition(
          child: const Center(
            key: ValueKey('user_profile_loading'),
            child: AppProgressIndicator(semanticLabel: '加载用户资料'),
          ),
        ),
      ];
    }

    if (session == null) {
      return [
        _buildGuestHero(context),
        SizedBox(height: metrics.sectionGap),
        Card(
          child: Padding(
            padding: EdgeInsets.all(metrics.cardPadding),
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
                SizedBox(height: metrics.sectionGap),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 360;
                    final loginButton = AppButton(
                      label: '去登录',
                      onPressed: () => context.push('/auth'),
                      icon: const Icon(Icons.login_rounded),
                    );
                    final membershipButton = AppButton(
                      label: '了解会员',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.push('/membership'),
                      icon: const Icon(Icons.workspace_premium_outlined),
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          loginButton,
                          SizedBox(height: metrics.contentGap),
                          membershipButton,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: loginButton),
                        SizedBox(width: metrics.contentGap),
                        Expanded(child: membershipButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final profile = _profile;
    final membershipProfile = _membershipProfileFor(session, profile);
    final displayName =
        profile?.displayIdentity ??
        session.displayIdentity ??
        session.userId ??
        '用户';
    final userId = profile?.userId ?? session.userId ?? '-';

    return [
      _buildProfileHero(
        context,
        displayName: displayName,
        userId: userId,
        profile: profile,
        membershipProfile: membershipProfile,
        localAvatarPath: _localAvatarPath,
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
      SizedBox(height: metrics.sectionGap),
      _buildInfoCard(
        context,
        title: '个人资料',
        description: '账号的基础身份信息。',
        rows: [
          _ProfileRow(
            label: '显示名',
            value: profile?.displayIdentity ?? session.displayIdentity ?? '-',
          ),
          _ProfileRow(
            label: '账号',
            value:
                profile?.loginIdentity ??
                session.loginIdentity ??
                session.userId ??
                '-',
          ),
          _ProfileRow(label: '手机号', value: profile?.phone ?? '-'),
          _ProfileRow(label: '邮箱', value: profile?.email ?? '-'),
          _ProfileRow(label: '用户 ID', value: userId),
          _ProfileRow(label: '注册时间', value: _formatTime(profile?.createdAt)),
        ],
      ),
      SizedBox(height: metrics.contentGap),
      Card(
        child: Padding(
          padding: EdgeInsets.all(metrics.cardPadding),
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
                '刷新资料可以同步最新的账号信息，清除缓存可以解决会员状态显示异常的问题。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      AppAdaptiveMetrics.resolveForConstraints(
                        context,
                        constraints,
                      ).isCompactDensity;
                  final refreshButton = AppButton(
                    label: '刷新资料',
                    variant: AppButtonVariant.secondary,
                    onPressed: _isLoadingProfile ? null : _refreshPage,
                    icon: const Icon(Icons.refresh_rounded),
                  );
                  final clearCacheButton = AppButton(
                    label: _isClearingCache ? '清除中...' : '清除缓存',
                    variant: AppButtonVariant.secondary,
                    onPressed: _isClearingCache ? null : _handleClearCache,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    isLoading: _isClearingCache,
                  );
                  final logoutButton = AppButton(
                    label: _isLoggingOut ? '退出中...' : '退出登录',
                    variant: AppButtonVariant.danger,
                    onPressed: _isLoggingOut ? null : _handleLogout,
                    icon: const Icon(Icons.logout_rounded),
                    isLoading: _isLoggingOut,
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        refreshButton,
                        SizedBox(height: metrics.contentGap),
                        clearCacheButton,
                        SizedBox(height: metrics.contentGap),
                        logoutButton,
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: refreshButton),
                          SizedBox(width: metrics.contentGap),
                          Expanded(child: clearCacheButton),
                        ],
                      ),
                      SizedBox(height: metrics.contentGap),
                      SizedBox(width: double.infinity, child: logoutButton),
                    ],
                  );
                },
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
      padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding + 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          AppAdaptiveMetrics.of(context).cardRadius + 8,
        ),
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

  // ==================== 会员卡片相关方法 ====================

  /// 计算会员进度条相关数据
  ({int totalDays, int enjoyedDays, int remainingDays, double progress})
  _computeMembershipProgress(UserProfile? profile) {
    final now = DateTime.now();
    // 使用 created_at 作为起始时间，如果没有则用当前时间
    final startAt = profile?.createdAt ?? now;
    final expireAt = profile?.vipExpireAt;

    if (expireAt == null || expireAt.isBefore(now)) {
      return (totalDays: 0, enjoyedDays: 0, remainingDays: 0, progress: 0.0);
    }

    final totalDays = expireAt.difference(startAt).inDays;
    final enjoyedDays = now.difference(startAt).inDays;
    final remainingDays = expireAt.difference(now).inDays;
    final progress = totalDays > 0 ? enjoyedDays / totalDays : 0.0;

    return (
      totalDays: totalDays,
      enjoyedDays: enjoyedDays,
      remainingDays: remainingDays,
      progress: progress.clamp(0.0, 1.0),
    );
  }

  /// 获取会员等级标签样式
  ({String label, Color color, Color backgroundColor}) _getVipLevelStyle(
    UserProfile? profile,
  ) {
    final level = profile?.vipLevel?.toLowerCase() ?? '';
    switch (level) {
      case 'vip':
        return (
          label: 'VIP',
          color: const Color(0xFFB8860B),
          backgroundColor: const Color(0xFFFFF8E7),
        );
      case 'svip':
        return (
          label: 'SVIP',
          color: const Color(0xFF6A1B9A),
          backgroundColor: const Color(0xFFF3E5F5),
        );
      case 'premium':
        return (
          label: '高级会员',
          color: const Color(0xFFE65100),
          backgroundColor: const Color(0xFFFFF3E0),
        );
      default:
        return (
          label: '会员',
          color: const Color(0xFF2C3E50),
          backgroundColor: const Color(0xFFECF0F1),
        );
    }
  }

  /// 判断是否为有效会员
  bool _isValidVip(UserProfile? profile) {
    return MembershipAccessResolver.fromProfile(profile).hasMembership;
  }

  /// 格式化天数
  String _formatDays(int days) {
    return '$days 天';
  }

  Widget _buildMembershipCard(UserProfile? profile, BuildContext context) {
    final isValidVip = _isValidVip(profile);

    if (!isValidVip) {
      return _buildUpgradeCard(context);
    }

    return _buildVipStatusCard(profile, context);
  }

  Widget _buildUpgradeCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => context.push('/membership'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.9),
              colorScheme.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '开通会员，享阅读特权',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '去广告 · 无限书架 · 专属书单',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AppButton(
              label: '开通会员',
              size: AppButtonSize.compact,
              onPressed: () => context.push('/membership'),
              icon: const Icon(Icons.workspace_premium_rounded, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVipStatusCard(UserProfile? profile, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = _getVipLevelStyle(profile);
    final progress = _computeMembershipProgress(profile);
    final expireAt = profile?.vipExpireAt;
    final isLifetime = profile?.planType?.toLowerCase() == 'lifetime';
    final expireText =
        isLifetime
            ? '永久有效'
            : expireAt != null
            ? '${expireAt.year}-${expireAt.month.toString().padLeft(2, '0')}-${expireAt.day.toString().padLeft(2, '0')} 到期'
            : '会员有效';

    return InkWell(
      onTap: () => context.push('/membership'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: style.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    style.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: style.color,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    expireText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                AppButton(
                  label: '查看权益',
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.compact,
                  onPressed: () => context.push('/membership'),
                  icon: const Icon(Icons.chevron_right_rounded, size: 16),
                ),
              ],
            ),
            if (!isLifetime) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.progress,
                  minHeight: 4,
                  backgroundColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    style.color == const Color(0xFFB8860B)
                        ? const Color(0xFFFFD700)
                        : style.color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已享受 ${_formatDays(progress.enjoyedDays)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '剩余 ${_formatDays(progress.remainingDays)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
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

  // ==================== 原有方法 ====================

  Widget _buildProfileHero(
    BuildContext context, {
    required String displayName,
    required String userId,
    required UserProfile? profile,
    required UserProfile? membershipProfile,
    required String? localAvatarPath,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = displayName.trim().isEmpty ? 'U' : displayName.trim()[0];
    final isValidVip = _isValidVip(membershipProfile);
    final vipLevelStyle = _getVipLevelStyle(membershipProfile);

    return Container(
      padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding + 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          AppAdaptiveMetrics.of(context).cardRadius + 10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surface.withValues(alpha: 0.84),
                ),
                child: buildLocalFileImage(
                  imagePath: localAvatarPath,
                  width: 60,
                  height: 60,
                  cacheWidth: 180,
                  cacheHeight: 180,
                  fallback: Center(
                    child: Text(
                      initial,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isValidVip)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: vipLevelStyle.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              vipLevelStyle.label,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: vipLevelStyle.color,
                              ),
                            ),
                          ),
                      ],
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
          _buildMembershipCard(membershipProfile, context),
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
        padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding),
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
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 420,
      builder: (surfaceContext) {
        final colorScheme = Theme.of(surfaceContext).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '退出登录',
              style: Theme.of(
                surfaceContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '确定要退出当前账号吗？',
              style: Theme.of(surfaceContext).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(true),
                  child: const Text('退出'),
                ),
              ],
            ),
          ],
        );
      },
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
      _showMessage('退出失败，请稍后再试。', tone: AppFeedbackTone.error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Future<void> _handleClearCache() async {
    final session = _session;
    if (session == null) {
      return;
    }
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 420,
      builder: (surfaceContext) {
        final colorScheme = Theme.of(surfaceContext).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '清除缓存',
              style: Theme.of(
                surfaceContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '清除会员状态缓存并重新从服务器获取最新数据。如果你刚开通会员但界面未更新，可以尝试此操作。',
              style: Theme.of(surfaceContext).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(true),
                  child: const Text('清除'),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isClearingCache = true;
    });

    try {
      final userId = session.userId?.trim() ?? '';
      if (userId.isNotEmpty) {
        await _minePageSessionService.clearUserScopedCache(userId);
      }
      if (!mounted) {
        return;
      }
      // 清除缓存后立即刷新
      await _refreshPage();
      _showMessage('缓存已清除，会员状态已刷新', tone: AppFeedbackTone.success);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('清除缓存失败，请稍后再试。', tone: AppFeedbackTone.error);
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCache = false;
        });
      }
    }
  }

  Future<void> _showEditProfileSheet() async {
    final session = _session;
    if (session == null) {
      return;
    }
    final profile = _profile;
    final result = await showAdaptiveActionSurface<UserProfileUpdateInput>(
      context: context,
      maxWidth: 520,
      builder: (surfaceContext) {
        return _EditProfileSurface(
          validationService: ref.read(authFormValidationServiceProvider),
          initialAccount:
              profile?.account ?? session.account ?? session.username ?? '',
          initialDisplayName:
              profile?.displayName ??
              session.displayName ??
              profile?.username ??
              session.username ??
              '',
          initialPhone: profile?.phone ?? '',
          initialEmail: profile?.email ?? '',
        );
      },
    );
    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _isSavingProfile = true;
    });
    try {
      final updated = await _userProfileService.updateProfile(
        result,
        userId: session.userId,
      );
      final nextSession = AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        accessExpiresAt: session.accessExpiresAt,
        refreshExpiresAt: session.refreshExpiresAt,
        userId: session.userId,
        username: updated.username,
        account: updated.account,
        displayName:
            updated.displayName?.trim().isNotEmpty == true
                ? updated.displayName
                : updated.username,
        membershipActive: updated.membershipActive,
        vipLevel: updated.vipLevel,
        planType: updated.planType,
        vipStatus: updated.vipStatus,
        vipExpireAt: updated.vipExpireAt,
      );
      await _sessionStore.saveSession(nextSession);
      if (!mounted) {
        return;
      }
      setState(() {
        _session = nextSession;
        _profile = updated;
      });
      _showMessage('资料已更新', tone: AppFeedbackTone.success);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.briefMessage, tone: AppFeedbackTone.error);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('保存失败，请稍后再试。', tone: AppFeedbackTone.error);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    AppFeedbackTone tone = AppFeedbackTone.info,
  }) {
    if (!mounted) {
      return;
    }
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone: tone,
      useHaptics: false,
    );
  }
}

class _ProfileRow {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _EditProfileSurface extends StatefulWidget {
  const _EditProfileSurface({
    required this.validationService,
    required this.initialAccount,
    required this.initialDisplayName,
    required this.initialPhone,
    required this.initialEmail,
  });

  final AuthFormValidationService validationService;
  final String initialAccount;
  final String initialDisplayName;
  final String initialPhone;
  final String initialEmail;

  @override
  State<_EditProfileSurface> createState() => _EditProfileSurfaceState();
}

class _EditProfileSurfaceState extends State<_EditProfileSurface> {
  late final TextEditingController _accountController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(text: widget.initialAccount);
    _displayNameController = TextEditingController(
      text: widget.initialDisplayName,
    );
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _accountController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '编辑资料',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          '可修改当前账号的显示名、联系方式和密码，账号本身不可修改。',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _accountController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: '账号',
            helperText: '账号创建后不可修改',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _displayNameController,
          decoration: const InputDecoration(
            labelText: '显示名',
            hintText: '请输入显示名',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: '手机号',
            hintText: '请输入手机号',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: '邮箱', hintText: '请输入邮箱'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: '新密码',
            hintText: '留空则不修改密码',
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: '确认新密码',
            hintText: '再次输入新密码',
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(_errorText!, style: TextStyle(color: colorScheme.error)),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _submit, child: const Text('保存')),
          ],
        ),
      ],
    );
  }

  void _submit() {
    final account = _accountController.text.trim();
    final displayName = _displayNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final validationError =
        widget.validationService.validateAccount(account) ??
        widget.validationService.validateOptionalPhone(phone) ??
        widget.validationService.validateOptionalEmail(email) ??
        widget.validationService.validateOptionalNewPassword(password) ??
        widget.validationService.validateOptionalConfirmPassword(
          confirmPassword,
          password: password,
        );
    if (validationError != null) {
      setState(() {
        _errorText = validationError;
      });
      return;
    }
    Navigator.of(context).pop(
      UserProfileUpdateInput(
        displayName: displayName.isEmpty ? account : displayName,
        phone: phone,
        email: email,
        password: password.trim(),
      ),
    );
  }
}
