# TaskDispatcher

**中文 | English**

## 📌 简介 / Introduction

`TaskDispatcher` 是一个 **单例类**，用于管理一个 **Isolate 池**，以实现任务的并行处理。  
`TaskDispatcher` is a **singleton class** that manages an **Isolate pool** to achieve parallel task execution.  

它通过 **Isolate 池复用** 的方式来分发任务，减少频繁创建和销毁 Isolate 的性能开销。  
It dispatches tasks by **reusing isolates from the pool**, avoiding the overhead of frequent isolate creation and destruction.  

---

## 🚀 使用步骤 / Usage Steps

### 1. 初始化 Isolate 池 / Initialize the Isolate Pool

使用 `TaskDispatcher().initializePool()` 方法初始化池。  
Use `TaskDispatcher().initializePool()` to initialize the pool.  

通过设置 `poolSize` 控制池内 Isolate 数量（默认为 3）。  
You can specify `poolSize` to control the number of isolates in the pool (default is 3).  

该方法可多次调用，动态调整池大小。  
This method can be called multiple times to dynamically adjust the pool size.  

---

### 2. 提交任务 / Dispatch Tasks

使用 `dispatchTask` 提交任务，该方法接受一个闭包任务函数和一个可选的 `onComplete` 回调。  
Use `dispatchTask` to submit tasks. It accepts a task function (closure) and an optional `onComplete` callback.  

任务完成后会执行回调，并将结果传入。  
The callback will be executed once the task completes, with the result passed in.  

---

### 3. 自动任务调度 / Automatic Scheduling

`dispatchTask` 会自动将任务分发给空闲的 IsolateHandler。  
`dispatchTask` automatically assigns tasks to an available `IsolateHandler`.  

如果所有 Isolate 忙碌，任务会进入队列，直到有空闲的 Isolate。  
If all isolates are busy, the task will be queued until one becomes available.  

---

## 🏗 类结构说明 / Class Structure

- **TaskDispatcher**  
  任务管理器，负责 Isolate 池的初始化和任务调度。  
  The task manager, responsible for pool initialization and task scheduling.  

- **IsolateHandler**  
  单个 Isolate 的管理类，负责实际任务执行和状态管理。  
  A manager for a single isolate, responsible for executing tasks and managing state.  

- **Task**  
  封装任务内容及完成回调的辅助类。  
  A helper class that encapsulates the task logic and completion callback.  

---

## 📖 示例 / Examples

### 闭包回调方式 / Callback-based usage

```dart
void main() {
  // 初始化池，大小为 5 / Initialize the pool with size 5
  TaskDispatcher().initializePool(poolSize: 5);

  // 提交任务 / Dispatch a task
  TaskDispatcher().dispatchTask(() async {
    // 模拟一个耗时任务 / Simulate a time-consuming task
    await Future.delayed(Duration(seconds: 2));
    return '任务完成'; // Task finished
  }, onComplete: (result) {
    print(result); // 输出 '任务完成' / Prints '任务完成'
  });
}
```

---

### async/await 方式 / async/await usage

```dart
void main() async {
  final dispatcher = TaskDispatcher();
  dispatcher.initializePool(poolSize: 3);

  final result = await dispatcher.dispatch<int>(() async {
    // 模拟一个耗时任务 / Simulate a time-consuming task
    await Future.delayed(Duration(seconds: 1));
    return 42; // 返回任务结果 / Return task result
  });

  print("Task result: $result"); 
  // 输出: Task result: 42 
  // Prints: Task result: 42
}
```

---

## 🎯 设计目的 / Purpose

该类的设计目的是：  
The purpose of this class is to:  

- 在 Dart 中高效利用 Isolate 来模拟多线程和线程池。  
  Efficiently utilize Isolates in Dart to simulate multithreading and thread pools.  

- 适合需要并发处理的任务场景，避免 Isolate 反复创建销毁降低性能。  
  Suitable for concurrency-heavy tasks, avoiding the cost of repeatedly creating/destroying isolates.  

- 简化后台任务执行，不再需要手动管理 Isolate 生命周期。  
  Simplify background task execution by removing the need to manually manage isolate lifecycles.  

---

## 📦 安装 / Installation

```yaml
dependencies:
  task_dispatcher:
    git:
      url: https://github.com/yourname/task_dispatcher.git
```

---

## 🔖 License

MIT License. See [LICENSE](LICENSE) for details.  
