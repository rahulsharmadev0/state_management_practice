import 'package:bloc/bloc.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

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
          status == other.status &&
          error == other.error;

  @override
  int get hashCode => Object.hash(event, status);
}

/// An optimized EventBus mixin using RxDart's BehaviorSubject for better reactivity.
mixin _EventBus<K, Event> on BlocEventSink<Event> {
  // Map of BehaviorSubjects for each event key
  final Map<K, BehaviorSubject<EventWrapper<Event>>> _subjects = {};

  /// Gets or creates a BehaviorSubject for a specific key
  BehaviorSubject<EventWrapper<Event>> _getSubject(K key) {
    if (!_subjects.containsKey(key)) {
      _subjects[key] = BehaviorSubject<EventWrapper<Event>>();
    }
    return _subjects[key]!;
  }

  /// Adds a new event listener for a given key.
  /// Returns a subscription that can be used to cancel the listener.
  StreamSubscription<EventWrapper<Event>> addEventListener<X>(
    K key,
    void Function(EventWrapper<Event> eventWrapper) callback, {
    void Function(dynamic, StackTrace)? onError,
  }) {
    final subject = _getSubject(key);
    return subject.stream.listen(callback, onError: onError);
  }

  /// Removes all listeners for the given key and disposes the subject.
  void removeEventListeners(K key) {
    _subjects[key]?.close();
    _subjects.remove(key);
  }

  void _disposeEventBus() {
    for (final subject in _subjects.values) {
      subject.close();
    }
    _subjects.clear();
  }

  void _addEvent(K key, Event event, EventStatus status, {dynamic error}) {
    final wrapper = EventWrapper<Event>(event, status, error: error);
    _getSubject(key).add(wrapper);
  }

  bool get hasListeners => _subjects.isNotEmpty;

  bool get hasActiveListeners => _subjects.values.any((subject) => subject.hasListener);

  int get totalListeners => _subjects.length;

  List<K> get activeEvents => _subjects.keys.toList();

  bool hasListenersForEvent(K key) => _subjects.containsKey(key);
}

/// {@template LifecycleBloc}
/// # LifecycleBloc 🏗️
///
/// A specialized [Bloc] that enhances event lifecycle tracking in a reactive and decoupled way.
///
/// This class extends the standard `Bloc` by introducing automatic **event lifecycle tracking**.
/// Each event processed by the bloc goes through distinct phases:
///
/// - ✅ **started** – The event has been received and is being processed.
/// - ✅ **success** – The event has been processed successfully.
/// - ✅ **error** – An error occurred while handling the event.
/// - ✅ **completed** – The event lifecycle has concluded, whether successful or not.
///
/// ## 🔥 **Best Use Cases**
/// - **Bloc-to-Bloc communication** (event lifecycle tracking with less tight coupling).
/// - **Multi-step workflows** like authentication, payments, or file uploads.
/// - **Background processes** that require real-time UI updates.
/// - **Real-time event-driven systems** like chat apps, stock price updates, or notification handlers.
///
/// **Note:** Generally, sibling dependencies between two entities in the same architectural layer should be avoided due to hard maintain.🫡
///
/// {@endtemplate}
abstract class LifecycleBloc<Event, State> extends Bloc<Event, State>
    with _EventBus<Event, Event> {
  LifecycleBloc(super.initialState);

  EventTransformer<E> _lifecycleTransformer<E extends Event>() {
    return (events, mapper) => events.asyncExpand((event) async* {
      // Notify that event processing is starting.
      _addEvent(event, event, EventStatus.started);
      try {
        await for (final state in mapper(event)) {
          yield state;
        }
        // Notify that event processing succeeded.
        _addEvent(event, event, EventStatus.success);
      } catch (error) {
        // Notify that event processing encountered an error.
        _addEvent(event, event, EventStatus.error, error: error);
        rethrow;
      } finally {
        // Notify that event processing is complete.
        _addEvent(event, event, EventStatus.completed);
      }
    });
  }

  /// Overrides [on] to integrate the lifecycle transformer.
  ///
  /// This method ensures that all event handlers automatically benefit from
  /// lifecycle tracking while still allowing custom transformers to be used.
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
    _disposeEventBus();
    return super.close();
  }
}
