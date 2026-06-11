# 书源导入功能优化方案

创建时间：2026-06-11  
优先级：P0（影响用户体验）  
问题：大 JSON（几千行）粘贴卡顿、截断

---

## 问题背景

### 当前问题

**核心问题：** 书源 JSON 可能有几千行，复制粘贴到输入框会导致：

1. **卡顿严重**
   - TextField 处理大文本性能差
   - 输入框渲染慢，卡顿明显
   - 用户体验很差

2. **内容截断**
   - 部分平台（移动端）剪贴板有长度限制
   - 超长 JSON 可能被截断
   - 导致 JSON 格式错误

3. **操作不便**
   - 只能手动复制粘贴
   - 没有其他导入方式
   - 出错后难以定位问题

### 当前实现

```dart
// 只有一个大的 TextField
TextFormField(
  controller: _jsonController,
  minLines: 8,
  maxLines: 14,
  decoration: const InputDecoration(
    labelText: 'Legado JSON',
  ),
)
```

**问题：**
- 单一输入方式
- 无法处理超大文本
- 没有进度反馈

---

## 改进方案

### 方案总览

**新增 3 种导入方式 + 优化粘贴输入：**

1. ⭐ **链接导入**（推荐）- 网络下载
2. ⭐ **文件导入**（本地）- 选择本地文件
3. ✅ **粘贴输入**（优化）- 改进现有方式
4. 🔄 **扫码导入**（可选）- 扫描二维码

---

## 一、链接导入（新增，推荐）⭐

### 1.1 功能说明

**使用场景：**
- 用户从网站/论坛获取书源分享链接
- 直接粘贴链接，自动下载书源
- 适合大 JSON，无大小限制

**流程：**
```
用户输入链接 → 验证格式 → 后台下载 → 解析 JSON → 导入成功
```

### 1.2 UI 设计

```dart
// 链接输入对话框
┌─────────────────────────────────────┐
│  📥 通过链接导入书源                  │
├─────────────────────────────────────┤
│  🌐 输入书源链接                      │
│  ┌───────────────────────────────┐  │
│  │ https://example.com/source.json │  │
│  └───────────────────────────────┘  │
│                                      │
│  💡 支持的链接格式：                  │
│  • 直接 JSON 文件链接                │
│  • GitHub Gist                       │
│  • Pastebin                          │
│                                      │
│  [取消]  [导入]                      │
└─────────────────────────────────────┘
```

### 1.3 实现要点

```dart
// lib/features/mine/application/book_source_url_import_service.dart

class BookSourceUrlImportService {
  Future<PrivateBookSourceInput> importFromUrl(String url) async {
    // 1. 验证链接格式
    if (!_isValidUrl(url)) {
      throw const FormatException('链接格式不正确');
    }
    
    // 2. 下载 JSON（显示进度）
    final json = await _downloadWithProgress(url);
    
    // 3. 解析验证
    if (!PrivateBookSourceInput.isValidJson(json)) {
      throw const FormatException('JSON 格式不正确');
    }
    
    // 4. 返回书源
    return PrivateBookSourceInput.fromJson(json);
  }
  
  Future<String> _downloadWithProgress(String url) async {
    // 使用 Dio 下载，支持进度回调
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.plain),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          _progressController.add(received / total);
        }
      },
    );
    return response.data as String;
  }
}
```

**优点：**
- ✅ 无大小限制（几千行、上万行都可以）
- ✅ 自动下载，用户方便
- ✅ 显示进度，体验好
- ✅ 可以验证链接有效性

**缺点：**
- ⚠️ 需要网络
- ⚠️ 链接可能失效

---

## 二、文件导入（新增，本地）⭐

### 2.1 功能说明

**使用场景：**
- 用户本地保存了书源 JSON 文件
- 从其他 APP 分享的文件
- 适合大 JSON，无大小限制

**流程：**
```
点击"选择文件" → 系统文件选择器 → 读取文件 → 解析 JSON → 导入成功
```

