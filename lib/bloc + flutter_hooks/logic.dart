import 'package:flutter_bloc/flutter_bloc.dart';
import '../common.dart';
import 'package:uuid/uuid.dart';

typedef TodosState = ({List<Todo> todos, TodoListFilter filter});

class TodosCubit extends Cubit<TodosState> {
  final _uuid = const Uuid();
  TodoListFilter get filter => state.filter;
  List<Todo> get todos => state.todos;

  int get uncomplete => todos.where((todo) => !todo.completed).length;

  List<Todo> get filteredTodos => switch (filter) {
    TodoListFilter.completed => todos.where((todo) => todo.completed).toList(),
    TodoListFilter.active => todos.where((todo) => !todo.completed).toList(),
    TodoListFilter.all => todos,
  };

  TodosCubit()
    : super((
        todos: [
          const Todo(id: 'todo-0', description: 'Buy cookies'),
          const Todo(id: 'todo-1', description: 'Star Riverpod'),
          const Todo(id: 'todo-2', description: 'Have a walk'),
        ],
        filter: TodoListFilter.all,
      ));

  void setFilter(TodoListFilter filter) => emitCW(filter: filter);

  void add(String description) {
    emitCW(todos: [...state.todos, Todo(id: _uuid.v4(), description: description)]);
  }

  void toggle(String id) {
    emitCW(
      todos:
          state.todos
              .map((o) => o.id == id ? o.copyWith(completed: !o.completed) : o)
              .toList(),
    );
  }

  void edit({required String id, required String description}) {
    emitCW(
      todos:
          state.todos
              .map((o) => o.id == id ? o.copyWith(description: description) : o)
              .toList(),
    );
  }

  void remove(Todo target) {
    emitCW(todos: state.todos.where((todo) => todo.id != target.id).toList());
  }

  void emitCW({List<Todo>? todos, TodoListFilter? filter}) {
    emit((todos: todos ?? state.todos, filter: filter ?? state.filter));
  }
}
