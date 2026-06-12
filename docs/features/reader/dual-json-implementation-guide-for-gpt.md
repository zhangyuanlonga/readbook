# 书源双JSON存储实施指南（给GPT的详细文档）

**任务目标：** 实现书源原始JSON + 规整JSON双存储方案  
**预计工期：** 2-3天  
**难度等级：** 中等  
**涉及代码库：**
- Rust网关：`/Users/zhangyuanlong/storage/FlutterProject/reader-rust-master`
- Go后端：`/Users/zhangyuanlong/storage/FlutterProject/read-admin`
- Flutter前端：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook`

---

## 📋 背景说明

### 当前问题

**问题：** Legado书源格式非常灵活，字段可以是string/object/array，但Rust代码只能兼容70-80%，导致部分书源导入失败。

**示例问题书源：**
```json
{
  "bookSourceName": "某书源",
  "bookSourceUrl": "https://example.com",
  "loginUi": {                    // ❌ Rust期待string，但这是object
    "type": "web",
    "url": "xxx"
  },
  "userAgent": ["UA1", "UA2"],   // ❌ Rust期待string，但这是array
  "ruleSearch": {                // ✅ 这个已经兼容
    "bookList": "$.data[*]"
  }
}
```

**Rust报错：**
```
invalid type: map, expected a string at line 4 column 13
```

### 解决方案

**核心思路：** 保存两份JSON
1. `source_json` - 用户上传的原始JSON（完全保真）
2. `source_json_normalized` - Rust规整后的JSON（100%可用）
3. `normalization_warnings` - 规整时的警告信息

**使用策略：**
- 阅读器使用：`source_json_normalized`（保证能用）
- 用户编辑：显示`source_json`（原始数据）+ `normalization_warnings`（透明提示）

---

## 🎯 实施步骤

### 步骤1：数据库迁移（Go）

**文件：** `read-admin/migrations/XXXXXX_add_normalized_fields.sql`

```sql
-- 添加新字段
ALTER TABLE book_sources 
  ADD COLUMN source_json_normalized TEXT COMMENT 'Rust规整后的JSON',
  ADD COLUMN normalization_warnings TEXT COMMENT '规整时的兼容性警告';

-- 添加索引（可选，如果需要查询有警告的书源）
CREATE INDEX idx_book_sources_has_warnings 
  ON book_sources(normalization_warnings(100));
```

**注意事项：**
- MySQL用`TEXT`类型存储JSON
- PostgreSQL可以用`JSONB`，但这里保持一致用`TEXT`
- `normalization_warnings`可以为NULL（表示无警告）

---


### 步骤2：Rust端 - 实现规整化接口（已写入文件，见上方）

详细代码已经在文件中，包含：
- 2.1 创建normalize.rs接口文件
- 2.2 字段转换检测逻辑
- 2.3 注册路由
- 2.4 测试用例

---

### 步骤3：Go端 - 调用规整化接口

#### 3.1 定义Go数据结构

**文件：** `read-admin/internal/domain/booksource/entity.go`

在BookSource结构体中添加新字段：

```go
type BookSource struct {
    // ... 现有字段 ...
    
    SourceJSON              string    `json:"source_json" db:"source_json"`
    SourceJSONNormalized    string    `json:"source_json_normalized" db:"source_json_normalized"`
    NormalizationWarnings   string    `json:"normalization_warnings" db:"normalization_warnings"`
    
    // ... 其他字段 ...
}
```

#### 3.2 定义Rust响应结构

**文件：** `read-admin/internal/application/booksource/normalize.go`（新建）

```go
package booksource

type NormalizeRequest struct {
    SourceJSON string `json:"source_json"`
}

type NormalizeResponse struct {
    NormalizedJSON      string         `json:"normalized_json"`
    Warnings            []FieldWarning `json:"warnings"`
    IsValid             bool           `json:"is_valid"`
    CompatibilityScore  uint8          `json:"compatibility_score"`
}

