import 'package:solid_annotations/solid_annotations.dart';

import '../domain/todo.dart';

class TodosController {
  TodosController({List<Todo> initialTodos = const []}) {
    todos.addAll(initialTodos);
  }

  @SolidState()
  List<Todo> todos = const [];

  @SolidState()
  List<Todo> get completedTodos => todos.where((t) => t.completed).toList();

  @SolidState()
  List<Todo> get incompleteTodos => todos.where((t) => !t.completed).toList();

  void add(Todo todo) => todos.add(todo);

  void remove(String id) => todos.removeWhere((t) => t.id == id);

  void toggle(String id) {
    final i = todos.indexWhere((t) => t.id == id);
    todos[i] = todos[i].copyWith(completed: !todos[i].completed);
  }
}
