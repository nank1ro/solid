// Negative fixture for issue #108: `Consumer` has the exact bare-`super.x`
// PURE CONSUMER shape as `cross_file_super_param_bare_pure_consumer/
// customers_repository.dart` — importing ONLY `base_repository.dart`, never
// `plain_repository.dart` directly — but `PlainRepository` carries no
// `@SolidState` members. The syntactic super-formal seeding proposes
// `PlainRepository` as a candidate (seeding is annotation-blind by design),
// and the fix review finding 1 one-hop extension genuinely reaches its
// declaration through `base_repository.dart`'s own import of
// `plain_repository.dart` (this file never imports it directly, so without
// that one hop the class would never be found at all) — but finds zero
// `@SolidState` members there, so the cross-file registry stays empty and
// this file must pass through the fast, verbatim-passthrough path exactly
// as before the fix.
import 'base_repository.dart';

class Consumer extends BaseRepository {
  Consumer(super.plain);

  bool hasLabel() => plain.label != null;
}
