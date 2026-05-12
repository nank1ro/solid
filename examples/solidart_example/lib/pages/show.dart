import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../controllers/toggle.dart';

class ShowPage extends StatefulWidget {
  const ShowPage({super.key});

  @override
  State<ShowPage> createState() => _ShowPageState();
}

class _ShowPageState extends State<ShowPage> {
  late final controller = context.read<ToggleController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: controller.toggle,
            child: SignalBuilder(
              builder: (context, child) {
                return Show(
                  when: () => controller.loggedIn.value,
                  builder: (_) => const Text('LOGIN'),
                  fallback: (_) => const Text('LOGOUT'),
                );
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return Show(
              when: () => controller.loggedIn.value,
              builder: (_) => const Text('Logged In'),
              fallback: (_) => const Text('Logged out'),
            );
          },
        ),
      ),
    );
  }
}
