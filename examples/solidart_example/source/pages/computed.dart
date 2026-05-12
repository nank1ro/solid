import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/computed_value.dart';

class ComputedPage extends StatelessWidget {
  const ComputedPage({super.key});

  @SolidEnvironment()
  late ComputedValueController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Computed')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Count: ${controller.count}'),
            const SizedBox(height: 16),
            Text('Double Count: ${controller.doubleCount}'),
            const SizedBox(height: 16),
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
