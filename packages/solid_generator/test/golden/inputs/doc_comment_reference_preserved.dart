import 'package:solid_annotations/solid_annotations.dart';

// A doc-comment reference to a reactive field (`[count]`) must survive the
// `.value` rewrite untouched — the value rewriter appends `.value` to runtime
// reads of `count`, but a `[count]` in a documentation comment is a resolved
// reference, not a read, and rewriting it to `[count.value]` breaks it
// (`comment_references`). The getter BODY still gets the append.
class Counter {
  @SolidState()
  int count = 0;

  /// Twice the [count]. Reads [count] then doubles it.
  int get doubled => count * 2;
}
