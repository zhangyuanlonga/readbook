# 受管资源系统执行计划

更新时间：2026-04-28  
用途：作为阶段 4“资源系统统一”的唯一执行文档，统一资源引用模型、目录规则、迁移口径与后续落地顺序。  
总计划状态：`已完成专题`

关联文档：

- `docs/project_architecture_unification_plan.md`
- `docs/development_architecture_guardrails.md`
- `docs/cover_image_business_inventory.md`
- `docs/book_model_and_cover_business_inventory.md`

---

## 1. 目标

阶段 4 要解决的不是“再加几个背景/图集 service”，而是把当前已经存在的多套平行资源能力收成统一系统：

- 高级主题壁纸
- 应用背景 / 阅读背景
- 封面图集
- 启动图集
- 底栏图集
- 字体文件
- 自定义封面

统一后要求：

- 业务层不再直接扩散绝对路径
- 主题层只持有绑定关系，不直接管理底层文件路径
- 导入、删除、预览、迁移、引用校验、恢复能力走统一生命周期

---

## 2. 本轮完成范围

本轮已完成资源系统的完整收口，不再停留在“语义基线”。

本轮完成项：

- [x] 新建本专题文档
- [x] 定义统一资源模型：
  - `ManagedAssetRef`
  - `ManagedAssetCollection`
  - `ManagedAssetType`
  - `ManagedAssetScope`
  - `ManagedAssetRoot`
- [x] 定义统一目录策略：
  - `ManagedAssetDirectoryPolicy`
  - `ManagedAssetDirectoryPolicies`
- [x] 让 `ManagedFilePathResolver` 改为消费统一目录策略，而不是继续硬编码前缀
- [x] 新建 `ManagedAssetStore`，统一导入、相对化、绝对解析与删除入口
- [x] 让 `custom cover / cover gallery / launch image gallery / bottom nav icon / reader font` 改为相对持久化
- [x] 让 `reader preferences / app interface typography preferences` 不再持久化自定义字体绝对路径
- [x] 让 `AppAdvancedThemeModeConfig` 持有 `ManagedAssetRef` 绑定，而不是直接持久化壁纸路径
- [x] 让高级主题导入、复制、删除流程回到受管背景目录，而不是 theme 私有目录语义
- [x] 让本地封面与主题/图集消费端通过统一解析器恢复绝对路径

---

## 3. 统一语义

### 3.1 `ManagedAssetType`

表示资源内容本身的业务类型。

当前首批类型：

- `appBackground`
- `readerBackground`
- `coverGalleryImage`
- `launchImageGalleryImage`
- `bottomNavIcon`
- `readerFont`
- `customBookCover`
- `localBookArtifact`

### 3.2 `ManagedAssetScope`

表示资源归属与绑定语义，不表达底层目录。

当前首批 scope：

- `appAppearance`
- `readerAppearance`
- `bookshelfBook`
- `readingRecord`
- `themeBinding`
- `launchImage`
- `bottomNav`
- `typography`
- `localBook`

### 3.3 `ManagedAssetRef`

表达“某个业务对象引用了一个受管资源”。

它至少要能表达：

- 资源类型
- 资源 scope
- 所在根目录
- 相对路径
- 可选 collection id
- 可选 asset id
- 可选展示名

资源绑定 key 的语义：

- 稳定标识绑定关系
- 不直接等同于物理文件路径

### 3.4 `ManagedAssetCollection`

表达“一个图集 / 一组关联资源”。

典型对应：

- 封面图集
- 启动图集
- 底栏图集

---

## 4. 统一目录策略

资源目录不再靠各 service 私有约定维护，而是统一由策略表声明。

当前策略：

- `documents/backgrounds/`
- `documents/reader_backgrounds/`
- `documents/cover_galleries/`
- `documents/launch_image_galleries/`
- `support/bottom_nav_icon_galleries/`
- `support/reader_fonts/`
- `support/shuxiang_reading_next/custom_covers/`
- `support/local_books/`

兼容旧前缀：

- `custom_covers/`

要求：

- 后续新增受管资源目录，必须先加到策略表
- 路径迁移和解析只认策略表，不再到处散落前缀常量

---

## 5. 已落地约束

当前统一口径：

1. 受管资源的目录、相对路径与恢复规则只认 `ManagedAssetDirectoryPolicies`
2. 业务持久化层写入路径时，必须先经过 `ManagedAssetStore.relativizePersistedPath`
3. 消费端需要文件时，必须经过 `ManagedAssetStore` / `ManagedFilePathResolver` 恢复绝对路径
4. 高级主题模式配置只持有 `ManagedAssetRef` 绑定；`wallpaperPath / readerWallpaperPath` 仅保留兼容 getter
5. 新增受管资源目录或类型时，必须同时补策略表、测试和本专题文档

---

## 6. 验收口径

本专题最终完成时，应满足：

- 资源引用不再依赖各 feature 私有路径语义
- 迁移服务与路径解析只依赖统一目录策略
- 主题绑定字段与事实资源字段边界清楚
- 受管资源可以稳定迁移、恢复和校验
