import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart'
    hide LazyStateExtension, untracked;

class FilteredController implements Disposable {
  FilteredController() {
    record;
  }

  final counter = Signal<int>(0, name: 'counter');

  final log = ListSignal<int>([], name: 'log');

  late final record = Effect(() {
    final c = counter.value;
    untracked(() => log.value = [...log.value, c]);
  }, name: 'record');

  @override
  void dispose() {
    record.dispose();
    log.dispose();
    counter.dispose();
  }
}
