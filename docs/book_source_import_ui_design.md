# 书源导入 UI 设计详细说明

创建时间：2026-06-11  
配合：[书源导入功能优化方案](book_source_import_improvement_plan.md)  
用途：给开发人员的详细 UI 实现指南

---

## 一、整体流程概览

### 三步流程

```
步骤1：书源列表页
  ↓ 点击 [+ 添加]
步骤2：底部弹层选择导入方式（3选1）
  ↓ 选择后进入表单页
步骤3：完整表单页面
  - 上半部分：导入 JSON
  - 下半部分：填写表单（名称、类型、分组、描述）
  ↓ 提交
完成
```

---

## 二、详细页面设计

### 页面1：书源列表页（已有，需改造）

#### 当前位置
`lib/features/mine/presentation/private_book_sources_page.dart`

#### 改造内容

**AppBar 右上角：**

```dart
AppBar(
  title: const Text('我的书源'),
  actions: [
    // 主要操作：添加书源
    IconButton(
      icon: const Icon(Icons.add),
      tooltip: '添加书源',
      onPressed: () => _showImportMethodSheet(context, ref),
    ),
    
    // 次要操作：更多菜单
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: '更多',
      onSelected: (value) {
        switch (value) {
          case 'export':
            // 导出所有书源
            break;
          case 'clear':
            // 清空所有书源
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.upload, size: 20),
              SizedBox(width: 8),
              Text('导出所有书源'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.delete_sweep, size: 20),
              SizedBox(width: 8),
              Text('清空所有书源'),
            ],
          ),
        ),
      ],
    ),
  ],
)
```

**关键点：**
- ✅ [+ 添加] 放在最前面，最常用
- ✅ [⋮ 更多] 放在后面，次要功能
- ✅ 使用 Tooltip 提示用户

---

### 页面2：导入方式选择底部弹层（新建）

#### 文件位置（建议）
`lib/features/mine/presentation/widgets/import_method_bottom_sheet.dart`

#### UI 设计

```text
┌─────────────────────────────────────┐
│                                      │
│  选择导入方式                         │ ← 标题（居中）
│                                      │
│  ┌───────────────────────────────┐  │
│  │ 🌐 通过链接导入               │  │ ← ListTile
│  │ 快速便捷，适合大 JSON          │  │   subtitle 说明
│  └───────────────────────────────┘  │
│  ─────────────────────────────────  │ ← Divider
│  ┌───────────────────────────────┐  │
│  │ 📁 从文件选择                 │  │
│  │ 本地文件，无需网络             │  │
│  └───────────────────────────────┘  │
│  ─────────────────────────────────  │
│  ┌───────────────────────────────┐  │
│  │ 📋 粘贴 JSON                  │  │
│  │ 适合小 JSON                    │  │
│  └───────────────────────────────┘  │
│                                      │
│  [取消]  ← TextButton（居中）       │
│                                      │
└─────────────────────────────────────┘
```

#### 实现代码

```dart
// lib/features/mine/presentation/widgets/import_method_bottom_sheet.dart

class ImportMethodBottomSheet extends StatelessWidget {
  const ImportMethodBottomSheet({super.key});
  
  static Future<ImportMethod?> show(BuildContext context) {
    return showModalBottomSheet<ImportMethod>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ImportMethodBottomSheet(),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '选择导入方式',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 选项1：链接导入
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.link,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('通过链接导入'),
              subtitle: const Text('快速便捷，适合大 JSON'),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
              onTap: () => Navigator.pop(context, ImportMethod.url),
            ),
            
            const Divider(height: 1, indent: 72),
            
            // 选项2：文件导入
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_open,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              title: const Text('从文件选择'),
              subtitle: const Text('本地文件，无需网络'),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
              onTap: () => Navigator.pop(context, ImportMethod.file),
            ),
            
            const Divider(height: 1, indent: 72),
            
            // 选项3：粘贴导入
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.content_paste,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
              title: const Text('粘贴 JSON'),
              subtitle: const Text('适合小 JSON'),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
              onTap: () => Navigator.pop(context, ImportMethod.paste),
            ),
            
            const SizedBox(height: 16),
            
            // 取消按钮
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// 导入方式枚举
enum ImportMethod {
  url,    // 链接导入
  file,   // 文件导入
  paste,  // 粘贴导入
}
```

**关键点：**
- ✅ 使用 `showModalBottomSheet`，符合 Material 规范
- ✅ 每个选项用不同颜色区分（primary/secondary/tertiary Container）
- ✅ 圆角图标背景，美观
- ✅ Subtitle 说明每种方式的特点
- ✅ 右侧箭头提示可点击
- ✅ 底部取消按钮

---

### 页面3：完整表单页面（新建/改造）

#### 文件位置
`lib/features/mine/presentation/book_source_form_page.dart`

#### UI 布局（分三部分）

