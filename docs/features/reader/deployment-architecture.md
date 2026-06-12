# 架构说明：Rust + Go 同服务器部署

**部署架构：** 单服务器，共享数据库

```
┌─────────────────────────────────┐
│       同一服务器/容器            │
│                                  │
│  ┌──────────┐    ┌──────────┐  │
│  │   Go     │    │  Rust    │  │
│  │  后端    │    │  网关    │  │
│  └─────┬────┘    └────┬─────┘  │
│        │              │         │
│        └──────┬───────┘         │
│               ↓                 │
│        ┌──────────────┐         │
│        │  PostgreSQL  │         │
│        │   (共享)     │         │
│        └──────────────┘         │
└─────────────────────────────────┘
```

---

## 🎯 关键优化点

### 1. 双JSON规整化

**❌ 不要这样做（HTTP调用）：**
```
Go创建书源 → HTTP请求Rust → Rust规整化 → HTTP返回 → Go保存
```

**✅ 应该这样做：**

**方案A：Rust后台任务**
```
Go保存原始 → 数据库
             ↓
Rust定时扫描 → 规整化 → 直接更新数据库
```

**方案B：数据库触发器**
```
Go保存原始 → 数据库触发器 → 通知Rust → 规整化
```

**方案C：消息队列（可选）**
```
Go保存原始 → 发布消息 → Rust消费 → 规整化
```

---

### 2. 登录信息存储

**❌ 不要这样做：**
```
Rust保存登录信息 → Go需要时HTTP请求Rust
```

**✅ 应该这样做：**
```
Rust保存 → 数据库book_source_login_info表
Go读取 → 直接查询数据库（如果需要）
```

---

### 3. 使用书源

**两端都直接读数据库：**
```
Go搜索：SELECT source_json_normalized FROM book_sources
Rust搜索：SELECT source_json_normalized FROM book_sources
```

**如果normalized为空，回退到original：**
```sql
SELECT 
  COALESCE(source_json_normalized, source_json) as json_to_use
FROM book_sources
```

---

## 📊 数据库表设计

### book_sources 表
```sql
CREATE TABLE book_sources (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    source_json TEXT,                    -- 原始JSON
    source_json_normalized TEXT,         -- 规整后JSON
    normalization_warnings TEXT,         -- 警告信息
    normalization_status TEXT,           -- pending/processing/done/failed
    last_normalized_at TIMESTAMP,
    -- ... 其他字段
);

-- 索引：查询未规整化的书源
CREATE INDEX idx_normalization_pending 
  ON book_sources(normalization_status) 
  WHERE normalization_status = 'pending';
```

### book_source_login_info 表（新增）
```sql
CREATE TABLE book_source_login_info (
    source_id TEXT PRIMARY KEY,
    login_info_encrypted TEXT,           -- AES加密的登录信息
    login_header_encrypted TEXT,         -- AES加密的登录header
    login_status TEXT,                   -- active/expired/unknown
    last_login_at TIMESTAMP,
    expires_at TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

---

## 🔄 规整化工作流

### Rust后台任务（推荐）

```rust
// Rust端定时任务
#[tokio::main]
async fn normalize_worker() {
    loop {
        // 查询待规整化的书源
        let pending_sources = sqlx::query!(
            "SELECT id, source_json FROM book_sources 
             WHERE normalization_status = 'pending' 
             OR source_json_normalized IS NULL
             LIMIT 10"
        )
        .fetch_all(&pool)
        .await?;
        
        for source in pending_sources {
            // 规整化
            let result = normalize(&source.source_json)?;
            
            // 直接更新数据库
            sqlx::query!(
                "UPDATE book_sources 
                 SET source_json_normalized = $1,
                     normalization_warnings = $2,
                     normalization_status = 'done',
                     last_normalized_at = NOW()
                 WHERE id = $3",
                result.normalized_json,
                result.warnings_json,
                source.id
            )
            .execute(&pool)
            .await?;
        }
        
        // 休眠1秒
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}
```

### Go端只负责保存

```go
func (s *Service) CreatePrivateSource(ctx context.Context, input CreatePrivateSourceInput) (BookSource, error) {
    item := BookSource{
        SourceJSON:            input.SourceJSON,
        NormalizationStatus:   "pending",  // 标记为待处理
    }
    
    return s.repo.Create(ctx, item)
    // Rust后台会自动处理
}
```

---

## 💡 为什么这样更好？

### 1. 性能优势
- ❌ HTTP调用：50-100ms
- ✅ 数据库直接访问：5-10ms

### 2. 架构简单
- ❌ HTTP：需要处理超时、重试、错误
- ✅ 数据库：标准的增删改查

### 3. 解耦
- ❌ HTTP：Go依赖Rust服务可用
- ✅ 数据库：异步处理，互不阻塞

### 4. 可扩展
- 未来可以加消息队列
- 规整化任务可以并行
- 可以监控处理进度

---

## 🎯 实施建议

### 短期（双JSON存储）

**Go端：**
```go
// 只保存原始，标记pending
item.SourceJSON = input.SourceJSON
item.NormalizationStatus = "pending"
repo.Create(ctx, item)
```

**Rust端：**
```rust
// 后台任务定时扫描并规整化
normalize_worker().await
```

### 中期（登录系统）

**Rust端：**
```rust
// 登录信息直接存数据库
sqlx::query!(
    "INSERT INTO book_source_login_info (source_id, login_info_encrypted) 
     VALUES ($1, $2)",
    source_id, encrypted
).execute(&pool).await?
```

**Go端：**
```go
// 如果需要读取（很少），直接查数据库
loginInfo := repo.GetLoginInfo(sourceID)
```

---

**总结：同服务器部署，共享数据库，避免不必要的HTTP调用，使用数据库+后台任务方案。**
