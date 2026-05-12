import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/toggle.dart';

class ShowPage extends StatelessWidget {
  const ShowPage({super.key});

  @SolidEnvironment()
  late ToggleController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: controller.toggle,
            child: Show(
              when: () => controller.loggedIn,
              builder: (_) => const Text('LOGIN'),
              fallback: (_) => const Text('LOGOUT'),
            ),
          ),
        ],
      ),
      body: Center(
        child: Show(
          when: () => controller.loggedIn,
          builder: (_) => const Text('Logged In'),
          fallback: (_) => const Text('Logged out'),
        ),
      ),
    );
  }
}
