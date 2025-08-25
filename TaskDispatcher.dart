import 'dart:async';
import 'dart:isolate';
import 'dart:collection';

/// TaskDispatcher 是一个单例类，用于管理一个 Isolate 池，以实现任务的并行处理。
/// 它通过 Isolate 池复用的方式来分发任务，从而减少频繁创建和销毁 Isolate 的性能开销。
///
/// 使用步骤：
/// 1. 使用 `TaskDispatcher().initializePool()` 方法初始化 Isolate 池，
///    通过设置 `poolSize` 来控制池内的 Isolate 数量（默认为3）。
///    该方法可多次调用来动态调整池大小。
///
/// 2. 使用 `dispatchTask` 方法提交任务，该方法接受一个闭包形式的任务函数，
///    以及一个可选的 `onComplete` 回调。任务完成后会执行回调，并将结果传入。
///
/// 3. `dispatchTask` 方法会自动将任务分发给空闲的 IsolateHandler（池内的 Isolate）。
///    如果所有 Isolate 都在忙碌，任务会进入队列等待，直到有空闲的 Isolate 可用。
///
/// 类结构说明：
/// - `TaskDispatcher`：任务管理器，负责 Isolate 池的初始化和任务调度。
/// - `IsolateHandler`：单个 Isolate 的管理类，负责实际任务的执行及状态管理。
/// - `Task`：封装任务内容及完成回调的辅助类。
///
/// 闭包回调方式示例用法：
///
/// ```dart
/// void main() {
///   // 初始化池，设置大小为 5 / Initialize the pool of isolates of a dispatcher
///   TaskDispatcher().initializePool(poolSize: 5);
///
///   // 提交任务 / dispatchTask
///   TaskDispatcher().dispatchTask(() async {
///     await Future.delayed(Duration(seconds: 2));
///     return '任务完成';
///   }, onComplete: (result) {
///     print(result); // 输出 '任务完成'
///   });
/// }
/// ```
///
/// 该类的设计目的是在 Dart 中高效利用Isolate来模拟其他语言中的多线程和线程池，适合需要并发处理的任务调度场景，避免Isolate反复创建反复销毁降低性能
/// 也避免了使用后台执行任务的时候需要手动创建Isolate并相应后续操作的麻烦。
///
/// async/await用法，示例用法：
///     final result = await dispatcher.dispatch<int>(() async {
///       await Future.delayed(Duration(seconds: 1));
///       return 42; // 返回任务结果
///     });
///     print("Task result: $result"); // 应输出: Task result: 42

class TaskDispatcher {
  static final TaskDispatcher _instance = TaskDispatcher._internal();

  int poolSize = 3;

  factory TaskDispatcher() {
    return _instance;
  }

  TaskDispatcher._internal() {
    // 如果池还未初始化，则使用默认 poolSize 3
    if (_isolateHandlers.isEmpty) {
      initializePool(poolSize: poolSize);
    }
  }

  final List<IsolateHandler> _isolateHandlers = [];
  final Queue<Task> _taskQueue = Queue();

  void initializePool({int? poolSize}) {
    if (poolSize != null) {
      this.poolSize = poolSize;
    }

    // 调整池大小
    if (_isolateHandlers.length < this.poolSize) {
      // 添加新的 IsolateHandler
      for (int i = _isolateHandlers.length; i < this.poolSize; i++) {
        _isolateHandlers.add(IsolateHandler());
      }
    } else if (_isolateHandlers.length > this.poolSize) {
      // 移除多余的 IsolateHandler
      for (int i = _isolateHandlers.length - 1; i >= this.poolSize; i--) {
        _isolateHandlers[i].dispose();
        _isolateHandlers.removeAt(i);
      }
    }
  }

  Future<T> dispatch<T>(Future<T> Function() task) async {
    final completer = Completer<T>();
    final handler = _isolateHandlers.firstWhere((h) => !h.isBusy, orElse: () => _isolateHandlers[0]);
    handler.executeTask(Task(task, (result) {
      completer.complete(result);
    }));
    return completer.future;
  }

  void dispatchTask<T>(Future<T> Function() task, {void Function(T)? onComplete}) {
    final IsolateHandler? isolateHandler = _getIdleIsolateHandler();

    if (isolateHandler != null) {
      // 存在空闲的hanlder立即执行任务
      isolateHandler.executeTask(Task(task, (result) {
        if (onComplete != null) {
          onComplete(result);
        }
      }));
    } else {
      // 所有 Isolate 正在忙，将任务添加到队列中
      _taskQueue.add(Task(task, (result) {
        if (onComplete != null) {
          onComplete(result);
        }
      }));
    }
  }

  void _checkQueue() {
    if (_taskQueue.isEmpty) return;

    final IsolateHandler? idleHandler = _getIdleIsolateHandler();
    if (idleHandler != null && _taskQueue.isNotEmpty) {
      // 将队列中的任务派发给空闲的 Isolate
      idleHandler.executeTask(_taskQueue.removeFirst());
    }
  }

  IsolateHandler? _getIdleIsolateHandler() {
    for (final handler in _isolateHandlers) {
      if (!handler.isBusy) {
        return handler;
      }
    }
    return null;  // 如果没有空闲的 handler，返回 null
  }

}

class IsolateHandler {
  late final Isolate _isolate;
  late final Completer<SendPort> _sendPortCompleter;
  bool isBusy = false;

  IsolateHandler() {
    _sendPortCompleter = Completer<SendPort>();
    _init();
  }

  Future<void> _init() async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_entryPoint, receivePort.sendPort);
    // 从 receivePort 获取 SendPort 并完成 _sendPortCompleter
    receivePort.listen((message) {
      if (message is SendPort) {
        _sendPortCompleter.complete(message);
        receivePort.close(); // 获取到 SendPort 后关闭 receivePort
      }
    });
  }

  static void _entryPoint(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      final task = message[0] as Future Function();
      final resultPort = message[1] as SendPort;
      final result = await task();
      resultPort.send(result);
    });
  }

  Future<void> executeTask(Task task) async {
    final sendPort = await _sendPortCompleter.future;
    isBusy = true;

    final resultPort = ReceivePort();
    sendPort.send([task.task, resultPort.sendPort]);

    resultPort.listen((result) {
      task.onComplete(result);
      isBusy = false;
      resultPort.close();
    });
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
  }
}

class Task<T> {
  final Future<T> Function() task;
  final void Function(dynamic) onComplete;

  Task(this.task, this.onComplete);
}
