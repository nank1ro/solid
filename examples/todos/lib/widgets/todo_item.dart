import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/todos.dart';
import '../domain/todo.dart';

class TodoItem extends StatefulWidget {
  const TodoItem({super.key, required this.todo});

  final Todo todo;

  @override
  State<TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem> {
  late final todosController = context.read<TodosController>();

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(widget.todo.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => todosController.remove(widget.todo.id),
      background: Container(
        decoration: const BoxDecoration(color: Colors.red),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 8),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: CheckboxListTile(
        title: Text(widget.todo.task),
        value: widget.todo.completed,
        onChanged: (_) => todosController.toggle(widget.todo.id),
      ),
    );
  }
}