```text
┌─────────────────────────────────────┐
│  ← 添加书源                          │ ← AppBar
├─────────────────────────────────────┤
│                                      │
│  ═══════════════════════════════════ │
│  第一部分：导入 JSON（可滚动）       │
│  ═══════════════════════════════════ │
│                                      │
│  📥 书源 JSON                         │
│  [🌐 链接] [📁 文件] [📋 粘贴]  ← Tab│
│                                      │
│  // 根据 Tab 显示不同内容           │
│  // 链接：输入框 + 获取按钮         │
│  // 文件：选择文件按钮              │
│  // 粘贴：粘贴按钮 + 输入框         │
│                                      │
│  ┌───────────────────────────────┐  │
│  │ JSON 预览（只读，前100行）    │  │
│  └───────────────────────────────┘  │
│  ✅ 已加载 2680 行 (450KB)           │
│  [清除重新选择]                      │
│                                      │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                      │
│  ═══════════════════════════════════ │
│  第二部分：填写表单（必填）          │
│  ═══════════════════════════════════ │
│                                      │
│  📝 书源信息                          │
│                                      │
│  名称 *                              │
│  ┌───────────────────────────────┐  │
│  │ 笔趣阁                        │  │
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
│  │ 可选                          │  │
│  └───────────────────────────────┘  │
│                                      │
│  ═══════════════════════════════════ │
│  第三部分：提交按钮（底部固定）      │
│  ═══════════════════════════════════ │
│                                      │
│  [取消]  [保存]                      │
└─────────────────────────────────────┘
```

#### 关键交互细节

**1. Tab 切换导入方式：**

```dart
// 使用 SegmentedButton（Material 3）
SegmentedButton<ImportMethod>(
  segments: const [
    ButtonSegment(
      value: ImportMethod.url,
      label: Text('链接'),
      icon: Icon(Icons.link, size: 18),
    ),
    ButtonSegment(
      value: ImportMethod.file,
      label: Text('文件'),
      icon: Icon(Icons.folder_open, size: 18),
    ),
    ButtonSegment(
      value: ImportMethod.paste,
      label: Text('粘贴'),
      icon: Icon(Icons.content_paste, size: 18),
    ),
  ],
  selected: {_selectedMethod},
  onSelectionChanged: (Set<ImportMethod> newSelection) {
    setState(() {
      _selectedMethod = newSelection.first;
    });
  },
)
```

**2. 链接导入UI：**

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    TextField(
      controller: _urlController,
      decoration: InputDecoration(
        hintText: 'https://example.com/source.json',
        prefixIcon: Icon(Icons.link),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.url,
    ),
    SizedBox(height: 8),
    FilledButton.icon(
      onPressed: _isLoading ? null : _importFromUrl,
      icon: _isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.download),
      label: Text(_isLoading ? '获取中...' : '获取'),
    ),
  ],
)
```

**3. 文件导入UI：**

```dart
Column(
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
      Row(
        children: [
          Icon(Icons.insert_drive_file, size: 16, color: Colors.grey),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              '$_selectedFileName ($_selectedFileSizeKB KB)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ],
  ],
)
```

**4. 粘贴导入UI：**

```dart
Column(
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
      SizedBox(height: 12),
      Text(
        '或直接粘贴到下方输入框',
        style: TextStyle(fontSize: 12, color: Colors.grey),
        textAlign: TextAlign.center,
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
          if (value.trim().length > 100) {
            _loadJsonFromText(value);
          }
        },
      ),
    ],
  ],
)
```

**5. JSON 预览（已加载后）：**

```dart
if (_fullJson.isNotEmpty) ...[
  TextField(
    controller: _jsonPreviewController,
    readOnly: true,
    minLines: 8,
    maxLines: 14,
    decoration: InputDecoration(
      labelText: 'JSON 预览（前 100 行）',
      border: OutlineInputBorder(),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
    ),
    style: TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
    ),
  ),
  
  SizedBox(height: 8),
  
  // 状态信息
  Row(
    children: [
      Icon(Icons.check_circle, color: Colors.green, size: 18),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          '已加载 ${_getLineCount()} 行 (${_getSizeKB()} KB)',
          style: TextStyle(fontSize: 14),
        ),
      ),
      TextButton(
        onPressed: _clearJson,
        child: Text('清除'),
      ),
    ],
  ),
]
```

**6. 表单字段：**

```dart
// 名称（必填）
TextFormField(
  controller: _nameController,
  decoration: InputDecoration(
    labelText: '名称',
    hintText: '例如：笔趣阁',
    suffixIcon: Icon(Icons.star, size: 16, color: Colors.red), // 必填标记
    border: OutlineInputBorder(),
  ),
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入书源名称';
    }
    return null;
  },
)

// 类型（下拉，必填）
DropdownButtonFormField<String>(
  value: _selectedType,
  decoration: InputDecoration(
    labelText: '类型',
    suffixIcon: Icon(Icons.star, size: 16, color: Colors.red),
    border: OutlineInputBorder(),
  ),
  items: ['网络书源', '本地书源', '其他'].map((type) {
    return DropdownMenuItem(value: type, child: Text(type));
  }).toList(),
  onChanged: (value) {
    setState(() => _selectedType = value!);
  },
)

