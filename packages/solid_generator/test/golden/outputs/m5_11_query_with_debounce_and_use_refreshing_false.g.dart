import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Combined extends StatefulWidget {
  Combined({super.key});

  @override
  State<Combined> createState() => _CombinedState();
}

class _CombinedState extends State<Combined> {
  late final fetchData = Resource<String>(
    () async => 'result',
    debounceDelay: const Duration(milliseconds: 300),
    useRefreshing: false,
    name: 'fetchData',
  );

  @override
  void dispose() {
    fetchData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
