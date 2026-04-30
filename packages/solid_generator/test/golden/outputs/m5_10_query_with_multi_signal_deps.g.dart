import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class UserCard extends StatefulWidget {
  UserCard({super.key});

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  final userId = Signal<int>(1, name: 'userId');
  final orgId = Signal<String?>(null, name: 'orgId');
  late final _fetchUserSource = Computed<(int, String?)>(
    () => (userId.value, orgId.value),
    name: '_fetchUserSource',
  );
  late final fetchUser = Resource<String>(
    () async => 'user-${userId.value}@${orgId.value ?? ''}',
    source: _fetchUserSource,
    name: 'fetchUser',
  );

  @override
  void dispose() {
    fetchUser.dispose();
    _fetchUserSource.dispose();
    orgId.dispose();
    userId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
