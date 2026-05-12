// Cross-class chain to a Signal API getter: `<env>.<reactiveField>.hasValue`
// (or `.value` / `.previousValue`) must pass through verbatim — the rewriter
// must NOT insert a `.value` between the field and the getter, because the
// lowered chain would route through the unboxed payload type and break.
// Lazy-state probes via `@SolidEnvironment` injection are the canonical
// driver for this rule.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class LazyHolder {
  @SolidState()
  late int count;
}

class LazyDisplay extends StatelessWidget {
  LazyDisplay({super.key});

  @SolidEnvironment()
  late LazyHolder holder;

  @override
  Widget build(BuildContext context) {
    return switch (holder.count.hasValue) {
      true => Text('count: ${holder.count}'),
      false => const Text('not initialized'),
    };
  }
}
