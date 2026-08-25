// `SettingsReader` itself carries a `@SolidState` field so this file is
// forced through the full parse-and-rewrite pipeline (otherwise the
// builder's `hasSolidAnnotation` fast-path would skip parsing entirely and
// this fixture would prove nothing about the new seeding). `PlainSettings`
// — reached only via the constructor-injected `_settings` field — has no
// `@Solid*` annotations, so `_settings.volume` must stay byte-identical.

import 'package:solid_annotations/solid_annotations.dart';

import 'plain_settings.dart';

class SettingsReader {
  SettingsReader(this._settings);

  final PlainSettings _settings;

  @SolidState()
  int readCount = 0;

  int readVolume() {
    readCount = readCount + 1;
    return _settings.volume;
  }
}
