// Cross-file `@SolidState` host for the pure-consumer WIDGET regression
// (GAP 1 of the post-#106 residual gap survey). Every consumer in this
// fixture reaches this class through plain constructor injection — no
// `@SolidEnvironment` field, no `.environment()`/`Provider()` call site —
// so the cross-file registry seeding already fixed for #104/#105 picks up
// `AuthRepository`; what's new here is that some of the consumers are
// WIDGETS whose `build()` needs a `SignalBuilder` wrap, not just a `.value`
// lowering.
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
