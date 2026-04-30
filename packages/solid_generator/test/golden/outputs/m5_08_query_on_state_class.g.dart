import 'dart:async';
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class UserCard extends StatefulWidget {
  const UserCard({super.key});

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  final StreamSubscription<void> _subscription = Stream<void>.periodic(
    const Duration(seconds: 1),
  ).listen((_) {});

  late final fetchUser = Resource<String>(
    () async => 'Alice',
    name: 'fetchUser',
  );

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
    fetchUser.dispose();
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return fetchUser().when(
          ready: (name) => Text(name),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('error: $e'),
        );
      },
    );
  }
}
