import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'home_page.dart';

void main() {
  SolidartConfig.autoDispose = false;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'My App', home: HomePage());
  }
}
