import 'package:flutter/foundation.dart';

/// Android 上默认不自动聚焦文本输入，避免页面/弹层打开时直接拉起输入法。
bool get appEnableAutoFocusForTextInput =>
    kIsWeb || defaultTargetPlatform != TargetPlatform.android;
