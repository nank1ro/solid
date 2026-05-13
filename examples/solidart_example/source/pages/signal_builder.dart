import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class SignalBuilderPage extends StatelessWidget {
  const SignalBuilderPage({super.key});

  @SolidState()
  int counter1 = 0;

  @SolidState()
  int counter2 = 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('SignalBuilder')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ListTile(
              title: Text(
                'First counter: $counter1',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium!.copyWith(color: Colors.black),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Second counter: $counter2',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium!.copyWith(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () => counter1++,
                  child: const Text('Counter1++'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => counter2++,
                  child: const Text('Counter2++'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
