---
name: go-review
description: Go 代码审查与优化最佳实践。涵盖惯用模式、错误处理、并发、测试和安全编码规范。适用场景：(1) 对 Go 代码进行 code review，(2) 优化 Go 代码质量和性能，(3) 检查 Go 代码中的反模式和安全隐患。
---

# Go 代码审查与优化

通用 Go 代码审查与优化最佳实践。确保代码符合惯用风格、可维护且安全。

## 审查流程

对 Go 代码进行 code review 时，按以下优先级依次检查：

1. **安全性** — 参考 [security.md](references/security.md)
2. **错误处理** — 参考 [error-handling.md](references/error-handling.md)
3. **并发安全** — 参考 [concurrency.md](references/concurrency.md)
4. **惯用模式** — 参考 [patterns.md](references/patterns.md)
5. **测试质量** — 参考 [testing.md](references/testing.md)

## 快速参考

### 错误处理
- 始终用上下文包装错误：`fmt.Errorf("操作失败: %w", err)`
- 对预期条件使用哨兵错误：`var ErrNotFound = errors.New("not found")`
- 调用函数后立即检查错误

### 并发
- 使用 `sync.Mutex` 保护共享状态
- 读多写少时使用 `sync.RWMutex`
- 使用 channel 进行 goroutine 通信
- 始终使用 `defer` 释放锁

### 测试
- 使用表驱动测试实现全面覆盖
- 使用 interface 实现可 mock 性
- 测试文件命名：同包下的 `*_test.go`

### 安全
- 禁止在日志中输出凭证或 token
- 在 debug 日志中脱敏敏感 header
- 验证所有外部输入
- 使用 `context.Context` 实现取消机制

## Go 箴言

1. "不要通过共享内存来通信，而要通过通信来共享内存"
2. "错误也是值"
3. "少量复制优于少量依赖"
4. "清晰优于聪明"
5. "设计架构，命名组件，记录细节"

## 检查清单文件

| 文件 | 说明 |
|------|------|
| [patterns.md](references/patterns.md) | 惯用 Go 模式 |
| [concurrency.md](references/concurrency.md) | goroutine、channel、sync |
| [error-handling.md](references/error-handling.md) | 错误包装、哨兵错误 |
| [testing.md](references/testing.md) | 表驱动测试、mock |
| [security.md](references/security.md) | 输入验证、安全编码 |
