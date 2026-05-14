import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../api/weather_api.dart';
import '../controllers/cities_controller.dart';
import '../domain/city.dart';
import '../widgets/search_result_tile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final api = context.read<WeatherApi>();
  late final citiesController = context.read<CitiesController>();
  final query = Signal<String>('', name: 'query');
  late final results = Resource<List<City>>(
    () => api.geocode(query.value),
    source: query,
    debounceDelay: const Duration(milliseconds: 350),
    name: 'results',
  );

  @override
  void dispose() {
    results.dispose();
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add city')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search city name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (s) => query.value = s,
            ),
          ),
          SignalBuilder(
            builder: (context, child) {
              return Expanded(
                child: query.value.trim().isEmpty
                    ? const Center(child: Text('Type to search'))
                    : SignalBuilder(
                        builder: (context, child) {
                          return results().when(
                            ready: (cities) {
                              if (cities.isEmpty) {
                                return const Center(child: Text('No matches'));
                              }
                              return ListView.builder(
                                itemCount: cities.length,
                                itemBuilder: (context, index) {
                                  final city = cities[index];
                                  return SearchResultTile(
                                    city: city,
                                    alreadyAdded: citiesController.contains(
                                      city,
                                    ),
                                    onAdd: () {
                                      citiesController.add(city);
                                      Navigator.of(context).pop();
                                    },
                                  );
                                },
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, _) => Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Search failed: $e',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}
