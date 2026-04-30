// SPEC §4.8 rule 10 / §14 item 4: Resources on an existing State<X> subclass
// are lazy — never spliced into initState. SPEC §10: disposal is prepended
// to the existing dispose() body in reverse-declaration order.
// `Future.delayed` returns `Future<void>` here — explicit type-arg silences
// `inference_failure_on_instance_creation` from the strict golden lints. The
// `loading:` lambda preserves a const-constructed widget (Dart has no const
// tear-off form), so `unnecessary_lambdas` is silenced.
// ignore_for_file: unnecessary_lambdas

import 'dart:async';

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class UserCard extends StatefulWidget {
  const UserCard({super.key});

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  final StreamSubscription<void> _subscription = Stream<void>.periodic(
    const Duration(seconds: 1),
  ).listen((_) {});

  @SolidQuery()
  Future<String> fetchUser() async => 'Alice';

  @override
  void initState() {
    super.initState();
    debugPrint('init');
  }

  @override
  void didUpdateWidget(covariant UserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('update');
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return fetchUser().when(
      ready: (name) => Text(name),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('error: $e'),
    );
  }
}
