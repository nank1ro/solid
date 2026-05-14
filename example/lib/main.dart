import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'counter.dart';

void main() {
  SolidartConfig.autoDispose = false;
  runApp(const MaterialApp(home: CounterPage()));
}
