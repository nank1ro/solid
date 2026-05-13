import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/todos.dart';
import '../domain/todo.dart';

class TodoItem extends StatelessWidget {
  TodoItem({super.key, required this.todo});

  final Todo todo;

  @SolidEnvironment()
  late TodosController todosController;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => todosController.remove(todo.id),
      background: Container(
        decoration: const BoxDecoration(color: Colors.red),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 8),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: CheckboxListTile(
        title: Text(todo.task),
        value: todo.completed,
        onChanged: (_) => todosController.toggle(todo.id),
      ),
    );
  }
}
