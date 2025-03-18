import 'package:flutter_bloc/flutter_bloc.dart';
import 'stream_event_bus.dart';

// Events
enum _NotepadEvent { add, remove, edit }

class NotepadEvent {
  final int? index;
  final String? note;
  final _NotepadEvent type;

  NotepadEvent.add(String this.note) : type = _NotepadEvent.add, index = null;
  NotepadEvent.remove(int this.index) : type = _NotepadEvent.remove, note = null;
  NotepadEvent.edit(int this.index, this.note) : type = _NotepadEvent.edit;
}

typedef NotepadState = List<String>;

// Bloc
class NotepadBloc extends StreamLifeCycleBloc<NotepadEvent, List<String>> {
  NotepadBloc() : super([]) {
    on<NotepadEvent>((event, emit) {
      NotepadState newState = switch (event.type) {
        _NotepadEvent.add => state..add(event.note!),
        _NotepadEvent.remove => state..removeAt(event.index!),
        _NotepadEvent.edit => state..[event.index!] = event.note!,
      };
      emit(newState);
    });
  }
}
