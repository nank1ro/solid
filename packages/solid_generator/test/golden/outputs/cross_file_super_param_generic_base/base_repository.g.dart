// Generic base class whose field is typed with its OWN type parameter `T`
// (issue #108 fix review addendum finding 2) — `Base(this.repo); final T
// repo;`. No import of any concrete type is needed here: `T` only becomes a
// real class once a subclass supplies a concrete type argument in its own
// `extends` clause.
class Base<T> {
  Base(this.repo);

  final T repo;
}
