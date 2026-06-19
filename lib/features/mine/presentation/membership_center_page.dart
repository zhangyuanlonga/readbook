import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/foundation/app_feedback.dart';
import '../../../app/widgets/foundation/app_refresh_indicator.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/device/device_identity.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/membership/membership_access_resolver.dart';
import '../../../core/membership/membership_device_seat.dart';
import '../../../core/membership/membership_entitlement.dart';
import '../../../core/membership/membership_seat_sync_result.dart';
import '../../../core/membership/membership_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/source_access/source_access_provider.dart';
import '../application/advanced_theme_provider.dart';
import '../providers.dart';

class MembershipCenterPage extends ConsumerStatefulWidget {
  const MembershipCenterPage({super.key});

  @override
  ConsumerState<MembershipCenterPage> createState() =>
      _MembershipCenterPageState();
}

class _MembershipCenterPageState extends ConsumerState<MembershipCenterPage> {
  static const String _supportQqNumber = '782045011';
  static const String _paymentQrAssetPath = 'assets/logo/vx.jpg';
  static final Uri _supportChatUri = Uri.parse(
    'mqqwpa://im/chat?chat_type=wpa&uin=$_supportQqNumber&version=1&src_type=app',
  );
  static final Uri _supportFallbackUri = Uri.parse(
    'https://wpa.qq.com/msgrd?v=3&uin=$_supportQqNumber&site=qq&menu=yes',
  );
  static final Uri _supportGroupUri = Uri.parse(
    'https://qun.qq.com/universal-share/share?ac=1&authKey=Tabvg05EAafVbER7E8%2BzAQ18yErg2a%2B5PoqQH41t6dbPjcZIfDSnNX%2F4KCAXhzVh&busi_data=eyJncm91cENvZGUiOiIxMDgyODI3MjI0IiwidG9rZW4iOiIzam5tVFQ0cUs1T3VlMytzVk9iOXB1Zk40Q1RaUXJiQytzd2JlZUx3NDhXQTJscy9ZZGE5WW1hQXhPdGFwMHU1IiwidWluIjoiNzgyMDQ1MDExIn0%3D&data=PHNA5IOU4A3ujR5i9rmpWqWn4Qc-L9MNr8ByREa7IfvpXTo1utwnHVIfjkB7Rlk4x3yE9dfMR5_ZjOfsQ9wYcA&svctype=4&tempid=h5_group_info',
  );

  static const List<_MembershipFeatureItem> _featureItems = [
    _MembershipFeatureItem(
      icon: Icons.all_inclusive_rounded,
      title: '无限制阅读',
      description: '畅享完整阅读能力，解锁所有高级会员功能，获得更自由的使用体验。',
    ),
    _MembershipFeatureItem(
      icon: Icons.sell_outlined,
      title: '标签与分类无限制',
      description: '自由管理书架标签与分类，不受数量限制，构建更清晰的个人整理体系。',
    ),
    _MembershipFeatureItem(
      icon: Icons.font_download_outlined,
      title: '自定义字体',
      description: '支持导入自定义字体，并可应用到软件外观与阅读页面，打造专属阅读风格。',
    ),
    _MembershipFeatureItem(
      icon: Icons.record_voice_over_outlined,
      title: '语音朗读',
      description: '支持更灵活的语音朗读体验，可结合后续语音能力扩展打造更自然的听书模式。',
    ),
    _MembershipFeatureItem(
      icon: Icons.smart_toy_outlined,
      title: 'AI 助手',
      description: '为阅读理解、内容提炼、问答辅助等场景预留 AI 能力入口，后续将持续扩展。',
      note: '需配置对应 AI 服务密钥或接入能力',
    ),
    _MembershipFeatureItem(
      icon: Icons.translate_outlined,
      title: '自定义 API 引擎翻译',
      description: '支持接入自定义翻译服务，为阅读过程中的术语、句段和内容理解提供翻译辅助。',
      note: '需配置对应翻译服务密钥或接口',
    ),
    _MembershipFeatureItem(
      icon: Icons.devices_rounded,
      title: '全平台解锁',
      description: '支持 iOS、Android、macOS、Windows、Linux 多平台使用，登录账号即可自由切换设备。',
    ),
    _MembershipFeatureItem(
      icon: Icons.palette_outlined,
      title: '自定义高级主题',
      description: '可设置自定义外观颜色、背景图、封面风格与导航栏资源，统一你的个性化视觉体验。',
    ),
    _MembershipFeatureItem(
      icon: Icons.photo_library_outlined,
      title: '封面图集',
      description: '为书籍设置自定义封面图集，打造更有风格的专属书架。',
    ),
    _MembershipFeatureItem(
      icon: Icons.wallpaper_outlined,
      title: '背景图集',
      description: '为应用设置自定义背景图片，让书架、发现页和我的页拥有统一的视觉氛围。',
    ),
    _MembershipFeatureItem(
      icon: Icons.menu_book_outlined,
      title: '多格式阅读',
      description: '支持导入 TXT、EPUB、PDF、Markdown、HTML、MOBI、AZW、AZW3 等多种常见阅读格式。',
    ),
    _MembershipFeatureItem(
      icon: Icons.widgets_outlined,
      title: '桌面小组件',
      description: '为常用阅读入口、最近阅读与快捷状态展示预留桌面小组件能力，后续会逐步开放。',
    ),
  ];

