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
  late final fetchUser = Resource<String>(
    () async => 'user-${userId.value}',
    source: userId,
    name: 'fetchUser',
  );

  @override
  void dispose() {
    fetchUser.dispose();
    userId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
