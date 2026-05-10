// `const` at call sites of generator-emitted const-eligible widget classes. After `const` is added to the constructor
// declaration, this rewrite adds `const` to invocations of those constructors
// elsewhere in the output so `prefer_const_constructors` stays silent
// end-to-end.
//
// Validates three cases in one fixture:
//   (a) top-level `main()` body — passthrough scope.
//   (b) inside another widget's rewritten `build()` body — the post-emit pass
//       walks the assembled output, so it catches sites that survived the
//       value-rewriter.
//   (c) const elision — when both the outer and an inner `InstanceCreation`
//       are const-eligible, only the outermost gains an explicit `const`;
//       Dart's const-context elision covers the nested one.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

void main() => runApp(Outer(child: Inner()));

class Inner extends StatelessWidget {
  Inner({super.key});

  @SolidState()
  int n = 0;

  @override
  Widget build(BuildContext context) {
    return Text('$n');
  }
}

class Outer extends StatelessWidget {
  Outer({super.key, required this.child});

  final Widget child;

  @SolidState()
  int m = 0;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Text('$m'), child, Inner()]);
  }
}
