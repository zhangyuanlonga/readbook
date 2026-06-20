import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_basic_section.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_bottom_nav_gallery_section.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_cover_gallery_section.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_font_section.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_launch_gallery_section.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_preview_panel.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_resource_picker_widgets.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_wallpaper_section.dart';

void main() {
  testWidgets('title starts editing and submits changed text', (tester) async {
    var editStarted = false;
    String? changed;
    String? submitted;
    final controller = TextEditingController(text: '初始主题');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: AdvancedThemeEditorTitle(
              isEditing: false,
              nameController: controller,
              title: '初始主题',
              onStartEditing: () => editStarted = true,
              onChanged: (value) => changed = value,
              onSubmitted: (value) => submitted = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('初始主题'));

    expect(editStarted, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: AdvancedThemeEditorTitle(
              isEditing: true,
              nameController: controller,
              title: '初始主题',
              onStartEditing: () => editStarted = true,
              onChanged: (value) => changed = value,
              onSubmitted: (value) => submitted = value,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '新主题');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(changed, '新主题');
    expect(submitted, '新主题');
  });

  testWidgets('wallpaper resource card exposes tap target and content', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdvancedThemeWallpaperResourceCard(
              title: '应用背景',
              subtitle: '已设置',
              badges: const <String>['高级主题引用', '当前主题'],
              preview: const Icon(Icons.image_outlined),
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('应用背景'));

    expect(tapped, isTrue);
    expect(find.text('已设置'), findsOneWidget);
    expect(find.text('高级主题引用'), findsOneWidget);
    expect(find.text('当前主题'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('cover and launch sections keep dedicated labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AdvancedThemeCoverGallerySection(
                subtitle: '未设置',
                badges: <String>['默认'],
                preview: SizedBox.shrink(),
                onTap: _noop,
              ),
              AdvancedThemeLaunchGallerySection(
                subtitle: '已设置',
                badges: <String>['高级主题引用'],
                preview: SizedBox.shrink(),
                onTap: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('书籍封面'), findsOneWidget);
    expect(find.text('启动图集'), findsOneWidget);
    expect(find.text('未设置'), findsOneWidget);
    expect(find.text('已设置'), findsOneWidget);
    expect(find.text('默认'), findsOneWidget);
    expect(find.text('高级主题引用'), findsOneWidget);
  });

  testWidgets('bottom nav and font sections expose style resource actions', (
    tester,
  ) async {
    var bottomNavTapped = false;
    var interfaceFontTapped = false;
    var readerFontTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AdvancedThemeBottomNavGallerySection(
                subtitle: '默认底栏',
                onTap: () => bottomNavTapped = true,
              ),
              AdvancedThemeFontSection(
                interfaceFontName: '界面字体 A',
                readerFontName: '阅读字体 B',
                onPickInterfaceFont: () => interfaceFontTapped = true,
                onPickReaderFont: () => readerFontTapped = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('底栏'));
    await tester.tap(find.text('界面字体'));
    await tester.tap(find.text('阅读字体'));

    expect(bottomNavTapped, isTrue);
    expect(interfaceFontTapped, isTrue);
    expect(readerFontTapped, isTrue);
    expect(find.text('默认底栏'), findsOneWidget);
    expect(find.text('界面字体 A'), findsOneWidget);
    expect(find.text('阅读字体 B'), findsOneWidget);
  });

  testWidgets('preview panel keeps decoration and constrained content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdvancedThemePreviewPanel(
            decoration: BoxDecoration(color: Colors.red),
            maxWidth: 240,
            child: SizedBox(width: 400, child: Text('编辑内容')),
          ),
        ),
      ),
    );

    final constrainedBox = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(AdvancedThemePreviewPanel),
        matching: find.byType(ConstrainedBox),
      ),
    );

    expect(find.text('编辑内容'), findsOneWidget);
    expect(constrainedBox.constraints.maxWidth, 240);
  });

  testWidgets('resource picker sheet keeps helper content and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedThemeResourcePickerSheet(
            title: '选择资源',
            helperText: '辅助说明',
            heightFactor: 0.5,
            content: const Text('资源列表'),
            actions: const <Widget>[
              TextButton(onPressed: null, child: Text('取消')),
              Spacer(),
              FilledButton(onPressed: null, child: Text('应用')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('选择资源'), findsOneWidget);
    expect(find.text('辅助说明'), findsOneWidget);
    expect(find.text('资源列表'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('应用'), findsOneWidget);
  });

  testWidgets('image selection grid reports selected path', (tester) async {
    String? selectedPath;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 420,
            child: AdvancedThemeImageSelectionGrid(
              imagePaths: const <String>['/tmp/a.png', '/tmp/b.png'],
              selectedPath: '/tmp/a.png',
              titleBuilder: (path) => path,
              onSelected: (path) => selectedPath = path,
              imageBuilder:
                  (_, path, __) => ColoredBox(
                    key: ValueKey<String>(path),
                    color: Colors.blue,
                  ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('/tmp/b.png')));

    expect(selectedPath, '/tmp/b.png');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}

void _noop() {}
