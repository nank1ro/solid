import 'package:solid_annotations/solid_annotations.dart';

import '../domain/todo.dart';

class FilterController {
  @SolidState()
  TodosFilter filter = TodosFilter.all;
}
