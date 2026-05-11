import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solidart_example/controllers/toggle.dart';

class ShowPage extends StatefulWidget {
  const ShowPage({super.key});

  @override
  State<ShowPage> createState() => _ShowPageState();
}

class _ShowPageState extends State<ShowPage> {
  late final controller = ToggleController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

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
              when: () => controller.loggedIn.value,
              builder: (_) => const Text('LOGIN'),
              fallback: (_) => const Text('LOGOUT'),
            ),
          ),
        ],
      ),
      body: Center(
        child: Show(
          when: () => controller.loggedIn.value,
          builder: (_) => const Text('Logged In'),
          fallback: (_) => const Text('Logged out'),
        ),
      ),
    );
  }
}
