// SPEC §3.5 / §4.8 rule 5: a query body that reads exactly ONE @SolidState
// reactive identifier passes that Signal/Computed directly as the Resource's
// `source:` argument — no synthesized wrapper Computed, since
// `Computed(() => signal.value)` would be a no-op.

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class UserCard extends StatelessWidget {
  UserCard({super.key});

  @SolidState()
  int userId = 1;

  @SolidQuery()
  Future<String> fetchUser() async => 'user-$userId';

  @override
  Widget build(BuildContext context) => const Placeholder();
}
