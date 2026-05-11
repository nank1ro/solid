import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'package:todos_example/controllers/filter.dart';
import 'package:todos_example/controllers/todos.dart';
import 'package:todos_example/domain/todo.dart';
import 'package:todos_example/pages/todos.dart';
import 'package:todos_example/widgets/todo_item.dart';

Widget makeApp(TodosController todosController) {
  return MaterialApp(
    home: const TodosPage()
        .environment<TodosController>((_) => todosController)
        .environment((_) => FilterController()),
  );
}

void main() {
  testWidgets('Todos with initial value', (tester) async {
    final initialTodos = List.generate(
      3,
      (i) => Todo(id: i.toString(), task: 'mock$i', completed: false),
    );
    await tester.pumpWidget(
      makeApp(TodosController(initialTodos: initialTodos)),
    );

    expect(tester.widgetList(find.byType(TodoItem)).length, 3);
    expect(find.text('mock0'), findsOneWidget);
    expect(find.text('mock1'), findsOneWidget);
    expect(find.text('mock2'), findsOneWidget);
  });

  testWidgets('Add a todo', (tester) async {
    await tester.pumpWidget(makeApp(TodosController()));

    expect(tester.widgetList(find.byType(TodoItem)).length, 0);

    await tester.enterText(find.byType(TextFormField), 'test todo');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(tester.widgetList(find.byType(TodoItem)).length, 1);
    expect(find.text('test todo'), findsOneWidget);
  });

  testWidgets('Remove a todo', (tester) async {
    final initialTodos = List.generate(
      3,
      (i) => Todo(id: i.toString(), task: 'mock$i', completed: false),
    );
    await tester.pumpWidget(
      makeApp(TodosController(initialTodos: initialTodos)),
    );

    expect(tester.widgetList(find.byType(TodoItem)).length, 3);

    final firstTodoItem = find.byType(TodoItem).first;
    await tester.fling(firstTodoItem, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(tester.widgetList(find.byType(TodoItem)).length, 2);
    expect(find.text('mock0'), findsNothing);
  });

  testWidgets('Toggle a todo', (tester) async {
    final initialTodos = List.generate(
      2,
      (i) => Todo(id: '$i', task: 'mock$i', completed: false),
    );
    await tester.pumpWidget(
      makeApp(TodosController(initialTodos: initialTodos)),
    );

    expect(find.text('completed (0)'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();

    expect(find.text('completed (1)'), findsOneWidget);

    await tester.tap(find.text('completed (1)'));
    await tester.pump();

    expect(find.text('mock0'), findsOneWidget);
    expect(find.text('mock1'), findsNothing);
  });
}
