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
  final seed = Signal<int>(0, name: 'seed');
  late final _fetchValueSource = Computed<(int, int)>(
    () => (seed.value, filter.factor.value),
    name: '_fetchValueSource',
  );
  late final fetchValue = Resource<int>(
    () async => seed.value + filter.factor.value,
    source: _fetchValueSource,
    name: 'fetchValue',
  );

  @override
  void dispose() {
    fetchValue.dispose();
    _fetchValueSource.dispose();
    seed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
