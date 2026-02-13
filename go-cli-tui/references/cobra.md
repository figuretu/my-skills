# Cobra 命令模式

使用 [spf13/cobra](https://github.com/spf13/cobra) 构建 CLI 命令的最佳实践。

## 检查清单

### 1. 使用 RunE 处理错误

**描述**: 优先使用 `RunE` 而非 `Run`，让错误沿命令链正确传播。

**严重程度**: Medium

**备注**: root 命令可以例外使用 `Run`，因为它通常只负责分发到子命令。

**推荐做法**:
```go
// 推荐
var myCmd = &cobra.Command{
    Use: "mycommand",
    RunE: func(cmd *cobra.Command, args []string) error {
        if err := doWork(); err != nil {
            return fmt.Errorf("failed to do work: %w", err)
        }
        return nil
    },
}

// 避免
var myCmd = &cobra.Command{
    Use: "mycommand",
    Run: func(cmd *cobra.Command, args []string) {
        if err := doWork(); err != nil {
            fmt.Fprintf(os.Stderr, "Error: %v\n", err)
            os.Exit(1)  // 绕过了 Cobra 的错误处理机制
        }
    },
}
```

---

### 2. 使用 Args 校验器

**描述**: 使用 Cobra 内置的参数校验器，而非手动校验。

**严重程度**: Low

**推荐做法**:
```go
// 推荐
var myCmd = &cobra.Command{
    Use:  "mycommand <required-arg>",
    Args: cobra.ExactArgs(1),
}

// 自定义校验
var myCmd = &cobra.Command{
    Use: "deploy [environment]",
    Args: func(cmd *cobra.Command, args []string) error {
        if len(args) > 0 && !isValidEnv(args[0]) {
            return fmt.Errorf("invalid environment: %s", args[0])
        }
        return nil
    },
}
```

---

### 3. 在 init() 中注册 Flags

**描述**: 在 `init()` 函数中注册所有 flags，保持初始化顺序可预测。

**严重程度**: Medium

**推荐做法**:
```go
var myFlag string

var myCmd = &cobra.Command{
    Use: "mycommand",
    RunE: runMyCommand,
}

func init() {
    rootCmd.AddCommand(myCmd)
    myCmd.Flags().StringVar(&myFlag, "myflag", "default", "Description of flag")
    myCmd.Flags().BoolVar(&verbose, "verbose", false, "Enable verbose output")
}
```

---

### 4. 使用 Persistent Flags 共享选项

**描述**: 在父命令上使用 `PersistentFlags()`，让子命令自动继承共享选项。

**严重程度**: Low

**推荐做法**:
```go
// root.go 中
func init() {
    rootCmd.PersistentFlags().BoolVarP(&debug, "debug", "d", false, "Enable debug output")
    rootCmd.PersistentFlags().StringVar(&serverURL, "server-url", "http://localhost:8080", "Server URL")
}

// 子命令自动继承这些 flags
```

---

### 5. 提供完整的帮助文本

**描述**: 命令应包含清晰的 `Short`、`Long` 描述和使用示例。

**严重程度**: Low

**推荐做法**:
```go
var myCmd = &cobra.Command{
    Use:   "mycommand [flags] <required-arg>",
    Short: "Brief one-line description",
    Long: `Extended description explaining the command's purpose.

Examples:
  # Basic usage
  mycli mycommand value

  # With flags
  mycli mycommand --flag=option value`,
}
```

---

### 6. 使用子命令层级

**描述**: 将相关命令分组到父命令下，提升组织结构。

**严重程度**: Low

**推荐做法**:
```go
// 父命令（不需要 Run 函数）
var servicesCmd = &cobra.Command{
    Use:   "services",
    Short: "Manage services",
}

// 子命令
var servicesStartCmd = &cobra.Command{
    Use:   "start [service-name]",
    Short: "Start services",
    RunE:  runServicesStart,
}

func init() {
    rootCmd.AddCommand(servicesCmd)
    servicesCmd.AddCommand(servicesStartCmd)
    servicesCmd.AddCommand(servicesStopCmd)
    servicesCmd.AddCommand(servicesStatusCmd)
}
```

---

### 7. 使用 PersistentPreRunE 做通用初始化

**描述**: 用 `PersistentPreRunE` 处理所有子命令共享的初始化逻辑。

**严重程度**: Medium

**推荐做法**:
```go
var rootCmd = &cobra.Command{
    Use:   "mycli",
    Short: "My CLI tool",
    PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
        if debug {
            initDebugLogger()
        }
        return nil
    },
}
```

---

### 8. 支持 JSON 输出以便脚本化

**描述**: 输出结构化数据的命令应支持 `--json` flag。

**严重程度**: Medium

**推荐做法**:
```go
func init() {
    myCmd.Flags().Bool("json", false, "Output in JSON format")
}

func runMyCommand(cmd *cobra.Command, args []string) error {
    jsonOutput, _ := cmd.Flags().GetBool("json")

    result := getResult()

    if jsonOutput {
        encoder := json.NewEncoder(os.Stdout)
        encoder.SetIndent("", "  ")
        return encoder.Encode(result)
    }

    // 人类可读输出
    fmt.Printf("Result: %s\n", result.Name)
    return nil
}
```

---

### 9. 校验 Flag 组合

**描述**: 校验互斥或依赖的 flag 组合。

**严重程度**: Medium

**推荐做法**:
```go
func init() {
    myCmd.Flags().StringVar(&inputFile, "file", "", "Input from file")
    myCmd.Flags().StringVar(&inputText, "text", "", "Input as text")

    // Cobra 1.5+ 内置校验
    myCmd.MarkFlagsMutuallyExclusive("file", "text")
}

func runMyCommand(cmd *cobra.Command, args []string) error {
    if inputFile != "" && inputText != "" {
        return fmt.Errorf("specify either --file or --text, not both")
    }
    // ...
}
```

---

### 10. 使用 Context 支持取消

**描述**: 通过命令传递 context，支持长时间操作的取消。

**严重程度**: High

**推荐做法**:
```go
func runMyCommand(cmd *cobra.Command, args []string) error {
    ctx := cmd.Context()

    // 将 context 传递给长时间运行的操作
    result, err := longRunningOperation(ctx)
    if err != nil {
        if errors.Is(err, context.Canceled) {
            return fmt.Errorf("operation cancelled")
        }
        return err
    }

    return nil
}
```
