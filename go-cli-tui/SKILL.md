---
name: go-cli-tui
description: Go CLI/TUI 最佳实践。涵盖 Cobra 命令模式、Bubble Tea TUI 开发、Lipgloss 样式和性能优化。
---

# Go CLI/TUI 最佳实践

通用的 Go CLI 和 TUI 开发最佳实践，基于 Cobra + Bubble Tea 生态。

## 技术栈

- Go 1.22+
- [Cobra](https://github.com/spf13/cobra) — CLI 框架
- [Bubble Tea](https://github.com/charmbracelet/bubbletea) — TUI 框架（Elm 架构）
- [Lipgloss](https://github.com/charmbracelet/lipgloss) — 终端样式
- [Bubbles](https://github.com/charmbracelet/bubbles) — TUI 组件库（viewport, textarea, spinner 等）

## 快速参考

### Cobra 核心要点
- 使用 `RunE` 而非 `Run`，让错误沿命令链传播
- 在 `init()` 中注册 flags，保持初始化顺序可预测
- 用 `PersistentFlags()` 共享父命令选项
- 用 `Args` 校验器替代手动参数检查
- 通过 `cmd.Context()` 支持取消操作

### Bubble Tea 核心要点
- 正确实现 `Init()` / `Update()` / `View()` 三件套
- 始终处理 `tea.WindowSizeMsg` 以适配终端尺寸
- 用自定义 message 类型驱动状态变更
- `View()` 必须是纯函数，不修改状态
- 用 `tea.Batch` 组合多个 command
- 长时间操作必须支持取消（Esc / Ctrl+C）

### 性能核心要点
- 延迟加载重依赖，`init()` 只注册命令和 flags
- HTTP 连接池复用，避免每次请求创建新 client
- 大响应使用流式处理，不要全量缓存到内存
- 渲染节流，避免 UI 闪烁
- 永远不要在 `Update()` 中执行阻塞 I/O
- 防御负尺寸，避免 viewport panic

## 参考文档

| 文件 | 内容 | 条目数 |
|------|------|--------|
| [references/cobra.md](references/cobra.md) | Cobra 命令模式、flags、校验 | 10 |
| [references/bubbletea.md](references/bubbletea.md) | Bubble Tea Model/Update/View 模式 | 12 |
| [references/performance.md](references/performance.md) | CLI/TUI 性能优化 | 12 |

## 通用开发指南

1. **用户体验优先**: CLI 应响应迅速，提供清晰反馈
2. **优雅降级**: 妥善处理网络错误、超时和缺失依赖
3. **跨平台兼容**: 在 macOS、Linux、Windows 上测试
4. **终端兼容**: 测试不同终端模拟器和窗口尺寸
5. **可脚本化**: 结构化数据命令支持 `--json` 输出