// 分组（下拉，可选）
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
)

// 描述（可选）
TextFormField(
  controller: _descriptionController,
  minLines: 3,
  maxLines: 5,
  decoration: InputDecoration(
    labelText: '描述',
    hintText: '可选，描述书源的特点和来源',
    border: OutlineInputBorder(),
    alignLabelWithHint: true,
  ),
)
```

**7. 底部按钮：**

```dart
// 底部固定按钮栏
Padding(
  padding: EdgeInsets.all(16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('取消'),
      ),
      SizedBox(width: 8),
      FilledButton(
        onPressed: _fullJson.isEmpty || _saving ? null : _save,
        child: Text(_saving ? '保存中...' : '保存'),
      ),
    ],
  ),
)
```

---

## 三、交互细节与体验优化

### 3.1 加载状态

**导入过程显示进度：**

```dart
// 下载进度对话框
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => AlertDialog(
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('正在下载 JSON...'),
        SizedBox(height: 8),
        Text(
          '$_downloadedKB KB / $_totalKB KB',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    ),
  ),
)
```

### 3.2 错误提示

**友好的错误信息：**

```dart
void _showErrorDialog(String title, String message) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      icon: Icon(Icons.error_outline, color: Colors.red, size: 48),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('知道了'),
        ),
      ],
    ),
  );
}

// 使用
try {
  await _importFromUrl(url);
} catch (e) {
  if (e is FormatException) {
    _showErrorDialog('格式错误', 'JSON 格式不正确，请检查后重试');
  } else if (e is TimeoutException) {
    _showErrorDialog('下载超时', '网络连接超时，请检查网络后重试');
  } else {
    _showErrorDialog('导入失败', e.toString());
  }
}
```

### 3.3 自动填充表单

```dart
// 从 JSON 自动解析并填充表单
void _tryAutoFillForm(String json) {
  try {
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    
    setState(() {
      // 自动填充名称
      if (parsed['name'] != null && _nameController.text.isEmpty) {
        _nameController.text = parsed['name'].toString();
      }
      
      // 自动填充描述
      if (parsed['description'] != null && _descriptionController.text.isEmpty) {
        _descriptionController.text = parsed['description'].toString();
      }
      
      // 自动填充类型（如果能识别）
      if (parsed['type'] != null) {
        final type = parsed['type'].toString();
        if (['网络书源', '本地书源'].contains(type)) {
          _selectedType = type;
        }
      }
    });
    
    // 提示用户
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已自动填充部分信息，请确认后保存'),
        duration: Duration(seconds: 2),
      ),
    );
  } catch (_) {
    // 解析失败，忽略
  }
}
```

### 3.4 键盘优化

```dart
// 点击空白处收起键盘
GestureDetector(
  onTap: () => FocusScope.of(context).unfocus(),
  child: SingleChildScrollView(
    // 表单内容
  ),
)

// 表单字段键盘类型
TextField(
  keyboardType: TextInputType.url,  // 链接输入
)

TextField(
  keyboardType: TextInputType.multiline,  // 多行文本
  textInputAction: TextInputAction.newline,
)
```

---

## 四、关键实现要点

### 4.1 必须实现

1. **异步加载 JSON** - 使用 `Future.microtask` 避免卡顿
2. **只显示预览** - 完整 JSON 存变量，只显示前 100 行
3. **自动填充表单** - 从 JSON 解析基本信息
4. **表单验证** - 名称和类型必填
5. **进度提示** - 下载、解析时显示进度
6. **错误处理** - 友好的错误提示

### 4.2 体验优化

1. **Tab 默认选中** - 根据从底部弹层选择的方式预选 Tab
2. **键盘优化** - 合适的 `keyboardType` 和 `textInputAction`
3. **空白处收起键盘** - `GestureDetector.onTap`
4. **自动 focus** - 进入页面自动聚焦第一个输入框
5. **防抖处理** - 粘贴输入延迟验证，避免频繁触发

---

## 五、测试要点

### 功能测试

- [ ] 3 种导入方式都能正常获取 JSON
- [ ] 大 JSON（5000+ 行）不卡顿
- [ ] 自动填充表单成功
- [ ] 表单验证正确（必填项检查）
- [ ] 保存成功后返回列表

### 交互测试

- [ ] 底部弹层正常弹出和关闭
- [ ] Tab 切换流畅
- [ ] 加载进度显示正确
- [ ] 错误提示友好
- [ ] 键盘弹起不遮挡输入框

### 边界测试

- [ ] 空 JSON 提示
- [ ] 格式错误 JSON 提示
- [ ] 网络超时处理
- [ ] 剪贴板为空处理
- [ ] 文件选择取消处理

---

**最后更新：** 2026-06-11