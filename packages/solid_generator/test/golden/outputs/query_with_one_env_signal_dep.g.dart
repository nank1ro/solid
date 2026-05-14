import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Filter implements Disposable {
  final factor = Signal<int>(1, name: 'factor');

  @override
  void dispose() {
    factor.dispose();
  }
}

class ValueCard extends StatefulWidget {
  const ValueCard({super.key});

  @override
  State<ValueCard> createState() => _ValueCardState();
}

class _ValueCardState extends State<ValueCard> {
  late final filter = context.read<Filter>();
  late final fetchValue = Resource<int>(
    () async => 10 * filter.factor.value,
    source: filter.factor,
    name: 'fetchValue',
  );

  @override
  void dispose() {
    fetchValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
