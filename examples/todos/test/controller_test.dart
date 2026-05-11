import 'package:flutter_test/flutter_test.dart';
import 'package:todos_example/controllers/todos.dart';
import 'package:todos_example/domain/todo.dart';

void main() {
  group('TodosController -', () {
    test('When providing initialTodos, `todos` emits the correct state', () {
      const initialTodos = [
        Todo(id: '1', task: 'mock1', completed: false),
        Todo(id: '2', task: 'mock2', completed: false),
      ];
      final controller = TodosController(initialTodos: initialTodos);
      addTearDown(controller.dispose);

      expect(controller.todos, hasLength(2));
    });

    test('Add a todo', () {
      final controller = TodosController();
      addTearDown(controller.dispose);

      expect(controller.todos, isEmpty);

      controller.add(const Todo(id: '1', task: 'mock1', completed: false));

      expect(controller.todos, hasLength(1));
    });

    test('Remove a todo', () {
      const initialTodos = [
        Todo(id: '1', task: 'mock1', completed: false),
        Todo(id: '2', task: 'mock2', completed: false),
      ];
      final controller = TodosController(initialTodos: initialTodos);
      addTearDown(controller.dispose);

      expect(controller.todos, hasLength(2));

      controller.remove('1');

      expect(controller.todos, hasLength(1));
      expect(controller.todos.first.id, '2');
    });

    test('Toggle a todo', () {
      const initialTodos = [
        Todo(id: '1', task: 'mock1', completed: false),
      ];
      final controller = TodosController(initialTodos: initialTodos);
      addTearDown(controller.dispose);

      expect(controller.todos.first.completed, false);

      controller.toggle('1');

      expect(controller.todos.first.completed, true);
    });
  });
}
