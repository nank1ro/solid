import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Store implements Disposable {
  final items = ListSignal<int>([], name: 'items');

  @override
  void dispose() {
    items.dispose();
  }
}

class Reader extends StatefulWidget {
  const Reader({super.key});

  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> {
  late final store = context.read<Store>();
  late final watchCount = Resource<int>.stream(() async* {
    yield store.items.length;
  }, name: 'watchCount');

  @override
  void dispose() {
    watchCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
