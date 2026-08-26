// Negative fixture for issue #106: `SettingsReader` has the exact PURE
// CONSUMER shape (constructor-injected field, zero `@Solid*` annotations,
// zero provider call sites of its own) as `cross_file_pure_consumer/
// session_reader.dart`, but `PlainSettings` carries no `@SolidState`
// members. The new cross-file probe seeds `PlainSettings` into
// `wantedTypes` (the seeding is annotation-blind by design — it only
// proposes the receiver's type name as a candidate) and walks the import,
// but finds zero `@SolidState` members there, so the cross-file registry
// stays empty and this file must pass through the fast, verbatim-passthrough
// path exactly as before the fix — proving the fast path survives for
// genuinely solid-free files.

import 'plain_settings.dart';

class SettingsReader {
  SettingsReader(this._settings);

  final PlainSettings _settings;

  int readVolume() => _settings.volume;
}
