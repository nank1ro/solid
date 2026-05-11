import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'package:todos_example/controllers/filter.dart';
import 'package:todos_example/controllers/todos.dart';
import 'package:todos_example/domain/todo.dart';

class Toolbar extends StatelessWidget {
  Toolbar({super.key});

  @SolidEnvironment()
  late TodosController todosController;

  @SolidEnvironment()
  late FilterController filterController;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: TodosFilter.values.length,
      child: TabBar(
        labelColor: Colors.black,
        tabs: [
          Tab(text: 'all (${todosController.todos.length})'),
          Tab(text: 'incomplete (${todosController.incompleteTodos.length})'),
          Tab(text: 'completed (${todosController.completedTodos.length})'),
        ],
        onTap: (index) {
          filterController.filter = TodosFilter.values[index];
        },
      ),
    );
  }
}
