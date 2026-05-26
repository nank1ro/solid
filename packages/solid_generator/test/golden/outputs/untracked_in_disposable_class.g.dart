import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart' hide untracked;

class HistoryController implements Disposable {
  HistoryController() {
    record;
  }

  final counter = Signal<int>(0, name: 'counter');

  final history = ListSignal<int>([], name: 'history');

  late final record = Effect(() {
    final c = counter.value;
    untracked(() => history.value = [...history.value, c]);
  }, name: 'record');

  @override
  void dispose() {
    record.dispose();
    history.dispose();
    counter.dispose();
  }
}
