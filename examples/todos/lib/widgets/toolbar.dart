import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../controllers/filter.dart';
import '../controllers/todos.dart';
import '../domain/todo.dart';

class Toolbar extends StatefulWidget {
  const Toolbar({super.key});

  @override
  State<Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<Toolbar> {
  late final todosController = context.read<TodosController>();
  late final filterController = context.read<FilterController>();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: TodosFilter.values.length,
      child: TabBar(
        labelColor: Colors.black,
        tabs: [
          SignalBuilder(
            builder: (context, child) {
              return Tab(text: 'all (${todosController.todos.length})');
            },
          ),
          SignalBuilder(
            builder: (context, child) {
              return Tab(
                text:
                    'incomplete (${todosController.incompleteTodos.value.length})',
              );
            },
          ),
          SignalBuilder(
            builder: (context, child) {
              return Tab(
                text:
                    'completed (${todosController.completedTodos.value.length})',
              );
            },
          ),
        ],
        onTap: (index) {
          filterController.filter.value = TodosFilter.values[index];
        },
      ),
    );
  }
}
