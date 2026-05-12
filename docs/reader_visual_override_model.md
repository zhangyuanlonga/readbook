# 阅读器视觉设置覆盖模型

更新时间：2026-04-29  
用途：统一“阅读器默认设置 / 高级主题 / 用户在阅读器内再次手动修改”之间的覆盖顺序、字段归属、持久化边界与迁移口径，避免再次出现“看起来没持久化，实际被别的层覆盖”的问题。

关联文档：

- `docs/product_experience_guide.md`
- `docs/engineering_guide.md`
- `docs/project_architecture_unification_plan.md`
- `docs/architecture_guard_automation_plan.md`
- `docs/archive/reader_settings_inventory_2026-04-25.md`

---

## 1. 结论先行

阅读器设置后续必须明确拆成 4 层，而不是继续把所有值混在一个 `ReaderSettings` 读写链里：

1. 系统默认值
2. 用户阅读习惯默认值
3. 高级主题视觉覆盖
4. 用户在阅读器里的手动视觉覆盖

一句话规则：

- **阅读习惯归用户默认设置**
- **视觉皮肤归高级主题**
- **阅读器里再次手动修改的视觉项优先级最高**
- **高级主题只能覆盖，不能反写基础设置**

最终解析顺序固定为：

```text
defaults
  -> persistedReaderPreferences
  -> advancedThemeVisualOverlay
  -> readerManualVisualOverrides
  -> sessionOnlyState
```

---

## 2. 当前问题判断

当前阅读器设置“退出再进像没保存”的问题，不是单一平台问题，而是 Flutter 侧覆盖模型不清楚导致的。

### 2.1 已确认的问题

#### 问题 A：App 主题反向覆盖阅读器主题

原实现中，阅读器启动和生命周期会把 `appThemeMode` 再回写到 `ReaderSettings.themeMode`。

影响：

- 用户在阅读器里改 `浅色 / 护眼 / 深色 / 纸张`
- 退出阅读器再进入
- 看起来像“设置没持久化”

当前状态：

- 该问题已在本轮修复，不再允许 app shell 主题反向覆盖 reader 自己的主题设置。

#### 问题 B：高级主题阅读背景覆盖阅读器本地背景

当前渲染入口中，只要高级主题配置了 `readerWallpaperPath`，就优先渲染主题阅读背景，而不是 `ReaderSettings.backgroundImageBase64`。

影响：

- 只有启用了高级主题阅读背景的用户会遇到
- 用户在阅读器里改“无背景 / 自定义背景 / 预设背景”
- 重进后看起来像“本地背景设置没生效”

#### 问题 C：高级主题阅读字体覆盖阅读器本地字体

当前 bootstrap 中，只要高级主题有 `readerFontFamilyKey`，就会把读取到的 `ReaderSettings.fontSource / fontFamilyKey / customFontPath` 替换为主题字体。

影响：

- 只有启用了高级主题阅读字体的用户会遇到
- 用户在阅读器里改正文字体
- 重进后看起来像“字体设置没生效”

### 2.2 这 3 个问题的共同根因

共同根因不是 SharedPreferences 失效，而是：

- 持久化层只负责保存 `ReaderSettings`
- 但启动期和渲染期又有其他来源覆盖它
- 且覆盖关系没有被建模为显式层级

结果就是：

- 数据“确实存了”
- 但展示时被别的层盖掉
- 用户体感仍然是“没保存”

---

## 3. 目标覆盖模型

### 3.1 层级定义

#### 第一层：系统默认值

来源：

- `const ReaderSettings()`

作用：

- 所有设置项的最底层兜底值

要求：

- 只作为兜底，不表达用户意图

#### 第二层：用户阅读习惯默认值

来源：

- `ReaderPreferencesService.saveSettings/loadSettings`

作用：

- 表达用户长期阅读习惯

典型字段：

- 字号
- 行距
- 段距
- 段首缩进
- 字距
- 翻页方式
- 翻页动画
- 音量键翻页
- 自动阅读速度
- 页脚信息项
- 页边距
- 章节头显示与偏移

要求：

- 这是用户的“长期默认偏好”
- 不应被 app 主题直接回写
- 不应被高级主题直接改写持久化值

#### 第三层：高级主题视觉覆盖

来源：

- `AppAdvancedTheme`
- 当前主要是 `readerWallpaperPath`
- 当前主要是 `readerFontFamilyKey`

作用：

- 表达主题给阅读器带来的视觉皮肤

要求：

