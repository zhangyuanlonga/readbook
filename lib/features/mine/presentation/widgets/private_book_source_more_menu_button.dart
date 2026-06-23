import 'package:flutter/material.dart';

import '../../../../app/widgets/foundation/foundation.dart';
import '../../application/private_book_source_service.dart';

enum PrivateBookSourceMoreAction {
  detail,
  login,
  session,
  clearSession,
  test,
  submit,
  edit,
  delete,
}

class PrivateBookSourceMoreMenuRules {
  const PrivateBookSourceMoreMenuRules._();

  static bool canSubmit(PrivateBookSourceItem item) {
    return item.visibility == 'private';
  }

  static bool canEdit(PrivateBookSourceItem item) {
    return item.visibility != 'shared';
  }
}

class PrivateBookSourceMoreMenuButton extends StatelessWidget {
  const PrivateBookSourceMoreMenuButton({
    super.key,
    required this.item,
    required this.onDetail,
    required this.onLogin,
    required this.onSession,
    required this.onClearSession,
    required this.onTest,
    required this.onSubmit,
    required this.onEdit,
    required this.onDelete,
  });

  final PrivateBookSourceItem item;
  final VoidCallback onDetail;
  final VoidCallback onLogin;
  final VoidCallback onSession;
  final VoidCallback onClearSession;
  final VoidCallback onTest;
  final VoidCallback onSubmit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: AppMenuButton<PrivateBookSourceMoreAction>(
        tooltip: '更多',
        padding: EdgeInsets.zero,
        icon: Icons.more_vert_rounded,
        onSelected: (action) {
          switch (action) {
            case PrivateBookSourceMoreAction.detail:
              onDetail();
            case PrivateBookSourceMoreAction.login:
              onLogin();
            case PrivateBookSourceMoreAction.session:
              onSession();
            case PrivateBookSourceMoreAction.clearSession:
              onClearSession();
            case PrivateBookSourceMoreAction.test:
              onTest();
            case PrivateBookSourceMoreAction.submit:
              onSubmit();
            case PrivateBookSourceMoreAction.edit:
              onEdit();
            case PrivateBookSourceMoreAction.delete:
              onDelete();
          }
        },
        actions: [
          const AppMenuAction(
            value: PrivateBookSourceMoreAction.detail,
            label: '详情',
            icon: Icons.info_outline_rounded,
          ),
          const AppMenuAction(
            value: PrivateBookSourceMoreAction.login,
            label: '登录',
            icon: Icons.login_rounded,
          ),
          const AppMenuAction(
            value: PrivateBookSourceMoreAction.session,
            label: '登录状态',
            icon: Icons.verified_user_outlined,
          ),
          const AppMenuAction(
            value: PrivateBookSourceMoreAction.clearSession,
            label: '清除登录态',
            icon: Icons.delete_sweep_outlined,
          ),
          const AppMenuAction(
            value: PrivateBookSourceMoreAction.test,
            label: '检测',
            icon: Icons.science_outlined,
          ),
          AppMenuAction(
            value: PrivateBookSourceMoreAction.submit,
            label: '提交共享',
            icon: Icons.ios_share_outlined,
            enabled: PrivateBookSourceMoreMenuRules.canSubmit(item),
          ),
          AppMenuAction(
            value: PrivateBookSourceMoreAction.edit,
            label: '编辑',
            icon: Icons.edit_outlined,
            enabled: PrivateBookSourceMoreMenuRules.canEdit(item),
          ),
          const AppMenuAction(
            value: PrivateBookSourceMoreAction.delete,
            label: '删除',
            icon: Icons.delete_outline,
            destructive: true,
          ),
        ],
      ),
    );
  }
}
