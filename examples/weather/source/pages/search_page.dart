import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../api/weather_api.dart';
import '../controllers/cities_controller.dart';
import '../domain/city.dart';
import '../widgets/search_result_tile.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @SolidEnvironment()
  late WeatherApi api;

  @SolidEnvironment()
  late CitiesController citiesController;

  @SolidState()
  String query = '';

  @SolidQuery(debounce: Duration(milliseconds: 350))
  Future<List<City>> results() => api.geocode(query);

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
              onChanged: (s) => query = s,
            ),
          ),
          Expanded(
            child: query.trim().isEmpty
                ? const Center(child: Text('Type to search'))
                : results().when(
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
                            alreadyAdded: citiesController.contains(city),
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
                  ),
          ),
        ],
      ),
    );
  }
}
