import 'package:example/counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

void main() {
  SolidartConfig.autoDispose = false;
  runApp(const MaterialApp(home: CounterPage()));
}
