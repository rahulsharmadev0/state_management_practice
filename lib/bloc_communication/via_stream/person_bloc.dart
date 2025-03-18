import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'notepad_bloc.dart';
import 'stream_event_bus.dart';

// Events
sealed class PersonEvent {
  const PersonEvent();
}

class AddNote extends PersonEvent {
  final String note;
  const AddNote(this.note);
}

class RemoveNote extends PersonEvent {
  final int index;
  const RemoveNote(this.index);
}

class EditNote extends PersonEvent {
  final int index;
  final String note;
  const EditNote(this.index, this.note);
}

// State
abstract class PersonState {}

class PersonIdle extends PersonState {}

class PersonWriting extends PersonState {}

// Bloc
class PersonBloc extends Bloc<PersonEvent, PersonState> {
  final NotepadBloc notepadBloc; // Dependency Injection
  final Map<String, StreamSubscription> _subscriptions = {};

  PersonBloc(this.notepadBloc) : super(PersonIdle()) {
    // Register for reset/restart events
    registerEventHandlers();
  }

  void registerEventHandlers() {
    on<AddNote>(_handleAddNote);
    on<RemoveNote>(_handleRemoveNote);
    on<EditNote>(_handleEditNote);
  }

  Future<void> _handleAddNote(AddNote event, Emitter<PersonState> emit) async {
    emit(PersonWriting());

    var notepadEvent = NotepadEvent.add(event.note);
    final eventId = 'add-${DateTime.now().millisecondsSinceEpoch}';

    // Cancel any existing subscription for similar events
    await _cleanupSubscriptions();

    // Create a subscription to the notepad event with improved handling
    final subscription = notepadBloc.addEventListener(
      notepadEvent,
      (eventWrapper) async {
        print('Received event: ${eventWrapper.status} for ${eventWrapper.event.note}');

        if (eventWrapper.status == EventStatus.completed) {
          // Only handle completion once
          if (state is PersonWriting) {
            await Future.delayed(Duration(seconds: 1));
            emit(PersonIdle());
          }

          // Schedule cleanup for this subscription
          Future.delayed(Duration(milliseconds: 500), () {
            _subscriptions[eventId]?.cancel();
            _subscriptions.remove(eventId);
          });
        }
      },
      onError: (error) {
        print('Error in event listener: $error');
        emit(PersonIdle());

        // Clean up on error
        _subscriptions[eventId]?.cancel();
        _subscriptions.remove(eventId);
      },
    );

    // Store the subscription for later cleanup
    _subscriptions[eventId] = subscription;

    // Trigger the event in notepadBloc
    notepadBloc.add(notepadEvent);
  }

  void _handleRemoveNote(RemoveNote event, Emitter<PersonState> emit) {
    notepadBloc.add(NotepadEvent.remove(event.index));
  }

  void _handleEditNote(EditNote event, Emitter<PersonState> emit) {
    notepadBloc.add(NotepadEvent.edit(event.index, event.note));
  }

  /// Clean up stale subscriptions - important for restart/reload scenarios
  Future<void> _cleanupSubscriptions() async {
    final staleSubs = <String>[];

    // Find stale subscriptions
    for (final entry in _subscriptions.entries) {
      staleSubs.add(entry.key);
    }

    // Cancel stale subscriptions
    for (final key in staleSubs) {
      await _subscriptions[key]?.cancel();
      _subscriptions.remove(key);
    }
  }

  @override
  Future<void> close() async {
    // Cancel all active subscriptions
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    return super.close();
  }
}
