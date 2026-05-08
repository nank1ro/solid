import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  late final fetchCount = Resource<int>(() async => 0, name: 'fetchCount');

  @override
  void dispose() {
    fetchCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => fetchCount.refresh(),
      child: const Icon(Icons.refresh),
    );
  }
}
