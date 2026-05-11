import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Breadth extends StatefulWidget {
  const Breadth({super.key});

  @override
  State<Breadth> createState() => _BreadthState();
}

class _BreadthState extends State<Breadth> {
  final xs = ListSignal<int>(const [], name: 'xs');
  final tags = SetSignal<int>(const {}, name: 'tags');
  final counts = MapSignal<String, int>(const {}, name: 'counts');
  late final sum = Computed<int>(
    () => xs.fold<int>(0, (a, b) => a + b),
    name: 'sum',
  );
  late final evenCount = Computed<int>(
    () => xs.where((i) => i.isEven).length,
    name: 'evenCount',
  );
  late final hasOne = Computed<bool>(() => tags.contains(1), name: 'hasOne');
  late final keys = Computed<Iterable<String>>(() => counts.keys, name: 'keys');
  late final log = Effect(() {
    print(
      'len=${xs.length} '
      'first=${xs.first} '
      'idx0=${xs[0]} '
      'has-one=${tags.contains(1)} '
      'keys=${counts.keys} '
      'a=${counts['a']} '
      'has-a=${counts.containsKey('a')} '
      'indexOf=${xs.indexOf(0)} '
      'indexWhere=${xs.indexWhere((i) => i > 5)}',
    );
  }, name: 'log');

  @override
  void initState() {
    super.initState();
    log;
  }

  @override
  void dispose() {
    log.dispose();
    keys.dispose();
    hasOne.dispose();
    evenCount.dispose();
    sum.dispose();
    counts.dispose();
    tags.dispose();
    xs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text(
          'sum=${sum.value} '
          'evens=${evenCount.value} '
          'has-one=${hasOne.value} '
          'last=${xs.last} '
          'empty=${xs.isEmpty} '
          'set-len=${tags.length} '
          'map-len=${counts.length}',
        );
      },
    );
  }
}
