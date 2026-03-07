---
name: cpp-coding
description: "C++ 编码规范与最佳实践（编码规范类，与流程类 skill 不互斥）。涵盖现代 C++ 惯用模式、RAII、智能指针、错误处理、并发、性能和安全编码。适用场景：(1) 用 C++ 实现新需求或新功能，(2) 重构 C++ 模块/类，(3) 对 C++ 代码进行 code review，(4) 优化 C++ 代码质量，(5) 其他 skill 驱动的流程涉及 C++ 代码编写或修改时，作为编码规范补充加载。不适用于局部小修（语法修复、变量重命名、单行改动等）。"
---

# C++ 编码最佳实践

确保 C++ 代码符合现代 C++ 风格、可维护、高性能且安全。适用于实现、重构和 code review。

## 使用模式

本 skill 是**编码规范类**，定位为 C++ 代码质量基线，与流程类 skill 不互斥。

| 模式 | 场景 | 行为 |
|------|------|------|
| 独立 | 用户直接要求 C++ 编码指导、review 或重构 | 作为主 skill 加载 |
| 协同 | 其他 skill 驱动的流程涉及 C++ 代码变更 | 与流程 skill 同时加载，约束代码质量 |

## 风格原则（优先级排序）

1. **Correctness** — 代码逻辑正确，无未定义行为，资源管理安全。
2. **Clarity** — 代码意图清晰，易于理解和维护。
3. **Performance** — 避免不必要的拷贝、分配和计算开销。
4. **Safety** — 防止内存泄漏、悬空指针、数据竞争等问题。
5. **Consistency** — 与项目现有代码风格保持一致。

## 核心编码规范

### 格式化

- 遵循项目的 `.clang-format` 配置，无例外。
- 如果项目没有 `.clang-format`，遵循 Google C++ Style Guide 格式规范。
- 命名规范：
  - 类型名（类、结构体、枚举）：`CamelCase`（如 `TabletManager`）
  - 函数名：`snake_case` 或 `CamelCase`（与项目保持一致）
  - 变量名：`snake_case`（如 `tablet_count`）
  - 成员变量：`snake_case_`（尾部下划线，如 `tablets_`）
  - 常量：`kCamelCase`（如 `kMaxRetryCount`）
- 行长度：建议不超过 100 字符，按语义断行。

### 头文件

- 使用 `#pragma once` 而非传统的 include guards。
- 头文件包含顺序：
  1. 对应的 `.h` 文件（如果是 `.cc` 文件）
  2. C 系统头文件（如 `<unistd.h>`）
  3. C++ 标准库头文件（如 `<vector>`、`<memory>`）
  4. 第三方库头文件（如 `<glog/logging.h>`）
  5. 项目内部头文件
- 每组之间空一行。

### 类型和变量

- **显式类型声明**：在生产代码中优先使用显式类型声明，避免过度使用 `auto`。
  - ✅ 允许：迭代器、复杂模板类型、lambda 返回值等显而易见的场景
  - ❌ 避免：基本类型、简单对象类型（如 `auto x = 5;` 应写为 `int x = 5;`）
  - 测试代码中可以更自由地使用 `auto`
- **Lambda 表达式**：在生产代码中谨慎使用 lambda，优先使用命名函数。
  - ✅ 允许：STL 算法的简单谓词、回调函数
  - ❌ 避免：复杂逻辑的 lambda（超过 3 行）、捕获大量外部变量
  - 测试代码中可以更自由地使用 lambda
- **const 正确性**：能用 `const` 尽量使用 `const`。
  - 函数参数：传引用时使用 `const Type&`（除非需要修改）
  - 成员函数：不修改成员变量的函数标记为 `const`
  - 局部变量：不会修改的变量声明为 `const`

### 内存管理

- **禁止裸指针管理资源**：禁止使用 `new`/`delete` 直接管理内存。
- **智能指针优先级**：
  1. **栈对象**：优先使用栈对象，避免不必要的堆分配
  2. **unique_ptr**：独占所有权场景（90% 的情况）
  3. **shared_ptr**：仅在真正需要共享所有权时使用，避免滥用
- **RAII 惯用法**：资源在构造函数中分配，在析构函数中释放。
  - 文件句柄、网络连接、锁等都应该用 RAII 封装

```cpp
// Good: 使用 unique_ptr
std::unique_ptr<Widget> widget = std::make_unique<Widget>();

// Good: 栈对象
Widget widget;

// Bad: 裸指针
Widget* widget = new Widget();  // 禁止！
delete widget;

// Acceptable: shared_ptr（仅在真正需要共享时）
std::shared_ptr<Widget> shared_widget = std::make_shared<Widget>();
```

### 错误处理

- **Result 类型**：对于可能失败的操作，使用项目定义的 `Result<T>` 或 `Status` 类型。
- **错误传播宏**：使用项目提供的错误处理宏进行错误传播：
  - `RETURN_IF_ERROR(expr)` - 如果表达式返回错误，立即返回
  - `RETURN_ERROR(status, msg)` - 返回带消息的错误
  - `ASSIGN_OR_RETURN(lhs, expr)` - 赋值或返回错误
- **异常使用**：
  - 遵循项目的异常策略（有些项目禁用异常）
  - 如果使用异常，仅用于真正的异常情况，不用于控制流
  - 析构函数、移动构造函数、swap 函数应标记 `noexcept`

