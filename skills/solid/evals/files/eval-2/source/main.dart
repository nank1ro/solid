import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'posts_page.dart';

void main() {
  SolidartConfig.autoDispose = false;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'My App', home: PostsPage());
  }
}
