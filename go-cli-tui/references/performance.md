# CLI 性能优化

构建高响应、高效率 Go CLI/TUI 应用的最佳实践。

## 检查清单

### 1. 延迟加载重依赖

**描述**: 将昂贵资源的加载推迟到实际需要时。

**严重程度**: High

**推荐做法**:
```go
// 推荐 — 延迟加载
var configCache *Config

func getConfig() (*Config, error) {
    if configCache != nil {
        return configCache, nil
    }
    cfg, err := loadConfig()
    if err != nil {
        return nil, err
    }
    configCache = cfg
    return configCache, nil
}

// 避免 — 在 init() 中急切加载
func init() {
    config, _ = loadConfig()  // 拖慢所有命令的启动
}
```

---

### 2. HTTP 连接池复用

**描述**: 复用 HTTP client 和连接，避免每次请求创建新实例。

**严重程度**: Medium

**推荐做法**:
```go
var httpClient *http.Client
var httpOnce sync.Once

func GetHTTPClient() *http.Client {
    httpOnce.Do(func() {
        httpClient = &http.Client{
            Timeout: 30 * time.Second,
            Transport: &http.Transport{
                MaxIdleConns:        100,
                MaxIdleConnsPerHost: 10,
                IdleConnTimeout:     90 * time.Second,
            },
        }
    })
    return httpClient
}
```

---

### 3. 流式处理大响应

**描述**: 对大型 API 响应使用流式处理，而非全量缓存到内存。

**严重程度**: High

**推荐做法**:
```go
// 推荐 — 流式处理
func streamResponse(resp *http.Response, callback func(chunk string)) error {
    reader := bufio.NewReader(resp.Body)
    for {
        line, err := reader.ReadString('\n')
        if err == io.EOF {
            break
        }
        if err != nil {
            return err
        }
        callback(line)
    }
    return nil
}

// 避免 — 全量缓存
func readResponse(resp *http.Response) (string, error) {
    body, err := io.ReadAll(resp.Body)  // 可能消耗大量内存
    return string(body), err
}
```

---

### 4. 渲染/进度更新节流

**描述**: 限制 UI 更新频率，防止闪烁和 CPU 过度消耗。

**严重程度**: Medium

**推荐做法**:
```go
type throttledWriter struct {
    mu          sync.Mutex
    lastContent string
    sent        bool
}

func (w *throttledWriter) Send(content string) {
    w.mu.Lock()
    defer w.mu.Unlock()

    w.lastContent = content

    if !w.sent {
        render(content)
        w.sent = true

        go func() {
            time.Sleep(100 * time.Millisecond)
            w.mu.Lock()
            w.sent = false
            w.mu.Unlock()
        }()
    }
}
```

---

### 5. 缓存昂贵计算

**描述**: 缓存不频繁变化的昂贵操作结果。

**严重程度**: Medium

**推荐做法**:
```go
type cachedResult struct {
    data      interface{}
    timestamp time.Time
}

var cache = struct {
    sync.RWMutex
    items map[string]cachedResult
}{items: make(map[string]cachedResult)}

func getCached(key string, ttl time.Duration, fetch func() (interface{}, error)) (interface{}, error) {
    cache.RLock()
    if item, ok := cache.items[key]; ok && time.Since(item.timestamp) < ttl {
        cache.RUnlock()
        return item.data, nil
    }
    cache.RUnlock()

    data, err := fetch()
    if err != nil {
        return nil, err
    }

    cache.Lock()
    cache.items[key] = cachedResult{data: data, timestamp: time.Now()}
    cache.Unlock()

    return data, nil
}
```

---

### 6. 减少不必要的渲染

**描述**: 仅在状态实际变化时重新渲染 TUI。

**严重程度**: Medium

**推荐做法**:
```go
// 用内容哈希检测变化
func computeContentKey(messages []Message) string {
    if len(messages) == 0 {
        return "empty"
    }
    msg := messages[len(messages)-1]
    h := fnv.New64a()
    io.WriteString(h, msg.Role)
    io.WriteString(h, msg.Content)
    return fmt.Sprintf("%x", h.Sum64())
}

var lastContentKey string

func renderIfChanged(messages []Message, cached string) string {
    key := computeContentKey(messages)
    if lastContentKey == key {
        return cached  // 返回缓存的渲染结果
    }
    lastContentKey = key
    return renderMessages(messages)
}
```