- 只能作为“运行时覆盖”
- 不能直接写回 `ReaderPreferencesService`
- 关闭主题、切换主题后可以自然失效

#### 第四层：阅读器内手动视觉覆盖

来源：

- 用户已经启用了高级主题
- 但在阅读器里再次手动改了视觉项

作用：

- 表达“我现在就想用自己的视觉选择，而不是主题提供值”

要求：

- 优先级高于高级主题
- 必须单独持久化
- 不能再混回第二层的基础阅读习惯设置里

#### 第五层：会话态临时状态

来源：

- 自动阅读开启时临时强制滚动模式
- 临时亮度预览
- 临时弹层预览态

作用：

- 只影响当前阅读会话

要求：

- 不写回长期设置

---

## 4. 字段归属建议

### 4.1 应保留在“用户阅读习惯默认值”的字段

这些项应该继续长期保存在 `ReaderSettings` 主链中：

- `fontSize`
- `lineHeight`
- `paragraphSpacing`
- `paragraphIndent`
- `letterSpacing`
- `textFullJustifyEnabled`
- `textBottomJustifyEnabled`
- `pageTurnMode`
- `pageAnimationStyle`
- `volumeKeyPageEnabled`
- `autoReadSpeed`
- `switchSourceScoreRankingEnabled`
- `infoFooterEnabled`
- `infoShowTime`
- `infoShowBattery`
- `infoShowChapter`
- `infoShowProgress`
- `infoFooterPadding`
- `bodyMargin*`
- `showChapterHeader`
- `chapterHeader*`
- 漫画模式与图片间距等阅读行为项

原则：

- 这些项属于“阅读习惯”
- 不应该因为高级主题切换而改变

### 4.2 应归入“高级主题视觉覆盖”的字段

这些项更适合作为主题皮肤层：

- 阅读背景图
- 阅读字体绑定
- 未来若有阅读面专属纸张纹理、背景滤镜，也应归这里

原则：

- 这些项属于“主题视觉表达”
- 不属于用户阅读行为习惯

### 4.3 应归入“阅读器内手动视觉覆盖”的字段

这些项一旦在阅读器里被用户再次手动修改，就应形成比高级主题更高的 override：

- `themeMode`
- `backgroundStyle`
- `backgroundTone`
- `backgroundImageBase64`
- `fontSource`
- `fontFamilyKey`
- `customFontPath`
- `systemFontPreset`
- `bodyTextColorValue`
- `bodyTextItalicEnabled`
- `bodyTextShadow*`
- `bodyTextDecoration*`

原则：

- 这些项都直接影响阅读面最终观感
- 用户在阅读中再次手动调整时，应视为“我想暂时脱离主题接管”

---

## 5. 推荐优先级

### 5.1 最终解析规则

最终阅读器设置应按如下顺序解析：

```text
ReaderSettings resolved =
  defaults
  -> persistedReaderPreferences
  -> advancedThemeVisualOverlay
  -> readerManualVisualOverrides
  -> sessionOnlyState
```

### 5.2 具体示例

#### 示例 A：普通用户，无高级主题

结果：

- 直接使用 `persistedReaderPreferences`

#### 示例 B：用户设置了高级主题阅读背景

结果：

- 阅读背景来自高级主题
- 其他阅读习惯仍来自 `persistedReaderPreferences`

#### 示例 C：用户有高级主题，但在阅读器里又选了自己的背景

结果：

- 当前阅读背景应来自 `readerManualVisualOverrides`
- 高级主题背景退为次级来源

#### 示例 D：用户关闭自己的视觉覆盖

结果：

- 回退为高级主题视觉覆盖
- 若没有高级主题，再回退为基础持久化设置

---

## 6. 当前代码与目标模型的差距

### 6.1 现在的实际情况

当前代码里：

- `ReaderPreferencesService` 同时承担“阅读习惯 + 视觉值”的长期持久化
- bootstrap 又会读取高级主题并覆盖字体
- 渲染期又会读取高级主题并覆盖背景
- 覆盖层没有单独的数据模型

所以当前是：

```text
defaults
  -> persistedReaderPreferences
  -> hidden theme replacement in bootstrap/rendering
```

缺的就是：

- `readerManualVisualOverrides`
- 明确的视觉覆盖解析器
- 是否回退跟随主题的显式状态

### 6.2 当前最容易继续踩坑的点

1. 如果继续把高级主题值写回 `ReaderSettings`，就会污染用户基础默认值
2. 如果继续直接在渲染时覆盖背景，但没有 override 层，用户会继续觉得“没保存”
3. 如果字体覆盖只在 bootstrap 做，背景覆盖只在渲染期做，行为会继续不一致

