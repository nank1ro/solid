// Negative-fixture companion for `consumer.dart`: `PlainRepository` carries
// no `@Solid*` annotations at all — a genuinely solid-free type reached
// only through a bare `super.x` constructor parameter (issue #108).

class PlainRepository {
  String? label;
}
