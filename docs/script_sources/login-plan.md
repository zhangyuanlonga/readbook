# 登录态计划（归档）

这份文档保留为历史讨论记录，不代表当前主线设计，也不应作为现行规范参考。

当前主线已经明确：

- `browser` 是浏览器上下文能力
- `browser` 不等于 `login`
- 书源作者当前应优先围绕 `http / html / browser / cookie / cache / session` 写规则

这意味着本文件中的一些旧设想，例如：

- `ctx.browser.login(...)`
- “登录态”作为当前核心抽象

都不再是现阶段的正式方向。

如果你现在要写书源或理解当前系统，请改看：

1. [官方书源编写手册](./official-source-author-guide.md)
2. [书源规范 v1](./source-spec-v1.md)
3. [宿主运行时 API](./runtime-ctx-api.md)

保留此文件的唯一目的，是避免丢失历史设计讨论。
