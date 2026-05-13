import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/effects.dart';

class EffectsPage extends StatelessWidget {
  const EffectsPage({super.key});

  @SolidEnvironment()
  late EffectsController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Effects')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Check the console to see the effect printing'),
            const SizedBox(height: 16),
            Text('Count: ${controller.count}'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
