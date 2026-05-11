// A `late` @SolidState int field is lowered to `Signal<int>.lazy`. Source
// code may probe initialization state via the bare-receiver chain
// `<field>.hasValue` — the rewriter must pass that getter through verbatim
// (parallel to `.value`), since `hasValue` is a real `SignalBase<T>` getter
// and inserting `.value` would yield the non-compiling
// `field.value.hasValue`. Bare reads (`field + 1`) and writes
// (`field = …`) still receive the normal `.value` rewrite. The source-side
// `.hasValue` typechecks via the `LazyStateExtension<T> on T` stub in
// `solid_annotations`.

import 'package:solid_annotations/solid_annotations.dart';

class LazyCounter {
  @SolidState()
  late int counter;

  void increment() {
    counter = counter.hasValue ? counter + 1 : 0;
  }
}
