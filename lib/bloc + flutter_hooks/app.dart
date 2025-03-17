import 'package:bloc_suite/bloc_suite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../bloc/logic.dart';
import '../common.dart';

void main() => runApp(
  MaterialApp(home: BlocProvider(create: (_) => TodosCubit(), child: const Home())),
);

class Home extends HookWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final newTodoController = useTextEditingController();
    final todos = context.watch<TodosCubit>().filteredTodos;
    final f = context.read<TodosCubit>();

    print('Build: Home');
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
                f.add(value);
                newTodoController.clear();
              },
            ),
            const SizedBox(height: 42),
            Toolbar(),
            if (todos.isNotEmpty) const Divider(height: 0),
            for (var i = 0; i < todos.length; i++) ...[
              if (i > 0) const Divider(height: 0),
              Dismissible(
                key: ValueKey(todos[i].id),
                onDismissed: (_) {
                  f.remove(todos[i]);
                },
                child: TodoIdProvider(todo: todos[i], child: const TodoItem()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TodoIdProvider extends InheritedWidget {
  final Todo todo;
  const TodoIdProvider({super.key, required this.todo, required super.child});
  static TodoIdProvider of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<TodoIdProvider>();
    assert(result != null, 'No TodoIdProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(TodoIdProvider oldWidget) => todo != oldWidget.todo;
}

class TodoItem extends HookWidget {
  const TodoItem({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.read<TodosCubit>();
    final itemFocusNode = useFocusNode();
    final todo = TodoIdProvider.of(context).todo;

    final textFieldFocusNode = useFocusNode();
    final textEditingController = useTextEditingController();
    final itemIsFocused = useState(false);

    // Set up focus change effect
    useEffect(() {
      void onFocusChange() {
        itemIsFocused.value = itemFocusNode.hasFocus;
      }

      itemFocusNode.addListener(onFocusChange);
      return () => itemFocusNode.removeListener(onFocusChange);
    }, [itemFocusNode]);

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
            if (textEditingController.text != todo.description) {
              f.edit(id: todo.id, description: textEditingController.text);
            }
          }
        },
        child: ListTile(
          onTap: () {
            itemFocusNode.requestFocus();
            textFieldFocusNode.requestFocus();
          },
          leading: Checkbox(
            value: todo.completed,
            onChanged: (value) => f.toggle(todo.id),
          ),
          title:
              itemIsFocused.value
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

class Toolbar extends BlocSelectorWidget<TodosCubit, TodosState, TodoListFilter> {
  Toolbar({super.key}) : super(selector: (s) => s.filter);

  @override
  Widget build(context, bloc, filter) {
    final setFilter = context.read<TodosCubit>().setFilter;
    print("build: Toolbar");
    return Material(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: BlocSelector<TodosCubit, TodosState, int>(
              selector: (state) => state.todos.where((todo) => !todo.completed).length,
              builder:
                  (_, left) => Text('$left items left', overflow: TextOverflow.ellipsis),
            ),
          ),
          FilterRow(
            onAll: () => setFilter(TodoListFilter.all),
            onActive: () => setFilter(TodoListFilter.active),
            onCompleted: () => setFilter(TodoListFilter.completed),
            activeFilter: filter,
          ),
        ],
      ),
    );
  }
}
