/// Annotations for the Solid framework.
library;

import 'package:meta/meta_meta.dart';

/// Marks a field or getter as reactive state. See SPEC Section 3.1.
@Target({TargetKind.field, TargetKind.getter})
class SolidState {
  /// Optional debug [name]; defaults to the annotated identifier.
  const SolidState({this.name});

  /// Optional debug name; defaults to the annotated identifier.
  final String? name;
}

/// Reserved. Full contract deferred to a later SPEC revision;
/// see SPEC Section 3.2.
class SolidEffect {
  /// Reserved constructor.
  const SolidEffect();
}

/// Reserved. Full contract deferred to a later SPEC revision;
/// see SPEC Section 3.2.
class SolidQuery {
  /// Reserved constructor.
  const SolidQuery();
}

/// Reserved. Full contract deferred to a later SPEC revision;
/// see SPEC Section 3.2.
class SolidEnvironment {
  /// Reserved constructor.
  const SolidEnvironment();
}
