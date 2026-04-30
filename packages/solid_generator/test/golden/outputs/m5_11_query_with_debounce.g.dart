import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Searcher extends StatefulWidget {
  Searcher({super.key});

  @override
  State<Searcher> createState() => _SearcherState();
}

class _SearcherState extends State<Searcher> {
  late final fetchData = Resource<String>(
    () async => 'result',
    debounceDelay: const Duration(milliseconds: 300),
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
