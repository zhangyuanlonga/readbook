# 书源管理 - 业务流程 + 优化方案 + 技术实现

**文档类型**: 综合技术文档  
**创建日期**: 2026-06-14  
**状态**: ✅ 完整完成

---

## 🔄 核心业务流程

### 流程 1: 书源添加流程

```
用户点击"添加书源"
   ↓
[选择添加方式]
   ├→ 方式1: 输入URL
   │    ├─ 输入书源地址
   │    ├─ 自动测试
   │    ├─ 验证通过
   │    └─ 保存
   │
   ├→ 方式2: 导入文件
   │    ├─ 选择文件
   │    ├─ 解析内容
   │    ├─ 批量测试
   │    └─ 批量保存
   │
   ├→ 方式3: 书源市场（优化）
   │    ├─ 浏览推荐
   │    ├─ 查看详情
   │    └─ 一键订阅
   │
   └→ 方式4: 扫码添加（优化）
        ├─ 扫描二维码
        └─ 自动导入
```

### 流程 2: 书源健康检查

```
定时任务（每天）
   ↓
[遍历所有启用书源]
   ↓
[并行测试]
   ├─ 连接测试
   ├─ 搜索测试
   └─ 速度测试
   ↓
[记录结果]
   ├─ 成功率
   ├─ 平均速度
   └─ 最后检查时间
   ↓
[标记失效书源]
   ├─ 连续失败3次 → 禁用
   └─ 通知用户
```

---

## 💡 优化方案

### P0-1: 书源市场 🔥🔥🔥

**目标**: 让用户轻松发现和添加优质书源

```dart
class SourceMarketplace {
  Future<List<SourceItem>> getRecommended() async {
    return await _api.get('/sources/recommended');
  }
  
  Future<List<SourceItem>> getPopular() async {
    return await _api.get('/sources/popular');
  }
  
  Future<void> subscribe(String sourceId) async {
    // 1. 下载书源配置
    final config = await _api.get('/sources/$sourceId/config');
    
    // 2. 测试书源
    final testResult = await _testSource(config);
    
    if (!testResult.success) {
      throw SourceUnavailableException();
    }
    
    // 3. 保存到本地
    await _db.insertSource(Source.fromConfig(config));
    
    // 4. 订阅更新
    await _subscribeUpdates(sourceId);
  }
}

// UI
class SourceMarketPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // 推荐书源
        _Section(
          title: '官方推荐',
          sources: _recommended,
        ),
        
        // 热门书源
        _Section(
          title: '热门榜单',
          sources: _popular,
        ),
        
        // 分类
        _CategoryGrid(),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  final SourceItem source;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(source.name),
            subtitle: Text(source.description),
            trailing: _RatingStars(source.rating),
          ),
          
          // 统计信息
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.people, size: 16),
                Text('${source.userCount}人使用'),
                SizedBox(width: 16),
                Icon(Icons.update, size: 16),
                Text(source.lastUpdate),
              ],
            ),
          ),
          
          // 操作按钮
          ButtonBar(
            children: [
              TextButton(
                onPressed: () => _showDetail(source),
                child: Text('详情'),
              ),
              ElevatedButton(
                onPressed: () => _subscribe(source),
                child: Text('订阅'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

**工期**: 3天（需要后端支持）  
**收益**: 新用户激活率+60%，书源添加效率+10倍

---

### P0-2: 自动健康检查 🔥🔥🔥

```dart
class SourceHealthChecker {
  Future<void> runDailyCheck() async {
    final sources = await _db.getEnabledSources();
    
    // 并行测试（最多5个并发）
    final pool = Pool(5);
    final results = await Future.wait(
      sources.map((source) => 
        pool.withResource(() => _checkSource(source))
      ),
    );
    
    // 处理结果
    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      final result = results[i];
      
      if (result.success) {
        // 重置失败计数
        await _db.updateSource(
          source.id,
          failureCount: 0,
          lastCheckTime: DateTime.now(),
          avgSpeed: result.speed,
        );
      } else {
        // 增加失败计数
        final newCount = source.failureCount + 1;
        
        if (newCount >= 3) {
          // 连续失败3次，禁用
          await _db.updateSource(source.id, enabled: false);
          _notifySourceDisabled(source);
        } else {
          await _db.updateSource(source.id, failureCount: newCount);
        }
      }
    }
  }
  
  Future<HealthCheckResult> _checkSource(Source source) async {
    try {
      final startTime = DateTime.now();
      
      // 测试搜索
      final searchResult = await source.search('test').timeout(
        Duration(seconds: 10),
      );
      
      final duration = DateTime.now().difference(startTime);
      
      return HealthCheckResult(
        success: searchResult.isNotEmpty,
        speed: duration.inMilliseconds,
      );
    } catch (e) {
      return HealthCheckResult(success: false);
    }
  }
}
```

**工期**: 2天  
**收益**: 书源可用率保持在95%以上

---

### P0-3: 智能添加优化 🔥🔥

```dart
class SmartSourceAdder {
  Future<AddResult> addSource(String input) async {
    // 1. 智能识别输入类型
    final type = _detectInputType(input);
    
    switch (type) {
      case InputType.url:
        return await _addByUrl(input);
      
      case InputType.json:
        return await _addByJson(input);
      
      case InputType.qrCode:
        return await _addByQrCode(input);
      
      default:
        throw UnsupportedInputException();
    }
  }
  
