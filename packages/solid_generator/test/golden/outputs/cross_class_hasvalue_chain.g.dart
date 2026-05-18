import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

class LazyHolder implements Disposable {
  late final count = Signal<int>.lazy(name: 'count');

  @override
  void dispose() {
    count.dispose();
  }
}

class LazyDisplay extends StatefulWidget {
  const LazyDisplay({super.key});

  @override
  State<LazyDisplay> createState() => _LazyDisplayState();
}

class _LazyDisplayState extends State<LazyDisplay> {
  late final holder = context.read<LazyHolder>();

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return switch (holder.count.hasValue) {
          true => Text('count: ${holder.count.value}'),
          false => const Text('not initialized'),
        };
      },
    );
  }
}
