// Rejection suite for invalid `@SolidQuery` placements.
//
// Cases ordered to mirror the bullet list: non-Future/Stream return →
// parameterized → static → abstract/external → getter → setter → top-level
// function. Class fields are NOT rejected: a field initializer expression
// (e.g. `Future.value(0)`) is a valid fetcher shape — the lowering wraps it
// as `Resource<T>(fetcher: () => <init>)`. Body-keyword/return-type mismatch
// is also NOT rejected: a `Future<T>` method with an arrow body that
// returns a Future is valid Dart and is preserved by the emitter; Dart's
// own analyzer reports `await_in_non_async_function` when `await` is used
// without `async`, so the generator does not duplicate that check.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'non_future_return',
    errorContains:
        '@SolidQuery cannot be applied to a non-Future/Stream method',
  ),
  (
    name: 'solid_query_parameterized',
    errorContains: '@SolidQuery cannot be applied to a parameterized method',
  ),
  (
    name: 'solid_query_static',
    errorContains: '@SolidQuery cannot be applied to a static method',
  ),
  (
    name: 'solid_query_abstract',
    errorContains: '@SolidQuery cannot be applied to an abstract method',
  ),
  (
    name: 'solid_query_getter',
    errorContains: '@SolidQuery cannot be applied to a getter',
  ),
  (
    name: 'solid_query_setter',
    errorContains: '@SolidQuery cannot be applied to a setter',
  ),
  (
    name: 'solid_query_top_level',
    errorContains: '@SolidQuery cannot be applied to a top-level function',
  ),
];

void main() {
  runRejectionCases('invalid @SolidQuery targets', _cases);
}
