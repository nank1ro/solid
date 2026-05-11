import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solidart_example/controllers/counter.dart';

class SignalBuilderPage extends StatefulWidget {
  const SignalBuilderPage({super.key});

  @override
  State<SignalBuilderPage> createState() => _SignalBuilderPageState();
}

class _SignalBuilderPageState extends State<SignalBuilderPage> {
  late final counter1 = CounterController();
  late final counter2 = CounterController();

  @override
  void dispose() {
    counter1.dispose();
    counter2.dispose();
    super.dispose();
  }

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
            SignalBuilder(
              builder: (_, _) {
                return ListTile(
                  title: Text(
                    'First counter: ${counter1.counter.value}',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium!.copyWith(color: Colors.black),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Second counter: ${counter2.counter.value}',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium!.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: counter1.increment,
                  child: const Text('Counter1++'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: counter2.increment,
                  child: const Text('Counter2++'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Text(
                'Using a SignalBuilder the builder is fired for each change in any signal. '
                'Even when only one signal updates, the whole builder is called again. ',
                style: textTheme.titleMedium!.copyWith(color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
