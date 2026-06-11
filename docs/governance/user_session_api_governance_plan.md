# 用户状态与API请求治理计划

创建时间：2026-06-10  
状态：待执行  
优先级：P0（数据安全问题）

## 问题背景

### 当前问题

**问题1：退出登录后数据混乱**
- 退出登录后，某些API请求仍然携带旧用户的凭证或数据
- 请求返回的不是当前用户的数据
- 多账号切换时数据混乱
- 登出后某些页面仍显示旧用户信息

**问题2：接口不实时请求**
- 某些接口使用了本地缓存，没有实时请求服务器
- 导致数据不是最新的，可能显示过期信息
- 多设备使用时数据不同步
- 存在安全风险（如权限变更未及时生效）

**根本原因：**
- ❌ 缺少统一的用户状态管理
- ❌ API请求拦截器未正确处理登录状态
- ❌ 登出时某些模块未正确清理状态
- ❌ 本地缓存与用户状态未绑定
- ❌ 不同平台（Android/iOS/Web/Desktop）行为不一致
- ❌ 缺少明确的缓存策略和实时性要求
- ❌ 某些接口滥用缓存，应该实时请求却使用了缓存

---

## 阶段 1：用户状态统一管理（1周，P0）

### 目标：建立全局统一的用户状态源

### 任务清单

#### 1.1 创建统一的用户状态管理

- [ ] **创建 UserSessionManager**
  - 单例模式，全局唯一用户状态源
  - 管理：用户ID、登录状态、token、用户基本信息
  - 提供：登录、登出、状态查询方法
  - 文件：`lib/core/auth/user_session_manager.dart`（新建）

- [ ] **定义用户状态模型**
  ```dart
  class UserSessionState {
    final bool isLoggedIn;
    final String? userId;
    final String? username;
    final String? accessToken;
    final DateTime? tokenExpiresAt;
  }
  ```
  - 文件：`lib/core/auth/user_session_state.dart`（新建）

- [ ] **使用 Riverpod StateNotifier 管理状态**
  - 状态变化时自动通知所有监听者
  - 提供 `userSessionProvider`
  - 文件：`lib/core/auth/user_session_provider.dart`（新建）

#### 1.2 改造现有 AuthService

- [ ] **AuthService 迁移到 UserSessionManager**
  - 登录成功时：调用 `UserSessionManager.login()`
  - 登出时：调用 `UserSessionManager.logout()`
  - 移除 AuthService 内部的状态存储
  - 文件：`lib/features/auth/application/auth_service.dart`

- [ ] **统一 token 存储和读取**
  - 只从 `UserSessionManager` 获取 token
  - 移除各处分散的 token 读取逻辑
  - 文件：`lib/features/auth/application/auth_service.dart`

#### 1.3 实现登出时完整清理

- [ ] **创建 SessionCleaner 清理器**
  - 清理顺序：内存状态 → SharedPreferences → SecureStorage → 通知监听者
  - 确保所有用户相关数据被清除
  - 文件：`lib/core/auth/session_cleaner.dart`（新建）

- [ ] **登出时执行完整清理**
  ```dart
  Future<void> logout() async {
    // 1. 清理内存状态
    _state = UserSessionState.empty();
    
    // 2. 清理 SharedPreferences
    await _prefs.remove('auth.user_id');
    await _prefs.remove('auth.username');
    
    // 3. 清理 SecureStorage
    await _secureStorage.delete(key: 'auth.access_token');
    await _secureStorage.delete(key: 'auth.refresh_token');
    
    // 4. 通知所有监听者
    notifyListeners();
  }
  ```
  - 文件：`lib/core/auth/user_session_manager.dart`

---

## 阶段 2：API请求拦截器改造（1周，P0）

### 目标：确保所有API请求正确携带当前用户凭证

### 任务清单

#### 2.1 创建统一的API拦截器

- [ ] **创建 AuthInterceptor**
  - 拦截所有API请求
  - 自动添加当前用户的 access_token
  - 处理 401 未授权响应
  - 文件：`lib/core/network/auth_interceptor.dart`（新建）

- [ ] **实现 token 注入逻辑**
  ```dart
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = UserSessionManager.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
  ```

- [ ] **实现 401 响应处理**
  - 收到 401：清除登录状态
  - 跳转到登录页
  - 避免继续使用失效 token
  - 文件：`lib/core/network/auth_interceptor.dart`

#### 2.2 改造 ApiClient

