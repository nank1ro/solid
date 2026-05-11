import 'package:flutter/material.dart';
import 'package:todos_example/widgets/todos_body.dart';

class TodosPage extends StatelessWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todos')),
      body: const Padding(
        padding: EdgeInsets.all(8),
        child: TodosBody(),
      ),
    );
  }
}
