import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'test/ui/counter_display.dart';

void main() => runApp(
  MaterialApp(
    home: Provider(
      create: (_) => Counter(),
      child: CounterDisplay(),
      dispose: (context, provider) => provider.dispose(),
    ),
  ),
);
