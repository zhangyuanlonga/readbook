import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'app.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  _configureImagePicker();
  PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
  runApp(const ProviderScope(child: App()));
}

void _configureImagePicker() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }
}
