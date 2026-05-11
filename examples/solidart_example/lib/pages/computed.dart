import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solidart_example/controllers/computed_value.dart';

class ComputedPage extends StatefulWidget {
  const ComputedPage({super.key});

  @override
  State<ComputedPage> createState() => _ComputedPageState();
}

class _ComputedPageState extends State<ComputedPage> {
  late final controller = ComputedValueController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Computed')),
      body: Center(
        child: SignalBuilder(
          builder: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Count: ${controller.count.value}'),
              const SizedBox(height: 16),
              Text('Double Count: ${controller.doubleCount.value}'),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
