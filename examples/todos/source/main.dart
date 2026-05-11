import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'controllers/filter.dart';
import 'controllers/todos.dart';
import 'domain/todo.dart';
import 'pages/todos.dart';

void main() {
  SolidartConfig.autoDispose = false;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todos Example',
      home: const TodosPage()
          .environment((_) => TodosController(initialTodos: Todo.sample))
          .environment((_) => FilterController()),
    );
  }
}
