import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class Logger {
  void log(String message) => print(message);
}

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final logger = context.read<Logger>();

  @override
  Widget build(BuildContext context) {
    return Text('hello');
  }
}
