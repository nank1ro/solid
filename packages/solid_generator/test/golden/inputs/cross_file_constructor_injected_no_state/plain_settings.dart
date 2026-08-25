// Negative-fixture companion for `settings_reader.dart`: `PlainSettings`
// carries no `@Solid*` annotations at all. Reached from
// `settings_reader.dart` only via a constructor-injected field — the new
// constructor-param/field-type seeding introduced for issue #104 still adds
// `PlainSettings` to `wantedTypes` (the seeding is annotation-blind by
// design; it only proposes the receiver's type name as a candidate), but
// the subsequent import walk finds zero `@SolidState` members here, so
// `classRegistry` never gains a `PlainSettings` entry and `_settings.volume`
// must stay byte-identical.

class PlainSettings {
  int volume = 50;
}
