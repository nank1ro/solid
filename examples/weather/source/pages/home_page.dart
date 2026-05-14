import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/cities_controller.dart';
import '../widgets/city_card.dart';
import 'search_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @SolidEnvironment()
  late CitiesController citiesController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weather (${citiesController.count})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: citiesController.cities.isEmpty
          ? const Center(child: Text('No cities — add one with the + button'))
          : ListView.builder(
              itemCount: citiesController.cities.length,
              itemBuilder: (context, index) {
                final city = citiesController.cities[index];
                return CityCard(key: ValueKey(city), city: city);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SearchPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
