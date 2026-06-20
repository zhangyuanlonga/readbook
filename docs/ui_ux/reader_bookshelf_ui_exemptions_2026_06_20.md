# Reader 与 Bookshelf UI 豁免记录

日期: 2026-06-20
范围: Phase 6 Reader/Bookshelf 外围迁移、blur 性能和固定视觉审计

## 1. 已完成迁移

- Bookshelf 分类/标签选择面板已接入 `AppSurface`、`AppTextField` 和 token 化 option chip。
- Bookshelf 初始 loading 已迁移到 `AppBlockingProgressCard`；empty、filtered empty、error 已继续使用状态组件族。
- Reader overlay bars 已统一 blur sigma 上限，loading spinner 已迁移到 `AppProgressIndicator`。
- Reader 自动阅读浮动提示已迁移到 `AppSurface`。
- Reader settings sheet 外围卡片已迁移到 `AppSurface`，保存中状态使用 `AppProgressIndicator`。
- Reader 章节缓存范围/进度面板已迁移到 `AppSurface` 和 `AppProgressIndicator`。

## 2. blur 性能约束

| 区域 | 当前策略 | 说明 |
|---|---|---|
| Reader 顶部/底部 overlay bar | `sigmaX/Y = 8` | 覆盖区域窄，跟随 overlay 显隐；不使用全屏 blur |
| Reader desktop 进度浮层 | `sigmaX/Y = 8` | 原 10 收敛到 8，限制 saveLayer 成本 |
| 旧 Reader overlay widget | `sigmaX/Y = 8` | 原 12 收敛到 8，避免路径切换后回退 |
| 高级主题应用背景 | 保留资源层策略 | 大图 blur 不在 Reader/Bookshelf 外围阶段扩大 |

验收口径:

- 默认配置不新增全屏 `BackdropFilter`。
- overlay blur 上限不超过 8，除非单独做 profile 记录。
- 低端设备或模拟器若出现滚动/显隐 jank，优先降 blur 或切换为半透明 surface。

## 3. 允许豁免项

| 豁免项 | 原因 | 复查 |
|---|---|---|
| Reader 内容渲染透明层 | 翻页、背景和文本合成需要固定透明语义 | 2026-09-20 |
| Reader overlay 黑色阴影/alpha | 任意阅读背景上需要固定对比度 | 2026-09-20 |
| Bookshelf/Reader 封面与内容图片本身 | 属于内容资产，不应被 App 主题强制改色 | 2026-09-20 |
| 书籍分类颜色 swatch | 用户内容标记颜色，属于数据资产 | 2026-09-20 |
| 书籍卡片复杂按压/长按 shell | 承载选择、打开、批处理状态，本阶段不重写手势边界 | 2026-09-20 |

## 4. 后续 Backlog

- Bookshelf toolbar、setting sheet 和 book card shell 可在下一轮继续评估 `AppSurface` 参数扩展。
- Reader overlay 的 gradient/alpha 可以后续沉到 `ReaderChromeTokens`，但不应影响当前阅读操作路径。
- 对长期保留的豁免项补 `UI-GOV-EXEMPT` 注释，脚本后续可识别并从 warning 中降级。
