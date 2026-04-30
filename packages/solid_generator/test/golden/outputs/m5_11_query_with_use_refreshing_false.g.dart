import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Loader extends StatefulWidget {
  Loader({super.key});

  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> {
  late final fetchData = Resource<String>(
    () async => 'result',
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