type FieldWarning struct {
    Field         string `json:"field"`
    DisplayName   string `json:"display_name"`
    OriginalType  string `json:"original_type"`
    ConvertedType string `json:"converted_type"`
    Message       string `json:"message"`
}

// 格式化警告为简短字符串（存数据库用）
func (r *NormalizeResponse) FormatWarnings() string {
    if len(r.Warnings) == 0 {
        return ""
    }
    
    messages := make([]string, len(r.Warnings))
    for i, w := range r.Warnings {
        messages[i] = w.Message
    }
    return strings.Join(messages, "; ")
}
```

#### 3.3 实现规整化调用

**文件：** `read-admin/internal/application/booksource/service.go`

```go
import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "time"
)

type Service struct {
    // ... 现有字段 ...
    rustGatewayURL string
    httpClient     *http.Client
}

// 调用Rust规整化接口
func (s *Service) normalizeSourceJSON(ctx context.Context, sourceJSON string) (*NormalizeResponse, error) {
    reqBody := NormalizeRequest{
        SourceJSON: sourceJSON,
    }
    
    body, err := json.Marshal(reqBody)
    if err != nil {
        return nil, fmt.Errorf("序列化请求失败: %w", err)
    }
    
    req, err := http.NewRequestWithContext(
        ctx,
        "POST",
        s.rustGatewayURL+"/api/normalize",
        bytes.NewReader(body),
    )
    if err != nil {
        return nil, fmt.Errorf("创建请求失败: %w", err)
    }
    
    req.Header.Set("Content-Type", "application/json")
    
    resp, err := s.httpClient.Do(req)
    if err != nil {
        return nil, fmt.Errorf("调用Rust接口失败: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("Rust接口返回错误: %d", resp.StatusCode)
    }
    
    var result NormalizeResponse
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return nil, fmt.Errorf("解析响应失败: %w", err)
    }
    
    return &result, nil
}
```

#### 3.4 修改创建书源逻辑

**文件：** `read-admin/internal/application/booksource/service.go`

修改 `CreatePrivateSource` 方法：

```go
func (s *Service) CreatePrivateSource(ctx context.Context, input CreatePrivateSourceInput) (BookSource, error) {
    // 第一步：校验输入（保持原有逻辑）
    name := strings.TrimSpace(input.Name)
    if name == "" || len(name) > maxNameLen {
        return BookSource{}, ErrInvalidInput
    }
    
    // 第二步：保存原始JSON（不做任何修改）
    sourceJSON := input.SourceJSON
    sourceJSONForValidation := strings.TrimSpace(sourceJSON)
    
    if sourceJSONForValidation != "" && len(sourceJSON) > maxSourceJSONLen {
        return BookSource{}, ErrInvalidInput
    }
    if sourceJSONForValidation != "" && !json.Valid([]byte(sourceJSONForValidation)) {
        return BookSource{}, ErrInvalidInput
    }
    
    // 第三步：调用Rust规整化
    var normalizedJSON string
    var warnings string
    var compatibilityScore uint8 = 100
    
    if sourceJSONForValidation != "" {
        normalizeResp, err := s.normalizeSourceJSON(ctx, sourceJSON)
        if err != nil {
            // 规整化失败不阻止创建，但记录错误
            s.logger.Warn("规整化失败",
                "error", err,
                "source_name", name,
            )
            warnings = fmt.Sprintf("规整化失败: %s", err.Error())
        } else if normalizeResp.IsValid {
            normalizedJSON = normalizeResp.NormalizedJSON
            warnings = normalizeResp.FormatWarnings()
            compatibilityScore = normalizeResp.CompatibilityScore
        } else {
            // Rust返回invalid
            warnings = normalizeResp.FormatWarnings()
        }
    }
    
    // 第四步：创建书源实体
    sourceCode := strings.TrimSpace(input.SourceCode)
    if sourceCode != "" && len(sourceCode) > maxSourceCodeLen {
        return BookSource{}, ErrInvalidInput
    }
    if sourceJSONForValidation == "" && sourceCode == "" {
        return BookSource{}, ErrInvalidInput
    }
    
    description := strings.TrimSpace(input.Description)
    if len(description) > maxDescriptionLen {
        return BookSource{}, ErrInvalidInput
    }
    
    groupName, err := normalizeGroupName(input.GroupName)
    if err != nil {
        return BookSource{}, err
    }
    if groupName == "" {
        groupName = defaultGroupNameFromSourceJSON(sourceJSON)
    }
    
    userID := normalizeID(input.UserID)
    if userID == "" {
        return BookSource{}, ErrInvalidInput
    }
    
    now := time.Now().UTC()
    item := BookSource{
        ID:                   generateID(),
        Name:                 name,
        Title:                name,
        SupportedTypes:       supportedTypes,
        SourceCode:           sourceCode,
        SourceJSON:           sourceJSON,              // 原始JSON
        SourceJSONNormalized: normalizedJSON,         // 规整后的JSON
        NormalizationWarnings: warnings,               // 警告信息
        Description:          description,
        UserID:               userID,
        GroupName:            groupName,
        Visibility:           VisibilityPrivate,
        Enabled:              true,
        LastTestStatus:       TestStatusUnknown,
        CreatedAt:            now,
        UpdatedAt:            now,
    }
    
    // 第五步：保存到数据库
    if err := s.repo.Create(ctx, item); err != nil {
        return BookSource{}, fmt.Errorf("保存失败: %w", err)
    }
    
    return item, nil
}
```

#### 3.5 修改使用书源的逻辑

**文件：** `read-admin/internal/infrastructure/gateway/rust_gateway.go`

修改所有调用Rust的地方，优先使用normalized版本：

```go
func (g *RustGateway) SearchBooks(ctx context.Context, source BookSource, keyword string) ([]Book, error) {
    // 优先使用规整后的JSON
    jsonToUse := source.SourceJSONNormalized
    if jsonToUse == "" {
        // 回退到原始JSON（老数据或规整失败的情况）
        jsonToUse = source.SourceJSON
    }
    
    reqBody := map[string]interface{}{
        "sourceJson": jsonToUse,  // 使用规整后的版本
        "keyword":    keyword,
    }
    
    // ... 后续逻辑不变 ...
}

