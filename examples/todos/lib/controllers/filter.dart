import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'package:todos_example/domain/todo.dart';

class FilterController implements Disposable {
  final filter = Signal<TodosFilter>(TodosFilter.all, name: 'filter');

  @override
  void dispose() {
    filter.dispose();
  }
}