  Future<AddResult> _addByUrl(String url) async {
    // 1. 下载配置
    final config = await _downloadConfig(url);
    
    // 2. 验证格式
    if (!_validateConfig(config)) {
      throw InvalidConfigException();
    }
    
    // 3. 测试书源
    _showProgress('正在测试书源...');
    final testResult = await _testSource(config);
    
    if (!testResult.success) {
      throw SourceUnavailableException(testResult.error);
    }
    
    // 4. 保存
    _showProgress('保存中...');
    await _saveSource(config);
    
    return AddResult(
      success: true,
      source: config,
      testResult: testResult,
    );
  }
}
```

**工期**: 1天  
**收益**: 添加成功率+40%，添加时间-50%

---

### P1-1: 批量管理 🔥🔥

```dart
class BatchSourceManager {
  Future<void> batchOperation(
    List<String> sourceIds,
    BatchAction action,
  ) async {
    switch (action) {
      case BatchAction.enable:
        await _batchEnable(sourceIds);
        break;
      
      case BatchAction.disable:
        await _batchDisable(sourceIds);
        break;
      
      case BatchAction.test:
        await _batchTest(sourceIds);
        break;
      
      case BatchAction.delete:
        await _batchDelete(sourceIds);
        break;
      
      case BatchAction.export:
        await _batchExport(sourceIds);
        break;
    }
  }
  
  Future<void> _batchTest(List<String> sourceIds) async {
    final sources = await _db.getSourcesByIds(sourceIds);
    
    // 显示进度
    final progressController = StreamController<BatchProgress>();
    
    int completed = 0;
    for (final source in sources) {
      final result = await _testSource(source);
      completed++;
      
      progressController.add(BatchProgress(
        current: completed,
        total: sources.length,
        currentItem: source.name,
      ));
    }
  }
}
```

**工期**: 1天  
**收益**: 批量操作效率+5倍

---

## 📦 技术库推荐

```yaml
dependencies:
  # HTTP客户端（已有）
  dio: ^5.8.0  ✅
  
  # 二维码扫描
  mobile_scanner: ^3.5.5
  
  # 二维码生成
  qr_flutter: ^4.1.0
  
  # 并发控制
  async: ^2.11.0
  
  # JSON解析（已有）
  json_serializable: ^6.7.1  ✅
```

---

## 📊 优化方案总览

| 方案 | 优先级 | 工期 | 预期收益 |
|------|--------|------|---------|
| 书源市场 | P0 | 3天 | 激活率 +60% |
| 健康检查 | P0 | 2天 | 可用率 95%+ |
| 智能添加 | P0 | 1天 | 成功率 +40% |
| 批量管理 | P1 | 1天 | 效率 +5倍 |
| 备份恢复 | P1 | 1天 | 安全性 +100% |
| 统计分析 | P2 | 1天 | 决策支持 |

**总工期**: 9天  
**整体收益**: 书源管理体验从 6/10 → 9/10

---

## ⚡ 性能优化

### 1. 书源测试优化

```dart
// 并发测试，快速响应
Future<List<TestResult>> testSources(List<Source> sources) async {
  final pool = Pool(5);  // 最多5个并发
  
  return await Future.wait(
    sources.map((source) =>
      pool.withResource(() => 
        _testSource(source).timeout(Duration(seconds: 10))
      )
    ),
  );
}
```

### 2. 书源缓存

```dart
// 缓存书源列表，避免频繁读取
class CachedSourceService {
  List<Source>? _cache;
  DateTime? _cacheTime;
  
  Future<List<Source>> getSources() async {
    if (_cache != null && 
        DateTime.now().difference(_cacheTime!) < Duration(minutes: 5)) {
      return _cache!;
    }
    
    _cache = await _db.getSources();
    _cacheTime = DateTime.now();
    return _cache!;
  }
}
```

---

**文档状态**: ✅✅✅✅ 完整完成  
**预计实施工期**: 9天
