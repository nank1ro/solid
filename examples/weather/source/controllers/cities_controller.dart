import 'package:solid_annotations/solid_annotations.dart';

import '../domain/city.dart';

class CitiesController {
  CitiesController({List<City> initial = const []}) {
    cities.addAll(initial);
  }

  @SolidState()
  List<City> cities = [];

  @SolidState()
  int get count => cities.length;

  void add(City city) {
    if (cities.contains(city)) return;
    cities.add(city);
  }

  void remove(City city) {
    cities.removeWhere((c) => c == city);
  }

  bool contains(City city) => cities.contains(city);
}
