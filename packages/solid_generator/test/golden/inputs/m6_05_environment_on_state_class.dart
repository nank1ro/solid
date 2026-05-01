// Mirror of M1-07 / M4-08 for `@SolidEnvironment`. An existing
// `State<HomePage>` already hosts a hand-written `initState` (calls
// `super.initState()` then `debugPrint('init')`) and a hand-written
// `dispose` (cancels a stream subscription, calls `super.dispose()`). It
// also has one `@SolidEnvironment` field and one `@SolidState` field. The
// golden locks SPEC §4.9 rule 2 (env fields are lazy and never spliced
// into `initState`) and §4.9 rule 5 / §10 (env fields never enter the
// host's dispose-name list — disposal belongs to the `Provider<T>`
// owner). The `@SolidState counter` field IS prepended to the existing
// dispose body, per the §10 rule the host already follows for its own
// reactive members.
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Logger {
  void log(String message) => print(message);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @SolidEnvironment()
  late Logger logger;

  @SolidState()
  int counter = 0;

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
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
