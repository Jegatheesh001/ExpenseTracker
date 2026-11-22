import 'dart:async';

/// Serializes recovery and all wallet writers within the application isolate.
class WalletWriteQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() operation) async {
    final previous = _tail;
    final finished = Completer<void>();
    _tail = finished.future;
    await previous;
    try {
      return await operation();
    } finally {
      finished.complete();
    }
  }
}
