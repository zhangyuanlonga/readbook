# Responsive Framework Migration Execution Plan

- [x] 建立执行清单与验收标准（本文件）
- [x] 引入 `responsive_framework` 依赖并完成 `pub get`
- [x] 在 `MaterialApp.builder` 接入统一断点（不开全局缩放）
- [x] 保持 `AppLayout/AppSpacing` API 不变，完成断点桥接
- [x] 修复高风险固定宽度弹窗（`560/420`）
- [x] 优化书架网格最小列数策略（超窄屏降列）
- [x] 优化「我的」页面宫格列数策略（2/3/4 列）
- [x] 放宽全局文本缩放钳制（改善无障碍可读性）
- [x] 更新/补齐相关自适应测试断言
- [x] 运行关键测试并记录结果

## 验收标准

- [x] 关键自适应用例测试通过
- [x] 关键页面在窄屏（>=320）与横屏无明显溢出
- [x] 无新增编译错误
