# UI/UX 交互规范与动效指南

创建时间：2026-06-10  
配套文档：[UI/UX审计与设计系统](ui_ux_audit_and_design_system.md)

## 四、交互规范

### 4.1 操作反馈规范

#### 点击反馈

**移动端：**
- 所有可点击元素必须有视觉反馈
- 使用 InkWell 或 InkResponse
- 水波纹颜色：onSurface.withAlpha(0.12)
- 触摸目标最小：44x44dp

**桌面端：**
- 鼠标悬停：背景色加深 5%
- 点击：背景色加深 10%
- Cursor 改为 pointer

#### 加载状态

**全局加载：**
- 首屏加载：全屏 CircularProgressIndicator
- 居中显示，配文字"加载中..."

**局部加载：**
- 列表加载更多：底部小型 Indicator
- 刷新：下拉刷新组件
- 按钮加载：按钮内 Mini Indicator + 禁用

**加载失败：**
- 显示错误信息 + 重试按钮
- 网络错误、服务器错误分别提示

#### 操作结果反馈

**成功操作：**
- SnackBar 提示，绿色图标 ✓
- 3秒自动消失
- 示例："保存成功"、"删除成功"

**失败操作：**
- SnackBar 提示，红色图标 ✗
- 5秒自动消失或手动关闭
- 示例："保存失败：网络错误"

**中性提示：**
- SnackBar 提示，信息图标 ℹ
- 3秒自动消失
- 示例："已复制到剪贴板"

### 4.2 确认操作规范

#### 何时需要确认

**必须确认：**
- 删除操作（数据不可恢复）
- 清空操作（批量删除）
- 登出操作
- 重置操作
- 覆盖操作

**不需要确认：**
- 可撤销的操作（如移动、重命名）
- 低风险操作（如收藏、点赞）
- 导航操作

#### 确认方式

**移动端：**
- 轻度确认：底部弹层（BottomSheet）
- 重度确认：对话框（AlertDialog）
- 危险操作：需要输入确认文字

**桌面端：**
- 轻度确认：Popover
- 重度确认：Modal Dialog
- 危险操作：需要输入确认文字

**确认对话框结构：**
```dart
// 标题：简短动词短语
"删除书籍"

// 内容：说明后果
"删除后无法恢复，是否继续？"

// 按钮：
// - 左边：次要操作（取消）
// - 右边：主要操作（确定/删除）
[取消] [删除]  // 危险操作用红色
```

### 4.3 空状态与错误状态

#### 空状态

**设计原则：**
- 图标 + 标题 + 描述 + 行动建议
- 图标：64x64dp，使用品牌色或中性色
- 标题：简短，说明当前状态
- 描述：告诉用户为什么是空的
- 行动：提供下一步操作（如果有）

**示例：**
```text
📚 图标
还没有添加书籍
点击右上角"+"添加第一本书
[+ 添加书籍]
```

#### 错误状态

**网络错误：**
```text
🌐 无网络连接
请检查网络设置后重试
[重试]
```

**服务器错误：**
```text
⚠️ 加载失败
服务器暂时无法访问
[重试]
```

**权限错误：**
```text
🔒 需要登录
登录后查看更多内容
[去登录]
```

### 4.4 菜单与选择器

#### 更多菜单（overflow menu）

**移动端：**
- 使用底部弹层（BottomSheet）
- 每项高度：56dp
- 图标 + 文字
- 危险操作放最后，用红色

**桌面端：**
- 使用下拉菜单（PopupMenu）
- 每项高度：40dp
- 可以有快捷键提示
- 支持子菜单

**菜单项顺序：**
1. 主要操作（编辑、分享）
2. 次要操作（详情、设置）
3. 危险操作（删除）

#### 选择器

**单选：**
- 移动端：底部弹层 + Radio
- 桌面端：下拉菜单 Dropdown

**多选：**
- 移动端：底部弹层 + Checkbox
- 桌面端：弹出对话框 + Checkbox

**日期选择：**
- 使用系统日期选择器
- 自定义时提供快捷选项（今天、明天、下周）

### 4.5 搜索与筛选

#### 搜索框

**样式：**
- 高度：40dp
- 圆角：14dp
- 前缀图标：搜索 🔍
- 后缀：清除按钮（有内容时显示）

**交互：**
- 实时搜索：输入后 300ms 防抖
- 搜索历史：最多显示 10 条
- 清空历史：提供入口

**搜索结果：**
- 关键词高亮
- 无结果：显示空状态
- 建议：提供搜索建议

#### 筛选器

**移动端：**
- 入口：搜索框右侧"筛选"按钮
- 展开：底部弹层
- 结构：分类 + 选项

**桌面端：**
- 入口：侧边栏筛选面板
- 常驻显示
- 支持折叠分类

---

## 五、动效规范

### 5.1 动画时长标准

```dart
class AppDuration {
  // 超快速（微交互）
  static const instant = Duration(milliseconds: 100);
  
  // 快速（hover、点击反馈）
  static const fast = Duration(milliseconds: 200);
  
  // 标准（页面元素出现、消失）
  static const normal = Duration(milliseconds: 300);
  
  // 中速（页面过渡）
  static const medium = Duration(milliseconds: 400);
  
  // 慢速（复杂动画）
  static const slow = Duration(milliseconds: 600);
}
```