- [ ] **移除 ApiClient 中的 attachAccessToken 参数**
  - 当前：每个请求手动指定是否附加 token
  - 改为：拦截器自动判断和附加
  - 文件：`lib/core/network/api_client.dart`

- [ ] **确保 ApiClient 使用拦截器**
  - 在 Dio 实例中添加 AuthInterceptor
  - 确保所有请求都经过拦截器
  - 文件：`lib/core/network/api_client.dart`

#### 2.3 排查所有API调用点

- [ ] **搜索所有 ApiClient.request 调用**
  - 命令：`grep -r "ApiClient.*request" lib/`
  - 检查是否正确使用了拦截器
  - 移除手动添加 token 的代码

- [ ] **搜索所有直接使用 Dio 的地方**
  - 命令：`grep -r "Dio()" lib/`
  - 确保都经过统一的 ApiClient
  - 或者为直接使用的 Dio 也添加拦截器

---

## 阶段 3：本地缓存与用户绑定（1周，P1）

### 目标：避免多账号数据混用

### 任务清单

#### 3.1 设计用户隔离策略

- [ ] **确定哪些数据需要按用户隔离**
  - 需要隔离：私人书源、搜索历史、在线书籍缓存
  - 不需要隔离：本地图书、阅读器设置、应用主题
  - 文档：`docs/user_data_isolation_policy.md`（新建）

- [ ] **设计数据库表改造方案**
  - 方案1：为需要隔离的表添加 `user_id` 列
  - 方案2：使用独立的数据库文件（每个用户一个）
  - 推荐：方案1（简单，易迁移）

#### 3.2 改造数据库表结构

- [ ] **为相关表添加 user_id 列**
  - 表：`reading_progresses`（已有 user_id？检查）
  - 表：`bookmarks`
  - 表：`chapter_caches`（在线书籍缓存）
  - 表：`search_hit_statistics`
  - 文件：`lib/data/datasources/local/app_database.dart`

- [ ] **添加数据库迁移**
  - 为现有数据填充 `user_id`
  - 如果当前有登录用户，使用当前用户ID
  - 如果未登录，使用特殊标记 `local_user`
  - 文件：`lib/data/datasources/local/app_database.dart`

- [ ] **修改查询逻辑**
  - 所有查询自动过滤当前用户数据
  - 例如：`SELECT * FROM reading_progresses WHERE user_id = ?`
  - 确保不会返回其他用户的数据

#### 3.3 改造 SharedPreferences 存储

- [ ] **为用户相关配置添加用户ID前缀**
  - 当前：`search.history` 所有用户共享
  - 改为：`search.history.{userId}` 按用户隔离
  - 文件：`lib/features/search/application/search_history_service.dart`

- [ ] **登出时清理当前用户的配置**
  - 清理：`search.history.{currentUserId}`
  - 保留：其他用户的配置
  - 文件：`lib/core/auth/session_cleaner.dart`

---

## 阶段 2.5：API缓存策略治理（1周，P0）

### 目标：明确哪些接口必须实时请求，哪些可以缓存

### 任务清单

#### 2.5.1 排查所有API接口缓存情况

- [ ] **审计所有API接口**
  - 列出所有调用服务器的接口
  - 标记哪些使用了缓存
  - 标记缓存策略（内存缓存、磁盘缓存、时长）
  - 创建清单：`docs/api_cache_audit.md`

- [ ] **识别必须实时请求的接口**
  - 用户信息相关：用户资料、余额、权限
  - 安全相关：登录、登出、token刷新
  - 实时性要求高：书源列表、搜索结果
  - 标记为 `REALTIME_REQUIRED`

- [ ] **识别可以缓存的接口**
  - 静态数据：配置、分类列表
  - 变化频率低：章节内容、书籍详情
  - 标记为 `CACHEABLE` 并定义缓存时长

#### 2.5.2 定义缓存策略规范

- [ ] **创建API缓存策略文档**
  - 定义三个级别：REALTIME、SHORT_CACHE、LONG_CACHE
  - 文件：`docs/api_cache_policy.md`（新建）

- [ ] **为每类接口定义策略**
  - 用户信息接口：realtime
  - 私人书源列表：realtime
  - 章节内容：shortCache (5分钟)
  - 书籍详情：shortCache (5分钟)

- [ ] **禁止滥用缓存的场景**
  - 用户敏感信息不允许缓存
  - 权限验证接口不允许缓存
  - 登出后必须清除所有用户相关缓存

#### 2.5.3 改造现有缓存实现

