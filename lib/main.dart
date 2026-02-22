import 'package:flutter_appread/app/bootstrap.dart';

void main() {
  bootstrap();
}
 

//  ```bash
// # 默认：auto + release
// ./scripts/build_unified_artifacts.sh

// # 在 macOS 上显式打 android + ios + macos
// ./scripts/build_unified_artifacts.sh android,ios,macos release

// # 只打 Android APK，并按 ABI 拆分
// ANDROID_TARGET=apk SPLIT_PER_ABI=1 ./scripts/build_unified_artifacts.sh android release
// ```