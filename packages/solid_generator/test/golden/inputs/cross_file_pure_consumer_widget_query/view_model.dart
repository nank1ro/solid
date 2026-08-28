// Cross-instance `@SolidQuery` consumption fixture: a plain view-model class
// declaring a `@SolidQuery` method, consumed cross-file by a pure-consumer
// `StatelessWidget`'s `build()` (see `view.dart`). Before this fix,
// `@SolidQuery` method names were excluded from every cross-class registry
// — `builder.dart` only ever seeded `classRegistry` (the `@SolidState`
// field/getter map), never a query counterpart — so a widget reading
// `viewModel.customers()` cross-instance got no `SignalBuilder` wrap and no
// `flutter_solidart` import: the read looked fixed but stayed non-reactive.
//
// `CustomersViewModel` owns zero `@SolidState` fields — proving the fix
// does not piggyback on the (already-working) cross-instance `@SolidState`
// path.
import 'package:solid_annotations/solid_annotations.dart';

class Customer {
  const Customer(this.name);

  final String name;
}

class CustomersViewModel {
  @SolidQuery()
  Future<List<Customer>> customers() async => const [Customer('Ada')];
}
