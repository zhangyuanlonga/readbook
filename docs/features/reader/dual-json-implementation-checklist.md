# 书源双JSON存储 - 阶段性实施计划

**项目目标：** 实现书源原始JSON + 规整JSON双存储，提升兼容性到100%  
**预计工期：** 2-3天  
**当前状态：** 待启动  

---

## 📊 总览

| 阶段 | 任务数 | 预计工期 | 状态 |
|------|--------|---------|------|
| 阶段0：准备工作 | 3个 | 0.5天 | ⬜ 未开始 |
| 阶段1：Rust规整化接口 | 5个 | 1天 | ⬜ 未开始 |
| 阶段2：Go端集成 | 6个 | 1天 | ⬜ 未开始 |
| 阶段3：数据迁移 | 3个 | 0.5天 | ⬜ 未开始 |
| 阶段4：Flutter前端 | 4个 | 0.5天 | ⬜ 未开始 |
| 阶段5：测试验证 | 5个 | 0.5天 | ⬜ 未开始 |
| 阶段6：上线部署 | 4个 | 0.5天 | ⬜ 未开始 |

---

## 🎯 阶段0：准备工作（0.5天）

### 任务清单

- [ ] **0.1 理解背景和方案**
  - 阅读 `dual-json-implementation-guide-for-gpt.md`
  - 理解双JSON存储的核心思路
  - 确认三个关键文件路径

- [ ] **0.2 环境准备**
  - 确认Rust项目可编译：`cd reader-rust-master && cargo build`
  - 确认Go项目可编译：`cd read-admin && go build`
  - 确认Flutter项目可运行：`cd flutterreadbook && flutter run`

- [ ] **0.3 创建分支**
  ```bash
  cd reader-rust-master
  git checkout -b feature/dual-json-storage
  
  cd read-admin
  git checkout -b feature/dual-json-storage
  
  cd flutterreadbook
  git checkout -b feature/dual-json-storage
  ```

**验收标准：**
- ✅ 三个项目都能正常编译/运行
- ✅ 已创建功能分支

---

## 🦀 阶段1：Rust规整化接口（1天）

### 任务清单

- [ ] **1.1 创建normalize.rs文件**
  - 文件路径：`reader-rust-master/src/api/normalize.rs`
  - 复制实施指南中的代码（步骤2.1）
  - 定义 `NormalizeRequest` 和 `NormalizeResponse` 结构

- [ ] **1.2 实现规整化核心逻辑**
  - 实现 `normalize_book_source` 函数
  - 解析原始JSON到 `BookSource`
  - 重新序列化为规整版本
  - 计算兼容性评分

- [ ] **1.3 实现字段转换检测**
  - 实现 `detect_field_conversions` 函数
  - 检测20+个字段的类型转换
  - 生成 `FieldWarning` 列表

- [ ] **1.4 注册路由**
  - 修改 `src/api/mod.rs`
  - 添加 `pub mod normalize;`
  - 注册路由：`/api/normalize`

- [ ] **1.5 编写测试**
  - 创建 `tests/normalize_test.rs`
  - 测试简单书源（无警告）
  - 测试复杂书源（有警告）
  - 测试无效JSON（返回is_valid=false）
  ```bash
  cargo test normalize
  ```

**验收标准：**
- ✅ `cargo build` 编译通过
- ✅ `cargo test normalize` 测试通过
- ✅ 手动测试接口返回正确

**验收命令：**
```bash
# 启动Rust服务
cargo run

# 测试接口（另一个终端）
curl -X POST http://localhost:8080/api/normalize \
  -H "Content-Type: application/json" \
  -d '{"source_json": "{\"bookSourceName\":\"测试\",\"bookSourceUrl\":\"https://test.com\",\"loginUi\":{\"type\":\"web\"}}"}'

# 预期：返回normalized_json和warnings
```

---

## 🐹 阶段2：Go端集成（1天）

### 任务清单

- [ ] **2.1 数据库迁移**
  - 创建迁移文件：`migrations/XXXXXX_add_normalized_fields.sql`
  - 添加字段：
    ```sql
    ALTER TABLE book_sources 
      ADD COLUMN source_json_normalized TEXT,
      ADD COLUMN normalization_warnings TEXT;
    ```
  - 执行迁移：`go run cmd/migrate/main.go`

- [ ] **2.2 更新Go数据模型**
  - 文件：`internal/domain/booksource/entity.go`
  - 添加字段：
    ```go
    SourceJSONNormalized  string `json:"source_json_normalized" db:"source_json_normalized"`
    NormalizationWarnings string `json:"normalization_warnings" db:"normalization_warnings"`
    ```

