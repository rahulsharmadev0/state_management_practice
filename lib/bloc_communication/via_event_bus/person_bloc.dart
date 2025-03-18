import 'package:flutter_bloc/flutter_bloc.dart';
import 'notepad_bloc.dart';

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

  PersonBloc(this.notepadBloc) : super(PersonIdle()) {
    on<AddNote>((event, emit) {
      var notepadEvent = NotepadEvent.add(event.note);

      // Listen to the notepadBloc for the event
      callback(event) async {
        await Future.delayed(Duration(seconds: 1));
        emit(PersonIdle());
        notepadBloc.removeEventListeners(notepadEvent);
      }

      notepadBloc.addEventListener(notepadEvent, callback);

      notepadBloc.add(notepadEvent); // Trigger the event
    });
    on<RemoveNote>((event, emit) {
      notepadBloc.add(NotepadEvent.remove(event.index));
    });
    on<EditNote>((event, emit) {
      notepadBloc.add(NotepadEvent.edit(event.index, event.note));
    });
  }
}
