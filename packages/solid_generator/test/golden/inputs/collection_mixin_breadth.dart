// Pins the rule that NO collection-signal chain member receives a `.value`
// insertion — the rewrite is keyed on the AST chain shape (`_isChainPrefix`
// matching `PrefixedIdentifier.prefix` / `PropertyAccess.target` /
// `MethodInvocation.target` / `IndexExpression.target`), so every
// `ListMixin<E>` / `SetMixin<E>` / `MapMixin<K, V>` member resolves through
// the signal directly — no method name is special-cased.
//
// `xs`, `tags`, `counts` are each collection signals. The build body and
// the Computed bodies below exercise: property getters (`length`, `first`,
// `isEmpty`, `keys`), instance methods returning iterables / primitives
// (`where`, `map`, `fold`, `contains`, `containsKey`, `indexOf`,
// `indexWhere`, `lookup`), index access (`[i]`, `[k]`), and mutation
// methods (`add`, `insert`, `removeAt`, `removeWhere`, `sort`,
// `[i] = v`, `[k] = v`, `putIfAbsent`). Every one of them must round-trip
// without a `.value` between the signal and the member.

// `print` is the canonical Effect side-effect demonstration; cascades are
// pinned by a sibling fixture (`collection_cascade.dart`), so the bare
// repeat-receiver calls in `mutate()` below are intentional.
// ignore_for_file: avoid_print, cascade_invocations

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Breadth extends StatelessWidget {
  Breadth({super.key});

  @SolidState()
  List<int> xs = const [];

  @SolidState()
  Set<int> tags = const {};

  @SolidState()
  Map<String, int> counts = const {};

  // Same-class Computed bodies exercising a wide mix of mixin members.
  @SolidState()
  int get sum => xs.fold<int>(0, (a, b) => a + b);

  @SolidState()
  int get evenCount => xs.where((i) => i.isEven).length;

  @SolidState()
  bool get hasOne => tags.contains(1);

  @SolidState()
  Iterable<String> get keys => counts.keys;

  // Effect body uses a mixed bag of read shapes — every one resolves via
  // the mixin on the signal, no `.value` insertion.
  @SolidEffect()
  void log() {
    print(
      'len=${xs.length} '
      'first=${xs.first} '
      'idx0=${xs[0]} '
      'has-one=${tags.contains(1)} '
      'keys=${counts.keys} '
      'a=${counts['a']} '
      'has-a=${counts.containsKey('a')} '
      'indexOf=${xs.indexOf(0)} '
      'indexWhere=${xs.indexWhere((i) => i > 5)}',
    );
  }

  void mutate() {
    // Mutation methods — direct calls on the signal (no `.value`),
    // because the single-call shape is `MethodInvocation` with
    // target=identifier, which `_isChainPrefix` catches.
    xs.add(1);
    xs.insert(0, 5);
    xs.removeAt(0);
    xs.removeWhere((i) => i.isOdd);
    xs.sort();
    xs[0] = 99;
    tags.add(2);
    tags.remove(2);
    counts['a'] = 1;
    counts.remove('a');
    counts.putIfAbsent('b', () => 0);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'sum=$sum '
      'evens=$evenCount '
      'has-one=$hasOne '
      'last=${xs.last} '
      'empty=${xs.isEmpty} '
      'set-len=${tags.length} '
      'map-len=${counts.length}',
    );
  }
}
