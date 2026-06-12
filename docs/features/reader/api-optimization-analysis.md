# 接口调用优化分析 - Rust vs Go 职责划分

**分析时间：** 2026-06-11  
**架构：** Rust + Go 同服务器，共享数据库  
**目标：** 减少不必要的Go→Rust调用，明确职责边界

---

## 🎯 核心原则

### Rust擅长：
- ✅ **书源解析执行**（搜索、章节、正文）
- ✅ **JS脚本执行**（规则引擎）
- ✅ **高性能计算**（规整化、加密）
- ✅ **WebView操作**（未来）

### Go擅长：
- ✅ **业务逻辑**（权限、会员、配额）
- ✅ **CRUD操作**（书源管理）
- ✅ **用户认证**（登录、Token）
- ✅ **数据聚合**（统计、报表）

---

## 📊 当前接口分析

### 类型1：书源CRUD（Go负责）✅ 正确

```
POST   /v1/me/book-sources          创建私人书源
GET    /v1/me/book-sources          列出私人书源
GET    /v1/me/book-sources/:id      获取书源详情
PATCH  /v1/me/book-sources/:id      更新书源
DELETE /v1/me/book-sources/:id      删除书源
```

**现状：** Go直接操作数据库 ✅  
**建议：** 保持不变

---

### 类型2：书源搜索/解析（Rust负责）✅ 正确

```
POST /gateway/search              搜索书籍
POST /gateway/book-info           获取书籍详情
POST /gateway/chapters            获取章节列表
POST /gateway/content             获取章节内容
```

**现状：** Flutter → Rust直接调用 ✅  
**建议：** 保持不变，Go不需要介入

---

### 类型3：书源测试（有问题）⚠️

**当前流程：**
```
Flutter → Go (/v1/me/book-sources/:id/test)
         ↓
      Go → Rust (sourceGateway/test)
         ↓
      Go ← Rust (测试结果)
         ↓
Flutter ← Go (返回结果)
```

**问题：**
- Go只是简单转发，没有业务逻辑
- 增加了一次HTTP调用（50-100ms）
- Go需要维护Rust接口的类型定义

**优化方案A：Flutter直接调Rust** ✅ 推荐
```
Flutter → Rust (/api/test-source)
         ↓
      Rust测试 → 直接返回
         ↓
Flutter ← 测试结果
```

**优化方案B：Go只做权限校验**
```
Flutter → Go (/v1/me/book-sources/:id/test)
         ↓
      Go验证权限（是否是用户的书源）
         ↓
      Go返回临时Token
         ↓
Flutter ← Token
         ↓
Flutter → Rust (/api/test-source?token=xxx)
```

---

### 类型4：书源规整化（需要优化）⚠️

**当前设计（文档中）：**
```
Go创建书源 → HTTP调用Rust → 规整化 → 返回 → Go保存
```

**优化方案：Rust后台任务** ✅ 推荐
```
Go保存原始 → 数据库（标记pending）
             ↓
Rust定时扫描 → 规整化 → 更新数据库
```

**优势：**
- 无HTTP调用开销
- 异步处理，不阻塞用户
- 可批量处理

---

### 类型5：登录信息管理（需要优化）⚠️

**错误设计：**
```
Flutter → Go → Rust (保存登录信息)
Flutter → Go → Rust (获取登录信息)
```

**正确设计：共享数据库** ✅
```
Rust保存/读取 → book_source_login_info表
Go查询（如需要）→ 直接读数据库
```

---

## 📋 具体接口优化建议

### 需要删除的Go接口（让Flutter直接调Rust）

#### 1. 书源测试接口 ❌ 删除
```go
// 删除这个接口
POST /v1/me/book-sources/:id/test

// Flutter改为直接调用
POST /api/test-source
```

**原因：** Go只是转发，无业务逻辑

---

#### 2. 书源能力检查 ❌ 删除（如果有）
```go
// 如果有这种接口，删除
GET /v1/book-sources/:id/capabilities

// Flutter改为直接调用Rust
GET /api/source-capabilities
```

---

### 需要保留的Go接口（有业务逻辑）

#### 1. 书源CRUD ✅ 保留
```go
POST   /v1/me/book-sources          // 权限校验、配额检查
GET    /v1/me/book-sources          // 只返回用户的书源
PATCH  /v1/me/book-sources/:id      // 权限校验
DELETE /v1/me/book-sources/:id      // 权限校验
```

