import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class HistoryRecorder extends StatelessWidget {
  HistoryRecorder({super.key});

  @SolidState()
  int counter = 0;

  @SolidState()
  List<int> history = [];

  @SolidEffect()
  void recordHistory() {
    final c = counter;
    untracked(() => history = [...history, c]);
  }

  @override
  Widget build(BuildContext context) {
    return Text('history has ${history.length} entries');
  }
}