- [ ] **移除不应该缓存的接口缓存**
  - 搜索：`grep -r "cache" lib/features/*/application/`
  - 移除：标记为 REALTIME_REQUIRED 的接口缓存

- [ ] **为 ApiClient 添加缓存策略参数**
  - 添加 cachePolicy 参数（默认不缓存）
  - 文件：`lib/core/network/api_client.dart`

- [ ] **实现缓存拦截器**
  - 缓存 key 包含：用户ID + URL + 参数
  - 登出时清除当前用户缓存
  - 文件：`lib/core/network/cache_interceptor.dart`（新建）

#### 2.5.4 特别处理高风险接口

- [ ] **用户信息接口强制实时**
  - `/v1/me/profile`、`/v1/me/book-sources` 实时请求
  - 不允许任何形式的缓存

- [ ] **在线书籍接口策略**
  - 搜索结果：实时请求
  - 书籍详情：短期缓存（5分钟）
  - 章节内容：可缓存（标记用户ID）

- [ ] **添加缓存刷新机制**
  - 下拉刷新强制重新请求
  - 关键操作后自动刷新

---

## 阶段 4：状态监听与自动清理（1周，P1）

### 目标：登出时自动清理所有相关状态

### 任务清单

#### 4.1 实现状态监听机制

- [ ] **创建 SessionChangeListener 接口**
  ```dart
  abstract class SessionChangeListener {
    Future<void> onUserLogin(String userId);
    Future<void> onUserLogout();
  }
  ```
  - 文件：`lib/core/auth/session_change_listener.dart`（新建）

- [ ] **在 UserSessionManager 中管理监听器**
  - 提供注册和注销方法
  - 用户状态变化时通知所有监听器
  - 文件：`lib/core/auth/user_session_manager.dart`

#### 4.2 为各模块实现监听器

- [ ] **私人书源模块监听器**
  - 登出时：清理本地缓存的书源列表
  - 文件：`lib/features/mine/application/private_book_source_session_listener.dart`（新建）

- [ ] **搜索历史模块监听器**
  - 登出时：不清理（历史保留）
  - 登录时：加载当前用户历史
  - 文件：`lib/features/search/application/search_history_session_listener.dart`（新建）

- [ ] **书架模块监听器**
  - 登出时：清理在线书籍
  - 保留：本地图书
  - 文件：`lib/features/bookshelf/application/bookshelf_session_listener.dart`（新建）

- [ ] **阅读器模块监听器**
  - 登出时：清理在线书籍的阅读进度内存缓存
  - 保留：本地图书阅读进度
  - 文件：`lib/features/reader/application/reader_session_listener.dart`（新建）

#### 4.3 注册所有监听器

- [ ] **在应用启动时注册监听器**
  - 位置：`lib/app/startup/app_startup_coordinator.dart`
  - 时机：应用初始化时
  - 确保在用户操作前注册完成

---

## 阶段 5：跨平台一致性验证（1周，P1）

### 目标：确保所有平台行为一致

### 任务清单

#### 5.1 编写平台一致性测试

- [ ] **创建登录登出测试套件**
  - 测试：登录 → 获取数据 → 登出 → 数据已清理
  - 测试：多账号切换 → 数据正确隔离
  - 测试：token 过期 → 自动跳转登录
  - 文件：`test/core/auth/user_session_test.dart`（新建）

- [ ] **创建API请求测试**
  - 测试：未登录时请求 → 不携带 token
  - 测试：登录后请求 → 自动携带 token
  - 测试：登出后请求 → 不携带 token
  - 文件：`test/core/network/auth_interceptor_test.dart`（新建）

#### 5.2 各平台真机验证

- [ ] **Android 真机测试**
  - 登录 → 登出 → 重新登录不同账号
  - 检查：API请求头
  - 检查：返回数据是否正确
  - 使用抓包工具验证

- [ ] **iOS 真机测试**
  - 相同测试流程
  - 确保与 Android 行为一致

- [ ] **Web 浏览器测试**
  - 相同测试流程
  - 检查：浏览器开发者工具网络请求

- [ ] **Desktop（macOS/Windows）测试**
  - 相同测试流程
  - 确保行为一致

---

## 阶段 6：错误处理和日志（1周，P2）

### 目标：方便排查用户状态相关问题

### 任务清单

#### 6.1 添加详细日志

- [ ] **记录用户状态变化**
  - 登录：记录用户ID、时间
  - 登出：记录清理项、时间
  - Token刷新：记录成功/失败
  - 文件：`lib/core/auth/user_session_manager.dart`

