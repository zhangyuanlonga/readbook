import 'package:shuxiang_reading_next/app/bootstrap.dart';
import 'package:shuxiang_reading_next/app/error_monitoring_bootstrap.dart';

Future<void> main() async {
  await runAppWithErrorMonitoring(bootstrap);
}

//  ```bash
// # 默认：auto + release
// ./scripts/build_unified_artifacts.sh

// # 在 macOS 上显式打 android + ios + macos
// ./scripts/build_unified_artifacts.sh android,ios,macos release

// ./scripts/build_unified_artifacts.sh android,macos debug
// # 只打 Android APK，并按 ABI 拆分

// ANDROID_TARGET=apk SPLIT_PER_ABI=1 ./scripts/build_unified_artifacts.sh android release
// ```

//  ```bash
// # Shorebird 热更新：当前移动端基线 1.3.0+26061101
// /Users/zhangyuanlong/.shorebird/bin/shorebird patch \
//   --platforms=android,ios \
//   --release-version=1.3.0+26061101 \
//   --no-codesign
// ```