// 同样修改其他调用Rust的方法
func (g *RustGateway) GetBookDetail(ctx context.Context, source BookSource, bookURL string) (BookDetail, error) {
    jsonToUse := source.SourceJSONNormalized
    if jsonToUse == "" {
        jsonToUse = source.SourceJSON
    }
    // ...
}

func (g *RustGateway) GetChapterList(ctx context.Context, source BookSource, bookURL string) ([]Chapter, error) {
    jsonToUse := source.SourceJSONNormalized
    if jsonToUse == "" {
        jsonToUse = source.SourceJSON
    }
    // ...
}

func (g *RustGateway) GetChapterContent(ctx context.Context, source BookSource, chapterURL string) (string, error) {
    jsonToUse := source.SourceJSONNormalized
    if jsonToUse == "" {
        jsonToUse = source.SourceJSON
    }
    // ...
}
```

---

### 步骤4：数据迁移脚本

#### 4.1 Go迁移脚本

**文件：** `read-admin/cmd/migrate_normalize/main.go`（新建）

```go
package main

import (
    "context"
    "fmt"
    "log"
    "time"
    
    "your-project/internal/application/booksource"
    "your-project/internal/infrastructure/persistence"
)

func main() {
    ctx := context.Background()
    
    // 初始化依赖
    db := persistence.NewDB() // 你的数据库连接
    repo := persistence.NewBookSourceRepository(db)
    service := booksource.NewService(repo, /* 其他依赖 */)
    
    log.Println("开始迁移现有书源...")
    
    // 获取所有需要规整化的书源
    sources, err := repo.FindAll(ctx, persistence.FindOptions{
        // 只查询未规整化的
        Filters: map[string]interface{}{
            "source_json_normalized_is_null": true,
        },
    })
    if err != nil {
        log.Fatalf("查询书源失败: %v", err)
    }
    
    log.Printf("找到 %d 个需要规整化的书源", len(sources))
    
    // 逐个规整化
    successCount := 0
    failCount := 0
    
    for i, source := range sources {
        log.Printf("[%d/%d] 处理书源: %s (%s)", 
            i+1, len(sources), source.Name, source.ID)
        
        if source.SourceJSON == "" {
            log.Printf("  跳过：无source_json")
            continue
        }
        
        // 调用规整化
        normalizeResp, err := service.NormalizeSourceJSON(ctx, source.SourceJSON)
        if err != nil {
            log.Printf("  失败：%v", err)
            failCount++
            continue
        }
        
        // 更新数据库
        source.SourceJSONNormalized = normalizeResp.NormalizedJSON
        source.NormalizationWarnings = normalizeResp.FormatWarnings()
        source.UpdatedAt = time.Now().UTC()
        
        if err := repo.Update(ctx, source); err != nil {
            log.Printf("  更新失败：%v", err)
            failCount++
            continue
        }
        
        log.Printf("  成功：兼容性 %d%%, 警告 %d 条", 
            normalizeResp.CompatibilityScore,
            len(normalizeResp.Warnings))
        successCount++
        
        // 避免过快
        time.Sleep(100 * time.Millisecond)
    }
    
    log.Printf("迁移完成：成功 %d，失败 %d", successCount, failCount)
}
```

#### 4.2 执行迁移

```bash
# 编译迁移脚本
cd read-admin
go build -o bin/migrate_normalize cmd/migrate_normalize/main.go

