import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Settings implements Disposable {
  final factor = Signal<int>(1, name: 'factor');

  final prefix = Signal<String?>(null, name: 'prefix');

  @override
  void dispose() {
    prefix.dispose();
    factor.dispose();
  }
}

class ValueCard extends StatefulWidget {
  const ValueCard({super.key});

  @override
  State<ValueCard> createState() => _ValueCardState();
}

class _ValueCardState extends State<ValueCard> {
  late final settings = context.read<Settings>();
  late final _fetchValueSource = Computed<(String?, int)>(
    () => (settings.prefix.value, settings.factor.value),
    name: '_fetchValueSource',
  );
  late final fetchValue = Resource<String>(
    () async => '${settings.prefix.value ?? ''}${10 * settings.factor.value}',
    source: _fetchValueSource,
    name: 'fetchValue',
  );

  @override
  void dispose() {
    fetchValue.dispose();
    _fetchValueSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
