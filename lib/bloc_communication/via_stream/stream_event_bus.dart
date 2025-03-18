import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  @override
  String toString() => 'EventWrapper(event: $event, status: $status, error: $error)';
}

/// A stream-based event bus that holds the last event for each key
class StreamEventBus<K, Event> {
  final Map<K, StreamController<EventWrapper<Event>>> _controllers = {};
  final Map<K, EventWrapper<Event>> _lastEvents = {};

  // Track all emissions to avoid duplicates
  final Set<EventWrapper<Event>> _recentEmissions = {};

  /// Get or create a stream controller for a specific key
  StreamController<EventWrapper<Event>> _getController(K key) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = StreamController<EventWrapper<Event>>.broadcast();
    }
    return _controllers[key]!;
  }

  /// Add a listener for a specific event key
  StreamSubscription<EventWrapper<Event>> listen(
    K key,
    void Function(EventWrapper<Event>) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final controller = _getController(key);
    final subscription = controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );

    // Send the last event to the new subscriber if available
    if (_lastEvents.containsKey(key)) {
      final lastEvent = _lastEvents[key]!;
      // Don't send 'started' events for late subscribers
      if (lastEvent.status != EventStatus.started) {
        Future.microtask(() => onData(lastEvent));
      }
    }

    return subscription;
  }

  /// Emit a new event with a specific status
  void emit(K key, Event event, EventStatus status, {dynamic error}) {
    final wrapper = EventWrapper<Event>(event, status, error: error);

    // Only store the last event for non-intermediate statuses
    // For completed events, we may want to clear the last event
    if (status == EventStatus.completed) {
      // Optional: remove the last event for completed events
      // _lastEvents.remove(key);

      // Or update it to show it's completed
      _lastEvents[key] = wrapper;
    } else if (status != EventStatus.started) {
      // Don't store intermediate statuses like 'started'
      _lastEvents[key] = wrapper;
    }

    // Check for duplicate emissions in quick succession
    if (_recentEmissions.contains(wrapper)) {
      print('Duplicate event emission avoided: $wrapper');
      return;
    }

    // Add to recent emissions
    _recentEmissions.add(wrapper);

    // Schedule cleanup of recent emissions set
    Future.delayed(Duration(milliseconds: 100), () {
      _recentEmissions.remove(wrapper);
    });

    if (_controllers.containsKey(key)) {
      _controllers[key]!.add(wrapper);
    }
  }

  /// Clear all cached events but keep streams active
  void clearCache() {
    _lastEvents.clear();
    _recentEmissions.clear();
    print('StreamEventBus: Cleared all cached events');
  }

  /// Check if a key has any active listeners
  bool hasListeners(K key) {
    return _controllers.containsKey(key) &&
        !_controllers[key]!.isClosed &&
        _controllers[key]!.hasListener;
  }

  /// Close all controllers
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _lastEvents.clear();
    _recentEmissions.clear();
  }

  /// Close a specific controller
  void closeStream(K key) {
    if (_controllers.containsKey(key)) {
      _controllers[key]!.close();
      _controllers.remove(key);
      _lastEvents.remove(key);
    }
  }
}

/// A BLoC that integrates the StreamEventBus for lifecycle event notifications.
abstract class StreamLifeCycleBloc<Event, State> extends Bloc<Event, State> {
  final StreamEventBus<Event, Event> _eventBus = StreamEventBus<Event, Event>();
  final Map<Event, Set<StreamSubscription<EventWrapper<Event>>>> _activeSubscriptions =
      {};

  StreamLifeCycleBloc(super.initialState);

  /// Listen to events of a specific type
  StreamSubscription<EventWrapper<Event>> addEventListener(
    Event key,
    void Function(EventWrapper<Event>) callback, {
    Function? onError,
  }) {
    final subscription = _eventBus.listen(key, callback, onError: onError);

    // Track subscriptions for cleanup
    _activeSubscriptions.putIfAbsent(key, () => {}).add(subscription);

    return subscription;
  }

  /// Remove a specific event listener
  void removeEventListener(
    Event key,
    StreamSubscription<EventWrapper<Event>> subscription,
  ) {
    subscription.cancel();
    _activeSubscriptions[key]?.remove(subscription);
    if (_activeSubscriptions[key]?.isEmpty ?? false) {
      _activeSubscriptions.remove(key);
    }
  }

  /// Stop listening to events of a specific type
  void removeEventListeners(Event key) {
    // Cancel all subscriptions for this key
    if (_activeSubscriptions.containsKey(key)) {
      for (final subscription in _activeSubscriptions[key]!) {
        subscription.cancel();
      }
      _activeSubscriptions.remove(key);
    }

    _eventBus.closeStream(key);
  }

  /// Clear all event history but keep streams active
  void resetEventBus() {
    _eventBus.clearCache();
  }

  /// A transformer that wraps event processing with lifecycle callbacks.
  EventTransformer<E> _lifecycleTransformer<E extends Event>() {
    return (events, mapper) => events.asyncExpand((event) async* {
      try {
        // Notify that event processing is starting
        _eventBus.emit(event, event, EventStatus.started);

        // Use a debounce to avoid rapid emissions of the same event
        bool hasYieldedState = false;

        await for (final state in mapper(event)) {
          hasYieldedState = true;
          yield state;
        }

        // Notify that event processing succeeded
        _eventBus.emit(event, event, EventStatus.success);
      } catch (error) {
        // Notify that event processing encountered an error
        _eventBus.emit(event, event, EventStatus.error, error: error);
        rethrow;
      } finally {
        // Add a small delay before emitting completion to avoid rapid succession emissions
        await Future.delayed(Duration(milliseconds: 50));

        // Notify that event processing is complete
        _eventBus.emit(event, event, EventStatus.completed);
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
        // Combine custom transformer with the lifecycle transformer
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
    // Cancel all tracked subscriptions
    for (final key in _activeSubscriptions.keys) {
      for (final subscription in _activeSubscriptions[key]!) {
        await subscription.cancel();
      }
    }
    _activeSubscriptions.clear();

    _eventBus.dispose();
    return super.close();
  }
}
