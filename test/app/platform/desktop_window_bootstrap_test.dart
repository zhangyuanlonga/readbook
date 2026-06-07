import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/layout/app_layout.dart';
import 'package:shuxiang_reading_next/app/platform/desktop_window_bootstrap.dart';

void main() {
  test('DesktopWindowBootstrap 最小窗口宽度允许验证 600dp 以下断点', () {
    expect(
      DesktopWindowBootstrap.minimumSize.width,
      lessThan(AppLayout.mediumBreakpointWidth),
    );
    expect(DesktopWindowBootstrap.minimumSize.height, greaterThanOrEqualTo(600));
  });

  test('DesktopWindowBootstrap 初始窗口仍按常规桌面尺寸启动', () {
    expect(
      DesktopWindowBootstrap.initialSize.width,
      greaterThanOrEqualTo(AppLayout.desktopBreakpointWidth),
    );
    expect(
      DesktopWindowBootstrap.initialSize.height,
      greaterThan(DesktopWindowBootstrap.minimumSize.height),
    );
  });
}
