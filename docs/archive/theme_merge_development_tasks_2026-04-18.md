# 颜色并入高级主题开发任务（2026-04-18）

## 1. 目标

把当前外观里的 `颜色` 能力，逐步并入 `高级主题`，但不是搬入口，而是把颜色背后的大覆盖域能力吸收到高级主题里。

最终方向：

- `模式` 保持独立
- `颜色` 不再作为独立系统存在
- `高级主题` 同时具备：
  - 基础主题层能力
  - 精细覆盖层能力

## 2. 开发边界

这轮开发必须严格控制范围，不额外延伸。

### 明确只做

- 调查颜色层与高级主题层作用域
- 定义高级主题里的“基础主题层 / 精细覆盖层”
- 让高级主题编辑器承接颜色的大覆盖域能力
- 逐步让外层页面从基础 `colorScheme` 切到高级主题运行态

### 明确不做

- 不改 `主题模式`
- 不改阅读器正文主题体系
- 不改 `高级主题` 名称
- 不新增官方预设主题体系
- 不把色板方案搬进高级主题
- 不重写底层存储模型
- 不顺手处理无关业务

### 执行规则

- 如果发现新的“顺手做更完整”的想法，默认不纳入本轮
- 必须先完成当前阶段验证，再进入下一阶段

## 3. 当前事实基线

当前已明确：

- `颜色` 是全局基础主题层
- `高级主题` 已经有较完整的精细设置项
- 两者当前重叠在：
  - 强调体系
  - 表面/容器体系
  - 边框体系

基线文档：

- [theme_color_advanced_scope_map_2026-04-18.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/theme_color_advanced_scope_map_2026-04-18.md)
- [theme_merge_plan_2026-04-18.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/theme_merge_plan_2026-04-18.md)

## 4. 分阶段任务

## 第一阶段：作用域映射确认

目标：

- 把“颜色层”和“高级主题层”当前控制什么彻底确认下来
- 作为后续改造的唯一事实基线

任务清单：

- [x] 梳理颜色层当前真实覆盖范围
- [x] 梳理高级主题层当前设置项
- [x] 梳理高级主题层当前真实生效页面
- [x] 归纳颜色层与高级主题层重叠区
- [x] 归纳断层区
- [x] 输出作用域映射文档

交付物：

- [theme_color_advanced_scope_map_2026-04-18.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/theme_color_advanced_scope_map_2026-04-18.md)

## 第二阶段：结构定义

目标：

- 明确高级主题内部要分成哪两层
- 不急着大改代码，先把结构定义清楚

任务清单：

- [x] 明确哪些项属于“基础主题层”
- [x] 明确哪些项属于“精细覆盖层”
- [x] 明确哪些现有字段可直接复用
- [x] 明确哪些页面后续优先切换到基础主题层
- [x] 把结构定义回写到方案文档

完成标准：

- 团队能用一句话说清：
  - 颜色层原来负责什么
  - 高级主题未来如何同时承接基础主题层和精细覆盖层

## 第三阶段：编辑器分组重构

目标：

- 高级主题编辑器不再只是“细碎改色”
- 而是能承接新版两层结构

任务清单：

- [x] 调整编辑器分组为：
  - [x] 基础主题层
  - [x] 精细覆盖层
  - [x] 资源层
- [x] 保留手动配置具体颜色项的方式
- [x] 不新增“几个颜色方案让用户选”的替代 UI
- [x] 保留浅色 / 深色双配置
- [x] 明确“回填当前基础主题结果”的行为和范围

完成标准：

- 用户能在高级主题编辑器里理解：
  - 哪些颜色是在定整体风格
  - 哪些颜色是在精修局部块

## 第四阶段：运行态接管基础主题层

目标：

- 让高级主题真正开始承接颜色层的大覆盖域能力

任务清单：

- [x] 确定运行态解析顺序
- [x] 先让高级主题接管外层页面的基础强调体系
- [x] 再接管外层页面的大面积表面/容器体系
- [x] 再接管外层页面的边框体系
- [x] 保持高级主题的精细覆盖层继续有效

范围限制：

- 只做外层页面
- 不做阅读器正文

## 第五阶段：页面切换实施

目标：

- 先只覆盖底部导航栏四个一级大页面
- 其他内部页面后续再说，不纳入当前阶段

优先页面：

- [bookshelf_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart)
- [discover_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/discover/presentation/discover_page.dart)
- [reading_records_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reading_records_page.dart)
- [mine_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/mine_page.dart)

任务清单：

- [ ] 收口 `primary / primaryContainer / onPrimaryContainer` 直连使用点
- [ ] 收口 `surfaceContainer*` 直连使用点
- [ ] 收口 `outline / outlineVariant` 直连使用点
- [ ] 优先迁移选中态 / badge / pill
- [ ] 优先迁移输入框 / 容器 / 卡片边框

本阶段明确不做：

- 不处理底部四个一级页面之外的内部页
- 不处理阅读器正文和阅读器内功能

## 第六阶段：验证与收尾

目标：

- 确保新版主题结构稳定可测

任务清单：

- [ ] 更新方案文档
- [ ] 更新审计文档
- [ ] `flutter analyze` 通过
- [ ] 主题相关测试通过
- [ ] 补最小必要的回归测试：
  - [ ] 搜索页主题状态色
  - [ ] 发现页分类/按钮
  - [ ] 书架页 badge/阴影/选中态
  - [ ] 编辑器预览与运行态一致性
- [ ] 做一轮人工核对：
  - [ ] 书架
  - [ ] 发现
  - [ ] 搜索
  - [ ] 我的
  - [ ] 高级主题编辑器

## 5. 当前建议执行顺序

为了不再跑偏，建议严格按下面顺序执行：

1. 第一阶段已完成
2. 先完成第二阶段结构定义
3. 再做第三阶段编辑器分组
4. 再做第四阶段运行态接管
5. 然后第五阶段页面迁移
6. 最后第六阶段验证收尾

## 6. 一句话版本

先定义“颜色层的大覆盖域能力”怎么归入高级主题，再让高级主题逐步接管外层页面；先结构，后实现，最后验证，不无限延伸。
