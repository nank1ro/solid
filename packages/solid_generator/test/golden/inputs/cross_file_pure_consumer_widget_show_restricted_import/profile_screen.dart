// Combinator-blind import-repair regression: this file already imports
// `flutter_solidart` with a `show Signal` combinator (for an unrelated,
// hand-rolled signal) BEFORE it ever gains a cross-file pure-consumer
// WIDGET read. Before the fix, `builder.dart`'s no-annotation branch
// decided whether to repair the import by checking
// `!current.contains(flutterSolidartUri)` — which is FALSE here (the
// existing `show Signal` import's directive text already contains that
// URI), so the repair step never ran at all. The lowered `build()` method
// below emits a bare `SignalBuilder(...)` call that the `show Signal`
// import does NOT expose — non-compiling generated code.
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart' show Signal;

import 'auth_repository.dart';

/// An unrelated, hand-rolled signal — not `@SolidState`-generated — that
/// explains why this file already imports `flutter_solidart` (restricted to
/// `Signal`) before ever gaining a cross-file pure-consumer widget read.
final refreshTick = Signal<int>(0);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen(this.authRepository, {super.key});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return Text(authRepository.session ?? 'anonymous');
  }
}
