import 'dart:async';
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  final counter = Signal<int>(0, name: 'counter');

  final StreamSubscription<void> _subscription = Stream<void>.periodic(
    const Duration(seconds: 1),
  ).listen((_) {});

  @override
  void initState() {
    super.initState();
    debugPrint('init');
  }

  @override
  void didUpdateWidget(covariant Counter oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('update');
  }

  @override
  void dispose() {
    counter.dispose();
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
