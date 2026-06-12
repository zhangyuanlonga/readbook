# 接口优化实施清单

**目标：** 减少Go→Rust的HTTP调用，提升性能50%+  
**工期：** 1-2周  
**优先级：** 高

---

## 📊 总览

| 阶段 | 任务数 | 预计工期 | 收益 |
|------|--------|---------|------|
| 阶段1：测试接口优化 | 3个 | 2天 | 节省50ms/次 |
| 阶段2：规整化后台任务 | 4个 | 3天 | 提升83%速度 |
| 阶段3：清理冗余接口 | 2个 | 1天 | 代码更清晰 |

---

## 🎯 阶段1：书源测试接口优化（2天）

### 目标
删除Go中转，Flutter直接调用Rust

### 当前流程（低效）
```
Flutter → Go (/v1/me/book-sources/:id/test)
         ↓ HTTP 50ms
      Go → Rust (/gateway/test)
         ↓ HTTP 50ms
Flutter ← Go ← Rust
总耗时：200ms
```

### 优化后流程
```
Flutter → Rust (/api/test-source)
         ↓ HTTP 50ms
Flutter ← Rust
总耗时：100ms ⬆️ 50%提升
```

---

### 任务清单

#### Rust端
- [ ] **1.1 新增测试接口**
  - 文件：`reader-rust-master/src/api/test.rs`
  - 接口：`POST /api/test-source`
  - 入参：`{source_json, keyword, timeout_ms}`
  - 返回：`{status, message, results}`

#### Flutter端
- [ ] **1.2 修改调用地址**
  - 文件：`lib/features/mine/application/book_source_test_service.dart`
  - 改为：直接调用Rust网关
  - 删除：Go接口调用代码

#### Go端
- [ ] **1.3 删除测试接口**
  - 文件：`internal/transport/http/handler_book_source.go`
  - 删除：`func (h *bookSourceHandler) TestMine`
  - 删除：路由注册 `v1.POST("/me/book-sources/:id/test", h.TestMine)`

**验收标准：**
- [ ] Flutter能直接调用Rust测试接口
- [ ] 测试功能正常
- [ ] 性能提升50%

---

## 🔄 阶段2：规整化改为后台任务（3天）

### 目标
创建书源时不阻塞，Rust后台异步规整化

### 当前流程（阻塞）
```
Go创建 → HTTP调用Rust规整化
         ↓ 同步等待100-200ms ❌
      保存数据库
总耗时：300ms
```

### 优化后流程
```
Go保存原始 → 数据库（标记pending）
总耗时：50ms ⬆️ 83%提升
         ↓
Rust后台 → 定时扫描 → 规整化 → 更新数据库
```

---

### 任务清单

#### 数据库
- [ ] **2.1 添加规整化状态字段**
  - 文件：数据库迁移
  - 添加：`normalization_status ENUM('pending', 'processing', 'done', 'failed')`
  - 添加：`last_normalized_at TIMESTAMP`
  - 添加索引：`idx_normalization_pending`

#### Go端
- [ ] **2.2 简化创建书源逻辑**
  - 文件：`internal/application/booksource/service.go`
  - 保存原始JSON
  - 设置：`normalization_status = 'pending'`
  - 删除：HTTP调用Rust规整化的代码
  - 立即返回（不等待规整化）

#### Rust端（核心）
- [ ] **2.3 实现后台规整化任务**
  - 文件：`reader-rust-master/src/worker/normalizer.rs`（新建）
  - 功能：
    - 定时扫描pending状态的书源（每5秒）
    - 批量规整化（每次10个）
    - 更新数据库：`normalized_json`, `warnings`, `status`
  - 技术：`tokio::spawn` + 定时器

- [ ] **2.4 启动后台任务**
  - 文件：`reader-rust-master/src/main.rs`
  - 在main函数中启动规整化worker
  - 优雅关闭处理

**验收标准：**
- [ ] 创建书源立即返回
- [ ] Rust后台自动规整化
- [ ] 数据库字段正确更新
- [ ] 性能：创建从300ms → 50ms

---

## 🧹 阶段3：清理冗余代码（1天）

### 任务清单

- [ ] **3.1 删除Go端规整化相关代码**
  - 删除：`internal/application/booksource/normalize.go`（如果有HTTP调用）
  - 删除：`NormalizeRequest`, `NormalizeResponse` 结构体
  - 删除：Go→Rust的HTTP client调用

- [ ] **3.2 更新文档**
  - 更新：API文档（测试接口地址变更）
  - 更新：架构图（去掉Go→Rust箭头）

**验收标准：**
- [ ] 代码更简洁
- [ ] 文档已更新

---

## 📊 实施顺序建议

### Week 1（Day 1-5）
```
Day 1-2: 阶段1（测试接口优化）
Day 3-5: 阶段2（规整化后台任务）
```

### Week 2（Day 6）
```
Day 6: 阶段3（清理冗余代码）
```

---

## 🔧 技术要点

### Rust后台任务示例结构

```rust
// worker/normalizer.rs
pub async fn start_normalizer(pool: PgPool) {
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(5));
        
        loop {
            interval.tick().await;
            
            // 查询pending状态
            let sources = sqlx::query!(
                "SELECT id, source_json FROM book_sources 
                 WHERE normalization_status = 'pending' 
                 LIMIT 10"
            )
            .fetch_all(&pool)
            .await
            .unwrap_or_default();
            
            // 规整化
            for source in sources {
                let result = normalize(&source.source_json);
                
                // 更新数据库
                sqlx::query!(
                    "UPDATE book_sources 
                     SET source_json_normalized = $1,
                         normalization_warnings = $2,
                         normalization_status = 'done'
                     WHERE id = $3",
                    result.normalized,
                    result.warnings,
                    source.id
                )
                .execute(&pool)
                .await
                .ok();
            }
        }
    });
}
```

### Go端简化创建

```go
// 简化后的CreatePrivateSource
func (s *Service) CreatePrivateSource(ctx context.Context, input CreatePrivateSourceInput) (BookSource, error) {
    item := BookSource{
        SourceJSON:            input.SourceJSON,
        NormalizationStatus:   "pending",  // 标记为待处理
        // ... 其他字段
    }
    
    return s.repo.Create(ctx, item)
    // 立即返回，Rust后台会处理
}
```

---

## ⚠️ 注意事项

### 1. 数据库事务
- Rust更新时检查状态（避免重复处理）
- 使用`FOR UPDATE SKIP LOCKED`防止并发

### 2. 错误处理
- 规整化失败：设置`status='failed'`，记录错误
- 失败的书源可以手动重试

### 3. 监控
- 记录规整化耗时
- 监控pending队列长度
- 告警：pending堆积>100

---

## ✅ 最终验收

### 性能指标
- [ ] 创建书源：<100ms
- [ ] 测试书源：<200ms
- [ ] 规整化延迟：<30秒

### 功能指标
- [ ] 所有书源能正常创建
- [ ] 测试功能正常
- [ ] 规整化成功率>95%

### 代码质量
- [ ] 无Go→Rust HTTP调用
- [ ] 代码更简洁
- [ ] 文档已更新

---

## 📊 预期收益

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 创建书源耗时 | 300ms | 50ms | **83%** ⬆️ |
| 测试书源耗时 | 200ms | 100ms | **50%** ⬆️ |
| Go→Rust调用 | 2次/创建 | 0次 | **100%** ⬇️ |
| 用户体验 | 需要等待 | 立即返回 | **显著提升** ✅ |

---

**建议：按阶段1→2→3顺序实施，每个阶段完成后验收再进入下一阶段。**
