import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class SearchBox extends StatefulWidget {
  const SearchBox({super.key});

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final controller = TextEditingController();

  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(controller.value.text),
        SignalBuilder(
          builder: (context, child) {
            return Text('count: ${counter.value}');
          },
        ),
      ],
    );
  }
}
