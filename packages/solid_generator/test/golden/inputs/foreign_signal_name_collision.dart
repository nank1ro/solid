// A foreign `flutter_solidart` signal whose SOURCE TEXT collides with the
// name of a generator-managed `@SolidState` member read by the SAME build
// method. `Collide.gate` is a hand-written `Signal<int>`; `Model.gate` is an
// `@SolidState` field reached cross-instance. Both reads are tracked, the
// managed one anchors the outer `Tooltip` wrap and the foreign one the inner
// `Text` wrap — so unless the two occupy disjoint key name-spaces, the
// Section 7.5 same-signal collapse sees the inner wrap's name-set as a
// subset of the outer's and prunes it, leaving the foreign signal with no
// tracking context at all (silently no rebuild).
//
// `NoCollide` is the control: identical shape, foreign signal renamed, and
// its inner wrap must survive either way. Section 7.6 — different signals
// always keep both wraps — is what both classes assert.
//
// `flutter_solidart` is not a dependency of the generator package, so
// `Signal` is unresolved here and the rewriter matches the declared type's
// lexeme (the AST-fallback tier).
// ignore_for_file: undefined_class, undefined_identifier

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Model {
  @SolidState()
  int gate = 0;
}

class Collide extends StatelessWidget {
  const Collide({required this.model, required this.gate, super.key});

  final Model model;
  final Signal<int> gate;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'managed: ${model.gate}',
      child: Text('foreign: ${gate.value}'),
    );
  }
}

class NoCollide extends StatelessWidget {
  const NoCollide({required this.model, required this.other, super.key});

  final Model model;
  final Signal<int> other;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'managed: ${model.gate}',
      child: Text('foreign: ${other.value}'),
    );
  }
}
