import 'package:flutter/material.dart';

//---------------------------
// Globle Widget Unique Keys
//---------------------------
final addTodoKey = UniqueKey();
final activeFilterKey = UniqueKey();
final completedFilterKey = UniqueKey();
final allFilterKey = UniqueKey();

enum TodoListFilter { all, active, completed }

@immutable
class Todo {
  const Todo({required this.description, required this.id, this.completed = false});

  final String id;
  final String description;
  final bool completed;

  @override
  String toString() {
    return 'Todo(description: $description, completed: $completed)';
  }

  // Suggested code may be subject to a license. Learn more: ~LicenseLog:3411353701.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo &&
        other.id == id &&
        other.description == description &&
        other.completed == completed;
  }

  @override
  int get hashCode => id.hashCode ^ description.hashCode ^ completed.hashCode;

  Todo copyWith({String? id, String? description, bool? completed}) {
    return Todo(
      id: id ?? this.id,
      description: description ?? this.description,
      completed: completed ?? this.completed,
    );
  }
}

//-----Common Widget

class TitleWidget extends StatelessWidget {
  const TitleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'todos',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color.fromARGB(38, 47, 47, 247),
        fontSize: 100,
        fontWeight: FontWeight.w100,
        fontFamily: 'Helvetica Neue',
      ),
    );
  }
}

class FilterRow extends StatelessWidget {
  final VoidCallback onAll;
  final VoidCallback onActive;
  final VoidCallback onCompleted;
  final TodoListFilter activeFilter;
  const FilterRow({
    super.key,
    required this.onActive,
    required this.onAll,
    required this.onCompleted,
    required this.activeFilter,
  });

  Color? textColorFor(TodoListFilter value) =>
      activeFilter == value ? Colors.blue : Colors.black;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          key: allFilterKey,
          message: 'All todos',
          child: TextButton(
            onPressed: onAll,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.all(textColorFor(TodoListFilter.all)),
            ),
            child: const Text('All'),
          ),
        ),
        Tooltip(
          key: activeFilterKey,
          message: 'Only uncompleted todos',
          child: TextButton(
            onPressed: () => onActive,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.all(
                textColorFor(TodoListFilter.active),
              ),
            ),
            child: const Text('Active'),
          ),
        ),
        Tooltip(
          key: completedFilterKey,
          message: 'Only completed todos',
          child: TextButton(
            onPressed: onCompleted,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.all(
                textColorFor(TodoListFilter.completed),
              ),
            ),
            child: const Text('Completed'),
          ),
        ),
      ],
    );
  }
}
