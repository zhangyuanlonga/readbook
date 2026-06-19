import 'package:flutter/material.dart';

import 'book_detail_primary_actions.dart';
import 'book_detail_sections.dart';

class BookDetailQuickActionsState {
  const BookDetailQuickActionsState({
    required this.isInBookshelf,
    required this.isShelfStateLoading,
    required this.isShelfActionLoading,
    required this.hasCatalog,
    required this.isCatalogLoading,
    required this.hasLoadedResult,
    required this.canSwitchSource,
  });

  final bool isInBookshelf;
  final bool isShelfStateLoading;
  final bool isShelfActionLoading;
  final bool hasCatalog;
  final bool isCatalogLoading;
  final bool hasLoadedResult;
  final bool canSwitchSource;

  bool get canOpenCatalog => hasCatalog && hasLoadedResult;

  bool get isCatalogEnabled => hasCatalog && !isCatalogLoading;

  bool get isOrganizeEnabled => isInBookshelf;
}

class BookDetailQuickActionsPresenter extends StatelessWidget {
  const BookDetailQuickActionsPresenter({
    super.key,
    required this.state,
    required this.onToggleBookshelf,
    required this.onOpenCatalog,
    required this.onSwitchSource,
    required this.onOpenOrganize,
  });

  final BookDetailQuickActionsState state;
  final VoidCallback onToggleBookshelf;
  final VoidCallback onOpenCatalog;
  final VoidCallback onSwitchSource;
  final VoidCallback onOpenOrganize;

  @override
  Widget build(BuildContext context) {
    return BookDetailQuickActionsCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return BookDetailPrimaryActions(
            availableWidth: constraints.maxWidth,
            isInBookshelf: state.isInBookshelf,
            isShelfStateLoading: state.isShelfStateLoading,
            isShelfActionLoading: state.isShelfActionLoading,
            onToggleBookshelf: onToggleBookshelf,
            onOpenCatalog: state.canOpenCatalog ? onOpenCatalog : null,
            isCatalogEnabled: state.isCatalogEnabled,
            onSwitchSource: state.canSwitchSource ? onSwitchSource : null,
            isSwitchSourceEnabled: state.canSwitchSource,
            onOpenOrganize: onOpenOrganize,
            isOrganizeEnabled: state.isOrganizeEnabled,
          );
        },
      ),
    );
  }
}
