// `@SolidQuery` on a `StatelessWidget` whose body reads widget-bound
// constructor fields. The lowered Resource closure must read the ctor
// fields through `widget.<name>` because the closure lives on the State
// class. Unlike Computed/Effect, queries don't require reactive deps, so
// this fixture exercises the rewrite without an accompanying Signal read.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key, required this.lat, required this.lon});

  final double lat;
  final double lon;

  @SolidQuery()
  Future<String> forecast() async => 'temp@$lat,$lon';

  @override
  Widget build(BuildContext context) => Text('$lat,$lon');
}