**使用原则：**
- 微交互：100ms（hover、涟漪）
- 元素出现/消失：200-300ms
- 页面过渡：300-400ms
- 复杂动画：400-600ms
- **不要超过 600ms**（用户会感觉慢）

### 5.2 动画曲线标准

```dart
class AppCurves {
  // 标准进入（元素出现）
  static const easeIn = Curves.easeIn;
  
  // 标准退出（元素消失）
  static const easeOut = Curves.easeOut;
  
  // 标准双向（通用）
  static const easeInOut = Curves.easeInOut;
  
  // 强调动画（品牌特色）
  static const emphasized = Cubic(0.4, 0.0, 0.2, 1.0);
  
  // 弹性动画（特殊场景）
  static const bounce = Curves.elasticOut;
}
```

**使用场景：**
- 元素淡入：easeOut
- 元素淡出：easeIn
- 位移动画：easeInOut
- 品牌动画：emphasized
- 成功反馈：bounce（轻微）

### 5.3 页面过渡动画

#### 移动端页面过渡

**forward（进入下级页面）：**
- 从右侧滑入
- 时长：300ms
- 曲线：easeInOut
- 上层页面左移并淡出

**back（返回上级页面）：**
- 向右滑出
- 时长：300ms
- 曲线：easeInOut
- 上层页面左滑入并淡入

**modal（弹出模态）：**
- 从底部滑入
- 时长：400ms
- 曲线：emphasized
- 背景遮罩淡入

**代码示例：**
```dart
PageRouteBuilder(
  transitionDuration: AppDuration.normal,
  pageBuilder: (context, animation, secondaryAnimation) => NextPage(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    final tween = Tween(begin: begin, end: end);
    final offsetAnimation = animation.drive(tween.chain(
      CurveTween(curve: AppCurves.easeInOut),
    ));
    return SlideTransition(position: offsetAnimation, child: child);
  },
);
```

#### 桌面端页面过渡

**推荐：** 淡入淡出（更符合桌面习惯）
- 时长：200ms
- 曲线：easeInOut
- 不要用滑动（桌面不是触摸屏）

### 5.4 微交互动画

#### 点击反馈动画

**按钮点击：**
```dart
AnimatedScale(
  scale: _pressed ? 0.95 : 1.0,
  duration: AppDuration.instant,
  child: YourButton(),
)
```

#### 加载动画

**旋转加载：**
- CircularProgressIndicator
- 无限循环
- 使用品牌色

**脉冲加载：**
```dart
AnimatedOpacity(
  opacity: _loading ? 0.5 : 1.0,
  duration: AppDuration.fast,
  child: YourWidget(),
)
```

#### 列表项动画

**新增项：**
- 淡入 + 轻微缩放
- 时长：300ms

**删除项：**
- 缩放到0 + 淡出
- 时长：300ms

**示例：**
```dart
AnimatedList(
  itemBuilder: (context, index, animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: YourListItem(),
      ),
    );
  },
)
```

### 5.5 品牌特色动画（月光感）

#### "月光划过"动画

**设计理念：**
- 柔和的光晕效果
- 从左到右缓慢划过
- 用于启动屏、欢迎页

**实现：**
```dart
AnimatedContainer(
  duration: AppDuration.slow,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment(-1.0 + _progress, 0),
      end: Alignment(1.0 + _progress, 0),
      colors: [
        Colors.transparent,
        Colors.white.withOpacity(0.1),
        Colors.transparent,
      ],
    ),
  ),
)
```

#### "月相变化"动画

**设计理念：**
- 圆形元素逐渐显示/隐藏
- 模拟月相变化
- 用于加载、切换状态

#### "星光闪烁"微交互

**设计理念：**
- 小型光点随机闪烁
- 背景装饰
- 不干扰主要内容

---

## 六、关键页面改进优先级

### P0 - 高频页面（立即改进）

#### 1. 书架页
- ❌ 问题：卡片样式不统一、空状态不友好
- ✅ 改进：统一卡片样式、优化空状态、添加骨架屏

#### 2. 搜索页
- ❌ 问题：搜索结果无动画、筛选入口不明显
- ✅ 改进：搜索结果淡入动画、优化筛选交互

#### 3. 阅读器
- ❌ 问题：进入/退出无过渡、设置面板突兀
- ✅ 改进：Hero 动画、设置面板滑入动画

#### 4. 我的页面
- ❌ 问题：入口图标不统一、层级不清晰
- ✅ 改进：统一图标风格、优化视觉层次

### P1 - 关键流程（尽快改进）

#### 5. 登录/注册
- ❌ 问题：表单缺少焦点动画、错误提示不友好
- ✅ 改进：输入框焦点动画、友好错误提示

#### 6. 书籍详情
- ❌ 问题：进入无Hero动画、信息展示平铺
- ✅ 改进：封面Hero动画、信息分层展示

#### 7. 设置页
- ❌ 问题：设置项排版乱、开关无动画
- ✅ 改进：分组优化、开关切换动画

### P2 - 体验优化（后续改进）

#### 8. 书源管理
- ❌ 问题：列表单调、操作反馈弱
- ✅ 改进：列表动画、操作确认优化

#### 9. 主题设置
- ❌ 问题：主题切换无过渡
- ✅ 改进：主题切换淡入淡出

#### 10. 关于页面
- ❌ 问题：信息堆砌、缺少品牌感
- ✅ 改进：信息分层、添加品牌动画

---