# 执行迁移
./bin/migrate_normalize

# 验证结果
# SELECT COUNT(*) FROM book_sources WHERE source_json_normalized IS NOT NULL;
```

---


### 步骤5：Flutter前端 - 显示兼容性警告

#### 5.1 更新数据模型

**文件：** `lib/features/mine/domain/entities/book_source.dart`

```dart
class BookSource {
  final String id;
  final String name;
  final String sourceJson;
  final String? sourceJsonNormalized;        // 新增
  final String? normalizationWarnings;       // 新增
  // ... 其他字段 ...
  
  const BookSource({
    required this.id,
    required this.name,
    required this.sourceJson,
    this.sourceJsonNormalized,
    this.normalizationWarnings,
    // ...
  });
}
```

#### 5.2 创建警告横幅组件

**文件：** `lib/shared/widgets/compatibility_warning_banner.dart`（新建）

```dart
import 'package:flutter/material.dart';

class CompatibilityWarningBanner extends StatelessWidget {
  final String warnings;
  
  const CompatibilityWarningBanner({
    Key? key,
    required this.warnings,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 解析警告（用;分隔）
    final warningList = warnings.split(';')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
                const SizedBox(width: 8),
                Text(
                  '兼容性提示',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ),
          
          // 警告列表
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...warningList.map((warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: Colors.orange.shade800)),
                      Expanded(
                        child: Text(
                          warning,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                
                const SizedBox(height: 8),
                
                // 说明文字
                Text(
                  '说明：阅读器使用的是兼容版本，您的原始数据已完整保留',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 5.3 在书源详情页显示

**文件：** `lib/features/mine/presentation/private_book_source_detail_page.dart`

```dart
class PrivateBookSourceDetailPage extends ConsumerWidget {
  final String sourceId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceAsync = ref.watch(bookSourceDetailProvider(sourceId));
    
    return Scaffold(
      appBar: AppBar(title: const Text('书源详情')),
      body: sourceAsync.when(
        data: (source) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 显示兼容性警告
              if (source.normalizationWarnings?.isNotEmpty ?? false)
                CompatibilityWarningBanner(
                  warnings: source.normalizationWarnings!,
                ),
              
              // 原始JSON编辑器
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '书源JSON',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: source.sourceJson),
                      maxLines: 20,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '书源JSON配置',
                      ),
                    ),
                  ],
                ),
              ),
              
              // 保存按钮等...
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
  }
}
```

#### 5.4 在书源列表页显示警告徽章

**文件：** `lib/features/mine/presentation/widgets/book_source_card.dart`

```dart
class BookSourceCard extends StatelessWidget {
  final BookSource source;
  
  @override
  Widget build(BuildContext context) {
    final hasWarnings = source.normalizationWarnings?.isNotEmpty ?? false;
    
    return Card(
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(source.name)),
            // 显示警告徽章
            if (hasWarnings)
              Tooltip(
                message: '存在兼容性提示',
                child: Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                  size: 16,
                ),
              ),
          ],
        ),
        subtitle: Text(source.groupName ?? '未分组'),
        onTap: () => context.push('/source/${source.id}'),
      ),
    );
  }
}
```

---

### 步骤6：关键注意事项

#### 6.1 错误处理

**规整化失败不应阻止创建：**
```go
// Go端
if err != nil {
    // 记录警告但继续创建
    warnings = fmt.Sprintf("规整化失败: %s", err.Error())
} else if normalizeResp.IsValid {
    normalizedJSON = normalizeResp.NormalizedJSON
}
```

**使用时回退到原始JSON：**
```go
// Rust Gateway
jsonToUse := source.SourceJSONNormalized
if jsonToUse == "" {
    jsonToUse = source.SourceJSON  // 回退
}
```

#### 6.2 性能考虑

**规整化接口应该快速响应：**
- 目标：<100ms
- 不要做复杂的书源测试
- 只做结构化解析和重新序列化

**数据库查询优化：**
```sql
-- 如果经常查询有警告的书源，添加索引
CREATE INDEX idx_has_warnings 
  ON book_sources((normalization_warnings IS NOT NULL));
```

#### 6.3 向后兼容

**老数据处理：**
- `source_json_normalized` 为空 → 使用 `source_json`
- 不强制要求所有老数据都迁移
- 新书源自动生成normalized版本

**API兼容性：**
```go
// 返回时兼容老客户端
type BookSourceResponse struct {
    // ... 其他字段 ...
    SourceJSON              string  `json:"source_json"`
    SourceJSONNormalized    *string `json:"source_json_normalized,omitempty"`  // 可选
    NormalizationWarnings   *string `json:"normalization_warnings,omitempty"`  // 可选
}
```

#### 6.4 监控指标

**建议监控：**
1. 规整化成功率
2. 规整化耗时（P50/P90/P99）
3. 有警告的书源比例
4. 最常见的警告类型

**统计SQL：**
```sql
-- 有警告的书源比例
SELECT 
  COUNT(*) as total,
  SUM(CASE WHEN normalization_warnings IS NOT NULL THEN 1 ELSE 0 END) as with_warnings,
  ROUND(SUM(CASE WHEN normalization_warnings IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as warning_rate
FROM book_sources;

-- 最常见的警告
SELECT 
  SUBSTRING_INDEX(normalization_warnings, ';', 1) as first_warning,
  COUNT(*) as count
FROM book_sources
WHERE normalization_warnings IS NOT NULL
GROUP BY first_warning
ORDER BY count DESC
LIMIT 10;
```

---

### 步骤7：测试清单

#### 7.1 Rust端测试

**测试用例：**
- ✅ 简单书源（只有string字段）→ 无警告
- ✅ 复杂书源（object/array字段）→ 有警告
- ✅ 无效JSON → 返回is_valid=false
- ✅ 超大JSON → 正常处理
- ✅ 特殊字符/转义 → 正确保留

**运行测试：**
```bash
cd reader-rust-master
cargo test normalize
```

#### 7.2 Go端测试

**测试用例：**
- ✅ 创建书源 → normalized字段正确填充
- ✅ Rust接口失败 → 仍然能创建（只是无normalized）
- ✅ 使用书源 → 优先用normalized版本
- ✅ 编辑书源 → 显示原始JSON

**运行测试：**
```bash
cd read-admin
go test ./internal/application/booksource/...
```

#### 7.3 端到端测试

**手动测试流程：**
1. 导入一个复杂书源（含object/array字段）
2. 检查数据库：`source_json_normalized`和`warnings`是否正确
3. 使用书源搜索书籍 → 应该能正常搜索
4. 编辑书源 → 应该显示原始JSON和警告横幅
5. 查看书源列表 → 应该显示警告徽章

---

### 步骤8：上线计划

#### 8.1 分阶段上线

**第1阶段：Rust接口上线（不影响现有功能）**
- 部署Rust新接口
- 验证接口可用性
- 不修改Go端

**第2阶段：Go端集成（灰度）**
- 部署Go新代码
- 只对新创建的书源调用规整化
- 观察错误率和性能

**第3阶段：数据迁移（批量）**
- 执行迁移脚本
- 分批处理老数据
- 验证迁移质量

**第4阶段：前端更新（完整功能）**
- 部署Flutter新版本
- 用户可见兼容性警告

#### 8.2 回滚方案

**如果出现问题：**
1. Go端可以快速回滚（不调用规整化接口）
2. 数据库字段可以为空（向后兼容）
3. 前端可以忽略新字段

---

### 步骤9：文档和沟通

#### 9.1 用户文档

**帮助中心添加说明：**
```markdown
# 书源兼容性说明

Q: 什么是"兼容性提示"？
A: 部分书源使用了高级格式（对象/数组），我们已自动转换为兼容格式。
   您的原始数据已完整保留，不会丢失。

Q: 兼容性提示会影响使用吗？
A: 不会。阅读器使用的是兼容版本，可以正常搜索和阅读。

Q: 如何去除兼容性提示？
A: 可以将书源中的对象/数组字段改为字符串格式。
   例如：
   错误：  "loginUi": {"type": "web"}
   正确：  "loginUi": "web"
```

#### 9.2 开发文档

**更新API文档：**
- 书源实体新增字段说明
- 规整化接口文档
- 迁移脚本使用说明

---

### 步骤10：长期优化

#### 10.1 自动修复建议

**未来可以提供修复建议：**
```json
{
  "warnings": [{
    "field": "loginUi",
    "message": "字段为对象类型",
    "suggestion": "建议改为字符串格式",
    "auto_fix": "web"  // 自动修复建议
  }]
}
```

#### 10.2 规整化质量提升

**持续改进：**
- 收集用户反馈
- 优化字段检测逻辑
- 提高兼容性评分准确度

---

## 📋 完整实施检查清单

### Rust端
- [ ] 创建 `src/api/normalize.rs`
- [ ] 实现规整化逻辑
- [ ] 实现字段转换检测
- [ ] 注册路由
- [ ] 编写测试用例
- [ ] 测试通过

### Go端
- [ ] 数据库迁移SQL
- [ ] 更新BookSource实体
- [ ] 创建 `normalize.go`
- [ ] 修改 `CreatePrivateSource`
- [ ] 修改RustGateway使用逻辑
- [ ] 编写迁移脚本
- [ ] 编写测试用例
- [ ] 测试通过

### Flutter端
- [ ] 更新BookSource模型
- [ ] 创建警告横幅组件
- [ ] 修改详情页显示
- [ ] 修改列表页显示
- [ ] 测试UI展示

### 上线
- [ ] Rust接口部署
- [ ] Go服务部署
- [ ] 执行数据迁移
- [ ] Flutter版本发布
- [ ] 监控指标正常
- [ ] 用户文档更新

---

## 🎯 预期效果

**技术指标：**
- ✅ 书源可用率：70-80% → **100%**
- ✅ 数据保真：**100%**
- ✅ 规整化耗时：<100ms
- ✅ 迁移成功率：>95%

**用户体验：**
- ✅ 导入不再失败
- ✅ 透明的兼容性提示
- ✅ 原始数据可编辑
- ✅ 阅读功能100%可用

---

## 💡 给GPT的建议

**实施顺序：**
1. 先做Rust端（核心逻辑）
2. 再做Go端（调用集成）
3. 最后做Flutter端（UI展示）

**遇到问题：**
- Rust编译错误 → 检查依赖版本
- Go调用失败 → 检查URL配置
- 数据库迁移慢 → 分批处理

**质量保证：**
- 每个步骤都写测试
- 测试通过再进入下一步
- 端到端测试必须做

---

**文档版本：** 1.0  
**最后更新：** 2026-06-11  
**适用场景：** 书源双JSON存储实施  
**预计工期：** 2-3天  
**难度等级：** 中等


---

## 附录A：最终合理性检查

### 总体评分：⭐⭐⭐⭐ (4/5星) - 推荐实施

#### 技术可行性 ✅
- ✅ 架构合理（Go存储 + Rust规整）
- ✅ 性能可控（创建+30-50ms，使用无影响）
- ✅ 数据一致性可保证（需补充编辑逻辑）
- ✅ 可回滚、可降级

#### 业务价值 ⭐⭐⭐⭐⭐
- ✅ 解决核心痛点（70%→100%可用率）
- ✅ 用户体验显著提升
- ✅ 数据完全保真

#### 风险评估
- 🟡 存储成本增加50%（可接受）
- 🟡 规整化接口单点故障（有降级方案）
- 🟡 两份JSON可能不同步（需补充编辑逻辑）
- 🟢 其他风险可控

#### 必须补充的内容

**1. 编辑时重新规整化（必须）**
```go
func (s *Service) UpdatePrivateSource(ctx context.Context, input UpdateInput) error {
    existing, _ := s.repo.FindByID(ctx, input.ID)
    
    // 如果source_json被修改，重新规整化
    if input.SourceJSON != "" && input.SourceJSON != existing.SourceJSON {
        normalized, err := s.normalizeSourceJSON(ctx, input.SourceJSON)
        if err == nil && normalized.IsValid {
            input.SourceJSONNormalized = normalized.NormalizedJSON
            input.NormalizationWarnings = normalized.FormatWarnings()
        } else {
            // 规整化失败，记录警告
            input.NormalizationWarnings = "规整化失败"
        }
    }
    
    return s.repo.Update(ctx, input)
}
```

**2. 超时保护（建议）**
```go
func (s *Service) normalizeSourceJSON(ctx context.Context, sourceJSON string) (*NormalizeResponse, error) {
    // 设置5秒超时
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    
    // ... 调用Rust接口 ...
}
```

**3. 监控指标（建议）**
```go
// 记录规整化指标
metrics.RecordNormalizeDuration(duration)
metrics.RecordNormalizeSuccess(success)
metrics.RecordWarningCount(len(warnings))
```

#### 替代方案对比

| 方案 | 可用性 | 数据保真 | 用户体验 | 实现成本 | 推荐度 |
|------|--------|---------|---------|---------|--------|
| **双JSON存储** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ 推荐 |
| 只规整版 | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ❌ 丢数据 |
| 完全兼容 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ | ❌ 成本太高 |
| 让用户改 | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐⭐⭐ | ❌ 体验差 |

#### 最终建议

**✅ 立即实施，但需要补充：**
1. 编辑时重新规整化逻辑（必须）
2. 超时保护（建议）
3. 监控指标（建议）

**预期效果：**
- 可用率：70-80% → **100%**
- 数据保真：**100%**
- 用户体验：报错 → 透明提示

---

## 附录B：私人书源检测失败后的可见性问题

### 问题说明

**用户关心的问题：** 如果私人书源检测失败后，在搜索范围内能显示出来吗？

### 答案：取决于过滤逻辑

#### 情况1：严格过滤（不显示）❌

**Go后端代码：**
```go
func GetUserSources(ctx context.Context, userID string) ([]BookSource, error) {
    return repo.Find(ctx, FindOptions{
        Filters: map[string]interface{}{
            "user_id": userID,
            "enabled": true,
            "last_test_status": "success",  // ❌ 只返回成功的
        },
    })
}
```

**结果：** 检测失败的书源**不会显示**

#### 情况2：宽松过滤（显示）✅ 推荐

**Go后端代码：**
```go
func GetUserSources(ctx context.Context, userID string) ([]BookSource, error) {
    sources, err := repo.Find(ctx, FindOptions{
        Filters: map[string]interface{}{
            "user_id": userID,
            "enabled": true,  // ✅ 只过滤enabled
            // ✅ 不过滤last_test_status
        },
    })
    
    if err != nil {
        return nil, err
    }
    
    // 按检测状态排序：成功的在前
    sort.SliceStable(sources, func(i, j int) bool {
        statusI := sources[i].LastTestStatus
        statusJ := sources[j].LastTestStatus
        
        // success > unknown > failed
        scoreI := statusScore(statusI)
        scoreJ := statusScore(statusJ)
        
        return scoreI > scoreJ
    })
    
    return sources, nil
}

func statusScore(status string) int {
    switch status {
    case "success": return 3
    case "unknown": return 2
    case "failed":  return 1
    default:        return 0
    }
}
```

**结果：** 检测失败的书源**会显示**（但排在后面）

### 推荐实现

#### Go端：返回所有启用的，按状态排序

```go
// 在步骤3的service.go中添加

// GetUserAccessibleSources 获取用户可访问的书源
func (s *Service) GetUserAccessibleSources(
    ctx context.Context,
    userID string,
) ([]BookSource, error) {
    sources, err := s.repo.Find(ctx, FindOptions{
        Filters: map[string]interface{}{
            "user_id": userID,
            "enabled": true,  // 只要启用就返回
        },
    })
    
    if err != nil {
        return nil, err
    }
    
    // 按状态排序：成功的在前
    sort.SliceStable(sources, func(i, j int) bool {
        return statusScore(sources[i].LastTestStatus) > 
               statusScore(sources[j].LastTestStatus)
    })
    
    return sources, nil
}

func statusScore(status string) int {
    switch status {
    case "success": return 3
    case "unknown": return 2
    case "failed":  return 1
    default:        return 0
    }
}
```

#### Flutter端：显示所有但标记状态

```dart
// 在步骤5的基础上，添加搜索书源选择器

class SearchSourceSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(userSourcesProvider);
    
    return sourcesAsync.when(
      data: (sources) => ListView.builder(
        itemCount: sources.length,
        itemBuilder: (context, index) {
          final source = sources[index];
          final isFailed = source.lastTestStatus == 'failed';
          final isSelected = ref.watch(
            selectedSourceIdsProvider.select((ids) => ids.contains(source.id))
          );
          
          return CheckboxListTile(
            title: Text(source.name),
            subtitle: isFailed
                ? Text(
                    '上次检测失败，可能无法搜索',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  )
                : null,
            secondary: isFailed
                ? Icon(Icons.warning_amber, color: Colors.orange)
                : null,
            value: isSelected,
            onChanged: (selected) {
              // 检测失败时给予提示
              if (isFailed && selected == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('此书源上次检测失败，搜索可能无结果'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              
              ref.read(selectedSourceIdsProvider.notifier)
                  .toggle(source.id);
            },
          );
        },
      ),
      loading: () => Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('加载失败: $err')),
    );
  }
}
```

**UI效果：**
```
搜索 - 选择书源

☑️ 书源A（检测成功）
☐ 书源B ⚠️
   上次检测失败，可能无法搜索
☑️ 书源C（检测成功）
```

### 推荐逻辑总结

**✅ 应该显示检测失败的书源，因为：**
1. 检测失败不代表完全不可用（可能是临时网络问题）
2. 用户应该有选择权
3. 明明添加了却看不到，用户体验差

**✅ 但需要明确标记：**
1. 用图标标识（⚠️）
2. 用文字说明（"上次检测失败"）
3. 排序靠后（成功的优先）
4. 选择时给予提示

### 如何检查当前逻辑

```bash
# 检查Go后端是否过滤test_status
cd read-admin
grep -r "last_test_status.*success" internal/application/booksource/

# 检查Flutter前端是否过滤test_status
cd flutterreadbook
grep -r "lastTestStatus.*==.*success" lib/features/search/

# 如果找到这种过滤，说明检测失败的不会显示
```

---

**文档更新完成！现在包含了合理性检查和可见性问题的完整说明。**

