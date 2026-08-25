// Cross-file `@SolidState` host reached ONLY through a plain (simple)
// constructor parameter (see `report_builder.dart`) — the class stores no
// field of this type at all, so the builder's field-declared-type seeding
// alone cannot see `AnalyticsService`; only the constructor-parameter
// seeding introduced for issue #104 reaches it.

import 'package:solid_annotations/solid_annotations.dart';

class AnalyticsService {
  @SolidState()
  int eventCount = 0;
}