### 2.2 UI 设计

```dart
// 文件选择按钮
┌─────────────────────────────────────┐
│  📁 从文件导入                        │
├─────────────────────────────────────┤
│  点击选择本地 JSON 文件               │
│  ┌───────────────────────────────┐  │
│  │  📄 选择文件                   │  │
│  └───────────────────────────────┘  │
│                                      │
│  💡 支持格式：.json .txt             │
│                                      │
│  已选择：book_source.json (125KB)    │
│                                      │
│  [取消]  [导入]                      │
└─────────────────────────────────────┘
```

### 2.3 实现要点

```dart
// lib/features/mine/application/book_source_file_import_service.dart

class BookSourceFileImportService {
  Future<PrivateBookSourceInput> importFromFile() async {
    // 1. 打开文件选择器
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
      allowMultiple: false,
    );
    
    if (result == null || result.files.isEmpty) {
      throw const CancelledException();
    }
    
    final file = result.files.first;
    
    // 2. 检查文件大小（限制 10MB）
    if (file.size > 10 * 1024 * 1024) {
      throw const FormatException('文件过大（最大 10MB）');
    }
    
    // 3. 读取文件内容
    String json;
    if (file.path != null) {
      // 桌面端/移动端：有路径
      json = await File(file.path!).readAsString();
    } else if (file.bytes != null) {
      // Web 端：只有字节
      json = utf8.decode(file.bytes!);
    } else {
      throw const FormatException('无法读取文件');
    }
    
    // 4. 解析验证
    if (!PrivateBookSourceInput.isValidJson(json)) {
      throw const FormatException('JSON 格式不正确');
    }
    
    return PrivateBookSourceInput.fromJson(json);
  }
}
```

**依赖：**
```yaml
# pubspec.yaml
dependencies:
  file_picker: ^8.0.0  # 文件选择器
```

**优点：**
- ✅ 无大小限制（本地文件）
- ✅ 不需要网络
- ✅ 支持跨平台（移动端、桌面端、Web）
- ✅ 系统原生选择器，体验好

**缺点：**
- ⚠️ 用户需要先保存文件

---

## 三、粘贴输入（优化现有）✅

### 3.1 当前问题

```dart
// 当前：直接用 TextField，大文本卡顿
TextFormField(
  controller: _jsonController,
  minLines: 8,
  maxLines: 14,  // 只显示 14 行，几千行显示不完
)
```

### 3.2 优化方案

#### 方案A：异步粘贴 + 进度提示（推荐）

```dart
// 改进：异步粘贴，显示进度

class _OptimizedJsonInput extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 只显示前 100 行的预览
        TextField(
          controller: _previewController,
          minLines: 8,
          maxLines: 14,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'JSON 预览（前 100 行）',
            hintText: _fullJson.isEmpty ? '点击下方按钮粘贴' : null,
          ),
        ),
        
        SizedBox(height: 12),
        
        // 粘贴按钮
        if (_fullJson.isEmpty)
          FilledButton.icon(
            onPressed: _pasteFromClipboard,
            icon: Icon(Icons.content_paste),
            label: Text('从剪贴板粘贴'),
          ),
        
        // 已粘贴提示
        if (_fullJson.isNotEmpty)
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text('已粘贴 ${_lineCount} 行 (${_sizeKB} KB)'),
              Spacer(),
              TextButton(
                onPressed: _clear,
                child: Text('清除'),
              ),
            ],
          ),
      ],
    );
  }
  
  Future<void> _pasteFromClipboard() async {
    try {
      // 1. 显示加载
      setState(() => _loading = true);
      
      // 2. 异步读取剪贴板（不阻塞 UI）
      final clipboardData = await Clipboard.getData('text/plain');
      final json = clipboardData?.text?.trim() ?? '';
      
      if (json.isEmpty) {
        throw const FormatException('剪贴板为空');
      }
      
      // 3. 验证 JSON（异步）
      await Future.microtask(() {
        if (!PrivateBookSourceInput.isValidJson(json)) {
          throw const FormatException('JSON 格式不正确');
        }
      });
      
      // 4. 更新数据
      setState(() {
        _fullJson = json;
        _lineCount = json.split('\n').length;
        _sizeKB = (utf8.encode(json).length / 1024).toStringAsFixed(1);
        
        // 只显示前 100 行预览
        final lines = json.split('\n');
        final preview = lines.take(100).join('\n');
        _previewController.text = preview + (lines.length > 100 ? '\n\n... (还有 ${lines.length - 100} 行)' : '');
        
        _loading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('粘贴成功：$_lineCount 行')),
      );
      
    } catch (error) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('粘贴失败：${error.toString()}')),
      );
    }
  }
}
```

