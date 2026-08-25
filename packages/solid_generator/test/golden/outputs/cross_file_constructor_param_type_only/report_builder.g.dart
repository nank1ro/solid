import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'analytics_service.dart';

class ReportBuilder implements Disposable {
  ReportBuilder(AnalyticsService service) : _label = service.toString();

  final String _label;

  final reportsBuilt = Signal<int>(0, name: 'reportsBuilt');

  int summarize(AnalyticsService service) {
    reportsBuilt.value = reportsBuilt.value + 1;
    return service.eventCount.value;
  }

  String describe() => _label;

  @override
  void dispose() {
    reportsBuilt.dispose();
  }
}
