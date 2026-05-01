import 'dart:async';
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';

class Logger {
  void log(String message) => print(message);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final logger = context.read<Logger>();

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
  void dispose() {
    counter.dispose();
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
