# 启动屏集成指南

创建时间：2026-06-11  
文件：`lib/app/widgets/app_splash_screen.dart`

---

## 快速集成

### 方式1：在启动流程中使用

```dart
// lib/main.dart 或启动入口

import 'package:flutter/material.dart';
import 'app/widgets/app_splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _showSplash
          ? AppSplashScreen(
              onComplete: () {
                setState(() {
                  _showSplash = false;
                });
              },
            )
          : const HomePage(), // 你的主页面
    );
  }
}
```

---

### 方式2：与现有启动逻辑集成

```dart
// 如果你已经有启动初始化逻辑

class AppStartupPage extends StatefulWidget {
  const AppStartupPage({super.key});

  @override
  State<AppStartupPage> createState() => _AppStartupPageState();
}

class _AppStartupPageState extends State<AppStartupPage> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 你的初始化逻辑（加载配置、数据等）
    await Future.wait([
      _loadConfig(),
      _loadUserData(),
      Future.delayed(const Duration(milliseconds: 1500)), // 最少显示 1.5s
    ]);

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return AppSplashScreen(
        onComplete: () {
          // 可选：额外的完成回调
        },
      );
    }

    // 初始化完成后导航到主页
    return const HomePage();
  }
}
```

---

## 自定义配置

### 修改显示时长

```dart
// lib/app/widgets/app_splash_screen.dart

// 找到这一行（第 36 行）：
Future.delayed(const Duration(milliseconds: 1500), () {

// 修改为你想要的时长：
Future.delayed(const Duration(milliseconds: 2000), () { // 2秒
```

### 修改淡入速度

```dart
// 找到这一行（第 25 行）：
duration: const Duration(milliseconds: 800),

// 修改为：
duration: const Duration(milliseconds: 600), // 更快
// 或
duration: const Duration(milliseconds: 1000), // 更慢
```

---

## 效果说明

### 动画时序

```
0ms     ────────────────────────────────> 1500ms
        │                                │
        │ 淡入 (0-800ms)                │ 完成
        │   opacity: 0 → 1               │
        │   curve: easeOut               │
        └────────────────────────────────┘
```

### 视觉效果

1. **0ms** - 纯白屏幕，文字完全透明
2. **0-800ms** - 文字淡入（easeOut 曲线）
3. **800-1500ms** - 完全显示
4. **1500ms** - 调用 `onComplete()`，进入主页

---

## 测试清单

### 功能测试

- [ ] 启动显示启动屏
- [ ] 1.5 秒后自动跳转
- [ ] 淡入动画流畅
- [ ] 各平台显示正常

### 视觉测试

- [ ] 纯白背景正确
- [ ] 字体显示正确（Georgia 斜体）
- [ ] 字号适配（手机 48sp / 平板 64sp）
- [ ] 颜色正确（深灰黑 + 中灰）
- [ ] 位置居中偏上

### 平台测试

- [ ] Android 真机
- [ ] iOS 真机
- [ ] Web 浏览器
- [ ] Desktop（macOS/Windows）

---

## 常见问题

### Q: 如何禁用淡入动画？

**A:** 修改 `_controller.forward()` 为立即完成：

```dart
_controller.value = 1.0; // 直接设为完成状态
```

### Q: 如何延长显示时间？

**A:** 修改 `Future.delayed` 的时长：

```dart
Future.delayed(const Duration(milliseconds: 2500), () { // 2.5秒
```

### Q: 如何等待初始化完成？

**A:** 使用方式2，在 `_initialize()` 中处理初始化逻辑

---

## 文件结构

```
lib/
  └── app/
      └── widgets/
          └── app_splash_screen.dart  ← 启动屏组件
```

---

## 依赖

**无需任何外部依赖！**

- ✅ 使用 Flutter 内置动画
- ✅ 使用系统自带字体（Georgia）
- ✅ 纯白背景无需资源文件

---

**最后更新：** 2026-06-11