```cpp
// Good: 使用 Result 类型和错误处理宏
Result<Widget> CreateWidget(const Config& config) {
    RETURN_IF_ERROR(ValidateConfig(config));

    auto widget = std::make_unique<Widget>();
    RETURN_IF_ERROR(widget->Initialize(config));

    return widget;
}

// Good: 使用错误处理宏
Status ProcessData(const Data& data) {
    ASSIGN_OR_RETURN(auto parsed, ParseData(data));
    RETURN_IF_ERROR(ValidateData(parsed));
    return SaveData(parsed);
}
```

### 函数设计

- **单一职责**：每个函数只做一件事，保持函数短小精悍（建议不超过 50 行）。
- **参数传递**：
  - 输入参数：小对象传值，大对象传 `const&`
  - 输出参数：使用返回值或 `Result<T>`，避免输出参数
  - 可选参数：使用 `std::optional<T>`
- **返回值优化**：利用 RVO/NRVO，直接返回对象而非指针。

```cpp
// Good: 返回值优化
std::vector<int> GetData() {
    std::vector<int> result;
    // ... 填充 result
    return result;  // RVO 优化，无拷贝
}

// Good: 参数传递
void ProcessWidget(const Widget& input, Widget* output);  // 输入 const&，输出指针
Result<Widget> CreateWidget(const Config& config);       // 更好：返回 Result
```

### 类设计

- **Rule of Five/Zero**：
  - 如果定义了析构函数，通常也需要定义拷贝构造、拷贝赋值、移动构造、移动赋值
  - 如果不需要自定义，使用 `= default`
  - 如果禁止拷贝/移动，使用 `= delete`
- **继承**：
  - 不被继承的类使用 `final` 修饰
  - 重写虚函数使用 `override` 修饰
  - 虚析构函数：基类如果有虚函数，析构函数必须是虚函数
- **成员变量顺序**：
  - 基本类型在前，复杂类型在后
  - public、protected、private 分组，不要混在一起

```cpp
// Good: Rule of Five
class Widget {
public:
    Widget() = default;
    ~Widget() = default;
    Widget(const Widget&) = delete;              // 禁止拷贝
    Widget& operator=(const Widget&) = delete;
    Widget(Widget&&) noexcept = default;         // 允许移动
    Widget& operator=(Widget&&) noexcept = default;
};

// Good: 继承
class Base {
public:
    virtual ~Base() = default;
    virtual void DoSomething() = 0;
};

class Derived final : public Base {  // final 表示不可再继承
public:
    void DoSomething() override;      // override 表示重写
};
```

### 并发

- **避免共享可变状态**：优先使用消息传递而非共享内存。
- **互斥锁**：使用 RAII 风格的锁（`std::lock_guard`、`std::unique_lock`）。
- **原子操作**：简单计数器使用 `std::atomic`。
- **线程安全**：在类文档中明确说明线程安全性。

```cpp
// Good: RAII 锁
std::mutex mutex_;
void ThreadSafeMethod() {
    std::lock_guard<std::mutex> lock(mutex_);
    // 临界区代码
}  // 自动释放锁
```

## 注释规范

### 总体原则

注释面向读者，解释 **why** 而非 **what**。所有注释以句号结尾。

### 文件头注释

每个文件开头应有版权声明和文件用途说明（如果项目要求）。

### 类和函数注释

- 导出的类、函数必须有注释。
- 注释应说明功能、参数、返回值、异常/错误、线程安全性。

```cpp
// Manages the lifecycle of tablets in the system.
// Thread-safe: all public methods can be called concurrently.
class TabletManager {
public:
    // Creates a new tablet with the given configuration.
    // Returns an error if the configuration is invalid or creation fails.
    Result<Tablet> CreateTablet(const TabletConfig& config);
};
```

### 实现注释

复杂逻辑前添加注释说明意图。

```cpp
void ProcessData(const Data& data) {
    // Validate input before processing.
    if (!IsValid(data)) {
        return;
    }

    // Apply transformation pipeline.
    auto transformed = Transform(data);

    // Persist to storage.
    Save(transformed);
}
```

## C++ 核心准则

> Prefer simple and conventional ways of doing things.
> Make interfaces precisely and strongly typed.
> Avoid premature optimization.
> Don't leak any resources.
> Don't use owning raw pointers.
> Use RAII to prevent leaks.
> Prefer immutable data to mutable data.
> Encapsulate messy constructs, rather than spreading through the code.
> Use exceptions for error handling.
> Prefer compile-time checking to run-time checking.
> Make interfaces easy to use correctly and hard to use incorrectly.

## 专项参考（按需加载）

**加载时机**：仅在 code review 或重构时按需加载。实现需求时不读专项参考，遵循上方核心编码规范即可。

| 文件 | 何时加载 |
|------|----------|
| [memory-management.md](references/memory-management.md) | 代码涉及智能指针、RAII、移动语义 |
| [error-handling.md](references/error-handling.md) | 代码涉及错误处理、异常、Result 类型 |
| [concurrency.md](references/concurrency.md) | 代码涉及多线程、锁、原子操作 |
| [performance.md](references/performance.md) | 需要优化性能、分析算法复杂度 |
| [security.md](references/security.md) | 代码涉及外部输入、网络、文件操作 |

## 项目特定规范

如果项目根目录存在 `.cpp-coding-overrides.md` 文件，优先加载该文件作为项目特定规范的补充或覆盖。
