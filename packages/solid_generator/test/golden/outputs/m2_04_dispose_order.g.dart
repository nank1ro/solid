import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class DisposeOrder extends StatefulWidget {
  DisposeOrder({super.key});

  @override
  State<DisposeOrder> createState() => _DisposeOrderState();
}

class _DisposeOrderState extends State<DisposeOrder> {
  final count = Signal<int>(0, name: 'count');
  final label = Signal<String>('', name: 'label');
  late final summary = Computed<int>(() => count.value * 2, name: 'summary');

  @override
  void dispose() {
    summary.dispose();
    label.dispose();
    count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
