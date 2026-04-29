import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Greeter extends StatefulWidget {
  Greeter({super.key});

  @override
  State<Greeter> createState() => _GreeterState();
}

class _GreeterState extends State<Greeter> {
  late final fetchData = Resource<String>(() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return 'fetched';
  }, name: 'fetchData');

  @override
  void dispose() {
    fetchData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