**优点：**
- ✅ 异步处理，不卡顿
- ✅ 只显示预览，性能好
- ✅ 显示行数和大小，用户清楚
- ✅ 可以清除重新粘贴

---

#### 方案B：流式验证（备选）

```dart
// 大 JSON 流式验证，边读边验证

Future<bool> _validateJsonStream(String json) async {
  // 分块验证，避免一次性解析导致卡顿
  const chunkSize = 10000;  // 每次验证 10000 字符
  
  for (var i = 0; i < json.length; i += chunkSize) {
    final end = math.min(i + chunkSize, json.length);
    final chunk = json.substring(i, end);
    
    // 异步执行，不阻塞 UI
    await Future.microtask(() {
      // 简单验证：检查括号匹配
      _validateChunk(chunk);
    });
    
    // 更新进度
    _progressController.add((i + chunkSize) / json.length);
  }
  
  // 最后验证完整 JSON
  return PrivateBookSourceInput.isValidJson(json);
}
```

---

## 四、扫码导入（可选）🔄

### 4.1 功能说明

**使用场景：**
- 书源网站提供二维码
- 扫码直接导入
- 适合快速分享

**流程：**
```
点击"扫码" → 打开摄像头 → 扫描二维码 → 解析链接 → 下载 JSON → 导入
```

### 4.2 实现要点

```dart
// 依赖
dependencies:
  mobile_scanner: ^5.0.0  # 二维码扫描

// 使用
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => QRScannerPage(
      title: '扫描书源二维码',
    ),
  ),
);

if (result != null) {
  // 二维码内容是书源链接
  await _importFromUrl(result as String);
}
```

**优先级：** P2（锦上添花，非必须）

---

## 五、UI 改进方案（详细设计）

### 5.0 UI 方案选择（已确定）

**推荐方案：右上角 [+ 添加] 按钮 + 底部弹层选择** ⭐⭐⭐

**理由：**
- ✅ 简洁明了，不占用页面空间
- ✅ 符合移动端习惯
- ✅ 易于扩展（更多功能放 [⋮ 更多] 菜单）
- ✅ 用户体验好

---

### 5.1 完整导入流程（重要）

**三步流程：**
```
步骤1：书源列表页 → 点击 [+ 添加] → 弹出底部弹层
步骤2：选择导入方式（3选1）→ 进入完整表单页面
步骤3：导入 JSON + 填写表单 → 提交保存
```

**关键点：** 不管用什么方式导入，最后都要填表单！

---

### 5.2 导入表单设计（完整版）

