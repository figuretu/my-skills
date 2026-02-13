# Bubble Tea TUI 模式

使用 [Bubble Tea](https://github.com/charmbracelet/bubbletea) 和 [Lipgloss](https://github.com/charmbracelet/lipgloss) 构建终端用户界面的最佳实践。

## 检查清单

### 1. 正确实现 Model 接口

**描述**: 所有 Bubble Tea model 必须实现 `Init()`、`Update()` 和 `View()` 三个方法。

**严重程度**: High

**推荐做法**:
```go
type myModel struct {
    // 状态字段
    width  int
    height int
    err    error
}

func (m myModel) Init() tea.Cmd {
    // 返回初始命令（可以为 nil）
    return tea.Batch(doAsyncWork(), tea.EnterAltScreen)
}

func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    // 处理消息，返回更新后的 model 和命令
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.width = msg.Width
        m.height = msg.Height
    }
    return m, nil
}

func (m myModel) View() string {
    // 返回渲染字符串（绝不在此修改状态）
    return "Hello, World!"
}
```

---

### 2. 处理窗口尺寸消息

**描述**: 始终处理 `tea.WindowSizeMsg` 以支持终端窗口调整。

**严重程度**: High

**推荐做法**:
```go
func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.width = msg.Width
        m.height = msg.Height

        // 更新子组件
        m.viewport.Width = msg.Width
        m.viewport.Height = msg.Height - footerHeight - headerHeight

        // 防御负尺寸
        if m.viewport.Height < 1 {
            m.viewport.Height = 1
        }

        m.textarea.SetWidth(msg.Width - 2)
    }
    return m, nil
}
```

---

### 3. 使用消息类型驱动状态变更

**描述**: 为异步操作和状态更新定义自定义消息类型。

**严重程度**: Medium

**推荐做法**:
```go
// 定义消息类型
type responseMsg struct{ content string }
type errorMsg struct{ err error }
type streamDone struct{}

// 在 Update 中使用
func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case responseMsg:
        m.content = msg.content
    case errorMsg:
        m.err = msg.err
    case streamDone:
        m.loading = false
    }
    return m, nil
}

// 创建返回消息的命令
func fetchDataCmd() tea.Cmd {
    return func() tea.Msg {
        data, err := fetchData()
        if err != nil {
            return errorMsg{err: err}
        }
        return responseMsg{content: data}
    }
}
```

---

### 4. 使用 tea.Batch 组合多个命令

**描述**: 从 Update 返回多个命令时，用 `tea.Batch` 组合。

**严重程度**: Medium

**推荐做法**:
```go
func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd

    // 更新子组件
    var vpCmd tea.Cmd
    m.viewport, vpCmd = m.viewport.Update(msg)
    cmds = append(cmds, vpCmd)

    var taCmd tea.Cmd
    m.textarea, taCmd = m.textarea.Update(msg)
    cmds = append(cmds, taCmd)

    switch msg := msg.(type) {
    case tea.KeyMsg:
        if msg.String() == "enter" {
            cmds = append(cmds, sendMessageCmd(m.textarea.Value()))
        }
    }

    return m, tea.Batch(cmds...)
}
```

---

### 5. 保持 View() 纯函数无副作用

**描述**: `View()` 方法只负责渲染状态，绝不修改状态。

**严重程度**: High

**推荐做法**:
```go
// 推荐
func (m myModel) View() string {
    var b strings.Builder
    b.WriteString(m.header())
    b.WriteString(m.viewport.View())
    b.WriteString(m.footer())
    return b.String()
}

// 避免 — 在 View 中修改状态
func (m myModel) View() string {
    m.renderCount++  // 错误：修改了状态
    return fmt.Sprintf("Rendered %d times", m.renderCount)
}
```

---

### 6. 统一使用 Lipgloss 样式

**描述**: 将样式定义为包级变量或 model 字段，保持一致性。

**严重程度**: Medium

**推荐做法**:
```go
// 在包级别或 model 初始化时定义样式
var (
    headerStyle = lipgloss.NewStyle().
        Bold(true).
        Foreground(lipgloss.Color("86"))

    errorStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("9"))

    hintStyle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("240"))
)

// 在 View 中使用
func (m myModel) View() string {
    return headerStyle.Render("Title") + "\n" +
           m.content + "\n" +
           hintStyle.Render("Press q to quit")
}
```

---

### 7. 正确处理键盘事件

**描述**: 使用 `tea.KeyMsg` 配合正确的按键字符串比较。

**严重程度**: Medium

**推荐做法**:
```go
func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "ctrl+c", "q":
            return m, tea.Quit
        case "enter":
            return m, m.submitInput()
        case "up":
            m.navigateHistory(-1)
        case "down":
            m.navigateHistory(1)
        case "esc":
            if m.menuActive {
                m.menuActive = false
            } else if m.loading {
                m.cancelOperation()
            }
        }
    }
    return m, nil
}
```

---

### 8. 实现取消支持

**描述**: 长时间运行的操作应支持通过 Escape 或 Ctrl+C 取消。

**严重程度**: High

**推荐做法**:
```go
type myModel struct {
    cancelFunc context.CancelFunc
    loading    bool
}

func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        if msg.String() == "esc" && m.loading {
            if m.cancelFunc != nil {
                m.cancelFunc()
            }
            m.loading = false
            return m, nil
        }
    }
    return m, nil
}

func (m *myModel) startAsyncOperation() tea.Cmd {
    ctx, cancel := context.WithCancel(context.Background())
    m.cancelFunc = cancel
    m.loading = true

    return func() tea.Msg {
        result, err := doWork(ctx)
        if err != nil {
            return errorMsg{err: err}
        }
        return responseMsg{content: result}
    }
}
```

---

### 9. 使用 Viewport 实现可滚动内容

**描述**: 对可能超出终端高度的内容使用 viewport 组件。

**严重程度**: Medium

**推荐做法**:
```go
import "github.com/charmbracelet/bubbles/viewport"

type myModel struct {
    viewport viewport.Model
    ready    bool
}

func newModel() myModel {
    vp := viewport.New(80, 20)
    vp.SetContent("Initial content")
    return myModel{viewport: vp}
}

func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd

    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        headerHeight := 3
        footerHeight := 2
        m.viewport.Width = msg.Width
        m.viewport.Height = msg.Height - headerHeight - footerHeight
        m.ready = true
    }

    m.viewport, cmd = m.viewport.Update(msg)
    return m, cmd
}
```

---

### 10. 正确处理自动滚动

**描述**: 新内容到达时自动滚动到底部，但尊重用户的滚动位置。

**严重程度**: Medium

**推荐做法**:
```go
func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case responseMsg:
        // 添加内容前检查用户是否在底部
        wasAtBottom := m.viewport.AtBottom()

        // 添加新内容
        m.content += msg.content
        m.viewport.SetContent(m.content)

        // 仅在用户正在跟随时自动滚动
        if wasAtBottom {
            m.viewport.GotoBottom()
        }
    }
    return m, nil
}
```

---

### 11. 使用 Spinner 显示加载状态

**描述**: 异步操作期间显示 spinner 动画，给用户反馈。

**严重程度**: Low

**推荐做法**:
```go
import "github.com/charmbracelet/bubbles/spinner"

type myModel struct {
    spinner spinner.Model
    loading bool
}

func newModel() myModel {
    s := spinner.New()
    s.Spinner = spinner.Dot
    s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))
    return myModel{spinner: s}
}

func (m myModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    if m.loading {
        var cmd tea.Cmd
        m.spinner, cmd = m.spinner.Update(msg)
        return m, cmd
    }
    return m, nil
}

func (m myModel) View() string {
    if m.loading {
        return m.spinner.View() + " Loading..."
    }
    return m.content
}
```

---

### 12. 分离 Overlay 组件

**描述**: Overlay 组件（菜单、对话框）应作为独立 model，便于复用。

**严重程度**: Medium

**推荐做法**:
```go
// toast.go
type ToastModel struct {
    message   string
    visible   bool
    timestamp time.Time
}

func (m ToastModel) Update(msg tea.Msg) (ToastModel, tea.Cmd) {
    switch msg := msg.(type) {
    case ShowToastMsg:
        m.message = msg.Message
        m.visible = true
        return m, tea.Tick(3*time.Second, func(t time.Time) tea.Msg {
            return HideToastMsg{}
        })
    case HideToastMsg:
        m.visible = false
    }
    return m, nil
}

// 在主 model 中使用
func (m myModel) View() string {
    content := m.mainContent()
    if toast := m.toast.View(); toast != "" {
        content += "\n" + toast
    }
    return content
}
```
