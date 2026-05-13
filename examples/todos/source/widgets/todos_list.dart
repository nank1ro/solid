import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/filter.dart';
import '../controllers/todos.dart';
import '../domain/todo.dart';
import 'todo_item.dart';

class TodoList extends StatelessWidget {
  TodoList({super.key});

  @SolidEnvironment()
  late TodosController todosController;

  @SolidEnvironment()
  late FilterController filterController;

  @SolidState()
  List<Todo> get filteredTodos {
    switch (filterController.filter) {
      case TodosFilter.all:
        // `.toList()` returns a fresh copy so the Computed's default
        // `identical` comparator sees a new reference whenever the
        // underlying `ListSignal` mutates (in-place adds keep the same
        // reference, which would suppress invalidation).
        return todosController.todos.toList();
      case TodosFilter.incomplete:
        return todosController.incompleteTodos;
      case TodosFilter.completed:
        return todosController.completedTodos;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final todo in filteredTodos) TodoItem(todo: todo),
      ],
    );
  }
}