```dart
// 完整的导入表单

┌─────────────────────────────────────┐
│  ← 添加书源                          │
├─────────────────────────────────────┤
│                                      │
│  📥 书源 JSON                         │
│                                      │
│  [🌐 链接导入] [📁 文件] [📋 粘贴]   │ ← 3种方式选一个
│                                      │
│  ┌───────────────────────────────┐  │
│  │ {                             │  │ ← JSON 预览
│  │   "name": "笔趣阁",           │  │   （只读，前100行）
│  │   "url": "https://...",       │  │
│  │   ...                         │  │
│  │ }                             │  │
│  │                               │  │
│  │ ... (还有 2580 行)            │  │
│  └───────────────────────────────┘  │
│  ✅ 已加载 2680 行 (450KB)           │
│  [清除重新选择]                      │
│                                      │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │ ← 分隔线
│                                      │
│  📝 书源信息（必填）                  │
│                                      │
│  名称 *                              │
│  ┌───────────────────────────────┐  │
│  │ 笔趣阁                        │  │ ← 可以从JSON自动填充
│  └───────────────────────────────┘  │
│                                      │
│  类型 *                              │
│  ┌───────────────────────────────┐  │
│  │ 网络书源 ▼                    │  │
│  └───────────────────────────────┘  │
│                                      │
│  分组                                │
│  ┌───────────────────────────────┐  │
│  │ 默认 ▼                        │  │
│  └───────────────────────────────┘  │
│                                      │
│  描述                                │
│  ┌───────────────────────────────┐  │
│  │ 自动从JSON解析，也可手动修改   │  │
│  └───────────────────────────────┘  │
│                                      │
│  [取消]  [保存]                      │
└─────────────────────────────────────┘
```

---

### 5.3 导入方式选择（3个Tab）

```dart
// 上方 3 个 Tab 切换导入方式

┌─────────────────────────────────────┐
│  [🌐 链接] [📁 文件] [📋 粘贴]  ← Tab│
├─────────────────────────────────────┤
│                                      │
│  // Tab 1: 链接导入                 │
│  ┌───────────────────────────────┐  │
│  │ https://example.com/source.json│  │
│  └───────────────────────────────┘  │
│  [获取]                              │
│                                      │
│  // Tab 2: 文件导入                 │
│  [📁 选择文件]                       │
│  已选：book_source.json (125KB)      │
│                                      │
│  // Tab 3: 粘贴                     │
│  [📋 从剪贴板粘贴]                   │
│  ┌───────────────────────────────┐  │
│  │ 或直接粘贴到这里...           │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### 5.2 进度反馈

```dart
// 导入过程显示进度

┌─────────────────────────────────────┐
│  正在导入书源...                      │
├─────────────────────────────────────┤
│                                      │
│  ████████████░░░░░░░  65%           │
│                                      │
│  正在下载 JSON (320KB / 500KB)       │
│                                      │
│  [取消]                              │
└─────────────────────────────────────┘
```

### 5.3 错误提示

```dart
// 友好的错误提示

┌─────────────────────────────────────┐
│  ⚠️ 导入失败                         │
├─────────────────────────────────────┤
│                                      │
│  原因：JSON 格式不正确                │
│                                      │
│  详情：                               │
│  第 125 行：缺少逗号                  │
│  "name": "书源1"                     │
│          ↑ 这里应该有逗号             │
│                                      │
│  [复制错误信息]  [重试]  [取消]       │
└─────────────────────────────────────┘
```

---

## 六、实施计划

### 阶段1：基础改进（1周，P0）

**Week 1：**
- [ ] 优化粘贴输入（异步 + 预览）
- [ ] 新增链接导入功能
- [ ] 新增文件导入功能
- [ ] 创建导入方式选择页面

**产出：**
- 3 种导入方式可用
- 大 JSON 不再卡顿

---

### 阶段2：体验优化（3天，P1）

**Week 2：**
- [ ] 添加进度提示
- [ ] 优化错误提示（友好、定位）
- [ ] 添加导入历史记录
- [ ] 添加批量导入（多个文件）

**产出：**
- 用户体验流畅
- 错误提示清晰

---

### 阶段3：高级功能（可选，P2）

**Week 3+：**
- [ ] 扫码导入
- [ ] 导入预览（导入前查看书源信息）
- [ ] 自动检测链接（粘贴时自动识别）
- [ ] 云端备份导入

---

## 七、技术实现

### 7.1 文件结构

```
lib/features/mine/
├── application/
│   ├── book_source_url_import_service.dart      # 链接导入
│   ├── book_source_file_import_service.dart     # 文件导入
│   └── book_source_import_validator.dart        # JSON 验证
├── presentation/
│   ├── book_source_import_method_page.dart      # 导入方式选择
│   ├── book_source_url_import_dialog.dart       # 链接导入对话框
│   ├── book_source_paste_input_widget.dart      # 优化的粘贴输入
│   └── book_source_import_progress_dialog.dart  # 进度对话框
└── private_book_sources_page.dart               # 主页面（改造）
```

### 7.2 依赖添加

```yaml
# pubspec.yaml
dependencies:
  file_picker: ^8.0.0        # 文件选择
  mobile_scanner: ^5.0.0     # 二维码扫描（可选）
  path_provider: ^2.1.0      # 临时文件存储
