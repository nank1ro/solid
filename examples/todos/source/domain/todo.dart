import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

@immutable
class Todo {
  const Todo({
    required this.id,
    required this.task,
    required this.completed,
  });

  factory Todo.create(String task) {
    return Todo(id: const Uuid().v4(), task: task, completed: false);
  }

  final String id;
  final String task;
  final bool completed;

  static List<Todo> get sample {
    return [
      Todo.create('Learn Solid'),
      Todo.create('Wash the car'),
      Todo.create('Go shopping'),
    ];
  }

  Todo copyWith({bool? completed}) {
    return Todo(id: id, task: task, completed: completed ?? this.completed);
  }
}

enum TodosFilter { all, incomplete, completed }
