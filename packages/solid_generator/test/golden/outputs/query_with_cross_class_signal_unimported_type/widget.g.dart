import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'controllers.dart';
import 'types.dart';

class Display extends StatefulWidget {
  const Display({super.key});

  @override
  State<Display> createState() => _DisplayState();
}

class _DisplayState extends State<Display> {
  late final settings = context.read<Settings>();
  final seed = Signal<int>(0, name: 'seed');
  late final _qSource = Computed<(int, Unit)>(
    () => (seed.value, settings.unit.value),
    name: '_qSource',
  );
  late final q = Resource<String>(
    () async => '${seed.value}-${settings.unit.value}',
    source: _qSource,
    name: 'q',
  );

  @override
  void dispose() {
    q.dispose();
    _qSource.dispose();
    seed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
