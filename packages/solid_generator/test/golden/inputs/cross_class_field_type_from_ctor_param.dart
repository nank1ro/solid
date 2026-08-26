// GAP 4 (post-#106 residual gap survey): an instance field declared with NO
// type annotation (`final _service;`) infers `dynamic` under Dart's own
// type-inference rules — a constructor field-formal parameter's EXPLICIT
// type (`AuthRepository this._service`) does NOT propagate back onto the
// field's inferred type, confirmed empirically via `package:analyzer`
// against a real resolved unit (the field's `declaredFragment.element.type`
// is `dynamic`, not `AuthRepository`). None of `value_rewriter.dart`'s
// existing receiver-resolution tiers consult constructor parameters, so
// `_service.session` stayed un-lowered even though the type is spelled out
// right there in the constructor signature.
//
// This is a same-file fixture (not `cross_file_*`): the untyped-field →
// ctor-param fallback is a pure AST scan of the ENCLOSING class's own
// constructors, independent of where `AuthRepository` itself is declared.
//
// `SessionReader` covers the field-formal parameter shape
// (`AuthRepository this._service`) — the explicit type is spelled out only
// on the parameter. `SessionReaderViaInitializer` covers the sibling
// initializer-list shape: a plain (non-field-formal) typed parameter
// assigned to the untyped field in the constructor's initializer list
// (`SessionReaderViaInitializer(AuthRepository service) : _service =
// service;`). Both classes carry their own `@SolidState` field so they
// enter the per-member rewrite pipeline (a class with zero `@Solid*`
// annotations of its own, in a file where some OTHER class IS annotated, is
// passed through verbatim rather than rewritten — only a file where EVERY
// class lacks annotations takes the pure-consumer path).
//
// The untyped `_service` field is the whole point of this fixture — the
// lints below all restate the same fact (no explicit type, so `dynamic`)
// that this fixture exists to exercise.
// ignore_for_file: inference_failure_on_uninitialized_variable
// ignore_for_file: specify_nonobvious_property_types
// ignore_for_file: prefer_typing_uninitialized_variables
// ignore_for_file: strict_top_level_inference
// ignore_for_file: avoid_dynamic_calls
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}

class SessionReader {
  SessionReader(AuthRepository this._service);

  final _service;

  @SolidState()
  int probeCount = 0;

  bool hasSession() {
    probeCount = probeCount + 1;
    return _service.session != null;
  }
}

class SessionReaderViaInitializer {
  SessionReaderViaInitializer(AuthRepository service) : _service = service;

  final _service;

  @SolidState()
  int probeCount = 0;

  bool hasSession() {
    probeCount = probeCount + 1;
    return _service.session != null;
  }
}
