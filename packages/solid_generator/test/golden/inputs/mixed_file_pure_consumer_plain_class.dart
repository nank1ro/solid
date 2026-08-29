// The plain-class (non-widget) sibling of `mixed_file_pure_consumer_widget`:
// a pure-consumer plain class that reads/writes another class's `@SolidState`
// through a constructor-injected field, co-located in the SAME file as the
// annotated class. Exercises the `ClassKind.plainClass` branch of the per-class
// `lowerPureConsumerClass` (a mixed file never reaches the whole-file
// `lowerPureConsumers`). Without it, `_counter.count = …` stays un-lowered and
// hits `assignment_to_final` on the generated `final Signal`.
//
// A pure consumer owns no reactive member, so `Controller` must NOT gain
// `implements Disposable` — only `.value` lowering applies (no `SignalBuilder`,
// no wrap — that is a widget-`build`-only concern).
import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int count = 0;
}

class Controller {
  Controller(this._counter);

  final Counter _counter;

  int read() => _counter.count;

  void increment() => _counter.count = _counter.count + 1;
}
