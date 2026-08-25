// `AnalyticsService`'s name appears in this file ONLY as a constructor
// parameter type and as a same-class METHOD parameter type — never as any
// field's declared type, `@SolidEnvironment` field, or `Provider(...)` /
// `.environment<T>()` call site. Before the fix, `_populateCrossFileTypes`
// seeded `wantedTypes` from env fields and Provider/`.environment()` call
// sites only, so `classRegistry` never learned about `AnalyticsService`
// here and `summarize`'s `service.eventCount` read — whose receiver type is
// resolved by `value_rewriter.dart`'s existing parameter-typed tier, which
// needs no seeding of its own, only a populated `classRegistry` entry —
// stayed silently un-lowered. Constructor-parameter seeding is the ONLY
// thing that closes that gap for this file: there is no field of type
// `AnalyticsService` anywhere to seed from instead.
//
// The constructor stores a `String` derived from `service`, not `service`
// itself, so the file genuinely has no `AnalyticsService`-typed field.

import 'package:solid_annotations/solid_annotations.dart';

import 'analytics_service.dart';

class ReportBuilder {
  ReportBuilder(AnalyticsService service) : _label = service.toString();

  final String _label;

  @SolidState()
  int reportsBuilt = 0;

  int summarize(AnalyticsService service) {
    reportsBuilt = reportsBuilt + 1;
    return service.eventCount;
  }

  String describe() => _label;
}
