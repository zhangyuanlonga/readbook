import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_settings_sheet.dart';

void main() {
  testWidgets('ReaderSettingsSheet renders basic controls and advanced group navigation', (
    tester,
  ) async {
    ReaderSettings? updatedSettings;
    ReaderSettingsSheetGroupKey? selectedGroup;
    ReaderSettingsSheetTab? selectedTab;
    var currentSettings = const ReaderSettings();
    var currentTab = ReaderSettingsSheetTab.basic;
    String? currentGroupKey;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: ReaderSettingsSheet(
                title: '设置',
                state: ReaderSettingsSheetState.fromSettings(
                  settings: currentSettings,
                  showInterfaceSettings: true,
                  activeTab: currentTab,
                  activeGroupKey: currentGroupKey,
                ),
                callbacks: ReaderSettingsSheetCallbacks(
                  onSettingsChanged: (settings) {
                    updatedSettings = settings;
                    setState(() {
                      currentSettings = settings;
                    });
                  },
                  onTabChanged: (tab) {
                    selectedTab = tab;
                    setState(() {
                      currentTab = tab;
                      currentGroupKey = null;
                    });
                  },
                  onAdvancedGroupChanged: (group) {
                    selectedGroup = group;
                    setState(() {
                      currentGroupKey =
                          group == null
                              ? null
                              : readerSettingsSheetGroupStorageKey(group);
                    });
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('主题'), findsOneWidget);
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(updatedSettings?.themeMode, ReaderThemeMode.dark);

    await tester.tap(find.text('高级设置'));
    await tester.pumpAndSettle();
    expect(selectedTab, ReaderSettingsSheetTab.advanced);

    await tester.tap(find.text('进入分组').first);
    await tester.pumpAndSettle();
    expect(selectedGroup, ReaderSettingsSheetGroupKey.typography);
  });
}
