# 里程碑 03：核心业务链多端兼容与验收

创建日期：2026-06-04

状态：待执行。

适用平台：Android、iOS、Web JS、macOS、Windows、Linux。

核心目标：把登录、搜索、详情、在线阅读、书架、设置等核心业务链按多端兼容和测试验收执行。一个任务不是“Web / Desktop 能点通”就算完成，而是移动端、Web、Desktop 的业务设计、状态、降级、测试和未验证原因都要清楚。

后续执行规则：每次只领取一个最小任务编号，例如 `M3-02-03`。

## 1. M3-01 业务链基线盘点

- [ ] M3-01-01 列出登录、注册、会话恢复、退出登录的入口、状态、存储和失败路径。
- [ ] M3-01-02 列出搜索、发现、书籍详情、目录、开始阅读的入口和状态路径。
- [ ] M3-01-03 列出在线阅读章节加载、进度保存、设置、目录跳转、返回栈路径。
- [ ] M3-01-04 列出书架、继续阅读、筛选排序、分类、批量选择路径。
- [ ] M3-01-05 列出设置、资料、主题、反馈、远程访问等我的页业务路径。
- [ ] M3-01-06 为每条链记录 Android、iOS、Web JS、macOS、Windows、Linux 的已知能力差异。

## 2. M3-02 登录与会话链

- [ ] M3-02-01 检查移动端登录、注册、退出登录、会话恢复是否仍按旧体验工作。
- [ ] M3-02-02 检查 Web 登录后刷新恢复、根路径跳转、未登录拦截和退出登录。
- [ ] M3-02-03 检查 macOS 登录、键盘提交、窗口尺寸、外部浏览器 / fallback 凭证策略。
- [x] M3-02-04 为 Windows 登录路径写代码级影响判断和 CI / 手工补验要求。
- [ ] M3-02-05 为 Linux 登录路径写代码级影响判断和 CI / 手工补验要求。
- [x] M3-02-06 补 auth form validation / session store 相关测试。
- [ ] M3-02-07 为会话存储、凭证 fallback、过期跳转补中文维护注释。
- [ ] M3-02-08 输出登录链六平台验收记录。

### M3-02 执行记录（2026-06-04）

#### M3-02-04 Windows 登录路径代码级影响判断

- 登录入口：`/auth` 路由进入 `AuthPage`；个人资料页未登录状态通过 `context.push('/auth')` 进入登录页。
- 表单路径：Windows 被 `AppLayout.isDesktopLike` 归入桌面布局；宽屏使用桌面双栏 / 单栏 surface，窄窗回落为滚动表单，不依赖移动端键盘 inset 行为。登录密码框和注册确认密码框保留 `TextInputAction.done` 与 `onFieldSubmitted => _submit()`，Windows 物理键盘回车提交路径可用。
- 服务路径：`AuthPage` 通过 `authServiceProvider` 调用 `AuthService.loginAndStore` / `registerAndStore`；成功后写入 `AuthSessionStore` 并触发登录事件，失败时保留 inline error。
- Windows 会话存储：`createDefaultAuthSessionSecretStore` 在 Windows 走 `SharedPreferencesAuthSessionSecretStore` fallback，不依赖移动端 secure storage 插件；`AuthSessionStore` 仍保留旧 prefs token 迁移逻辑，便于历史版本升级。
- 代码级风险：Windows fallback token 存在 SharedPreferences，不等价于 OS 凭据库；发布前需要确认后端 token 时效和退出登录清理策略足够保守。当前登录链没有外部浏览器 OAuth 分支，Windows 不需要额外 browser callback 验证。
- CI 要求：至少运行 `flutter test test/features/auth/application/auth_form_validation_service_test.dart test/core/auth/auth_session_store_test.dart test/core/auth/auth_service_test.dart`；Windows 构建机需开启 Developer Mode 或具备 symlink 权限。
- 手工补验要求：Windows Release 或 Debug 启动后，依次补验登录页打开、账号/密码空值校验、回车提交、登录失败 inline error、登录成功会话恢复、退出登录后会话清理、重启应用后未过期 session 仍可恢复。

#### M3-02-06 测试补充

