# 性能优化最佳实践

## 基本原则

1. **先保证正确性，再优化性能**
2. **测量，不要猜测** - 使用 profiler 找到瓶颈
3. **优化热点路径** - 80/20 原则，优化 20% 的代码获得 80% 的收益
4. **避免过早优化** - 清晰的代码优于聪明的代码

## 避免不必要的拷贝

### 传参优化

```cpp
// Bad: 不必要的拷贝
void ProcessData(std::vector<int> data) {  // 拷贝整个 vector！
    // ...
}

// Good: 传引用
void ProcessData(const std::vector<int>& data) {  // 无拷贝
    // ...
}

// Good: 移动语义
void TakeOwnership(std::vector<int> data) {  // 接受移动
    // ...
}
// 调用：TakeOwnership(std::move(vec));
```

### 返回值优化 (RVO/NRVO)

```cpp
// Good: 编译器优化，无拷贝
std::vector<int> CreateVector() {
    std::vector<int> result;
    result.push_back(1);
    result.push_back(2);
    return result;  // RVO 优化
}

// Bad: 阻止 RVO
std::vector<int> CreateVector() {
    std::vector<int> result;
    result.push_back(1);
    return std::move(result);  // 不要这样做！阻止 RVO
}
```

### emplace vs push

```cpp
// Bad: 构造临时对象再拷贝
std::vector<Widget> widgets;
widgets.push_back(Widget(args));  // 构造 + 移动

// Good: 原地构造
widgets.emplace_back(args);  // 直接在 vector 中构造
```

## 内存管理

### 预分配内存

```cpp
// Bad: 多次重新分配
std::vector<int> vec;
for (int i = 0; i < 1000; ++i) {
    vec.push_back(i);  // 可能多次重新分配
}

// Good: 预分配
std::vector<int> vec;
vec.reserve(1000);  // 一次分配
for (int i = 0; i < 1000; ++i) {
    vec.push_back(i);
}
```

### 对象池

```cpp
// Good: 对象池避免频繁分配/释放
class ObjectPool {
public:
    std::unique_ptr<Widget> Acquire() {
        if (pool_.empty()) {
            return std::make_unique<Widget>();
        }
        auto widget = std::move(pool_.back());
        pool_.pop_back();
        return widget;
    }

    void Release(std::unique_ptr<Widget> widget) {
        widget->Reset();
        pool_.push_back(std::move(widget));
    }

private:
    std::vector<std::unique_ptr<Widget>> pool_;
};
```

### 小对象优化

```cpp
// Good: 使用 std::string 的 SSO (Small String Optimization)
std::string short_str = "hello";  // 栈上存储，无堆分配

// Good: 自定义小对象优化
template<typename T, size_t N = 16>
class SmallVector {
    union {
        T stack_storage_[N];
        T* heap_storage_;
    };
    size_t size_;
    bool on_heap_;
};
```

## 算法优化

### 选择合适的数据结构

```cpp
// Bad: 频繁查找使用 vector
std::vector<int> data;
if (std::find(data.begin(), data.end(), value) != data.end()) {  // O(n)
    // ...
}

// Good: 使用 unordered_set
std::unordered_set<int> data;
if (data.find(value) != data.end()) {  // O(1)
    // ...
}
```

### 避免不必要的排序

```cpp
// Bad: 只需要最大值却排序整个数组
std::sort(data.begin(), data.end());
int max = data.back();  // O(n log n)

// Good: 使用 max_element
int max = *std::max_element(data.begin(), data.end());  // O(n)
```

### 批量操作

```cpp
// Bad: 逐个插入
for (const auto& item : items) {
    vec.push_back(item);
}

// Good: 批量插入
vec.insert(vec.end(), items.begin(), items.end());
```

## 缓存友好

### 数据局部性