```

### 7.3 核心代码示例

```dart
// lib/features/mine/presentation/private_book_source_form_page.dart

class PrivateBookSourceFormPage extends StatefulWidget {
  const PrivateBookSourceFormPage({
    super.key,
    this.existingItem,  // 编辑时传入
  });
  
  final PrivateBookSource? existingItem;
  
  @override
  State<PrivateBookSourceFormPage> createState() => _PrivateBookSourceFormPageState();
}

class _PrivateBookSourceFormPageState extends State<PrivateBookSourceFormPage> {
  final _formKey = GlobalKey<FormState>();
  
  // JSON 相关
  String _fullJson = '';  // 完整 JSON（可能几千行）
  final _jsonPreviewController = TextEditingController();  // 只显示预览
  
  // 表单字段
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = '网络书源';
  String _selectedGroup = '默认';
  
  // 导入方式（Tab）
  int _importMethodIndex = 2;  // 默认"粘贴"
  
  @override
  void initState() {
    super.initState();
    
    // 如果是编辑，加载现有数据
    if (widget.existingItem != null) {
      _loadExistingItem();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem == null ? '添加书源' : '编辑书源'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // ═══════════════════════════════════
            // 第一部分：导入 JSON
            // ═══════════════════════════════════
            Text(
              '📥 书源 JSON',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
            
            // Tab 切换导入方式
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text('🌐 链接'), icon: Icon(Icons.link)),
                ButtonSegment(value: 1, label: Text('📁 文件'), icon: Icon(Icons.folder_open)),
                ButtonSegment(value: 2, label: Text('📋 粘贴'), icon: Icon(Icons.content_paste)),
              ],
              selected: {_importMethodIndex},
              onSelectionChanged: (Set<int> selected) {
                setState(() => _importMethodIndex = selected.first);
              },
            ),
            
            SizedBox(height: 12),
            
            // 根据选择的 Tab 显示不同输入方式
            _buildImportMethodContent(),
            
            SizedBox(height: 12),
            
            // JSON 预览（只读，前100行）
            if (_fullJson.isNotEmpty) ...[
              TextField(
                controller: _jsonPreviewController,
                readOnly: true,
                minLines: 8,
                maxLines: 14,
                decoration: InputDecoration(
                  labelText: 'JSON 预览（前 100 行）',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text('已加载 ${_getLineCount()} 行 (${_getSizeKB()} KB)'),
                  Spacer(),
                  TextButton(
                    onPressed: _clearJson,
                    child: Text('清除重新选择'),
                  ),
                ],
              ),
            ],
            
            SizedBox(height: 24),
            Divider(),
            SizedBox(height: 24),
            
