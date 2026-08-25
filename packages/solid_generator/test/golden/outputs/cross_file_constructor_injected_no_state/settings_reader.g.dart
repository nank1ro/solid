import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'plain_settings.dart';

class SettingsReader implements Disposable {
  SettingsReader(this._settings);

  final PlainSettings _settings;

  final readCount = Signal<int>(0, name: 'readCount');

  int readVolume() {
    readCount.value = readCount.value + 1;
    return _settings.volume;
  }

  @override
  void dispose() {
    readCount.dispose();
  }
}
