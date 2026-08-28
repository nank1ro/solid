import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Customer {
  const Customer(this.name);

  final String name;
}

class CustomersViewModel implements Disposable {
  late final customers = Resource<List<Customer>>(
    () async => const [Customer('Ada')],
    name: 'customers',
  );

  @override
  void dispose() {
    customers.dispose();
  }
}