- `auth_form_validation_service_test.dart` 增加 required trim、可选新密码长度、空格密码当前行为、确认密码边界覆盖。
- `auth_session_store_test.dart` 增加安全存储 access token 优先、legacy refresh / 过期时间补缺迁移、禁用 legacy fallback 时不读取也不清理旧凭证的覆盖。
- 执行结果：`flutter test test/features/auth/application/auth_form_validation_service_test.dart test/core/auth/auth_session_store_test.dart test/core/auth/auth_service_test.dart` 通过。

#### M3-02-08 登录链六平台验收记录（本次仅 Windows）

| 平台 | 状态 | 验收记录 | 未覆盖 / 后续补验 |
| --- | --- | --- | --- |
| Windows | 部分通过 | 代码路径完成影响判断；`AuthPage` 桌面布局、键盘提交、`AuthService`、`AuthSessionStore`、Windows fallback secret store 均有可追踪路径；本次补充 auth form validation 和 session store 单测；`flutter build windows` 通过，生成 `build/windows/x64/runner/Release/shuxiang_reading_next.exe`。 | 需要连接真实后端或可控 mock 后端，在 Windows UI 上手工补验登录成功、失败、退出、重启恢复。 |

## 3. M3-03 搜索、发现与详情链

- [ ] M3-03-01 检查移动端搜索输入、历史、筛选、空态、失败重试。
- [ ] M3-03-02 检查 Web 搜索刷新恢复、路由参数、浏览器返回和网络失败展示。
- [ ] M3-03-03 检查 Desktop 搜索键盘提交、宽屏列表、详情打开和返回栈。
- [ ] M3-03-04 检查书籍详情元数据、目录、加入书架、换源、开始阅读的 service 边界。
- [ ] M3-03-05 补搜索 / 详情 provider 或 service 测试。
- [ ] M3-03-06 运行 route inventory 和 route string guard。
- [ ] M3-03-07 输出搜索详情链六平台验收记录。

## 4. M3-04 在线阅读链

- [ ] M3-04-01 检查移动端触控翻页、滚动、目录、设置、进度保存不回退。
- [ ] M3-04-02 检查 Web 键盘、滚轮、刷新恢复、章节加载和不支持能力降级。
- [ ] M3-04-03 检查 macOS 键盘、鼠标、窗口宽度、目录和设置弹层。
- [ ] M3-04-04 为 Windows / Linux 阅读链写补验要求，不能用 macOS 代替。
- [ ] M3-04-05 补阅读器 session / progress / route helper 相关测试。
- [ ] M3-04-06 为阅读进度、章节定位、刷新恢复关键逻辑补中文维护注释。
- [ ] M3-04-07 输出在线阅读链六平台验收记录。

## 5. M3-05 书架与继续阅读链

- [ ] M3-05-01 检查移动端书架列表、排序、长按、更多入口、继续阅读不回退。
- [ ] M3-05-02 检查 Web 书架刷新恢复、空态、继续阅读和详情跳转。
- [ ] M3-05-03 检查 Desktop 批量选择、菜单、键盘焦点和继续阅读。
- [ ] M3-05-04 补 bookshelf service / page state / migration 相关测试。
- [ ] M3-05-05 检查旧书架数据、阅读进度、书签、分类不会因兼容治理丢失。
- [ ] M3-05-06 输出书架链六平台验收记录。

## 6. M3-06 设置、主题与我的页链

- [ ] M3-06-01 检查移动端设置、主题、资料、反馈、远程访问入口不回退。
- [ ] M3-06-02 检查 Web 不支持能力是否隐藏、禁用或提供替代说明。
- [ ] M3-06-03 检查 Desktop 文件选择、保存、分享、打开目录等行为是否符合桌面习惯。
- [ ] M3-06-04 补高级主题、资料、反馈、设置相关 service / provider 测试。
- [ ] M3-06-05 输出我的页链六平台验收记录。

## 7. M3 验收

- [ ] M3-07-01 每条核心业务链都有六平台影响记录。
- [ ] M3-07-02 没有条件真实验证的平台写明原因和发布前补验方式。
- [ ] M3-07-03 业务链相关代码遵守 provider、route helper、storage、capability、中文注释规则。
- [ ] M3-07-04 `flutter analyze` 通过或记录阻塞原因。
- [ ] M3-07-05 Web build、目标单测、guard、可用桌面构建或未验证原因记录完整。
