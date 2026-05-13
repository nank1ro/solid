// Multiple tracked reads of the same query (`user`) at nested positions —
// outer at the `.when(...)` discriminant, inner inside a ready-branch Text.
// The placement pass collapses these into ONE `SignalBuilder` around the
// outer `user().when(...)` chain because every inner read subscribes to
// the same query the outer already covers.

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class UserPanel extends StatelessWidget {
  const UserPanel({super.key});

  @SolidQuery()
  Future<String> user() async => 'Alice';

  @override
  Widget build(BuildContext context) {
    return user().when(
      ready: (data) => Column(
        children: [
          Text(data),
          Text('refreshing: ${user().isRefreshing}'),
        ],
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('$e'),
    );
  }
}
