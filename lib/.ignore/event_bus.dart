import 'package:flutter/foundation.dart';

class EventBus<T> {
  final String key = UniqueKey().toString();
  final Map<String, List<CallbackData<T>>> _subscribers = {};
  T? lastValue;

  /// Emits a new value to subscribers. Skips if the value is unchanged.
  void emit(T value) {
    if (lastValue == value) return; // Skip if previous value is the same.
    lastValue = value;

    final subscribers = _subscribers[key];
    if (subscribers == null || subscribers.isEmpty) return;

    for (var subscriber in subscribers) {
      try {
        subscriber.callback(value);
      } catch (e) {
        subscriber.onError?.call(e);
      }
    }
  }

  /// Subscribes to the stream and returns a function to cancel the subscription.
  Function() addListener(Function(T value) callback, {Function(dynamic)? onError}) {
    final callbackData = CallbackData(callback, onError);
    _subscribers.putIfAbsent(key, () => []).add(callbackData);

    // Immediately push the last value to the new subscriber if available.
    if (lastValue != null) {
      try {
        callback(lastValue as T);
      } catch (e) {
        onError?.call(e);
      }
    }

    return () => _subscribers[key]?.remove(callbackData);
  }

  /// Unsubscribes all listeners from this stream.
  void dispose() => _subscribers.remove(key);
}

/// Holds callback and optional error handler.
class CallbackData<T> {
  final Function(T) callback;
  final Function(dynamic)? onError;

  CallbackData(this.callback, this.onError);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallbackData<T> &&
          runtimeType == other.runtimeType &&
          callback == other.callback;

  @override
  int get hashCode => callback.hashCode;
}

void main(List<String> args) {
  final event = EventBus<int>();

  void person1(int value) {
    print('Person 1 received: ${value + 1}');
  }

  void person2(int value) {
    print('Person 1 received: ${value + 3}');
  }

  void person3(int value) {
    print('Person 1 received: ${value + 4}');
  }

  void person4(int value) {
    print('Person 1 received: ${value + 5}');
  }

  event.addListener(person1);
  event.addListener(person2);

  event.emit(1);
  event.emit(2);
  event.emit(3);

  event.addListener(person3);
  event.addListener(person4);

  event.emit(10);
  event.emit(20);

  event.dispose();
}