  late final AuthSessionStore _sessionStore;
  late final MembershipService _membershipService;
  final TextEditingController _codeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  AuthSession? _session;
  MembershipEntitlement? _entitlement;
  MembershipSeatSyncResult? _seatSyncResult;
  List<MembershipDeviceSeat> _deviceSeats = const <MembershipDeviceSeat>[];
  bool _isLoading = true;
  bool _isRedeeming = false;
  bool _isClaimingTrial = false;
  String? _errorMessage;

  bool get _hasActiveMembership =>
      MembershipAccessResolver.fromEntitlement(_entitlement).hasMembership;
  bool get _isActing => _isRedeeming || _isClaimingTrial;

  @override
  void initState() {
    super.initState();
    _sessionStore = ref.read(mineAuthSessionStoreProvider);
    _membershipService = ref.read(mineMembershipServiceProvider);
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
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    const title = '会员中心';

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
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

            return DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: AppRefreshIndicator(
                    semanticsLabel: '刷新会员中心',
                    onRefresh: _refreshPage,
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        topInset + metrics.contentGap,
                        horizontal,
                        92 + metrics.sectionGap + bottomSafe,
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
      if (!mounted) {
        return;
      }
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
    final remoteAccessSnapshotService = ref.read(
      remoteAccessSnapshotServiceProvider,
    );
    final snapshotRevisionNotifier = ref.read(
      mineRemoteAccessSnapshotRevisionProvider.notifier,
    );
    try {
      final entitlement = await _membershipService.fetchEntitlement();
      final userId = _session?.userId?.trim() ?? '';
      if (userId.isNotEmpty) {
        await remoteAccessSnapshotService.saveMergedMembership(
          userId: userId,
          entitlement: entitlement,
        );
        snapshotRevisionNotifier.update((value) => value + 1);
        await ref.read(sourceAccessScopeProvider.notifier).refresh();
      }
      MembershipSeatSyncResult? seatSyncResult;
      String? transientError;
      var seats = const <MembershipDeviceSeat>[];
      if (entitlement.isActive) {
        seats = await _membershipService.fetchDeviceSeats();
        try {
          final identity = await _membershipService.loadCurrentDeviceIdentity();
          final activeSeatCount = seats.where((item) => item.isActive).length;
          final hasCurrentSeat = _membershipService.currentDeviceHasActiveSeat(
            seats,
            identity,
          );
          final currentSeat = _findCurrentSeat(seats, identity);
          if (hasCurrentSeat) {
            seatSyncResult = MembershipSeatSyncResult(
              deviceStatus: 'ok',
              maxDevices: entitlement.maxDevices,
              activeDeviceCount: activeSeatCount,
              seat: currentSeat,
            );
          } else if (activeSeatCount >= entitlement.maxDevices) {
            seatSyncResult = MembershipSeatSyncResult(
              deviceStatus: 'over_limit',
              maxDevices: entitlement.maxDevices,
              activeDeviceCount: activeSeatCount,
              seat: null,
            );
          } else {
            seatSyncResult = await _membershipService.syncCurrentDeviceSeat();
            seats = await _membershipService.fetchDeviceSeats();
          }
        } on ApiException catch (error) {
          if (_isSeatOverLimitError(error)) {
            seatSyncResult = MembershipSeatSyncResult(
              deviceStatus: 'over_limit',
              maxDevices: entitlement.maxDevices,
              activeDeviceCount: seats.where((item) => item.isActive).length,
              seat: null,
            );
          } else {
            transientError = error.briefMessage;
          }
        } catch (error) {
          transientError =
              error is AppException ? error.briefMessage : '设备席位同步失败。';
        }
      }
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
            error is AppException
                ? error.briefMessage
                : _MembershipMessages.loadFailed;
      });
    }
  }

  bool _isSeatOverLimitError(ApiException error) {
    final apiCode = error.apiCode.toLowerCase();
    final message = error.briefMessage.toLowerCase();
    return apiCode.contains('over_limit') ||
        apiCode.contains('seat') ||
        message.contains('device seat over limit') ||
        message.contains('over limit') ||
        message.contains('设备席位') ||
        message.contains('超上限');
  }

  MembershipDeviceSeat? _findCurrentSeat(
    List<MembershipDeviceSeat> seats,
    DeviceIdentity identity,
  ) {
    for (final seat in seats) {
      if (!seat.isActive) {
        continue;
      }
      if (seat.installId == identity.installId ||
          (seat.deviceUid != null && seat.deviceUid == identity.deviceUid) ||
          (seat.deviceFingerprint != null &&
              seat.deviceFingerprint == identity.deviceFingerprint)) {
        return seat;
      }
    }
    return null;
  }

  Future<bool> _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage(_MembershipMessages.inputCode);
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
      _showMessage(_MembershipMessages.redeemSuccess);
      await ref.read(sourceAccessScopeProvider.notifier).refresh();
      await _loadPage();
      return true;
    } catch (error) {
      _showMessage(
        error is AppException
            ? error.briefMessage
            : _MembershipMessages.redeemFailed,
      );
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
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 440,
      builder: (surfaceContext) {
        final colorScheme = Theme.of(surfaceContext).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '释放设备席位',
              style: Theme.of(
                surfaceContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '确认释放设备 ${_seatDisplayLabel(seat)} 的会员席位吗？',
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
                  child: const Text('释放'),
                ),
              ],
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
      _showMessage(_MembershipMessages.seatReleased);
      await _loadPage();
      return true;
    } catch (error) {
      _showMessage(
        error is AppException
            ? error.briefMessage
            : _MembershipMessages.seatReleaseFailed,
      );
      return false;
    }
  }

  Future<bool> _ensureSignedIn() async {
    if (_session != null) {
      return true;
    }
    _showMessage(_MembershipMessages.needLogin);
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

  Future<void> _handleTrialAction() async {
    if (!await _ensureSignedIn()) {
      return;
    }
    if (_isClaimingTrial) {
      return;
    }
    if (!mounted) {
      return;
    }

    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 440,
      builder: (surfaceContext) {
        final colorScheme = Theme.of(surfaceContext).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '领取试用会员',
              style: Theme.of(
                surfaceContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '将为当前账号领取 7 天 Pro 试用会员，每个账号限领一次。确认立即领取吗？',
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
                  child: const Text('立即领取'),
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
      _isClaimingTrial = true;
    });
    try {
      await _membershipService.claimTrialMembership();
      _showMessage(_MembershipMessages.trialSuccess);
      await ref.read(sourceAccessScopeProvider.notifier).refresh();
      await _loadPage();
    } catch (error) {
      _showMessage(
        error is AppException
            ? error.briefMessage
            : _MembershipMessages.trialFailed,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isClaimingTrial = false;
        });
      }
    }
  }

  Future<void> _openSupport() async {
    if (!mounted) {
      return;
    }
    await showAdaptiveActionSurface<void>(
      context: context,
      maxWidth: 520,
      builder:
          (surfaceContext) =>
              SingleChildScrollView(child: _buildSupportSheet(surfaceContext)),
    );
  }

  Future<void> _copySupportQqNumber() async {
    await Clipboard.setData(const ClipboardData(text: _supportQqNumber));
    if (!mounted) {
      return;
    }
    _showMessage('已复制客服 QQ：$_supportQqNumber');
  }

  Future<void> _openSupportChatDirectly() async {
    final launched = await launchUrl(
      _supportChatUri,
      mode: LaunchMode.externalApplication,
    );
    if (launched || !mounted) {
      return;
    }
    final fallbackLaunched = await launchUrl(
      _supportFallbackUri,
      mode: LaunchMode.externalApplication,
    );
    if (fallbackLaunched || !mounted) {
      return;
    }
    _showMessage('当前无法直接发起私聊，可先复制 QQ 号添加好友。');
  }

  Future<void> _openSupportGroup() async {
    final launched = await launchUrl(
      _supportGroupUri,
      mode: LaunchMode.externalApplication,
    );
    if (launched || !mounted) {
      return;
    }
    _showMessage('跳转失败，请稍后重试。');
  }

  Future<void> _savePaymentQrCode() async {
    try {
      final data = await rootBundle.load(_paymentQrAssetPath);
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final saveDirectory = Directory(
        p.join(documentsDirectory.path, 'membership_payments'),
      );
      if (!await saveDirectory.exists()) {
        await saveDirectory.create(recursive: true);
      }
      final targetFile = File(
        p.join(saveDirectory.path, 'membership_payment_qr.jpg'),
      );
      await targetFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (!mounted) {
        return;
      }
      _showMessage('二维码已保存到 ${targetFile.path}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('保存二维码失败，请直接截图保存。');
    }
  }

  List<Widget> _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    if (_isLoading) {
      return [
        SizedBox(height: metrics.sectionGap * 3),
        Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      ];
    }

    final widgets = <Widget>[
      if (_errorMessage != null && _errorMessage!.isNotEmpty)
        _buildMessageCard(context, _errorMessage!, isError: true),
      _buildTrialNoticeCard(context),
    ];

    if (_session == null) {
      widgets.addAll([
        _buildHeroCard(context, loggedIn: false),
        SizedBox(height: metrics.sectionGap),
        _buildFeatureCard(context),
        SizedBox(height: metrics.sectionGap),
        _buildMembershipStatusStrip(context),
      ]);
      return _animateContentEntries(widgets);
    }

    if (!_hasActiveMembership) {
      widgets.addAll([
        _buildHeroCard(context, loggedIn: true),
        SizedBox(height: metrics.sectionGap),
        _buildFeatureCard(context),
        SizedBox(height: metrics.sectionGap),
        _buildMembershipStatusStrip(context),
      ]);
    }

    if (_hasActiveMembership) {
      widgets.addAll([
        _buildEntitlementCard(context),
        SizedBox(height: metrics.sectionGap),
        _buildMembershipStatusStrip(context),
      ]);
    }
    return _animateContentEntries(widgets);
  }

  List<Widget> _animateContentEntries(List<Widget> widgets) {
    return [
      for (var index = 0; index < widgets.length; index++)
        AppFadeSlideTransition(
          delay: Duration(milliseconds: (index * 44).clamp(0, 220).toInt()),
          child: widgets[index],
        ),
    ];
  }

  Widget _buildBottomActionBar(BuildContext context, double bottomSafe) {
    final metrics = AppAdaptiveMetrics.of(context);
    final primaryLabel =
        _session == null
            ? '登录/注册'
            : _hasActiveMembership
            ? '管理会员'
            : '¥68 立即购买';
    final primaryColor =
        _hasActiveMembership
            ? Theme.of(context).colorScheme.primary
            : const Color(0xFFD84B4B);
    return Container(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        metrics.contentGap + bottomSafe,
      ),
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
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed:
                  _isActing
                      ? null
                      : _session == null
                      ? _handleLoginAction
                      : _hasActiveMembership
                      ? _handleManageAction
                      : _openSupport,
              child: Text(primaryLabel),
            ),
          ),
          SizedBox(height: metrics.contentGap / 2),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: metrics.contentGap / 2,
            runSpacing: metrics.contentGap / 2,
            children: [
              if (_session == null)
                TextButton(
                  onPressed: _isActing ? null : _handleActivateAction,
                  child: const Text('许可证激活'),
                )
              else if (_hasActiveMembership)
                TextButton(
                  onPressed: _isActing ? null : _handleActivateAction,
                  child: const Text('激活新许可证'),
                )
              else
                TextButton(
                  onPressed: _isActing ? null : _handleTrialAction,
                  child: Text(_isClaimingTrial ? '领取中...' : '试用会员'),
                ),
              if (!_hasActiveMembership)
                TextButton(
                  onPressed: _isActing ? null : _handleActivateAction,
                  child: const Text('激活许可证'),
                ),
              TextButton(onPressed: _openSupport, child: const Text('联系客服')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleLoginAction() async {
    await context.push('/auth');
    await _loadPage();
  }

  Widget _buildTrialNoticeCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final message =
        _session == null
            ? '登录账号后可自助领取 7 天试用会员，每个账号限领一次。'
            : _hasActiveMembership && (_entitlement?.isTrial ?? false)
            ? '当前账号正处于试用期内，试用结束后可通过许可证继续开通正式会员。'
            : '当前账号可自助领取 7 天试用会员，每个账号限领一次。';
    return Container(
      margin: EdgeInsets.only(bottom: metrics.contentGap),
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_outlined, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.cardRadius + 8),
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              '扫码支付',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '默认展示微信支付二维码。你可以先保存到本地，或者直接截图后扫码支付；如需确认开通结果，也可以使用下方方式联系我。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.42),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        _paymentQrAssetPath,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      '支付后如需人工确认，可联系 QQ：$_supportQqNumber',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '建议优先保存二维码到本地，若保存失败也可以直接截图后扫码支付。支付完成后可复制客服 QQ、尝试私聊，或前往官方群继续处理。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _SupportActionButton(
                        icon: Icons.download_rounded,
                        label: '保存二维码',
                        onPressed: _savePaymentQrCode,
                      ),
                    ),
                    Expanded(
                      child: _SupportActionButton(
                        icon: Icons.copy_rounded,
                        label: '复制客服QQ号',
                        onPressed: _copySupportQqNumber,
                      ),
                    ),
                    Expanded(
                      child: _SupportActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '尝试私聊',
                        onPressed: _openSupportChatDirectly,
                      ),
                    ),
                    Expanded(
                      child: _SupportActionButton(
                        icon: Icons.groups_rounded,
                        label: '前往官方群',
                        onPressed: _openSupportGroup,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipStatusStrip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final label =
        _session == null
            ? '当前状态：未登录'
            : _hasActiveMembership
            ? '当前状态：会员已生效'
            : '当前状态：未开通会员';
    final detail =
        _session == null
            ? '登录后可激活许可证并同步权益信息。'
            : _hasActiveMembership
            ? '可继续管理许可证、设备席位与会员权益。'
            : '可通过许可证激活会员，立即解锁完整能力。';
    return Container(
      margin: EdgeInsets.only(bottom: metrics.contentGap),
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _hasActiveMembership
                ? Icons.workspace_premium_outlined
                : Icons.info_outline_rounded,
            size: 18,
            color:
                _hasActiveMembership
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, {required bool loggedIn}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const accentColor = Color(0xFFB68A4D);
    const accentDeepColor = Color(0xFF8D6730);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '书享阅读',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                TextSpan(
                  text: ' PRO',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: accentDeepColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥68',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: accentDeepColor,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '¥88/永久',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '早鸟价',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accentDeepColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '解锁会员，享受最舒服的阅读体验',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontalInset = metrics.isCompactWindow ? 0.0 : metrics.pagePadding;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '高级会员权益',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 12),
          ..._featureItems.map((item) => _buildFeatureItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, _MembershipFeatureItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final accentColor = const Color(0xFFB68A4D);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: metrics.contentGap),
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.note != null && item.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '注意：${item.note!}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
        padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding),
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
                        entitlement!.displayLevel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasMembership
                            ? _buildEntitlementSummary(activeEntitlement!)
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
              _describeStatus(entitlement.vipStatus),
            ),
            _buildInfoRow(context, '权益来源', _describeSource(entitlement)),
            _buildInfoRow(context, '设备上限', '${entitlement.maxDevices} 台'),
            _buildInfoRow(context, '试用状态', entitlement.displayBenefitKind),
            if (entitlement.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entitlement.features
                    .map(
                      (feature) => Chip(
                        label: Text(_describeFeature(feature)),
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
    final metrics = AppAdaptiveMetrics.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.cardRadius + 8),
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding + 4),
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
              '激活会员',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '输入您获取的许可证码，即可开通或续期会员。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '许可证码',
                hintText: '例如：PRO-XXXX-XXXX',
                helperText: '许可证码通常以邮件或短信形式发送',
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
    final metrics = AppAdaptiveMetrics.of(context);
    final activeCount =
        seatSyncResult?.activeDeviceCount ??
        deviceSeats.where((item) => item.isActive).length;
    final maxDevices =
        seatSyncResult?.maxDevices ?? (entitlement?.maxDevices ?? 1);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.cardRadius + 8),
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding + 4),
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
              '设备管理',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '已授权 $activeCount 台设备，最多 $maxDevices 台',
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    activeCount >= maxDevices
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '您可以在这里管理已授权的设备，释放不再使用的设备席位。',
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
    await showAdaptiveActionSurface<void>(
      context: context,
      maxWidth: 520,
      builder: (surfaceContext) {
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
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: _buildRedeemCard(
                  surfaceContext,
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
    await showAdaptiveActionSurface<void>(
      context: context,
      maxWidth: 680,
      maxHeightFactor: 0.86,
      builder: (surfaceContext) {
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
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: _buildSeatCard(
                  surfaceContext,
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
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: metrics.contentGap),
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(metrics.cardRadius),
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
      case 'custom':
        return '自定义';
      default:
        return '月卡';
    }
  }

  String _buildEntitlementSummary(MembershipEntitlement entitlement) {
    final planLabel = _describePlan(entitlement.planType);
    final sourceLabel = entitlement.displaySourceLabel;
    final expireText =
        entitlement.expireAt == null &&
                entitlement.planType.toLowerCase() == 'lifetime'
            ? '永久有效'
            : entitlement.expireAt == null
            ? '长期有效'
            : '${_formatTime(entitlement.expireAt)} 到期';

    if (entitlement.isCampaignTrial) {
      return '当前为$sourceLabel，按$planLabel口径展示，$expireText。';
    }
    if (entitlement.isSystemTrial || entitlement.isTrial) {
      return '当前为$sourceLabel，$expireText。';
    }
    return '已开通$planLabel，$expireText。';
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

  String _describeSource(MembershipEntitlement? entitlement) {
    return entitlement?.displaySourceLabel ?? '-';
  }

  String _describeFeature(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'theme_custom':
        return '自定义主题';
      case 'online_service':
        return '在线服务';
      case 'advanced_rule':
        return '高级规则';
      case 'backup_restore':
        return '备份恢复';
      case 'ad_free':
        return '去广告';
      case 'priority_support':
        return '优先支持';
      case 'advanced_reader':
        return '高级阅读功能';
      default:
        return raw.trim().isEmpty ? '未知权益' : raw.trim();
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
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone:
          message.contains('失败') ? AppFeedbackTone.error : AppFeedbackTone.info,
      useHaptics: false,
    );
  }
}

class _MembershipMessages {
  static const String redeemSuccess = '激活成功，会员权益已生效';
  static const String trialSuccess = '试用领取成功，会员权益已生效';
  static const String trialFailed = '试用领取失败，请稍后重试';
  static const String seatReleased = '设备已释放，席位已空出';
  static const String redeemFailed = '激活失败，请检查许可证码';
  static const String seatReleaseFailed = '释放失败，请稍后重试';
  static const String loadFailed = '加载失败，请下拉刷新';
  static const String needLogin = '请先登录账号';
  static const String inputCode = '请输入许可证码';
}

class _MembershipFeatureItem {
  const _MembershipFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    this.note,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? note;
}

class _SupportActionButton extends StatelessWidget {
  const _SupportActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 64),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
