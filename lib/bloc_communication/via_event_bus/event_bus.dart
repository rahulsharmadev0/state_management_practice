import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Represents a callback with an optional error handler.
class CallbackData<T> {
  final void Function(T) callback;
  final void Function(dynamic)? onError;

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

/// A generic store for subscribers keyed by K.
class CallbackDataStore<K, Data extends CallbackData> {
  final Map<K, List<Data>> _subscribers = {};

  /// Dispose all subscribers for a given key.
  void dispose(K key) => _subscribers.remove(key);

  /// Dispose all subscribers in the store.
  void disposeAll() => _subscribers.clear();

  /// Add a subscriber for the given key.
  void add(K key, Data data) => _subscribers.putIfAbsent(key, () => []).add(data);

  /// Remove a specific subscriber.
  void remove(K key, Data data) => _subscribers[key]?.remove(data);

  /// Notify all subscribers for the given key.
  void notify(K key, void Function(Data) notifyCallback) {
    final subscribers = _subscribers[key];
    if (subscribers == null || subscribers.isEmpty) return;
    // Iterate over a copy in case the list is modified during iteration.
    for (final subscriber in List<Data>.from(subscribers)) {
      notifyCallback(subscriber);
    }
  }
}

/// Represents the lifecycle status of an event.
enum EventStatus { started, success, error, completed }

/// A wrapper that holds an event along with its lifecycle status and error (if any).
class EventWrapper<T> {
  final T event;
  final EventStatus status;
  final dynamic error;

  const EventWrapper(this.event, this.status, {this.error});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventWrapper<T> &&
          runtimeType == other.runtimeType &&
          event == other.event &&
          status == other.status;

  @override
  int get hashCode => Object.hash(event, status);
}

/// An optimized EventBus mixin that provides lifecycle-aware event emission.
mixin EventBus<K, Event> on BlocEventSink<Event> {
  final CallbackDataStore<K, CallbackData<EventWrapper<Event>>> _subscribers =
      CallbackDataStore<K, CallbackData<EventWrapper<Event>>>();

  EventWrapper<Event>? _lastEvent;

  /// Emits a wrapped event with a lifecycle status.
  void _emitEvent(K key, EventWrapper<Event> wrapper) {
    // Optionally, skip duplicate notifications for the same event/status.
    if (_lastEvent != null &&
        _lastEvent!.event == wrapper.event &&
        _lastEvent!.status == wrapper.status) {
      return;
    }
    _lastEvent = wrapper;
    _subscribers.notify(key, (subscriber) {
      try {
        subscriber.callback(wrapper);
      } catch (e) {
        subscriber.onError?.call(e);
      }
    });
  }

  /// Adds a new event listener for a given key.
  void addEventListener(
    K key,
    void Function(EventWrapper<Event> eventWrapper) callback, {
    void Function(dynamic)? onError,
  }) {
    final callbackData = CallbackData<EventWrapper<Event>>(callback, onError);
    _subscribers.add(key, callbackData);

    // Immediately notify the new listener with the last event if available.
    if (_lastEvent != null) {
      try {
        callback(_lastEvent!);
      } catch (e) {
        onError?.call(e);
      }
    }
  }

  /// Removes all listeners for the given key.
  void removeEventListeners(K key) => _subscribers.dispose(key);

  /// Disposes all event listeners.
  @protected
  void disposeEventBus() => _subscribers.disposeAll();

  /// Public method to add an event notification with a lifecycle status.
  void addEvent(K key, Event event, EventStatus status, {dynamic error}) {
    final wrapper = EventWrapper<Event>(event, status, error: error);
    _emitEvent(key, wrapper);
  }
}

/// A BLoC that integrates the EventBus for lifecycle event notifications.
abstract class EventLifeCycleBloc<Event, State> extends Bloc<Event, State>
    with EventBus<Event, Event> {
  EventLifeCycleBloc(super.initialState);

  /// A transformer that wraps event processing with lifecycle callbacks.
  EventTransformer<E> _lifecycleTransformer<E extends Event>() {
    return (events, mapper) => events.asyncExpand((event) async* {
      // Notify that event processing is starting.
      addEvent(event, event, EventStatus.started);
      try {
        await for (final state in mapper(event)) {
          yield state;
        }
        // Notify that event processing succeeded.
        addEvent(event, event, EventStatus.success);
      } catch (error) {
        // Notify that event processing encountered an error.
        addEvent(event, event, EventStatus.error, error: error);
        rethrow;
      } finally {
        // Notify that event processing is complete.
        addEvent(event, event, EventStatus.completed);
      }
    });
  }

  /// Overrides [on] to integrate the lifecycle transformer.
  @override
  void on<E extends Event>(
    EventHandler<E, State> handler, {
    EventTransformer<E>? transformer,
  }) {
    Stream<E> combinedTransformer(events, mapper) {
      final lifecycleTransformed = _lifecycleTransformer<E>();
      if (transformer != null) {
        // Combine custom transformer with the lifecycle transformer.
        return transformer(
          events,
          (event) => lifecycleTransformed(Stream.value(event), mapper),
        );
      }
      return lifecycleTransformed(events, mapper);
    }

    super.on<E>(handler, transformer: combinedTransformer);
  }

  @override
  Future<void> close() async {
    disposeEventBus();
    return super.close();
  }
}
