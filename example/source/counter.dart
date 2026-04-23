import 'package:flutter/material.dart';

/// Hello-world widget used as the M0 smoke-test.
class Counter extends StatelessWidget {
  /// Creates a [Counter] widget.
  const Counter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('hello')),
    );
  }
}