- [ ] **2.3 创建normalize.go**
  - 文件：`internal/application/booksource/normalize.go`
  - 定义 `NormalizeRequest`、`NormalizeResponse`、`FieldWarning`
  - 实现 `FormatWarnings()` 方法

- [ ] **2.4 实现调用Rust接口**
  - 在 `service.go` 中实现 `normalizeSourceJSON` 方法
  - HTTP POST调用 `rustGatewayURL + "/api/normalize"`
  - 解析响应
  - 添加超时保护（5秒）

- [ ] **2.5 修改创建书源逻辑**
  - 修改 `CreatePrivateSource` 方法
  - 保存原始JSON到 `source_json`
  - 调用规整化接口
  - 保存规整后的JSON到 `source_json_normalized`
  - 保存警告信息到 `normalization_warnings`
  - **关键：规整化失败不阻止创建**

- [ ] **2.6 修改使用书源逻辑**
  - 修改 `rust_gateway.go` 中的所有方法：
    - `SearchBooks`
    - `GetBookDetail`
    - `GetChapterList`
    - `GetChapterContent`
  - 优先使用 `source_json_normalized`
  - 如果为空，回退到 `source_json`

**验收标准：**
- ✅ `go build` 编译通过
- ✅ `go test ./internal/application/booksource/...` 测试通过
- ✅ 数据库字段已添加

**验收测试：**
```bash
# 创建一个测试书源（通过API或命令行）
# 检查数据库
SELECT 
  name, 
  LENGTH(source_json) as original_len,
  LENGTH(source_json_normalized) as normalized_len,
  normalization_warnings
FROM book_sources 
WHERE id = 'test_id';

# 预期：normalized_len > 0, warnings 可能有值
```

---

## 🔄 阶段3：数据迁移（0.5天）

### 任务清单

- [ ] **3.1 创建迁移脚本**
  - 文件：`read-admin/cmd/migrate_normalize/main.go`
  - 复制实施指南中的代码（步骤4.1）
  - 实现批量规整化逻辑

- [ ] **3.2 测试迁移脚本**
  - 在测试数据库上运行
  ```bash
  go build -o bin/migrate_normalize cmd/migrate_normalize/main.go
  ./bin/migrate_normalize --dry-run
  ```
  - 检查日志输出
  - 确认不会出错

- [ ] **3.3 执行正式迁移**
  - 备份数据库
  ```bash
  mysqldump -u user -p database > backup.sql
  ```
  - 执行迁移
  ```bash
  ./bin/migrate_normalize
  ```
  - 验证结果
  ```sql
  SELECT 
    COUNT(*) as total,
    COUNT(source_json_normalized) as normalized_count,
    COUNT(normalization_warnings) as with_warnings
  FROM book_sources;
  ```

**验收标准：**
- ✅ 迁移脚本无错误
- ✅ 80%以上的书源已规整化
- ✅ 数据库备份已保存

---

## 📱 阶段4：Flutter前端（0.5天）

### 任务清单

- [ ] **4.1 更新数据模型**
  - 文件：`lib/features/mine/domain/entities/book_source.dart`
  - 添加字段：
    ```dart
    final String? sourceJsonNormalized;
    final String? normalizationWarnings;
    ```
  - 更新序列化代码

- [ ] **4.2 创建警告横幅组件**
  - 文件：`lib/shared/widgets/compatibility_warning_banner.dart`
  - 复制实施指南中的代码（步骤5.2）
  - 实现警告解析和显示

- [ ] **4.3 修改书源详情页**
  - 文件：`lib/features/mine/presentation/private_book_source_detail_page.dart`
  - 添加警告横幅显示
  - 显示原始JSON编辑器

- [ ] **4.4 修改书源列表页**
  - 文件：`lib/features/mine/presentation/widgets/book_source_card.dart`
  - 添加警告徽章图标
  - 检测失败的书源显示提示

**验收标准：**
- ✅ `flutter analyze` 无错误
- ✅ UI正确显示警告信息
- ✅ 可以编辑原始JSON

**验收测试：**
1. 导入一个复杂书源
2. 进入详情页，看到警告横幅
3. 编辑JSON，保存后警告更新

---

## 🧪 阶段5：测试验证（0.5天）

### 任务清单

- [ ] **5.1 单元测试**
  - Rust测试：`cd reader-rust-master && cargo test`
  - Go测试：`cd read-admin && go test ./...`
  - 确保所有测试通过

- [ ] **5.2 集成测试**
  - 测试用例1：简单书源（无警告）
    - 创建 → 检查数据库 → 使用搜索
  - 测试用例2：复杂书源（有警告）
    - 创建 → 检查警告 → 使用搜索
  - 测试用例3：编辑书源
    - 编辑JSON → 保存 → 检查重新规整化

