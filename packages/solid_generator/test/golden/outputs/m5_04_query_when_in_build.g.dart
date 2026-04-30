import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class UserScreen extends StatefulWidget {
  UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  late final fetchName = Resource<String>(
    () async => 'Alice',
    name: 'fetchName',
  );

  @override
  void dispose() {
    fetchName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return fetchName().when(
          ready: (name) => Text(name),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('error: $e'),
        );
      },
    );
  }
}