            // ═══════════════════════════════════
            // 第二部分：填写表单（必填）
            // ═══════════════════════════════════
            Text(
              '📝 书源信息（必填）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
            
            // 名称
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '名称 *',
                hintText: '例如：笔趣阁',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入书源名称';
                }
                return null;
              },
            ),
            
            SizedBox(height: 16),
            
            // 类型（下拉）
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: '类型 *',
                border: OutlineInputBorder(),
              ),
              items: ['网络书源', '本地书源', '其他'].map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedType = value!);
              },
            ),
            
            SizedBox(height: 16),
            
            // 分组（下拉）
            DropdownButtonFormField<String>(
              value: _selectedGroup,
              decoration: InputDecoration(
                labelText: '分组',
                border: OutlineInputBorder(),
              ),
              items: ['默认', '常用', '备用', '测试'].map((group) {
                return DropdownMenuItem(value: group, child: Text(group));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedGroup = value!);
              },
            ),
            
            SizedBox(height: 16),
            
            // 描述
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: '描述',
                hintText: '可选，描述书源的特点和来源',
                border: OutlineInputBorder(),
              ),
            ),
            
            SizedBox(height: 24),
            
            // 提交按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消'),
                ),
                SizedBox(width: 8),
                FilledButton(
                  onPressed: _fullJson.isEmpty ? null : _save,
                  child: Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 根据 Tab 显示不同的导入方式
  Widget _buildImportMethodContent() {
    switch (_importMethodIndex) {
      case 0:
        return _buildUrlImport();
      case 1:
        return _buildFileImport();
      case 2:
        return _buildPasteImport();
      default:
        return SizedBox.shrink();
    }
  }
  
  // 链接导入
  Widget _buildUrlImport() {
    final urlController = TextEditingController();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: urlController,
          decoration: InputDecoration(
            hintText: 'https://example.com/source.json',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
        ),
        SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _importFromUrl(urlController.text),
          icon: Icon(Icons.download),
          label: Text('获取'),
        ),
      ],
    );
  }
  
  // 文件导入
  Widget _buildFileImport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _importFromFile,
          icon: Icon(Icons.folder_open),
          label: Text('选择文件'),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.all(16),
          ),
        ),
        if (_selectedFileName.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            '已选：$_selectedFileName ($_selectedFileSizeKB KB)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }
  
  // 粘贴导入
  Widget _buildPasteImport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_fullJson.isEmpty) ...[
          OutlinedButton.icon(
            onPressed: _pasteFromClipboard,
            icon: Icon(Icons.content_paste),
            label: Text('从剪贴板粘贴'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.all(16),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '或直接粘贴到下方输入框',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          SizedBox(height: 8),
          TextField(
            minLines: 8,
            maxLines: 14,
            decoration: InputDecoration(
              hintText: '粘贴 JSON 内容...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (value.trim().isNotEmpty) {
                _loadJsonFromText(value);
              }
            },
          ),
        ],
      ],
    );
  }
  
  // 从链接导入
  Future<void> _importFromUrl(String url) async {
    try {
      // 显示加载
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(child: CircularProgressIndicator()),
      );
      
      final service = BookSourceUrlImportService();
      final json = await service.downloadJson(url);
      
      Navigator.pop(context);  // 关闭加载
      
      await _loadJsonFromText(json);
      
      // 尝试自动填充表单
      _tryAutoFillForm(json);
      
    } catch (error) {
      Navigator.pop(context);  // 关闭加载
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：${error.toString()}')),
      );
    }
  }
  
  // 从文件导入
  Future<void> _importFromFile() async {
    try {
      final service = BookSourceFileImportService();
      final result = await service.pickFile();
      
      if (result != null) {
        await _loadJsonFromText(result.content);
        
        setState(() {
          _selectedFileName = result.fileName;
          _selectedFileSizeKB = (result.sizeBytes / 1024).toStringAsFixed(1);
        });
        
        // 尝试自动填充表单
        _tryAutoFillForm(result.content);
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：${error.toString()}')),
      );
    }
  }
  
  // 从剪贴板粘贴
  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      final json = clipboardData?.text?.trim() ?? '';
      
      if (json.isEmpty) {
        throw const FormatException('剪贴板为空');
      }
      
      await _loadJsonFromText(json);
      
      // 尝试自动填充表单
      _tryAutoFillForm(json);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('粘贴成功：${_getLineCount()} 行')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('粘贴失败：${error.toString()}')),
      );
    }
  }
  
  // 加载 JSON（异步，不阻塞UI）
  Future<void> _loadJsonFromText(String json) async {
    // 异步验证
    await Future.microtask(() {
      if (!PrivateBookSourceInput.isValidJson(json)) {
        throw const FormatException('JSON 格式不正确');
      }
    });
    
    setState(() {
      _fullJson = json;
      
      // 只显示前 100 行预览
      final lines = json.split('\n');
      final preview = lines.take(100).join('\n');
      _jsonPreviewController.text = preview + 
        (lines.length > 100 ? '\n\n... (还有 ${lines.length - 100} 行)' : '');
    });
  }
  
  // 尝试自动填充表单（从 JSON 解析）
  void _tryAutoFillForm(String json) {
    try {
      final parsed = jsonDecode(json);
      
      // 自动填充名称
      if (parsed['name'] != null && _nameController.text.isEmpty) {
        _nameController.text = parsed['name'].toString();
      }
      
      // 自动填充描述
      if (parsed['description'] != null && _descriptionController.text.isEmpty) {
        _descriptionController.text = parsed['description'].toString();
      }
      
      // 可以添加更多自动填充逻辑
    } catch (_) {
      // 解析失败，忽略
    }
  }
  
  void _clearJson() {
    setState(() {
      _fullJson = '';
      _jsonPreviewController.clear();
      _selectedFileName = '';
    });
  }
  
  int _getLineCount() {
    return _fullJson.split('\n').length;
  }
  
  String _getSizeKB() {
    return (utf8.encode(_fullJson).length / 1024).toStringAsFixed(1);
  }
  
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_fullJson.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先导入书源 JSON')),
      );
      return;
    }
    
    // 提交保存
    final input = PrivateBookSourceInput(
      name: _nameController.text.trim(),
      type: _selectedType,
      group: _selectedGroup,
      description: _descriptionController.text.trim(),
      json: _fullJson,
    );
    
    // 调用 Service 保存
    // await _service.save(input);
    
    Navigator.pop(context, true);
  }
}
```

---

## 八、验收标准

### 功能验收

- [ ] 链接导入可用（支持 HTTP/HTTPS）
- [ ] 文件导入可用（支持 .json/.txt）
- [ ] 粘贴输入优化（不卡顿）
- [ ] 显示导入进度
- [ ] 错误提示友好

### 性能验收

- [ ] 10000 行 JSON 粘贴不卡顿（< 1秒）
- [ ] 链接下载显示进度
- [ ] 文件选择响应及时（< 500ms）

### 体验验收

- [ ] 3 种方式都易用
- [ ] 错误提示清晰
- [ ] 支持跨平台（移动端/桌面端/Web）

---

## 九、注意事项

### 安全性

1. **链接验证**
   - 只允许 HTTP/HTTPS
   - 检查文件大小（限制 10MB）
   - 超时控制（30秒）

2. **文件验证**
   - 限制文件大小（10MB）
   - 验证文件格式
   - 扫描恶意内容（可选）

### 兼容性

1. **跨平台**
   - 移动端：file_picker 支持
   - 桌面端：file_picker 支持
   - Web：file_picker 部分支持（只能选择，不能获取路径）

2. **降级方案**
   - 如果 file_picker 不可用，隐藏文件导入
   - 如果剪贴板不可用，提示用户

---

## 十、总结

### 核心改进

1. **新增链接导入** - 解决大 JSON 问题 ⭐
2. **新增文件导入** - 本地文件方便 ⭐
3. **优化粘贴输入** - 异步处理不卡顿 ✅
4. **改进用户体验** - 进度提示、错误友好

### 优先级

**P0（必须）：**
- 链接导入
- 文件导入
- 粘贴优化

**P1（重要）：**
- 进度提示
- 错误优化

**P2（可选）：**
- 扫码导入
- 批量导入

### 预期效果

**改进前：**
- 只能粘贴
- 大 JSON 卡顿
- 经常失败

**改进后：**
- 3+ 种导入方式
- 大 JSON 流畅
- 体验友好

---

**执行时间：1-2周**  
**难度：中等**  
**价值：高（直接影响用户体验）** 🎯

---

**最后更新：** 2026-06-11