- [ ] **5.3 性能测试**
  - 测试规整化耗时
  ```bash
  # 测试100次规整化
  for i in {1..100}; do
    time curl -X POST http://localhost:8080/api/normalize ...
  done
  ```
  - 确认平均 <100ms

- [ ] **5.4 边界测试**
  - 测试Rust服务挂掉（降级到原始JSON）
  - 测试超大JSON（>1MB）
  - 测试无效JSON

- [ ] **5.5 用户体验测试**
  - [ ] 导入30%会失败的书源 → 现在都能成功
  - [ ] 查看警告提示 → 清晰易懂
  - [ ] 使用书源搜索 → 正常工作
  - [ ] 编辑书源 → 正常保存

**验收标准：**
- ✅ 所有测试通过
- ✅ 性能符合预期
- ✅ 边界情况处理正确

---

## 🚀 阶段6：上线部署（0.5天）

### 任务清单

- [ ] **6.1 准备发布**
  - [ ] 合并代码到主分支
  - [ ] 打Tag：`v1.x.x-dual-json`
  - [ ] 编写发布说明

- [ ] **6.2 部署Rust服务**
  - [ ] 构建镜像：`docker build -t reader-rust:v1.x.x`
  - [ ] 部署到测试环境
  - [ ] 验证 `/api/normalize` 接口可用
  - [ ] 部署到生产环境

- [ ] **6.3 部署Go服务**
  - [ ] 执行数据库迁移
  - [ ] 构建镜像：`docker build -t read-admin:v1.x.x`
  - [ ] 灰度发布（10% → 50% → 100%）
  - [ ] 监控错误率和规整化成功率

- [ ] **6.4 发布Flutter版本**
  - [ ] 构建Android APK
  - [ ] 构建iOS IPA
  - [ ] 发布到应用商店/内测渠道
  - [ ] 更新用户文档

**验收标准：**
- ✅ 所有服务正常运行
- ✅ 监控指标正常
- ✅ 用户可以正常使用

---

## 📋 补充任务（可选）

### 监控和优化

- [ ] **补充1：添加监控指标**
  ```go
  metrics.RecordNormalizeDuration(duration)
  metrics.RecordNormalizeSuccess(success)
  metrics.RecordWarningRate(len(warnings))
  ```

- [ ] **补充2：编辑时重新规整化**
  ```go
  func UpdatePrivateSource(...) {
    if sourceJSON changed {
      re-normalize()
    }
  }
  ```

- [ ] **补充3：书源可见性优化**
  - 检测失败的书源也显示（但标记）
  - 按检测状态排序
  - 实施指南附录B中的代码

---

## 📊 进度跟踪

### 当前状态
- 总进度：0/30 任务完成（0%）
- 当前阶段：⬜ 阶段0：准备工作
- 预计完成时间：未开始

### 每日更新（示例）

**Day 1 (2026-06-12)**
- ✅ 阶段0：准备工作（3/3）
- ✅ 阶段1：Rust接口（5/5）
- ⏳ 阶段2：Go集成（2/6）

**Day 2 (2026-06-13)**
- ✅ 阶段2：Go集成（6/6）
- ✅ 阶段3：数据迁移（3/3）
- ⏳ 阶段4：Flutter前端（2/4）

**Day 3 (2026-06-14)**
- ✅ 阶段4：Flutter前端（4/4）
- ✅ 阶段5：测试验证（5/5）
- ✅ 阶段6：上线部署（4/4）

---

## 🎯 关键里程碑

- [ ] **里程碑1：Rust接口可用**（Day 1结束）
  - 规整化接口正常工作
  - 测试通过

- [ ] **里程碑2：Go端集成完成**（Day 2结束）
  - 创建书源自动规整化
  - 使用书源优先用规整版

- [ ] **里程碑3：全功能完成**（Day 3结束）
  - 前端显示警告
  - 所有测试通过
  - 准备上线

---

## ✅ 最终验收清单

### 功能验收
- [ ] 导入任意书源都能成功（100%兼容率）
- [ ] 原始JSON完整保留
- [ ] 警告信息清晰展示
- [ ] 搜索功能正常使用

### 技术验收
- [ ] 所有单元测试通过
- [ ] 集成测试通过
- [ ] 性能符合预期（规整化<100ms）
- [ ] 代码已Code Review

### 业务验收
- [ ] 用户体验改善
- [ ] 客服咨询减少
- [ ] 无严重Bug

---

**文档版本：** 2.0（阶段性任务清单版）  
**最后更新：** 2026-06-11  
**实施负责人：** [待填写]  
**开始时间：** [待填写]  
**预计完成：** [待填写]
