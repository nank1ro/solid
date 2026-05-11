import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'package:todos_example/domain/todo.dart';

class TodosController implements Disposable {
  TodosController({List<Todo> initialTodos = const []}) {
    todos.addAll(initialTodos);
  }

  final todos = ListSignal<Todo>(const [], name: 'todos');

  late final completedTodos = Computed<List<Todo>>(
    () => todos.value.where((t) => t.completed).toList(),
    name: 'completedTodos',
  );

  late final incompleteTodos = Computed<List<Todo>>(
    () => todos.value.where((t) => !t.completed).toList(),
    name: 'incompleteTodos',
  );

  void add(Todo todo) => todos.add(todo);

  void remove(String id) => todos.removeWhere((t) => t.id == id);

  void toggle(String id) {
    final i = todos.indexWhere((t) => t.id == id);
    todos[i] = todos[i].copyWith(completed: !todos[i].completed);
  }

  @override
  void dispose() {
    incompleteTodos.dispose();
    completedTodos.dispose();
    todos.dispose();
  }
}
