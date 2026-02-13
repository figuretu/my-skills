# 并发模式

Go 并发编程最佳实践：goroutine、channel 和同步原语。

## 检查清单

### 1. 使用 Mutex 保护共享状态

**说明**: 所有共享可变状态必须用 mutex 保护。

**通过标准**: 每个包含共享可变状态的 struct 都有 mutex，访问已同步。

**不通过标准**: 共享状态未同步访问，可能存在竞态条件。

**严重程度**: 严重

**建议**:
```go
type Manager struct {
    mu        sync.RWMutex          // 保护 items map
    items     map[string]*ItemInfo
}

func (m *Manager) GetItem(name string) (*ItemInfo, bool) {
    m.mu.RLock()
    defer m.mu.RUnlock()
    item, ok := m.items[name]
    return item, ok
}
```

---

### 2. 读多写少时使用 RWMutex

**说明**: 当读操作远多于写操作时，使用 `sync.RWMutex`。

**通过标准**: 读密集操作使用 `RLock`/`RUnlock`，写操作使用 `Lock`/`Unlock`。

**不通过标准**: 读密集场景使用 `sync.Mutex`，造成不必要的竞争。

**严重程度**: 中

---

### 3. 始终 defer 释放锁

**说明**: 使用 `defer` 释放 mutex，确保在所有代码路径上都能释放。

**通过标准**: 每个 `Lock()` 后紧跟 `defer Unlock()`。

**不通过标准**: 在多个 return 点手动 unlock，panic 时有死锁风险。

**严重程度**: 严重

**建议**:
```go
func (m *Manager) StopAll() {
    m.mu.RLock()
    names := make([]string, 0, len(m.items))
    for name := range m.items {
        names = append(names, name)
    }
    m.mu.RUnlock()  // 调用 Stop 前释放锁

    for _, name := range names {
        m.Stop(name)
    }
}
```

---

### 4. 使用 channel 进行 goroutine 通信

**说明**: 优先使用 channel 而非共享内存进行 goroutine 协调。

**通过标准**: goroutine 通过类型化 channel 通信，channel 所有权清晰。

**不通过标准**: goroutine 通过全局变量共享状态且缺少同步。

**严重程度**: 高

**建议**:
```go
func startStream() <-chan Message {
    ch := make(chan Message, 32)  // 带缓冲，异步处理
    go func() {
        defer close(ch)  // 完成时关闭
        ch <- Message{Content: data}
    }()
    return ch
}
```

---

### 5. 合理设置 channel 缓冲区大小

**说明**: 根据生产者/消费者模式选择缓冲区大小。

**通过标准**: 生产者不应阻塞时使用带缓冲 channel，需要同步时使用无缓冲 channel。

**不通过标准**: 无缓冲 channel 导致死锁，过大缓冲浪费内存。

**严重程度**: 中

**建议**:
```go
// 带缓冲：生产者不应因慢消费者而阻塞
ch := make(chan Message, 32)

// 无缓冲：需要同步点
done := make(chan struct{})
```

---

### 6. 由生产者关闭 channel

**说明**: 只有 channel 的生产者应该关闭 channel。

**通过标准**: channel 由发送数据的 goroutine 关闭，接收者不关闭。

**不通过标准**: 接收者关闭 channel，导致发送时 panic。

**严重程度**: 严重

**建议**:
```go
go func() {
    defer close(ch)  // 生产者关闭
    for _, item := range items {
        ch <- item
    }
}()

// 接收者只读取
for msg := range ch {
    process(msg)
}
```

---

### 7. 使用 Context 实现取消机制

**说明**: 使用 `context.Context` 传播超时和取消信号。

**通过标准**: 长时间运行的操作接受 context，取消信号被正确处理。

**不通过标准**: 操作无法取消，context 被忽略或未传递。

**严重程度**: 高

**建议**:
```go
func fetchData(ctx context.Context, url string) (*Data, error) {
    ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
    defer cancel()

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, err
    }
    // ...
}
```

---

### 8. 使用 sync.Once 实现一次性初始化

**说明**: 使用 `sync.Once` 实现线程安全的延迟初始化。

**通过标准**: 单例初始化使用 `sync.Once`，无竞态条件。

**不通过标准**: 双重检查锁定或其他易出错的模式。

**严重程度**: 中

**建议**:
```go
var (
    initOnce sync.Once
    instance *Service
)

func GetInstance() (*Service, error) {
    var initErr error
    initOnce.Do(func() {
        instance, initErr = newService()
    })
    return instance, initErr
}
```

---

### 9. 避免 goroutine 泄漏

**说明**: 每个 goroutine 必须有明确的退出条件。

**通过标准**: goroutine 有退出条件（channel 关闭、context 取消、超时）。

**不通过标准**: goroutine 永久阻塞在 channel 读取上或没有退出路径。

**严重程度**: 高

**建议**:
```go
go func() {
    for {
        select {
        case msg, ok := <-ch:
            if !ok {
                return  // channel 关闭，退出
            }
            process(msg)
        case <-ctx.Done():
            return  // context 取消，退出
        }
    }
}()
```

---

### 10. 使用 WaitGroup 协调 goroutine

**说明**: 使用 `sync.WaitGroup` 等待多个 goroutine 完成。

**通过标准**: 并行操作使用 WaitGroup，所有 goroutine 都被等待。

**不通过标准**: 主 goroutine 在 worker 完成前退出，存在竞态条件。

**严重程度**: 中

**建议**:
```go
func processAll(items []Item) {
    var wg sync.WaitGroup
    for _, item := range items {
        wg.Add(1)
        go func(it Item) {
            defer wg.Done()
            process(it)
        }(item)  // 传参避免闭包捕获
    }
    wg.Wait()  // 阻塞直到全部完成
}
```
