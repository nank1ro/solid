import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class UserPanel extends StatefulWidget {
  const UserPanel({super.key});

  @override
  State<UserPanel> createState() => _UserPanelState();
}

class _UserPanelState extends State<UserPanel> {
  late final user = Resource<String>(() async => 'Alice', name: 'user');

  @override
  void dispose() {
    user.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return user().when(
          ready: (data) => Column(
            children: [Text(data), Text('refreshing: ${user().isRefreshing}')],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('$e'),
        );
      },
    );
  }
}