---

## 7. 建议的数据模型

### 7.1 保留

- `ReaderSettings`
  继续作为“用户阅读习惯默认值”主模型

### 7.2 新增

建议新增单独模型，例如：

- `ReaderVisualOverrides`

建议字段：

- `themeMode`
- `backgroundStyle`
- `backgroundTone`
- `backgroundImageBase64`
- `fontSource`
- `fontFamilyKey`
- `customFontPath`
- `systemFontPreset`
- `bodyTextColorValue`
- `bodyTextItalicEnabled`
- `bodyTextShadow*`
- `bodyTextDecoration*`

要求：

- 字段都允许为空
- `null` 表示“未覆盖，继续跟随下层”

### 7.3 新增服务

建议新增：

- `ReaderSettingsResolutionService`

职责：

1. 读取 `ReaderSettings`
2. 读取高级主题视觉覆盖
3. 读取 `ReaderVisualOverrides`
4. 输出最终 `ResolvedReaderSettings`

要求：

- bootstrap 和 settings sheet 都只消费这一条统一解析链

---

## 8. 交互口径

### 8.1 用户第一次设置阅读器视觉项

如果当前没有高级主题：

- 直接写入 `ReaderSettings`

### 8.2 用户启用高级主题后

如果用户没有在阅读器里再手动改视觉项：

- 视觉上跟随高级主题

### 8.3 用户在高级主题生效后再次手动改视觉项

行为：

- 写入 `ReaderVisualOverrides`
- 立即覆盖高级主题视觉层

建议 UI 文案：

- “已覆盖当前高级主题的阅读视觉设置”

### 8.4 用户希望重新跟随高级主题

行为：

- 清除对应 `ReaderVisualOverrides`

建议 UI 动作：

- “恢复跟随主题”

---

## 9. 推荐落地顺序

### 第一阶段：先冻结覆盖规则

目标：

- 不再出现新的隐式覆盖

执行：

- [x] 清理 app theme 对 reader theme 的反向回写
- [x] 明确高级主题只作为视觉覆盖层
- [x] 明确阅读器视觉手动修改优先级高于高级主题

当前说明：

- 当前已先收口“阅读背景 / 阅读字体”两条现有高级主题覆盖链，不再允许主题值直接污染 `ReaderSettings` 基础持久化。

### 第二阶段：拆出视觉 override 模型

目标：

- 不再把所有视觉项混写回 `ReaderSettings`

执行：

- [x] 新增 `ReaderVisualOverrides`
- [x] 新增持久化 service
- [x] 新增 resolved settings 解析服务

当前说明：

- 当前 override 模型先覆盖“阅读背景 / 阅读字体”两类与高级主题直接重叠的视觉字段。

### 第三阶段：替换 bootstrap / rendering / settings sheet

目标：

- 所有入口统一走显式解析模型

执行：

- [x] bootstrap 不再直接改写主题字体到 `ReaderSettings`
- [x] 背景渲染不再隐式盖过用户本地视觉 override
- [x] settings sheet 视觉项改为写 override，而不是直接污染基础设置

当前说明：

- 当前“阅读背景 / 阅读字体”两条与高级主题直接冲突的视觉入口，已统一改为经 `ReaderSettingsResolutionService + ReaderVisualOverridesService` 解析与持久化。

### 第四阶段：补回归测试

目标：

- 把这次“看起来没持久化”的问题做成长期回归保护

执行：

- [x] 无高级主题时，阅读器视觉设置可重进恢复
- [x] 有高级主题时，主题视觉可覆盖基础设置
- [x] 有高级主题且用户手动覆盖后，手动值优先
- [x] 清除 override 后恢复跟随高级主题

当前说明：

- 已补：
  - `test/domain/entities/reader_visual_overrides_test.dart`
  - `test/features/reader/application/reader_visual_overrides_service_test.dart`
  - `test/features/reader/application/reader_settings_resolution_service_test.dart`
- 现有 `ReaderPreferencesService` / `ReaderThemeModeService` 回归也已一起验证通过。

---

## 10. 最终判断

最合理的模型不是：

- “高级主题一启用就把阅读器设置整体改写”

也不是：

- “阅读器里所有设置都永远高于高级主题”

最合理的是：

- **高级主题覆盖视觉皮肤**
- **阅读器默认设置保存阅读习惯**
- **用户在阅读器里再次手动改视觉项时，局部 override 高于高级主题**

这既符合用户直觉，也最容易解释和维护。
