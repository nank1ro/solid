// SPEC §3.5 / §4.8 rule 5: a query body that reads TWO OR MORE @SolidState
// reactive identifiers synthesizes a Record-Computed source field whose
// tuple mirrors the body's reads. The source Computed disposes AFTER the
// Resource (reverse-declaration order in dispose()) so the Resource tears
// down its subscription before its source is released. The nullable `orgId`
// Signal exercises the `(int, String?)` Record-tuple type — non-nullable
// alongside nullable in the same source list.

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class UserCard extends StatelessWidget {
  UserCard({super.key});

  @SolidState()
  int userId = 1;

  @SolidState()
  String? orgId;

  @SolidQuery()
  Future<String> fetchUser() async => 'user-$userId@${orgId ?? ''}';

  @override
  Widget build(BuildContext context) => const Placeholder();
}