- [ ] **记录API请求关键信息**
  - 请求URL
  - 是否携带token
  - 响应状态码
  - 401 响应处理
  - 文件：`lib/core/network/auth_interceptor.dart`

#### 6.2 添加异常情况处理

- [ ] **处理 token 为空的情况**
  - 需要登录的API：跳转登录页
  - 不需要登录的API：正常请求
  - 文件：`lib/core/network/auth_interceptor.dart`

- [ ] **处理 token 过期但未收到 401**
  - 本地检查 token 过期时间
  - 过期则自动刷新或跳转登录
  - 文件：`lib/core/auth/user_session_manager.dart`

- [ ] **处理网络异常**
  - 网络错误：不清除登录状态
  - 服务器错误（500）：不清除登录状态
  - 只有 401 才清除登录状态

#### 6.3 添加诊断工具

- [ ] **在设置中显示当前用户状态**
  - 位置：设置 → 关于 → 用户状态
  - 显示：是否登录、用户ID、token 是否有效
  - 用于排查问题
  - 文件：`lib/features/mine/presentation/about_page.dart`

---

## 验收标准

### 核心验收

- [ ] **登出后数据正确清理**
  - 登录用户A → 查看数据 → 登出
  - 登录用户B → 查看数据
  - 验证：B 看不到 A 的数据

- [ ] **API 请求正确携带 token**
  - 抓包验证：所有需要认证的请求都有 Authorization 头
  - 验证：token 值正确

- [ ] **401 响应正确处理**
  - 服务器返回 401
  - 验证：自动清除登录状态并跳转登录页

- [ ] **多账号切换正常**
  - 登录A → 登出 → 登录B
  - 验证：显示的是 B 的数据，不是 A 的

### 平台一致性验收

- [ ] **Android 测试通过**
- [ ] **iOS 测试通过**
- [ ] **Web 测试通过**
- [ ] **macOS 测试通过**
- [ ] **Windows 测试通过**（如有条件）

---

## 测试清单

### 单元测试

- [ ] UserSessionManager 登录登出测试
- [ ] AuthInterceptor token 注入测试
- [ ] SessionCleaner 清理逻辑测试
- [ ] 数据库按用户查询测试

### 集成测试

- [ ] 完整登录登出流程测试
- [ ] 多账号切换测试
- [ ] Token 过期自动处理测试
- [ ] API 请求拦截测试

### 手动测试

- [ ] 各平台登录登出流程
- [ ] 抓包验证 API 请求头
- [ ] 多账号数据隔离验证
- [ ] 异常情况验证（断网、服务器错误）

---

## 风险评估

### 高风险项

1. **数据库表改造** - 可能影响现有数据
   - 缓解：先备份，迁移前验证
   - 回滚：提供降级方案

2. **API 拦截器改造** - 可能影响所有请求
   - 缓解：充分测试所有API
   - 回滚：保留旧代码开关

3. **多账号隔离** - 可能导致数据丢失或混乱
   - 缓解：先在测试环境验证
   - 回滚：提供数据恢复工具

### 中风险项

1. **状态监听机制** - 可能遗漏某些模块
   - 缓解：详细列出所有需要清理的模块
   - 测试：手动验证每个模块

2. **日志和诊断** - 可能泄露敏感信息
   - 缓解：脱敏处理，不记录完整 token
   - 审查：代码 review 检查日志内容

---

## 实施建议

### 人员安排

- **阶段 1-2（核心）**：1 名后端开发全职投入
- **阶段 3-4**：1 名后端开发 + 1 名测试
- **阶段 5-6**：全栈开发 + QA

### 排期建议

- 第 1 周：阶段 1（用户状态统一）
- 第 2 周：阶段 2（API拦截器）
- 第 3 周：阶段 3（数据隔离）
- 第 4 周：阶段 4（状态监听）
- 第 5 周：阶段 5（平台验证）
- 第 6 周：阶段 6（日志诊断）
- 第 7 周：全面回归测试

### 发布策略

1. **分阶段发布**
   - v1：阶段 1-2（核心修复）
   - v2：阶段 3-4（数据隔离）
   - v3：阶段 5-6（完善）

2. **灰度发布**
   - 先 10% 用户
   - 观察 1 周无问题
   - 再全量发布

---

## 关联文档

- [存储与数据生命周期完整指南](storage_and_data_lifecycle_guide.md)
- [存储治理改造计划](storage_governance_improvement_plan.md)

---

**更新记录：**
- 2026-06-10：初始创建