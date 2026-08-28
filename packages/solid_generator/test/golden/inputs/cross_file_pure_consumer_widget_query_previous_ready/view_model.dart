// Cross-instance `.previousReady`/`.previousError` tear-off fixture: a plain
// view-model declaring a `@SolidQuery`, consumed cross-file by a pure-consumer
// `StatelessWidget`'s `build()` (see `view.dart`) through the retained-state
// tear-offs ONLY (no `viewModel.customers()` call anywhere in the consumer).
import 'package:solid_annotations/solid_annotations.dart';

class Customer {
  const Customer(this.name);

  final String name;
}

class CustomersViewModel {
  @SolidQuery()
  Future<List<Customer>> customers() async => const [Customer('Ada')];
}
