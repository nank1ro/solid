import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/todos.dart';
import '../domain/todo.dart';
import 'todos_list.dart';
import 'toolbar.dart';

class TodosBody extends StatefulWidget {
  const TodosBody({super.key});

  @override
  State<TodosBody> createState() => _TodosBodyState();
}

class _TodosBodyState extends State<TodosBody> {
  @SolidEnvironment()
  late TodosController todosController;

  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: _textController,
          decoration: const InputDecoration(hintText: 'Write new todo'),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Cannot be empty';
            return null;
          },
          onFieldSubmitted: (task) {
            if (task.isEmpty) return;
            todosController.add(Todo.create(task));
            _textController.clear();
          },
        ),
        const SizedBox(height: 16),
        const Toolbar(),
        const SizedBox(height: 16),
        const Expanded(child: TodoList()),
      ],
    );
  }
}
