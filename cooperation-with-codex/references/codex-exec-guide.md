# Codex CLI exec 命令参考

## 基本语法

```bash
codex exec [flags] "<prompt>"
```

运行时 Codex 将进度输出到 stderr，最终结果输出到 stdout。

## 常用 Flags

| Flag | 说明 |
|------|------|
| `--full-auto` | 允许编辑，sandbox 限制在工作区写入 |
| `--sandbox <mode>` | `read-only`（默认）/ `workspace-write` / `danger-full-access` |
| `-m, --model <MODEL>` | 指定模型（如 `gpt-5.3-codex`、`gpt-5.2`） |
| `-c, --config <KEY=VALUE>` | 配置覆盖（如 `model_reasoning_effort=xhigh`） |
| `-C, --cd <DIR>` | 指定工作目录 |
| `-o, --output-last-message <PATH>` | 将最终消息写入文件 |
| `--json` | JSON Lines 输出（适合脚本消费） |
| `--ephemeral` | 不持久化 session 文件 |
| `--output-schema <PATH>` | 指定输出 JSON Schema |

## Session 管理

### 恢复上一个 session

```bash
codex exec resume --last "<follow-up prompt>"
```

通过 stdin 传递 prompt：

```bash
echo "<prompt>" | codex exec resume --last 2>/dev/null
```

### 恢复指定 session

```bash
codex exec resume <SESSION_ID> "<prompt>"
```

恢复时自动继承原 session 的模型、推理强度和 sandbox 设置。除非用户明确要求，恢复时不加额外配置 flags。

## 文件引用

在 prompt 中使用 `@file` 语法让 Codex 读取指定文件：

```
修改 @src/main.ts 中的 handleRequest 函数，添加错误处理
```

## 输出处理

### 管道输出

```bash
codex exec "<prompt>" | tee output.md
```

### JSON Lines 输出

```bash
codex exec --json "<prompt>" | jq
```

事件类型：`thread.started`、`turn.started`、`turn.completed`、`turn.failed`、`item.*`、`error`

## 协作模式默认命令

```bash
codex exec --full-auto -m gpt-5.3-codex -c model_reasoning_effort=xhigh \
  -C "<workdir>" "<prompt>" 2>/dev/null
```

- `--full-auto`：允许工作区写入，比 `--dangerously-bypass-approvals-and-sandbox` 更安全
- `2>/dev/null`：抑制 thinking tokens（stderr），调试时移除
- Bash timeout 建议设为 300000ms
