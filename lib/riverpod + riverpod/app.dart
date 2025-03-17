import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../common.dart';
import 'logic.dart';

//---------------------------
// Notifier Provider
//--------------------------
final todoListProvider = NotifierProvider<TodoList, List<Todo>>(
  TodoList.new,
); //For Complex
final todoListFilter = StateProvider((_) => TodoListFilter.all); // For Single State
final _currentTodo = Provider<Todo>((ref) => throw UnimplementedError()); // Only For Read
final uncompletedTodosCount = Provider<int>(
  (ref) =>
      ref
          .watch(todoListProvider)
          .where((todo) => !todo.completed)
          .length, // Only For Read
);

final filteredTodos = Provider<List<Todo>>((ref) {
  // Only For Read
  final filter = ref.watch(todoListFilter);
  final todos = ref.watch(todoListProvider);
  return switch (filter) {
    TodoListFilter.completed => todos.where((todo) => todo.completed).toList(),
    TodoListFilter.active => todos.where((todo) => !todo.completed).toList(),
    TodoListFilter.all => todos,
  };
});

void main() => runApp(const ProviderScope(child: MaterialApp(home: Home())));

class Home extends HookConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(filteredTodos);
    final newTodoController = useTextEditingController();
    print("Home");
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          children: [
            const TitleWidget(),
            TextField(
              key: addTodoKey,
              controller: newTodoController,
              decoration: const InputDecoration(labelText: 'What needs to be done?'),
              onSubmitted: (value) {
                ref.read(todoListProvider.notifier).add(value);
                newTodoController.clear();
              },
            ),
            const SizedBox(height: 42),
            const Toolbar(),
            if (todos.isNotEmpty) const Divider(height: 0),
            for (var i = 0; i < todos.length; i++) ...[
              if (i > 0) const Divider(height: 0),
              Dismissible(
                key: ValueKey(todos[i].id),
                onDismissed: (_) {
                  ref.read(todoListProvider.notifier).remove(todos[i]);
                },
                child: ProviderScope(
                  overrides: [_currentTodo.overrideWithValue(todos[i])],
                  child: const TodoItem(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class Toolbar extends HookConsumerWidget {
  const Toolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print("build: Toolbar");
    return Material(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${ref.watch(uncompletedTodosCount)} items left',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilterRow(
            onAll: () => ref.read(todoListFilter.notifier).state = TodoListFilter.all,
            onActive:
                () => ref.read(todoListFilter.notifier).state = TodoListFilter.active,
            onCompleted:
                () => ref.read(todoListFilter.notifier).state = TodoListFilter.completed,
            activeFilter: ref.watch(todoListFilter),
          ),
        ],
      ),
    );
  }
}

class TodoItem extends HookConsumerWidget {
  const TodoItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todo = ref.watch(_currentTodo);
    final itemFocusNode = useFocusNode();
    final itemIsFocused = useIsFocused(itemFocusNode);
    final textEditingController = useTextEditingController();
    final textFieldFocusNode = useFocusNode();
    print("build: TodoItem(${todo.id})");
    return Material(
      color: Colors.white,
      elevation: 6,
      child: Focus(
        focusNode: itemFocusNode,
        onFocusChange: (focused) {
          if (focused) {
            textEditingController.text = todo.description;
          } else {
            // Commit changes only when the textfield is unfocused, for performance
            ref
                .read(todoListProvider.notifier)
                .edit(id: todo.id, description: textEditingController.text);
          }
        },
        child: ListTile(
          onTap: () {
            itemFocusNode.requestFocus();
            textFieldFocusNode.requestFocus();
          },
          leading: Checkbox(
            value: todo.completed,
            onChanged: (value) => ref.read(todoListProvider.notifier).toggle(todo.id),
          ),
          title:
              itemIsFocused
                  ? TextField(
                    autofocus: true,
                    focusNode: textFieldFocusNode,
                    controller: textEditingController,
                  )
                  : Text(todo.description),
        ),
      ),
    );
  }
}

bool useIsFocused(FocusNode node) {
  final isFocused = useState(node.hasFocus);

  useEffect(() {
    void listener() {
      isFocused.value = node.hasFocus;
    }

    node.addListener(listener);
    return () => node.removeListener(listener);
  }, [node]);

  return isFocused.value;
}
