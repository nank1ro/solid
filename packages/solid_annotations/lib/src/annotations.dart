/// Annotations for the Solid framework.
library;

import 'package:meta/meta_meta.dart';

/// {@template SolidAnnotations.SolidState}
/// Marks a field or getter as reactive state. See SPEC Section 3.1.
/// {@endtemplate}
@Target({TargetKind.field, TargetKind.getter})
class SolidState {
  /// {@macro SolidAnnotations.SolidState}
  const SolidState({this.name});

  /// Optional debug name; defaults to the annotated identifier.
  final String? name;
}

/// {@template SolidAnnotations.SolidEffect}
/// Reserved. Full contract deferred to a later SPEC revision;
/// see SPEC Section 3.2.
/// {@endtemplate}
class SolidEffect {
  /// {@macro SolidAnnotations.SolidEffect}
  const SolidEffect();
}

/// {@template SolidAnnotations.SolidQuery}
/// Reserved. Full contract deferred to a later SPEC revision;
/// see SPEC Section 3.2.
/// {@endtemplate}
class SolidQuery {
  /// {@macro SolidAnnotations.SolidQuery}
  const SolidQuery();
}

/// {@template SolidAnnotations.SolidEnvironment}
/// Reserved. Full contract deferred to a later SPEC revision;
/// see SPEC Section 3.2.
/// {@endtemplate}
class SolidEnvironment {
  /// {@macro SolidAnnotations.SolidEnvironment}
  const SolidEnvironment();
}