**原因：** 需要权限控制、配额管理

---

#### 2. 书源审核 ✅ 保留
```go
PATCH /v1/book-sources/:id/review   // 管理员审核
```

**原因：** 业务流程复杂

---

#### 3. 书源分组 ✅ 保留
```go
GET    /v1/me/book-source-groups
POST   /v1/me/book-source-groups
```

**原因：** 纯CRUD

---

### 需要改造的Go接口（减少Rust调用）

#### 1. 书源导入
```go
// 当前：
POST /v1/me/book-sources/import
  → 验证
  → 调用Rust检查格式 ❌
  → 保存

// 优化后：
POST /v1/me/book-sources/import
  → 验证JSON格式（Go本地）
  → 保存原始JSON
  → 标记pending（Rust后台规整化）✅
```

---

## 🔄 数据流优化

### 优化前（多次调用）
```
创建书源流程：
Flutter → Go (/v1/me/book-sources)
         ↓
      Go → Rust (/api/normalize) ❌ HTTP调用
         ↓
      Go保存数据库
         ↓
Flutter ← 返回

测试书源流程：
Flutter → Go (/v1/me/book-sources/:id/test)
         ↓
      Go → Rust (/api/test) ❌ HTTP调用
         ↓
Flutter ← 返回
```

### 优化后（减少调用）
```
创建书源流程：
Flutter → Go (/v1/me/book-sources)
         ↓
      Go保存数据库（标记pending）
         ↓
Flutter ← 立即返回
         ↓
Rust后台任务 → 扫描pending → 规整化 ✅

测试书源流程：
Flutter → Rust (/api/test-source) ✅ 直接调用
         ↓
Flutter ← 返回
```

---

## 📊 优化效果预估

| 操作 | 优化前 | 优化后 | 节省 |
|------|--------|--------|------|
| 创建书源 | 300ms | 50ms | **83%** |
| 测试书源 | 200ms | 100ms | **50%** |
| 规整化 | 同步阻塞 | 异步后台 | **不阻塞** |

---

## 🎯 实施建议

### 阶段1：立即可做（高优先级）

**1. 删除书源测试的Go中转**
```
删除：POST /v1/me/book-sources/:id/test
添加：Rust直接暴露 POST /api/test-source
Flutter直接调用Rust
```

**2. 规整化改为后台任务**
```
Go只保存原始JSON
Rust定时任务扫描并规整化
```

**影响：** 无破坏性变更，性能提升50%+

---

### 阶段2：中期优化（中优先级）

**1. 登录信息改为数据库存储**
```
Rust保存到 book_source_login_info 表
Go/Rust都直接读数据库
```

**2. 配额检查前置到Rust**
```
如果配额信息在数据库，Rust可以自己查
不需要经过Go
```

---

### 阶段3：长期规划（低优先级）

**1. 考虑gRPC替代HTTP**
```
如果Go确实需要调Rust
用gRPC比HTTP快3-5倍
```

**2. 考虑共享内存**
```
极端情况下可以用共享内存通信
但增加复杂度，不推荐
```

---

## ✅ 行动清单

### 立即删除的接口
- [ ] `POST /v1/me/book-sources/:id/test` → 改为Flutter直接调Rust

### 需要改造的接口
- [ ] `POST /v1/me/book-sources` → 去掉规整化HTTP调用
- [ ] 规整化改为Rust后台任务

### 需要新增的Rust接口
- [ ] `POST /api/test-source` - 书源测试（直接暴露给Flutter）
- [ ] `POST /api/normalize` - 规整化（但不通过HTTP，而是后台任务）

### 架构优化
- [ ] 创建 `book_source_login_info` 表
- [ ] Rust添加定时任务框架
- [ ] 更新Flutter调用路径

---

## 🎯 总结

### 核心原则
**Flutter → Go：** 需要权限、业务逻辑的操作  
**Flutter → Rust：** 书源解析、测试等纯计算  
**Go ↔ Rust：** 尽量通过数据库，避免HTTP

### 预期收益
- ✅ 减少50%的Go→Rust HTTP调用
- ✅ 创建书源速度提升83%
- ✅ 架构更清晰，职责分明

---

**建议优先实施阶段1，立即可见效果！**
