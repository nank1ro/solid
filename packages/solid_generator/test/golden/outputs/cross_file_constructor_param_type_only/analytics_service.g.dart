import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class AnalyticsService implements Disposable {
  final eventCount = Signal<int>(0, name: 'eventCount');

  @override
  void dispose() {
    eventCount.dispose();
  }
}