---

### 7. 使用 Goroutine 并行化独立操作

**描述**: 并发执行独立操作以减少总等待时间。

**严重程度**: Medium

**推荐做法**:
```go
func fetchProjectData(id string) (*ProjectData, error) {
    var wg sync.WaitGroup
    var models []ModelInfo
    var config *Config
    var modelsErr, cfgErr error

    wg.Add(2)

    go func() {
        defer wg.Done()
        models, modelsErr = fetchModels(id)
    }()

    go func() {
        defer wg.Done()
        config, cfgErr = fetchConfig(id)
    }()

    wg.Wait()

    if modelsErr != nil {
        return nil, modelsErr
    }
    if cfgErr != nil {
        return nil, cfgErr
    }

    return &ProjectData{Models: models, Config: config}, nil
}
```

---

### 8. 高效字符串拼接

**描述**: 使用 `strings.Builder` 拼接多个字符串。

**严重程度**: Low

**推荐做法**:
```go
// 推荐
func renderMessages(messages []Message) string {
    var b strings.Builder
    for _, msg := range messages {
        b.WriteString(formatMessage(msg))
        b.WriteString("\n")
    }
    return b.String()
}

// 避免
func renderMessages(messages []Message) string {
    result := ""
    for _, msg := range messages {
        result += formatMessage(msg) + "\n"  // 每次迭代创建新字符串
    }
    return result
}
```

---

### 9. 防御负尺寸

**描述**: 防止负的 viewport 尺寸导致 panic。

**严重程度**: High

**推荐做法**:
```go
func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        headerHeight := lipgloss.Height(m.renderHeader())
        footerHeight := lipgloss.Height(m.renderFooter())

        // 关键：防止负高度
        newHeight := msg.Height - headerHeight - footerHeight
        if newHeight < 1 {
            newHeight = 1
        }

        m.viewport.Height = newHeight
        m.viewport.Width = msg.Width

        // 同样保护 textarea 宽度
        newWidth := msg.Width - 2
        if newWidth < 10 {
            newWidth = 10
        }
        m.textarea.SetWidth(newWidth)
    }
    return m, nil
}
```

---

### 10. 使用 Context 超时

**描述**: 为所有网络操作设置合适的超时。

**严重程度**: High

**推荐做法**:
```go
func fetchWithTimeout(url string) ([]byte, error) {
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil {
        return nil, err
    }

    resp, err := GetHTTPClient().Do(req)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            return nil, fmt.Errorf("request timed out after 30s")
        }
        return nil, err
    }
    defer resp.Body.Close()

    return io.ReadAll(resp.Body)
}
```

---

### 11. 不要阻塞主循环

**描述**: 永远不要在 `Update()` 中执行阻塞操作 — 使用 command 代替。

**严重程度**: High

**推荐做法**:
```go
// 推荐 — 异步 command
func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        if msg.String() == "enter" {
            return m, fetchDataCmd(m.input)  // 立即返回
        }
    case dataMsg:
        m.data = msg.data  // 处理结果
    }
    return m, nil
}

func fetchDataCmd(input string) tea.Cmd {
    return func() tea.Msg {
        data, err := fetchFromAPI(input)  // 在 goroutine 中运行
        if err != nil {
            return errorMsg{err: err}
        }
        return dataMsg{data: data}
    }
}

// 避免 — 在 Update 中阻塞
func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        if msg.String() == "enter" {
            data, _ := fetchFromAPI(m.input)  // 阻塞 UI
            m.data = data
        }
    }
    return m, nil
}
```

---

### 12. 先 Profile 再优化

**描述**: 使用 Go 的 profiling 工具定位实际瓶颈。

**严重程度**: Low

**推荐做法**:
```go
// 为开发环境添加 profiling 支持
import _ "net/http/pprof"

func main() {
    if os.Getenv("ENABLE_PPROF") == "1" {
        go func() {
            log.Println(http.ListenAndServe("localhost:6060", nil))
        }()
    }
    // ...
}

// 使用方法：
// ENABLE_PPROF=1 mycli run
// go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30
```
