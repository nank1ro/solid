import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class HistoryRecorder extends StatefulWidget {
  const HistoryRecorder({super.key});

  @override
  State<HistoryRecorder> createState() => _HistoryRecorderState();
}

class _HistoryRecorderState extends State<HistoryRecorder> {
  final counter = Signal<int>(0, name: 'counter');
  final history = ListSignal<int>([], name: 'history');
  late final recordHistory = Effect(() {
    final c = counter.value;
    untracked(() => history.value = [...history.value, c]);
  }, name: 'recordHistory');

  @override
  void initState() {
    super.initState();
    recordHistory;
  }

  @override
  void dispose() {
    recordHistory.dispose();
    history.dispose();
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text('history has ${history.length} entries');
      },
    );
  }
}
