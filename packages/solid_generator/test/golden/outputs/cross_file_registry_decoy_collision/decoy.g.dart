// Same-simple-name decoy with zero `@SolidState` members — regression
// fixture for the cross-file registry decoy-collision bug in
// `builder.dart::_populateCrossFileTypes`. `main.dart` imports this file
// BEFORE `controller.dart`, so the import-order-first, non-annotated
// `UnitsController` here is reached first when the builder walks main.dart's
// imports looking for the wanted type name `UnitsController`.
class UnitsController {
  String label = 'x';
}