```cpp
// Bad: 缓存不友好（结构体数组）
struct Particle {
    float x, y, z;
    float vx, vy, vz;
    float mass;
};
std::vector<Particle> particles;

// 更新位置时，加载了不需要的 velocity 和 mass
for (auto& p : particles) {
    p.x += dt;
    p.y += dt;
    p.z += dt;
}

// Good: 缓存友好（数组结构体）
struct Particles {
    std::vector<float> x, y, z;
    std::vector<float> vx, vy, vz;
    std::vector<float> mass;
};

// 只加载需要的数据
for (size_t i = 0; i < particles.x.size(); ++i) {
    particles.x[i] += dt;
    particles.y[i] += dt;
    particles.z[i] += dt;
}
```

### 避免虚函数调用

```cpp
// Bad: 热点路径中的虚函数调用
for (const auto& shape : shapes) {
    shape->Draw();  // 虚函数调用开销
}

// Good: 按类型分组，减少虚函数调用
for (const auto& circle : circles) {
    circle.Draw();  // 直接调用
}
for (const auto& rect : rectangles) {
    rect.Draw();
}
```

## 并发优化

### 减少锁竞争

```cpp
// Bad: 粗粒度锁
std::mutex mutex;
std::map<std::string, int> cache;

int Get(const std::string& key) {
    std::lock_guard<std::mutex> lock(mutex);
    return cache[key];
}

// Good: 读写锁
std::shared_mutex mutex;
std::map<std::string, int> cache;

int Get(const std::string& key) {
    std::shared_lock<std::shared_mutex> lock(mutex);  // 多个读者可以并发
    return cache[key];
}
```

### 线程局部存储

```cpp
// Good: 避免锁竞争
thread_local std::vector<int> thread_buffer;

void Process(int value) {
    thread_buffer.push_back(value);  // 无需锁
}
```

## 编译器优化

### 内联

```cpp
// Good: 小函数标记为 inline
inline int Square(int x) {
    return x * x;
}

// Good: constexpr 函数在编译时计算
constexpr int Factorial(int n) {
    return n <= 1 ? 1 : n * Factorial(n - 1);
}
```

### 分支预测

```cpp
// Good: 使用 [[likely]] 和 [[unlikely]] (C++20)
if (condition) [[likely]] {
    // 常见路径
} else {
    // 罕见路径
}

// Good: 避免分支
// Bad
int abs(int x) {
    return x < 0 ? -x : x;
}

// Good: 无分支版本
int abs(int x) {
    int mask = x >> 31;
    return (x + mask) ^ mask;
}
```

## 性能测量

### 使用 Benchmark

```cpp
#include <benchmark/benchmark.h>

static void BM_VectorPushBack(benchmark::State& state) {
    for (auto _ : state) {
        std::vector<int> vec;
        for (int i = 0; i < state.range(0); ++i) {
            vec.push_back(i);
        }
    }
}
BENCHMARK(BM_VectorPushBack)->Range(8, 8<<10);

static void BM_VectorReserve(benchmark::State& state) {
    for (auto _ : state) {
        std::vector<int> vec;
        vec.reserve(state.range(0));
        for (int i = 0; i < state.range(0); ++i) {
            vec.push_back(i);
        }
    }
}
BENCHMARK(BM_VectorReserve)->Range(8, 8<<10);
```

### Profiling

```bash
# 使用 perf 进行性能分析
perf record -g ./my_program
perf report

# 使用 valgrind 的 callgrind
valgrind --tool=callgrind ./my_program
kcachegrind callgrind.out.*
```

## 常见陷阱

### 过早优化

```cpp
// Bad: 过早优化，牺牲可读性
int sum = 0;
for (int i = 0; i < n; i += 4) {  // 循环展开
    sum += data[i] + data[i+1] + data[i+2] + data[i+3];
}

// Good: 清晰的代码，让编译器优化
int sum = 0;
for (int i = 0; i < n; ++i) {
    sum += data[i];
}
```

### 忽略编译器优化

```cpp
// 编译时使用优化选项
// -O2 或 -O3
// -march=native (针对当前 CPU 优化)
// -flto (链接时优化)
```

## 性能检查清单

- [ ] 热点路径避免不必要的拷贝
- [ ] 容器预分配内存
- [ ] 使用合适的数据结构
- [ ] 避免不必要的虚函数调用
- [ ] 减少锁竞争
- [ ] 使用 profiler 验证优化效果
- [ ] 编译时启用优化选项
