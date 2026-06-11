# 启动图设计方案

创建时间：2026-06-11  
设计风格：极简优雅、专业感强

---

## 一、设计理念

### 设计目标
- ✅ 极简纯净（纯白底色）
- ✅ 优雅精致（沿用桌面端字体风格）
- ✅ 品牌识别（Selune + CLEAR READING）
- ✅ 专业感强（类似高端阅读 APP）

### 设计参考
- 微信读书：纯白 + 品牌字体
- Apple Books：纯白 + 简洁标志
- Kindle：纯白 + 品牌 Logo

---

## 二、设计方案

### 视觉效果

```
┌────────────────────────────────┐
│                                │
│                                │
│                                │
│           Selune               │ ← Georgia 斜体加粗
│        CLEAR READING           │ ← 小号字母间距加宽
│                                │
│                                │
│                                │
│                                │
└────────────────────────────────┘

纯白背景 #FFFFFF
```

### 详细规格

#### 1. 背景
- **颜色：** `#FFFFFF` 纯白
- **无渐变、无图案**

#### 2. 主标题 "Selune"
- **字体：** Georgia（衬线字体）
- **样式：** 斜体（Italic）
- **粗细：** 700（Bold）
- **字号：** 48sp（移动端）/ 64sp（平板）
- **颜色：** `#1A1A1A`（深灰黑）
- **字母间距：** 0
- **行高：** 0.98

#### 3. 副标题 "CLEAR READING"
- **字体：** 系统默认（San Francisco / Roboto）
- **样式：** 全大写
- **粗细：** 700（Bold）
- **字号：** 11sp（移动端）/ 13sp（平板）
- **颜色：** `#666666`（中灰，透明度 68%）
- **字母间距：** 1.35
- **与主标题间距：** 8dp

#### 4. 布局
- **主标题位置：** 垂直居中，稍微偏上（-40dp）
- **水平居中**
- **副标题：** 紧跟主标题下方

---

## 三、代码实现

### Flutter 实现代码

```dart
// lib/app/widgets/app_splash_screen.dart

import 'package:flutter/material.dart';

class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    
    return Scaffold(
      backgroundColor: Colors.white, // 纯白背景
      body: Center(
        child: Transform.translate(
          offset: const Offset(0, -40), // 稍微偏上
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 主标题：Selune
              Text(
                'Selune',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: const ['Times New Roman', 'serif'],
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                  fontSize: isTablet ? 64.0 : 48.0,
                  color: const Color(0xFF1A1A1A),
                  height: 0.98,
                  letterSpacing: 0,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 副标题：CLEAR READING
              Text(
                'CLEAR READING',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isTablet ? 13.0 : 11.0,
                  color: const Color(0xFF666666).withOpacity(0.68),
                  letterSpacing: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 四、视觉效果预览

### ASCII 预览（竖屏）

```
╔════════════════════════════════╗
║                                ║
║                                ║
║                                ║
║                                ║
║           Selune               ║ 48sp, 斜体, 深灰黑
║        CLEAR READING           ║ 11sp, 全大写, 中灰
║                                ║
║                                ║
║                                ║
║                                ║
╚════════════════════════════════╝
```

### 设计要点说明

**1. 字体选择：**
- ✅ **Georgia** - 经典衬线字体，优雅、书卷气
- ✅ 斜体 - 增加流动感、艺术感
- ✅ 与桌面端左上角**完全一致**

**2. 颜色方案：**
- ✅ 纯白背景 - 纯净、专业
- ✅ 深灰黑主标题 - 不用纯黑（#000000），更柔和
- ✅ 中灰副标题 - 层次感，不抢主标题

**3. 布局哲学：**
- ✅ 居中但偏上 - 视觉重心舒适
- ✅ 极简 - 只有品牌名称，无其他元素
- ✅ 留白充足 - 呼吸感强

---

## 五、品牌一致性

### 与桌面端对比

**桌面端左上角（代码）：**
```dart
Text(
  'Selune',
  style: textTheme.headlineMedium?.copyWith(
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['Times New Roman', 'serif'],
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
    height: 0.98,
    letterSpacing: 0,
  ),
)
```

**启动图（新设计）：**
```dart
Text(
  'Selune',
  style: TextStyle(
    fontFamily: 'Georgia',           // ← 一致
    fontFamilyFallback: const [...], // ← 一致
    fontStyle: FontStyle.italic,     // ← 一致
    fontWeight: FontWeight.w700,     // ← 一致
    height: 0.98,                    // ← 一致
    letterSpacing: 0,                // ← 一致
    fontSize: 48.0,                  // ← 调整适配移动端
    color: const Color(0xFF1A1A1A),  // ← 深灰黑
  ),
)
```

**完全一致！** ✅

---

## 六、实现建议

### 集成位置

**方式1：替换原生启动屏（推荐）**
```
android/app/src/main/res/drawable/launch_background.xml
ios/Runner/Assets.xcassets/LaunchImage.imageset/
```

**方式2：Flutter 启动屏组件**
```dart
// 在 main.dart 首屏显示
MaterialApp(
  home: AppSplashScreen(), // 显示 1-2 秒后跳转
)
```

### 动画建议（可选）

**淡入效果（优雅）：**
```dart
// 主标题淡入 + 轻微上移
AnimatedOpacity(
  opacity: _visible ? 1.0 : 0.0,
  duration: Duration(milliseconds: 600),
  curve: Curves.easeOut,
  child: Text('Selune'),
)
```

**无动画（更简洁）：**
- 直接显示，无动画
- 更快进入应用

---

## 七、对比其他方案

### 方案A：当前设计（推荐）⭐⭐⭐⭐⭐

```
纯白背景
  Selune（斜体）
  CLEAR READING
```

**优点：**
- ✅ 极简纯净
- ✅ 品牌一致
- ✅ 优雅专业

---

### 方案B：加图标（不推荐）

```
纯白背景
  [📖 图标]
  Selune
  CLEAR READING
```

**缺点：**
- ⚠️ 不够极简
- ⚠️ 与桌面端不一致

---

### 方案C：渐变背景（不推荐）

```
白→灰渐变背景
  Selune
  CLEAR READING
```

**缺点：**
- ⚠️ 不够纯净
- ⚠️ 偏离极简理念

---

## 八、最终建议

### 推荐方案：方案A ⭐

**理由：**
1. ✅ 完美沿用桌面端字体风格
2. ✅ 纯白底色，纯净优雅
3. ✅ 品牌识别度高
4. ✅ 专业感强
5. ✅ 无需额外依赖（无 Lottie、无图标）

### 实施步骤

**Week 1：**
1. 创建 `AppSplashScreen` 组件
2. 集成到启动流程
3. 测试各平台效果

**预期效果：**
- 启动 → 纯白屏幕 → Selune（斜体） → 主页面
- 时长：1-1.5 秒
- 无动画（或淡入 0.6秒）

---

## 九、预期效果

### 用户感受
- 😊 "很优雅，像高端阅读 APP"
- 😊 "纯白很舒服，不刺眼"
- 😊 "Selune 这个字体好看"
- 😊 "专业感很强"

### 品牌印象
- ✅ 优雅
- ✅ 纯净
- ✅ 专业
- ✅ 书卷气

---

**最后更新：** 2026-06-11  
**设计师：** AI + 你的审美