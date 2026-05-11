import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../controllers/filter.dart';
import '../controllers/todos.dart';
import '../domain/todo.dart';
import 'todo_item.dart';

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  late final todosController = context.read<TodosController>();
  late final filterController = context.read<FilterController>();
  late final filteredTodos = Computed<List<Todo>>(() {
    switch (filterController.filter.value) {
      case TodosFilter.all:
        // `.toList()` returns a fresh copy so the Computed's default
        // `identical` comparator sees a new reference whenever the
        // underlying `ListSignal` mutates (in-place adds keep the same
        // reference, which would suppress invalidation).
        return todosController.todos.toList();
      case TodosFilter.incomplete:
        return todosController.incompleteTodos.value;
      case TodosFilter.completed:
        return todosController.completedTodos.value;
    }
  }, name: 'filteredTodos');

  @override
  void dispose() {
    filteredTodos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return ListView(
          children: [
            for (final todo in filteredTodos.value) TodoItem(todo: todo),
          ],
        );
      },
    );
  }
}
