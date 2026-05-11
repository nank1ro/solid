import 'package:solid_annotations/solid_annotations.dart';
import 'package:todos_example/domain/todo.dart';

class FilterController {
  @SolidState()
  TodosFilter filter = TodosFilter.all;
}
