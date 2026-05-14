import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import '../domain/city.dart';

class CitiesController implements Disposable {
  CitiesController({List<City> initial = const []}) {
    cities.addAll(initial);
  }

  final cities = ListSignal<City>([], name: 'cities');

  late final count = Computed<int>(() => cities.length, name: 'count');

  void add(City city) {
    if (cities.contains(city)) return;
    cities.add(city);
  }

  void remove(City city) {
    cities.removeWhere((c) => c == city);
  }

  bool contains(City city) => cities.contains(city);

  @override
  void dispose() {
    count.dispose();
    cities.dispose();
  }
}
