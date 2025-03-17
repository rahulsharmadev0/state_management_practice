import 'package:bloc_suite/bloc_suite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'logic.dart';
import '../common.dart';

void main() => runApp(
  MaterialApp(home: BlocProvider(create: (_) => TodosCubit(), child: const Home())),
);

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final TextEditingController newTodoController;

  @override
  void initState() {
    super.initState();
    newTodoController = TextEditingController();
  }

  @override
  void dispose() {
    newTodoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

class TodoItem extends StatefulWidget {
  const TodoItem({super.key});

  @override
  State<TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem> {
  late final FocusNode itemFocusNode;
  late final FocusNode textFieldFocusNode;
  late final TextEditingController textEditingController;
  bool itemIsFocused = false;

  @override
  void initState() {
    super.initState();
    itemFocusNode = FocusNode();
    textFieldFocusNode = FocusNode();
    textEditingController = TextEditingController();

    // Set up focus listener
    itemFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => itemIsFocused = itemFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    itemFocusNode.removeListener(_onFocusChange);
    itemFocusNode.dispose();
    textFieldFocusNode.dispose();
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = context.read<TodosCubit>();
    final todo = TodoIdProvider.of(context).todo;

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

class Toolbar extends BlocSelectorWidget<TodosCubit, TodosState, TodoListFilter> {
  Toolbar({super.key}) : super(selector: (s) => s.filter);

  @override
  Widget build(context, bloc, filter) {
    final setFilter = context.read<TodosCubit>().setFilter;
    print("build: Toolbar)");
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
